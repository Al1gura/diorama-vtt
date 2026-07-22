extends Node

const SAMPLE_DURATION_USEC: int = 1_100_000
const FPS_SAMPLE_COUNT: int = 3
const FIXTURE_MODULE_NAME: String = "测试模组"
const RESULT_PATH: String = "user://p2_acceptance_metrics.json"

var _assertion_count: int = 0
var _failures: Array[String] = []

@onready var _main: Node3D = $Main


func _ready() -> void:
	await get_tree().process_frame
	var result: Dictionary = await _run_metrics()
	result["assertions"] = _assertion_count
	result["failed"] = _failures.size()
	result["failures"] = _failures
	result["godot_version"] = Engine.get_version_info()
	result["display_server"] = DisplayServer.get_name()
	_write_result(result)
	print("P2_ACCEPTANCE_METRICS " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P2_ACCEPTANCE_METRICS_FAILURES " + JSON.stringify(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run_metrics() -> Dictionary:
	var fixture_path: String = ModuleGate.MODULE_ROOT.path_join(FIXTURE_MODULE_NAME)
	_remove_dir_recursive(fixture_path)
	var recover_error: int = ModuleGate.recover_legacy_test_module()
	_check(recover_error == OK, "无法把现有测试模组复制到隔离验收目录")
	await get_tree().process_frame

	var scene_names: Array[String] = ModuleGate.list_scene_names()
	_check(scene_names.size() >= 2, "验收模组至少需要两个真实场景")
	if scene_names.size() < 2:
		_cleanup_fixture(fixture_path)
		return {
			"scene_switch_samples": [],
			"dual_window_fps_samples": [],
			"frames_drawn_samples": [],
		}

	var scene_switch_samples: Array[Dictionary] = []
	for index: int in range(4):
		var target_name: String = scene_names[index % 2]
		var start_usec: int = Time.get_ticks_usec()
		_main.call("_switch_to_scene", target_name)
		var synchronous_usec: int = Time.get_ticks_usec() - start_usec
		await get_tree().process_frame
		await get_tree().process_frame
		var visible_usec: int = Time.get_ticks_usec() - start_usec
		var actual_name: String = String(_main.get("_current_scene_name"))
		_check(actual_name == target_name, "切场景完成后当前场景名不一致")
		scene_switch_samples.append({
			"target": target_name,
			"synchronous_ms": float(synchronous_usec) / 1000.0,
			"visible_ms": float(visible_usec) / 1000.0,
		})

	var cast_view: Node = _main.get("_cast_view") as Node
	var output_controller: Node = _main.get("_player_output_controller") as Node
	_check(cast_view != null and is_instance_valid(cast_view), "CastView 未创建")
	_check(
		output_controller != null and is_instance_valid(output_controller),
		"PlayerOutputController 未创建"
	)
	var fps_samples: Array[float] = []
	var frames_drawn_samples: Array[float] = []
	var cast_window_visible: bool = false
	if (
		cast_view != null
		and is_instance_valid(cast_view)
		and output_controller != null
		and is_instance_valid(output_controller)
	):
		var open_result: Dictionary = output_controller.call("open_output") as Dictionary
		_check(int(open_result.get("error", FAILED)) == OK, "玩家输出控制器未能打开投屏")
		await get_tree().process_frame
		await get_tree().process_frame
		var cast_window: Window = cast_view.get("_cast_window") as Window
		cast_window_visible = (
			cast_window != null
			and is_instance_valid(cast_window)
			and cast_window.visible
			and bool(cast_view.call("is_open"))
		)
		_check(cast_window_visible, "第二个原生投屏窗口未进入可见状态")

		for _sample_index: int in range(FPS_SAMPLE_COUNT):
			var sample_start_usec: int = Time.get_ticks_usec()
			var sample_start_frames: int = Engine.get_frames_drawn()
			while Time.get_ticks_usec() - sample_start_usec < SAMPLE_DURATION_USEC:
				await get_tree().process_frame
			var elapsed_usec: int = Time.get_ticks_usec() - sample_start_usec
			var frames_delta: int = Engine.get_frames_drawn() - sample_start_frames
			fps_samples.append(Engine.get_frames_per_second())
			frames_drawn_samples.append(
				float(frames_delta) * 1_000_000.0 / float(maxi(elapsed_usec, 1))
			)

		var close_result: Dictionary = output_controller.call("close_output") as Dictionary
		_check(int(close_result.get("error", FAILED)) == OK, "玩家输出控制器未能关闭投屏")
		await get_tree().process_frame
		await get_tree().process_frame
		_check(not bool(cast_view.call("is_open")), "测量结束后投屏状态未关闭")
		_check(cast_view.get("_cast_window") == null, "测量结束后投屏窗口引用未释放")

	_check(not fps_samples.is_empty(), "没有取得双窗口帧率样本")
	for fps: float in fps_samples:
		_check(fps > 0.0, "双窗口帧率样本必须大于零")
	for measured_fps: float in frames_drawn_samples:
		_check(measured_fps > 0.0, "双窗口真实绘制速率必须大于零")

	_cleanup_fixture(fixture_path)
	return {
		"scene_switch_samples": scene_switch_samples,
		"dual_window_fps_samples": fps_samples,
		"frames_drawn_samples": frames_drawn_samples,
		"dual_window_fps_average": _average(fps_samples),
		"frames_drawn_average": _average(frames_drawn_samples),
		"cast_window_visible": cast_window_visible,
	}


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)


func _write_result(result: Dictionary) -> void:
	var output_file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if output_file == null:
		push_error("无法写入 P2 验收测量结果: %s" % RESULT_PATH)
		return
	output_file.store_string(JSON.stringify(result, "\t"))
	output_file.close()


func _cleanup_fixture(fixture_path: String) -> void:
	if ModuleGate.current_module_name() == FIXTURE_MODULE_NAME:
		ModuleGate.close_module()
	_remove_dir_recursive(fixture_path)


func _remove_dir_recursive(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var directory: DirAccess = DirAccess.open(dir_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while entry_name != "":
		var entry_path: String = dir_path.path_join(entry_name)
		if directory.current_is_dir():
			_remove_dir_recursive(entry_path)
		else:
			DirAccess.remove_absolute(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(dir_path)

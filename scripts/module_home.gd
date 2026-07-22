extends Control

const EDITOR_SCENE_PATH: String = "res://scenes/main.tscn"

var _module_list_container: VBoxContainer
var _status_label: Label
var _recover_legacy_button: Button
var _import_dialog: FileDialog = null
var _transitioning: bool = false


func _ready() -> void:
	_build_ui()
	_sync_module_list()
	if ModuleGate.has_open_module():
		_enter_editor()


func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.075, 0.08, 0.09, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(center)
	var content: VBoxContainer = VBoxContainer.new()
	content.custom_minimum_size = Vector2(500, 0)
	content.add_theme_constant_override("separation", 12)
	center.add_child(content)
	var title: Label = Label.new()
	title.text = "Gvtt"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	content.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "选择模组"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.68, 0.72, 0.76))
	content.add_child(subtitle)
	content.add_child(HSeparator.new())
	var module_scroll: ScrollContainer = ScrollContainer.new()
	module_scroll.custom_minimum_size = Vector2(500, 220)
	module_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(module_scroll)
	_module_list_container = VBoxContainer.new()
	_module_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_module_list_container.add_theme_constant_override("separation", 6)
	module_scroll.add_child(_module_list_container)
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	content.add_child(action_row)
	var new_module_button: Button = Button.new()
	new_module_button.text = "新建模组"
	new_module_button.custom_minimum_size = Vector2(150, 40)
	new_module_button.pressed.connect(_on_new_module_pressed)
	action_row.add_child(new_module_button)
	var import_module_button: Button = Button.new()
	import_module_button.text = "导入模组"
	import_module_button.custom_minimum_size = Vector2(150, 40)
	import_module_button.pressed.connect(_on_import_module_pressed)
	action_row.add_child(import_module_button)
	_recover_legacy_button = Button.new()
	_recover_legacy_button.text = "恢复旧数据"
	_recover_legacy_button.custom_minimum_size = Vector2(0, 36)
	_recover_legacy_button.pressed.connect(_on_recover_legacy_module_pressed)
	content.add_child(_recover_legacy_button)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)


func _sync_module_list() -> void:
	for child: Node in _module_list_container.get_children():
		_module_list_container.remove_child(child)
		child.queue_free()
	var module_names: Array[String] = ModuleGate.list_module_names()
	if module_names.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "暂无模组"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.58, 0.62, 0.66))
		_module_list_container.add_child(empty_label)
	else:
		for module_name: String in module_names:
			var module_button: Button = Button.new()
			module_button.text = module_name
			module_button.custom_minimum_size = Vector2(0, 42)
			module_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			module_button.pressed.connect(_on_open_module_pressed.bind(module_name))
			_module_list_container.add_child(module_button)
	_recover_legacy_button.visible = ModuleGate.legacy_module_available()


func _on_new_module_pressed() -> void:
	var err: int = ModuleGate.create_unique_module("新模组")
	if err != OK:
		_set_status("新建模组失败 code=" + str(err), true)
		return
	_enter_editor()


func _on_import_module_pressed() -> void:
	if _import_dialog == null or not is_instance_valid(_import_dialog):
		_import_dialog = FileDialog.new()
		_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_import_dialog.use_native_dialog = true
		_import_dialog.dir_selected.connect(_on_module_import_dir_selected)
		add_child(_import_dialog)
	_import_dialog.title = "选择要导入的模组文件夹"
	_import_dialog.popup_file_dialog()


func _on_module_import_dir_selected(dir_path: String) -> void:
	if dir_path == "":
		return
	var err: int = ModuleGate.import_module_from_path(dir_path)
	if err != OK:
		_set_status("导入模组失败 code=" + str(err), true)
		return
	_enter_editor()


func _on_recover_legacy_module_pressed() -> void:
	var err: int = ModuleGate.recover_legacy_test_module()
	if err != OK:
		_set_status("恢复旧数据失败 code=" + str(err), true)
		return
	_enter_editor()


func _on_open_module_pressed(module_name: String) -> void:
	var err: int = ModuleGate.open_module(module_name)
	var manifest_result: Dictionary = ModuleGate.last_manifest_result()
	if err != OK:
		var failure_text: String = "打开模组失败"
		var result_message: String = String(manifest_result.get("message", ""))
		if result_message != "":
			failure_text += "：" + result_message
		failure_text += " code=" + str(err)
		_set_status(failure_text, true)
		return
	_enter_editor()


func _enter_editor() -> void:
	if _transitioning:
		return
	_transitioning = true
	var err: int = get_tree().change_scene_to_file(EDITOR_SCENE_PATH)
	if err != OK:
		_transitioning = false
		_set_status("进入编辑器失败 code=" + str(err), true)


func _set_status(text: String, is_error: bool) -> void:
	_status_label.text = text
	var color: Color = Color(0.92, 0.38, 0.32) if is_error else Color(0.42, 0.78, 0.52)
	_status_label.add_theme_color_override("font_color", color)

class_name CastView
extends Node
## Native player-window shell. Output state belongs to PlayerOutputController.

signal close_requested

const DEFAULT_SIZE: Vector2i = Vector2i(1280, 720)
const DEFAULT_TITLE: String = "Gvtt - 玩家视角（投屏）"

var _cast_window: Window = null
var _media_canvas: CanvasLayer = null
var _media_root: Control = null
var _presenter_host: Control = null
var _is_open: bool = false
var _low_quality: bool = false


func is_open() -> bool:
	return _is_open and _cast_window != null and is_instance_valid(_cast_window)


func open(parent_node: Node) -> int:
	if is_open():
		_cast_window.show()
		_cast_window.grab_focus()
		return OK
	if parent_node == null or not is_instance_valid(parent_node):
		return ERR_INVALID_PARAMETER
	_cast_window = Window.new()
	_cast_window.name = "CastWindow"
	_cast_window.title = DEFAULT_TITLE
	_cast_window.size = DEFAULT_SIZE
	_cast_window.add_to_group("gvtt_player_output_window")
	_cast_window.visible = false
	_cast_window.borderless = false
	_cast_window.unfocusable = false
	_cast_window.close_requested.connect(_on_window_close_requested)
	parent_node.add_child(_cast_window)
	_build_media_surface()
	_apply_low_quality()
	_cast_window.show()
	_cast_window.grab_focus()
	_is_open = true
	return OK


func release_window() -> void:
	if _cast_window != null and is_instance_valid(_cast_window):
		var close_callable: Callable = Callable(self, "_on_window_close_requested")
		if _cast_window.close_requested.is_connected(close_callable):
			_cast_window.close_requested.disconnect(close_callable)
		_cast_window.hide()
		_cast_window.queue_free()
	_cast_window = null
	_media_canvas = null
	_media_root = null
	_presenter_host = null
	_is_open = false


func get_cast_window() -> Window:
	return _cast_window


func get_presenter_host() -> Control:
	return _presenter_host


func show_media_surface() -> void:
	if _media_root != null and is_instance_valid(_media_root):
		_media_root.show()


func show_map_surface() -> void:
	if _media_root != null and is_instance_valid(_media_root):
		_media_root.hide()


func set_low_quality(enabled: bool) -> void:
	_low_quality = enabled
	_apply_low_quality()


func _build_media_surface() -> void:
	_media_canvas = CanvasLayer.new()
	_media_canvas.name = "PlayerOutputCanvas"
	_cast_window.add_child(_media_canvas)
	_media_root = Control.new()
	_media_root.name = "MediaRoot"
	_media_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_media_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_media_canvas.add_child(_media_root)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "BlackBackdrop"
	backdrop.color = Color.BLACK
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_media_root.add_child(backdrop)
	_presenter_host = Control.new()
	_presenter_host.name = "PresenterHost"
	_presenter_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_presenter_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_media_root.add_child(_presenter_host)
	_media_root.hide()


func _on_window_close_requested() -> void:
	close_requested.emit()


func _apply_low_quality() -> void:
	if _cast_window == null or not is_instance_valid(_cast_window):
		return
	_cast_window.positional_shadow_atlas_size = 0 if _low_quality else 2048
	_cast_window.msaa_3d = Viewport.MSAA.MSAA_DISABLED
	_cast_window.use_taa = false
	_cast_window.mesh_lod_threshold = 2.0 if _low_quality else 1.0

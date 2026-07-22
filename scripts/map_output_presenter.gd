class_name MapOutputPresenter
extends PlayerOutputPresenter

var _cast_view: CastView = null
var _main_camera: Camera3D = null
var _cast_camera: Camera3D = null
var _los_service: Node = null
var _fog_overlay: CanvasLayer = null
var _fog_overlay_script: GDScript = preload("res://scripts/cast_fog_overlay.gd")
var _active: bool = false


func configure(cast_view: CastView, main_camera: Camera3D, los_service: Node) -> void:
	_cast_view = cast_view
	_main_camera = main_camera
	_los_service = los_service


func activate() -> int:
	if _cast_view == null or not _cast_view.is_open() or _main_camera == null:
		return ERR_UNCONFIGURED
	var cast_window: Window = _cast_view.get_cast_window()
	if cast_window == null:
		return ERR_UNCONFIGURED
	cast_window.world_3d = _main_camera.get_viewport().world_3d
	_ensure_nodes(cast_window)
	if _cast_camera == null:
		return ERR_CANT_CREATE
	_cast_camera.current = true
	if _fog_overlay != null:
		_fog_overlay.show()
	_connect_los()
	_sync_camera()
	_sync_fog()
	_active = true
	_released = false
	set_process(true)
	return OK


func deactivate(_reason: StringName) -> void:
	_active = false
	set_process(false)
	if _cast_camera != null and is_instance_valid(_cast_camera):
		_cast_camera.current = false
	if _fog_overlay != null and is_instance_valid(_fog_overlay):
		_fog_overlay.hide()


func release() -> void:
	if _released:
		return
	deactivate(&"release")
	_disconnect_los()
	if _fog_overlay != null and is_instance_valid(_fog_overlay):
		_fog_overlay.queue_free()
	if _cast_camera != null and is_instance_valid(_cast_camera):
		_cast_camera.queue_free()
	_fog_overlay = null
	_cast_camera = null
	_main_camera = null
	_los_service = null
	_cast_view = null
	super.release()


func set_player_visible_layers(mask: int) -> void:
	if _cast_camera != null and is_instance_valid(_cast_camera):
		_cast_camera.cull_mask = mask


func _process(_delta: float) -> void:
	if not _active:
		return
	_sync_camera()


func _ensure_nodes(cast_window: Window) -> void:
	if _cast_camera == null or not is_instance_valid(_cast_camera):
		_cast_camera = Camera3D.new()
		_cast_camera.name = "CastCamera"
		_cast_camera.cull_mask = GvttRenderLayers.CULL_MASK_PLAYER
		cast_window.add_child(_cast_camera)
	if _fog_overlay == null or not is_instance_valid(_fog_overlay):
		_fog_overlay = _fog_overlay_script.new() as CanvasLayer
		if _fog_overlay != null:
			_fog_overlay.name = "CastFogOverlay"
			cast_window.add_child(_fog_overlay)
			_fog_overlay.call("configure", cast_window, _cast_camera)


func _connect_los() -> void:
	if _los_service == null or not is_instance_valid(_los_service):
		return
	var changed_callable: Callable = Callable(self, "_on_los_visibility_changed")
	if not _los_service.is_connected("visibility_changed", changed_callable):
		_los_service.connect("visibility_changed", changed_callable)


func _disconnect_los() -> void:
	if _los_service == null or not is_instance_valid(_los_service):
		return
	var changed_callable: Callable = Callable(self, "_on_los_visibility_changed")
	if _los_service.is_connected("visibility_changed", changed_callable):
		_los_service.disconnect("visibility_changed", changed_callable)


func _sync_camera() -> void:
	if _cast_camera == null or _main_camera == null:
		return
	if not is_instance_valid(_cast_camera) or not is_instance_valid(_main_camera):
		return
	_cast_camera.global_transform = _main_camera.global_transform
	_cast_camera.projection = _main_camera.projection
	_cast_camera.fov = _main_camera.fov
	_cast_camera.near = _main_camera.near
	_cast_camera.far = _main_camera.far
	_cast_camera.keep_aspect = _main_camera.keep_aspect
	if _main_camera.projection == Camera3D.ProjectionType.PROJECTION_ORTHOGONAL:
		_cast_camera.size = _main_camera.size


func _on_los_visibility_changed(polygon: PackedVector2Array, active: bool) -> void:
	if _fog_overlay != null and is_instance_valid(_fog_overlay):
		_fog_overlay.call("set_world_polygon", polygon, active)


func _sync_fog() -> void:
	if _fog_overlay == null or not is_instance_valid(_fog_overlay):
		return
	if _los_service == null or not is_instance_valid(_los_service):
		_fog_overlay.call("set_world_polygon", PackedVector2Array(), false)
		return
	var polygon: PackedVector2Array = _los_service.call("get_visible_polygon") as PackedVector2Array
	var active: bool = _los_service.call("get_observer_token") != null and polygon.size() >= 3
	_fog_overlay.call("set_world_polygon", polygon, active)

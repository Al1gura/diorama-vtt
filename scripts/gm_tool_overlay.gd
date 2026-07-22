class_name GMToolOverlay
extends CanvasLayer

var _target_viewport: Viewport = null
var _main_camera: Camera3D = null
var _tool_viewport: SubViewport = null
var _tool_camera: Camera3D = null
var _texture_rect: TextureRect = null
var _tool_cull_mask: int = 0
var _adopted_surface: Control = null


func configure(
		target_viewport: Viewport,
		main_camera: Camera3D,
		cull_mask: int,
		canvas_layer: int
) -> void:
	_target_viewport = target_viewport
	_main_camera = main_camera
	_tool_cull_mask = cull_mask
	layer = canvas_layer
	_create_tool_viewport()
	_create_texture_rect()
	set_process_priority(100)
	set_process(true)
	_sync_viewport_size()
	_sync_camera()


func adopt_gizmo_surface(gizmo: Node) -> bool:
	if gizmo == null or not is_instance_valid(gizmo):
		return false
	var surface_value: Variant = gizmo.get("_surface")
	if not surface_value is Control:
		return false
	var surface: Control = surface_value as Control
	if surface.get_parent() != self:
		var old_parent: Node = surface.get_parent()
		if old_parent != null:
			old_parent.remove_child(surface)
		add_child(surface)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_child(surface, get_child_count() - 1)
	_adopted_surface = surface
	return true


func has_adopted_gizmo_surface() -> bool:
	return _adopted_surface != null and is_instance_valid(_adopted_surface)


func _process(_delta: float) -> void:
	_sync_viewport_size()
	_sync_camera()


func _create_tool_viewport() -> void:
	_tool_viewport = SubViewport.new()
	_tool_viewport.name = "GMToolViewport"
	_tool_viewport.size = Vector2i.ONE
	_tool_viewport.transparent_bg = true
	_tool_viewport.gui_disable_input = true
	_tool_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_tool_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _target_viewport != null and is_instance_valid(_target_viewport):
		_tool_viewport.world_3d = _target_viewport.world_3d
	add_child(_tool_viewport)
	_tool_camera = Camera3D.new()
	_tool_camera.name = "GMToolCamera"
	_tool_camera.cull_mask = _tool_cull_mask
	_tool_camera.current = true
	_tool_viewport.add_child(_tool_camera)


func _create_texture_rect() -> void:
	_texture_rect = TextureRect.new()
	_texture_rect.name = "GMToolTexture"
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_texture_rect.texture = _tool_viewport.get_texture()
	add_child(_texture_rect)


func _sync_viewport_size() -> void:
	if (
		_target_viewport == null
		or not is_instance_valid(_target_viewport)
		or _tool_viewport == null
	):
		return
	var target_size: Vector2 = _target_viewport.get_visible_rect().size
	var safe_size: Vector2i = Vector2i(
		maxi(roundi(target_size.x), 1),
		maxi(roundi(target_size.y), 1)
	)
	if _tool_viewport.size != safe_size:
		_tool_viewport.size = safe_size


func _sync_camera() -> void:
	if (
		_main_camera == null
		or not is_instance_valid(_main_camera)
		or _tool_camera == null
	):
		return
	_tool_camera.global_transform = _main_camera.global_transform
	_tool_camera.projection = _main_camera.projection
	_tool_camera.keep_aspect = _main_camera.keep_aspect
	_tool_camera.fov = _main_camera.fov
	_tool_camera.size = _main_camera.size
	_tool_camera.near = _main_camera.near
	_tool_camera.far = _main_camera.far
	_tool_camera.frustum_offset = _main_camera.frustum_offset
	_tool_camera.h_offset = _main_camera.h_offset
	_tool_camera.v_offset = _main_camera.v_offset
	_tool_camera.cull_mask = _tool_cull_mask

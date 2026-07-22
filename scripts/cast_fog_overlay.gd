class_name CastFogOverlay
extends CanvasLayer

const FOG_COLOR: Color = Color(0.015, 0.02, 0.025, 0.94)
const MASK_SHADER_CODE: String = """
shader_type canvas_item;

uniform sampler2D visibility_mask : filter_nearest, repeat_disable;
uniform vec4 fog_color : source_color = vec4(0.015, 0.02, 0.025, 0.94);

void fragment() {
	float visible = step(0.5, texture(visibility_mask, UV).a);
	COLOR = vec4(fog_color.rgb, fog_color.a * (1.0 - visible));
}
"""

var _target_viewport: Viewport = null
var _cast_camera: Camera3D = null
var _mask_viewport: SubViewport = null
var _mask_polygon: Polygon2D = null
var _fog_rect: TextureRect = null
var _world_polygon: PackedVector2Array = PackedVector2Array()
var _active: bool = false


func configure(
	target_viewport: Viewport,
	cast_camera: Camera3D,
	canvas_layer: int = 100
) -> void:
	_target_viewport = target_viewport
	_cast_camera = cast_camera
	layer = canvas_layer
	_create_mask_viewport()
	_create_fog_rect()
	set_process(true)
	_update_viewport_size()
	_update_projected_polygon()


func set_world_polygon(polygon: PackedVector2Array, active: bool) -> void:
	_world_polygon = polygon.duplicate()
	_active = active and _world_polygon.size() >= 3
	if _fog_rect != null:
		_fog_rect.visible = _active
	_update_projected_polygon()


func is_fog_active() -> bool:
	return _active


func get_projected_polygon() -> PackedVector2Array:
	if _mask_polygon == null:
		return PackedVector2Array()
	return _mask_polygon.polygon.duplicate()


func _process(_delta: float) -> void:
	if not _active:
		return
	_update_viewport_size()
	_update_projected_polygon()


func _create_mask_viewport() -> void:
	_mask_viewport = SubViewport.new()
	_mask_viewport.name = "LOSVisibilityMask"
	_mask_viewport.transparent_bg = true
	_mask_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_mask_viewport)
	_mask_polygon = Polygon2D.new()
	_mask_polygon.name = "VisiblePolygon"
	_mask_polygon.color = Color.WHITE
	_mask_viewport.add_child(_mask_polygon)


func _create_fog_rect() -> void:
	_fog_rect = TextureRect.new()
	_fog_rect.name = "LOSFog"
	_fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fog_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fog_rect.texture = _mask_viewport.get_texture()
	_fog_rect.visible = false
	var shader: Shader = Shader.new()
	shader.code = MASK_SHADER_CODE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("visibility_mask", _mask_viewport.get_texture())
	material.set_shader_parameter("fog_color", FOG_COLOR)
	_fog_rect.material = material
	add_child(_fog_rect)


func _update_viewport_size() -> void:
	if (
		_target_viewport == null
		or not is_instance_valid(_target_viewport)
		or _mask_viewport == null
	):
		return
	var target_size: Vector2 = _target_viewport.get_visible_rect().size
	var safe_size: Vector2i = Vector2i(
		maxi(roundi(target_size.x), 1),
		maxi(roundi(target_size.y), 1)
	)
	if _mask_viewport.size != safe_size:
		_mask_viewport.size = safe_size


func _update_projected_polygon() -> void:
	if _mask_polygon == null:
		return
	if (
		not _active
		or _cast_camera == null
		or not is_instance_valid(_cast_camera)
		or not _cast_camera.is_inside_tree()
	):
		_mask_polygon.polygon = PackedVector2Array()
		return
	var projected: PackedVector2Array = PackedVector2Array()
	for world_point: Vector2 in _world_polygon:
		var point_3d: Vector3 = Vector3(world_point.x, 0.0, world_point.y)
		if _cast_camera.is_position_behind(point_3d):
			_mask_polygon.polygon = PackedVector2Array()
			return
		projected.append(_cast_camera.unproject_position(point_3d))
	_mask_polygon.polygon = projected

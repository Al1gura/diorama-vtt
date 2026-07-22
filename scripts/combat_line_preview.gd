class_name CombatLinePreview
extends Node3D
## GM-only preview for one explicit shooter-to-target combat geometry query.

const NO_BLOCKER_COLOR: Color = Color(0.1, 0.85, 0.95, 1.0)
const BLOCKER_COLOR: Color = Color(1.0, 0.65, 0.15, 1.0)
const REMAINDER_COLOR: Color = Color(0.55, 0.58, 0.62, 0.75)
const MARKER_SIZE: float = 0.12
const EYE_OFFSET_FROM_TOP_RATIO: float = 1.0 / 9.0
const AIM_GUIDE_SEGMENTS: int = 32

var _line_instance: MeshInstance3D = null
var _line_mesh: ImmediateMesh = null
var _aim_guide: Line2D = null
var _no_blocker_material: StandardMaterial3D = null
var _blocker_material: StandardMaterial3D = null
var _remainder_material: StandardMaterial3D = null
var _last_result: Dictionary = {}
var _last_origin: Vector3 = Vector3.ZERO
var _last_target: Vector3 = Vector3.ZERO
var _last_shooter: Node3D = null
var _locked: bool = false


func _ready() -> void:
	set_meta("gvtt_runtime_only", true)
	_create_renderer()
	hide_preview()


func show_preview(
		shooter: Node3D,
		target_position: Vector3,
		target_entity: Node3D = null
) -> Dictionary:
	if _locked:
		return _last_result.duplicate()
	if shooter == null or not is_instance_valid(shooter):
		hide_preview()
		return {}
	var world: World3D = shooter.get_world_3d()
	if world == null:
		hide_preview()
		return {}
	_last_origin = get_entity_aim_point(shooter)
	_last_target = target_position
	_last_shooter = shooter
	if _last_origin.is_equal_approx(_last_target):
		hide_preview()
		return {}
	_last_result = CombatLineQuery.cast(
		world,
		_last_origin,
		_last_target,
		_collect_excludes(shooter, target_entity)
	)
	_draw_result()
	return _last_result.duplicate()


func hide_preview() -> void:
	_last_result = {}
	_last_shooter = null
	if _line_mesh != null:
		_line_mesh.clear_surfaces()
	if _line_instance != null:
		_line_instance.visible = false
	hide_aim_guide()


func clear_preview() -> void:
	_locked = false
	hide_preview()


func lock_current() -> bool:
	if (
			_line_instance == null
			or not _line_instance.visible
			or _last_shooter == null
			or not is_instance_valid(_last_shooter)
	):
		return false
	_locked = true
	hide_aim_guide()
	return true


func unlock() -> void:
	_locked = false


func is_locked() -> bool:
	return _locked


func is_locked_for(shooter: Node3D) -> bool:
	return _locked and shooter != null and shooter == _last_shooter


func get_last_result() -> Dictionary:
	return _last_result.duplicate()


func get_last_origin() -> Vector3:
	return _last_origin


func get_last_target() -> Vector3:
	return _last_target


func get_line_instance() -> MeshInstance3D:
	return _line_instance


static func get_entity_aim_point(entity: Node3D) -> Vector3:
	if entity == null or not is_instance_valid(entity):
		return Vector3.ZERO
	var bounds: AABB = OcclusionGeometry.get_local_bounds(entity)
	if bounds.has_volume():
		var local_eye: Vector3 = bounds.get_center()
		local_eye.y = bounds.end.y - bounds.size.y * EYE_OFFSET_FROM_TOP_RATIO
		return entity.global_transform * local_eye
	var height: float = 0.0
	var token_properties: TokenProperties = entity.get_node_or_null(
		"TokenProperties"
	) as TokenProperties
	if token_properties != null:
		height = maxf(token_properties.collision_height, 0.0)
	return entity.global_position + Vector3.UP * height * (1.0 - EYE_OFFSET_FROM_TOP_RATIO)


static func get_screen_aim_direction(
		camera: Camera3D,
		aim_origin: Vector3,
		screen_position: Vector2
) -> Vector3:
	if camera == null or not is_instance_valid(camera) or not camera.is_inside_tree():
		return Vector3.ZERO
	var screen_center: Vector2 = camera.unproject_position(aim_origin)
	var screen_delta: Vector2 = screen_position - screen_center
	if screen_delta.length_squared() < 1.0:
		screen_delta = Vector2.UP
	var camera_basis: Basis = camera.global_transform.basis.orthonormalized()
	var world_right: Vector3 = camera_basis.x
	world_right.y = 0.0
	if world_right.length_squared() < 0.0001:
		world_right = Vector3.RIGHT
	world_right = world_right.normalized()
	var world_screen_up: Vector3 = camera_basis.y
	world_screen_up.y = 0.0
	world_screen_up -= world_right * world_screen_up.dot(world_right)
	if world_screen_up.length_squared() < 0.0001:
		world_screen_up = Vector3.UP.cross(world_right)
	world_screen_up = world_screen_up.normalized()
	return (
		world_right * screen_delta.x - world_screen_up * screen_delta.y
	).normalized()


func show_aim_guide(screen_center: Vector2, radius: float) -> void:
	if _aim_guide == null or _locked:
		return
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(AIM_GUIDE_SEGMENTS + 1):
		var angle: float = PI + PI * float(index) / float(AIM_GUIDE_SEGMENTS)
		points.append(screen_center + Vector2(cos(angle), sin(angle)) * radius)
	_aim_guide.points = points
	_aim_guide.visible = true


func hide_aim_guide() -> void:
	if _aim_guide != null:
		_aim_guide.visible = false


func _collect_excludes(shooter: Node3D, target_entity: Node3D) -> Array[RID]:
	var excludes: Array[RID] = []
	_append_combat_body_rid(shooter, excludes)
	if target_entity != null and target_entity != shooter:
		_append_combat_body_rid(target_entity, excludes)
	return excludes


func _append_combat_body_rid(entity: Node3D, excludes: Array[RID]) -> void:
	var combat_body: CombatBody = entity.get_node_or_null("CombatBody") as CombatBody
	if combat_body == null:
		return
	var body_rid: RID = combat_body.get_runtime_body_rid()
	if body_rid.is_valid() and not excludes.has(body_rid):
		excludes.append(body_rid)


func _create_renderer() -> void:
	_line_mesh = ImmediateMesh.new()
	_line_instance = MeshInstance3D.new()
	_line_instance.name = "CombatLineVisual"
	_line_instance.mesh = _line_mesh
	_line_instance.top_level = true
	_line_instance.layers = 1 << (GvttRenderLayers.RENDER_LAYER_GM_ONLY - 1)
	_line_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line_instance.set_meta("gvtt_runtime_only", true)
	add_child(_line_instance)
	_aim_guide = Line2D.new()
	_aim_guide.name = "CombatAimGuide"
	_aim_guide.width = 2.0
	_aim_guide.default_color = Color(0.1, 0.85, 0.95, 0.65)
	_aim_guide.z_index = 1000
	_aim_guide.set_meta("gvtt_runtime_only", true)
	add_child(_aim_guide)
	_no_blocker_material = _create_line_material(NO_BLOCKER_COLOR)
	_blocker_material = _create_line_material(BLOCKER_COLOR)
	_remainder_material = _create_line_material(REMAINDER_COLOR)


func _create_line_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _draw_result() -> void:
	if _line_mesh == null or _line_instance == null:
		return
	_line_instance.visible = true
	_line_mesh.clear_surfaces()
	var blocked: bool = bool(_last_result.get("blocked", false))
	if not blocked:
		_draw_segment(_last_origin, _last_target, _no_blocker_material)
		_draw_cross(_last_target, _no_blocker_material)
		return
	var hit_position: Vector3 = _last_result.get("position", _last_target) as Vector3
	_draw_segment(_last_origin, hit_position, _blocker_material)
	_draw_segment(hit_position, _last_target, _remainder_material)
	_draw_cross(hit_position, _blocker_material)
	_draw_cross(_last_target, _remainder_material)


func _draw_segment(from: Vector3, to: Vector3, material: Material) -> void:
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	_line_mesh.surface_add_vertex(from)
	_line_mesh.surface_add_vertex(to)
	_line_mesh.surface_end()


func _draw_cross(marker_position: Vector3, material: Material) -> void:
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	_line_mesh.surface_add_vertex(marker_position + Vector3.LEFT * MARKER_SIZE)
	_line_mesh.surface_add_vertex(marker_position + Vector3.RIGHT * MARKER_SIZE)
	_line_mesh.surface_add_vertex(marker_position + Vector3.FORWARD * MARKER_SIZE)
	_line_mesh.surface_add_vertex(marker_position + Vector3.BACK * MARKER_SIZE)
	_line_mesh.surface_end()

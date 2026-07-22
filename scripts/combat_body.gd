extends Node3D
class_name CombatBody
## CombatBody —— 独立战斗碰撞体，只负责射击线几何遮挡。

const MIN_SHAPE_SIZE: float = 0.001
const COVER_HEIGHT_THRESHOLD: float = 1.0
const COVER_HEIGHT_EPSILON: float = 0.0001
const COMBAT_BODY_GROUP: StringName = &"gvtt_combat_bodies"

@export var target_node: Node3D = null
@export var blocks_shot: bool = true
@export var provides_full_cover: bool = false
@export var local_bounds_position: Vector3 = Vector3.ZERO
@export var local_bounds_size: Vector3 = Vector3.ONE
@export var geometry_fitted: bool = false

var _runtime_body: StaticBody3D = null
var _shape_node: CollisionShape3D = null
var _shape: BoxShape3D = null


func _enter_tree() -> void:
	add_to_group(COMBAT_BODY_GROUP)


func _ready() -> void:
	if target_node == null and get_parent() is Node3D:
		target_node = get_parent() as Node3D
	set_notify_transform(true)
	_create_runtime_body()
	sync_transform_from_target()


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSFORM_CHANGED:
		return
	if _runtime_body == null or not is_instance_valid(_runtime_body):
		return
	sync_transform_from_target()


func fit_from_target_synced() -> bool:
	if target_node == null or not is_instance_valid(target_node):
		clear_geometry()
		return false
	var bounds: AABB = OcclusionGeometry.get_local_bounds(target_node)
	if not bounds.has_volume():
		clear_geometry()
		return false
	set_local_bounds(bounds)
	return true


func set_local_bounds(bounds: AABB) -> void:
	if not bounds.has_volume():
		clear_geometry()
		return
	local_bounds_position = bounds.position
	local_bounds_size = bounds.size
	geometry_fitted = true
	sync_transform_from_target()


func clear_geometry() -> void:
	geometry_fitted = false
	_set_runtime_enabled(false)


func set_blocks_shot(value: bool) -> void:
	blocks_shot = value
	_set_runtime_enabled(blocks_shot and geometry_fitted)


func set_provides_full_cover(value: bool) -> void:
	provides_full_cover = value
	sync_transform_from_target()


func sync_transform_from_target() -> void:
	if not geometry_fitted or target_node == null or not is_instance_valid(target_node):
		_set_runtime_enabled(false)
		return
	if _runtime_body == null or _shape_node == null or _shape == null:
		return
	var root_basis: Basis = target_node.global_transform.basis
	var rotation_basis: Basis = root_basis.orthonormalized()
	var root_scale: Vector3 = root_basis.get_scale().abs()
	var bounds: AABB = AABB(local_bounds_position, local_bounds_size)
	var center_world_offset: Vector3 = root_basis * bounds.get_center()
	var center_body_offset: Vector3 = rotation_basis.inverse() * center_world_offset
	var actual_height: float = maxf(
		local_bounds_size.y * root_scale.y,
		MIN_SHAPE_SIZE
	)
	_runtime_body.global_transform = Transform3D(
		rotation_basis,
		target_node.global_position
	)
	_runtime_body.scale = Vector3.ONE
	_shape_node.position = center_body_offset
	_shape_node.scale = Vector3.ONE
	_shape.size = Vector3(
		maxf(local_bounds_size.x * root_scale.x, MIN_SHAPE_SIZE),
		actual_height,
		maxf(local_bounds_size.z * root_scale.z, MIN_SHAPE_SIZE)
	)
	_set_runtime_enabled(blocks_shot)


func get_local_bounds() -> AABB:
	if not geometry_fitted:
		return AABB()
	return AABB(local_bounds_position, local_bounds_size)


func get_entity_root() -> Node3D:
	return target_node


func get_world_visual_height() -> float:
	if not geometry_fitted or target_node == null or not is_instance_valid(target_node):
		return 0.0
	var root_scale: Vector3 = target_node.global_transform.basis.get_scale().abs()
	return local_bounds_size.y * root_scale.y


func meets_automatic_cover_height() -> bool:
	return get_world_visual_height() > COVER_HEIGHT_THRESHOLD + COVER_HEIGHT_EPSILON


func intersect_ground_segment(from: Vector3, to: Vector3) -> Dictionary:
	if (
		not blocks_shot
		or not provides_full_cover
		or not geometry_fitted
		or target_node == null
		or not is_instance_valid(target_node)
	):
		return {}
	var inverse: Transform3D = target_node.global_transform.affine_inverse()
	var local_from_3d: Vector3 = inverse * from
	var local_to_3d: Vector3 = inverse * to
	var local_from: Vector2 = Vector2(local_from_3d.x, local_from_3d.z)
	var local_to: Vector2 = Vector2(local_to_3d.x, local_to_3d.z)
	var local_delta: Vector2 = local_to - local_from
	if local_delta.length_squared() < MIN_SHAPE_SIZE * MIN_SHAPE_SIZE:
		return {}
	var bounds_min: Vector2 = Vector2(local_bounds_position.x, local_bounds_position.z)
	var bounds_max: Vector2 = bounds_min + Vector2(local_bounds_size.x, local_bounds_size.z)
	var x_range: Vector2 = _clip_segment_axis(
		local_from.x, local_delta.x, bounds_min.x, bounds_max.x
	)
	var z_range: Vector2 = _clip_segment_axis(
		local_from.y, local_delta.y, bounds_min.y, bounds_max.y
	)
	var entry_fraction: float = maxf(x_range.x, z_range.x)
	var exit_fraction: float = minf(x_range.y, z_range.y)
	if entry_fraction > exit_fraction or exit_fraction < 0.0 or entry_fraction > 1.0:
		return {}
	entry_fraction = clampf(entry_fraction, 0.0, 1.0)
	var local_normal: Vector3 = Vector3.ZERO
	if x_range.x > z_range.x:
		local_normal = Vector3(-signf(local_delta.x), 0.0, 0.0)
	elif z_range.x > x_range.x:
		local_normal = Vector3(0.0, 0.0, -signf(local_delta.y))
	var world_normal: Vector3 = (
		target_node.global_transform.basis.orthonormalized() * local_normal
	)
	return {
		"fraction": entry_fraction,
		"position": from.lerp(to, entry_fraction),
		"normal": world_normal.normalized(),
	}


func get_runtime_body() -> StaticBody3D:
	return _runtime_body


func get_runtime_shape() -> BoxShape3D:
	return _shape


func get_runtime_body_rid() -> RID:
	if _runtime_body == null or not is_instance_valid(_runtime_body):
		return RID()
	return _runtime_body.get_rid()


func _create_runtime_body() -> void:
	_runtime_body = StaticBody3D.new()
	_runtime_body.name = "CombatPhysicsBody"
	_runtime_body.set_meta("gvtt_runtime_only", true)
	_runtime_body.top_level = true
	_runtime_body.input_ray_pickable = false
	_runtime_body.collision_layer = 0
	_runtime_body.collision_mask = 0
	add_child(_runtime_body)
	_shape = BoxShape3D.new()
	_shape_node = CollisionShape3D.new()
	_shape_node.name = "CombatCollisionShape"
	_shape_node.set_meta("gvtt_runtime_only", true)
	_shape_node.shape = _shape
	_runtime_body.add_child(_shape_node)


func _set_runtime_enabled(enabled: bool) -> void:
	if _runtime_body == null or not is_instance_valid(_runtime_body):
		return
	_runtime_body.collision_layer = (
		GvttRenderLayers.COMBAT_PHYSICS_MASK if enabled else 0
	)


static func _clip_segment_axis(
		start: float,
		delta: float,
		minimum: float,
		maximum: float
) -> Vector2:
	if absf(delta) < MIN_SHAPE_SIZE:
		if start < minimum or start > maximum:
			return Vector2(1.0, -1.0)
		return Vector2(0.0, 1.0)
	var first: float = (minimum - start) / delta
	var second: float = (maximum - start) / delta
	return Vector2(minf(first, second), maxf(first, second))

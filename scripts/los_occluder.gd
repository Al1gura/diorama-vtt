class_name LOSOccluder
extends Node3D

signal segments_changed(occluder: LOSOccluder)

@export var target_node: Node3D = null
@export var blocks_los: bool = true
@export var geometry_fitted: bool = false
@export var local_bounds_position: Vector3 = Vector3.ZERO
@export var local_bounds_size: Vector3 = Vector3.ZERO

var _world_segments: Array[PackedVector2Array] = []
var _wall_properties: WallProperties = null


func _ready() -> void:
	if target_node == null and get_parent() is Node3D:
		target_node = get_parent() as Node3D
	set_notify_transform(true)
	_connect_wall_properties()
	if geometry_fitted:
		sync_transform_from_target()
	else:
		fit_from_target_synced()


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSFORM_CHANGED or not geometry_fitted:
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
	local_bounds_position = bounds.position
	local_bounds_size = bounds.size
	geometry_fitted = true
	sync_transform_from_target()
	return true


func clear_geometry() -> void:
	geometry_fitted = false
	_world_segments.clear()
	segments_changed.emit(self)


func set_blocks_los(value: bool) -> void:
	if blocks_los == value:
		return
	blocks_los = value
	sync_transform_from_target()


func sync_transform_from_target() -> void:
	_world_segments.clear()
	if (
		not geometry_fitted
		or not blocks_los
		or target_node == null
		or not is_instance_valid(target_node)
	):
		segments_changed.emit(self)
		return
	var bounds: AABB = AABB(local_bounds_position, local_bounds_size)
	var local_footprint: PackedVector2Array = OcclusionGeometry.get_local_ground_footprint(bounds)
	if local_footprint.size() < 3:
		segments_changed.emit(self)
		return
	var world_footprint: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in local_footprint:
		var world_point: Vector3 = target_node.global_transform * Vector3(point.x, 0.0, point.y)
		world_footprint.append(Vector2(world_point.x, world_point.z))
	for index: int in range(world_footprint.size()):
		var next_index: int = (index + 1) % world_footprint.size()
		_world_segments.append(PackedVector2Array([
			world_footprint[index], world_footprint[next_index]
		]))
	segments_changed.emit(self)


func get_world_segments() -> Array[PackedVector2Array]:
	var output: Array[PackedVector2Array] = []
	for segment: PackedVector2Array in _world_segments:
		output.append(segment.duplicate())
	return output


func get_local_bounds() -> AABB:
	return AABB(local_bounds_position, local_bounds_size)


func _connect_wall_properties() -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	_wall_properties = target_node.get_node_or_null("WallProperties") as WallProperties
	if _wall_properties == null:
		return
	blocks_los = _wall_properties.get_effective_blocks_los()
	if not _wall_properties.los_blocking_changed.is_connected(_on_wall_los_blocking_changed):
		_wall_properties.los_blocking_changed.connect(_on_wall_los_blocking_changed)


func _on_wall_los_blocking_changed(value: bool) -> void:
	set_blocks_los(value)

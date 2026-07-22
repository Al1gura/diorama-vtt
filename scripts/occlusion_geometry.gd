extends RefCounted
class_name OcclusionGeometry
## OcclusionGeometry —— 战斗与 LOS 共用的只读源几何。
##
## 这里只计算物件根局部边界，不持有物理体，也不判断挡枪或挡视线。


static func get_local_bounds(root: Node3D) -> AABB:
	if root == null or not is_instance_valid(root):
		return AABB()
	if root.is_inside_tree():
		root.force_update_transform()
	var root_inverse: Transform3D = root.global_transform.affine_inverse()
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current.has_meta("gvtt_runtime_only"):
			continue
		if current is GeometryInstance3D:
			var geometry: GeometryInstance3D = current as GeometryInstance3D
			var geometry_bounds: AABB = geometry.get_aabb()
			for corner: Vector3 in _aabb_corners(geometry_bounds):
				var root_corner: Vector3 = root_inverse * (geometry.global_transform * corner)
				if not has_bounds:
					bounds = AABB(root_corner, Vector3.ZERO)
					has_bounds = true
				else:
					bounds = bounds.expand(root_corner)
		for child: Node in current.get_children():
			pending.append(child)
	return bounds


static func get_local_ground_footprint(bounds: AABB) -> PackedVector2Array:
	if not bounds.has_volume():
		return PackedVector2Array()
	return PackedVector2Array([
		Vector2(bounds.position.x, bounds.position.z),
		Vector2(bounds.end.x, bounds.position.z),
		Vector2(bounds.end.x, bounds.end.z),
		Vector2(bounds.position.x, bounds.end.z),
	])


static func _aabb_corners(bounds: AABB) -> Array[Vector3]:
	var corner_origin: Vector3 = bounds.position
	var size: Vector3 = bounds.size
	return [
		corner_origin,
		corner_origin + Vector3(size.x, 0.0, 0.0),
		corner_origin + Vector3(0.0, size.y, 0.0),
		corner_origin + Vector3(0.0, 0.0, size.z),
		corner_origin + Vector3(size.x, size.y, 0.0),
		corner_origin + Vector3(size.x, 0.0, size.z),
		corner_origin + Vector3(0.0, size.y, size.z),
		corner_origin + size,
	]

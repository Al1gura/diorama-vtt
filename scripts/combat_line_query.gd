extends RefCounted
class_name CombatLineQuery
## CombatLineQuery —— 按战斗物理层执行单条 3D 射线查询。


static func cast(
		world: World3D,
		from: Vector3,
		to: Vector3,
		exclude: Array[RID] = []
) -> Dictionary:
	if world == null or from.is_equal_approx(to):
		return _empty_result(to)
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from,
		to,
		GvttRenderLayers.COMBAT_PHYSICS_MASK,
		exclude
	)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var hit: Dictionary = world.direct_space_state.intersect_ray(params)
	var physics_result: Dictionary = _result_from_physics_hit(hit, to)
	var cover_result: Dictionary = _cast_automatic_cover_footprints(
		world, from, to, exclude
	)
	if physics_result.is_empty():
		return cover_result if not cover_result.is_empty() else _empty_result(to)
	if cover_result.is_empty():
		return physics_result
	var physics_distance: float = from.distance_squared_to(
		physics_result.get("position", to) as Vector3
	)
	var cover_distance: float = from.distance_squared_to(
		cover_result.get("position", to) as Vector3
	)
	return cover_result if cover_distance < physics_distance else physics_result


static func _result_from_physics_hit(hit: Dictionary, to: Vector3) -> Dictionary:
	if hit.is_empty():
		return {}
	var collider: Object = hit.get("collider", null)
	var combat_body: CombatBody = _find_combat_body(collider)
	var entity_root: Node3D = null
	if combat_body != null:
		entity_root = combat_body.get_entity_root()
	return {
		"blocked": true,
		"position": hit.get("position", to),
		"normal": hit.get("normal", Vector3.ZERO),
		"collider": collider,
		"combat_body": combat_body,
		"entity": entity_root,
		"shape": hit.get("shape", -1),
		"rid": hit.get("rid", RID()),
		"abstract_cover": false,
	}


static func _cast_automatic_cover_footprints(
		world: World3D,
		from: Vector3,
		to: Vector3,
		exclude: Array[RID]
) -> Dictionary:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return {}
	var nearest_result: Dictionary = {}
	var nearest_fraction: float = INF
	for candidate: Node in scene_tree.get_nodes_in_group(CombatBody.COMBAT_BODY_GROUP):
		var combat_body: CombatBody = candidate as CombatBody
		if combat_body == null or combat_body.get_world_3d() != world:
			continue
		var body_rid: RID = combat_body.get_runtime_body_rid()
		if body_rid.is_valid() and exclude.has(body_rid):
			continue
		var ground_hit: Dictionary = combat_body.intersect_ground_segment(from, to)
		if ground_hit.is_empty():
			continue
		var fraction: float = float(ground_hit.get("fraction", INF))
		if fraction >= nearest_fraction:
			continue
		nearest_fraction = fraction
		nearest_result = {
			"blocked": true,
			"position": ground_hit.get("position", to),
			"normal": ground_hit.get("normal", Vector3.ZERO),
			"collider": combat_body.get_runtime_body(),
			"combat_body": combat_body,
			"entity": combat_body.get_entity_root(),
			"shape": 0,
			"rid": body_rid,
			"abstract_cover": true,
		}
	return nearest_result


static func is_blocked(
		world: World3D,
		from: Vector3,
		to: Vector3,
		exclude: Array[RID] = []
) -> bool:
	return bool(cast(world, from, to, exclude).get("blocked", false))


static func _find_combat_body(collider: Object) -> CombatBody:
	if not (collider is Node):
		return null
	var current: Node = collider as Node
	while current != null:
		if current is CombatBody:
			return current as CombatBody
		current = current.get_parent()
	return null


static func _empty_result(end_position: Vector3) -> Dictionary:
	return {
		"blocked": false,
		"position": end_position,
		"normal": Vector3.ZERO,
		"collider": null,
		"combat_body": null,
		"entity": null,
		"shape": -1,
		"rid": RID(),
		"abstract_cover": false,
	}

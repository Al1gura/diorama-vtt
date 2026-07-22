extends RefCounted
class_name MovementRuleProvider
## Replaceable ruleset boundary for movement distance and traversal costs.


func get_ruleset_id() -> StringName:
	return &"none"


func get_movement_budget_meters(_token_root: Node3D) -> float:
	return 0.0


func get_traversal_cost_multiplier(_traversal_tag: StringName) -> float:
	return 1.0


func calculate_path_cost(path: PackedVector3Array, segment_tags: Array[StringName]) -> float:
	var total: float = 0.0
	for index: int in range(1, path.size()):
		var tag: StringName = &"walkable"
		if index - 1 < segment_tags.size():
			tag = segment_tags[index - 1]
		total += path[index - 1].distance_to(path[index]) * get_traversal_cost_multiplier(tag)
	return total


func truncate_path(
		path: PackedVector3Array,
		segment_tags: Array[StringName],
		budget_meters: float
) -> Dictionary:
	var reachable: PackedVector3Array = PackedVector3Array()
	if path.is_empty() or budget_meters <= 0.0:
		return {"path": reachable, "cost": 0.0, "truncated": not path.is_empty()}
	reachable.append(path[0])
	var spent: float = 0.0
	for index: int in range(1, path.size()):
		var tag: StringName = &"walkable"
		if index - 1 < segment_tags.size():
			tag = segment_tags[index - 1]
		var multiplier: float = maxf(get_traversal_cost_multiplier(tag), 0.001)
		var segment_length: float = path[index - 1].distance_to(path[index])
		var segment_cost: float = segment_length * multiplier
		if spent + segment_cost <= budget_meters + 0.0001:
			reachable.append(path[index])
			spent += segment_cost
			continue
		var remaining_cost: float = maxf(budget_meters - spent, 0.0)
		var reachable_distance: float = remaining_cost / multiplier
		if segment_length > 0.0001 and reachable_distance > 0.0001:
			var weight: float = clampf(reachable_distance / segment_length, 0.0, 1.0)
			reachable.append(path[index - 1].lerp(path[index], weight))
			spent += reachable_distance * multiplier
		return {"path": reachable, "cost": spent, "truncated": true}
	return {"path": reachable, "cost": spent, "truncated": false}

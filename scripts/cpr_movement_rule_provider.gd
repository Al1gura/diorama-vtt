extends MovementRuleProvider
class_name CprMovementRuleProvider
## Cyberpunk RED movement adapter.
## One Move Action covers MOVE x 2 meters; climb, jump and swim cost double.


func get_ruleset_id() -> StringName:
	return &"cpr"


func get_movement_budget_meters(token_root: Node3D) -> float:
	if token_root == null or not is_instance_valid(token_root):
		return 0.0
	var cpr_properties: Node = token_root.get_node_or_null("CprTokenProperties")
	if cpr_properties == null:
		return 0.0
	return maxf(float(cpr_properties.get("move_stat")) * 2.0, 0.0)


func get_traversal_cost_multiplier(traversal_tag: StringName) -> float:
	if traversal_tag in [&"climb", &"jump", &"swim", &"difficult"]:
		return 2.0
	return 1.0

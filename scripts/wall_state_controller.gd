extends Node
class_name WallStateController

signal wall_state_changed(root: Node3D, state: WallProperties.WallState)


func sync_wall(root: Node3D, show_destroyed_visual: bool = false) -> bool:
	var properties: WallProperties = _get_wall_properties(root)
	if properties == null:
		return false
	var destroyed: bool = properties.wall_state == WallProperties.WallState.DESTROYED
	root.visible = show_destroyed_visual or not destroyed
	var combat_body: CombatBody = root.get_node_or_null("CombatBody") as CombatBody
	if combat_body != null:
		combat_body.set_blocks_shot(properties.get_effective_blocks_shot())
	var los_occluder: LOSOccluder = root.get_node_or_null("LOSOccluder") as LOSOccluder
	if los_occluder != null:
		los_occluder.set_blocks_los(properties.get_effective_blocks_los())
	return true


func destroy_wall(root: Node3D) -> bool:
	var properties: WallProperties = _get_wall_properties(root)
	if (
			properties == null
			or not properties.destructible
			or properties.wall_state == WallProperties.WallState.DESTROYED
	):
		return false
	properties.durability_current = 0
	properties.set_wall_state(WallProperties.WallState.DESTROYED)
	sync_wall(root)
	wall_state_changed.emit(root, properties.wall_state)
	return true


func repair_wall(root: Node3D) -> bool:
	var properties: WallProperties = _get_wall_properties(root)
	if properties == null or properties.wall_state != WallProperties.WallState.DESTROYED:
		return false
	properties.durability_current = maxi(properties.durability_max, 0)
	properties.set_wall_state(WallProperties.WallState.INTACT)
	sync_wall(root)
	wall_state_changed.emit(root, properties.wall_state)
	return true


func _get_wall_properties(root: Node3D) -> WallProperties:
	if root == null or not is_instance_valid(root):
		return null
	return root.get_node_or_null("WallProperties") as WallProperties

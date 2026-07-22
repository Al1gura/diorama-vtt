extends Node
class_name TraversalProperties
## Optional traversal metadata for any placed object.
##
## Geometry stays generic. A ruleset provider decides what each tag costs.

enum TraversalMode { WALKABLE, BLOCKED, DIFFICULT, CLIMB, JUMP, SWIM }

@export var traversal_mode: TraversalMode = TraversalMode.WALKABLE
@export var link_start: Vector3 = Vector3.ZERO
@export var link_end: Vector3 = Vector3.ZERO
@export var link_bidirectional: bool = true


func get_traversal_tag() -> StringName:
	match traversal_mode:
		TraversalMode.BLOCKED:
			return &"blocked"
		TraversalMode.DIFFICULT:
			return &"difficult"
		TraversalMode.CLIMB:
			return &"climb"
		TraversalMode.JUMP:
			return &"jump"
		TraversalMode.SWIM:
			return &"swim"
		_:
			return &"walkable"


func is_walkable_surface() -> bool:
	return traversal_mode in [
		TraversalMode.WALKABLE,
		TraversalMode.DIFFICULT,
		TraversalMode.SWIM,
	]


func creates_navigation_link() -> bool:
	return traversal_mode in [TraversalMode.CLIMB, TraversalMode.JUMP]


func configure_for_entity_type(entity_type: EntityProperties.EntityType) -> void:
	match entity_type:
		EntityProperties.EntityType.TERRAIN:
			traversal_mode = TraversalMode.WALKABLE
		EntityProperties.EntityType.TOKEN, EntityProperties.EntityType.LIGHT:
			traversal_mode = TraversalMode.WALKABLE
		_:
			traversal_mode = TraversalMode.BLOCKED

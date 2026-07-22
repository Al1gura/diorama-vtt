extends Node
class_name WallProperties
## WallProperties —— 墙体专属属性。
##
## 墙体的数值算法可以像生命值,但语义叫耐久,避免和 Token 规则混在一起。

enum WallState { INTACT, DAMAGED, DESTROYED }
enum CoverLevel { NONE, FULL }

signal los_blocking_changed(value: bool)
signal shot_blocking_changed(value: bool)
signal wall_state_changed(value: WallState)

@export var wall_state: WallState = WallState.INTACT
@export var destructible: bool = false
@export var durability_max: int = 20
@export var durability_current: int = 20
@export var blocks_los: bool = true
@export var blocks_shot: bool = true
@export var cover_level: CoverLevel = CoverLevel.FULL


func configure_from_legacy(props: EntityProperties) -> void:
	if props == null:
		return
	destructible = props.destructible
	durability_max = props.max_hp
	durability_current = props.max_hp
	blocks_los = props.los_occluder
	blocks_shot = props.cover_level == EntityProperties.CoverLevel.FULL
	cover_level = CoverLevel.FULL if props.cover_level == EntityProperties.CoverLevel.FULL else CoverLevel.NONE


func set_blocks_los(value: bool) -> void:
	if blocks_los == value:
		return
	blocks_los = value
	los_blocking_changed.emit(get_effective_blocks_los())


func set_blocks_shot(value: bool) -> void:
	if blocks_shot == value:
		return
	blocks_shot = value
	shot_blocking_changed.emit(get_effective_blocks_shot())


func set_wall_state(value: WallState) -> void:
	if wall_state == value:
		return
	wall_state = value
	wall_state_changed.emit(wall_state)
	los_blocking_changed.emit(get_effective_blocks_los())
	shot_blocking_changed.emit(get_effective_blocks_shot())


func get_effective_blocks_los() -> bool:
	return wall_state != WallState.DESTROYED and blocks_los


func get_effective_blocks_shot() -> bool:
	return wall_state != WallState.DESTROYED and blocks_shot

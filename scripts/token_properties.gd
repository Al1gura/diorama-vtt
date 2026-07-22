extends Node
class_name TokenProperties
## TokenProperties —— Token 专属属性。
##
## P2 只保存通用棋子几何与操作能力。MOVE 等规则字段由规则模组组件保存。

@export var can_move: bool = true
@export var footprint_cells: Vector2i = Vector2i(1, 1)
@export_range(0.1, 5.0, 0.05) var collision_radius: float = 0.45
@export_range(0.2, 10.0, 0.1) var collision_height: float = 1.8
@export var can_show_aim_line: bool = true
@export var marker_color: Color = Color(0.2, 0.7, 1.0, 1.0)

## Kept only so old scenes deserialize cleanly. Tactical movement ignores grid snapping.
@export_storage var snap_to_grid: bool = false

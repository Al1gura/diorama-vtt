extends Node
class_name InteractableProperties
## InteractableProperties —— 交互物体专属属性。
##
## P2 只提供 GM 手动触发入口,不做检定、钥匙、规则效果或脚本链。

enum InteractionState { IDLE, ACTIVE, DISABLED }
enum TriggerMode { MANUAL, AUTOMATIC }

@export var enabled: bool = true
@export var interaction_label: String = "触发"
@export var interaction_state: InteractionState = InteractionState.IDLE
@export var trigger_mode: TriggerMode = TriggerMode.MANUAL

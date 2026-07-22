class_name ActRef
extends Resource

## GM 可反复查看和使用的内容资料夹。数组位置只用于界面列出，不表示剧情顺序。
## 幕不拥有当前、完成、解锁或使用次数等运行进度。

@export var act_id: String = ""
@export var display_name: String = ""
@export var gm_notes: String = ""
@export var items: Array[ActItemRef] = []


func find_item(item_id_value: String) -> ActItemRef:
	for item: ActItemRef in items:
		if item.item_id == item_id_value:
			return item
	return null


func to_json_dict() -> Dictionary:
	var item_entries: Array[Dictionary] = []
	for item: ActItemRef in items:
		item_entries.append(item.to_json_dict())
	return {
		"act_id": act_id,
		"display_name": display_name,
		"gm_notes": gm_notes,
		"items": item_entries,
	}

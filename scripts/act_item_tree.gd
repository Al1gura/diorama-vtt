class_name ActItemTree
extends Tree

signal reorder_requested(item_id: String, target_index: int)

var _act_id: String = ""
var _reorder_enabled: bool = false


func configure_context(act_id: String, reorder_enabled: bool) -> void:
	_act_id = act_id
	_reorder_enabled = reorder_enabled


func _get_drag_data(at_position: Vector2) -> Variant:
	if not _reorder_enabled:
		return null
	var item: TreeItem = get_item_at_position(at_position)
	if item == null:
		return null
	var metadata_value: Variant = item.get_metadata(0)
	if not (metadata_value is Dictionary):
		return null
	var metadata: Dictionary = metadata_value as Dictionary
	var item_id: String = String(metadata.get("item_id", ""))
	var source_index: int = int(metadata.get("source_index", -1))
	if item_id == "" or source_index < 0:
		return null
	var preview: Label = Label.new()
	preview.text = item.get_text(0)
	preview.add_theme_color_override("font_color", Color.WHITE)
	set_drag_preview(preview)
	return {
		"type": "gvtt_act_item",
		"act_id": _act_id,
		"item_id": item_id,
		"source_index": source_index,
	}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _reorder_enabled or not (data is Dictionary):
		return false
	var drag_data: Dictionary = data as Dictionary
	if String(drag_data.get("type", "")) != "gvtt_act_item":
		return false
	if String(drag_data.get("act_id", "")) != _act_id:
		return false
	var target: TreeItem = get_item_at_position(at_position)
	if target == null or not (target.get_metadata(0) is Dictionary):
		return false
	drop_mode_flags = Tree.DROP_MODE_INBETWEEN
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var drag_data: Dictionary = data as Dictionary
	var target: TreeItem = get_item_at_position(at_position)
	var target_metadata: Dictionary = target.get_metadata(0) as Dictionary
	var source_index: int = int(drag_data.get("source_index", -1))
	var target_index: int = int(target_metadata.get("source_index", -1))
	if source_index < 0 or target_index < 0:
		return
	var drop_section: int = get_drop_section_at_position(at_position)
	var insertion_boundary: int = target_index + (1 if drop_section > 0 else 0)
	if source_index < insertion_boundary:
		insertion_boundary -= 1
	var final_index: int = maxi(insertion_boundary, 0)
	reorder_requested.emit(String(drag_data.get("item_id", "")), final_index)

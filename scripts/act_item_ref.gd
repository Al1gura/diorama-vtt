class_name ActItemRef
extends Resource

enum ItemType {
	MEDIA,
	TEXT,
	LOCATION,
}

const TYPE_MEDIA: String = "media"
const TYPE_TEXT: String = "text"
const TYPE_LOCATION: String = "location"

@export var item_id: String = ""
@export var item_type: ItemType = ItemType.MEDIA
@export var target_id: String = ""
@export var display_name: String = ""
@export var text_content: String = ""
@export var gm_notes: String = ""


func to_json_dict() -> Dictionary:
	return {
		"item_id": item_id,
		"item_type": item_type_to_string(item_type),
		"target_id": target_id,
		"display_name": display_name,
		"text_content": text_content,
		"gm_notes": gm_notes,
	}


static func item_type_from_string(value: String) -> int:
	match value:
		TYPE_MEDIA:
			return ItemType.MEDIA
		TYPE_TEXT:
			return ItemType.TEXT
		TYPE_LOCATION:
			return ItemType.LOCATION
	return -1


static func item_type_to_string(value: ItemType) -> String:
	match value:
		ItemType.MEDIA:
			return TYPE_MEDIA
		ItemType.TEXT:
			return TYPE_TEXT
		ItemType.LOCATION:
			return TYPE_LOCATION
	return ""

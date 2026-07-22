class_name ExternalContentRef
extends Resource

enum ContentType {
	IMAGE,
	VIDEO,
}

enum SourceKind {
	EXTERNAL_FILE,
	MODULE_RELATIVE,
}

const TYPE_IMAGE: String = "image"
const TYPE_VIDEO: String = "video"
const SOURCE_EXTERNAL_FILE: String = "external_file"
const SOURCE_MODULE_RELATIVE: String = "module_relative"

@export var content_id: String = ""
@export var content_type: ContentType = ContentType.IMAGE
@export var display_name: String = ""
@export var source_kind: SourceKind = SourceKind.EXTERNAL_FILE
@export var source_path: String = ""
@export var metadata: Dictionary = {}

var resolved_path: String = ""
var available: bool = false


func to_json_dict() -> Dictionary:
	return {
		"content_id": content_id,
		"content_type": content_type_to_string(content_type),
		"display_name": display_name,
		"source_kind": source_kind_to_string(source_kind),
		"source_path": source_path,
		"metadata": metadata,
	}


static func content_type_from_string(value: String) -> int:
	match value:
		TYPE_IMAGE:
			return ContentType.IMAGE
		TYPE_VIDEO:
			return ContentType.VIDEO
	return -1


static func content_type_to_string(value: ContentType) -> String:
	match value:
		ContentType.IMAGE:
			return TYPE_IMAGE
		ContentType.VIDEO:
			return TYPE_VIDEO
	return ""


static func source_kind_from_string(value: String) -> int:
	match value:
		SOURCE_EXTERNAL_FILE:
			return SourceKind.EXTERNAL_FILE
		SOURCE_MODULE_RELATIVE:
			return SourceKind.MODULE_RELATIVE
	return -1


static func source_kind_to_string(value: SourceKind) -> String:
	match value:
		SourceKind.EXTERNAL_FILE:
			return SOURCE_EXTERNAL_FILE
		SourceKind.MODULE_RELATIVE:
			return SOURCE_MODULE_RELATIVE
	return ""

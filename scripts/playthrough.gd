class_name Playthrough
extends Resource
## 一次带团会话的强类型内存真值。磁盘格式固定为 session.json。

const FORMAT: String = "gvtt_playthrough"
const SCHEMA_VERSION: int = 1

@export var schema_version: int = SCHEMA_VERSION
@export var session_id: String = ""
@export var module_id: String = ""
@export var session_name: String = ""
@export var current_location_id: String = ""
@export var location_states: Dictionary = {}
@export var notes: String = ""


func copy_data() -> Playthrough:
	var copy: Playthrough = Playthrough.new()
	copy.schema_version = schema_version
	copy.session_id = session_id
	copy.module_id = module_id
	copy.session_name = session_name
	copy.current_location_id = current_location_id
	copy.location_states = location_states.duplicate(true)
	copy.notes = notes
	return copy


func to_json_dict() -> Dictionary:
	var state_entries: Array[Dictionary] = []
	var location_ids: Array[String] = []
	for location_id_value: Variant in location_states.keys():
		location_ids.append(String(location_id_value))
	location_ids.sort()
	for location_id_value: String in location_ids:
		state_entries.append({
			"location_id": location_id_value,
			"state_relpath": String(location_states.get(location_id_value, "")),
		})
	return {
		"format": FORMAT,
		"schema_version": schema_version,
		"session_id": session_id,
		"module_id": module_id,
		"session_name": session_name,
		"current_location_id": current_location_id,
		"location_states": state_entries,
		"notes": notes,
	}

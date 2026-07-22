class_name ModuleManifest
extends Resource
## ModuleManifest —— 一个模组(一场跑团)的地点清单 + 叙事占位
##
## 设计依据:docs/multi_scene_draft.md 第 6 节。
## 一个"模组"=一场跑团(下午两点到晚上九点那种一局)装的所有地点集合。
## GM 备团时搭好各地点(各一个 .scn),在此清单里登记它们 + 指开场地点。
## 与 Playthrough(带团存档)分开存文件——底本可复用重跑,带团存档是一次性快照。
##
## 叙事文本(notes)先留字段不做 UI(决策5):Resource 加 String 字段近零成本,
## 将来加 UI 只是挂 TextEdit 绑它;不留则将来续兼容旧存档难。

const FORMAT: String = "gvtt_module_manifest"
const SCHEMA_VERSION: int = 2

## 当前 manifest.json 的结构版本。
@export var schema_version: int = SCHEMA_VERSION

## 稳定模组标识。目录名可变，这个值不可变。
@export var module_id: String = ""

## 模组名(给 GM 在"打开模组"界面看)。
@export var module_name: String = ""

## 这个模组装的地点清单。每个 LocationRef 指向一个底本场景文件路径。
@export var locations: Array[LocationRef] = []

## 开场默认进哪个地点(填 location_ref.display_name)。
@export var start_location: String = ""

## 开场默认进哪个地点(填 location_ref.location_id)。这是 P3.1 后的真值。
@export var start_location_id: String = ""

## 叙事占位:模组级的 GM 笔记(背景/剧情概要/线索)。先不接 UI。
@export var notes: String = ""

## Selects a replaceable rules adapter. P2 ships with the Cyberpunk RED adapter first.
@export var ruleset_id: StringName = &"cpr"

## 外部图片/视频等内容的引用清单。P3.1 只定义和校验，不实现播放器。
@export var external_contents: Array[ExternalContentRef] = []

## GM 按叙事“幕”整理的逻辑内容集合。幕只保存稳定标识引用，不保存媒体字节。
@export var acts: Array[ActRef] = []


func add_location(loc: LocationRef) -> void:
	locations.append(loc)


func find_location(display_name_value: String) -> LocationRef:
	for l: LocationRef in locations:
		if l.display_name == display_name_value:
			return l
	return null


func find_location_by_id(location_id_value: String) -> LocationRef:
	for location: LocationRef in locations:
		if location.location_id == location_id_value:
			return location
	return null


func find_act_by_id(act_id_value: String) -> ActRef:
	for act: ActRef in acts:
		if act.act_id == act_id_value:
			return act
	return null


func sync_legacy_start_location() -> void:
	start_location = ""
	var location: LocationRef = find_location_by_id(start_location_id)
	if location != null:
		start_location = location.display_name


func to_json_dict() -> Dictionary:
	var location_entries: Array[Dictionary] = []
	for location: LocationRef in locations:
		location_entries.append(location.to_json_dict())
	var external_entries: Array[Dictionary] = []
	for content: ExternalContentRef in external_contents:
		external_entries.append(content.to_json_dict())
	var act_entries: Array[Dictionary] = []
	for act: ActRef in acts:
		act_entries.append(act.to_json_dict())
	return {
		"format": FORMAT,
		"schema_version": schema_version,
		"module_id": module_id,
		"module_name": module_name,
		"start_location_id": start_location_id,
		"ruleset_id": String(ruleset_id),
		"notes": notes,
		"locations": location_entries,
		"external_contents": external_entries,
		"acts": act_entries,
	}

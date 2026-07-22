class_name LocationRef
extends Resource
## LocationRef —— 模组清单里一个"地点"的引用(不是场景本体)
##
## 一个"地点"=一个搭好的舞台场景文件,物理上一个 .scn/.tscn。
## LocationRef 只是清单里的一行:显示名 + 指向底本场景文件的路径。
## 设计依据:docs/multi_scene_draft.md 第 1/6 节。

## 给 GM 看的名字("镇广场"、"地牢一层")。
@export var display_name: String = ""

## 稳定地点标识。显示名和文件名可变，这个值不可变。
@export var location_id: String = ""

## 这个地点底本场景文件的模组内相对路径，例如 _canonical/<location_id>.scn。
@export var canonical_relpath: String = ""

## 这个地点底本场景文件的 user:// 路径。运行时计算，不写入 manifest.json。
@export var canonical_path: String = ""

## 场景文件是否真实存在。缺失引用保留在清单里，由 UI 提示 GM 修复。
var available: bool = false


func to_json_dict() -> Dictionary:
	return {
		"location_id": location_id,
		"display_name": display_name,
		"canonical_relpath": canonical_relpath,
	}

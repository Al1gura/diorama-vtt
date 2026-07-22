## Gvtt 素材库管理器（运行时导入 + 扫描）
##
## 职责：用户在左栏点"导入"选电脑上的文件后，复制进 user://library/<栏位名>/
## 存进素材库；导入时把 GLB 转成持久 PackedScene 缓存；扫描、加载和删除素材。
##
## 为什么存 user:// 不存 res://assets/：
##   离线文档 gdd_0372 第 60-63 行：res:// 在编辑器里跑能读写，但导出成 exe 后
##   变只读。本项目要打包成单 exe 给 GM 用（design.md 第 34 行），GM 导入的新
##   素材必须存 user://（gdd_0372 第 69 行"always writable"），否则打包后写不进去。
##
## 运行时加载 3D 模型依据：gdd_0187 第 192-220 行，导出后的项目用
##   GLTFDocument + GLTFState 把自包含 .glb 加载成场景节点（非编辑器专用）。
##   4.3 起 FBXDocument 也能运行时加载 FBX（gdd_0187 第 200-204 行）。
## 图片运行时加载依据：gdd_0187 第 81 行 Image.load_from_file 自动认格式。
##
## 文件操作 API 依据：gdd_1241 DirAccess
##   make_dir_recursive_absolute（第 115 行，建嵌套目录）
##   copy_absolute（第 86 行，复制文件）
##   dir_exists_absolute（第 91 行）
##   open（第 116 行）+ list_dir_begin/get_next/current_is_dir（扫描）

class_name LibraryManager
extends RefCounted

## 素材库根目录（user:// 下，打包后可写）。各栏位在此下分子目录。
const LIBRARY_ROOT: String = "user://library/"

## 外部 GLB 的原生场景缓存。Godot 编辑器也会在导入阶段把 3D 源文件打包为 .scn；
## 这里放 user://，保证单 EXE 中可写，并与 GM 的原始素材分开管理。
const MODEL_CACHE_ROOT: String = "user://library_cache/models/"
const MODEL_CACHE_VERSION: int = 1

## P1 只接收自包含的 GLB。文本 glTF 的外置 .bin/贴图无法靠复制单文件保证完整，
## FBX 同样可能依赖外部贴图；在依赖打包器完成前不把不可靠格式暴露给 GM。
const MODEL_EXTS: Array[String] = [".glb"]

## 支持的图片扩展名（小写，带点）。地面纹理用。
const IMAGE_EXTS: Array[String] = [".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga"]


## 确保某栏位的素材目录存在（不存在就建）。返回该栏位的完整路径。
## category = 栏位标识，如 "decor"（装饰）、"ground"（地面纹理）。
static func ensure_category_dir(category: String) -> String:
	var dir_path: String = LIBRARY_ROOT + category + "/"
	DirAccess.make_dir_recursive_absolute(dir_path)  # 已存在不报错
	return dir_path


## 把用户选的源文件复制进某栏位的素材目录。
## 源文件保持原名复制；若目标已存在同名文件会被覆盖（gdd_1241 第 163 行）。
## 成功返回目标路径，失败返回空字符串。
static func import_file(source_path: String, category: String) -> String:
	if source_path == "":
		return ""
	if not source_path.to_lower().ends_with(".glb"):
		push_error("LibraryManager: P1 仅支持自包含的 .glb 模型: %s" % source_path)
		return ""
	# 先验证并解析源文件。导入动作本来允许等待，拖动阶段则必须保持即时反馈。
	var packed: PackedScene = _pack_model_runtime(source_path)
	if packed == null:
		return ""
	var dest_dir: String = ensure_category_dir(category)
	var file_name: String = source_path.get_file()
	var dest_path: String = dest_dir + file_name
	var existed_before: bool = FileAccess.file_exists(dest_path)
	var err: int = DirAccess.copy_absolute(source_path, dest_path)
	if err != OK:
		push_error("LibraryManager: 复制失败 %s -> %s (code=%d)" % [source_path, dest_path, err])
		return ""
	if _save_model_cache(dest_path, packed) == "":
		if not existed_before:
			DirAccess.remove_absolute(dest_path)
		return ""
	return dest_path


## 扫描某栏位的素材目录，列出所有支持的素材文件路径。
## 只列文件不列子目录；按扩展名过滤（模型或图片）。
## kind = "model" 走 MODEL_EXTS，"image" 走 IMAGE_EXTS。
static func scan_category(category: String, kind: String) -> Array[String]:
	var dir_path: String = LIBRARY_ROOT + category + "/"
	var out: Array[String] = []
	var dd: DirAccess = DirAccess.open(dir_path)
	if dd == null:
		return out  # 目录不存在（还没导入过任何东西），返回空
	var exts: Array[String] = MODEL_EXTS if kind == "model" else IMAGE_EXTS
	dd.list_dir_begin()
	var fn: String = dd.get_next()
	while fn != "":
		if not dd.current_is_dir():
			var low: String = fn.to_lower()
			for ext: String in exts:
				if low.ends_with(ext):
					out.append(dir_path + fn)
					break
		fn = dd.get_next()
	dd.list_dir_end()
	out.sort()  # 按名排序，显示稳定
	return out


## 运行时加载一个 3D 模型文件为场景节点（根 Node）。
## GLB/glTF 走 GLTFDocument；FBX 走 FBXDocument（gdd_0187 第 200-204 行）。
## 成功返回可 add_child 的根节点，失败返回 null。
static func load_model_runtime(path: String) -> Node:
	var low: String = path.to_lower()
	if low.ends_with(".glb"):
		var doc: GLTFDocument = GLTFDocument.new()
		var state: GLTFState = GLTFState.new()
		var err: int = doc.append_from_file(path, state)
		if err != OK:
			push_error("LibraryManager: GLTF 加载失败 %s (code=%d)" % [path, err])
			return null
		return doc.generate_scene(state)
	push_error("LibraryManager: 不支持的模型格式 %s" % path)
	return null


## 返回模型缓存元数据路径。公开给测试和维护工具使用；不会创建目录或文件。
static func get_model_cache_metadata_path(model_path: String) -> String:
	var cache_dir: String = _get_model_cache_dir(model_path)
	if cache_dir == "":
		return ""
	return cache_dir + model_path.get_file() + ".cfg"


## 缓存有效时返回原生 .scn 路径；缺失、过期或元数据损坏时返回空字符串。
static func get_current_model_cache_path(model_path: String) -> String:
	if not FileAccess.file_exists(model_path):
		return ""
	var metadata_path: String = get_model_cache_metadata_path(model_path)
	if metadata_path == "" or not FileAccess.file_exists(metadata_path):
		return ""
	var config: ConfigFile = ConfigFile.new()
	if config.load(metadata_path) != OK:
		return ""
	var version: int = int(config.get_value("cache", "version", 0))
	var source_path: String = str(config.get_value("source", "path", ""))
	var modified_time: int = int(config.get_value("source", "modified_time", -1))
	var source_size: int = int(config.get_value("source", "size", -1))
	var cache_path: String = str(config.get_value("cache", "scene_path", ""))
	if version != MODEL_CACHE_VERSION or source_path != model_path:
		return ""
	if modified_time != FileAccess.get_modified_time(model_path):
		return ""
	if source_size != FileAccess.get_size(model_path):
		return ""
	if not cache_path.begins_with(MODEL_CACHE_ROOT) or not FileAccess.file_exists(cache_path):
		return ""
	return cache_path


## 确保外部 GLB 已转换成当前版本的原生场景缓存。
## 新导入模型会在导入阶段命中；旧素材只在首次使用时迁移一次。
static func ensure_model_cache(model_path: String) -> String:
	var current_path: String = get_current_model_cache_path(model_path)
	if current_path != "":
		return current_path
	var packed: PackedScene = _pack_model_runtime(model_path)
	if packed == null:
		return ""
	return _save_model_cache(model_path, packed)


## 删除一个模型的缓存场景、元数据和可能遗留的同名旧版本。
static func delete_model_cache(model_path: String) -> bool:
	var cache_dir: String = _get_model_cache_dir(model_path)
	if cache_dir == "":
		return true
	var metadata_path: String = get_model_cache_metadata_path(model_path)
	var all_ok: bool = true
	var dd: DirAccess = DirAccess.open(cache_dir)
	if dd != null:
		var prefix: String = model_path.get_file().get_basename() + "-"
		dd.list_dir_begin()
		var file_name: String = dd.get_next()
		while file_name != "":
			if (
					not dd.current_is_dir()
					and file_name.begins_with(prefix)
					and file_name.to_lower().ends_with(".scn")
			):
				if dd.remove(file_name) != OK:
					all_ok = false
			file_name = dd.get_next()
		dd.list_dir_end()
	if FileAccess.file_exists(metadata_path):
		if DirAccess.remove_absolute(metadata_path) != OK:
			all_ok = false
	if not all_ok:
		push_warning("LibraryManager: 模型缓存未完全清理 %s" % model_path)
	return all_ok


static func _get_model_cache_dir(model_path: String) -> String:
	var category: String = model_path.get_base_dir().get_file()
	if category == "" or model_path.get_file() == "":
		return ""
	return MODEL_CACHE_ROOT + category + "/"


static func _pack_model_runtime(model_path: String) -> PackedScene:
	var template: Node = load_model_runtime(model_path)
	if template == null:
		return null
	_set_scene_owner_recursive(template, template)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(template)
	template.free()
	if err != OK:
		push_error("LibraryManager: 模型缓存打包失败 %s (code=%d)" % [model_path, err])
		return null
	return packed


static func _set_scene_owner_recursive(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_set_scene_owner_recursive(child, owner_node)


static func _save_model_cache(model_path: String, packed: PackedScene) -> String:
	var cache_dir: String = _get_model_cache_dir(model_path)
	if cache_dir == "":
		return ""
	if DirAccess.make_dir_recursive_absolute(cache_dir) != OK:
		push_error("LibraryManager: 无法创建模型缓存目录 %s" % cache_dir)
		return ""
	var source_hash: String = FileAccess.get_sha256(model_path)
	if source_hash == "":
		push_error("LibraryManager: 无法计算模型文件指纹 %s" % model_path)
		return ""
	var scene_name: String = "%s-%s.scn" % [
		model_path.get_file().get_basename(),
		source_hash.substr(0, 16),
	]
	var scene_path: String = cache_dir + scene_name
	var save_err: int = ResourceSaver.save(packed, scene_path, ResourceSaver.FLAG_COMPRESS)
	if save_err != OK:
		push_error("LibraryManager: 模型缓存保存失败 %s (code=%d)" % [scene_path, save_err])
		return ""

	var metadata_path: String = get_model_cache_metadata_path(model_path)
	var old_scene_path: String = ""
	var old_config: ConfigFile = ConfigFile.new()
	if old_config.load(metadata_path) == OK:
		old_scene_path = str(old_config.get_value("cache", "scene_path", ""))
	var config: ConfigFile = ConfigFile.new()
	config.set_value("cache", "version", MODEL_CACHE_VERSION)
	config.set_value("cache", "scene_path", scene_path)
	config.set_value("source", "path", model_path)
	config.set_value("source", "modified_time", FileAccess.get_modified_time(model_path))
	config.set_value("source", "size", FileAccess.get_size(model_path))
	config.set_value("source", "sha256", source_hash)
	var config_err: int = config.save(metadata_path)
	if config_err != OK:
		push_error("LibraryManager: 模型缓存元数据保存失败 %s (code=%d)" % [metadata_path, config_err])
		return ""
	if (
			old_scene_path != ""
			and old_scene_path != scene_path
			and old_scene_path.begins_with(MODEL_CACHE_ROOT)
			and FileAccess.file_exists(old_scene_path)
	):
		DirAccess.remove_absolute(old_scene_path)
	return scene_path


## 删除一个导入的模型文件（user://library/<category>/<文件名>）。
## 只能删导入的（user:// 下），自带素材在 res:// 打包后只读删不掉，调用方负责判 source。
## 成功返回 true。依据 gdd_1241 DirAccess.remove（第 118 行）。
static func delete_model(category: String, file_name: String) -> bool:
	var path: String = LIBRARY_ROOT + category + "/" + file_name
	if not FileAccess.file_exists(path):
		return false
	var err: int = DirAccess.remove_absolute(path)
	if err != OK:
		push_error("LibraryManager: 删除失败 %s (code=%d)" % [path, err])
		return false
	delete_model_cache(path)
	return true


## 删除一个导入的地面纹理文件夹（user://library/ground/<组名>/，含里面所有图）。
## 成功返回 true。依据 gdd_1241 DirAccess.remove + list_dir 逐文件删。
static func delete_ground_texture(group_name: String) -> bool:
	var dir_path: String = LIBRARY_ROOT + "ground/" + group_name + "/"
	var dd: DirAccess = DirAccess.open(dir_path)
	if dd == null:
		return false
	# 先删里面所有文件
	dd.list_dir_begin()
	var fn: String = dd.get_next()
	var any_fail: bool = false
	while fn != "":
		if not dd.current_is_dir():
			if dd.remove(fn) != OK:
				any_fail = true
		fn = dd.get_next()
	dd.list_dir_end()
	if any_fail:
		return false
	# 再删空文件夹本身
	var err: int = DirAccess.remove_absolute(dir_path)
	if err != OK:
		push_error("LibraryManager: 删除纹理文件夹失败 %s (code=%d)" % [dir_path, err])
		return false
	return true
## 地面纹理按 PBR 多图一组：一个文件夹=一个纹理，里面多张图按文件名分类。
## 递归复制文件夹内所有文件（用 DirAccess.copy 逐文件）。成功返回目标文件夹路径，失败空字符串。
## 依据 gdd_1241：DirAccess.open + list_dir_begin/get_next + copy（第 85/161 行）。
static func import_texture_folder(source_dir: String) -> String:
	if source_dir == "":
		return ""
	var folder_name: String = source_dir.get_file()  # 文件夹名=纹理组名
	if folder_name == "":
		return ""
	var dest_dir: String = ensure_category_dir("ground") + folder_name + "/"
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var sd: DirAccess = DirAccess.open(source_dir)
	if sd == null:
		push_error("LibraryManager: 打不开源文件夹 %s" % source_dir)
		return ""
	sd.list_dir_begin()
	var fn: String = sd.get_next()
	var any_ok: bool = false
	while fn != "":
		if not sd.current_is_dir():
			var src_file: String = source_dir + "/" + fn
			var dest_file: String = dest_dir + fn
			if DirAccess.copy_absolute(src_file, dest_file) == OK:
				any_ok = true
		fn = sd.get_next()
	sd.list_dir_end()
	if not any_ok:
		push_error("LibraryManager: 文件夹内没复制成功任何文件 %s" % source_dir)
		return ""
	return dest_dir


## 扫描导入的地面纹理素材库（user://library/ground/），返回和自带 _ground_sets 同结构的数组。
## 每个子文件夹=一个纹理组，文件夹名=_base（组名），里面图片按文件名分类（albedo/normal 等）。
## 分类逻辑跟 main.gd _classify_texture 一致：单文件当 albedo，多文件按后缀分类。
## 这样导入的纹理能跟自带纹理合并进同一个 _ground_sets 列表，点它换皮逻辑不变。
static func scan_ground_textures() -> Array[Dictionary]:
	var root: String = ensure_category_dir("ground")
	var out: Array[Dictionary] = []
	var dd: DirAccess = DirAccess.open(root)
	if dd == null:
		return out
	dd.list_dir_begin()
	var subdir: String = dd.get_next()
	while subdir != "":
		if subdir == "." or subdir == "..":
			subdir = dd.get_next()
			continue
		if dd.current_is_dir():
			_scan_one_ground_folder(root + subdir, subdir, out)
		subdir = dd.get_next()
	dd.list_dir_end()
	return out


## 扫单个地面纹理文件夹，按文件名分类成一组纹理 set，追加进 out。
static func _scan_one_ground_folder(folder_path: String, folder_name: String, out: Array[Dictionary]) -> void:
	var dd: DirAccess = DirAccess.open(folder_path)
	if dd == null:
		return
	var files: Array[String] = []
	dd.list_dir_begin()
	var fn: String = dd.get_next()
	while fn != "":
		if not dd.current_is_dir():
			var low: String = fn.to_lower()
			if low.ends_with(".png") or low.ends_with(".jpg") or low.ends_with(".jpeg") \
					or low.ends_with(".webp") or low.ends_with(".bmp") or low.ends_with(".tga"):
				files.append(fn)
		fn = dd.get_next()
	dd.list_dir_end()
	if files.is_empty():
		return
	# 单文件 → 整个当 albedo（颜色图）
	if files.size() == 1:
		out.append({
			"_base": folder_name,
			"source": "imported",
			"albedo": folder_path + "/" + files[0],
		})
		return
	# 多文件 → 逐文件按关键词分类。同类型只认第一个（避免多张同类型图互相覆盖）。
	var group: Dictionary = {"_base": folder_name, "source": "imported"}
	for f: String in files:
		var stem: String = f.get_basename().to_lower().replace("-", "_")
		var tex_type: String = _classify_one_texture(stem)
		if not group.has(tex_type):  # 该类型还没图 → 存；已有 → 跳过不覆盖
			group[tex_type] = folder_path + "/" + f
	out.append(group)


## 单张纹理按文件名关键词分类（albedo/normal/roughness/metallic/ao/emission/orm）。
## 用"关键词子串搜索"：文件名里只要出现该关键词就归该类，不管在文件名哪个位置。
## 这样兼容把类型词放中间/结尾的素材包（如 gravel_normal_xtm、wood_diffuse_2k）。
## 关键词按长度降序排，先匹配更具体的（basecolor 比 color 长，先匹配）避免短词误吃长词。
## 跟 main.gd _classify_texture 同规则，复制一份在这避免循环依赖。
static func _classify_one_texture(stem: String) -> String:
	# [关键词, 类型] —— 关键词已按长度降序排，长的先匹配
	var rules: Array[Array] = [
		["ambient_occlusion", "ao"], ["ambientocclusion", "ao"],
		["base_color", "albedo"], ["basecolor", "albedo"],
		["metalness", "metallic"],
		["roughness", "roughness"], ["glossiness", "roughness"],
		["emission", "emission"], ["emissive", "emission"],
		["normal_gl", "normal"], ["normalgl", "normal"],
		["diffuse", "albedo"], ["albedo", "albedo"],
		["metallic", "metallic"],
		["normal", "normal"],
		["gloss", "roughness"],
		["_orm", "orm"], ["orm", "orm"],
		["_ao", "ao"], ["ao", "ao"],
		["color", "albedo"],
	]
	for rule: Array in rules:
		if stem.find(rule[0]) >= 0:
			return rule[1]
	return "albedo"  # 认不出就当颜色图

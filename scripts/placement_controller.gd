class_name PlacementController
extends Node

const WALL_SNAP_OFFSET: float = 0.05
const RAY_LENGTH: float = 1000.0

var _scene_root: Node3D = null
var _content_root: Node3D = null
var _camera: Camera3D = null
var _left_panel: Control = null
var _model_panels: Dictionary = {}
var _model_scene_cache: Dictionary = {}
var _model_thread_requests: Dictionary = {}
var _model_thread_paths: Array[String] = []
var _drag_preview_root: Node3D = null
var _token_properties_script: GDScript = null
var _wall_properties_script: GDScript = null
var _combat_body_script: GDScript = null
var _los_occluder_script: GDScript = null
var _light_properties_script: GDScript = null
var _interactable_properties_script: GDScript = null
var _traversal_properties_script: GDScript = null
var _cpr_token_properties_script: GDScript = null
var _get_current_ruleset_id: Callable = Callable()


func configure(
		scene_root: Node3D,
		content_root: Node3D,
		camera: Camera3D,
		left_panel: Control,
		model_panels: Dictionary,
		model_scene_cache: Dictionary,
		model_thread_requests: Dictionary,
		model_thread_paths: Array[String],
		token_properties_script: GDScript,
		wall_properties_script: GDScript,
		combat_body_script: GDScript,
		light_properties_script: GDScript,
		interactable_properties_script: GDScript,
		traversal_properties_script: GDScript,
		cpr_token_properties_script: GDScript,
		los_occluder_script: GDScript = null,
		get_current_ruleset_id: Callable = Callable()
) -> void:
	_scene_root = scene_root
	_content_root = content_root
	_camera = camera
	_left_panel = left_panel
	_model_panels = model_panels
	_model_scene_cache = model_scene_cache
	_model_thread_requests = model_thread_requests
	_model_thread_paths = model_thread_paths
	_token_properties_script = token_properties_script
	_wall_properties_script = wall_properties_script
	_combat_body_script = combat_body_script
	_los_occluder_script = los_occluder_script
	_light_properties_script = light_properties_script
	_interactable_properties_script = interactable_properties_script
	_traversal_properties_script = traversal_properties_script
	_cpr_token_properties_script = cpr_token_properties_script
	_get_current_ruleset_id = get_current_ruleset_id


func create_drag_preview(category: String, index: int) -> void:
	clear_drag_preview()
	if _scene_root == null or not is_instance_valid(_scene_root):
		return
	_drag_preview_root = Node3D.new()
	_drag_preview_root.name = "DragPreview"
	_scene_root.add_child(_drag_preview_root)
	var instance: Node = load_model_instance(category, index)
	if instance == null:
		clear_drag_preview()
		return
	_drag_preview_root.add_child(instance)
	_apply_drag_preview_visuals(_drag_preview_root)


func clear_drag_preview() -> void:
	if _drag_preview_root != null and is_instance_valid(_drag_preview_root):
		_drag_preview_root.queue_free()
	_drag_preview_root = null


func update_drag_preview(category: String, mouse_pos: Vector2) -> void:
	if _drag_preview_root == null or not is_instance_valid(_drag_preview_root):
		return
	if _left_panel != null and _left_panel.get_global_rect().has_point(mouse_pos):
		_drag_preview_root.visible = false
		return
	var drop: Dictionary = get_model_drop(category, true, mouse_pos)
	if drop.is_empty():
		_drag_preview_root.visible = false
		return
	_drag_preview_root.visible = true
	_drag_preview_root.position = drop["position"]
	if drop.get("snapped_to_wall", false):
		var normal: Vector3 = drop["normal"]
		if normal.length_squared() > 0.0001 and abs(normal.y) < 0.95:
			_drag_preview_root.look_at(
				_drag_preview_root.global_position + normal, Vector3.UP, true
			)
	else:
		_drag_preview_root.rotation = Vector3.ZERO


func has_drag_preview() -> bool:
	return _drag_preview_root != null and is_instance_valid(_drag_preview_root)


func get_drag_preview_root() -> Node3D:
	if has_drag_preview():
		return _drag_preview_root
	return null


func place_model(
		category: String,
		index: int,
		use_surface_snap: bool = false,
		mouse_pos: Vector2 = Vector2.INF
) -> Dictionary:
	if not _model_panels.has(category):
		return {}
	var panel: Dictionary = _model_panels[category]
	if index < 0 or index >= panel["items"].size():
		return {}
	var item: Dictionary = panel["items"][index]
	var path: String = item["path"]
	var source: String = item["source"]
	var drop: Dictionary = get_model_drop(category, use_surface_snap, mouse_pos)
	if drop.is_empty():
		return {}
	var instance: Node = load_model_instance(category, index)
	if instance == null:
		return {"error": "load_failed", "path": path}
	if _content_root == null or not is_instance_valid(_content_root):
		instance.queue_free()
		return {}
	var root: Node3D = Node3D.new()
	root.position = drop["position"]
	root.name = path.get_file().get_basename()
	if source == "builtin_light":
		root.name = "点光源"
		root.set_meta("gvtt_builtin_light", true)
	_content_root.add_child(root, true)
	root.set_owner(_content_root)
	if drop.get("snapped_to_wall", false):
		var normal: Vector3 = drop["normal"]
		if normal.length_squared() > 0.0001 and abs(normal.y) < 0.95:
			root.look_at(root.global_position + normal, Vector3.UP, true)
	root.add_child(instance)
	instance.set_owner(_content_root)
	var props: EntityProperties = EntityProperties.new()
	props.name = "EntityProperties"
	props.configure_from_category(category)
	root.add_child(props)
	props.set_owner(_content_root)
	attach_entity_type_properties(root, props)
	var proxy: PickProxy = PickProxy.new()
	proxy.name = "PickProxy"
	proxy.target_node = root
	proxy.show_marker = source == "builtin_light"
	if source == "builtin_light":
		var light_properties: Node = root.get_node_or_null("LightProperties")
		if light_properties != null:
			proxy.marker_color = light_properties.get("color")
	root.add_child(proxy)
	proxy.set_owner(_content_root)
	root.force_update_transform()
	proxy.fit_from_target_synced()
	return {
		"root": root,
		"path": path,
		"label": root.name,
		"snapped_to_wall": drop.get("snapped_to_wall", false),
	}


func load_model_instance(category: String, index: int) -> Node:
	if not _model_panels.has(category):
		return null
	var panel: Dictionary = _model_panels[category]
	if index < 0 or index >= panel["items"].size():
		return null
	var item: Dictionary = panel["items"][index]
	var path: String = item["path"]
	if item["source"] == "builtin_light":
		return _create_builtin_point_light_instance()
	if item["source"] == "imported":
		var cache_path: String = LibraryManager.ensure_model_cache(path)
		if cache_path == "":
			return null
		var imported_packed: PackedScene = get_cached_packed_scene(cache_path)
		if imported_packed == null:
			return null
		var imported_instance: Node = imported_packed.instantiate()
		_prepare_model_instance(imported_instance)
		return imported_instance
	var packed: PackedScene = get_cached_packed_scene(path)
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	_prepare_model_instance(instance)
	return instance


func _create_builtin_point_light_instance() -> Node:
	var light_root: Node3D = Node3D.new()
	light_root.name = "PointLight"
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "RuntimeLight"
	light.light_color = Color(1.0, 0.86, 0.55, 1.0)
	light.light_energy = 1.0
	light.omni_range = 8.0
	light.shadow_enabled = true
	light_root.add_child(light)
	return light_root


func get_cached_packed_scene(path: String) -> PackedScene:
	if path == "":
		return null
	if _model_scene_cache.has(path):
		var cached: Variant = _model_scene_cache[path]
		if cached is PackedScene:
			return cached as PackedScene
	if _model_thread_requests.has(path):
		var status: int = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var loaded: Resource = ResourceLoader.load_threaded_get(path)
			if loaded is PackedScene:
				_model_scene_cache[path] = loaded
				_model_thread_requests.erase(path)
				_model_thread_paths.erase(path)
				return loaded as PackedScene
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var waited: Resource = ResourceLoader.load_threaded_get(path)
			if waited is PackedScene:
				_model_scene_cache[path] = waited
				_model_thread_requests.erase(path)
				_model_thread_paths.erase(path)
				return waited as PackedScene
			return null
		_model_thread_requests.erase(path)
		_model_thread_paths.erase(path)
	var res: Resource = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	if res is PackedScene:
		_model_scene_cache[path] = res
		return res as PackedScene
	return null


func get_model_drop(
		category: String,
		use_surface_snap: bool,
		mouse_pos: Vector2 = Vector2.INF
) -> Dictionary:
	if _camera == null or not is_instance_valid(_camera):
		return {}
	var mp: Vector2 = mouse_pos
	if not is_finite(mp.x) or not is_finite(mp.y):
		mp = get_viewport().get_mouse_position()
	var org: Vector3 = _camera.project_ray_origin(mp)
	var dir: Vector3 = _camera.project_ray_normal(mp)
	var to: Vector3 = org + dir * RAY_LENGTH
	if use_surface_snap and category == "interactable":
		var wall_hit: Dictionary = _raycast_wall(org, to)
		if not wall_hit.is_empty():
			var normal: Vector3 = wall_hit.get("normal", -dir)
			if normal.length_squared() < 0.0001:
				normal = -dir
			normal = normal.normalized()
			var hit_pos: Vector3 = wall_hit["position"]
			return {
				"position": hit_pos + normal * WALL_SNAP_OFFSET,
				"normal": normal,
				"snapped_to_wall": true,
			}
	if abs(dir.y) < 0.0001:
		return {}
	var tt: float = -org.y / dir.y
	if tt <= 0.0:
		return {}
	return {"position": org + dir * tt, "normal": Vector3.UP, "snapped_to_wall": false}


func attach_entity_type_properties(root: Node3D, props: EntityProperties) -> void:
	if root == null or props == null:
		return
	match props.get_effective_entity_type():
		EntityProperties.EntityType.TOKEN:
			if root.get_node_or_null("TokenProperties") == null:
				var token_props: Node = _token_properties_script.new() as Node
				token_props.name = "TokenProperties"
				root.add_child(token_props)
				token_props.set_owner(_content_root)
			_attach_ruleset_token_properties(root)
		EntityProperties.EntityType.WALL:
			var wall_props: Node = root.get_node_or_null("WallProperties")
			if root.get_node_or_null("WallProperties") == null:
				wall_props = _wall_properties_script.new() as Node
				wall_props.name = "WallProperties"
				wall_props.call("configure_from_legacy", props)
				root.add_child(wall_props)
				wall_props.set_owner(_content_root)
			_ensure_combat_body(root)
			_ensure_los_occluder(root, wall_props)
		EntityProperties.EntityType.LIGHT:
			var light_props: Node = root.get_node_or_null("LightProperties")
			if root.get_node_or_null("LightProperties") == null:
				light_props = _light_properties_script.new() as Node
				light_props.name = "LightProperties"
				root.add_child(light_props)
				light_props.set_owner(_content_root)
			_sync_light_pick_proxy_marker(root, light_props)
			if light_props != null and bool(root.get_meta("gvtt_builtin_light", false)):
				light_props.call("ensure_runtime_light", root, _content_root)
		EntityProperties.EntityType.INTERACTABLE:
			if root.get_node_or_null("InteractableProperties") == null:
				var interactable_props: Node = _interactable_properties_script.new() as Node
				interactable_props.name = "InteractableProperties"
				root.add_child(interactable_props)
				interactable_props.set_owner(_content_root)
			_ensure_combat_body(root)
		EntityProperties.EntityType.TERRAIN, EntityProperties.EntityType.DECOR:
			_ensure_combat_body(root)
		_:
			pass
	_attach_traversal_properties(root, props)

func sync_combat_body(root: Node3D) -> bool:
	if root == null or not is_instance_valid(root):
		return false
	var props: EntityProperties = root.get_node_or_null("EntityProperties") as EntityProperties
	if props == null:
		return false
	match props.get_effective_entity_type():
		EntityProperties.EntityType.WALL:
			var wall_props: Node = root.get_node_or_null("WallProperties")
			if wall_props == null:
				return false
		EntityProperties.EntityType.INTERACTABLE, EntityProperties.EntityType.TERRAIN, EntityProperties.EntityType.DECOR:
			pass
		_:
			return false
	return _ensure_combat_body(root)


func sync_los_occluder(root: Node3D) -> bool:
	if root == null or not is_instance_valid(root):
		return false
	var props: EntityProperties = root.get_node_or_null("EntityProperties") as EntityProperties
	if props == null or props.get_effective_entity_type() != EntityProperties.EntityType.WALL:
		return false
	var wall_props: Node = root.get_node_or_null("WallProperties")
	if wall_props == null:
		return false
	return _ensure_los_occluder(root, wall_props)


func _ensure_los_occluder(root: Node3D, wall_props: Node) -> bool:
	if _los_occluder_script == null or wall_props == null:
		return false
	var occluder_node: Node = root.get_node_or_null("LOSOccluder")
	if occluder_node == null:
		occluder_node = _los_occluder_script.new() as Node
		if not (occluder_node is Node3D):
			return false
		occluder_node.name = "LOSOccluder"
		occluder_node.set("target_node", root)
		root.add_child(occluder_node)
		occluder_node.set_owner(_content_root)
	else:
		occluder_node.set("target_node", root)
	if root.is_inside_tree():
		root.force_update_transform()
	var effective_blocks_los: bool = bool(wall_props.get("blocks_los"))
	if wall_props.has_method("get_effective_blocks_los"):
		effective_blocks_los = bool(wall_props.call("get_effective_blocks_los"))
	occluder_node.call("set_blocks_los", effective_blocks_los)
	return bool(occluder_node.call("fit_from_target_synced"))


func _ensure_combat_body(root: Node3D) -> bool:
	if _combat_body_script == null:
		return false
	var combat_node: Node = root.get_node_or_null("CombatBody")
	if combat_node == null:
		combat_node = _combat_body_script.new() as Node
		if not (combat_node is Node3D):
			return false
		combat_node.name = "CombatBody"
		combat_node.set("target_node", root)
		combat_node.set("blocks_shot", false)
		combat_node.set("provides_full_cover", false)
		root.add_child(combat_node)
		combat_node.set_owner(_content_root)
	else:
		combat_node.set("target_node", root)
	if root.is_inside_tree():
		root.force_update_transform()
	var geometry_fitted: bool = bool(combat_node.call("fit_from_target_synced"))
	var is_cover: bool = bool(combat_node.call("meets_automatic_cover_height"))
	combat_node.call("set_provides_full_cover", is_cover)
	var effective_blocks_shot: bool = is_cover
	var props: EntityProperties = root.get_node_or_null("EntityProperties") as EntityProperties
	if props != null:
		props.cover_level = (
			EntityProperties.CoverLevel.FULL
			if is_cover
			else EntityProperties.CoverLevel.NONE
		)
	var wall_props: Node = root.get_node_or_null("WallProperties")
	if wall_props != null:
		if wall_props.has_method("get_effective_blocks_shot"):
			effective_blocks_shot = (
				is_cover and bool(wall_props.call("get_effective_blocks_shot"))
			)
	combat_node.call("set_blocks_shot", effective_blocks_shot)
	return geometry_fitted


func _apply_drag_preview_visuals(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		geometry.transparency = 0.45
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c: Node in node.get_children():
		_apply_drag_preview_visuals(c)


func _sync_light_pick_proxy_marker(root: Node3D, light_props: Node) -> void:
	var proxy_node: Node = root.get_node_or_null("PickProxy")
	if not (proxy_node is PickProxy):
		return
	var proxy: PickProxy = proxy_node as PickProxy
	var should_show_marker: bool = bool(root.get_meta("gvtt_builtin_light", false))
	proxy.set_marker_enabled(should_show_marker)
	if should_show_marker and light_props != null:
		proxy.set_marker_color(light_props.get("color"))


func _prepare_model_instance(instance: Node) -> void:
	_reset_all_transforms(instance)
	_align_model_to_drop_origin(instance)


func _align_model_to_drop_origin(instance: Node) -> void:
	if not (instance is Node3D):
		return
	var bounds: Dictionary = _get_model_local_bounds(instance)
	if not bounds.get("has_bounds", false):
		return
	var min_v: Vector3 = bounds["min"]
	var max_v: Vector3 = bounds["max"]
	var center: Vector3 = (min_v + max_v) * 0.5
	var offset: Vector3 = Vector3(-center.x, -min_v.y, -center.z)
	if offset.length_squared() < 0.000001:
		return
	var model_root: Node3D = instance as Node3D
	model_root.position += offset


func _get_model_local_bounds(node: Node) -> Dictionary:
	var stack_nodes: Array[Node] = [node]
	var stack_transforms: Array[Transform3D] = [Transform3D.IDENTITY]
	var has_point: bool = false
	var min_v: Vector3 = Vector3.ZERO
	var max_v: Vector3 = Vector3.ZERO
	while not stack_nodes.is_empty():
		var current: Node = stack_nodes.pop_back()
		var parent_transform: Transform3D = stack_transforms.pop_back()
		var current_transform: Transform3D = parent_transform
		if current is Node3D:
			var current_3d: Node3D = current as Node3D
			current_transform = parent_transform * current_3d.transform
		if current is VisualInstance3D:
			var visual: VisualInstance3D = current as VisualInstance3D
			var aabb: AABB = visual.get_aabb()
			for i: int in range(8):
				var point: Vector3 = current_transform * aabb.get_endpoint(i)
				if not has_point:
					has_point = true
					min_v = point
					max_v = point
				else:
					min_v = min_v.min(point)
					max_v = max_v.max(point)
		for c: Node in current.get_children():
			stack_nodes.append(c)
			stack_transforms.append(current_transform)
	return {"has_bounds": has_point, "min": min_v, "max": max_v}


func _raycast_wall(from: Vector3, to: Vector3) -> Dictionary:
	if _content_root == null or not is_instance_valid(_content_root):
		return {}
	var world: World3D = _content_root.get_world_3d()
	if world == null:
		return {}
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var mask: int = 1 << (GvttRenderLayers.PICK_PHYSICS_LAYER - 1)
	var excludes: Array[RID] = []
	for i: int in range(8):
		var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from, to, mask, excludes
		)
		params.collide_with_areas = true
		params.collide_with_bodies = false
		var hit: Dictionary = space.intersect_ray(params)
		if hit.is_empty():
			return {}
		var collider: Object = hit["collider"]
		if collider is Area3D:
			var root: Node3D = _find_entity_root(collider as Area3D)
			if root != null and _is_entity_category(root, "wall"):
				return hit
		if hit.has("rid") and hit["rid"] is RID:
			excludes.append(hit["rid"])
		else:
			return {}
	return {}


func _find_entity_root(area: Area3D) -> Node3D:
	var node: Node = area
	while node != null:
		if node is Node3D:
			for c: Node in node.get_children():
				if c is EntityProperties:
					return node as Node3D
		node = node.get_parent()
	return null


func _is_entity_category(root: Node3D, category: String) -> bool:
	for c: Node in root.get_children():
		if c is EntityProperties:
			var props: EntityProperties = c as EntityProperties
			return props.category == category
	return false


func _attach_ruleset_token_properties(root: Node3D) -> void:
	if _current_ruleset_id() != &"cpr":
		return
	if root.get_node_or_null("CprTokenProperties") != null:
		return
	var cpr_properties: Node = _cpr_token_properties_script.new() as Node
	cpr_properties.name = "CprTokenProperties"
	root.add_child(cpr_properties)
	cpr_properties.set_owner(_content_root)


func _current_ruleset_id() -> StringName:
	if not _get_current_ruleset_id.is_valid():
		return &""
	var result: Variant = _get_current_ruleset_id.call()
	if result is StringName:
		return result as StringName
	return StringName(String(result))


func _attach_traversal_properties(root: Node3D, props: EntityProperties) -> void:
	if root.get_node_or_null("TraversalProperties") != null:
		return
	var traversal: Node = _traversal_properties_script.new() as Node
	traversal.name = "TraversalProperties"
	traversal.call("configure_for_entity_type", props.get_effective_entity_type())
	root.add_child(traversal)
	traversal.set_owner(_content_root)


func _reset_all_transforms(node: Node) -> void:
	if node is Node3D:
		var n: Node3D = node as Node3D
		n.position = Vector3.ZERO
		n.rotation = Vector3.ZERO
		n.scale = Vector3.ONE

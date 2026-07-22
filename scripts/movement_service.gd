extends Node3D
class_name MovementService
## Runtime-only tactical movement: bake, query, preview, clearance and path following.

const SURFACE_PHYSICS_LAYER: int = 18
const BLOCKER_PHYSICS_LAYER: int = 19
const SURFACE_LAYER_MASK: int = 1 << (SURFACE_PHYSICS_LAYER - 1)
const BLOCKER_LAYER_MASK: int = 1 << (BLOCKER_PHYSICS_LAYER - 1)
const TARGET_RAY_LENGTH: float = 2000.0
const PATH_HEIGHT_OFFSET: float = 0.08
const FOLLOW_SPEED_METERS_PER_SECOND: float = 6.0
const MAX_FOLLOW_DURATION_SECONDS: float = 2.0
const MIN_FACING_DIRECTION_LENGTH_SQUARED: float = 0.0001
const RANGE_RING_SEGMENTS: int = 64
const NAVIGATION_CELL_SIZE: float = 0.1
const NAVIGATION_CELL_HEIGHT: float = 0.25
const NAVIGATION_SAFETY_RADIUS: float = 0.2
const DEFAULT_TOKEN_RADIUS: float = 0.45
const DEFAULT_TOKEN_HEIGHT: float = 1.8

var _content_root: Node3D = null
var _scene_size: Vector2 = Vector2.ZERO
var _region: NavigationRegion3D = null
var _navigation_map: RID = RID()
var _navigation_profiles: Dictionary = {}
var _source_geometry_data: NavigationMeshSourceGeometryData3D = null
var _active_profile_key: Vector2i = Vector2i(-1, -1)
var _navigation_link_specs: Array[Dictionary] = []
var _entity_local_bounds: Dictionary = {}
var _preview_instance: MeshInstance3D = null
var _preview_mesh: ImmediateMesh = null
var _range_instance: MeshInstance3D = null
var _range_mesh: ImmediateMesh = null
var _valid_material: StandardMaterial3D = null
var _range_material: StandardMaterial3D = null
var _rule_provider: MovementRuleProvider = null
var _query_parameters: NavigationPathQueryParameters3D = NavigationPathQueryParameters3D.new()
var _query_result: NavigationPathQueryResult3D = NavigationPathQueryResult3D.new()
var _preview_token: Node3D = null
var _preview_full_path: PackedVector3Array = PackedVector3Array()
var _preview_reachable_path: PackedVector3Array = PackedVector3Array()
var _preview_cost: float = 0.0
var _preview_budget: float = 0.0
var _preview_over_budget: bool = false
var _moving_token: Node3D = null
var _moving_path: PackedVector3Array = PackedVector3Array()
var _moving_path_index: int = 0
var _moving_speed: float = FOLLOW_SPEED_METERS_PER_SECOND
var _link_tags: Dictionary = {}
var _traversal_volumes: Array[Dictionary] = []


func _ready() -> void:
	set_meta("gvtt_runtime_only", true)
	set_process(false)
	_create_preview_renderer()


func _exit_tree() -> void:
	_clear_navigation_runtime()


func _process(delta: float) -> void:
	if _moving_token == null or not is_instance_valid(_moving_token):
		_stop_path_following()
		return
	if _moving_path_index >= _moving_path.size():
		_stop_path_following()
		return
	var destination: Vector3 = _moving_path[_moving_path_index]
	_face_movement_direction(destination)
	var distance: float = _moving_token.global_position.distance_to(destination)
	var step: float = _moving_speed * delta
	if distance <= step or distance <= 0.001:
		_moving_token.global_position = destination
		_moving_path_index += 1
		if _moving_path_index >= _moving_path.size():
			_stop_path_following()
		return
	_moving_token.global_position = _moving_token.global_position.move_toward(destination, step)


func rebuild(
		content_root: Node3D,
		scene_size: Vector2,
		rule_provider: MovementRuleProvider
) -> bool:
	_content_root = content_root
	_scene_size = scene_size
	_rule_provider = rule_provider
	_clear_navigation_runtime()
	if _content_root == null or not is_instance_valid(_content_root) or _rule_provider == null:
		return false
	_region = NavigationRegion3D.new()
	_region.name = "MovementNavigationRegion"
	_region.set_meta("gvtt_runtime_only", true)
	add_child(_region)
	_create_ground_surface(scene_size)
	_collect_runtime_geometry()
	var default_key: Vector2i = _get_navigation_profile_key(
		DEFAULT_TOKEN_RADIUS,
		DEFAULT_TOKEN_HEIGHT
	)
	var parse_mesh: NavigationMesh = _create_navigation_mesh(default_key, scene_size)
	_source_geometry_data = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(
		parse_mesh,
		_source_geometry_data,
		_region
	)
	if not _create_navigation_profile(default_key, scene_size, true):
		return false
	return _activate_navigation_profile(default_key)


func begin_preview(token_root: Node3D) -> bool:
	clear_preview()
	_stop_path_following()
	if token_root == null or not is_instance_valid(token_root):
		return false
	if not _activate_navigation_profile_for_token(token_root):
		return false
	_preview_budget = _rule_provider.get_movement_budget_meters(token_root)
	if _preview_budget <= 0.0:
		return false
	_preview_token = token_root
	_draw_range_ring()
	return true


func update_preview(camera: Camera3D, screen_position: Vector2) -> Dictionary:
	if _preview_token == null or not is_instance_valid(_preview_token) or camera == null:
		clear_preview()
		return {}
	var target_result: Dictionary = _screen_to_navigation_position(camera, screen_position)
	if target_result.is_empty():
		clear_preview_path()
		return {}
	return _query_preview_to_target(target_result["position"] as Vector3)


func preview_to_world_position(token_root: Node3D, target_position: Vector3) -> Dictionary:
	if _preview_token != token_root and not begin_preview(token_root):
		return {}
	if not is_navigation_ready():
		return {}
	var closest_target: Vector3 = NavigationServer3D.map_get_closest_point(
		_navigation_map, target_position)
	return _query_preview_to_target(closest_target)


func _query_preview_to_target(target_position: Vector3) -> Dictionary:
	if not _activate_navigation_profile_for_token(_preview_token):
		clear_preview_path()
		return {}
	var candidate: Dictionary = _build_preview_candidate(target_position)
	if candidate.is_empty():
		clear_preview_path()
		return {}
	if bool(candidate["clearance_limited"]):
		var base_profile_key: Vector2i = _active_profile_key
		var safety_steps: int = ceili(
			NAVIGATION_SAFETY_RADIUS / NAVIGATION_CELL_SIZE
		)
		var safety_profile_key: Vector2i = Vector2i(
			base_profile_key.x + safety_steps,
			base_profile_key.y
		)
		if _activate_navigation_profile(safety_profile_key):
			var safety_candidate: Dictionary = _build_preview_candidate(target_position)
			if not safety_candidate.is_empty() and not bool(safety_candidate["clearance_limited"]):
				candidate = safety_candidate
	_apply_preview_candidate(candidate)
	_draw_preview()
	return {
		"cost": _preview_cost,
		"full_cost": float(candidate["full_cost"]),
		"budget": _preview_budget,
		"over_budget": _preview_over_budget,
		"endpoint": _preview_reachable_path[-1],
	}


func _build_preview_candidate(target_position: Vector3) -> Dictionary:
	var start_position: Vector3 = NavigationServer3D.map_get_closest_point(
		_navigation_map,
		_preview_token.global_position
	)
	var closest_target: Vector3 = NavigationServer3D.map_get_closest_point(
		_navigation_map,
		target_position
	)
	_query_parameters.map = _navigation_map
	_query_parameters.start_position = start_position
	_query_parameters.target_position = closest_target
	_query_parameters.navigation_layers = 1
	_query_parameters.path_postprocessing = (
		NavigationPathQueryParameters3D.PATH_POSTPROCESSING_CORRIDORFUNNEL
	)
	NavigationServer3D.query_path(_query_parameters, _query_result)
	var full_path: PackedVector3Array = _snap_path_to_surfaces(_query_result.path)
	if full_path.size() < 2:
		return {}
	var segment_tags: Array[StringName] = _build_segment_tags(full_path)
	var full_cost: float = _rule_provider.calculate_path_cost(full_path, segment_tags)
	var truncated: Dictionary = _rule_provider.truncate_path(
		full_path,
		segment_tags,
		_preview_budget
	)
	var budget_path: PackedVector3Array = truncated["path"] as PackedVector3Array
	var reachable_path: PackedVector3Array = _apply_clearance_limit(
		_preview_token,
		budget_path
	)
	if reachable_path.is_empty():
		return {}
	return {
		"full_path": full_path,
		"reachable_path": reachable_path,
		"cost": _rule_provider.calculate_path_cost(
			reachable_path,
			_build_segment_tags(reachable_path)
		),
		"full_cost": full_cost,
		"over_budget": full_cost > _preview_budget + 0.0001,
		"clearance_limited": reachable_path[-1].distance_to(budget_path[-1]) > 0.01,
	}


func _apply_preview_candidate(candidate: Dictionary) -> void:
	_preview_full_path = candidate["full_path"] as PackedVector3Array
	_preview_reachable_path = candidate["reachable_path"] as PackedVector3Array
	_preview_cost = float(candidate["cost"])
	_preview_over_budget = bool(candidate["over_budget"])


func commit_preview() -> bool:
	if _preview_token == null or not is_instance_valid(_preview_token):
		clear_preview()
		return false
	if _preview_reachable_path.size() < 2:
		clear_preview()
		return false
	_moving_token = _preview_token
	_moving_path = _preview_reachable_path.duplicate()
	_moving_path_index = 1
	_moving_speed = _calculate_follow_speed(_moving_path)
	clear_preview()
	set_process(true)
	return true


func pause_active_movement() -> void:
	_stop_path_following()
	clear_preview()


func is_movement_active() -> bool:
	return _moving_token != null and is_instance_valid(_moving_token)


func clear_preview() -> void:
	_preview_token = null
	_preview_budget = 0.0
	if _range_mesh != null:
		_range_mesh.clear_surfaces()
	clear_preview_path()


func clear_preview_path() -> void:
	_preview_full_path = PackedVector3Array()
	_preview_reachable_path = PackedVector3Array()
	_preview_cost = 0.0
	_preview_over_budget = false
	if _preview_mesh != null:
		_preview_mesh.clear_surfaces()


func is_navigation_ready() -> bool:
	return (
		_region != null
		and is_instance_valid(_region)
		and _navigation_map.is_valid()
		and NavigationServer3D.map_get_iteration_id(_navigation_map) > 0
	)


func get_preview_summary() -> Dictionary:
	return {
		"cost": _preview_cost,
		"budget": _preview_budget,
		"over_budget": _preview_over_budget,
	}


func _clear_navigation_runtime() -> void:
	clear_preview()
	_stop_path_following()
	_link_tags.clear()
	_traversal_volumes.clear()
	_navigation_link_specs.clear()
	_entity_local_bounds.clear()
	if _region != null and is_instance_valid(_region):
		for child: Node in _region.get_children():
			if child is NavigationLink3D:
				(child as NavigationLink3D).set_navigation_map(RID())
		_region.set_navigation_map(RID())
	for profile_value: Variant in _navigation_profiles.values():
		var profile: Dictionary = profile_value as Dictionary
		var uses_node_region: bool = bool(profile.get("uses_node_region", false))
		var region_rid: RID = profile.get("region", RID()) as RID
		if not uses_node_region and region_rid.is_valid():
			NavigationServer3D.free_rid(region_rid)
		var map_rid: RID = profile.get("map", RID()) as RID
		if map_rid.is_valid():
			NavigationServer3D.free_rid(map_rid)
	_navigation_profiles.clear()
	_source_geometry_data = null
	_active_profile_key = Vector2i(-1, -1)
	_navigation_map = RID()
	if _region != null and is_instance_valid(_region):
		remove_child(_region)
		_region.queue_free()
	_region = null


func _get_navigation_profile_key(radius: float, height: float) -> Vector2i:
	return Vector2i(
		maxi(1, ceili(maxf(radius, 0.1) / NAVIGATION_CELL_SIZE)),
		maxi(1, ceili(maxf(height, 0.2) / NAVIGATION_CELL_HEIGHT))
	)


func _create_navigation_mesh(profile_key: Vector2i, scene_size: Vector2) -> NavigationMesh:
	var navigation_mesh: NavigationMesh = NavigationMesh.new()
	navigation_mesh.agent_radius = float(profile_key.x) * NAVIGATION_CELL_SIZE
	navigation_mesh.agent_height = float(profile_key.y) * NAVIGATION_CELL_HEIGHT
	navigation_mesh.agent_max_climb = NAVIGATION_CELL_HEIGHT
	navigation_mesh.agent_max_slope = 45.0
	navigation_mesh.cell_size = NAVIGATION_CELL_SIZE
	navigation_mesh.cell_height = NAVIGATION_CELL_HEIGHT
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_mesh.geometry_collision_mask = SURFACE_LAYER_MASK
	navigation_mesh.filter_baking_aabb = AABB(
		Vector3(-scene_size.x * 0.5, -10.0, -scene_size.y * 0.5),
		Vector3(scene_size.x, 60.0, scene_size.y)
	)
	return navigation_mesh


func _create_navigation_profile(
		profile_key: Vector2i,
		scene_size: Vector2,
		uses_node_region: bool = false
) -> bool:
	if _navigation_profiles.has(profile_key):
		return true
	if _source_geometry_data == null or _region == null or not is_instance_valid(_region):
		return false
	var navigation_mesh: NavigationMesh = _create_navigation_mesh(profile_key, scene_size)
	NavigationServer3D.bake_from_source_geometry_data(
		navigation_mesh,
		_source_geometry_data
	)
	if navigation_mesh.get_polygon_count() == 0:
		return false
	var map_rid: RID = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(map_rid, true)
	NavigationServer3D.map_set_cell_size(map_rid, NAVIGATION_CELL_SIZE)
	NavigationServer3D.map_set_cell_height(map_rid, NAVIGATION_CELL_HEIGHT)
	NavigationServer3D.map_set_use_async_iterations(map_rid, false)
	NavigationServer3D.map_force_update(map_rid)
	var region_rid: RID = RID()
	if uses_node_region:
		_region.set_navigation_map(map_rid)
		_region.navigation_mesh = navigation_mesh
		region_rid = _region.get_rid()
	else:
		region_rid = NavigationServer3D.region_create()
		NavigationServer3D.region_set_map(region_rid, map_rid)
		NavigationServer3D.region_set_navigation_mesh(region_rid, navigation_mesh)
	NavigationServer3D.region_set_use_async_iterations(region_rid, false)
	_create_navigation_links_for_map(map_rid)
	NavigationServer3D.map_force_update(map_rid)
	_navigation_profiles[profile_key] = {
		"map": map_rid,
		"region": region_rid,
		"navigation_mesh": navigation_mesh,
		"uses_node_region": uses_node_region,
	}
	return NavigationServer3D.map_get_iteration_id(map_rid) > 0


func _activate_navigation_profile(profile_key: Vector2i) -> bool:
	if not _navigation_profiles.has(profile_key):
		if not _create_navigation_profile(profile_key, _scene_size):
			return false
	var profile: Dictionary = _navigation_profiles[profile_key] as Dictionary
	_navigation_map = profile["map"] as RID
	_active_profile_key = profile_key
	return NavigationServer3D.map_get_iteration_id(_navigation_map) > 0


func _activate_navigation_profile_for_token(token_root: Node3D) -> bool:
	var token_properties: TokenProperties = token_root.get_node_or_null(
		"TokenProperties") as TokenProperties
	if token_properties == null:
		return false
	var profile_key: Vector2i = _get_navigation_profile_key(
		token_properties.collision_radius,
		token_properties.collision_height
	)
	return _activate_navigation_profile(profile_key)


func _create_preview_renderer() -> void:
	_preview_mesh = ImmediateMesh.new()
	_preview_instance = MeshInstance3D.new()
	_preview_instance.name = "MovementPathPreview"
	_preview_instance.mesh = _preview_mesh
	_preview_instance.set_meta("gvtt_runtime_only", true)
	add_child(_preview_instance)
	_range_mesh = ImmediateMesh.new()
	_range_instance = MeshInstance3D.new()
	_range_instance.name = "MovementRangePreview"
	_range_instance.mesh = _range_mesh
	_range_instance.set_meta("gvtt_runtime_only", true)
	add_child(_range_instance)
	_valid_material = _create_line_material(Color(0.2, 0.95, 0.35, 1.0))
	_range_material = _create_line_material(Color(0.15, 0.7, 1.0, 1.0))


func _create_line_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	return material


func _draw_preview() -> void:
	_preview_mesh.clear_surfaces()
	if _preview_reachable_path.size() < 2:
		return
	_add_path_surface(_preview_reachable_path, _valid_material)


func _add_path_surface(path: PackedVector3Array, material: Material) -> void:
	if path.size() < 2:
		return
	_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for point: Vector3 in path:
		_preview_mesh.surface_add_vertex(point + Vector3.UP * PATH_HEIGHT_OFFSET)
	_preview_mesh.surface_end()


func _draw_range_ring() -> void:
	if _range_mesh == null:
		return
	_range_mesh.clear_surfaces()
	if _preview_token == null or not is_instance_valid(_preview_token):
		return
	var ring_points: PackedVector3Array = _build_range_ring_points(
		_preview_token.global_position,
		_preview_budget
	)
	ring_points = _snap_path_to_surfaces(ring_points)
	if ring_points.size() < 2:
		return
	_range_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _range_material)
	for point: Vector3 in ring_points:
		_range_mesh.surface_add_vertex(point + Vector3.UP * PATH_HEIGHT_OFFSET)
	_range_mesh.surface_end()


func _build_range_ring_points(center: Vector3, radius: float) -> PackedVector3Array:
	var ring_points: PackedVector3Array = PackedVector3Array()
	for segment_index: int in range(RANGE_RING_SEGMENTS + 1):
		var angle: float = TAU * float(segment_index) / float(RANGE_RING_SEGMENTS)
		ring_points.append(
			center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		)
	return ring_points


func _create_ground_surface(scene_size: Vector2) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "MovementGroundBody"
	body.collision_layer = SURFACE_LAYER_MASK
	body.collision_mask = 0
	_region.add_child(body)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var ground_mesh: PlaneMesh = PlaneMesh.new()
	ground_mesh.size = scene_size
	var ground_shape: ConcavePolygonShape3D = ground_mesh.create_trimesh_shape()
	shape_node.shape = ground_shape
	body.add_child(shape_node)


func _collect_runtime_geometry() -> void:
	for child: Node in _content_root.get_children():
		if not (child is Node3D):
			continue
		var entity_root: Node3D = child as Node3D
		var entity_properties: EntityProperties = _find_entity_properties(entity_root)
		if entity_properties == null:
			continue
		var entity_type: EntityProperties.EntityType = entity_properties.get_effective_entity_type()
		if entity_type in [
			EntityProperties.EntityType.TOKEN,
			EntityProperties.EntityType.LIGHT,
		]:
			continue
		if entity_type == EntityProperties.EntityType.WALL:
			var wall_properties: WallProperties = entity_root.get_node_or_null(
				"WallProperties"
			) as WallProperties
			if (
				wall_properties != null
				and wall_properties.wall_state == WallProperties.WallState.DESTROYED
			):
				continue
		var traversal: TraversalProperties = entity_root.get_node_or_null(
			"TraversalProperties") as TraversalProperties
		if traversal == null:
			continue
		var local_bounds: AABB = _get_cached_local_bounds(entity_root)
		var world_bounds: AABB = _get_world_bounds(entity_root)
		if traversal.is_walkable_surface():
			_create_entity_collision(entity_root, SURFACE_LAYER_MASK, false, local_bounds)
			if traversal.get_traversal_tag() != &"walkable" and world_bounds.has_volume():
				_traversal_volumes.append({
					"bounds": world_bounds,
					"tag": traversal.get_traversal_tag(),
				})
		else:
			var use_bounds_collision: bool = entity_type != EntityProperties.EntityType.TERRAIN
			_create_entity_collision(
				entity_root,
				BLOCKER_LAYER_MASK,
				use_bounds_collision,
				local_bounds
			)
			_create_navigation_obstacle(entity_root, local_bounds)
		if traversal.creates_navigation_link():
			_create_navigation_link(entity_root, traversal)


func _create_entity_collision(
		entity_root: Node3D,
		layer_mask: int,
		use_bounds_shape: bool,
		local_bounds: AABB
) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "MovementBody"
	body.set_meta("movement_entity_name", str(entity_root.name))
	body.collision_layer = layer_mask
	body.collision_mask = 0
	_region.add_child(body)
	if use_bounds_shape and local_bounds.has_volume():
		_add_bounds_collision(entity_root, local_bounds, body)
	else:
		_add_mesh_collisions(entity_root, body)
	if body.get_child_count() == 0:
		_region.remove_child(body)
		body.queue_free()


func _add_mesh_collisions(node: Node, body: StaticBody3D) -> void:
	if node.has_meta("gvtt_runtime_only"):
		return
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			var shape: ConcavePolygonShape3D = mesh_instance.mesh.create_trimesh_shape()
			if shape != null:
				var shape_node: CollisionShape3D = CollisionShape3D.new()
				shape_node.shape = shape
				body.add_child(shape_node)
				shape_node.global_transform = mesh_instance.global_transform
	for child: Node in node.get_children():
		_add_mesh_collisions(child, body)


func _add_bounds_collision(entity_root: Node3D, bounds: AABB, body: StaticBody3D) -> void:
	var root_basis: Basis = entity_root.global_transform.basis
	var rotation_basis: Basis = root_basis.orthonormalized()
	var root_scale: Vector3 = root_basis.get_scale().abs()
	var center_world_offset: Vector3 = root_basis * bounds.get_center()
	var center_body_offset: Vector3 = rotation_basis.inverse() * center_world_offset
	body.global_transform = Transform3D(rotation_basis, entity_root.global_position)
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(
		maxf(bounds.size.x * root_scale.x, 0.001),
		maxf(bounds.size.y * root_scale.y, 0.001),
		maxf(bounds.size.z * root_scale.z, 0.001)
	)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.shape = box_shape
	shape_node.position = center_body_offset
	body.add_child(shape_node)


func _create_navigation_obstacle(entity_root: Node3D, bounds: AABB) -> void:
	if not bounds.has_volume():
		return
	var obstacle: NavigationObstacle3D = NavigationObstacle3D.new()
	obstacle.name = "MovementObstacle"
	obstacle.affect_navigation_mesh = true
	obstacle.avoidance_enabled = false
	obstacle.height = maxf(bounds.size.y, 0.1)
	var min_x: float = bounds.position.x
	var max_x: float = bounds.end.x
	var min_z: float = bounds.position.z
	var max_z: float = bounds.end.z
	obstacle.vertices = PackedVector3Array([
		Vector3(min_x, 0.0, min_z),
		Vector3(max_x, 0.0, min_z),
		Vector3(max_x, 0.0, max_z),
		Vector3(min_x, 0.0, max_z),
	])
	_region.add_child(obstacle)
	var obstacle_transform: Transform3D = entity_root.global_transform
	obstacle_transform.origin = entity_root.global_transform * Vector3(
		0.0, bounds.position.y, 0.0)
	obstacle.global_transform = obstacle_transform


func _create_navigation_link(entity_root: Node3D, traversal: TraversalProperties) -> void:
	_navigation_link_specs.append({
		"bidirectional": traversal.link_bidirectional,
		"travel_cost": _rule_provider.get_traversal_cost_multiplier(
			traversal.get_traversal_tag()
		),
		"start": entity_root.global_transform * traversal.link_start,
		"end": entity_root.global_transform * traversal.link_end,
		"tag": traversal.get_traversal_tag(),
	})


func _create_navigation_links_for_map(map_rid: RID) -> void:
	for spec: Dictionary in _navigation_link_specs:
		var link: NavigationLink3D = NavigationLink3D.new()
		link.name = "MovementTraversalLink"
		link.bidirectional = bool(spec["bidirectional"])
		link.travel_cost = float(spec["travel_cost"])
		_region.add_child(link)
		link.set_navigation_map(map_rid)
		link.set_global_start_position(spec["start"] as Vector3)
		link.set_global_end_position(spec["end"] as Vector3)
		_link_tags[link.get_rid()] = spec["tag"] as StringName


func _screen_to_navigation_position(camera: Camera3D, screen_position: Vector2) -> Dictionary:
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_end: Vector3 = ray_origin + camera.project_ray_normal(screen_position) * TARGET_RAY_LENGTH
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ray_origin, ray_end, SURFACE_LAYER_MASK | BLOCKER_LAYER_MASK)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(
		_navigation_map, hit["position"] as Vector3)
	return {"position": closest}


func _build_segment_tags(path: PackedVector3Array) -> Array[StringName]:
	var tags: Array[StringName] = []
	for index: int in range(1, path.size()):
		var tag: StringName = &"walkable"
		if (
			index < _query_result.path_types.size()
			and _query_result.path_types[index] == NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK
			and index < _query_result.path_rids.size()
		):
			var path_rid: RID = _query_result.path_rids[index]
			if _link_tags.has(path_rid):
				tag = _link_tags[path_rid] as StringName
		else:
			tag = _tag_at_position(path[index - 1].lerp(path[index], 0.5))
		tags.append(tag)
	return tags


func _tag_at_position(world_position: Vector3) -> StringName:
	for entry: Dictionary in _traversal_volumes:
		var bounds: AABB = entry["bounds"] as AABB
		if bounds.has_point(world_position):
			return entry["tag"] as StringName
	return &"walkable"


func _apply_clearance_limit(token_root: Node3D, path: PackedVector3Array) -> PackedVector3Array:
	if path.size() < 2:
		return path
	var token_properties: TokenProperties = token_root.get_node_or_null(
		"TokenProperties") as TokenProperties
	if token_properties == null:
		return PackedVector3Array()
	var radius: float = maxf(token_properties.collision_radius, 0.1)
	var height: float = maxf(token_properties.collision_height, radius * 2.0)
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	var resolved: PackedVector3Array = PackedVector3Array([path[0]])
	for index: int in range(1, path.size()):
		var start: Vector3 = resolved[-1]
		var destination: Vector3 = path[index]
		var parameters: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		parameters.shape = capsule
		parameters.transform = Transform3D(Basis.IDENTITY, start + Vector3.UP * height * 0.5)
		parameters.motion = destination - start
		parameters.collision_mask = BLOCKER_LAYER_MASK
		parameters.collide_with_areas = false
		parameters.collide_with_bodies = true
		var cast_result: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(parameters)
		var safe_fraction: float = 1.0
		if not cast_result.is_empty():
			safe_fraction = cast_result[0]
		if safe_fraction < 0.999:
			if safe_fraction > 0.001:
				resolved.append(start.lerp(destination, safe_fraction))
			break
		resolved.append(destination)
	return resolved


func _snap_path_to_surfaces(path: PackedVector3Array) -> PackedVector3Array:
	var snapped_path: PackedVector3Array = PackedVector3Array()
	for path_point: Vector3 in path:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			path_point + Vector3.UP * 5.0,
			path_point + Vector3.DOWN * 10.0,
			SURFACE_LAYER_MASK
		)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			snapped_path.append(path_point)
		else:
			snapped_path.append(hit["position"] as Vector3)
	return snapped_path


func _find_entity_properties(entity_root: Node3D) -> EntityProperties:
	for child: Node in entity_root.get_children():
		if child is EntityProperties:
			return child as EntityProperties
	return null


func _get_world_bounds(root: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current.has_meta("gvtt_runtime_only"):
			continue
		if current is GeometryInstance3D:
			var geometry: GeometryInstance3D = current as GeometryInstance3D
			var local_bounds: AABB = geometry.get_aabb()
			for corner: Vector3 in _aabb_corners(local_bounds):
				var world_corner: Vector3 = geometry.global_transform * corner
				if not has_bounds:
					bounds = AABB(world_corner, Vector3.ZERO)
					has_bounds = true
				else:
					bounds = bounds.expand(world_corner)
		for child: Node in current.get_children():
			pending.append(child)
	return bounds


func _get_cached_local_bounds(root: Node3D) -> AABB:
	var instance_id: int = root.get_instance_id()
	if _entity_local_bounds.has(instance_id):
		return _entity_local_bounds[instance_id] as AABB
	var bounds: AABB = _get_local_bounds(root)
	_entity_local_bounds[instance_id] = bounds
	return bounds


func _get_local_bounds(root: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	var root_inverse: Transform3D = root.global_transform.affine_inverse()
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current.has_meta("gvtt_runtime_only"):
			continue
		if current is GeometryInstance3D:
			var geometry: GeometryInstance3D = current as GeometryInstance3D
			var geometry_bounds: AABB = geometry.get_aabb()
			for corner: Vector3 in _aabb_corners(geometry_bounds):
				var root_corner: Vector3 = root_inverse * (geometry.global_transform * corner)
				if not has_bounds:
					bounds = AABB(root_corner, Vector3.ZERO)
					has_bounds = true
				else:
					bounds = bounds.expand(root_corner)
		for child: Node in current.get_children():
			pending.append(child)
	return bounds


func _aabb_corners(bounds: AABB) -> Array[Vector3]:
	var corner_origin: Vector3 = bounds.position
	var size: Vector3 = bounds.size
	return [
		corner_origin,
		corner_origin + Vector3(size.x, 0.0, 0.0),
		corner_origin + Vector3(0.0, size.y, 0.0),
		corner_origin + Vector3(0.0, 0.0, size.z),
		corner_origin + Vector3(size.x, size.y, 0.0),
		corner_origin + Vector3(size.x, 0.0, size.z),
		corner_origin + Vector3(0.0, size.y, size.z),
		corner_origin + size,
	]


func _calculate_follow_speed(path: PackedVector3Array) -> float:
	var path_length: float = _calculate_path_length(path)
	return maxf(
		FOLLOW_SPEED_METERS_PER_SECOND,
		path_length / MAX_FOLLOW_DURATION_SECONDS
	)


func _calculate_path_length(path: PackedVector3Array) -> float:
	var path_length: float = 0.0
	for index: int in range(1, path.size()):
		path_length += path[index - 1].distance_to(path[index])
	return path_length


func _face_movement_direction(destination: Vector3) -> void:
	var facing_direction: Vector3 = destination - _moving_token.global_position
	facing_direction.y = 0.0
	if facing_direction.length_squared() <= MIN_FACING_DIRECTION_LENGTH_SQUARED:
		return
	_moving_token.look_at(
		_moving_token.global_position + facing_direction,
		Vector3.UP,
		true
	)


func _stop_path_following() -> void:
	_moving_token = null
	_moving_path = PackedVector3Array()
	_moving_path_index = 0
	_moving_speed = FOLLOW_SPEED_METERS_PER_SECOND
	set_process(false)

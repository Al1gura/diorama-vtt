extends Node3D

const SAVE_PATH: String = "user://p2_6_wall_destruction_test.scn"

var _assertion_count: int = 0
var _failures: Array[String] = []
var _wall_state_controller_script: GDScript = load(
	"res://scripts/wall_state_controller.gd"
)


func _ready() -> void:
	await get_tree().process_frame
	_check(
		_wall_state_controller_script != null,
		"WallStateController script is missing"
	)
	if _wall_state_controller_script != null:
		await _test_destroy_repair_runtime_contract()
		await _test_non_destructible_contract()
		await _test_movement_navigation_contract()
		await _test_persistence_contract()
	_cleanup_save_file()
	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
	}
	print("P2_6_WALL_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P2_6_WALL_FAILURES " + JSON.stringify(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_destroy_repair_runtime_contract() -> void:
	var content_root: Node3D = Node3D.new()
	content_root.name = "RuntimeContentRoot"
	add_child(content_root)
	var placement: PlacementController = _create_placement_controller(content_root)
	var wall: Node3D = _create_wall(
		content_root, placement, "RuntimeWall", Vector3(0.5, 2.0, 10.0)
	)
	var wall_properties: WallProperties = wall.get_node("WallProperties") as WallProperties
	wall_properties.destructible = true
	wall_properties.blocks_los = true
	wall_properties.blocks_shot = true
	var observer: Node3D = _create_observer(content_root, Vector3(-2.0, 0.0, 0.0))
	var los_service: LOSService = LOSService.new()
	los_service.name = "LOSService"
	add_child(los_service)
	los_service.configure(content_root, Vector2(10.0, 10.0))
	var controller: Node = _wall_state_controller_script.new() as Node
	controller.name = "WallStateController"
	add_child(controller)
	controller.call("sync_wall", wall)
	await get_tree().physics_frame
	var combat_body: CombatBody = wall.get_node("CombatBody") as CombatBody
	var los_occluder: LOSOccluder = wall.get_node("LOSOccluder") as LOSOccluder
	var blocked_before: Dictionary = CombatLineQuery.cast(
		get_world_3d(), Vector3(-4.0, 1.0, 0.0), Vector3(4.0, 1.0, 0.0)
	)
	var visible_before: PackedVector2Array = los_service.get_visible_polygon()
	_check(bool(blocked_before.get("blocked", false)), "Intact wall did not block shot")
	_check(
		not Geometry2D.is_point_in_polygon(Vector2(4.0, 0.0), visible_before),
		"Intact wall did not block LOS"
	)
	var recomputes_before: int = los_service.get_recompute_count()
	_check(bool(controller.call("destroy_wall", wall)), "Destructible wall was not destroyed")
	await get_tree().physics_frame
	_check(
		wall_properties.wall_state == WallProperties.WallState.DESTROYED,
		"Destroyed wall did not persist DESTROYED state"
	)
	_check(wall_properties.durability_current == 0, "Destroyed wall durability was not zero")
	_check(
		wall_properties.blocks_los and wall_properties.blocks_shot,
		"Destroying a wall overwrote its intact blocking configuration"
	)
	_check(
		not bool(wall_properties.call("get_effective_blocks_los"))
		and not bool(wall_properties.call("get_effective_blocks_shot")),
		"Destroyed wall still reported effective blocking"
	)
	_check(not wall.visible, "Destroyed wall intact visual remained visible")
	_check(
		bool(controller.call("sync_wall", wall, true)),
		"Destroyed wall could not apply its edit-mode visual override"
	)
	_check(
		wall.visible
		and wall_properties.wall_state == WallProperties.WallState.DESTROYED
		and combat_body.get_runtime_body().collision_layer == 0
		and los_occluder.get_world_segments().is_empty(),
		"Edit-mode wall visual override changed destroyed runtime semantics"
	)
	_check(
		bool(controller.call("sync_wall", wall, false)) and not wall.visible,
		"Destroyed wall visual override did not return to run-mode hiding"
	)
	_check(
		combat_body.get_runtime_body().collision_layer == 0,
		"Destroyed wall remained on the combat collision layer"
	)
	_check(
		los_occluder.get_world_segments().is_empty(),
		"Destroyed wall still exposed LOS segments"
	)
	var blocked_after: Dictionary = CombatLineQuery.cast(
		get_world_3d(), Vector3(-4.0, 1.0, 0.0), Vector3(4.0, 1.0, 0.0)
	)
	var visible_after: PackedVector2Array = los_service.get_visible_polygon()
	_check(not bool(blocked_after.get("blocked", true)), "Destroyed wall still blocked shot")
	_check(
		Geometry2D.is_point_in_polygon(Vector2(4.0, 0.0), visible_after),
		"Destroyed wall did not open LOS"
	)
	_check(
		los_service.get_recompute_count() > recomputes_before,
		"Destroying a wall did not trigger LOS recomputation"
	)
	_check(
		not bool(controller.call("destroy_wall", wall)),
		"Destroying an already destroyed wall was not idempotent"
	)
	_check(bool(controller.call("repair_wall", wall)), "Destroyed wall was not repaired")
	await get_tree().physics_frame
	_check(
		wall_properties.wall_state == WallProperties.WallState.INTACT
		and wall_properties.durability_current == wall_properties.durability_max,
		"Repair did not restore intact state and durability"
	)
	_check(wall.visible, "Repaired wall visual remained hidden")
	_check(
		combat_body.get_runtime_body().collision_layer
			== GvttRenderLayers.COMBAT_PHYSICS_MASK,
		"Repaired wall did not restore combat blocking"
	)
	_check(los_occluder.get_world_segments().size() == 4, "Repair did not restore LOS blocking")

	wall_properties.set_blocks_los(false)
	controller.call("sync_wall", wall)
	_check(bool(controller.call("destroy_wall", wall)), "Glass-like wall was not destroyed")
	_check(bool(controller.call("repair_wall", wall)), "Glass-like wall was not repaired")
	_check(
		not wall_properties.blocks_los
		and not bool(wall_properties.call("get_effective_blocks_los"))
		and bool(wall_properties.call("get_effective_blocks_shot")),
		"Repair overwrote independent LOS and shot blocking semantics"
	)
	_remove_now(controller)
	_remove_now(los_service)
	_remove_now(placement)
	_remove_now(content_root)
	await get_tree().process_frame
	_check(not is_instance_valid(observer), "Observer leaked after runtime contract cleanup")


func _test_non_destructible_contract() -> void:
	var content_root: Node3D = Node3D.new()
	content_root.name = "LockedContentRoot"
	add_child(content_root)
	var placement: PlacementController = _create_placement_controller(content_root)
	var wall: Node3D = _create_wall(
		content_root, placement, "LockedWall", Vector3(2.0, 2.0, 0.5)
	)
	var wall_properties: WallProperties = wall.get_node("WallProperties") as WallProperties
	wall_properties.destructible = false
	var controller: Node = _wall_state_controller_script.new() as Node
	add_child(controller)
	_check(
		not bool(controller.call("destroy_wall", wall)),
		"Non-destructible wall accepted destruction"
	)
	_check(
		wall_properties.wall_state == WallProperties.WallState.INTACT
		and wall.visible,
		"Rejected destruction still changed the wall"
	)
	_remove_now(controller)
	_remove_now(placement)
	_remove_now(content_root)
	await get_tree().process_frame


func _test_movement_navigation_contract() -> void:
	var content_root: Node3D = Node3D.new()
	content_root.name = "MovementContentRoot"
	add_child(content_root)
	var placement: PlacementController = _create_placement_controller(content_root)
	var wall: Node3D = _create_wall(
		content_root, placement, "MovementWall", Vector3(1.0, 2.0, 8.0)
	)
	var wall_properties: WallProperties = wall.get_node("WallProperties") as WallProperties
	wall_properties.destructible = true
	var token: Node3D = _create_movement_token(
		content_root, "MovementToken", Vector3(-4.0, 0.0, 0.0)
	)
	var token_properties: TokenProperties = token.get_node("TokenProperties") as TokenProperties
	var controller: Node = _wall_state_controller_script.new() as Node
	controller.name = "MovementWallStateController"
	add_child(controller)
	controller.call("sync_wall", wall)
	var movement_service: MovementService = MovementService.new()
	movement_service.name = "MovementService"
	add_child(movement_service)
	var rule_provider: MovementRuleProvider = CprMovementRuleProvider.new()
	_check(
		movement_service.rebuild(content_root, Vector2(20.0, 20.0), rule_provider),
		"Intact-wall movement navigation failed to build"
	)
	var target_position: Vector3 = Vector3(4.0, 0.0, 0.0)
	var intact_route: Dictionary = movement_service.preview_to_world_position(
		token, target_position
	)
	_check(not intact_route.is_empty(), "Intact wall left no route around its ends")
	var intact_cost: float = INF
	if not intact_route.is_empty():
		intact_cost = float(intact_route["full_cost"])
		_check(intact_cost > 8.5, "Intact wall did not force a movement detour")
	_check(
		_count_movement_blockers(movement_service) == 1,
		"Intact wall did not create exactly one movement physics blocker"
	)
	_check(
		_count_movement_obstacles(movement_service) == 1,
		"Intact wall did not create exactly one navigation obstacle"
	)

	token_properties.collision_radius = 0.9
	token_properties.collision_height = 2.4
	movement_service.clear_preview()
	movement_service.preview_to_world_position(token, target_position)
	var intact_profiles: Dictionary = movement_service.get("_navigation_profiles") as Dictionary
	var large_profile_key: Vector2i = Vector2i(9, 10)
	_check(
		intact_profiles.has(large_profile_key),
		"Large Token did not create its intact-wall navigation profile"
	)
	var intact_large_profile: Dictionary = intact_profiles.get(
		large_profile_key, {}
	) as Dictionary
	var intact_large_map: RID = intact_large_profile.get("map", RID()) as RID
	token_properties.collision_radius = 0.45
	token_properties.collision_height = 1.8
	movement_service.clear_preview()
	_check(
		bool(controller.call("destroy_wall", wall)),
		"Movement test wall could not be destroyed"
	)
	_check(
		movement_service.rebuild(content_root, Vector2(20.0, 20.0), rule_provider),
		"Destroyed-wall movement navigation failed to rebuild"
	)
	var reset_profiles: Dictionary = movement_service.get("_navigation_profiles") as Dictionary
	_check(
		reset_profiles.size() == 1 and not reset_profiles.has(large_profile_key),
		"Destroyed-wall rebuild retained stale Token profiles"
	)
	_check(
		movement_service.get("_preview_token") == null
		and movement_service.get("_moving_token") == null,
		"Destroyed-wall rebuild retained an active preview or movement path"
	)
	var destroyed_route: Dictionary = movement_service.preview_to_world_position(
		token, target_position
	)
	_check(not destroyed_route.is_empty(), "Destroyed wall did not open a movement route")
	var destroyed_cost: float = INF
	if not destroyed_route.is_empty():
		destroyed_cost = float(destroyed_route["full_cost"])
		var destroyed_endpoint: Vector3 = destroyed_route["endpoint"] as Vector3
		_check(
			destroyed_cost < intact_cost - 0.5,
			"Destroyed wall route still used the intact-wall detour"
		)
		_check(
			destroyed_endpoint.distance_to(target_position) < 0.25,
			"Destroyed wall route stopped at a stale movement physics blocker"
		)
	_check(
		_count_movement_blockers(movement_service) == 0,
		"Destroyed wall retained a MovementBody physics blocker"
	)
	_check(
		_count_movement_obstacles(movement_service) == 0,
		"Destroyed wall retained a navigation obstacle"
	)

	token_properties.collision_radius = 0.9
	token_properties.collision_height = 2.4
	movement_service.clear_preview()
	var large_destroyed_route: Dictionary = movement_service.preview_to_world_position(
		token, target_position
	)
	_check(
		not large_destroyed_route.is_empty()
		and float(large_destroyed_route["full_cost"]) < intact_cost - 0.5,
		"Large Token profile retained destroyed-wall navigation geometry"
	)
	var destroyed_profiles: Dictionary = movement_service.get("_navigation_profiles") as Dictionary
	var destroyed_large_profile: Dictionary = destroyed_profiles.get(
		large_profile_key, {}
	) as Dictionary
	var destroyed_large_map: RID = destroyed_large_profile.get("map", RID()) as RID
	_check(
		destroyed_profiles.has(large_profile_key)
		and destroyed_large_map.is_valid()
		and destroyed_large_map != intact_large_map,
		"Large Token profile was not rebuilt from fresh geometry"
	)
	token_properties.collision_radius = 0.45
	token_properties.collision_height = 1.8
	movement_service.clear_preview()
	_check(bool(controller.call("repair_wall", wall)), "Movement test wall could not be repaired")
	_check(
		movement_service.rebuild(content_root, Vector2(20.0, 20.0), rule_provider),
		"Repaired-wall movement navigation failed to rebuild"
	)
	var repaired_route: Dictionary = movement_service.preview_to_world_position(
		token, target_position
	)
	_check(not repaired_route.is_empty(), "Repaired wall left no route around its ends")
	if not repaired_route.is_empty():
		_check(
			float(repaired_route["full_cost"]) > destroyed_cost + 0.5,
			"Repair did not restore the wall movement detour"
		)
	_check(
		_count_movement_blockers(movement_service) == 1
		and _count_movement_obstacles(movement_service) == 1,
		"Repair did not restore exactly one movement blocker and obstacle"
	)
	_remove_now(movement_service)
	_remove_now(controller)
	_remove_now(placement)
	_remove_now(content_root)
	await get_tree().process_frame


func _test_persistence_contract() -> void:
	_cleanup_save_file()
	var content_root: Node3D = Node3D.new()
	content_root.name = "PersistentContentRoot"
	add_child(content_root)
	var placement: PlacementController = _create_placement_controller(content_root)
	var wall: Node3D = _create_wall(
		content_root, placement, "PersistentWall", Vector3(2.0, 2.0, 0.5), true
	)
	var wall_properties: WallProperties = wall.get_node("WallProperties") as WallProperties
	wall_properties.destructible = true
	wall_properties.blocks_los = true
	wall_properties.blocks_shot = true
	var controller: Node = _wall_state_controller_script.new() as Node
	add_child(controller)
	_check(bool(controller.call("destroy_wall", wall)), "Persistent wall was not destroyed")
	var save_error: int = ModuleIo.save_scene_tree(content_root, SAVE_PATH)
	_check(save_error == OK, "Destroyed wall scene failed to save")
	var loaded_root: Node = ModuleIo.load_scene_tree(SAVE_PATH)
	_check(loaded_root is Node3D, "Destroyed wall scene failed to load")
	if not (loaded_root is Node3D):
		_remove_now(controller)
		_remove_now(placement)
		_remove_now(content_root)
		return
	_remove_now(placement)
	_remove_now(content_root)
	add_child(loaded_root)
	var loaded_wall: Node3D = loaded_root.get_node("PersistentWall") as Node3D
	controller.call("sync_wall", loaded_wall)
	await get_tree().physics_frame
	var loaded_properties: WallProperties = loaded_wall.get_node(
		"WallProperties"
	) as WallProperties
	var loaded_combat: CombatBody = loaded_wall.get_node("CombatBody") as CombatBody
	var loaded_los: LOSOccluder = loaded_wall.get_node("LOSOccluder") as LOSOccluder
	_check(
		loaded_properties.wall_state == WallProperties.WallState.DESTROYED
		and loaded_properties.durability_current == 0,
		"Destroyed wall state did not survive save and load"
	)
	_check(
		loaded_properties.blocks_los and loaded_properties.blocks_shot,
		"Save and load overwrote intact blocking configuration"
	)
	_check(not loaded_wall.visible, "Loaded destroyed wall visual became visible")
	_check(
		loaded_combat.get_runtime_body().collision_layer == 0,
		"Loaded destroyed wall restored combat blocking"
	)
	_check(
		loaded_los.get_world_segments().is_empty(),
		"Loaded destroyed wall restored LOS blocking"
	)
	var loaded_root_3d: Node3D = loaded_root as Node3D
	var loaded_token: Node3D = _create_movement_token(
		loaded_root_3d, "LoadedMovementToken", Vector3(-4.0, 0.0, 0.0)
	)
	var loaded_movement: MovementService = MovementService.new()
	loaded_movement.name = "LoadedMovementService"
	add_child(loaded_movement)
	var loaded_provider: MovementRuleProvider = CprMovementRuleProvider.new()
	_check(
		loaded_movement.rebuild(loaded_root_3d, Vector2(20.0, 20.0), loaded_provider),
		"Loaded destroyed-wall movement navigation failed to build"
	)
	var loaded_route: Dictionary = loaded_movement.preview_to_world_position(
		loaded_token, Vector3(4.0, 0.0, 0.0)
	)
	_check(
		not loaded_route.is_empty() and float(loaded_route["full_cost"]) < 8.5,
		"Loaded destroyed wall returned as a navigation detour"
	)
	_check(
		_count_movement_blockers(loaded_movement) == 0
		and _count_movement_obstacles(loaded_movement) == 0,
		"Loaded destroyed wall regenerated movement blocking nodes"
	)
	_remove_now(loaded_movement)
	_check(bool(controller.call("repair_wall", loaded_wall)), "Loaded wall could not be repaired")
	await get_tree().physics_frame
	_check(
		loaded_wall.visible
		and loaded_combat.get_runtime_body().collision_layer
			== GvttRenderLayers.COMBAT_PHYSICS_MASK
		and loaded_los.get_world_segments().size() == 4,
		"Loaded wall repair did not restore runtime components"
	)
	_remove_now(loaded_root)
	_remove_now(controller)
	await get_tree().process_frame


func _create_placement_controller(content_root: Node3D) -> PlacementController:
	var controller: PlacementController = PlacementController.new()
	add_child(controller)
	controller.configure(
		self,
		content_root,
		null,
		null,
		{},
		{},
		{},
		[],
		load("res://scripts/token_properties.gd") as GDScript,
		load("res://scripts/wall_properties.gd") as GDScript,
		load("res://scripts/combat_body.gd") as GDScript,
		load("res://scripts/light_properties.gd") as GDScript,
		load("res://scripts/interactable_properties.gd") as GDScript,
		load("res://scripts/traversal_properties.gd") as GDScript,
		load("res://scripts/cpr_token_properties.gd") as GDScript,
		load("res://scripts/los_occluder.gd") as GDScript
	)
	return controller


func _create_wall(
		content_root: Node3D,
		placement: PlacementController,
		wall_name: String,
		size: Vector3,
		persistent: bool = false
) -> Node3D:
	var wall: Node3D = Node3D.new()
	wall.name = wall_name
	content_root.add_child(wall)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "WallVisual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position.y = size.y * 0.5
	wall.add_child(mesh_instance)
	var entity_properties: EntityProperties = EntityProperties.new()
	entity_properties.name = "EntityProperties"
	entity_properties.configure_from_category("wall")
	wall.add_child(entity_properties)
	if persistent:
		wall.set_owner(content_root)
		mesh_instance.set_owner(content_root)
		entity_properties.set_owner(content_root)
	placement.attach_entity_type_properties(wall, entity_properties)
	wall.force_update_transform()
	placement.sync_combat_body(wall)
	placement.sync_los_occluder(wall)
	return wall


func _create_observer(content_root: Node3D, position: Vector3) -> Node3D:
	var observer: Node3D = Node3D.new()
	observer.name = "ObserverToken"
	observer.position = position
	var token_properties: TokenProperties = TokenProperties.new()
	token_properties.name = "TokenProperties"
	observer.add_child(token_properties)
	content_root.add_child(observer)
	return observer


func _create_movement_token(
		content_root: Node3D,
		token_name: String,
		position: Vector3
) -> Node3D:
	var token: Node3D = Node3D.new()
	token.name = token_name
	token.position = position
	content_root.add_child(token)
	var entity_properties: EntityProperties = EntityProperties.new()
	entity_properties.name = "EntityProperties"
	entity_properties.configure_from_category("token")
	token.add_child(entity_properties)
	var token_properties: TokenProperties = TokenProperties.new()
	token_properties.name = "TokenProperties"
	token.add_child(token_properties)
	var cpr_properties: CprTokenProperties = CprTokenProperties.new()
	cpr_properties.name = "CprTokenProperties"
	cpr_properties.move_stat = 20
	token.add_child(cpr_properties)
	var traversal: TraversalProperties = TraversalProperties.new()
	traversal.name = "TraversalProperties"
	traversal.configure_for_entity_type(EntityProperties.EntityType.TOKEN)
	token.add_child(traversal)
	return token


func _count_movement_blockers(movement_service: MovementService) -> int:
	var region: NavigationRegion3D = movement_service.get("_region") as NavigationRegion3D
	if region == null:
		return 0
	var count: int = 0
	for child: Node in region.get_children():
		if child is StaticBody3D and (child as StaticBody3D).collision_layer == MovementService.BLOCKER_LAYER_MASK:
			count += 1
	return count


func _count_movement_obstacles(movement_service: MovementService) -> int:
	var region: NavigationRegion3D = movement_service.get("_region") as NavigationRegion3D
	if region == null:
		return 0
	var count: int = 0
	for child: Node in region.get_children():
		if child is NavigationObstacle3D:
			count += 1
	return count


func _cleanup_save_file() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)


func _remove_now(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.free()


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)

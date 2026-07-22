extends Node3D

var _assertion_count: int = 0
var _failures: Array[String] = []
var _combat_line_preview_script: GDScript = load("res://scripts/combat_line_preview.gd")


func _ready() -> void:
	await get_tree().process_frame
	_test_shared_geometry_contract()
	await _test_combat_query_contract()
	await _test_target_preview_contract()
	await _test_placement_integration()
	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
	}
	print("P2_4_COMBAT_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P2_4_COMBAT_FAILURES " + JSON.stringify(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_shared_geometry_contract() -> void:
	var bounds: AABB = AABB(Vector3(-2.0, 0.0, -0.25), Vector3(4.0, 2.0, 0.5))
	var footprint: PackedVector2Array = OcclusionGeometry.get_local_ground_footprint(bounds)
	_check(footprint.size() == 4, "Occlusion geometry did not expose a four-corner footprint")
	_check(
		footprint[0].is_equal_approx(Vector2(-2.0, -0.25)),
		"Occlusion geometry footprint did not preserve local bounds"
	)
	_check(
		GvttRenderLayers.COMBAT_PHYSICS_LAYER != GvttRenderLayers.PICK_PHYSICS_LAYER,
		"Combat and PickProxy physics layers are not independent"
	)


func _test_combat_query_contract() -> void:
	var pick_area: Area3D = _create_pick_area()
	await get_tree().physics_frame
	var pick_only_result: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		Vector3(0.0, 1.0, -3.0),
		Vector3(0.0, 1.0, 3.0)
	)
	_check(
		not bool(pick_only_result["blocked"]),
		"Combat query incorrectly hit a PickProxy Area3D"
	)
	_remove_now(pick_area)

	var wall: Node3D = _create_wall(Vector3(4.0, 2.0, 0.5))
	var combat_body: CombatBody = wall.get_node("CombatBody") as CombatBody
	await get_tree().physics_frame
	var center_hit: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		Vector3(0.0, 1.0, -3.0),
		Vector3(0.0, 1.0, 3.0)
	)
	_check(bool(center_hit["blocked"]), "Combat query did not hit the wall center")
	_check(center_hit["entity"] == wall, "Combat query did not return the wall entity root")
	_check(
		combat_body.get_runtime_body().collision_layer
			== GvttRenderLayers.COMBAT_PHYSICS_MASK,
		"CombatBody was not registered on the dedicated combat layer"
	)
	_check(
		combat_body.get_runtime_body().collision_mask == 0,
		"CombatBody unexpectedly scans other physics layers"
	)
	var side_result: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		Vector3(3.0, 1.0, -3.0),
		Vector3(3.0, 1.0, 3.0)
	)
	_check(not bool(side_result["blocked"]), "Combat query blocked a clear side line")

	wall.scale = Vector3(2.0, 1.0, 0.5)
	wall.force_update_transform()
	combat_body.sync_transform_from_target()
	var scaled_size: Vector3 = combat_body.get_runtime_shape().size
	_check(
		scaled_size.is_equal_approx(Vector3(8.0, 2.0, 0.25)),
		"CombatBody did not bake entity scale into BoxShape3D.size"
	)
	_check(
		combat_body.get_runtime_body().scale.is_equal_approx(Vector3.ONE),
		"Combat physics body inherited non-uniform scale"
	)
	wall.scale = Vector3.ONE
	wall.rotation.y = PI * 0.25
	wall.force_update_transform()
	combat_body.sync_transform_from_target()
	await get_tree().physics_frame
	var rotated_clear_from: Vector3 = wall.global_transform * Vector3(2.2, 1.0, -3.0)
	var rotated_clear_to: Vector3 = wall.global_transform * Vector3(2.2, 1.0, 3.0)
	var rotated_aabb_false_positive: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		rotated_clear_from,
		rotated_clear_to
	)
	_check(
		not bool(rotated_aabb_false_positive["blocked"]),
		"Rotated CombatBody behaved like an enlarged world-axis AABB"
	)
	var rotated_center_hit: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		Vector3(0.0, 1.0, -3.0),
		Vector3(0.0, 1.0, 3.0)
	)
	_check(bool(rotated_center_hit["blocked"]), "Rotated CombatBody missed its center")
	combat_body.set_provides_full_cover(true)
	await get_tree().physics_frame
	var rotated_high_clear: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		rotated_clear_from + Vector3.UP * 4.0,
		rotated_clear_to + Vector3.UP * 4.0
	)
	_check(
		not bool(rotated_high_clear["blocked"]),
		"Rotated abstract footprint behaved like an enlarged world-axis AABB"
	)
	var rotated_high_center_hit: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		Vector3(0.0, 5.0, -3.0),
		Vector3(0.0, 5.0, 3.0)
	)
	_check(
		bool(rotated_high_center_hit["blocked"])
		and bool(rotated_high_center_hit.get("abstract_cover", false)),
		"Rotated abstract footprint missed its center at high ray height"
	)
	combat_body.set_provides_full_cover(false)

	combat_body.set_blocks_shot(false)
	await get_tree().physics_frame
	var disabled_result: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		Vector3(0.0, 1.0, -3.0),
		Vector3(0.0, 1.0, 3.0)
	)
	_check(not bool(disabled_result["blocked"]), "blocks_shot=false still blocked the line")
	combat_body.set_blocks_shot(true)
	await get_tree().physics_frame
	_remove_now(wall)
	await get_tree().physics_frame
	var freed_result: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		Vector3(0.0, 1.0, -3.0),
		Vector3(0.0, 1.0, 3.0)
	)
	_check(not bool(freed_result["blocked"]), "Freed CombatBody left a physics blocker behind")


func _test_placement_integration() -> void:
	var scene_root: Node3D = Node3D.new()
	var content_root: Node3D = Node3D.new()
	add_child(scene_root)
	scene_root.add_child(content_root)
	var controller: PlacementController = PlacementController.new()
	add_child(controller)
	controller.configure(
		scene_root,
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
		load("res://scripts/cpr_token_properties.gd") as GDScript
	)
	var wall: Node3D = Node3D.new()
	content_root.add_child(wall)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(2.0, 2.0, 0.4)
	mesh_instance.mesh = mesh
	wall.add_child(mesh_instance)
	var props: EntityProperties = EntityProperties.new()
	props.configure_from_category("wall")
	wall.add_child(props)
	controller.attach_entity_type_properties(wall, props)
	var combat_body: CombatBody = wall.get_node_or_null("CombatBody") as CombatBody
	_check(combat_body != null, "PlacementController did not attach CombatBody to a wall")
	_check(
		combat_body != null and combat_body.geometry_fitted,
		"PlacementController attached CombatBody without fitting model geometry"
	)
	_check(
		wall.get_node_or_null("WallProperties") != null,
		"PlacementController lost WallProperties while attaching CombatBody"
	)
	var terrain: Node3D = Node3D.new()
	terrain.position = Vector3(5.0, 0.0, 0.0)
	content_root.add_child(terrain)
	var terrain_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var terrain_mesh: BoxMesh = BoxMesh.new()
	terrain_mesh.size = Vector3(4.7, 1.47, 2.08)
	terrain_mesh_instance.mesh = terrain_mesh
	terrain_mesh_instance.position.y = terrain_mesh.size.y * 0.5
	terrain.add_child(terrain_mesh_instance)
	var terrain_props: EntityProperties = EntityProperties.new()
	terrain_props.name = "EntityProperties"
	terrain_props.configure_from_category("terrain")
	terrain.add_child(terrain_props)
	controller.attach_entity_type_properties(terrain, terrain_props)
	var terrain_combat_body: CombatBody = terrain.get_node_or_null("CombatBody") as CombatBody
	_check(
		terrain_combat_body != null and terrain_combat_body.geometry_fitted,
		"PlacementController did not attach an approximate CombatBody to terrain scenery"
	)
	if terrain_combat_body != null:
		_check(
			terrain_combat_body.get_local_bounds().size.is_equal_approx(terrain_mesh.size),
			"Terrain CombatBody did not use an independent visual-bounds box"
		)
	await get_tree().physics_frame
	_check(
		terrain_combat_body != null
		and terrain_combat_body.provides_full_cover
		and is_equal_approx(
			terrain_combat_body.get_runtime_shape().size.y,
			terrain_mesh.size.y
		),
		"Automatic cover changed the real CombatBody runtime height"
	)
	var terrain_center_result: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		Vector3(5.0, 0.75, -3.0),
		Vector3(5.0, 0.75, 3.0)
	)
	_check(
		bool(terrain_center_result.get("blocked", false))
		and terrain_center_result.get("entity", null) == terrain,
		"Approximate terrain CombatBody did not block through its whole visual-bounds box"
	)
	var terrain_eye_result: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		Vector3(5.0, 1.6, -3.0),
		Vector3(5.0, 1.6, 3.0)
	)
	_check(
		bool(terrain_eye_result.get("blocked", false))
		and terrain_eye_result.get("entity", null) == terrain,
		"Low full-cover scenery did not block a standard standing-eye combat line"
	)
	var terrain_high_result: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		Vector3(5.0, 5.0, -3.0),
		Vector3(5.0, 5.0, 3.0)
	)
	_check(
		bool(terrain_high_result.get("blocked", false))
		and terrain_high_result.get("entity", null) == terrain
		and bool(terrain_high_result.get("abstract_cover", false)),
		"Automatic cover footprint did not block a high combat test line"
	)
	var original_terrain_height: float = terrain_mesh.size.y
	terrain.scale.y = 0.99 / original_terrain_height
	terrain.force_update_transform()
	controller.sync_combat_body(terrain)
	await get_tree().physics_frame
	_check(
		terrain_combat_body != null and not terrain_combat_body.provides_full_cover,
		"Height below one meter still became automatic cover"
	)
	_check(
		terrain_combat_body != null
		and is_equal_approx(terrain_combat_body.get_runtime_shape().size.y, 0.99),
		"Height below one meter did not keep the real runtime height"
	)
	_check(
		terrain_combat_body != null
		and terrain_combat_body.get_runtime_body().collision_layer == 0,
		"Height below one meter did not remove the object from the combat layer"
	)
	terrain.scale.y = 1.0 / original_terrain_height
	terrain.force_update_transform()
	controller.sync_combat_body(terrain)
	await get_tree().physics_frame
	_check(
		terrain_combat_body != null
		and not terrain_combat_body.provides_full_cover
		and terrain_combat_body.get_runtime_body().collision_layer == 0,
		"Height exactly one meter should not become automatic cover"
	)
	terrain.scale.y = 1.01 / original_terrain_height
	terrain.force_update_transform()
	controller.sync_combat_body(terrain)
	await get_tree().physics_frame
	_check(
		terrain_combat_body != null
		and terrain_combat_body.provides_full_cover
		and terrain_combat_body.get_runtime_body().collision_layer
			== GvttRenderLayers.COMBAT_PHYSICS_MASK,
		"Height above one meter did not become automatic cover"
	)
	var threshold_high_result: Dictionary = CombatLineQuery.cast(
		get_world_3d(),
		Vector3(5.0, 5.0, -3.0),
		Vector3(5.0, 5.0, 3.0)
	)
	_check(
		bool(threshold_high_result.get("blocked", false))
		and bool(threshold_high_result.get("abstract_cover", false)),
		"Height above one meter did not block through the footprint at high ray height"
	)
	var token: Node3D = Node3D.new()
	content_root.add_child(token)
	var token_entity_props: EntityProperties = EntityProperties.new()
	token_entity_props.configure_from_category("token")
	token.add_child(token_entity_props)
	controller.attach_entity_type_properties(token, token_entity_props)
	_check(
		token.get_node_or_null("CombatLineProbe") == null,
		"PlacementController still attached a persistent combat probe to a Token"
	)
	_check(
		token.get_node_or_null("CombatBody") == null,
		"PlacementController incorrectly made a Token an automatic combat blocker"
	)
	var light_root: Node3D = Node3D.new()
	content_root.add_child(light_root)
	var light_entity_props: EntityProperties = EntityProperties.new()
	light_entity_props.configure_from_category("light")
	light_root.add_child(light_entity_props)
	controller.attach_entity_type_properties(light_root, light_entity_props)
	_check(
		light_root.get_node_or_null("CombatBody") == null,
		"PlacementController incorrectly made a light an automatic combat blocker"
	)
	_remove_now(controller)
	_remove_now(scene_root)
	await get_tree().physics_frame


func _test_target_preview_contract() -> void:
	var shooter: Node3D = _create_token("Shooter", Vector3.ZERO)
	var target: Node3D = _create_token("Target", Vector3(0.0, 0.0, 3.0))
	var intermediate_token: Node3D = _create_token(
		"IntermediateToken", Vector3(0.0, 0.0, 1.5)
	)
	var preview: Node3D = _combat_line_preview_script.new() as Node3D
	preview.name = "CombatLinePreview"
	add_child(preview)
	await get_tree().physics_frame
	_check(
		shooter.get_node_or_null("CombatLineProbe") == null
		and target.get_node_or_null("CombatLineProbe") == null,
		"Two Tokens still created persistent per-Token combat lines"
	)
	_check(
		preview.get_parent() == self and not shooter.is_ancestor_of(preview),
		"Combat line preview was placed inside the shooter subtree"
	)
	var line_instance: MeshInstance3D = preview.call("get_line_instance") as MeshInstance3D
	_check(
		line_instance.layers == 1 << (GvttRenderLayers.RENDER_LAYER_GM_ONLY - 1),
		"Combat line preview was not restricted to the GM-only render layer"
	)
	_check(
		bool(preview.get_meta("gvtt_runtime_only", false))
		and bool(line_instance.get_meta("gvtt_runtime_only", false)),
		"Combat line preview runtime nodes were not marked runtime-only"
	)

	var wall: Node3D = _create_wall(Vector3(2.0, 2.0, 0.5))
	wall.position = Vector3(0.0, 0.0, 5.0)
	wall.force_update_transform()
	var combat_body: CombatBody = wall.get_node("CombatBody") as CombatBody
	combat_body.sync_transform_from_target()
	await get_tree().physics_frame
	var target_point: Vector3 = _get_token_aim_point(target)
	var behind_target_result: Dictionary = preview.call(
		"show_preview", shooter, target_point, target
	) as Dictionary
	_check(
		not bool(behind_target_result.get("blocked", true)),
		"A wall behind the explicit target incorrectly blocked the target line"
	)
	_check(
		(preview.call("get_last_target") as Vector3).is_equal_approx(target_point),
		"Combat preview did not preserve the explicit target endpoint"
	)

	wall.position = Vector3(0.0, 0.0, 2.0)
	wall.force_update_transform()
	combat_body.sync_transform_from_target()
	await get_tree().physics_frame
	var before_target_result: Dictionary = preview.call(
		"show_preview", shooter, target_point, target
	) as Dictionary
	_check(
		bool(before_target_result.get("blocked", false)),
		"A wall before the explicit target was not reported as a blocker"
	)
	var hit_position: Vector3 = before_target_result.get("position", target_point) as Vector3
	_check(
		hit_position.z > 1.0 and hit_position.z < target_point.z,
		"The blocker result was not located before the explicit target"
	)
	_remove_now(wall)
	await get_tree().physics_frame
	var token_only_result: Dictionary = preview.call(
		"show_preview", shooter, target_point, target
	) as Dictionary
	_check(
		not bool(token_only_result.get("blocked", true)),
		"An intermediate Token incorrectly became combat cover by default"
	)
	var visual_token: Node3D = _create_token("VisualToken", Vector3(2.0, 0.0, 0.0))
	var visual_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var visual_mesh: BoxMesh = BoxMesh.new()
	visual_mesh.size = Vector3(0.8, 1.8, 0.8)
	visual_mesh_instance.mesh = visual_mesh
	visual_mesh_instance.position.y = 0.9
	visual_token.add_child(visual_mesh_instance)
	visual_token.force_update_transform()
	var visual_eye: Vector3 = preview.call("get_entity_aim_point", visual_token) as Vector3
	_check(
		is_equal_approx(visual_eye.y, 1.6),
		"Combat preview eye point was not one ninth below the visual model top"
	)
	var aim_camera: Camera3D = Camera3D.new()
	add_child(aim_camera)
	aim_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	aim_camera.size = 10.0
	aim_camera.global_position = visual_eye + Vector3.UP * 10.0
	aim_camera.global_rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	await get_tree().process_frame
	var eye_screen_position: Vector2 = aim_camera.unproject_position(visual_eye)
	var requested_screen_delta: Vector2 = Vector2(80.0, 30.0)
	var free_aim_direction: Vector3 = _combat_line_preview_script.call(
		"get_screen_aim_direction",
		aim_camera,
		visual_eye,
		eye_screen_position + requested_screen_delta
	) as Vector3
	_check(
		is_equal_approx(free_aim_direction.length(), 1.0)
		and is_zero_approx(free_aim_direction.y),
		"Screen aim did not produce a horizontal world direction without a scene hit"
	)
	var projected_direction: Vector2 = (
		aim_camera.unproject_position(visual_eye + free_aim_direction * 3.0)
		- eye_screen_position
	)
	_check(
		projected_direction.normalized().dot(requested_screen_delta.normalized()) > 0.99,
		"Top-down screen aim direction flipped away from the requested screen direction"
	)
	var locked_target: Vector3 = Vector3(4.0, 1.6, 0.0)
	preview.call("show_preview", visual_token, locked_target)
	_check(bool(preview.call("lock_current")), "Combat preview could not lock its current world line")
	_check(bool(preview.call("is_locked")), "Combat preview did not report its locked state")
	preview.call("show_preview", visual_token, Vector3(-4.0, 1.6, 0.0))
	_check(
		(preview.call("get_last_target") as Vector3).is_equal_approx(locked_target),
		"Locked combat preview endpoint moved after a live preview update"
	)
	preview.call("unlock")
	preview.call("show_preview", visual_token, Vector3(-4.0, 1.6, 0.0))
	_check(
		not bool(preview.call("is_locked"))
		and (preview.call("get_last_target") as Vector3).is_equal_approx(
			Vector3(-4.0, 1.6, 0.0)
		),
		"Unlocked combat preview did not resume live endpoint updates"
	)
	var pointer_controller: PointerInteractionController = PointerInteractionController.new()
	_check(
		pointer_controller.begin_combat_aim(visual_token)
		and pointer_controller.is_combat_aiming_for(visual_token)
		and pointer_controller.should_block_entity_selection(),
		"Combat aim mode did not claim exclusive entity-selection input"
	)
	_check(
		pointer_controller.begin_camera_orbit(Vector2(100.0, 100.0))
		and pointer_controller.is_camera_orbit()
		and pointer_controller.is_combat_aim_active(),
		"Camera orbit could not coexist with persistent combat aim mode"
	)
	pointer_controller.reset()
	pointer_controller.end_combat_aim()
	_check(
		pointer_controller.is_idle()
		and not pointer_controller.should_block_entity_selection(),
		"Ending combat aim did not restore ordinary entity selection"
	)
	_remove_now(visual_token)
	_remove_now(aim_camera)
	_remove_now(preview)
	_remove_now(intermediate_token)
	_remove_now(target)
	_remove_now(shooter)
	await get_tree().physics_frame


func _create_token(token_name: String, token_position: Vector3) -> Node3D:
	var token: Node3D = Node3D.new()
	token.name = token_name
	token.position = token_position
	add_child(token)
	var token_properties: TokenProperties = TokenProperties.new()
	token_properties.name = "TokenProperties"
	token.add_child(token_properties)
	return token


func _get_token_aim_point(token: Node3D) -> Vector3:
	return _combat_line_preview_script.call("get_entity_aim_point", token) as Vector3


func _create_wall(size: Vector3) -> Node3D:
	var wall: Node3D = Node3D.new()
	wall.name = "CombatWall"
	add_child(wall)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position.y = size.y * 0.5
	wall.add_child(mesh_instance)
	var combat_body: CombatBody = CombatBody.new()
	combat_body.name = "CombatBody"
	combat_body.target_node = wall
	wall.add_child(combat_body)
	wall.force_update_transform()
	_check(combat_body.fit_from_target_synced(), "CombatBody could not fit wall geometry")
	return wall


func _create_pick_area() -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = "PickOnlyArea"
	area.collision_layer = 1 << (GvttRenderLayers.PICK_PHYSICS_LAYER - 1)
	area.collision_mask = 0
	add_child(area)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(2.0, 2.0, 2.0)
	shape_node.shape = shape
	shape_node.position.y = 1.0
	area.add_child(shape_node)
	return area


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

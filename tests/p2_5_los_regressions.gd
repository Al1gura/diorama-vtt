extends Node3D

var _assertion_count: int = 0
var _failures: Array[String] = []
var _visibility_script: GDScript = load("res://scripts/los_visibility_polygon.gd")
var _los_occluder_script: GDScript = load("res://scripts/los_occluder.gd")
var _los_service_script: GDScript = load("res://scripts/los_service.gd")
var _fog_overlay_script: GDScript = load("res://scripts/cast_fog_overlay.gd")
var _gm_tool_overlay_script: GDScript = load("res://scripts/gm_tool_overlay.gd")
var _cast_view_script: GDScript = load("res://scripts/cast_view.gd")


func _ready() -> void:
	await get_tree().process_frame
	_test_visibility_polygon_contract()
	await _test_occluder_contract()
	await _test_service_contract()
	await _test_placement_integration()
	await _test_cast_overlay_contract()
	await _test_main_overlay_contract()
	await _test_gm_tool_overlay_contract()
	await _test_cast_view_lifecycle()
	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
	}
	print("P2_5_LOS_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P2_5_LOS_FAILURES " + JSON.stringify(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_visibility_polygon_contract() -> void:
	_check(_visibility_script != null, "LOS visibility polygon script is missing")
	if _visibility_script == null:
		return
	var map_bounds: Rect2 = Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0))
	var wall_segments: Array[PackedVector2Array] = [
		_segment(Vector2(0.0, -5.0), Vector2(0.0, 5.0)),
	]
	var polygon: PackedVector2Array = _visibility_script.call(
		"compute", Vector2(-2.0, 0.0), wall_segments, map_bounds
	) as PackedVector2Array
	_check(polygon.size() >= 4, "LOS visibility polygon did not return a bounded region")
	_check(
		Geometry2D.is_point_in_polygon(Vector2(-4.0, 0.0), polygon),
		"LOS visibility polygon hid a clear point in front of the wall"
	)
	_check(
		not Geometry2D.is_point_in_polygon(Vector2(2.0, 0.0), polygon),
		"LOS visibility polygon leaked through a full map-height wall"
	)

	var corner_segments: Array[PackedVector2Array] = [
		_segment(Vector2(0.0, -4.0), Vector2(0.0, 2.0)),
		_segment(Vector2(0.0, 2.0), Vector2(4.0, 2.0)),
		_segment(Vector2(2.0, 2.0), Vector2(2.0, 4.0)),
	]
	var corner_polygon: PackedVector2Array = _visibility_script.call(
		"compute", Vector2(-2.0, 0.0), corner_segments, map_bounds
	) as PackedVector2Array
	_check(
		not Geometry2D.is_point_in_polygon(Vector2(3.0, 3.0), corner_polygon),
		"LOS rotational sweep leaked around a deep shared corner"
	)
	var repeated_polygon: PackedVector2Array = _visibility_script.call(
		"compute", Vector2(-2.0, 0.0), corner_segments, map_bounds
	) as PackedVector2Array
	_check(
		repeated_polygon == corner_polygon,
		"LOS visibility polygon was not deterministic for identical input"
	)


func _test_occluder_contract() -> void:
	_check(_los_occluder_script != null, "LOSOccluder script is missing")
	if _los_occluder_script == null:
		return
	var wall: Node3D = _create_visual_root("LOSVisualWall", Vector3(4.0, 2.0, 0.5))
	wall.position = Vector3(3.0, 0.0, -1.0)
	wall.rotation.y = PI * 0.25
	wall.scale = Vector3(1.5, 1.0, 0.5)
	wall.force_update_transform()
	var occluder: Node3D = _los_occluder_script.new() as Node3D
	occluder.name = "LOSOccluder"
	occluder.set("target_node", wall)
	wall.add_child(occluder)
	var fitted: bool = bool(occluder.call("fit_from_target_synced"))
	var segments: Array[PackedVector2Array] = []
	segments.assign(occluder.call("get_world_segments"))
	_check(fitted, "LOSOccluder did not fit the shared visual bounds")
	_check(segments.size() == 4, "LOSOccluder did not expose four footprint edges")
	var expected_local: Vector2 = Vector2(-2.0, -0.25)
	var expected_world_3d: Vector3 = wall.global_transform * Vector3(
		expected_local.x, 0.0, expected_local.y
	)
	_check(
		segments.size() == 4
		and segments[0][0].is_equal_approx(Vector2(expected_world_3d.x, expected_world_3d.z)),
		"LOSOccluder did not preserve wall translation, rotation, and scale"
	)
	_check(
		wall.get_node_or_null("CombatBody") == null
		and wall.get_node_or_null("PickProxy") == null,
		"LOSOccluder test unexpectedly depended on CombatBody or PickProxy"
	)
	occluder.call("set_blocks_los", false)
	var disabled_segments: Array[PackedVector2Array] = []
	disabled_segments.assign(occluder.call("get_world_segments"))
	_check(disabled_segments.is_empty(), "blocks_los=false still returned LOS segments")
	_remove_now(wall)
	await get_tree().process_frame


func _test_service_contract() -> void:
	_check(_los_service_script != null, "LOSService script is missing")
	if _los_service_script == null or _los_occluder_script == null:
		return
	var content_root: Node3D = Node3D.new()
	content_root.name = "LOSContentRoot"
	add_child(content_root)
	var service: Node = _los_service_script.new() as Node
	service.name = "LOSService"
	add_child(service)
	service.call("configure", content_root, Vector2(10.0, 10.0))
	var wall: Node3D = _create_visual_root(
		"ServiceWall", Vector3(0.5, 2.0, 10.0), content_root
	)
	var occluder: Node3D = _los_occluder_script.new() as Node3D
	occluder.name = "LOSOccluder"
	occluder.set("target_node", wall)
	wall.add_child(occluder)
	occluder.call("fit_from_target_synced")
	service.call("register_occluder", occluder)
	var observer_a: Node3D = Node3D.new()
	observer_a.name = "PlayerTokenA"
	observer_a.position = Vector3(-2.0, 0.0, 0.0)
	var token_properties_a: TokenProperties = TokenProperties.new()
	token_properties_a.name = "TokenProperties"
	observer_a.add_child(token_properties_a)
	content_root.add_child(observer_a)
	await get_tree().process_frame
	var polygon_a: PackedVector2Array = service.call("get_visible_polygon") as PackedVector2Array
	_check(
		service.call("get_observer_token") == observer_a,
		"LOSService did not automatically choose the first Token"
	)
	_check(
		Geometry2D.is_point_in_polygon(Vector2(-4.0, 0.0), polygon_a)
		and not Geometry2D.is_point_in_polygon(Vector2(4.0, 0.0), polygon_a),
		"LOSService did not block the far side of a wall"
	)
	var observer_b: Node3D = Node3D.new()
	observer_b.name = "PlayerTokenB"
	observer_b.position = Vector3(2.0, 0.0, 0.0)
	var token_properties_b: TokenProperties = TokenProperties.new()
	token_properties_b.name = "TokenProperties"
	observer_b.add_child(token_properties_b)
	content_root.add_child(observer_b)
	await get_tree().process_frame
	_check(
		service.call("get_observer_token") == observer_a,
		"A later Token unexpectedly stole the LOS observer"
	)
	var stable_recompute_count: int = int(service.call("get_recompute_count"))
	await get_tree().process_frame
	_check(
		int(service.call("get_recompute_count")) == stable_recompute_count,
		"LOSService recomputed while the observer and walls were unchanged"
	)
	service.call("set_token_observer", observer_b)
	var selected_polygon: PackedVector2Array = service.call(
		"get_visible_polygon"
	) as PackedVector2Array
	_check(
		service.call("get_observer_token") == observer_b
		and Geometry2D.is_point_in_polygon(Vector2(4.0, 0.0), selected_polygon)
		and not Geometry2D.is_point_in_polygon(Vector2(-4.0, 0.0), selected_polygon),
		"Selecting another Token did not switch the LOS observer"
	)
	var selected_recompute_count: int = int(service.call("get_recompute_count"))
	observer_a.position = Vector3(-3.0, 0.0, 0.0)
	await get_tree().process_frame
	_check(
		int(service.call("get_recompute_count")) == selected_recompute_count,
		"Moving an inactive Token unexpectedly recomputed LOS"
	)
	observer_b.position = Vector3(3.0, 0.0, 0.0)
	await get_tree().process_frame
	_check(
		int(service.call("get_recompute_count")) > selected_recompute_count,
		"LOSService did not recompute after the selected Token moved"
	)
	service.call("set_token_observer", observer_a)
	_remove_now(observer_a)
	await get_tree().process_frame
	await get_tree().process_frame
	var polygon_b: PackedVector2Array = service.call("get_visible_polygon") as PackedVector2Array
	_check(
		service.call("get_observer_token") == observer_b
		and Geometry2D.is_point_in_polygon(Vector2(4.0, 0.0), polygon_b),
		"LOSService did not fall back to the next Token after removal"
	)
	_remove_now(wall)
	await get_tree().process_frame
	var opened_polygon: PackedVector2Array = service.call(
		"get_visible_polygon"
	) as PackedVector2Array
	_check(
		Geometry2D.is_point_in_polygon(Vector2(-4.0, 0.0), opened_polygon),
		"Removing a wall left stale LOS occlusion behind"
	)
	_remove_now(observer_b)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		service.call("get_observer_token") == null
		and (service.call("get_visible_polygon") as PackedVector2Array).is_empty(),
		"LOSService did not disable visibility after the last Token was removed"
	)
	_remove_now(service)
	_remove_now(content_root)
	await get_tree().process_frame


func _test_placement_integration() -> void:
	if _los_occluder_script == null:
		return
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
		load("res://scripts/cpr_token_properties.gd") as GDScript,
		_los_occluder_script
	)
	var wall: Node3D = _create_visual_root(
		"PlacementWall", Vector3(2.0, 2.0, 0.4), content_root
	)
	var wall_props: EntityProperties = EntityProperties.new()
	wall_props.name = "EntityProperties"
	wall_props.configure_from_category("wall")
	wall.add_child(wall_props)
	controller.attach_entity_type_properties(wall, wall_props)
	_check(
		wall.get_node_or_null("LOSOccluder") != null,
		"PlacementController did not attach LOSOccluder to a wall"
	)
	var placed_occluder: Node = wall.get_node_or_null("LOSOccluder")
	var placed_wall_properties: WallProperties = wall.get_node_or_null(
		"WallProperties"
	) as WallProperties
	if placed_occluder != null and placed_wall_properties != null:
		placed_wall_properties.set_blocks_los(false)
		var disabled_wall_segments: Array[PackedVector2Array] = []
		disabled_wall_segments.assign(placed_occluder.call("get_world_segments"))
		_check(
			disabled_wall_segments.is_empty(),
			"WallProperties.set_blocks_los(false) did not disable LOSOccluder"
		)
		placed_wall_properties.set_blocks_los(true)
		var restored_wall_segments: Array[PackedVector2Array] = []
		restored_wall_segments.assign(placed_occluder.call("get_world_segments"))
		_check(
			restored_wall_segments.size() == 4,
			"WallProperties.set_blocks_los(true) did not restore LOSOccluder"
		)
	var terrain: Node3D = _create_visual_root(
		"PlacementTerrain", Vector3(2.0, 2.0, 2.0), content_root
	)
	var terrain_props: EntityProperties = EntityProperties.new()
	terrain_props.name = "EntityProperties"
	terrain_props.configure_from_category("terrain")
	terrain.add_child(terrain_props)
	controller.attach_entity_type_properties(terrain, terrain_props)
	_check(
		terrain.get_node_or_null("LOSOccluder") == null,
		"P2.5 incorrectly attached LOSOccluder to non-wall scenery"
	)
	_remove_now(controller)
	_remove_now(scene_root)
	await get_tree().process_frame


func _test_cast_overlay_contract() -> void:
	_check(_fog_overlay_script != null, "Cast fog overlay script is missing")
	if _fog_overlay_script == null:
		return
	var cast_window: Window = Window.new()
	cast_window.name = "TestCastWindow"
	cast_window.size = Vector2i(640, 360)
	cast_window.visible = false
	var cast_camera: Camera3D = Camera3D.new()
	cast_camera.name = "CastCamera"
	cast_camera.current = true
	cast_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	cast_camera.size = 10.0
	cast_camera.position = Vector3(0.0, 10.0, 0.0)
	cast_camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	cast_window.add_child(cast_camera)
	var overlay: CanvasLayer = _fog_overlay_script.new() as CanvasLayer
	overlay.name = "CastFogOverlay"
	cast_window.add_child(overlay)
	add_child(cast_window)
	overlay.call("configure", cast_window, cast_camera)
	var world_polygon: PackedVector2Array = PackedVector2Array([
		Vector2(-4.0, -4.0),
		Vector2(4.0, -4.0),
		Vector2(4.0, 4.0),
		Vector2(-4.0, 4.0),
	])
	overlay.call("set_world_polygon", world_polygon, true)
	await get_tree().process_frame
	var mask_viewport: SubViewport = overlay.get_node_or_null(
		"LOSVisibilityMask"
	) as SubViewport
	var fog_rect: TextureRect = overlay.get_node_or_null("LOSFog") as TextureRect
	var projected: PackedVector2Array = overlay.call(
		"get_projected_polygon"
	) as PackedVector2Array
	_check(
		overlay.get_viewport() == cast_window and overlay.get_viewport() != get_viewport(),
		"Cast fog overlay was not isolated to the cast Window viewport"
	)
	_check(
		mask_viewport != null and mask_viewport.size == cast_window.size,
		"Cast fog mask SubViewport did not match the cast Window size"
	)
	_check(
		bool(overlay.call("is_fog_active")) and projected.size() == world_polygon.size(),
		"Cast fog overlay did not project the world visibility polygon"
	)
	_check(
		fog_rect != null and fog_rect.texture != null and not fog_rect.flip_v,
		"Cast fog did not bind the SubViewport texture with screen-space orientation"
	)
	overlay.call("set_world_polygon", PackedVector2Array(), false)
	_check(
		not bool(overlay.call("is_fog_active")),
		"Cast fog remained active without a camera visibility polygon"
	)
	_remove_now(cast_window)
	await get_tree().process_frame


func _test_cast_view_lifecycle() -> void:
	_check(_cast_view_script != null, "CastView script is missing")
	if _cast_view_script == null or _los_service_script == null:
		return
	var main_camera: Camera3D = Camera3D.new()
	main_camera.name = "TestMainCamera"
	main_camera.current = true
	main_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	main_camera.size = 10.0
	main_camera.position = Vector3(0.0, 10.0, 0.0)
	main_camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(main_camera)
	var content_root: Node3D = Node3D.new()
	content_root.name = "CastLifecycleContent"
	add_child(content_root)
	var observer_token: Node3D = Node3D.new()
	observer_token.name = "CastLifecycleToken"
	var token_properties: TokenProperties = TokenProperties.new()
	token_properties.name = "TokenProperties"
	observer_token.add_child(token_properties)
	content_root.add_child(observer_token)
	var service: Node = _los_service_script.new() as Node
	service.name = "CastLifecycleLOSService"
	add_child(service)
	service.call("configure", content_root, Vector2(10.0, 10.0))
	var cast_view: Node = _cast_view_script.new() as Node
	cast_view.name = "CastLifecycleController"
	add_child(cast_view)
	cast_view.call("open", self)
	await get_tree().process_frame
	var opened_window: Window = null
	for child: Node in get_children():
		if child is Window and child.name == "CastWindow":
			opened_window = child as Window
			break
	_check(opened_window != null, "CastView.open() did not create the player Window")
	_check(
		opened_window != null
		and opened_window.get_node_or_null("PlayerOutputCanvas/MediaRoot/PresenterHost") is Control,
		"CastView.open() did not create the media presenter host"
	)
	var map_presenter: MapOutputPresenter = MapOutputPresenter.new()
	map_presenter.name = "MapOutputPresenter"
	add_child(map_presenter)
	map_presenter.configure(cast_view as CastView, main_camera, service)
	_check(map_presenter.activate() == OK, "MapOutputPresenter could not activate")
	await get_tree().process_frame
	_check(
		opened_window != null and opened_window.get_node_or_null("CastCamera") is Camera3D,
		"MapOutputPresenter did not create the cast Camera3D"
	)
	var opened_overlay: CanvasLayer = null
	if opened_window != null:
		opened_overlay = opened_window.get_node_or_null("CastFogOverlay") as CanvasLayer
	_check(opened_overlay != null, "MapOutputPresenter did not attach CastFogOverlay")
	_check(
		opened_overlay != null
		and opened_overlay.get_node_or_null("LOSVisibilityMask") is SubViewport,
		"MapOutputPresenter did not attach the LOS mask SubViewport"
	)
	_check(
		opened_overlay != null and bool(opened_overlay.call("is_fog_active")),
		"MapOutputPresenter did not consume the active LOSService polygon"
	)
	map_presenter.release()
	cast_view.call("release_window")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		not bool(cast_view.call("is_open"))
		and (opened_window == null or not is_instance_valid(opened_window)),
		"CastView.release_window() left the player Window tree alive"
	)
	_remove_now(map_presenter)
	_remove_now(cast_view)
	_remove_now(service)
	_remove_now(content_root)
	_remove_now(main_camera)
	await get_tree().process_frame


func _test_main_overlay_contract() -> void:
	if _fog_overlay_script == null:
		return
	var main_camera: Camera3D = Camera3D.new()
	main_camera.name = "MainOverlayCamera"
	main_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	main_camera.size = 10.0
	main_camera.position = Vector3(0.0, 10.0, 0.0)
	main_camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(main_camera)
	var overlay: CanvasLayer = _fog_overlay_script.new() as CanvasLayer
	overlay.name = "PlayerFogOverlay"
	add_child(overlay)
	overlay.call("configure", get_viewport(), main_camera, 0)
	overlay.call(
		"set_world_polygon",
		PackedVector2Array([
			Vector2(-4.0, -4.0),
			Vector2(4.0, -4.0),
			Vector2(4.0, 4.0),
			Vector2(-4.0, 4.0),
		]),
		true
	)
	await get_tree().process_frame
	var mask_viewport: SubViewport = overlay.get_node_or_null(
		"LOSVisibilityMask"
	) as SubViewport
	var expected_size: Vector2 = get_viewport().get_visible_rect().size
	_check(overlay.get_viewport() == get_viewport(), "Player fog did not bind the main viewport")
	_check(overlay.layer == 0, "Player fog was not placed below the GM UI layer")
	_check(
		mask_viewport != null
		and mask_viewport.size == Vector2i(roundi(expected_size.x), roundi(expected_size.y)),
		"Player fog mask did not match the main viewport size"
	)
	_check(bool(overlay.call("is_fog_active")), "Player fog did not activate on the main viewport")
	await RenderingServer.frame_post_draw
	var mask_image: Image = mask_viewport.get_texture().get_image()
	var mask_center: Vector2i = mask_image.get_size() / 2
	_check(
		mask_image.get_pixelv(mask_center).a > 0.5
		and mask_image.get_pixel(4, 4).a < 0.5,
		"Player fog mask pixels did not separate visible and hidden regions"
	)
	_remove_now(overlay)
	_remove_now(main_camera)
	await get_tree().process_frame


func _test_gm_tool_overlay_contract() -> void:
	_check(_gm_tool_overlay_script != null, "GM tool overlay script is missing")
	if _gm_tool_overlay_script == null:
		return
	var main_camera: Camera3D = Camera3D.new()
	main_camera.name = "GMToolMainCamera"
	main_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	main_camera.size = 17.0
	main_camera.near = 0.2
	main_camera.far = 400.0
	main_camera.position = Vector3(3.0, 12.0, 4.0)
	main_camera.rotation = Vector3(-1.2, 0.3, 0.0)
	add_child(main_camera)
	var overlay: CanvasLayer = _gm_tool_overlay_script.new() as CanvasLayer
	overlay.name = "GMToolOverlay"
	add_child(overlay)
	var gm_only_mask: int = 1 << (GvttRenderLayers.RENDER_LAYER_GM_ONLY - 1)
	overlay.call("configure", get_viewport(), main_camera, gm_only_mask, 1)
	var gizmo_stub: GizmoSurfaceStub = GizmoSurfaceStub.new()
	var gizmo_surface: Control = Control.new()
	gizmo_surface.name = "GizmoSurface"
	gizmo_stub._surface = gizmo_surface
	gizmo_stub.add_child(gizmo_surface)
	add_child(gizmo_stub)
	var adopted: bool = bool(overlay.call("adopt_gizmo_surface", gizmo_stub))
	await get_tree().process_frame
	var tool_viewport: SubViewport = overlay.get_node_or_null(
		"GMToolViewport"
	) as SubViewport
	var tool_camera: Camera3D = null
	if tool_viewport != null:
		tool_camera = tool_viewport.get_node_or_null("GMToolCamera") as Camera3D
	var texture_rect: TextureRect = overlay.get_node_or_null(
		"GMToolTexture"
	) as TextureRect
	_check(overlay.layer == 1, "GM tools were not placed above fog on layer 1")
	_check(
		tool_viewport != null and tool_viewport.world_3d == get_viewport().world_3d,
		"GM tool viewport did not share the main World3D"
	)
	_check(
		tool_camera != null
		and tool_camera.cull_mask == gm_only_mask
		and tool_camera.global_transform.is_equal_approx(main_camera.global_transform),
		"GM tool camera did not isolate layer 20 or mirror the main camera"
	)
	_check(
		tool_camera != null
		and tool_camera.projection == main_camera.projection
		and is_equal_approx(tool_camera.size, main_camera.size)
		and is_equal_approx(tool_camera.near, main_camera.near)
		and is_equal_approx(tool_camera.far, main_camera.far),
		"GM tool camera projection did not stay synchronized"
	)
	_check(
		texture_rect != null
		and texture_rect.texture != null
		and texture_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"GM tool texture was missing or intercepted pointer input"
	)
	_check(
		adopted
		and bool(overlay.call("has_adopted_gizmo_surface"))
		and gizmo_surface.get_parent() == overlay
		and gizmo_surface.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Gizmo 2D helpers were not moved above the fog"
	)
	_remove_now(gizmo_stub)
	_remove_now(overlay)
	_remove_now(main_camera)
	await get_tree().process_frame


func _segment(from: Vector2, to: Vector2) -> PackedVector2Array:
	return PackedVector2Array([from, to])


func _create_visual_root(
		root_name: String,
		size: Vector3,
		parent: Node = self
) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = root_name
	parent.add_child(root)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position.y = size.y * 0.5
	root.add_child(mesh_instance)
	return root


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)


func _remove_now(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


class GizmoSurfaceStub:
	extends Node

	var _surface: Control = null

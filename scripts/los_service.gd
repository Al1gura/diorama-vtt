class_name LOSService
extends Node

signal visibility_changed(polygon: PackedVector2Array, active: bool)

const POSITION_EPSILON_SQUARED: float = 0.000001
const VISIBILITY_POLYGON_SCRIPT: GDScript = preload("res://scripts/los_visibility_polygon.gd")

var _content_root: Node3D = null
var _observer_token: Node3D = null
var _observer_position: Vector2 = Vector2(INF, INF)
var _map_bounds: Rect2 = Rect2()
var _occluders: Array[Node3D] = []
var _visible_polygon: PackedVector2Array = PackedVector2Array()
var _recompute_count: int = 0


func configure(content_root: Node3D, map_size: Vector2) -> void:
	_content_root = content_root
	set_map_size(map_size)
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	if not get_tree().node_removed.is_connected(_on_tree_node_removed):
		get_tree().node_removed.connect(_on_tree_node_removed)
	_rebuild_occluder_registry()
	_find_first_token_observer()
	set_process(true)


func _exit_tree() -> void:
	if get_tree() == null:
		return
	if get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)
	if get_tree().node_removed.is_connected(_on_tree_node_removed):
		get_tree().node_removed.disconnect(_on_tree_node_removed)


func _process(_delta: float) -> void:
	if (
		_observer_token == null
		or not is_instance_valid(_observer_token)
		or not _observer_token.is_inside_tree()
	):
		_observer_token = null
		_find_first_token_observer()
	if _observer_token == null:
		_deactivate_visibility()
		return
	var current_position: Vector2 = Vector2(
		_observer_token.global_position.x,
		_observer_token.global_position.z
	)
	if current_position.distance_squared_to(_observer_position) > POSITION_EPSILON_SQUARED:
		_observer_position = current_position
		recompute()


func set_map_size(map_size: Vector2) -> void:
	var safe_size: Vector2 = Vector2(maxf(map_size.x, 0.0), maxf(map_size.y, 0.0))
	_map_bounds = Rect2(-safe_size * 0.5, safe_size)
	recompute()


func set_token_observer(observer_token: Node3D) -> void:
	if not _is_token_entity(observer_token):
		clear_observer()
		return
	_observer_token = observer_token
	_observer_position = Vector2(
		_observer_token.global_position.x,
		_observer_token.global_position.z
	)
	recompute()


func clear_observer() -> void:
	_observer_token = null
	_observer_position = Vector2(INF, INF)
	_visible_polygon = PackedVector2Array()
	visibility_changed.emit(PackedVector2Array(), false)


func get_observer_token() -> Node3D:
	return (
		_observer_token
		if _observer_token != null and is_instance_valid(_observer_token)
		else null
	)


func get_visible_polygon() -> PackedVector2Array:
	return _visible_polygon.duplicate()


func get_recompute_count() -> int:
	return _recompute_count


func register_occluder(occluder: Node3D) -> void:
	if not _is_los_occluder(occluder) or _occluders.has(occluder):
		return
	if _content_root != null and occluder != _content_root and not _content_root.is_ancestor_of(occluder):
		return
	_occluders.append(occluder)
	var changed_callable: Callable = Callable(self, "_on_occluder_segments_changed")
	if not occluder.is_connected("segments_changed", changed_callable):
		occluder.connect("segments_changed", changed_callable)
	recompute()


func unregister_occluder(occluder: Node3D) -> void:
	if not _occluders.has(occluder):
		return
	_occluders.erase(occluder)
	if is_instance_valid(occluder):
		var changed_callable: Callable = Callable(self, "_on_occluder_segments_changed")
		if occluder.is_connected("segments_changed", changed_callable):
			occluder.disconnect("segments_changed", changed_callable)
	recompute()


func recompute() -> void:
	if (
		_observer_token == null
		or not is_instance_valid(_observer_token)
		or not is_finite(_observer_position.x)
		or not is_finite(_observer_position.y)
	):
		_visible_polygon = PackedVector2Array()
		visibility_changed.emit(PackedVector2Array(), false)
		return
	var all_segments: Array[PackedVector2Array] = []
	for occluder: Node3D in _occluders.duplicate():
		if not is_instance_valid(occluder):
			_occluders.erase(occluder)
			continue
		var occluder_segments: Array[PackedVector2Array] = []
		occluder_segments.assign(occluder.call("get_world_segments"))
		all_segments.append_array(occluder_segments)
	_visible_polygon = VISIBILITY_POLYGON_SCRIPT.compute(
		_observer_position, all_segments, _map_bounds
	)
	_recompute_count += 1
	visibility_changed.emit(_visible_polygon.duplicate(), _visible_polygon.size() >= 3)


func _rebuild_occluder_registry() -> void:
	for occluder: Node3D in _occluders.duplicate():
		unregister_occluder(occluder)
	_occluders.clear()
	if _content_root == null or not is_instance_valid(_content_root):
		return
	var pending: Array[Node] = [_content_root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child: Node in current.get_children():
			pending.append(child)
			if child is Node3D and _is_los_occluder(child as Node3D):
				register_occluder(child as Node3D)


func _on_tree_node_added(node: Node) -> void:
	if node is Node3D and _is_los_occluder(node as Node3D):
		register_occluder(node as Node3D)


func _on_tree_node_removed(node: Node) -> void:
	if node is Node3D and _occluders.has(node as Node3D):
		unregister_occluder(node as Node3D)
	if node == _observer_token:
		_observer_token = null
		_deactivate_visibility()


func _on_occluder_segments_changed(_occluder: Node3D) -> void:
	recompute()


func _is_los_occluder(node: Node3D) -> bool:
	return (
		node != null
		and node.has_method("get_world_segments")
		and node.has_signal("segments_changed")
	)


func _find_first_token_observer() -> void:
	if _observer_token != null and is_instance_valid(_observer_token):
		return
	if _content_root == null or not is_instance_valid(_content_root):
		return
	for child: Node in _content_root.get_children():
		if child is Node3D and _is_token_entity(child as Node3D):
			set_token_observer(child as Node3D)
			return


func _is_token_entity(node: Node3D) -> bool:
	return (
		node != null
		and is_instance_valid(node)
		and node.get_node_or_null("TokenProperties") != null
	)


func _deactivate_visibility() -> void:
	var was_active: bool = not _visible_polygon.is_empty()
	_observer_position = Vector2(INF, INF)
	_visible_polygon = PackedVector2Array()
	if was_active:
		visibility_changed.emit(PackedVector2Array(), false)

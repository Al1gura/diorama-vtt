class_name CameraViewController
extends Node

const ORBIT_MIN_DIST: float = 3.0
const ORBIT_MAX_DIST: float = 80.0
const ORBIT_MIN_PITCH: float = 0.01
const ORBIT_MAX_PITCH: float = 1.5707
const ORBIT_DEFAULT_DIST: float = 25.0
const ORBIT_DEFAULT_YAW: float = 0.6
const ORBIT_DEFAULT_PITCH: float = 1.0
const MAP_DEFAULT_SIZE: float = 10.0

var _camera: Camera3D = null
var _grid_manager: GridManager = null
var _saved_orbit_dist: float = ORBIT_DEFAULT_DIST
var _saved_orbit_yaw: float = ORBIT_DEFAULT_YAW
var _saved_orbit_pitch: float = ORBIT_DEFAULT_PITCH
var _saved_orbit_focus: Vector3 = Vector3.ZERO
var _orbit_dist: float = ORBIT_DEFAULT_DIST
var _orbit_yaw: float = ORBIT_DEFAULT_YAW
var _orbit_pitch: float = ORBIT_DEFAULT_PITCH
var _orbit_focus: Vector3 = Vector3.ZERO
var _map_size: float = MAP_DEFAULT_SIZE
var _map_focus: Vector3 = Vector3.ZERO


func configure(camera: Camera3D, grid_manager: GridManager) -> void:
	_camera = camera
	_grid_manager = grid_manager
	if _camera != null and is_instance_valid(_camera):
		_camera.projection = Camera3D.ProjectionType.PROJECTION_ORTHOGONAL
		_camera.size = _map_size


func get_camera() -> Camera3D:
	if _camera != null and is_instance_valid(_camera):
		return _camera
	return null


func get_saved_orbit_dist() -> float:
	return _saved_orbit_dist


func set_saved_orbit_dist(value: float) -> void:
	_saved_orbit_dist = value


func get_saved_orbit_yaw() -> float:
	return _saved_orbit_yaw


func set_saved_orbit_yaw(value: float) -> void:
	_saved_orbit_yaw = value


func get_saved_orbit_pitch() -> float:
	return _saved_orbit_pitch


func set_saved_orbit_pitch(value: float) -> void:
	_saved_orbit_pitch = value


func get_saved_orbit_focus() -> Vector3:
	return _saved_orbit_focus


func set_saved_orbit_focus(value: Vector3) -> void:
	_saved_orbit_focus = value


func get_orbit_dist() -> float:
	return _orbit_dist


func set_orbit_dist(value: float) -> void:
	_orbit_dist = clampf(value, ORBIT_MIN_DIST, ORBIT_MAX_DIST)
	update_orbit_camera()
	refresh_grid()


func get_orbit_yaw() -> float:
	return _orbit_yaw


func set_orbit_yaw(value: float) -> void:
	_orbit_yaw = value
	update_orbit_camera()


func get_orbit_pitch() -> float:
	return _orbit_pitch


func set_orbit_pitch(value: float) -> void:
	_orbit_pitch = clampf(value, ORBIT_MIN_PITCH, ORBIT_MAX_PITCH)
	update_orbit_camera()


func get_orbit_focus() -> Vector3:
	return _orbit_focus


func set_orbit_focus(value: Vector3) -> void:
	_orbit_focus = value
	update_orbit_camera()


func get_map_size() -> float:
	return _map_size


func set_map_size(value: float) -> void:
	_map_size = clampf(value, 5.0, 80.0)
	if is_map_view() and _has_camera():
		_camera.size = _map_size
	refresh_grid()


func get_map_focus() -> Vector3:
	return _map_focus


func set_map_focus(value: Vector3) -> void:
	_map_focus = value
	if is_map_view() and _has_camera():
		_camera.position = _map_focus + Vector3(0.0, 25.0, 0.0)


func apply_for_mode(_mode: ModeGate.AppMode) -> void:
	apply_current_view()


func apply_current_view() -> void:
	if not _has_camera():
		return
	if is_map_view():
		_camera.projection = Camera3D.ProjectionType.PROJECTION_ORTHOGONAL
		_camera.size = _map_size
		_camera.position = _map_focus + Vector3(0.0, 25.0, 0.0)
		_camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	else:
		_orbit_dist = _saved_orbit_dist
		_orbit_yaw = _saved_orbit_yaw
		_orbit_pitch = _saved_orbit_pitch
		_orbit_focus = _saved_orbit_focus
		_camera.projection = Camera3D.ProjectionType.PROJECTION_PERSPECTIVE
		_camera.fov = 60.0
		update_orbit_camera()
	refresh_grid()


func is_map_view() -> bool:
	return ModeGate.is_sub_map()


func zoom(direction: float) -> void:
	if not _has_camera():
		return
	var zoom_factor: float = 1.0 + direction * 0.12
	if is_map_view():
		_map_size = clampf(_map_size * zoom_factor, 5.0, 80.0)
		_camera.size = _map_size
	else:
		_orbit_dist = clampf(_orbit_dist * zoom_factor, ORBIT_MIN_DIST, ORBIT_MAX_DIST)
		update_orbit_camera()
	refresh_grid()


func orbit(relative: Vector2) -> void:
	if not _has_camera():
		return
	_orbit_yaw -= relative.x * 0.005
	_orbit_pitch = clampf(
		_orbit_pitch - relative.y * 0.005, ORBIT_MIN_PITCH, ORBIT_MAX_PITCH
	)
	update_orbit_camera()


func pan(relative: Vector2) -> void:
	if not _has_camera():
		return
	if is_map_view():
		_map_focus.x -= relative.x * _camera.size * 0.0015
		_map_focus.z -= relative.y * _camera.size * 0.0015
		_camera.position = _map_focus + Vector3(0.0, 25.0, 0.0)
		return
	var right: Vector3 = _camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var forward: Vector3 = _camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var pan_scale: float = _orbit_dist * 0.0015
	_orbit_focus -= right * relative.x * pan_scale
	_orbit_focus -= forward * relative.y * pan_scale
	update_orbit_camera()


func save_play_view() -> void:
	_saved_orbit_dist = _orbit_dist
	_saved_orbit_yaw = _orbit_yaw
	_saved_orbit_pitch = _orbit_pitch
	_saved_orbit_focus = _orbit_focus


func restore_play_view() -> void:
	_orbit_dist = _saved_orbit_dist
	_orbit_yaw = _saved_orbit_yaw
	_orbit_pitch = _saved_orbit_pitch
	_orbit_focus = _saved_orbit_focus
	update_orbit_camera()
	refresh_grid()


func update_orbit_camera() -> void:
	if not _has_camera():
		return
	var offset: Vector3 = Vector3(
		_orbit_dist * cos(_orbit_pitch) * sin(_orbit_yaw),
		_orbit_dist * sin(_orbit_pitch),
		_orbit_dist * cos(_orbit_pitch) * cos(_orbit_yaw)
	)
	_camera.position = _orbit_focus + offset
	_camera.look_at(_orbit_focus, Vector3.UP)


func refresh_grid() -> void:
	if _grid_manager == null or not is_instance_valid(_grid_manager) or not _has_camera():
		return
	var viewport_size: Vector2 = _camera.get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return
	var pixels_per_meter: float = 0.0
	if _camera.projection == Camera3D.ProjectionType.PROJECTION_ORTHOGONAL:
		var view_height_meters: float = 2.0 * _camera.size
		pixels_per_meter = view_height_meters / viewport_size.y
	else:
		var fov_radians: float = deg_to_rad(_camera.fov)
		var view_height_perspective: float = 2.0 * _orbit_dist * tan(fov_radians * 0.5)
		pixels_per_meter = view_height_perspective / viewport_size.y
	_grid_manager.update_grid(pixels_per_meter)


func _has_camera() -> bool:
	return _camera != null and is_instance_valid(_camera)

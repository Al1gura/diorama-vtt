class_name PointerInteractionController
extends RefCounted


const MODEL_DRAG_THRESHOLD_PIXELS: float = 6.0
const RUNTIME_TOKEN_DRAG_THRESHOLD_PIXELS: float = 6.0

enum Gesture {
	IDLE,
	MODEL_CANDIDATE,
	MODEL_DRAG,
	RUNTIME_TOKEN_CANDIDATE,
	RUNTIME_TOKEN_DRAG,
	CAMERA_ORBIT,
	CAMERA_PAN,
}

var _gesture: Gesture = Gesture.IDLE
var _model_button: Button = null
var _model_category: String = ""
var _model_index: int = -1
var _model_press_position: Vector2 = Vector2.ZERO
var _model_last_position: Vector2 = Vector2.ZERO
var _runtime_token_target: Node3D = null
var _runtime_token_press_position: Vector2 = Vector2.ZERO
var _runtime_token_last_position: Vector2 = Vector2.ZERO
var _camera_press_position: Vector2 = Vector2.ZERO
var _camera_last_position: Vector2 = Vector2.ZERO
var _combat_aim_shooter: Node3D = null


func reset() -> void:
	_gesture = Gesture.IDLE
	_model_button = null
	_model_category = ""
	_model_index = -1
	_model_press_position = Vector2.ZERO
	_model_last_position = Vector2.ZERO
	_runtime_token_target = null
	_runtime_token_press_position = Vector2.ZERO
	_runtime_token_last_position = Vector2.ZERO
	_camera_press_position = Vector2.ZERO
	_camera_last_position = Vector2.ZERO


func get_gesture() -> int:
	return int(_gesture)


func get_gesture_name() -> String:
	match _gesture:
		Gesture.IDLE:
			return "IDLE"
		Gesture.MODEL_CANDIDATE:
			return "MODEL_CANDIDATE"
		Gesture.MODEL_DRAG:
			return "MODEL_DRAG"
		Gesture.RUNTIME_TOKEN_CANDIDATE:
			return "RUNTIME_TOKEN_CANDIDATE"
		Gesture.RUNTIME_TOKEN_DRAG:
			return "RUNTIME_TOKEN_DRAG"
		Gesture.CAMERA_ORBIT:
			return "CAMERA_ORBIT"
		Gesture.CAMERA_PAN:
			return "CAMERA_PAN"
		_:
			return "UNKNOWN"


func is_idle() -> bool:
	return _gesture == Gesture.IDLE


func is_model_candidate() -> bool:
	return _gesture == Gesture.MODEL_CANDIDATE


func is_model_drag() -> bool:
	return _gesture == Gesture.MODEL_DRAG


func is_runtime_token_candidate() -> bool:
	return _gesture == Gesture.RUNTIME_TOKEN_CANDIDATE


func is_runtime_token_drag() -> bool:
	return _gesture == Gesture.RUNTIME_TOKEN_DRAG


func is_camera_orbit() -> bool:
	return _gesture == Gesture.CAMERA_ORBIT


func is_camera_pan() -> bool:
	return _gesture == Gesture.CAMERA_PAN


func begin_combat_aim(shooter: Node3D) -> bool:
	if shooter == null or not is_instance_valid(shooter):
		return false
	_combat_aim_shooter = shooter
	return true


func end_combat_aim() -> void:
	_combat_aim_shooter = null


func is_combat_aim_active() -> bool:
	if _combat_aim_shooter != null and not is_instance_valid(_combat_aim_shooter):
		_combat_aim_shooter = null
	return _combat_aim_shooter != null


func is_combat_aiming_for(shooter: Node3D) -> bool:
	return (
		is_combat_aim_active()
		and shooter != null
		and shooter == _combat_aim_shooter
	)


func get_combat_aim_shooter() -> Node3D:
	if not is_combat_aim_active():
		return null
	return _combat_aim_shooter


func should_block_entity_selection() -> bool:
	return is_combat_aim_active()


func begin_model_candidate(
		button: Button,
		category: String,
		index: int,
		screen_position: Vector2
) -> bool:
	if not is_idle():
		return false
	if button == null or not is_instance_valid(button):
		return false
	_gesture = Gesture.MODEL_CANDIDATE
	_model_button = button
	_model_category = category
	_model_index = index
	_model_press_position = screen_position
	_model_last_position = screen_position
	return true


func is_model_drag_threshold_met(screen_position: Vector2) -> bool:
	if not is_model_candidate():
		return false
	return _model_press_position.distance_to(screen_position) >= MODEL_DRAG_THRESHOLD_PIXELS


func begin_model_drag(screen_position: Vector2) -> bool:
	if not is_model_candidate():
		return false
	_gesture = Gesture.MODEL_DRAG
	_model_last_position = screen_position
	return true


func get_model_button() -> Button:
	if _model_button != null and not is_instance_valid(_model_button):
		return null
	return _model_button


func get_model_category() -> String:
	return _model_category


func get_model_index() -> int:
	return _model_index


func get_model_press_position() -> Vector2:
	return _model_press_position


func update_model_position(screen_position: Vector2) -> void:
	if is_model_candidate() or is_model_drag():
		_model_last_position = screen_position


func begin_runtime_token_candidate(target: Node3D, screen_position: Vector2) -> bool:
	if not is_idle():
		return false
	if target == null or not is_instance_valid(target):
		return false
	_gesture = Gesture.RUNTIME_TOKEN_CANDIDATE
	_runtime_token_target = target
	_runtime_token_press_position = screen_position
	_runtime_token_last_position = screen_position
	return true


func is_runtime_token_drag_threshold_met(screen_position: Vector2) -> bool:
	if not is_runtime_token_candidate():
		return false
	return _runtime_token_press_position.distance_to(
		screen_position) >= RUNTIME_TOKEN_DRAG_THRESHOLD_PIXELS


func begin_runtime_token_drag(target: Node3D) -> bool:
	if not is_runtime_token_candidate():
		return false
	if target == null or not is_instance_valid(target):
		return false
	if target != _runtime_token_target:
		return false
	_gesture = Gesture.RUNTIME_TOKEN_DRAG
	return true


func get_runtime_token_target() -> Node3D:
	if _runtime_token_target != null and not is_instance_valid(_runtime_token_target):
		return null
	return _runtime_token_target


func get_runtime_token_press_position() -> Vector2:
	return _runtime_token_press_position


func update_runtime_token_position(screen_position: Vector2) -> void:
	if is_runtime_token_candidate() or is_runtime_token_drag():
		_runtime_token_last_position = screen_position


func begin_camera_orbit(screen_position: Vector2) -> bool:
	if not is_idle():
		return false
	_gesture = Gesture.CAMERA_ORBIT
	_camera_press_position = screen_position
	_camera_last_position = screen_position
	return true


func begin_camera_pan(screen_position: Vector2) -> bool:
	if not is_idle():
		return false
	_gesture = Gesture.CAMERA_PAN
	_camera_press_position = screen_position
	_camera_last_position = screen_position
	return true


func update_camera_position(screen_position: Vector2) -> void:
	if is_camera_orbit() or is_camera_pan():
		_camera_last_position = screen_position


func get_camera_last_position() -> Vector2:
	return _camera_last_position

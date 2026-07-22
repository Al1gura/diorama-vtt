class_name PlayerOutputPresenter
extends Node

signal prepared(request_id: int)
signal failed(request_id: int, error: int, message: String)
signal finished(request_id: int)
signal released(request_id: int)

var _request_id: int = 0
var _released: bool = false


func prepare(request_id: int, _resolved_content: Dictionary) -> void:
	_request_id = request_id
	_released = false


func activate() -> int:
	return OK


func deactivate(_reason: StringName) -> void:
	pass


func release() -> void:
	if _released:
		return
	_released = true
	released.emit(_request_id)


func is_released() -> bool:
	return _released


func get_natural_size() -> Vector2i:
	return Vector2i.ZERO


func get_output_texture() -> Texture2D:
	return null

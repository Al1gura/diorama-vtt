class_name SelectionController
extends RefCounted

signal selection_changed(target: Node3D, properties: EntityProperties)

var _current_target: Node3D = null
var _current_properties: EntityProperties = null


func select(target: Node3D, properties: EntityProperties = null) -> bool:
	if target == null or not is_instance_valid(target):
		clear()
		return false
	if target == _current_target and properties == _current_properties:
		return true
	_disconnect_current_target()
	_current_target = target
	_current_properties = properties
	_current_target.tree_exiting.connect(_on_current_target_tree_exiting, CONNECT_ONE_SHOT)
	selection_changed.emit(_current_target, _current_properties)
	return true


func clear() -> void:
	if _current_target == null and _current_properties == null:
		return
	_disconnect_current_target()
	_current_target = null
	_current_properties = null
	selection_changed.emit(null, null)


func has_selection() -> bool:
	return get_current_target() != null


func get_current_target() -> Node3D:
	if _current_target != null and not is_instance_valid(_current_target):
		clear()
	return _current_target


func get_current_properties() -> EntityProperties:
	if get_current_target() == null:
		return null
	if _current_properties != null and not is_instance_valid(_current_properties):
		return null
	return _current_properties


func _disconnect_current_target() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		return
	if _current_target.tree_exiting.is_connected(_on_current_target_tree_exiting):
		_current_target.tree_exiting.disconnect(_on_current_target_tree_exiting)


func _on_current_target_tree_exiting() -> void:
	_current_target = null
	_current_properties = null
	selection_changed.emit(null, null)

extends Node
class_name LightProperties
## Light-specific runtime properties.
##
## P2.3 only owns per-object light state. Scene atmosphere belongs to P3.

enum LightKind { OMNI, SPOT }

@export var is_on: bool = true
@export var light_kind: LightKind = LightKind.OMNI
@export var color: Color = Color(1.0, 0.86, 0.55, 1.0)
@export var energy: float = 1.0
@export var light_range: float = 8.0
@export var casts_shadow: bool = true
@export var spot_angle: float = 45.0

signal light_state_changed(target: Node3D, enabled: bool)


func set_on(root: Node3D, enabled: bool) -> void:
	if is_on == enabled:
		apply_to(root)
		return
	is_on = enabled
	apply_to(root)
	light_state_changed.emit(root, is_on)


func toggle(root: Node3D) -> void:
	set_on(root, not is_on)


func ensure_runtime_light(root: Node3D, owner_node: Node = null) -> Light3D:
	if root == null or not is_instance_valid(root):
		return null
	var existing_light: Light3D = find_first_light(root)
	if existing_light != null:
		_read_initial_values(existing_light)
		apply_to(root)
		return existing_light
	var runtime_light: Light3D = _create_light_node()
	runtime_light.name = "RuntimeLight"
	root.add_child(runtime_light)
	if owner_node != null and is_instance_valid(owner_node):
		runtime_light.set_owner(owner_node)
	apply_to(root)
	return runtime_light


func apply_to(root: Node3D) -> void:
	if root == null or not is_instance_valid(root):
		return
	_apply_to_lights_recursive(root)


func find_first_light(root: Node) -> Light3D:
	if root == null:
		return null
	if root is Light3D:
		return root as Light3D
	for child: Node in root.get_children():
		var found: Light3D = find_first_light(child)
		if found != null:
			return found
	return null


func _create_light_node() -> Light3D:
	if light_kind == LightKind.SPOT:
		var spot: SpotLight3D = SpotLight3D.new()
		spot.spot_range = light_range
		spot.spot_angle = spot_angle
		return spot
	var omni: OmniLight3D = OmniLight3D.new()
	omni.omni_range = light_range
	return omni


func _read_initial_values(light: Light3D) -> void:
	color = light.light_color
	if light.light_energy > 0.0:
		energy = light.light_energy
	casts_shadow = light.shadow_enabled
	if light is SpotLight3D:
		light_kind = LightKind.SPOT
		var spot: SpotLight3D = light as SpotLight3D
		light_range = spot.spot_range
		spot_angle = spot.spot_angle
	elif light is OmniLight3D:
		light_kind = LightKind.OMNI
		var omni: OmniLight3D = light as OmniLight3D
		light_range = omni.omni_range


func _apply_to_lights_recursive(node: Node) -> void:
	if node is Light3D:
		_apply_to_light(node as Light3D)
	for child: Node in node.get_children():
		_apply_to_lights_recursive(child)


func _apply_to_light(light: Light3D) -> void:
	light.light_color = color
	light.light_energy = energy if is_on else 0.0
	light.shadow_enabled = casts_shadow and is_on
	if light is OmniLight3D:
		var omni: OmniLight3D = light as OmniLight3D
		omni.omni_range = light_range
	elif light is SpotLight3D:
		var spot: SpotLight3D = light as SpotLight3D
		spot.spot_range = light_range
		spot.spot_angle = spot_angle

class_name MainUiController
extends Node

var _left_panel: Control = null
var _property_panel: Control = null
var _mode_button: Button = null
var _test_button: Button = null
var _mode_label: Label = null
var _sub_mode_button: Button = null
var _save_view_button: Button = null
var _restore_view_button: Button = null
var _clear_model_selections: Callable = Callable()


func configure(
		left_panel: Control,
		property_panel: Control,
		mode_button: Button,
		test_button: Button,
		mode_label: Label,
		sub_mode_button: Button,
		save_view_button: Button,
		restore_view_button: Button,
		clear_model_selections: Callable
) -> void:
	_left_panel = left_panel
	_property_panel = property_panel
	_mode_button = mode_button
	_test_button = test_button
	_mode_label = mode_label
	_sub_mode_button = sub_mode_button
	_save_view_button = save_view_button
	_restore_view_button = restore_view_button
	_clear_model_selections = clear_model_selections


func apply_for_mode(mode: ModeGate.AppMode, is_map_view: bool = true) -> void:
	apply_topbar_for_mode(mode, is_map_view)
	apply_panel_for_mode(mode)


func apply_topbar_for_mode(mode: ModeGate.AppMode, is_map_view: bool = true) -> void:
	if _mode_button != null and is_instance_valid(_mode_button):
		_mode_button.text = "开始 ▶" if mode == ModeGate.AppMode.EDIT else "◀ 编辑"
	if _test_button != null and is_instance_valid(_test_button):
		_test_button.visible = mode == ModeGate.AppMode.EDIT
	if _mode_label != null and is_instance_valid(_mode_label):
		_mode_label.text = "编辑态" if mode == ModeGate.AppMode.EDIT else "运行态"
	if _save_view_button != null and is_instance_valid(_save_view_button):
		_save_view_button.visible = mode == ModeGate.AppMode.EDIT
	if _restore_view_button != null and is_instance_valid(_restore_view_button):
		_restore_view_button.visible = mode == ModeGate.AppMode.RUN
	if _sub_mode_button != null and is_instance_valid(_sub_mode_button):
		_sub_mode_button.text = "地图" if is_map_view else "自由视角"


func apply_panel_for_mode(mode: ModeGate.AppMode) -> void:
	if mode == ModeGate.AppMode.RUN and _clear_model_selections.is_valid():
		_clear_model_selections.call()


func is_over_left_panel(screen_position: Vector2) -> bool:
	if _left_panel == null or not is_instance_valid(_left_panel):
		return false
	return _left_panel.get_global_rect().has_point(screen_position)


func is_over_property_panel(screen_position: Vector2) -> bool:
	if _property_panel == null or not is_instance_valid(_property_panel):
		return false
	return _property_panel.visible and _property_panel.get_global_rect().has_point(screen_position)


func show_property_panel() -> void:
	if _property_panel != null and is_instance_valid(_property_panel):
		_property_panel.visible = true


func hide_property_panel() -> void:
	if _property_panel != null and is_instance_valid(_property_panel):
		_property_panel.visible = false

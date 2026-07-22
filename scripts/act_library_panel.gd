class_name ActLibraryPanel
extends VBoxContainer

const ACT_ACTION_CREATE: int = 1
const ACT_ACTION_RENAME: int = 2
const ACT_ACTION_NOTES: int = 3
const ACT_ACTION_DELETE: int = 4
const ADD_TEXT: int = 1
const ADD_MEDIA_BASE: int = 1000
const ADD_LOCATION_BASE: int = 2000

var _player_output_controller: PlayerOutputController = null
var _switch_location: Callable = Callable()
var _editable: bool = true
var _viewed_act_id: String = ""
var _selected_item_id: String = ""
var _add_targets: Dictionary = {}

var _act_selector: OptionButton = null
var _act_menu: MenuButton = null
var _add_menu: MenuButton = null
var _search_edit: LineEdit = null
var _item_tree: ActItemTree = null
var _previous_button: Button = null
var _next_button: Button = null
var _present_button: Button = null
var _edit_button: Button = null
var _remove_button: Button = null
var _status_label: Label = null
var _name_dialog: ConfirmationDialog = null
var _name_edit: LineEdit = null
var _name_action: StringName = &""
var _delete_dialog: ConfirmationDialog = null
var _notes_dialog: ConfirmationDialog = null
var _notes_edit: TextEdit = null
var _item_dialog: ConfirmationDialog = null
var _item_name_edit: LineEdit = null
var _item_text_edit: TextEdit = null
var _item_notes_edit: TextEdit = null
var _editing_item_id: String = ""


func _ready() -> void:
	name = "ActLibraryPanel"
	add_to_group("gvtt_gm_act_control")
	add_theme_constant_override("separation", 5)
	_build_ui()
	_connect_module_signals()
	refresh()


func configure(
		player_output_controller: PlayerOutputController,
		switch_location: Callable
) -> void:
	_player_output_controller = player_output_controller
	_switch_location = switch_location
	refresh()


func apply_mode(mode: ModeGate.AppMode) -> void:
	_editable = mode == ModeGate.AppMode.EDIT
	_sync_controls()
	_refresh_tree()


func refresh() -> void:
	_refresh_act_selector()
	_refresh_tree()
	_sync_controls()


func get_item_display_name(item_id: String) -> String:
	var item: ActItemRef = _find_item_anywhere(item_id)
	return _item_info(item).get("display_name", "文字") if item != null else "文字"


func select_act_by_id(act_id: String) -> bool:
	for index: int in range(_act_selector.item_count):
		if String(_act_selector.get_item_metadata(index)) == act_id:
			_act_selector.select(index)
			_viewed_act_id = act_id
			_selected_item_id = ""
			_refresh_tree()
			return true
	return false


func get_viewed_act_id() -> String:
	return _viewed_act_id


func select_item_by_id(item_id: String) -> bool:
	var current: TreeItem = _item_tree.get_root().get_first_child()
	while current != null:
		var metadata: Dictionary = current.get_metadata(0) as Dictionary
		if String(metadata.get("item_id", "")) == item_id:
			current.select(0)
			_selected_item_id = item_id
			_sync_controls()
			return true
		current = current.get_next()
	return false


func get_control_state() -> Dictionary:
	return {
		"editable": _editable,
		"act_menu_disabled": _act_menu.disabled,
		"add_disabled": _add_menu.disabled,
		"previous_disabled": _previous_button.disabled,
		"next_disabled": _next_button.disabled,
		"present_disabled": _present_button.disabled,
		"edit_disabled": _edit_button.disabled,
		"remove_disabled": _remove_button.disabled,
	}


func _build_ui() -> void:
	var act_row: HBoxContainer = HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 4)
	add_child(act_row)
	_act_selector = OptionButton.new()
	_act_selector.name = "ActSelector"
	_act_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_act_selector.tooltip_text = "查看可反复使用的资料幕；切换幕不会改变玩家画面"
	_act_selector.item_selected.connect(_on_act_selected)
	act_row.add_child(_act_selector)
	_act_menu = MenuButton.new()
	_act_menu.name = "ActMenu"
	_act_menu.text = "⋮"
	_act_menu.custom_minimum_size = Vector2(34, 30)
	_act_menu.tooltip_text = "新建、重命名、备注或删除幕"
	var act_popup: PopupMenu = _act_menu.get_popup()
	act_popup.add_item("新建幕", ACT_ACTION_CREATE)
	act_popup.add_item("重命名", ACT_ACTION_RENAME)
	act_popup.add_item("GM 备注", ACT_ACTION_NOTES)
	act_popup.add_separator()
	act_popup.add_item("删除幕", ACT_ACTION_DELETE)
	act_popup.id_pressed.connect(_on_act_action)
	act_row.add_child(_act_menu)
	_add_menu = MenuButton.new()
	_add_menu.name = "ActAddMenu"
	_add_menu.text = "+"
	_add_menu.custom_minimum_size = Vector2(34, 30)
	_add_menu.tooltip_text = "把媒体、文字或地图加入正在查看的幕"
	_add_menu.get_popup().about_to_popup.connect(_rebuild_add_menu)
	_add_menu.get_popup().id_pressed.connect(_on_add_action)
	act_row.add_child(_add_menu)
	_search_edit = LineEdit.new()
	_search_edit.name = "ActSearch"
	_search_edit.placeholder_text = "搜索本幕内容"
	_search_edit.clear_button_enabled = true
	_search_edit.tooltip_text = "按名称、类型或状态过滤；搜索时暂停拖动排序"
	_search_edit.text_changed.connect(_on_search_changed)
	add_child(_search_edit)
	_item_tree = ActItemTree.new()
	_item_tree.name = "ActItemTree"
	_item_tree.hide_root = true
	_item_tree.columns = 1
	_item_tree.custom_minimum_size = Vector2(0, 190)
	_item_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_tree.item_selected.connect(_on_item_selected)
	_item_tree.reorder_requested.connect(_on_reorder_requested)
	add_child(_item_tree)
	var nav_row: HBoxContainer = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 3)
	add_child(nav_row)
	_previous_button = _command_button("↑", "选择上一项", _select_previous)
	_next_button = _command_button("↓", "选择下一项", _select_next)
	_present_button = _command_button("投放", "把选中内容展示给玩家", _present_selected)
	_present_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_button = _command_button("编辑", "编辑名称、文本或 GM 备注", _edit_selected)
	_remove_button = _command_button("移出", "只从正在查看的幕移除，不删除原内容", _remove_selected)
	_previous_button.name = "ActPreviousButton"
	_next_button.name = "ActNextButton"
	_present_button.name = "ActPresentButton"
	_edit_button.name = "ActEditButton"
	_remove_button.name = "ActRemoveButton"
	for button: Button in [
		_previous_button,
		_next_button,
		_present_button,
		_edit_button,
		_remove_button,
	]:
		nav_row.add_child(button)
	_status_label = Label.new()
	_status_label.name = "ActStatus"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
	add_child(_status_label)


func _command_button(text_value: String, tooltip: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(30, 30)
	button.tooltip_text = tooltip
	button.pressed.connect(action)
	return button


func _connect_module_signals() -> void:
	if not ModuleGate.acts_changed.is_connected(refresh):
		ModuleGate.acts_changed.connect(refresh)
	if not ModuleGate.external_contents_changed.is_connected(refresh):
		ModuleGate.external_contents_changed.connect(refresh)
	if not ModuleGate.scene_list_changed.is_connected(refresh):
		ModuleGate.scene_list_changed.connect(refresh)
	if not ModuleGate.module_changed.is_connected(_on_module_changed):
		ModuleGate.module_changed.connect(_on_module_changed)


func _on_module_changed(_module_name: String) -> void:
	_viewed_act_id = ""
	_selected_item_id = ""
	refresh()


func _refresh_act_selector() -> void:
	if _act_selector == null:
		return
	_act_selector.clear()
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		_viewed_act_id = ""
		return
	var selected_index: int = -1
	for act: ActRef in manifest.acts:
		_act_selector.add_item(act.display_name)
		var index: int = _act_selector.item_count - 1
		_act_selector.set_item_metadata(index, act.act_id)
		if act.act_id == _viewed_act_id:
			selected_index = index
	if selected_index < 0 and _act_selector.item_count > 0:
		selected_index = 0
	if selected_index >= 0:
		_act_selector.select(selected_index)
		_viewed_act_id = String(_act_selector.get_item_metadata(selected_index))
	else:
		_viewed_act_id = ""


func _refresh_tree() -> void:
	if _item_tree == null:
		return
	_item_tree.clear()
	var root: TreeItem = _item_tree.create_item()
	var act: ActRef = _current_act()
	if act == null:
		_selected_item_id = ""
		_item_tree.configure_context("", false)
		_status_label.text = "还没有幕。" if ModuleGate.has_open_module() else "未打开模组。"
		return
	var filter_text: String = _search_edit.text.strip_edges().to_lower()
	var selected_tree_item: TreeItem = null
	for index: int in range(act.items.size()):
		var item: ActItemRef = act.items[index]
		var info: Dictionary = _item_info(item)
		var searchable: String = (
			String(info.get("display_name", ""))
			+ " "
			+ String(info.get("type_label", ""))
			+ " "
			+ String(info.get("status", ""))
		).to_lower()
		if filter_text != "" and not searchable.contains(filter_text):
			continue
		var tree_item: TreeItem = _item_tree.create_item(root)
		tree_item.set_text(
			0,
			"%s · %s" % [String(info.get("type_label", "内容")), String(info.get("display_name", "未命名"))]
		)
		tree_item.set_tooltip_text(
			0,
			"%s\n%s" % [String(info.get("status", "")), item.gm_notes]
		)
		tree_item.set_metadata(0, {"item_id": item.item_id, "source_index": index})
		tree_item.set_custom_color(0, _status_color(StringName(String(info.get("status_key", "")))))
		if item.item_id == _selected_item_id:
			selected_tree_item = tree_item
	if selected_tree_item != null:
		selected_tree_item.select(0)
	elif root.get_first_child() != null:
		root.get_first_child().select(0)
		_selected_item_id = String((root.get_first_child().get_metadata(0) as Dictionary).get("item_id", ""))
	else:
		_selected_item_id = ""
	_item_tree.configure_context(_viewed_act_id, _editable and filter_text == "")
	_status_label.text = "%d 项%s" % [act.items.size(), "；搜索结果已过滤" if filter_text != "" else ""]
	_sync_controls()


func _item_info(item: ActItemRef) -> Dictionary:
	if item == null:
		return {"display_name": "缺失内容", "type_label": "内容", "status": "缺失", "status_key": "missing", "available": false}
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	match item.item_type:
		ActItemRef.ItemType.MEDIA:
			var content: ExternalContentRef = _find_media(item.target_id)
			if content == null:
				return _missing_info(item, "媒体")
			var inspection: Dictionary = MediaRegistry.inspect(content, ModuleGate.current_module_dir())
			var status_key: StringName = StringName(String(inspection.get("status", "")))
			return {
				"display_name": item.display_name if item.display_name != "" else content.display_name,
				"type_label": "图片" if content.content_type == ExternalContentRef.ContentType.IMAGE else "视频",
				"status": String(inspection.get("status_text", status_key)),
				"status_key": status_key,
				"available": status_key == MediaRegistry.STATUS_PLAYABLE,
			}
		ActItemRef.ItemType.LOCATION:
			var location: LocationRef = manifest.find_location_by_id(item.target_id) if manifest != null else null
			if location == null:
				return _missing_info(item, "地图")
			return {
				"display_name": item.display_name if item.display_name != "" else location.display_name,
				"type_label": "地图",
				"status": "可用" if location.available else "缺失",
				"status_key": "playable" if location.available else "missing",
				"available": location.available,
			}
		ActItemRef.ItemType.TEXT:
			var has_text: bool = item.text_content.strip_edges() != ""
			return {
				"display_name": item.display_name,
				"type_label": "文字",
				"status": "可展示" if has_text else "空文本",
				"status_key": "playable" if has_text else "damaged",
				"available": has_text,
			}
	return _missing_info(item, "内容")


func _missing_info(item: ActItemRef, type_label: String) -> Dictionary:
	return {
		"display_name": item.display_name if item.display_name != "" else "缺失引用",
		"type_label": type_label,
		"status": "缺失引用",
		"status_key": "missing",
		"available": false,
	}


func _status_color(status_key: StringName) -> Color:
	if status_key == MediaRegistry.STATUS_PLAYABLE or status_key == &"playable":
		return Color(0.78, 0.9, 0.78)
	if status_key == MediaRegistry.STATUS_MISSING or status_key == &"missing":
		return Color(0.95, 0.62, 0.32)
	if status_key == MediaRegistry.STATUS_DAMAGED or status_key == &"damaged":
		return Color(0.95, 0.42, 0.42)
	return Color(0.82, 0.78, 0.55)


func _sync_controls() -> void:
	var has_module: bool = ModuleGate.has_open_module()
	var act: ActRef = _current_act()
	var item: ActItemRef = _selected_item()
	_act_selector.disabled = not has_module or _act_selector.item_count == 0
	_act_menu.disabled = not has_module or not _editable
	_add_menu.disabled = not _editable or act == null
	_search_edit.editable = act != null
	_previous_button.disabled = item == null or _visible_item_position() <= 0
	_next_button.disabled = item == null or _visible_item_position() >= _visible_item_count() - 1
	_present_button.disabled = item == null or not bool(_item_info(item).get("available", false))
	_edit_button.disabled = not _editable or item == null
	_remove_button.disabled = not _editable or item == null
	var popup: PopupMenu = _act_menu.get_popup()
	for action_id: int in [ACT_ACTION_CREATE, ACT_ACTION_RENAME, ACT_ACTION_NOTES, ACT_ACTION_DELETE]:
		var popup_index: int = popup.get_item_index(action_id)
		if popup_index >= 0:
			popup.set_item_disabled(
				popup_index,
				not _editable or action_id != ACT_ACTION_CREATE and act == null
			)


func _on_act_selected(index: int) -> void:
	if index < 0 or index >= _act_selector.item_count:
		return
	_viewed_act_id = String(_act_selector.get_item_metadata(index))
	_selected_item_id = ""
	_refresh_tree()


func _on_item_selected() -> void:
	var selected: TreeItem = _item_tree.get_selected()
	if selected == null or not (selected.get_metadata(0) is Dictionary):
		_selected_item_id = ""
	else:
		_selected_item_id = String((selected.get_metadata(0) as Dictionary).get("item_id", ""))
	_sync_controls()


func _on_search_changed(_value: String) -> void:
	_refresh_tree()


func _on_reorder_requested(item_id: String, target_index: int) -> void:
	var error: int = ModuleGate.move_act_item(_viewed_act_id, item_id, target_index)
	_set_status("顺序已保存" if error == OK else "排序失败 code=" + str(error), error == OK)


func _on_act_action(action_id: int) -> void:
	match action_id:
		ACT_ACTION_CREATE:
			_show_name_dialog(&"create", "新建幕", "")
		ACT_ACTION_RENAME:
			var act: ActRef = _current_act()
			if act != null:
				_show_name_dialog(&"rename", "重命名幕", act.display_name)
		ACT_ACTION_NOTES:
			_show_notes_dialog()
		ACT_ACTION_DELETE:
			_show_delete_dialog()


func _show_name_dialog(action: StringName, title: String, initial_text: String) -> void:
	_close_name_dialog()
	_name_action = action
	_name_dialog = ConfirmationDialog.new()
	_name_dialog.title = title
	_name_dialog.ok_button_text = "保存"
	_name_edit = LineEdit.new()
	_name_edit.text = initial_text
	_name_edit.placeholder_text = "幕名称"
	_name_dialog.add_child(_name_edit)
	_name_dialog.register_text_enter(_name_edit)
	_name_dialog.confirmed.connect(_on_name_confirmed)
	_name_dialog.canceled.connect(_close_name_dialog)
	add_child(_name_dialog)
	_name_dialog.popup_centered(Vector2i(420, 0))
	_name_edit.select_all()
	_name_edit.grab_focus()


func _on_name_confirmed() -> void:
	var value: String = _name_edit.text if _name_edit != null else ""
	var error: int = ERR_INVALID_PARAMETER
	if _name_action == &"create":
		var result: Dictionary = ModuleGate.create_act(value)
		error = int(result.get("error", FAILED))
		var act: ActRef = result.get("act") as ActRef
		if act != null:
			_viewed_act_id = act.act_id
	elif _name_action == &"rename":
		error = ModuleGate.rename_act(_viewed_act_id, value)
	_close_name_dialog()
	_set_status("幕已保存" if error == OK else "幕保存失败 code=" + str(error), error == OK)


func _close_name_dialog() -> void:
	if _name_dialog != null and is_instance_valid(_name_dialog):
		_name_dialog.queue_free()
	_name_dialog = null
	_name_edit = null
	_name_action = &""


func _show_notes_dialog() -> void:
	var act: ActRef = _current_act()
	if act == null:
		return
	if _notes_dialog != null and is_instance_valid(_notes_dialog):
		_notes_dialog.queue_free()
	_notes_dialog = ConfirmationDialog.new()
	_notes_dialog.title = "幕的 GM 备注"
	_notes_dialog.ok_button_text = "保存备注"
	_notes_edit = TextEdit.new()
	_notes_edit.text = act.gm_notes
	_notes_edit.custom_minimum_size = Vector2(460, 220)
	_notes_dialog.add_child(_notes_edit)
	_notes_dialog.confirmed.connect(_on_notes_confirmed)
	add_child(_notes_dialog)
	_notes_dialog.popup_centered(Vector2i(500, 300))


func _on_notes_confirmed() -> void:
	var error: int = ModuleGate.update_act_notes(
		_viewed_act_id,
		_notes_edit.text if _notes_edit != null else ""
	)
	if _notes_dialog != null:
		_notes_dialog.queue_free()
	_notes_dialog = null
	_notes_edit = null
	_set_status("备注已保存" if error == OK else "备注保存失败 code=" + str(error), error == OK)


func _show_delete_dialog() -> void:
	var act: ActRef = _current_act()
	if act == null:
		return
	if _delete_dialog != null and is_instance_valid(_delete_dialog):
		_delete_dialog.queue_free()
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "删除幕"
	_delete_dialog.dialog_text = "删除“%s”？只删除幕和引用，不删除原媒体或地图。" % act.display_name
	_delete_dialog.ok_button_text = "删除幕"
	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_dialog)
	_delete_dialog.popup_centered(Vector2i(440, 0))


func _on_delete_confirmed() -> void:
	var error: int = ModuleGate.remove_act(_viewed_act_id)
	_viewed_act_id = ""
	_selected_item_id = ""
	if _delete_dialog != null:
		_delete_dialog.queue_free()
	_delete_dialog = null
	_set_status("幕已删除" if error == OK else "幕删除失败 code=" + str(error), error == OK)


func _rebuild_add_menu() -> void:
	var popup: PopupMenu = _add_menu.get_popup()
	popup.clear()
	_add_targets.clear()
	popup.add_item("新建文字", ADD_TEXT)
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		return
	if not manifest.external_contents.is_empty():
		popup.add_separator("媒体")
	for index: int in range(manifest.external_contents.size()):
		var content: ExternalContentRef = manifest.external_contents[index]
		var action_id: int = ADD_MEDIA_BASE + index
		popup.add_item(content.display_name, action_id)
		_add_targets[action_id] = {"type": ActItemRef.ItemType.MEDIA, "target_id": content.content_id}
	if not manifest.locations.is_empty():
		popup.add_separator("地图")
	for index: int in range(manifest.locations.size()):
		var location: LocationRef = manifest.locations[index]
		var action_id: int = ADD_LOCATION_BASE + index
		popup.add_item(location.display_name, action_id)
		_add_targets[action_id] = {"type": ActItemRef.ItemType.LOCATION, "target_id": location.location_id}


func _on_add_action(action_id: int) -> void:
	if action_id == ADD_TEXT:
		_show_item_dialog(null)
		return
	if not _add_targets.has(action_id):
		return
	var target: Dictionary = _add_targets[action_id] as Dictionary
	var result: Dictionary = ModuleGate.add_act_item(
		_viewed_act_id,
		int(target.get("type", ActItemRef.ItemType.MEDIA)),
		String(target.get("target_id", ""))
	)
	var error: int = int(result.get("error", FAILED))
	var item: ActItemRef = result.get("item") as ActItemRef
	if item != null:
		_selected_item_id = item.item_id
	_set_status("内容已加入幕" if error == OK else "加入失败 code=" + str(error), error == OK)


func _edit_selected() -> void:
	var item: ActItemRef = _selected_item()
	if item != null:
		_show_item_dialog(item)


func _show_item_dialog(item: ActItemRef) -> void:
	if _item_dialog != null and is_instance_valid(_item_dialog):
		_item_dialog.queue_free()
	_editing_item_id = item.item_id if item != null else ""
	_item_dialog = ConfirmationDialog.new()
	_item_dialog.title = "编辑幕内容" if item != null else "新建文字"
	_item_dialog.ok_button_text = "保存"
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_item_dialog.add_child(body)
	_item_name_edit = LineEdit.new()
	_item_name_edit.placeholder_text = "显示名称"
	_item_name_edit.text = item.display_name if item != null else ""
	body.add_child(_item_name_edit)
	_item_text_edit = TextEdit.new()
	_item_text_edit.placeholder_text = "展示给玩家的纯文本"
	_item_text_edit.custom_minimum_size = Vector2(480, 180)
	_item_text_edit.text = item.text_content if item != null else ""
	_item_text_edit.visible = item == null or item.item_type == ActItemRef.ItemType.TEXT
	body.add_child(_item_text_edit)
	_item_notes_edit = TextEdit.new()
	_item_notes_edit.placeholder_text = "GM 私有备注"
	_item_notes_edit.custom_minimum_size = Vector2(480, 100)
	_item_notes_edit.text = item.gm_notes if item != null else ""
	body.add_child(_item_notes_edit)
	_item_dialog.confirmed.connect(_on_item_confirmed)
	add_child(_item_dialog)
	_item_dialog.popup_centered(Vector2i(540, 380))


func _on_item_confirmed() -> void:
	var display_name: String = _item_name_edit.text if _item_name_edit != null else ""
	var text_content: String = _item_text_edit.text if _item_text_edit != null else ""
	var gm_notes: String = _item_notes_edit.text if _item_notes_edit != null else ""
	var error: int = ERR_INVALID_PARAMETER
	if _editing_item_id == "":
		var result: Dictionary = ModuleGate.add_act_item(
			_viewed_act_id,
			ActItemRef.ItemType.TEXT,
			"",
			display_name,
			text_content,
			gm_notes
		)
		error = int(result.get("error", FAILED))
		var item: ActItemRef = result.get("item") as ActItemRef
		if item != null:
			_selected_item_id = item.item_id
	else:
		error = ModuleGate.update_act_item(
			_viewed_act_id,
			_editing_item_id,
			display_name,
			text_content,
			gm_notes
		)
	_close_item_dialog()
	_set_status("内容已保存" if error == OK else "内容保存失败 code=" + str(error), error == OK)


func _close_item_dialog() -> void:
	if _item_dialog != null and is_instance_valid(_item_dialog):
		_item_dialog.queue_free()
	_item_dialog = null
	_item_name_edit = null
	_item_text_edit = null
	_item_notes_edit = null
	_editing_item_id = ""


func _remove_selected() -> void:
	var error: int = ModuleGate.remove_act_item(_viewed_act_id, _selected_item_id)
	_selected_item_id = ""
	_set_status("已从幕移出；原内容未删除" if error == OK else "移出失败 code=" + str(error), error == OK)


func _present_selected() -> void:
	var item: ActItemRef = _selected_item()
	if item == null or not bool(_item_info(item).get("available", false)):
		_set_status("选中内容不可用", false)
		return
	if item.item_type == ActItemRef.ItemType.LOCATION:
		var manifest: ModuleManifest = ModuleGate.current_manifest()
		var location: LocationRef = manifest.find_location_by_id(item.target_id) if manifest != null else null
		if location == null or not _switch_location.is_valid():
			_set_status("地图切换入口不可用", false)
			return
		_switch_location.call(location.display_name)
		_set_status("已切换地图 · " + location.display_name, true)
		return
	if not _ensure_output_open():
		return
	if item.item_type == ActItemRef.ItemType.TEXT:
		_player_output_controller.show_text(item.item_id, item.display_name, item.text_content)
		_set_status("已投放文字 · " + item.display_name, true)
		return
	var content: ExternalContentRef = _find_media(item.target_id)
	if content == null:
		_set_status("媒体引用缺失", false)
		return
	if content.content_type == ExternalContentRef.ContentType.IMAGE:
		_player_output_controller.show_image(content)
	else:
		_player_output_controller.show_video(content)
	_set_status("已投放 · " + content.display_name, true)


func _ensure_output_open() -> bool:
	if _player_output_controller == null or not is_instance_valid(_player_output_controller):
		_set_status("投屏控制器不可用", false)
		return false
	if _player_output_controller.is_open():
		return true
	var result: Dictionary = _player_output_controller.open_output()
	if int(result.get("error", FAILED)) != OK:
		_set_status(String(result.get("message", "投屏窗口打开失败")), false)
		return false
	return true


func _select_previous() -> void:
	_select_visible_offset(-1)


func _select_next() -> void:
	_select_visible_offset(1)


func _select_visible_offset(offset: int) -> void:
	var selected: TreeItem = _item_tree.get_selected()
	if selected == null:
		return
	var target: TreeItem = selected.get_prev_visible(false) if offset < 0 else selected.get_next_visible(false)
	if target == null or target == _item_tree.get_root():
		return
	target.select(0)
	_item_tree.scroll_to_item(target)
	_on_item_selected()


func _visible_item_position() -> int:
	var selected: TreeItem = _item_tree.get_selected()
	if selected == null:
		return -1
	var index: int = 0
	var current: TreeItem = _item_tree.get_root().get_first_child()
	while current != null:
		if current == selected:
			return index
		index += 1
		current = current.get_next()
	return -1


func _visible_item_count() -> int:
	var count: int = 0
	var current: TreeItem = _item_tree.get_root().get_first_child()
	while current != null:
		count += 1
		current = current.get_next()
	return count


func _current_act() -> ActRef:
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	return manifest.find_act_by_id(_viewed_act_id) if manifest != null else null


func _selected_item() -> ActItemRef:
	var act: ActRef = _current_act()
	return act.find_item(_selected_item_id) if act != null else null


func _find_item_anywhere(item_id: String) -> ActItemRef:
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		return null
	for act: ActRef in manifest.acts:
		var item: ActItemRef = act.find_item(item_id)
		if item != null:
			return item
	return null


func _find_media(content_id: String) -> ExternalContentRef:
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		return null
	for content: ExternalContentRef in manifest.external_contents:
		if content.content_id == content_id:
			return content
	return null


func _set_status(message: String, success: bool) -> void:
	if _status_label == null:
		return
	_status_label.text = message
	_status_label.add_theme_color_override(
		"font_color",
		Color(0.35, 0.82, 0.45) if success else Color(0.95, 0.42, 0.42)
	)

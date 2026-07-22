class_name TextOutputPresenter
extends PlayerOutputPresenter

var _host: Control = null
var _root: MarginContainer = null
var _title_label: Label = null
var _body_label: Label = null


func configure(host: Control) -> void:
	_host = host


func prepare(request_id: int, resolved_content: Dictionary) -> void:
	super.prepare(request_id, resolved_content)
	if _host == null or not is_instance_valid(_host):
		failed.emit(request_id, ERR_UNCONFIGURED, "文本承载面不可用")
		return
	var text_content: String = String(resolved_content.get("text_content", ""))
	if text_content.strip_edges() == "":
		failed.emit(request_id, ERR_INVALID_DATA, "文本内容为空")
		return
	_root = MarginContainer.new()
	_root.name = "TextOutput"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("margin_left", 72)
	_root.add_theme_constant_override("margin_top", 56)
	_root.add_theme_constant_override("margin_right", 72)
	_root.add_theme_constant_override("margin_bottom", 56)
	_root.add_to_group("gvtt_player_output_text")
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(body)
	_title_label = Label.new()
	_title_label.name = "TextTitle"
	_title_label.text = String(resolved_content.get("title", ""))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.58))
	_title_label.visible = _title_label.text.strip_edges() != ""
	body.add_child(_title_label)
	_body_label = Label.new()
	_body_label.name = "TextBody"
	_body_label.text = text_content
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_body_label.add_theme_font_size_override("font_size", 28)
	body.add_child(_body_label)
	_root.hide()
	_host.add_child(_root)
	prepared.emit(request_id)


func activate() -> int:
	if _root == null or not is_instance_valid(_root):
		return ERR_UNCONFIGURED
	_root.show()
	return OK


func deactivate(_reason: StringName) -> void:
	if _root != null and is_instance_valid(_root):
		_root.hide()


func release() -> void:
	if _released:
		return
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_title_label = null
	_body_label = null
	_host = null
	super.release()

class_name ImageOutputPresenter
extends PlayerOutputPresenter

const FADE_DURATION_SECONDS: float = 0.18

var _host: Control = null
var _texture_rect: TextureRect = null
var _image: Image = null
var _texture: ImageTexture = null
var _natural_size: Vector2i = Vector2i.ZERO
var _fade_tween: Tween = null


func configure(host: Control) -> void:
	_host = host


func prepare(request_id: int, resolved_content: Dictionary) -> void:
	super.prepare(request_id, resolved_content)
	if _host == null or not is_instance_valid(_host):
		failed.emit(request_id, ERR_UNCONFIGURED, "图片承载面不可用")
		return
	var path: String = String(resolved_content.get("resolved_path", ""))
	_image = Image.load_from_file(path)
	if _image == null or _image.is_empty():
		_image = null
		failed.emit(request_id, ERR_FILE_CORRUPT, "图片无法解码")
		return
	_natural_size = _image.get_size()
	_texture = ImageTexture.create_from_image(_image)
	if _texture == null or _natural_size.x <= 0 or _natural_size.y <= 0:
		failed.emit(request_id, ERR_CANT_CREATE, "图片纹理创建失败")
		return
	_texture_rect = TextureRect.new()
	_texture_rect.name = "ImageOutput"
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.add_to_group("gvtt_player_output_texture")
	_texture_rect.texture = _texture
	_texture_rect.modulate.a = 0.0
	_texture_rect.hide()
	_host.add_child(_texture_rect)
	prepared.emit(request_id)


func activate() -> int:
	if _texture_rect == null or not is_instance_valid(_texture_rect):
		return ERR_UNCONFIGURED
	_kill_fade_tween()
	_texture_rect.show()
	_fade_tween = create_tween().bind_node(self)
	_fade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(
		_texture_rect,
		"modulate:a",
		1.0,
		FADE_DURATION_SECONDS
	)
	return OK


func deactivate(reason: StringName) -> void:
	_kill_fade_tween()
	if _texture_rect != null and is_instance_valid(_texture_rect):
		if reason == &"return_to_map":
			_create_fade_out_overlay()
		_texture_rect.hide()


func release() -> void:
	if _released:
		return
	if _texture_rect != null and is_instance_valid(_texture_rect):
		_texture_rect.texture = null
		_texture_rect.queue_free()
	_texture_rect = null
	_texture = null
	_image = null
	_natural_size = Vector2i.ZERO
	_fade_tween = null
	_host = null
	super.release()


func get_natural_size() -> Vector2i:
	return _natural_size


func get_output_texture() -> Texture2D:
	return _texture


func _create_fade_out_overlay() -> void:
	if _host == null or not is_instance_valid(_host) or _texture == null:
		return
	var fade_rect: TextureRect = TextureRect.new()
	fade_rect.name = "ImageFadeOut"
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.texture = _texture
	fade_rect.modulate.a = _texture_rect.modulate.a
	fade_rect.add_to_group("gvtt_player_output_image_fade")
	_host.add_child(fade_rect)
	var fade_out_tween: Tween = fade_rect.create_tween()
	fade_out_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_out_tween.tween_property(
		fade_rect,
		"modulate:a",
		0.0,
		FADE_DURATION_SECONDS
	)
	fade_out_tween.tween_callback(fade_rect.queue_free)


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null

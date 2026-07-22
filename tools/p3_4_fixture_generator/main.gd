extends Control

const TOTAL_FRAMES: int = 270
const VIDEO_SIZE: Vector2i = Vector2i(640, 360)
const AUDIO_MIX_RATE: int = 48000
const AUDIO_DURATION_SECONDS: float = 9.0
const MELODY_NOTE_SECONDS: float = 0.5
const BASS_BAR_SECONDS: float = 2.25
const AUDIO_AMPLITUDE: float = 0.12
const AUDIO_FADE_SECONDS: float = 0.35

var _frame_index: int = 0
var _tone_player: AudioStreamPlayer = null


func _ready() -> void:
	var output_dir: String = _output_dir()
	var directory_error: int = DirAccess.make_dir_recursive_absolute(output_dir)
	if directory_error != OK:
		push_error("P3.4 夹具目录创建失败 code=%d" % directory_error)
		get_tree().quit(1)
		return
	var image_error: int = _write_quadrant_image(output_dir.path_join("quadrants_640x480.png"))
	if image_error != OK:
		push_error("P3.4 图片夹具写入失败 code=%d" % image_error)
		get_tree().quit(1)
		return
	_tone_player = AudioStreamPlayer.new()
	_tone_player.name = "FixtureTone"
	_tone_player.stream = _build_test_tone()
	add_child(_tone_player)
	_tone_player.play()
	queue_redraw()


func _process(_delta: float) -> void:
	_frame_index += 1
	queue_redraw()
	if _frame_index > TOTAL_FRAMES:
		set_process(false)
		_release_tone()
		get_tree().quit(0)


func _draw() -> void:
	var frame_value: int = mini(_frame_index, TOTAL_FRAMES - 1)
	var time_seconds: float = float(frame_value) / 30.0
	var travel_ratio: float = float(frame_value) / float(TOTAL_FRAMES - 1)
	var cycle_ratio: float = fmod(time_seconds, 3.0) / 3.0
	for band_index: int in range(18):
		var band_ratio: float = float(band_index) / 17.0
		var band_color: Color = Color(0.03, 0.05, 0.12, 1.0).lerp(Color(0.14, 0.05, 0.18, 1.0), band_ratio)
		draw_rect(Rect2(0.0, float(band_index) * 20.0, 640.0, 21.0), band_color)

	draw_rect(Rect2(34.0, 34.0, 572.0, 292.0), Color(0.015, 0.02, 0.05, 0.78))
	draw_rect(Rect2(42.0, 42.0, 556.0, 276.0), Color(0.08, 0.12, 0.2, 0.65), false, 2.0)
	draw_line(Vector2(72.0, 214.0), Vector2(568.0, 214.0), Color(0.2, 0.28, 0.38, 0.8), 2.0)

	var primary_x: float = 150.0 + 210.0 * sin(time_seconds * 0.9)
	var primary_y: float = 150.0 + 30.0 * cos(time_seconds * 1.4)
	var primary_radius: float = 34.0 + 8.0 * sin(time_seconds * 2.2)
	draw_circle(Vector2(primary_x, primary_y), primary_radius + 12.0, Color(0.05, 0.7, 0.9, 0.12))
	draw_circle(Vector2(primary_x, primary_y), primary_radius, Color(0.1, 0.78, 0.92, 0.95))

	var diamond_x: float = 470.0 - 150.0 * sin(time_seconds * 0.9 + 0.8)
	var diamond_y: float = 148.0 + 38.0 * sin(time_seconds * 1.15)
	var diamond_size: float = 30.0 + 9.0 * cos(time_seconds * 1.8)
	var diamond_points: PackedVector2Array = PackedVector2Array([
		Vector2(diamond_x, diamond_y - diamond_size),
		Vector2(diamond_x + diamond_size, diamond_y),
		Vector2(diamond_x, diamond_y + diamond_size),
		Vector2(diamond_x - diamond_size, diamond_y),
	])
	draw_colored_polygon(diamond_points, Color(0.98, 0.45, 0.22, 0.95))

	draw_string(ThemeDB.fallback_font, Vector2(76.0, 270.0), "GVTT MEDIA CHECK", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color(0.94, 0.96, 1.0, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(78.0, 294.0), "VIDEO / AUDIO / OGV", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.55, 0.72, 0.84, 1.0))

	draw_rect(Rect2(78.0, 302.0, 484.0, 6.0), Color(0.16, 0.2, 0.3, 1.0))
	draw_rect(Rect2(78.0, 302.0, 484.0 * travel_ratio, 6.0), Color(0.98, 0.78, 0.24, 1.0))
	for marker_index: int in range(4):
		var marker_x: float = 78.0 + float(marker_index) * 161.3
		draw_circle(Vector2(marker_x, 305.0), 4.0, Color(1.0, 0.9, 0.45, 1.0))
	if cycle_ratio < 0.5:
		draw_circle(Vector2(566.0, 70.0), 5.0, Color(0.3, 0.95, 0.55, 1.0))


func _output_dir() -> String:
	var generator_root: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var workspace_root: String = generator_root.get_base_dir().get_base_dir()
	return workspace_root.path_join("tests").path_join("fixtures").path_join("p3_4")


func _write_quadrant_image(path: String) -> int:
	var image: Image = Image.create_empty(640, 480, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	image.fill_rect(Rect2i(0, 0, 320, 240), Color(0.9, 0.08, 0.08, 1.0))
	image.fill_rect(Rect2i(320, 0, 320, 240), Color(0.08, 0.85, 0.15, 1.0))
	image.fill_rect(Rect2i(0, 240, 320, 240), Color(0.08, 0.2, 0.92, 1.0))
	image.fill_rect(Rect2i(320, 240, 320, 240), Color(0.95, 0.82, 0.08, 1.0))
	image.fill_rect(Rect2i(304, 224, 32, 32), Color(0.95, 0.08, 0.85, 1.0))
	return image.save_png(path)


func _build_test_tone() -> AudioStreamWAV:
	var sample_count: int = roundi(float(AUDIO_MIX_RATE) * AUDIO_DURATION_SECONDS)
	var melody_frequencies_hz: PackedFloat32Array = PackedFloat32Array([
		261.63, 329.63, 392.0, 329.63, 220.0, 261.63,
		349.23, 329.63, 196.0, 246.94, 293.66, 246.94,
		220.0, 293.66, 392.0, 329.63, 293.66, 261.63,
	])
	var bass_frequencies_hz: PackedFloat32Array = PackedFloat32Array([130.81, 110.0, 146.83, 98.0])
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index: int in range(sample_count):
		var time_seconds: float = float(sample_index) / float(AUDIO_MIX_RATE)
		var note_index: int = mini(floori(time_seconds / MELODY_NOTE_SECONDS), melody_frequencies_hz.size() - 1)
		var note_time: float = fmod(time_seconds, MELODY_NOTE_SECONDS)
		var melody_frequency_hz: float = melody_frequencies_hz[note_index]
		var melody_phase: float = TAU * melody_frequency_hz * note_time
		var melody_wave: float = 0.84 * sin(melody_phase) + 0.16 * sin(melody_phase * 2.0)
		var melody: float = melody_wave * _note_envelope(note_time, MELODY_NOTE_SECONDS)

		var bar_index: int = mini(floori(time_seconds / BASS_BAR_SECONDS), bass_frequencies_hz.size() - 1)
		var bar_time: float = fmod(time_seconds, BASS_BAR_SECONDS)
		var bass_frequency_hz: float = bass_frequencies_hz[bar_index]
		var bass_phase: float = TAU * bass_frequency_hz * bar_time
		var bass_attack: float = minf(bar_time / 0.12, 1.0)
		var bass_decay: float = exp(-bar_time * 0.65)
		var bass: float = sin(bass_phase) * bass_attack * bass_decay

		var envelope: float = _tone_envelope(sample_index, sample_count)
		var music_sample: float = 0.78 * melody + 0.22 * bass
		var sample: int = roundi(music_sample * AUDIO_AMPLITUDE * envelope * 32767.0)
		data.encode_s16(sample_index * 2, sample)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream


func _note_envelope(note_time: float, note_duration: float) -> float:
	var attack: float = minf(note_time / 0.06, 1.0)
	var release: float = minf((note_duration - note_time) / 0.16, 1.0)
	return attack * release


func _tone_envelope(sample_index: int, sample_count: int) -> float:
	var fade_samples: int = roundi(float(AUDIO_MIX_RATE) * AUDIO_FADE_SECONDS)
	if sample_index < fade_samples:
		return float(sample_index) / float(fade_samples)
	if sample_index >= sample_count - fade_samples:
		return float(sample_count - sample_index - 1) / float(fade_samples)
	return 1.0


func _release_tone() -> void:
	if _tone_player == null:
		return
	_tone_player.stop()
	_tone_player.stream = null
	remove_child(_tone_player)
	_tone_player.free()
	_tone_player = null

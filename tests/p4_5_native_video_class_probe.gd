extends Node

const FIXTURE_PATH: String = "res://build/p45_acceptance/vlc_fixture.mp4"
const NATIVE_VIDEO_BACKEND_SCRIPT: Script = preload("res://scripts/native_video_playback_backend.gd")


func _ready() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var failures: Array[String] = []
	var extension_loaded: bool = NATIVE_VIDEO_BACKEND_SCRIPT.ensure_extension_loaded()
	_check(extension_loaded, "Native Video extension did not load", failures)
	_check(ClassDB.class_exists(&"NativeVideoStream"), "NativeVideoStream was not registered", failures)
	_check(
		ClassDB.class_exists(&"NativeVideoStreamPlayback"),
		"NativeVideoStreamPlayback was not registered",
		failures
	)
	var absolute_fixture_path: String = ProjectSettings.globalize_path(FIXTURE_PATH)
	var stream: VideoStream = NATIVE_VIDEO_BACKEND_SCRIPT.create_stream(absolute_fixture_path)
	_check(stream != null, "Real MP4 did not load as VideoStream", failures)
	_check(stream != null and stream.get_class() == "NativeVideoStream", "MP4 loader returned the wrong stream class", failures)
	var resource_type: String = stream.get_class() if stream != null else ""
	var duration_seconds: float = _probe_duration(stream)
	_check(duration_seconds > 0.0, "Real MP4 did not expose a positive duration", failures)
	stream = null

	var corrupt_path: String = ProjectSettings.globalize_path(
		"res://build/p45_acceptance/p45_native_video_corrupt.mp4"
	)
	var corrupt_file: FileAccess = FileAccess.open(corrupt_path, FileAccess.WRITE)
	_check(corrupt_file != null, "Could not create corrupt MP4 fixture", failures)
	if corrupt_file != null:
		corrupt_file.store_buffer(PackedByteArray([0x47, 0x56, 0x54, 0x54]))
		corrupt_file.close()
	var corrupt_stream: VideoStream = NATIVE_VIDEO_BACKEND_SCRIPT.create_stream(corrupt_path)
	var corrupt_duration_seconds: float = _probe_duration(corrupt_stream)
	_check(corrupt_duration_seconds <= 0.0, "Corrupt MP4 reported a playable duration", failures)
	corrupt_stream = null
	DirAccess.remove_absolute(corrupt_path)
	await get_tree().process_frame
	await get_tree().process_frame

	var result: Dictionary = {
		"assertions": 8,
		"failed": failures.size(),
		"failures": failures,
		"duration_seconds": duration_seconds,
		"corrupt_duration_seconds": corrupt_duration_seconds,
		"extension_loaded": extension_loaded,
		"resource_type": resource_type,
	}
	print("P4_5_NATIVE_VIDEO_CLASS_PROBE_RESULT " + JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)


func _probe_duration(stream: VideoStream) -> float:
	if stream == null:
		return 0.0
	var player: VideoStreamPlayer = VideoStreamPlayer.new()
	player.stream = stream
	var duration_seconds: float = player.get_stream_length()
	player.stream = null
	player.free()
	return duration_seconds


func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

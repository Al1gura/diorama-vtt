@tool
extends McpTestSuite

const DEFAULT_GROUND_PATH: String = (
	"res://assets/textures/ground/uv_checker_4096_v2/uv_checker_4096_v2.png"
)
const RUNTIME_SUITE_PATH: String = "res://tests/p1_runtime_regressions.tscn"


func suite_name() -> String:
	return "p1_editor_contracts"


func test_default_ground_texture_is_an_imported_resource() -> void:
	assert_true(
		ResourceLoader.exists(DEFAULT_GROUND_PATH, "Texture2D"),
		"默认地面纹理没有进入 Godot 资源导入管线"
	)
	var texture: Texture2D = ResourceLoader.load(DEFAULT_GROUND_PATH, "Texture2D") as Texture2D
	assert_true(texture != null, "默认地面纹理无法由 ResourceLoader 加载")


func test_runtime_regression_scene_is_loadable() -> void:
	assert_true(
		ResourceLoader.exists(RUNTIME_SUITE_PATH, "PackedScene"),
		"P1 运行态回归场景不存在"
	)
	var suite_scene: PackedScene = ResourceLoader.load(
		RUNTIME_SUITE_PATH, "PackedScene"
	) as PackedScene
	assert_true(suite_scene != null, "P1 运行态回归场景无法加载")


func test_windows_export_embeds_the_pck() -> void:
	var preset: ConfigFile = ConfigFile.new()
	assert_eq(preset.load("res://export_presets.cfg"), OK, "无法读取 Windows 导出预设")
	assert_true(
		bool(preset.get_value("preset.0.options", "binary_format/embed_pck", false)),
		"Windows 导出没有启用单 EXE 内嵌 PCK"
	)

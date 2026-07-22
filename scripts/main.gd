extends Node3D
## Gvtt — 3D 俯视交互地图引擎
## P1: 编辑↔运行切换 + 资产管理 + 地面纹理替换
##
## 编辑↔运行 状态由全局 autoload ModeGate 统一管理。
## main.gd 订阅 ModeGate.mode_changed 信号，在信号回调里集中处理
## 面板开关、gizmo 隐藏等跨态权限。状态真值只有 ModeGate 一处，
## _on_mode_btn_pressed 也只调 ModeGate.switch_to，不再自己改状态。

@export var grid_size: int = 100
@export var grid_color: Color = Color(0.5, 0.5, 0.6, 0.3)
@export var ground_color: Color = Color(0.3, 0.28, 0.24, 1.0)
@export var ground_tile_size: float = 2.0      ## 当前地面纹理平铺尺寸（单位/格，默认 2 格）

## 自由视角轨道相机参数（球坐标模型）。
## yaw=偏航(左右转,弧度), pitch=俯仰(抬头低头,弧度,0=水平 PI/2=正上),
## distance=相机离焦点多远, focus=相机盯着看的那个点。
## 依据：社区主流做法(three.js OrbitControls 移植思路),见 LucaJunge/godot_orbit_controls。
## 不直接拷其代码(GPL 不兼容本仓 MIT),仅参考数学模型,用 Godot 4.7 标准 API 自实现。
const ORBIT_MIN_DIST: float = 3.0
const ORBIT_MAX_DIST: float = 80.0
const ORBIT_MIN_PITCH: float = 0.01      ## 防 pitch 到 0 翻转
const ORBIT_MAX_PITCH: float = 1.5707    ## 接近 PI/2,不顶到正上
const ORBIT_DEFAULT_DIST: float = 25.0
const ORBIT_DEFAULT_YAW: float = 0.6      ## 约 34°
const ORBIT_DEFAULT_PITCH: float = 1.0   ## 约 57°,接近原 55° 倾斜

## 默认场景配置(2026-07-10 修 bug2:"默认场景该有专门记录")。
## 开机起始场景 + 新建场景都走这套:纯空舞台(无物件)+ 默认地面纹理/平铺/场景大小。
## 将来想改默认场景(比如默认铺某纹理、默认带示例物件)只改这里一处。
## 2026-07-15 改:场景支持长方形(宽≠高),地面边长按宽×高、网格画到宽×高范围。
## 2026-07-15 改:默认贴图走"铺满拉伸"模式——一张图永远铺满整个地面,场景变长方形/改大小
## 贴图都跟着拉伸铺满(不按格数重复)。其他纹理仍按 ground_tile_size 格数重复铺。
const DEFAULT_GROUND_TEX_BASE: String = "uv_checker_4096_v2"   ## 默认贴图(UV 检测图新版,assets/textures/ground/uv_checker_4096_v2/)
const DEFAULT_GROUND_TEX_PATH: String = "res://assets/textures/ground/uv_checker_4096_v2/uv_checker_4096_v2.png"
const DEFAULT_GROUND_TILE: float = 100.0       ## 非默认纹理的默认平铺格数(默认贴图走铺满模式,此值不影响它)
const DEFAULT_SCENE_WIDTH: float = 100.0        ## 默认场景宽(米),地面 X 轴边长,网格画到该范围
const DEFAULT_SCENE_HEIGHT: float = 100.0       ## 默认场景高(米),地面 Z 轴边长,网格画到该范围

## 窗口大小/位置的记忆与默认值。
## 第一次打开(没记忆文件)用 DEFAULT_WINDOW_*；之后用上次关掉时存的大小/位置。
## 存进 user://window.cfg（ConfigFile），打包成 exe 后 user:// 照样在。
## 依据：gdd_1239 ConfigFile（set_value/get_value/save/load）、gdd_0202 第12-22行
## 关程序截 NOTIFICATION_WM_CLOSE_REQUEST、gdd_0786 Window.size/position。
const WINDOW_CFG_PATH: String = "user://window.cfg"
const DEFAULT_WINDOW_WIDTH: int = 1280
const DEFAULT_WINDOW_HEIGHT: int = 720
const MODULE_HOME_SCENE_PATH: String = "res://scenes/module_home.tscn"
const APP_MENU_SAVE_MODULE_ID: int = 1
const APP_MENU_SELECT_MODULE_ID: int = 3
const MEDIA_ACTION_RENAME_ID: int = 1
const MEDIA_ACTION_DELETE_ID: int = 2
const MEDIA_IMAGE_FILTER: String = "*.bmp,*.jpeg,*.jpg,*.png,*.svg,*.tga,*.webp"
const MEDIA_VIDEO_FILTER: String = "*.avi,*.m4v,*.mkv,*.mov,*.mp4,*.ogv,*.webm"
const PLAYTHROUGH_AUTOSAVE_DELAY_SECONDS: float = 1.0
const PLAYTHROUGH_AUTOSAVE_RETRY_SECONDS: float = 0.25

## 保存视角、实时轨道视角和地图视角状态只由 CameraViewController 持有。

## 鼠标手势唯一状态由 PointerInteractionController 持有，main.gd 只执行动作。
var _pointer_controller: Variant = load("res://scripts/pointer_interaction_controller.gd").new()
## 当前选中唯一真值由 SelectionController 持有，Gizmo 和属性面板只按它刷新。
var _selection_controller: Variant = load("res://scripts/selection_controller.gd").new()
## 素材预览、落点、实例化和组件挂载由 PlacementController 持有。
var _placement_controller: Variant = load("res://scripts/placement_controller.gd").new()
## 墙体破坏状态与运行时遮挡组件由 WallStateController 统一同步。
var _wall_state_controller: Variant = load("res://scripts/wall_state_controller.gd").new()
## 场景新建、切换、保存、脏标记和内容根清理由 SceneSessionController 持有。
var _scene_session_controller: Variant = load("res://scripts/scene_session_controller.gd").new()
## 带团会话保存、恢复和跨地点生命周期由普通注入节点编排，不做 Autoload。
var _playthrough_controller: Variant = load("res://scripts/playthrough_controller.gd").new()
## R5：相机视角状态由 CameraViewController 持有，main.gd 保留旧入口作协调。
var _camera_view_controller: Variant = load("res://scripts/camera_view_controller.gd").new()
## R5：顶栏、左栏、属性栏可见性由 MainUiController 持有。
var _main_ui_controller: Variant = load("res://scripts/main_ui_controller.gd").new()

var camera: Camera3D
var _grid_manager: GridManager  ## 网格管理器（替换旧 _draw_grid PlaneMesh shader）

## 模型类栏位配置：每个栏位一项 {label, category, builtin_dir}。
## label=左栏显示名；category=user://library/<category>/ 子目录名；
## builtin_dir 目前留空：除默认 UV 地面外，资产都按外部导入资产处理。
## 这些栏位共用同一套"合并自带+导入列表→建按钮→选中→左键放置"逻辑（_model_panelss 管）。
## 顺序对应左栏从上到下（地面纹理单独建，插在 terrain 和 wall 之间，不进此循环）。
const MODEL_PANELS: Array[Dictionary] = [
	{"label": "Token", "category": "token", "builtin_dir": ""},
	{"label": "地形", "category": "terrain", "builtin_dir": ""},
	{"label": "墙体", "category": "wall", "builtin_dir": ""},
	{"label": "装饰", "category": "decor", "builtin_dir": ""},
	{"label": "交互物体", "category": "interactable", "builtin_dir": ""},
	{"label": "光源", "category": "light", "builtin_dir": ""},
]

const WALL_SNAP_OFFSET: float = 0.05
const RAY_LENGTH: float = 1000.0
const COMBAT_AIM_TEST_DISTANCE: float = 20.0
const COMBAT_AIM_GUIDE_RADIUS: float = 96.0
const MODEL_DRAG_THRESHOLD_PIXELS: float = 6.0
const RUNTIME_TOKEN_DRAG_THRESHOLD_PIXELS: float = 6.0
const SELECTED_SCALE_STEP: float = 1.1
const SELECTED_SCALE_MIN: float = 0.05
const SELECTED_SCALE_MAX: float = 20.0

## 各模型栏位的运行时状态：category → {items, active_idx, container, import_btn}。
## items=Array[Dictionary] 每项 {source, path}（builtin=ResourceLoader.load(PackedScene)，
## imported=LibraryManager.load_model_runtime）；active_idx=当前选中项；container=按钮容器。
var _model_panelss: Dictionary = {}
var _drag_preview_root: Node3D = null
var _latest_left_press_position: Vector2 = Vector2.ZERO
var _runtime_token_drag_has_moved: bool = false
var _runtime_token_drag_aim_suppression_target: Node3D = null
var _runtime_token_edit_snapshots: Array[Dictionary] = []
var _movement_service: Node3D = null
var _movement_rule_provider: MovementRuleProvider = null
var _combat_line_preview: Node3D = null
var _los_service: Node = null
var _player_fog_overlay: CanvasLayer = null
var _gm_tool_overlay: CanvasLayer = null
var _model_scene_cache: Dictionary = {}
var _model_thread_requests: Dictionary = {}
var _model_thread_paths: Array[String] = []
var _editor_resources_activated: bool = false
var _ground_sets: Array[Dictionary] = []
var _active_ground_ts: Dictionary = {}          ## 当前选中的地面纹理 set
var _ui_layer: CanvasLayer
var _mode_btn: Button
var _test_btn: Button
var _app_menu_btn: MenuButton
var _current_module_label: Label
## 场景根(关卡的"舞台"外壳)。骨架层挂这里:相机/光照/地面/网格——
## 这些是 GM 看场景的眼睛和基础舞台,所有场景共用,**不存盘**。
## 顶栏 UI/gizmo/cast_view 留在 Main 上不进它。
## 依据:Node owner 机制(gdd_0512 第691行 pack 只存 owner=根的节点)。
var _scene_root: Node3D
## 内容层根(场景特有内容)。建筑物件挂这里——这是各场景不同的部分,
## **存盘只 pack 这一棵**:切场景 = 清它的孩子 + 读目标场景挂回。
## 在 _scene_root 下、owner=_scene_root,但存盘时单独 pack 它(不是 pack _scene_root)。
## 2026-07-10 方案乙:骨架/内容两层分离,相机/光/地面不随场景存读,
## 避免"清空重建整棵"导致相机/投屏/gizmo 引用全废的连带影响。
var _content_root: Node3D
var _ground: MeshInstance3D  ## Ground 节点引用(便于换纹理时访问,Ground reparent 后 $Ground 失效)
var _scene_section: VBoxContainer  ## 左栏"地图素材"节内容容器,刷新列表时往里填地图按钮
var _save_scene_btn: Button  ## 保存场景按钮:把当前编辑态存进当前选中场景
var _new_scene_btn: Button   ## 新建场景按钮:自动起名场景N+1、切个空场景编辑
var _playthrough_dialog: AcceptDialog = null
var _playthrough_list: VBoxContainer = null
var _add_table_button: Button = null
var _media_section: VBoxContainer = null
var _media_list: VBoxContainer = null
var _media_output_status_label: Label = null
var _media_return_map_button: Button = null
var _media_video_pause_button: Button = null
var _media_video_stop_button: Button = null
var _media_volume_slider: HSlider = null
var _media_volume_label: Label = null
var _media_edit_row: HBoxContainer = null
var _media_output_error_active: bool = false
var _gm_media_backdrop: ColorRect = null
var _gm_media_surface: TextureRect = null
var _media_file_dialog: FileDialog = null
var _media_import_type: ExternalContentRef.ContentType = ExternalContentRef.ContentType.IMAGE
var _media_rename_dialog: ConfirmationDialog = null
var _media_rename_edit: LineEdit = null
var _media_delete_dialog: ConfirmationDialog = null
var _pending_media_id: String = ""
var _act_library_panel: ActLibraryPanel = null
var _playthrough_autosave_timer: Timer = null
## P3.0 兼容入口：场景名真值只存在 SceneSessionController，这里不再存第二份值。
var _current_scene_name: String:
	get:
		return _scene_session_controller.get_current_scene_name()
	set(value):
		_scene_session_controller.set_current_scene_name(value)
var _pending_switch_to: String = ""  ## 弹窗期间记"要切去哪个场景",回调读它
var _pending_create_scene: bool = false  ## 弹窗期间记"确认后再新建场景",避免取消时提前改 ModuleGate 真值
var _switch_dialog: AcceptDialog = null  ## 切场景确认弹窗(三选一)
var _add_table_dialog: ConfirmationDialog = null
var _add_table_name_edit: LineEdit = null
## P3.0 兼容入口：脏标记真值只存在 SceneSessionController，这里不再存第二份值。
var _scene_dirty: bool:
	get:
		return _scene_session_controller.is_dirty()
	set(value):
		if value:
			_scene_session_controller.mark_dirty()
		else:
			_scene_session_controller.clear_dirty()
var _application_contract_log: Array[String] = []
var _mode_label: Label
var _sub_btn: Button                ## 地图 ↔ 自由视角 切换(两态都显示)
var _save_view_btn: Button          ## 保存视角(仅编辑态显示)
var _restore_view_btn: Button       ## 恢复视角(仅运行态显示)
var _cast_btn: Button               ## 投屏开关(两态都显示，旁路 ModeGate)
## 投屏窗口控制。旁路于 ModeGate，编辑/运行两态都可开投屏。
## 定位见 docs/design.md「三、3.1」与 docs/architecture.md「3.6」。
var _cast_view: CastView = null
var _player_output_controller: PlayerOutputController = null
var _scene_width_input: SpinBox     ## 场景宽输入框(左栏"场景"节下,X 轴边长)
var _scene_height_input: SpinBox   ## 场景高输入框(左栏"场景"节下,Z 轴边长)
var _left_panel: PanelContainer
var _panel_sections: Array[Dictionary] = []
var _prop_panel: PanelContainer          ## 属性面板(选中物件后弹,绑 EntityProperties)
var _prop_name_edit: LineEdit
var _prop_destructible_chk: CheckBox
var _prop_los_chk: CheckBox
var _prop_max_hp_row: HBoxContainer
var _prop_max_hp_spin: SpinBox
var _prop_move_row: HBoxContainer
var _prop_move_spin: SpinBox
var _prop_traversal_row: HBoxContainer
var _prop_traversal_option: OptionButton
var _prop_cover_chk: CheckBox
var _prop_vis_chk: CheckBox
var _prop_light_box: VBoxContainer
var _prop_light_on_chk: CheckBox
var _prop_light_color_picker: ColorPickerButton
var _prop_light_energy_spin: SpinBox
var _prop_light_range_spin: SpinBox
var _prop_light_shadow_chk: CheckBox
var _prop_title: Label
var _prop_editor_controls: Array[Control] = []
var _prop_runtime_box: VBoxContainer
var _prop_runtime_type_label: Label
var _prop_runtime_status_label: Label
var _prop_runtime_detail_label: Label
var _prop_runtime_light_toggle_btn: Button
var _prop_runtime_wall_toggle_btn: Button
var _updating_prop_panel: bool = false
var _tool_label: Label
var _tile_slider: HSlider
var _tile_spinbox: SpinBox
var _tile_control_area: VBoxContainer             ## 平铺控制区容器（不选纹理时隐藏）

## 素材库导入相关。导入按钮挂各栏位顶部，FileDialog 选中文件后复制进
## user://library/<栏位>/（LibraryManager 管）。_import_fd 记当前要导进哪个栏位。
## 依据：gdd_0596 FileDialog（ACCESS_FILESYSTEM + FILE_MODE_OPEN_FILE + add_filter）。
var _import_fd: FileDialog = null                 ## 运行时文件选择框（导入模型用，选文件）
var _import_dir_fd: FileDialog = null             ## 运行时文件选择框（导入地面纹理用，选文件夹）
var _import_target_category: String = ""          ## 当前导入操作的目标栏位标识
var _ground_import_btn: Button = null             ## 地面纹理栏"导入纹理文件夹"按钮
var _ground_list_container: VBoxContainer = null  ## 地面纹理栏纹理按钮列表容器

## LibraryManager 脚本引用。用 load() 拿脚本再调静态方法，不直接写全局类名
## LibraryManager——因为新建脚本的 class_name 在运行态全局类表注册有滞后
## (devlog 2026-07-09/07-10 记过此缓存坑)，load() 立即可用、不依赖编辑器缓存。
var _library_mgr: GDScript = load("res://scripts/library_manager.gd")
var _token_properties_script: GDScript = load("res://scripts/token_properties.gd")
var _combat_line_preview_script: GDScript = load("res://scripts/combat_line_preview.gd")
var _wall_properties_script: GDScript = load("res://scripts/wall_properties.gd")
var _combat_body_script: GDScript = load("res://scripts/combat_body.gd")
var _los_occluder_script: GDScript = load("res://scripts/los_occluder.gd")
var _los_service_script: GDScript = load("res://scripts/los_service.gd")
var _fog_overlay_script: GDScript = load("res://scripts/cast_fog_overlay.gd")
var _gm_tool_overlay_script: GDScript = load("res://scripts/gm_tool_overlay.gd")
var _light_properties_script: GDScript = load("res://scripts/light_properties.gd")
var _interactable_properties_script: GDScript = load("res://scripts/interactable_properties.gd")
var _traversal_properties_script: GDScript = load("res://scripts/traversal_properties.gd")
var _cpr_token_properties_script: GDScript = load("res://scripts/cpr_token_properties.gd")
var _movement_service_script: GDScript = load("res://scripts/movement_service.gd")
var _movement_rule_provider_script: GDScript = load("res://scripts/movement_rule_provider.gd")
var _cpr_movement_rule_provider_script: GDScript = load("res://scripts/cpr_movement_rule_provider.gd")


func _ready() -> void:
	_record_application_contract_step("startup:begin")
	get_tree().auto_accept_quit = false
	# 窗口最小尺寸兜底（锁字号模式下拖太小会挤乱 UI），先设再恢复窗口大小。
	# 依据：gdd_0786 Window.size/position/min_size、gdd_1239 ConfigFile。
	get_window().min_size = Vector2i(1024, 576)
	_apply_window_state()
	_record_application_contract_step("startup:window_state")
	# 场景根(骨架层):相机/光/地/网格这些"GM 眼睛+基础舞台"挂它下、owner=它。
	# 所有场景共用,不存盘。main.gd 脚本/UI/gizmo/cast_view 留在 Main、不进它。
	_scene_root = Node3D.new()
	_scene_root.name = "SceneRoot"
	add_child(_scene_root)
	# 内容层根(场景特有内容):建筑物件挂它下。存盘只 pack 这棵;切场景=清它+读目标挂回。
	# 在 _scene_root 下,owner=_scene_root,但存盘单独 pack _content_root(不 pack _scene_root)。
	# 挂 SceneProps 脚本:用它存地面纹理信息(纹理组名+平铺尺寸),随内容层 pack 存进场景
	# 文件(修 bug1:此前纹理在 Ground 骨架层不存盘,所有场景共用最后一套)。
	_content_root = Node3D.new()
	_content_root.name = "ContentRoot"
	_content_root.set_script(load("res://scripts/scene_props.gd"))
	_scene_root.add_child(_content_root)
	_content_root.set_owner(_scene_root)
	_record_application_contract_step("startup:content_roots")
	add_child(_placement_controller)
	add_child(_wall_state_controller)
	add_child(_scene_session_controller)
	add_child(_playthrough_controller)
	add_child(_camera_view_controller)
	add_child(_main_ui_controller)
	_record_application_contract_step("startup:controllers_added")
	_setup_camera()
	_setup_ground()
	_setup_cast_view()
	_setup_los_service()
	_init_grid_manager()
	_adopt_scene_content()
	_scan_all()
	_record_application_contract_step("startup:world_services")
	_build_ui()
	_record_application_contract_step("startup:ui_built")
	_configure_main_ui_controller()
	_configure_placement_controller()
	_configure_scene_session_controller()
	_configure_playthrough_controller()
	_record_application_contract_step("startup:dependencies_injected")
	# 实际应用由独立模组首页先打开模组，再进入本编辑器场景。
	# 测试可直接实例化编辑器；没有模组时保持锁定空桌面。
	_sync_scene_list()
	_current_scene_name = ""
	if ModuleGate.has_open_module():
		if _open_first_scene_or_create():
			_activate_editor_resources()
	else:
		_scene_session_controller.set_current_scene_name("")
		_scene_session_controller.apply_default_scene()
	# 共享单套 gizmo(全场唯一):左键点中物件 select 它、手柄移到它身上;
	# 点空白 clear。多选(Shift 加选)暂不做。gizmo 是 GM 工具不进 _scene_root。
	_gizmo = Gizmo3D.new()
	_gizmo.name = "SharedGizmo"
	_gizmo.use_local_space = true
	# gizmo 是 GM 编辑工具,放 GM-only 渲染层(第20层)——主窗 GM 相机可见,
	# 投屏相机 cull_mask 关第20层看不到手柄,玩家不被编辑工具干扰。
	_gizmo.layers = 1 << (GvttRenderLayers.RENDER_LAYER_GM_ONLY - 1)
	add_child(_gizmo)
	_gizmo.transform_end.connect(_on_gizmo_transform_end)
	_setup_gm_tool_overlay()
	_combat_line_preview = _combat_line_preview_script.new() as Node3D
	if _combat_line_preview != null:
		_combat_line_preview.name = "CombatLinePreview"
		add_child(_combat_line_preview)
	_selection_controller.selection_changed.connect(_on_selection_changed)
	# 订阅 ModuleGate 场景列表变化 → 左栏刷新。
	ModuleGate.scene_list_changed.connect(_sync_scene_list)
	ModuleGate.module_changed.connect(_on_module_changed)
	ModuleGate.external_contents_changed.connect(_sync_media_list)
	# 订阅全局模式闸。ModeGate _ready 时已广播一次初始态,
	# 但 main.gd 还没 connect,故这里手动对齐一次编辑态 UI。
	ModeGate.mode_changed.connect(_on_mode_changed)
	ModeGate.edit_sub_mode_changed.connect(_on_edit_sub_mode_changed)
	_record_application_contract_step("startup:signals_connected")
	_on_mode_changed(ModeGate.current())
	_on_edit_sub_mode_changed(ModeGate.current_sub_mode())
	_record_application_contract_step("startup:mode_applied")
	_sync_module_context_ui()
	_record_application_contract_step("startup:end")


func _process(_delta: float) -> void:
	_poll_model_cache_requests()


func _physics_process(_delta: float) -> void:
	_update_combat_line_preview()


func _configure_placement_controller() -> void:
	_placement_controller.configure(
		_scene_root,
		_content_root,
		camera,
		_left_panel,
		_model_panelss,
		_model_scene_cache,
		_model_thread_requests,
		_model_thread_paths,
		_token_properties_script,
		_wall_properties_script,
		_combat_body_script,
		_light_properties_script,
		_interactable_properties_script,
		_traversal_properties_script,
		_cpr_token_properties_script,
		_los_occluder_script,
		_get_current_ruleset_id
	)
	_drag_preview_root = _placement_controller.get_drag_preview_root()


func _configure_main_ui_controller() -> void:
	_main_ui_controller.configure(
		_left_panel,
		_prop_panel,
		_mode_btn,
		_test_btn,
		_mode_label,
		_sub_btn,
		_save_view_btn,
		_restore_view_btn,
		Callable(self, "_clear_all_model_selections")
	)


func _configure_scene_session_controller() -> void:
	_scene_session_controller.configure(
		_content_root,
		DEFAULT_GROUND_TEX_BASE,
		0.0,
		DEFAULT_SCENE_WIDTH,
		DEFAULT_SCENE_HEIGHT,
		_prepare_scene_session_switch,
		_apply_ground_texture_for_scene,
		_apply_scene_size,
		_sync_scene_size_inputs,
		_migrate_loaded_entity_type_properties,
		_module_add_scene,
		_module_save_current_scene,
		_module_set_current_location,
		_module_current_manifest
	)


func _configure_playthrough_controller() -> void:
	_playthrough_controller.configure(
		_content_root,
		_scene_session_controller,
		Callable(self, "_prepare_playthrough_save")
	)
	_playthrough_controller.operation_step_recorded.connect(_record_application_contract_step)
	_playthrough_autosave_timer = Timer.new()
	_playthrough_autosave_timer.name = "PlaythroughAutosaveTimer"
	_playthrough_autosave_timer.one_shot = true
	_playthrough_autosave_timer.wait_time = PLAYTHROUGH_AUTOSAVE_DELAY_SECONDS
	_playthrough_autosave_timer.timeout.connect(_on_playthrough_autosave_timeout)
	add_child(_playthrough_autosave_timer)


func _prepare_playthrough_save() -> void:
	_record_application_contract_step("session_save:prepare:begin")
	_cancel_pointer_gestures()
	if _movement_service != null and is_instance_valid(_movement_service):
		_movement_service.call("pause_active_movement")
	_unlock_combat_line_preview()
	_exit_combat_aim_mode()
	_record_application_contract_step("session_save:prepare:end")


func _module_add_scene() -> String:
	return ModuleGate.add_scene()


func _module_save_current_scene(scene_name: String, scene_root: Node3D) -> int:
	return ModuleGate.save_current_scene(scene_name, scene_root)


func _module_set_current_location(scene_name: String) -> void:
	ModuleGate.set_current_location(scene_name)


func _module_current_manifest() -> ModuleManifest:
	return ModuleGate.current_manifest()


func _get_current_ruleset_id() -> StringName:
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		return &""
	return manifest.ruleset_id


func _prepare_scene_session_switch() -> void:
	_record_application_contract_step("scene_switch:cleanup:begin")
	if _player_output_controller != null and is_instance_valid(_player_output_controller):
		_player_output_controller.prepare_scene_switch()
	_record_application_contract_step("scene_switch:cleanup:player_output")
	_cancel_pointer_gestures()
	_record_application_contract_step("scene_switch:cleanup:pointer")
	_destroy_movement_service()
	_record_application_contract_step("scene_switch:cleanup:movement")
	_restore_runtime_token_edit_snapshot()
	_record_application_contract_step("scene_switch:cleanup:runtime_tokens")
	_deselect()
	_record_application_contract_step("scene_switch:cleanup:selection")
	_record_application_contract_step("scene_switch:cleanup:end")


func _sync_scene_size_inputs(width: float, height: float) -> void:
	if _scene_width_input != null:
		_scene_width_input.set_value_no_signal(width)
	if _scene_height_input != null:
		_scene_height_input.set_value_no_signal(height)


func get_application_contract_log() -> Array[String]:
	return _application_contract_log.duplicate()


func clear_application_contract_log() -> void:
	_application_contract_log.clear()


func _record_application_contract_step(step: String) -> void:
	_application_contract_log.append(step)


## 开机恢复窗口大小/位置：读 user://window.cfg，有就用记忆值，没有用默认 1280×720。
## 这样也解决了"改 project.godot 后窗口没变成 1280×720"——因为这里主动设窗口大小，
## 不依赖 Godot 编辑器那次的旧配置。依据 gdd_1239 ConfigFile load/get_value、gdd_0786 Window。
func _apply_window_state() -> void:
	var win: Window = get_window()
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(WINDOW_CFG_PATH)
	if err == OK:
		# 有记忆文件：读大小（带默认值兜底，防文件在但某项缺了）
		var w: int = cfg.get_value("window", "width", DEFAULT_WINDOW_WIDTH)
		var h: int = cfg.get_value("window", "height", DEFAULT_WINDOW_HEIGHT)
		win.size = Vector2i(w, h)
		# Godot 内嵌运行窗口不能移动；正式 EXE 才恢复桌面位置。
		if not OS.has_feature("editor_runtime"):
			var x: int = cfg.get_value("window", "x", 0)
			var y: int = cfg.get_value("window", "y", 0)
			win.position = Vector2i(x, y)
	else:
		# 第一次开/文件丢了/读失败 → 默认尺寸，位置交给系统（居中等）
		win.size = Vector2i(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT)


## 关程序前存窗口大小/位置到 user://window.cfg。
## 依据 gdd_0202 第12-22行：Node 收到 NOTIFICATION_WM_CLOSE_REQUEST 时可存数据。
## 最大化状态下不存（记最大化前的尺寸才有意义）——取 size 会拿到最大化后的大尺寸，
## 故先排除 maximized/fullscreen/exclusive_fullscreen 三种铺满态。
func _save_window_state() -> void:
	var win: Window = get_window()
	# 铺满态（最大化/全屏）不记，避免存成"铺满屏"的尺寸，下次开一直铺满。
	if win.mode == Window.MODE_MAXIMIZED or win.mode == Window.MODE_FULLSCREEN \
			or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("window", "width", win.size.x)
	cfg.set_value("window", "height", win.size.y)
	cfg.set_value("window", "x", win.position.x)
	cfg.set_value("window", "y", win.position.y)
	cfg.save(WINDOW_CFG_PATH)


## 截获窗口关闭通知：在关程序那一刻存窗口大小/位置。
## 依据 gdd_0202 第12-22行 NOTIFICATION_WM_CLOSE_REQUEST（桌面关窗口标题栏 x 时触发）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _prepare_application_exit():
			get_tree().quit()
	elif (
			what == NOTIFICATION_WM_WINDOW_FOCUS_OUT
			or what == NOTIFICATION_WM_MOUSE_EXIT
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT
	):
		_cancel_pointer_gestures()


func _prepare_application_exit() -> bool:
	_record_application_contract_step("exit:begin")
	if _playthrough_controller.is_session_active():
		var save_result: Dictionary = _playthrough_controller.save_current_session()
		var save_error: int = int(save_result.get("error", FAILED))
		if save_error != OK:
			_show_playthrough_error(save_result, "退出前保存进度失败")
			_record_application_contract_step("exit:save_failed")
			return false
		_record_application_contract_step("exit:session_saved")
	_cancel_pointer_gestures()
	_record_application_contract_step("exit:pointer")
	_destroy_movement_service()
	_record_application_contract_step("exit:movement")
	_unlock_combat_line_preview()
	_exit_combat_aim_mode()
	_record_application_contract_step("exit:combat")
	if _player_output_controller != null and is_instance_valid(_player_output_controller):
		_player_output_controller.close_output()
	_record_application_contract_step("exit:cast")
	_save_window_state()
	_record_application_contract_step("exit:window_state")
	_record_application_contract_step("exit:end")
	return true


func _sync_scene_list() -> void:
	# 把 ModuleGate 当前地图素材列表填进左栏编辑服务区。
	if _scene_section == null:
		return
	_clear_scene_buttons(_scene_section)
	var module_open: bool = ModuleGate.has_open_module()
	if _new_scene_btn != null:
		_new_scene_btn.disabled = not module_open or ModeGate.is_run()
	if _save_scene_btn != null:
		_save_scene_btn.disabled = not module_open or _current_scene_name == ""
		_save_scene_btn.visible = ModeGate.is_edit()
		_save_scene_btn.text = "保存此地图"
		_save_scene_btn.tooltip_text = "把当前编辑态存进当前选中地图"
	if _scene_width_input != null:
		_scene_width_input.editable = module_open and _current_scene_name != "" and ModeGate.is_edit()
	if _scene_height_input != null:
		_scene_height_input.editable = module_open and _current_scene_name != "" and ModeGate.is_edit()
	if not module_open:
		_scene_section.add_child(_scene_status_label("未打开模组。"))
		return
	var names: Array[String] = ModuleGate.list_scene_names()
	if names.is_empty():
		_scene_section.add_child(_scene_status_label("当前模组还没有地图素材。"))
		return
	for nm: String in names:
		_scene_section.add_child(_btn_scene(nm))


func _has_editable_scene() -> bool:
	return ModuleGate.has_open_module() and _current_scene_name != ""


func _clear_scene_buttons(section: VBoxContainer) -> void:
	# 只按元数据清动态按钮，不依赖固定控件数量或索引。
	for child: Node in section.get_children():
		if child.get_meta("gvtt_scene_button", false):
			section.remove_child(child)
			child.queue_free()


func _scene_status_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	label.set_meta("gvtt_scene_button", true)
	return label


## 建一个左栏场景按钮。选中态视觉:当前 _current_scene_name == 它则样式区别。
func _btn_scene(nm: String) -> Button:
	var b: Button = Button.new()
	b.text = nm
	b.custom_minimum_size = Vector2(0, 36)
	b.flat = false
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.set_meta("gvtt_scene_button", true)
	b.pressed.connect(_on_scene_selected.bind(nm))
	# 视觉区分当前选中场景(此版:文字色)。
	if nm == _current_scene_name:
		b.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	return b


## 点左栏某场景:选中它作"当前编辑场景"。
## 当前场景有未存改动(_scene_dirty)→弹窗三选一(存/不存/取消);干净→直接切不弹。
## 真换舞台走 _switch_to_scene(清内容层物件+读目标场景挂回)。
func _on_scene_selected(nm: String) -> void:
	if not ModuleGate.has_open_module():
		_tool_label.text = "请先新建或导入模组"
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		return
	if nm == _current_scene_name:
		return  # 点当前场景,不切
	if ModeGate.is_run():
		_switch_runtime_location(nm)
		return
	if not _scene_session_controller.is_dirty():
		_switch_to_scene(nm)  # 干净,直接切,不弹窗(修 bug2:存过了不该再问)
		return
	_pending_create_scene = false
	_pending_switch_to = nm  # 记下要切去哪,弹窗回调读它
	_show_switch_dialog(nm)


## 新建场景:向 ModuleGate 加一个新场景(自动起名场景N+1)、切到它。
## 新场景没存过=空内容层(没物件)。当前有未存改动→弹窗;干净→直接切。
func _on_new_scene_pressed() -> void:
	if not ModuleGate.has_open_module():
		_tool_label.text = "请先新建或导入模组"
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		return
	if ModeGate.is_run():
		return
	if not _scene_session_controller.is_dirty():
		var nm: String = _scene_session_controller.create_scene()
		if nm == "":
			_tool_label.text = "新建地图失败：没有打开模组"
			_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			return
		_switch_to_scene(nm)  # 干净,直接切
		_save_current_scene_if_missing()
		return
	# 当前有改动,弹窗提醒存
	_pending_switch_to = ""
	_pending_create_scene = true
	_show_switch_dialog("新地图")


## 切场景弹窗(三选一)。nm = 要切去的目标场景名,弹窗文案里显示。
## 三个按钮:保存后切换(confirmed)/ 不保存直接切换(custom_action"discard")/ 取消(canceled)。
## API 依据:gdd_0513 AcceptDialog — ok_button_text(第109行)、add_cancel_button(第132行,
## 触发 canceled 信号)、add_button(第120行,触发 custom_action(action) 信号 第63行)、
## dialog_text(第100行)、popup_centered(显示,Window.popup_* 系列 第23行提示)。
func _show_switch_dialog(nm: String) -> void:
	if _switch_dialog != null and is_instance_valid(_switch_dialog):
		_switch_dialog.queue_free()  # 旧弹窗没清就新建,先释放
	_switch_dialog = AcceptDialog.new()
	_switch_dialog.title = "切换地图"
	_switch_dialog.dialog_text = "要切到「%s」吗?\n当前地图的物件可能还没保存,切走前要不要存一下?" % nm
	_switch_dialog.ok_button_text = "保存后切换"
	_switch_dialog.add_button("不保存直接切换", false, "discard")
	_switch_dialog.add_cancel_button("取消切换")
	_switch_dialog.confirmed.connect(_on_switch_dialog_save)
	_switch_dialog.canceled.connect(_on_switch_dialog_cancel)
	_switch_dialog.custom_action.connect(_on_switch_dialog_custom)
	add_child(_switch_dialog)
	_switch_dialog.popup_centered(Vector2i(420, 0))


## 弹窗[保存后切换]:先把当前场景存盘,再真换舞台到 _pending_switch_to。
func _on_switch_dialog_save() -> void:
	_hide_switch_dialog()
	# SceneProps 的纹理和尺寸也属于场景内容，空场景同样必须保存。
	if _current_scene_name != "" and _content_root != null:
		var err: int = _scene_session_controller.save_current_scene()
		if err != OK:
			_tool_label.text = "保存失败 code=" + str(err) + ",已取消切换"
			_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			return
	var target: String = _take_pending_switch_target()
	_switch_to_scene(target)
	_save_current_scene_if_missing()


## 弹窗[不保存直接切换]:直接真换舞台,_pending_switch_to，当前未存改动丢弃。
func _on_switch_dialog_custom(action: String) -> void:
	if action != "discard":
		return
	_hide_switch_dialog()
	var target: String = _take_pending_switch_target()
	_switch_to_scene(target)
	_save_current_scene_if_missing()


## 弹窗[取消]:不清空 _pending_switch_to 的话换个写法——这里直接清,不做任何切换。
func _on_switch_dialog_cancel() -> void:
	_hide_switch_dialog()
	_pending_switch_to = ""
	_pending_create_scene = false
	_tool_label.text = "已取消切换,留在「" + _current_scene_name + "」"
	_tool_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


func _hide_switch_dialog() -> void:
	if _switch_dialog != null and is_instance_valid(_switch_dialog):
		_switch_dialog.hide()


func _take_pending_switch_target() -> String:
	var target: String = _pending_switch_to
	if _pending_create_scene:
		target = _scene_session_controller.create_scene()
	_pending_switch_to = ""
	_pending_create_scene = false
	return target


func _save_current_module() -> int:
	if ModeGate.is_run():
		return _save_current_playthrough()
	if not ModuleGate.has_open_module():
		return ERR_UNCONFIGURED
	if _current_scene_name == "" or _content_root == null or not is_instance_valid(_content_root):
		return ERR_INVALID_DATA
	var scene_error: int = _scene_session_controller.save_current_scene()
	if scene_error != OK:
		_tool_label.text = "保存模组失败: 场景未保存 code=" + str(scene_error)
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return scene_error
	var manifest_error: int = ModuleGate.save_current_manifest()
	if manifest_error != OK:
		_tool_label.text = "保存模组失败: 清单未保存 code=" + str(manifest_error)
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return manifest_error
	_scene_session_controller.clear_dirty()
	_tool_label.text = "已保存模组: " + ModuleGate.current_module_name()
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	return OK


func _select_module() -> void:
	if not ModuleGate.has_open_module():
		return
	if _scene_session_controller.is_test_run_active():
		var test_result: Dictionary = _scene_session_controller.end_test_run()
		if int(test_result.get("error", FAILED)) != OK:
			_show_playthrough_error(test_result, "结束测试失败")
			return
		ModeGate.switch_to(ModeGate.AppMode.EDIT)
	if _playthrough_controller.is_session_active():
		var session_save_error: int = _save_current_playthrough()
		if session_save_error != OK:
			return
		ModeGate.switch_to(ModeGate.AppMode.EDIT)
	if _scene_session_controller.is_dirty():
		var save_error: int = _save_current_module()
		if save_error != OK:
			return
	ModuleGate.close_module()


func _on_app_menu_id_pressed(command_id: int) -> void:
	match command_id:
		APP_MENU_SAVE_MODULE_ID:
			_save_current_module()
		APP_MENU_SELECT_MODULE_ID:
			_select_module()


func _show_add_table_dialog() -> void:
	if not ModuleGate.has_open_module() or ModeGate.is_run():
		return
	_close_playthrough_dialog()
	if _add_table_dialog != null and is_instance_valid(_add_table_dialog):
		_add_table_dialog.queue_free()
	_add_table_dialog = ConfirmationDialog.new()
	_add_table_dialog.name = "AddTableDialog"
	_add_table_dialog.title = "新增一桌"
	_add_table_dialog.dialog_text = "给这桌起个名字，例如“周五团”或“朋友团”。"
	_add_table_dialog.ok_button_text = "新增"
	_add_table_dialog.cancel_button_text = "取消"
	_add_table_name_edit = LineEdit.new()
	_add_table_name_edit.name = "TableName"
	_add_table_name_edit.placeholder_text = "桌名"
	_add_table_name_edit.text = "第%d桌" % (_valid_playthrough_entries().size() + 1)
	_add_table_name_edit.select_all()
	_add_table_dialog.add_child(_add_table_name_edit)
	_add_table_dialog.register_text_enter(_add_table_name_edit)
	_add_table_dialog.confirmed.connect(_on_add_table_confirmed)
	_add_table_dialog.canceled.connect(_close_add_table_dialog)
	add_child(_add_table_dialog)
	_add_table_dialog.popup_centered(Vector2i(420, 0))
	_add_table_name_edit.grab_focus()


func _show_playthrough_dialog() -> void:
	if not ModuleGate.has_open_module() or ModeGate.is_run():
		return
	_close_playthrough_dialog()
	_playthrough_dialog = AcceptDialog.new()
	_playthrough_dialog.name = "StartPlaythroughDialog"
	_playthrough_dialog.title = "开始带团"
	_playthrough_dialog.dialog_text = "选择要继续的带团记录，或从模组底本新增一桌。"
	_playthrough_dialog.ok_button_text = "关闭"
	_playthrough_dialog.confirmed.connect(_close_playthrough_dialog)
	_playthrough_dialog.canceled.connect(_close_playthrough_dialog)
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "PlaythroughDialogBody"
	body.custom_minimum_size = Vector2(440, 220)
	body.add_theme_constant_override("separation", 8)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "PlaythroughScroll"
	scroll.custom_minimum_size = Vector2(440, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_playthrough_list = VBoxContainer.new()
	_playthrough_list.name = "PlaythroughList"
	_playthrough_list.custom_minimum_size = Vector2(420, 0)
	_playthrough_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_playthrough_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_playthrough_list)
	body.add_child(scroll)
	_add_table_button = Button.new()
	_add_table_button.name = "AddTableButton"
	_add_table_button.text = "＋ 新增一桌"
	_add_table_button.custom_minimum_size = Vector2(0, 36)
	_add_table_button.tooltip_text = "从当前模组底本新增一份独立带团记录"
	_add_table_button.pressed.connect(_show_add_table_dialog)
	body.add_child(_add_table_button)
	_playthrough_dialog.add_child(body)
	add_child(_playthrough_dialog)
	_sync_playthrough_list()
	_playthrough_dialog.popup_centered(Vector2i(500, 340))


func _close_playthrough_dialog() -> void:
	if _playthrough_dialog != null and is_instance_valid(_playthrough_dialog):
		_playthrough_dialog.hide()
		_playthrough_dialog.queue_free()
	_playthrough_dialog = null
	_playthrough_list = null
	_add_table_button = null


func _on_add_table_confirmed() -> void:
	var table_name: String = ""
	if _add_table_name_edit != null and is_instance_valid(_add_table_name_edit):
		table_name = _add_table_name_edit.text.strip_edges()
	if table_name == "":
		table_name = "第%d桌" % (_valid_playthrough_entries().size() + 1)
	_close_add_table_dialog()
	_start_new_playthrough(table_name)


func _close_add_table_dialog() -> void:
	if _add_table_dialog != null and is_instance_valid(_add_table_dialog):
		_add_table_dialog.queue_free()
	_add_table_dialog = null
	_add_table_name_edit = null


func _start_new_playthrough(session_name: String = "默认带团") -> void:
	if not ModuleGate.has_open_module() or ModeGate.is_run():
		return
	if _scene_session_controller.is_dirty():
		var canonical_save_error: int = _save_current_module()
		if canonical_save_error != OK:
			return
	var normalized_name: String = session_name.strip_edges()
	if normalized_name == "":
		normalized_name = "默认带团"
	var start_result: Dictionary = _playthrough_controller.start_new_session(normalized_name)
	if int(start_result.get("error", FAILED)) != OK:
		_show_playthrough_error(start_result, "开始带团失败")
		return
	ModeGate.switch_to(ModeGate.AppMode.RUN)
	_sync_scene_list()
	_sync_module_context_ui()
	_tool_label.text = "已新增并进入：" + normalized_name
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _continue_playthrough(session_id: String) -> void:
	var open_result: Dictionary = _playthrough_controller.open_session(session_id)
	if int(open_result.get("error", FAILED)) != OK:
		_show_playthrough_error(open_result, "继续带团失败")
		return
	ModeGate.switch_to(ModeGate.AppMode.RUN)
	_sync_scene_list()
	_sync_module_context_ui()
	var session: Playthrough = ModuleGate.current_session()
	_tool_label.text = "已继续带团：" + (session.session_name if session != null else session_id.left(8))
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _continue_playthrough_from_dialog(session_id: String) -> void:
	_close_playthrough_dialog()
	_continue_playthrough(session_id)


func _save_current_playthrough(show_success: bool = true) -> int:
	var save_result: Dictionary = _playthrough_controller.save_current_session()
	var save_error: int = int(save_result.get("error", FAILED))
	if save_error != OK:
		_show_playthrough_error(save_result, "进度保存失败")
		return save_error
	if show_success:
		_tool_label.text = "进度已保存"
		_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	return OK


func _schedule_playthrough_autosave() -> void:
	if (
			_playthrough_autosave_timer == null
			or not is_instance_valid(_playthrough_autosave_timer)
			or not ModeGate.is_run()
			or not _playthrough_controller.is_session_active()
	):
		return
	_playthrough_autosave_timer.start(PLAYTHROUGH_AUTOSAVE_DELAY_SECONDS)


func _on_playthrough_autosave_timeout() -> void:
	if (
			not ModeGate.is_run()
			or not _playthrough_controller.is_session_active()
			or not _playthrough_controller.is_runtime_dirty()
	):
		return
	if (
			_movement_service != null
			and is_instance_valid(_movement_service)
			and bool(_movement_service.call("is_movement_active"))
	):
		_playthrough_autosave_timer.start(PLAYTHROUGH_AUTOSAVE_RETRY_SECONDS)
		return
	var save_error: int = _save_current_playthrough(false)
	if save_error == OK:
		_tool_label.text = "进度已自动保存"
		_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _switch_runtime_location(location_name: String) -> void:
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		return
	var location: LocationRef = manifest.find_location(location_name)
	if location == null:
		return
	_record_application_contract_step("runtime_location_switch:begin")
	var switch_result: Dictionary = _playthrough_controller.switch_location(
		location.location_id
	)
	if int(switch_result.get("error", FAILED)) != OK:
		_show_playthrough_error(switch_result, "切换带团地点失败")
		_record_application_contract_step("runtime_location_switch:failed")
		return
	_apply_wall_state_for_mode(ModeGate.AppMode.RUN)
	_apply_token_drag_for_mode(ModeGate.AppMode.RUN)
	_apply_pick_proxy_markers_for_mode(ModeGate.AppMode.RUN)
	_sync_scene_list()
	_tool_label.text = "已切到带团地点「" + location_name + "」"
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	_record_application_contract_step("runtime_location_switch:end")


func _show_playthrough_error(result: Dictionary, fallback: String) -> void:
	var error: int = int(result.get("error", FAILED))
	var message: String = String(result.get("message", fallback))
	if message == "":
		message = fallback
	_tool_label.text = message + " code=" + str(error)
	_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _on_module_changed(module_name: String) -> void:
	_sync_module_context_ui()
	if module_name == "":
		_record_application_contract_step("module_close:begin")
		_current_scene_name = ""
		_record_application_contract_step("module_close:scene_name")
		_scene_session_controller.set_current_scene_name("")
		_scene_session_controller.apply_default_scene()
		_record_application_contract_step("module_close:default_scene")
		_sync_scene_list()
		_record_application_contract_step("module_close:scene_list")
		if get_tree().current_scene == self:
			call_deferred("_return_to_module_home")
		_record_application_contract_step("module_close:home_scene")
		_record_application_contract_step("module_close:end")
		return
	if _open_first_scene_or_create():
		_activate_editor_resources()


func _open_first_scene_or_create() -> bool:
	if not ModuleGate.has_open_module():
		return false
	_current_scene_name = ModuleGate.current_location()
	var scene_names: Array[String] = ModuleGate.list_scene_names()
	if _current_scene_name == "" and not scene_names.is_empty():
		_current_scene_name = scene_names[0]
		ModuleGate.set_current_location(_current_scene_name)
	if _current_scene_name == "":
		_current_scene_name = _scene_session_controller.create_scene()
		if _current_scene_name == "":
			_tool_label.text = "无法为模组创建第一个场景"
			_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			return false
	_scene_session_controller.set_current_scene_name(_current_scene_name)
	_switch_to_scene(_current_scene_name)
	if not _save_current_scene_if_missing():
		return false
	_sync_scene_list()
	return _has_editable_scene()


func _return_to_module_home() -> void:
	var err: int = get_tree().change_scene_to_file(MODULE_HOME_SCENE_PATH)
	if err != OK:
		_tool_label.text = "返回模组首页失败 code=" + str(err)
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _save_current_scene_if_missing() -> bool:
	if not _has_editable_scene():
		return false
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		return false
	for location: LocationRef in manifest.locations:
		if location.display_name != _current_scene_name:
			continue
		if FileAccess.file_exists(location.canonical_path):
			return true
		var save_err: int = _scene_session_controller.save_current_scene()
		if save_err == OK:
			return true
		_tool_label.text = "场景保存失败 code=" + str(save_err)
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return false
	return false


## 场景宽输入框值改变回调:只改宽(X 轴),高保持。重设地面/网格/UV,写进 SceneProps 存盘。
## 写进 SceneProps 随场景存盘,切场景读回时自动恢复(2026-07-14 用户需求:场景可调大小)。
## 2026-07-15 改:场景支持长方形,宽高各一个输入框各自回调,只动自己那一维。
func _on_scene_width_changed(new_w: float) -> void:
	if not _has_editable_scene():
		return
	if new_w < 5.0:
		new_w = 5.0
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		_content_root.scene_width = new_w
	var h: float = _current_scene_height()
	_apply_scene_size(new_w, h)
	_mark_scene_dirty()
	_tool_label.text = "地图大小设为: %.0f×%.0f 米" % [new_w, h]
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 场景高输入框值改变回调:只改高(Z 轴),宽保持。同上。
func _on_scene_height_changed(new_h: float) -> void:
	if not _has_editable_scene():
		return
	if new_h < 5.0:
		new_h = 5.0
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		_content_root.scene_height = new_h
	var w: float = _current_scene_width()
	_apply_scene_size(w, new_h)
	_mark_scene_dirty()
	_tool_label.text = "地图大小设为: %.0f×%.0f 米" % [w, new_h]
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 取当前场景的真宽/真高。优先读 _content_root 的 SceneProps 存值(切场景后权威),
## 没有就用 DEFAULT_SCENE_*。给宽高回调各自算"另一维"用,避免回调里读输入框
## 还没刷新的旧值导致两边互相覆盖。
func _current_scene_width() -> float:
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		return _content_root.scene_width
	return DEFAULT_SCENE_WIDTH


func _current_scene_height() -> float:
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		return _content_root.scene_height
	return DEFAULT_SCENE_HEIGHT


## 应用场景大小到地面/网格/纹理:地面 PlaneMesh、网格范围、UV 平铺(保持纹理重复格数)。
## 从 _on_scene_width/height_changed / _apply_default_scene / _switch_to_scene 调,不重复。
## 2026-07-15 改:接收宽×高两参数,地面 PlaneMesh 用 Vector2(w,h),网格 set_grid_size(w,h),
## UV 平铺按宽高各自重复(平铺格数 ground_tile_size 不变,只是每轴米数不同)。
func _apply_scene_size(width: float, height: float) -> void:
	if _los_service != null and is_instance_valid(_los_service):
		_los_service.call("set_map_size", Vector2(width, height))
	if _ground == null or not is_instance_valid(_ground) or _grid_manager == null:
		return
	var g: MeshInstance3D = _ground
	g.mesh = PlaneMesh.new()
	g.mesh.size = Vector2(width, height)
	_grid_manager.set_grid_size(width, height)
	_refresh_grid()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	_apply_texture_set(_active_ground_ts, mat)
	# UV 平铺:默认贴图铺满拉伸(跟着场景宽高变形),其他纹理按 ground_tile_size 重复。
	mat.uv1_scale = _ground_uv_scale(_active_ground_ts.get("_base", ""), width, height, ground_tile_size)
	g.set_surface_override_material(0, mat)
	# grid_size 是 @export 备用整数(部分逻辑还读它),取宽高较大值近似保持兼容。
	grid_size = int(maxf(width, height))


## 把当前场景设成默认空场景(纯空舞台):清内容层所有物件 + 设默认地面纹理/平铺/场景大小
## (DEFAULT_GROUND_TEX_BASE/TILE + DEFAULT_SCENE_WIDTH/HEIGHT) + 写进 _content_root 的 SceneProps。
## 开机起始场景、新建场景、切到没存过的场景都走这里——"默认场景有专门记录"。
## 将来改默认场景长相只改 DEFAULT_* 常量这一处(2026-07-10 修 bug2)。
## 2026-07-15 改:默认场景宽×高两值(支持长方形)。
func _apply_default_scene() -> void:
	_scene_session_controller.apply_default_scene()


## 真换舞台:把内容层(_content_root)清空 → 读目标场景文件挂回(没存过就空着)。
## 骨架层(相机/光/地面)不动——所有场景共用(方案乙),所以相机/投屏/gizmo 引用不重连。
## 读回的树整棵是 _content_root 那一层(pack 存的就是它),直接把它的孩子搬进当前 _content_root。
func _switch_to_scene(target_name: String) -> void:
	if not ModuleGate.has_open_module() or target_name == "":
		return
	_record_application_contract_step("scene_switch:begin")
	var result: Dictionary = _scene_session_controller.switch_to_scene(target_name)
	_record_application_contract_step("scene_switch:session")
	if not bool(result.get("ok", false)):
		_record_application_contract_step("scene_switch:failed")
		return
	_sync_scene_list()
	_record_application_contract_step("scene_switch:ui")
	var migrated_count: int = int(result.get("migrated_count", 0))
	if migrated_count > 0:
		_tool_label.text = "已恢复 %d 个旧对象，请保存场景" % migrated_count
		_tool_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.2))
	else:
		_tool_label.text = "已切到地图「" + _current_scene_name + "」"
		_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	_record_application_contract_step("scene_switch:end")


## 递归把 node 子树所有节点 owner 设成 owner_node(修 pack 的 owner 陷阱)。
## 搬读回树的孩子进当前 _content_root 后,owner 要重指当前 _content_root,否则下次存盘漏。
func _ensure_owner_recursive(node: Node, owner_node: Node) -> void:
	if node.has_meta("gvtt_runtime_only"):
		if node.owner != null:
			node.set_owner(null)
		return
	node.set_owner(owner_node)
	for c: Node in node.get_children():
		_ensure_owner_recursive(c, owner_node)


func _clear_owner_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		_clear_owner_recursive(child)
	if node.owner != null:
		node.set_owner(null)



## 保存当前编辑态:_content_root 这棵子树(建筑物件)存进当前选中场景的文件。
## 方案乙:只存内容层(物件),骨架层(相机/光/地面)不随场景存。
## 走 ModuleGate.save_current_scene → module_io.save_scene_tree(内含 owner 陷阱处理)。
func _on_save_scene_pressed() -> void:
	if not ModuleGate.has_open_module():
		_tool_label.text = "请先新建或导入模组"
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		return
	if _current_scene_name == "":
		_tool_label.text = "请先在左栏点选一个地图素材"
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		return
	if _content_root == null or not is_instance_valid(_content_root):
		return
	if ModeGate.is_run():
		_save_current_playthrough()
		return
	var err: int = _scene_session_controller.save_current_scene()
	if err == OK:
		_scene_session_controller.clear_dirty()
		_tool_label.text = "已保存地图:" + _current_scene_name
		_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	else:
		_tool_label.text = "保存失败 code=" + str(err)
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


## 把"场景内容"节点(相机/光照/地面/网格)挪到 _scene_root 下、owner 设成 _scene_root。
## 这样 pack(_scene_root) 存场景时它们是内容会被存;gizmo/UI/cast_view 不进它→不存。
## 依据:Node.reparent(gdd_0512 第142/1668行) + owner=pack根 才进存盘(gdd_0512 第691行)。
func _adopt_scene_content() -> void:
	# main.tscn 里写死的孩子(相机/方向光/WorldEnvironment/CameraPivot/Ground)现 owner=Main,
	# reparent 到 SceneRoot;GridOverlay 是 _draw_grid 动态建的,_draw_grid 里已 add_child(self),
	# 这里统一挪。rep前不能加 if 判断不存在的节点($ 访问会被 null 跳过)。
	for child: Node in get_children():
		if child == _scene_root:
			continue
		if child is Camera3D or child is DirectionalLight3D or child is WorldEnvironment \
				or child is Node3D and child.name == "CameraPivot":
			_reparent_own(child, _scene_root)
	# Ground 按名字认（另一地面 MeshInstance3D，同样不进 reparent）。
	# GridOverlay 现在是 GridManager 的子节点，不再直接从 main 下认。
	for child: Node in get_children():
		if child == _scene_root:
			continue
		if child.name == "Ground":
			_reparent_own(child, _scene_root)


## reparent 一个节点到 new_parent 并把 owner 设成 new_parent。
func _reparent_own(node: Node, new_parent: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() == new_parent:
		# 已在目标父下:只改 owner 即可(reparent 同父会触发不必要信号)。
		node.set_owner(new_parent)
		return
	node.reparent(new_parent, true)  # keep_global_transform=true 保留世界位姿(文档第142行)
	node.set_owner(new_parent)


func _scan_all() -> void:
	# 内置默认图用确定资源路径。导出后原始 PNG 会转成 CTEX，DirAccess
	# 只能枚举到 .import；ResourceLoader.exists 会按引擎重映射找到 CTEX。
	_ground_sets.clear()
	if ResourceLoader.exists(DEFAULT_GROUND_TEX_PATH, "Texture2D"):
		_ground_sets.append({
			"_base": DEFAULT_GROUND_TEX_BASE,
			"albedo": DEFAULT_GROUND_TEX_PATH,
		})
	else:
		push_error("内置默认地面纹理不存在: %s" % DEFAULT_GROUND_TEX_PATH)
	# 模型类栏位的 items 不在这里建——_build_ui 时 _build_model_section 调
	# _rebuild_model_items 各自扫自带+导入。开机 _scan_all 在 _build_ui 前跑只管纹理。



## 重建某模型栏位的统一 items 列表：自带模型(builtin_dir) + 导入模型(user://library/<category>/)。
## 自带标记 source="builtin"，放置走 ResourceLoader.load(PackedScene)；
## 导入标记 source="imported"，放置走 LibraryManager 的持久 PackedScene 缓存。
## 依据：gdd_0372 res:// 打包后只读、user:// 永远可写；gdd_0187 运行时加载 3D 模型。
## 返回 items 数组（不直接存进 _model_panelss，调用方自己存）。
func _rebuild_model_items(category: String, builtin_dir: String) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if category == "light":
		items.append({"source": "builtin_light", "path": "点光源"})
	# 自带模型（开发时随 exe 打包）
	if builtin_dir != "":
		var dd: DirAccess = DirAccess.open(builtin_dir)
		if dd != null:
			dd.list_dir_begin()
			var fn: String = dd.get_next()
			while fn != "":
				if not dd.current_is_dir():
					var low: String = fn.to_lower()
					if low.ends_with(".glb"):
						items.append({"source": "builtin", "path": builtin_dir + "/" + fn})
				fn = dd.get_next()
			dd.list_dir_end()
	# 导入模型（GM 用导入按钮加进来的，存 user://library/<category>/）
	var imported: Array[String] = _library_mgr.scan_category(category, "model")
	for p: String in imported:
		items.append({"source": "imported", "path": p})
	return items


## 刷新某模型栏位的按钮列表。清掉该栏位容器旧孩子，按 items 重建。
## 导入新素材后调它，左栏立刻出现新按钮。
func _rebuild_model_buttons(category: String) -> void:
	if not _model_panelss.has(category):
		return
	var panel: Dictionary = _model_panelss[category]
	var container: VBoxContainer = panel["container"]
	var items: Array[Dictionary] = panel["items"]
	if _editor_resources_activated:
		_warm_model_cache_for_items(items)
	for c: Node in container.get_children():
		container.remove_child(c)
		c.queue_free()
	for i: int in items.size():
		container.add_child(_btn_model(category, i))


func _activate_editor_resources() -> void:
	if _editor_resources_activated:
		return
	_editor_resources_activated = true
	for category_value: Variant in _model_panelss.keys():
		var category: String = str(category_value)
		var panel: Dictionary = _model_panelss[category]
		var items: Array[Dictionary] = panel["items"]
		_warm_model_cache_for_items(items)


func _warm_model_cache_for_items(items: Array[Dictionary]) -> void:
	for item: Dictionary in items:
		var path: String = item["path"]
		var source: String = item["source"]
		_warm_model_cache_for_path(path, source)


func _warm_model_cache_for_path(path: String, source: String) -> void:
	if path == "":
		return
	if source == "builtin_light":
		return
	var load_path: String = path
	if source == "imported":
		# 只预热已经完成导入转换的 .scn；旧 GLB 不在启动阶段同步迁移。
		load_path = LibraryManager.get_current_model_cache_path(path)
		if load_path == "":
			return
	if _model_scene_cache.has(load_path) or _model_thread_requests.has(load_path):
		return
	if ResourceLoader.has_cached(load_path):
		var cached: Resource = ResourceLoader.load(
			load_path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE
		)
		if cached is PackedScene:
			_model_scene_cache[load_path] = cached
			return
	var err: int = ResourceLoader.load_threaded_request(
		load_path, "PackedScene", false, ResourceLoader.CACHE_MODE_REUSE
	)
	if err == OK:
		_model_thread_requests[load_path] = true
		_model_thread_paths.append(load_path)
		return
	var res: Resource = ResourceLoader.load(
		load_path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE
	)
	if res is PackedScene:
		_model_scene_cache[load_path] = res


func _poll_model_cache_requests() -> void:
	if _model_thread_paths.is_empty():
		return
	var finished: Array[String] = []
	for path: String in _model_thread_paths:
		var status: int = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var res: Resource = ResourceLoader.load_threaded_get(path)
			if res is PackedScene:
				_model_scene_cache[path] = res
			finished.append(path)
		elif (
				status == ResourceLoader.THREAD_LOAD_FAILED
				or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		):
			finished.append(path)
	for path: String in finished:
		_model_thread_requests.erase(path)
		_model_thread_paths.erase(path)


func _drop_model_cache(path: String) -> void:
	if path == "":
		return
	var cache_paths: Array[String] = [path]
	var imported_cache_path: String = LibraryManager.get_current_model_cache_path(path)
	if imported_cache_path != "":
		cache_paths.append(imported_cache_path)
	for cache_path: String in cache_paths:
		if _model_thread_requests.has(cache_path):
			var status: int = ResourceLoader.load_threaded_get_status(cache_path)
			if (
					status == ResourceLoader.THREAD_LOAD_IN_PROGRESS
					or status == ResourceLoader.THREAD_LOAD_LOADED
			):
				# ResourceLoader 没有取消请求接口；删除文件前收束请求，避免 Windows 文件占用。
				ResourceLoader.load_threaded_get(cache_path)
		_model_scene_cache.erase(cache_path)
		_model_thread_requests.erase(cache_path)
		_model_thread_paths.erase(cache_path)


## 建一个模型栏位按钮。显示文件名（去扩展名），点击选中该项作待放置工具。
func _btn_model(category: String, index: int) -> Button:
	var btn: Button = Button.new()
	var item: Dictionary = _model_panelss[category]["items"][index]
	btn.text = item["path"].get_file().get_basename()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.keep_pressed_outside = true
	if item["source"] == "builtin_light":
		btn.text = "点光源"
	# 导入的项文字前加个标记，让 GM 一眼区分自带/导入
	if item["source"] == "imported":
		btn.text = "📥 " + btn.text
	btn.button_down.connect(_on_model_pointer_pressed.bind(btn, category, index))
	# 给按钮存元数据：右键时靠 gui_get_hovered_control 找到按钮再读它，
	# 知道该删哪个素材。不用 gui_input 信号——实测 Button 的 gui_input 收不到
	# MouseButton 事件（只收 MouseMotion），改在 _unhandled_input 里统一处理右键。
	btn.set_meta("category", category)
	btn.set_meta("index", index)
	btn.set_meta("kind", "model")
	return btn


## 真删除一个导入模型：删 user://library/<category>/<文件> → 重建该栏列表。
func _delete_model_item(category: String, index: int) -> void:
	var item: Dictionary = _model_panelss[category]["items"][index]
	var path: String = item["path"]
	var file_name: String = item["path"].get_file()
	_drop_model_cache(path)
	if not _library_mgr.delete_model(category, file_name):
		_tool_label.text = "删除失败：" + file_name
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return
	var panel: Dictionary = _model_panelss[category]
	panel["items"] = _rebuild_model_items(category, panel["builtin_dir"])
	panel["active_idx"] = -1
	_rebuild_model_buttons(category)
	_tool_label.text = "已删除" + panel["label"] + "：" + file_name
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 模型栏位项点击：选中/取消选中作待放置工具。所有模型栏位共用。
func _on_model_clicked(category: String, index: int) -> void:
	if not _has_editable_scene():
		return
	var panel: Dictionary = _model_panelss[category]
	var items: Array[Dictionary] = panel["items"]
	var label: String = panel["label"]
	var was_active: bool = int(panel["active_idx"]) == index
	# 先清所有栏位的选中（单选语义：同时只能有一个栏位的工具被选中）
	_clear_all_model_selections()
	if was_active:
		_tool_label.text = "未选中工具"
		_tool_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		panel["active_idx"] = index
		_tool_label.text = label + "：" + items[index]["path"].get_file().get_basename()
		_tool_label.add_theme_color_override("font_color", Color(0.3, 0.5, 0.9))


func _on_model_pointer_pressed(button: Button, category: String, index: int) -> void:
	if not ModeGate.is_edit() or not _has_editable_scene():
		return
	if not _model_panelss.has(category):
		return
	var panel: Dictionary = _model_panelss[category]
	var items: Array[Dictionary] = panel["items"]
	if index < 0 or index >= items.size():
		return
	if _pointer_controller.is_model_candidate():
		_pointer_controller.reset()
	_pointer_controller.begin_model_candidate(
		button, category, index, _latest_left_press_position)


func _model_pointer_exceeded_drag_threshold(mouse_pos: Vector2) -> bool:
	return _pointer_controller.is_model_drag_threshold_met(mouse_pos)


func _begin_model_drag(mouse_pos: Vector2) -> bool:
	if not _has_editable_scene():
		return false
	if not _pointer_controller.is_model_candidate():
		return false
	var category: String = _pointer_controller.get_model_category()
	var index: int = _pointer_controller.get_model_index()
	if not _pointer_controller.begin_model_drag(mouse_pos):
		return false
	if not _model_panelss.has(category):
		_pointer_controller.reset()
		return false
	var panel: Dictionary = _model_panelss[category]
	var items: Array[Dictionary] = panel["items"]
	if index < 0 or index >= items.size():
		_pointer_controller.reset()
		return false
	_create_drag_preview_model(category, index)
	_update_drag_preview(mouse_pos)
	_tool_label.text = "拖到地图松开：" + items[index]["path"].get_file().get_basename()
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.5, 0.9))
	return true


func _finish_model_pointer_candidate(mouse_pos: Vector2) -> void:
	var button: Button = _pointer_controller.get_model_button()
	var category: String = _pointer_controller.get_model_category()
	var index: int = _pointer_controller.get_model_index()
	var released_on_button: bool = (
		button != null
		and is_instance_valid(button)
		and button.get_global_rect().has_point(mouse_pos)
	)
	_clear_model_pointer_candidate()
	if not released_on_button or not ModeGate.is_edit():
		return
	if not _model_panelss.has(category):
		return
	var panel: Dictionary = _model_panelss[category]
	if index < 0 or index >= panel["items"].size():
		return
	_on_model_clicked(category, index)


func _clear_model_pointer_candidate() -> void:
	if _pointer_controller.is_model_candidate():
		_pointer_controller.reset()


func _cancel_model_drag() -> void:
	if _pointer_controller.is_model_drag():
		_pointer_controller.reset()
	_clear_drag_preview()


func _cancel_model_gesture() -> void:
	_clear_model_pointer_candidate()
	_cancel_model_drag()


func _finish_model_drag(mouse_pos: Vector2) -> void:
	if not _has_editable_scene():
		_cancel_model_drag()
		return
	if not _pointer_controller.is_model_drag():
		return
	var category: String = _pointer_controller.get_model_category()
	var index: int = _pointer_controller.get_model_index()
	_cancel_model_drag()
	if _main_ui_controller.is_over_left_panel(mouse_pos):
		return
	if _main_ui_controller.is_over_property_panel(mouse_pos):
		return
	if not _model_panelss.has(category):
		return
	var panel: Dictionary = _model_panelss[category]
	if index < 0 or index >= panel["items"].size():
		return
	_place_model(category, index, true, mouse_pos)
	_clear_all_model_selections()


func _create_drag_preview_model(category: String, index: int) -> void:
	_placement_controller.create_drag_preview(category, index)
	_drag_preview_root = _placement_controller.get_drag_preview_root()


func _clear_drag_preview() -> void:
	_placement_controller.clear_drag_preview()
	_drag_preview_root = null


func _update_drag_preview(mouse_pos: Vector2) -> void:
	if not _pointer_controller.is_model_drag():
		return
	_pointer_controller.update_model_position(mouse_pos)
	_placement_controller.update_drag_preview(_pointer_controller.get_model_category(), mouse_pos)
	_drag_preview_root = _placement_controller.get_drag_preview_root()


func _apply_drag_preview_visuals(node: Node) -> void:
	if node == null:
		return
	_placement_controller.call("_apply_drag_preview_visuals", node)


## 清所有模型栏位的选中状态（单选语义：跨栏位同时只能选中一个放置工具）。
func _clear_all_model_selections() -> void:
	for category: String in _model_panelss:
		_model_panelss[category]["active_idx"] = -1


## 返回当前选中的模型项 {category, index, item}，没有选中返回空字典。
## 放置时左键点击调用，决定放哪个物件。
func _get_active_model_item() -> Dictionary:
	for category: String in _model_panelss:
		var panel: Dictionary = _model_panelss[category]
		var idx: int = panel["active_idx"]
		if idx >= 0 and idx < panel["items"].size():
			return {"category": category, "index": idx, "item": panel["items"][idx]}
	return {}


## 点某模型栏位"导入"按钮：弹文件选择框选模型文件。category 由按钮 bind 带入。
## FileDialog 一次性建，复用；选完后 _on_import_file_selected 走导入流程。
func _on_model_import_pressed(category: String) -> void:
	_import_target_category = category
	_show_import_dialog("选一个 3D 模型导入" + _model_panelss[category]["label"] + "库",
		["*.glb ;glTF Binary（自包含模型）"])


## 建/复用导入文件选择框并弹出。filters 是 add_filter 的参数对（扩展名;描述）。
## 依据 gdd_0596：access=ACCESS_FILESYSTEM 能选电脑任意位置的文件；
## file_mode=FILE_MODE_OPEN_FILE 单选；add_filter 限制可选类型。
func _show_import_dialog(title_text: String, filters: Array) -> void:
	if _import_fd == null or not is_instance_valid(_import_fd):
		_import_fd = FileDialog.new()
		_import_fd.access = FileDialog.ACCESS_FILESYSTEM  # 能选电脑任意文件
		_import_fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE  # 单选一个文件
		_import_fd.use_native_dialog = true  # 用系统原生选择框，GM 更熟
		_import_fd.file_selected.connect(_on_import_file_selected)
		add_child(_import_fd)
	_import_fd.clear_filters()
	for f: Variant in filters:
		_import_fd.add_filter(f[0], f[1])
	_import_fd.title = title_text
	_import_fd.popup_file_dialog()


## 文件选择框选完文件回调：复制进目标栏位素材库 → 重建该栏位列表 → 刷新左栏按钮。
## 依据 gdd_0596 file_selected 信号（第 113 行）传选中文件路径。
func _on_import_file_selected(path: String) -> void:
	if path == "" or _import_target_category == "":
		return
	var category: String = _import_target_category
	_import_target_category = ""
	var expected_dest: String = LibraryManager.LIBRARY_ROOT + category + "/" + path.get_file()
	_drop_model_cache(expected_dest)
	var dest: String = _library_mgr.import_file(path, category)
	if dest == "":
		_tool_label.text = "导入失败：" + path.get_file()
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return
	# 重建该栏位的 items + 按钮
	var panel: Dictionary = _model_panelss[category]
	panel["items"] = _rebuild_model_items(category, panel["builtin_dir"])
	_rebuild_model_buttons(category)
	_tool_label.text = "已导入" + panel["label"] + "：" + dest.get_file()
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 点地面纹理栏"导入纹理文件夹"按钮：弹文件夹选择框。
## 地面纹理按 PBR 多图一组：选一个文件夹，里面多张图按文件名分类。
func _on_ground_import_pressed() -> void:
	_show_import_dir_dialog("选一个文件夹导入地面纹理（里面多张图按文件名自动分类）")


## 建/复用文件夹选择框并弹出。地面纹理导入用（选文件夹不是选文件）。
## 依据 gdd_0596：file_mode=FILE_MODE_OPEN_DIR 只选文件夹；dir_selected 信号（第 107 行）传选中目录。
func _show_import_dir_dialog(title_text: String) -> void:
	if _import_dir_fd == null or not is_instance_valid(_import_dir_fd):
		_import_dir_fd = FileDialog.new()
		_import_dir_fd.access = FileDialog.ACCESS_FILESYSTEM
		_import_dir_fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR  # 选文件夹
		_import_dir_fd.use_native_dialog = true
		_import_dir_fd.dir_selected.connect(_on_import_dir_selected)
		add_child(_import_dir_fd)
	_import_dir_fd.title = title_text
	_import_dir_fd.popup_file_dialog()


## 文件夹选择框选完回调：复制整个文件夹进地面纹理库 → 重建地面纹理列表。
## 依据 gdd_0596 dir_selected 信号传选中目录路径。
func _on_import_dir_selected(dir_path: String) -> void:
	if dir_path == "":
		return
	var dest: String = _library_mgr.import_texture_folder(dir_path)
	if dest == "":
		_tool_label.text = "导入纹理失败：" + dir_path.get_file()
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return
	_rebuild_ground_buttons()  # 重扫自带+导入纹理，刷新按钮
	_tool_label.text = "已导入纹理：" + dest.get_file()
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 重建地面纹理按钮列表：清容器 → 合并自带(_ground_sets) + 导入(scan_ground_textures)
## → 按每组纹理建按钮。导入新纹理后调它刷新。
func _rebuild_ground_buttons() -> void:
	if _ground_list_container == null:
		return
	# 合并自带 + 导入的地面纹理（加 source 标记判断右键能否删）
	var all_sets: Array[Dictionary] = []
	for s: Dictionary in _ground_sets:
		var copy: Dictionary = s.duplicate()
		copy["source"] = "builtin"  # 自带，res:// 打包后只读删不掉
		all_sets.append(copy)
	var imported: Array[Dictionary] = _library_mgr.scan_ground_textures()
	for s: Dictionary in imported:
		var copy: Dictionary = s.duplicate()
		copy["source"] = "imported"  # 导入的，user:// 可删
		all_sets.append(copy)
	# 清旧按钮
	for c: Node in _ground_list_container.get_children():
		_ground_list_container.remove_child(c)
		c.queue_free()
	# 按每组纹理建按钮
	for s: Dictionary in all_sets:
		_ground_list_container.add_child(_btn_ground(s))


func _scan_textures(dir_path: String, out_arr: Array[Dictionary]) -> void:
	## 扫子文件夹=扫纹理组。每个子文件夹是一个材质,文件夹名=纹理组名。
	## 文件夹内的文件按关键词分类(albedo/normal/roughness等)；
	## 如果文件夹内只有一个文件则不分类别,直接当整张贴图(albedo)。
	var dd: DirAccess = DirAccess.open(dir_path)
	if dd == null:
		return
	dd.list_dir_begin()
	var subdir: String = dd.get_next()
	while subdir != "":
		if subdir == "." or subdir == "..":
			subdir = dd.get_next()
			continue
		if dd.current_is_dir():
			_scan_texture_folder(dir_path.path_join(subdir), subdir, out_arr)
		subdir = dd.get_next()
	dd.list_dir_end()


func _scan_texture_folder(folder_path: String, folder_name: String, out_arr: Array[Dictionary]) -> void:
	var dd: DirAccess = DirAccess.open(folder_path)
	if dd == null:
		return
	var files: Array[String] = []
	dd.list_dir_begin()
	var fn: String = dd.get_next()
	while fn != "":
		if not dd.current_is_dir():
			var low: String = fn.to_lower()
			if low.ends_with(".png") or low.ends_with(".jpg") or low.ends_with(".jpeg"):
				files.append(fn)
		fn = dd.get_next()
	dd.list_dir_end()
	if files.is_empty():
		return
	# 单文件 → 整个当 albedo，不分关键字匹配
	if files.size() == 1:
		out_arr.append({"_base": folder_name, "albedo": folder_path.path_join(files[0])})
		print("Gvtt: tex set " + folder_name + " (single file)")
		return
	# 多文件 → 逐文件分类。同类型只认第一个（避免多张同类型图互相覆盖）。
	var group: Dictionary = {"_base": folder_name}
	for f: String in files:
		var parsed: Dictionary = _classify_texture(f)
		if not group.has(parsed["type"]):  # 该类型还没图 → 存；已有 → 跳过不覆盖
			group[parsed["type"]] = folder_path.path_join(f)
	out_arr.append(group)
	print("Gvtt: tex set " + folder_name + " (%d files)" % files.size())


func _classify_texture(filename: String) -> Dictionary:
	var stem: String = filename.get_basename().get_file().to_lower()
	stem = stem.replace("-", "_")
	# 关键词子串搜索（不管类型词在文件名哪个位置），按长度降序先匹配更具体的。
	# 跟 library_manager.gd _classify_one_texture 同规则，保持自带/导入纹理一致。
	var rules: Array[Array] = [
		["ambient_occlusion", "ao"], ["ambientocclusion", "ao"],
		["base_color", "albedo"], ["basecolor", "albedo"],
		["metalness", "metallic"],
		["roughness", "roughness"], ["glossiness", "roughness"],
		["emission", "emission"], ["emissive", "emission"],
		["normal_gl", "normal"], ["normalgl", "normal"],
		["diffuse", "albedo"], ["albedo", "albedo"],
		["metallic", "metallic"],
		["normal", "normal"],
		["gloss", "roughness"],
		["_orm", "orm"], ["orm", "orm"],
		["_ao", "ao"], ["ao", "ao"],
		["color", "albedo"],
	]
	for rule: Array in rules:
		var kw: String = rule[0]
		var pos: int = stem.find(kw)
		if pos >= 0:
			var base_name: String = stem.substr(0, pos).strip_edges()
			return {"base": base_name, "type": rule[1]}
	return {"base": stem, "type": "albedo"}


func _apply_texture_set(ts: Dictionary, mat: StandardMaterial3D) -> void:
	for key: String in ["albedo", "normal", "roughness", "metallic", "ao"]:
		if ts.has(key):
			var tex: Texture2D = _load_texture_runtime(ts[key])
			if tex != null:
				match key:
					"albedo": mat.albedo_texture = tex
					"normal": mat.normal_texture = tex; mat.normal_enabled = true
					"roughness": mat.roughness_texture = tex; mat.roughness_enabled = true
					"metallic": mat.metallic_texture = tex; mat.metallic_enabled = true
					"ao": mat.ao_texture = tex; mat.ao_enabled = true


## res:// 内置图必须走 ResourceLoader 才能使用导出后的导入资源；user:// 外部图才直接读 Image。
func _load_texture_runtime(path: String) -> Texture2D:
	if path.begins_with("res://"):
		var resource: Resource = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
		if resource is Texture2D:
			return resource as Texture2D
		push_warning("内置纹理加载失败: %s" % path)
		return null
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		push_warning("外部纹理加载失败: %s" % path)
		return null
	return ImageTexture.create_from_image(image)


func _setup_camera() -> void:
	camera = $Camera3D
	_camera_view_controller.configure(camera, _grid_manager)
	_apply_camera_for_mode(ModeGate.current())


func _setup_cast_view() -> void:
	# CastView 只保有原生窗口壳，输出状态和呈现器统一归控制器。
	_cast_view = CastView.new()
	_cast_view.name = "CastView"
	add_child(_cast_view)
	_player_output_controller = PlayerOutputController.new()
	_player_output_controller.name = "PlayerOutputController"
	add_child(_player_output_controller)
	_player_output_controller.output_requested.connect(_on_player_output_requested)
	_player_output_controller.output_changed.connect(_on_player_output_changed)
	_player_output_controller.output_failed.connect(_on_player_output_failed)
	_player_output_controller.video_playback_changed.connect(_on_video_playback_changed)
	_player_output_controller.video_volume_changed.connect(_on_video_volume_changed)


func _setup_los_service() -> void:
	_los_service = _los_service_script.new() as Node
	if _los_service == null:
		push_error("LOSService 创建失败")
		return
	_los_service.name = "LOSService"
	_los_service.set_meta("gvtt_runtime_only", true)
	add_child(_los_service)
	_los_service.call(
		"configure",
		_content_root,
		Vector2(_current_scene_width(), _current_scene_height())
	)
	_player_fog_overlay = _fog_overlay_script.new() as CanvasLayer
	if _player_fog_overlay == null:
		push_error("玩家 LOS 遮罩创建失败")
		return
	_player_fog_overlay.name = "PlayerFogOverlay"
	_player_fog_overlay.set_meta("gvtt_runtime_only", true)
	add_child(_player_fog_overlay)
	_player_fog_overlay.call("configure", get_viewport(), camera, 0)
	_los_service.connect(
		"visibility_changed",
		Callable(self, "_on_player_los_visibility_changed")
	)
	if _cast_view != null and _player_output_controller != null:
		_player_output_controller.configure(
			_cast_view,
			camera,
			_los_service,
			Callable(ModuleGate, "current_module_dir")
		)


func _setup_gm_tool_overlay() -> void:
	_gm_tool_overlay = _gm_tool_overlay_script.new() as CanvasLayer
	if _gm_tool_overlay == null:
		push_error("GM 工具前景层创建失败")
		return
	_gm_tool_overlay.name = "GMToolOverlay"
	_gm_tool_overlay.set_meta("gvtt_runtime_only", true)
	add_child(_gm_tool_overlay)
	var gm_only_mask: int = 1 << (GvttRenderLayers.RENDER_LAYER_GM_ONLY - 1)
	_gm_tool_overlay.call("configure", get_viewport(), camera, gm_only_mask, 1)
	if not bool(_gm_tool_overlay.call("adopt_gizmo_surface", _gizmo)):
		call_deferred("_adopt_gizmo_surface")


func _adopt_gizmo_surface() -> void:
	if (
		_gm_tool_overlay == null
		or not is_instance_valid(_gm_tool_overlay)
		or _gizmo == null
		or not is_instance_valid(_gizmo)
	):
		return
	if not bool(_gm_tool_overlay.call("adopt_gizmo_surface", _gizmo)):
		push_warning("Gizmo 辅助线未接入 GM 工具前景层")


func _on_player_los_visibility_changed(
	polygon: PackedVector2Array,
	active: bool
) -> void:
	if _player_fog_overlay == null or not is_instance_valid(_player_fog_overlay):
		return
	_player_fog_overlay.call("set_world_polygon", polygon, active)


func _apply_camera_for_mode(_mode: ModeGate.AppMode) -> void:
	_camera_view_controller.apply_for_mode(_mode)


## 球坐标 → 笛卡尔偏移,再放到相机并 look_at 焦点。
## pitch=0 水平,PI/2 正上。Godot 无现成球坐标 API,按文档手算三行。
func _update_orbit_camera() -> void:
	_camera_view_controller.update_orbit_camera()


func _setup_ground() -> void:
	_ground = $Ground
	var g: MeshInstance3D = _ground
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = ground_color
	mat.roughness = 0.9
	g.mesh = PlaneMesh.new()
	g.mesh.size = Vector2(grid_size, grid_size)
	g.set_surface_override_material(0, mat)


func _init_grid_manager() -> void:
	## 网格管理器（Godot 3D 编辑器网格方案）。
	## GridManager 自己作为节点挂到 main 下，里面建 GridOverlay MeshInstance3D 子节点。
	_grid_manager = load("res://scripts/grid_manager.gd").new()
	_grid_manager.name = "GridManager"
	add_child(_grid_manager)
	_camera_view_controller.configure(camera, _grid_manager)
	_refresh_grid()


func _refresh_grid() -> void:
	_camera_view_controller.refresh_grid()


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI_Layer"
	_ui_layer.layer = 2
	add_child(_ui_layer)
	_build_gm_media_surface()
	_left_panel = PanelContainer.new()
	_left_panel.name = "ItemPanel"
	_left_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE, true)
	_left_panel.set_offset(SIDE_TOP, 10)
	_left_panel.set_offset(SIDE_RIGHT, -210)
	_left_panel.custom_minimum_size = Vector2(200, 0)
	_ui_layer.add_child(_left_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left_panel.add_child(scroll)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)
	_tool_label = Label.new()
	_tool_label.text = "未选中工具"
	_tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_tool_label)
	# 幕是 GM 的第一工作入口；地图、媒体和文字都是幕可引用的内容。
	var act_section: VBoxContainer = _add_section(vbox, "幕", true)
	_act_library_panel = ActLibraryPanel.new()
	act_section.add_child(_act_library_panel)
	_act_library_panel.configure(
		_player_output_controller,
		Callable(self, "_on_scene_selected")
	)
	# 地图素材是幕的底层服务。编辑态在这里创建和保存，运行态从幕内引用切换。
	# 按 _add_section 规矩:节内容容器由它返回,按钮/列表都挂内容容器。
	_scene_section = _add_section(vbox, "地图素材")
	# 场景操作按钮行
	var scene_btn_row: HBoxContainer = HBoxContainer.new()
	scene_btn_row.add_theme_constant_override("separation", 4)
	_new_scene_btn = Button.new()
	_new_scene_btn.text = "新建地图"
	_new_scene_btn.custom_minimum_size = Vector2(88, 32)
	_new_scene_btn.tooltip_text = "新建一个空地图素材"
	_new_scene_btn.pressed.connect(_on_new_scene_pressed)
	scene_btn_row.add_child(_new_scene_btn)
	_save_scene_btn = Button.new()
	_save_scene_btn.text = "保存此地图"
	_save_scene_btn.custom_minimum_size = Vector2(110, 32)
	_save_scene_btn.tooltip_text = "把当前编辑态存进当前选中地图(覆盖)"
	_save_scene_btn.pressed.connect(_on_save_scene_pressed)
	scene_btn_row.add_child(_save_scene_btn)
	_scene_section.add_child(scene_btn_row)
	_scene_section.add_child(HSeparator.new())
	# 场景大小输入行:宽/高各一个输入框(2026-07-15 改:支持长方形场地)。
	# 跟其他栏位的导入按钮同样的位置和风格。
	var size_row: HBoxContainer = HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 6)
	var w_lbl: Label = Label.new()
	w_lbl.text = "宽"
	w_lbl.custom_minimum_size = Vector2(30, 0)
	w_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_row.add_child(w_lbl)
	_scene_width_input = SpinBox.new()
	_scene_width_input.min_value = 5.0
	_scene_width_input.max_value = 500.0
	_scene_width_input.step = 5.0
	_scene_width_input.value = DEFAULT_SCENE_WIDTH
	_scene_width_input.custom_minimum_size = Vector2(80, 32)
	_scene_width_input.tooltip_text = "地面 X 轴边长(米),改后地面/网格/纹理一起适配"
	_scene_width_input.value_changed.connect(_on_scene_width_changed)
	size_row.add_child(_scene_width_input)
	var h_lbl: Label = Label.new()
	h_lbl.text = "高"
	h_lbl.custom_minimum_size = Vector2(30, 0)
	h_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_child(h_lbl)
	_scene_height_input = SpinBox.new()
	_scene_height_input.min_value = 5.0
	_scene_height_input.max_value = 500.0
	_scene_height_input.step = 5.0
	_scene_height_input.value = DEFAULT_SCENE_HEIGHT
	_scene_height_input.custom_minimum_size = Vector2(80, 32)
	_scene_height_input.tooltip_text = "地面 Z 轴边长(米),改后地面/网格/纹理一起适配"
	_scene_height_input.value_changed.connect(_on_scene_height_changed)
	size_row.add_child(_scene_height_input)
	_scene_section.add_child(size_row)
	_scene_section.add_child(HSeparator.new())
	# 下面场景列表空着——_sync_scene_list() 往里填按钮(MenuGate 列表变化时也连它刷新)。
	_build_media_section(vbox)
	# 模型类栏位：循环建 MODEL_PANELS 配置的 6 个栏位，地面纹理插在 terrain 和 wall 之间。
	# 每个模型栏位 = 可折叠节 + 导入按钮 + 列表容器（刷新时往里填物件按钮）。
	for i: int in MODEL_PANELS.size():
		var cfg: Dictionary = MODEL_PANELS[i]
		# 地面纹理栏插在 terrain(索引1) 之后、wall(索引2) 之前
		if cfg["category"] == "wall":
			_build_ground_section(vbox)
		_build_model_section(vbox, cfg)
	var top_bar_row: HBoxContainer = HBoxContainer.new()
	top_bar_row.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	top_bar_row.set_offset(SIDE_LEFT, -690)
	top_bar_row.set_offset(SIDE_TOP, 10)
	top_bar_row.set_offset(SIDE_RIGHT, -10)
	top_bar_row.custom_minimum_size = Vector2(670, 40)
	top_bar_row.alignment = BoxContainer.ALIGNMENT_END
	top_bar_row.add_theme_constant_override("separation", 6)
	_ui_layer.add_child(top_bar_row)
	_app_menu_btn = MenuButton.new()
	_app_menu_btn.text = "文件"
	_app_menu_btn.custom_minimum_size = Vector2(72, 36)
	var app_popup: PopupMenu = _app_menu_btn.get_popup()
	app_popup.add_item("保存模组", APP_MENU_SAVE_MODULE_ID)
	app_popup.add_item("选择模组", APP_MENU_SELECT_MODULE_ID)
	app_popup.id_pressed.connect(_on_app_menu_id_pressed)
	top_bar_row.add_child(_app_menu_btn)
	_current_module_label = Label.new()
	_current_module_label.custom_minimum_size = Vector2(140, 36)
	_current_module_label.custom_maximum_size = Vector2(190, -1)
	_current_module_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_current_module_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_current_module_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar_row.add_child(_current_module_label)
	# 子模式切换:地图 ↔ 自由视角。两个态都显示。
	_sub_btn = Button.new()
	_sub_btn.text = "地图"
	_sub_btn.custom_minimum_size = Vector2(80, 36)
	_sub_btn.pressed.connect(_on_sub_btn_pressed)
	top_bar_row.add_child(_sub_btn)
	# 保存视角:仅编辑态显示。把当前自由视角四量存为"游玩视角"权威。
	_save_view_btn = Button.new()
	_save_view_btn.text = "保存视角"
	_save_view_btn.custom_minimum_size = Vector2(90, 36)
	_save_view_btn.pressed.connect(_on_save_view_pressed)
	top_bar_row.add_child(_save_view_btn)
	# 恢复视角:仅运行态显示。一按把 _orbit_* 拉回 saved。
	_restore_view_btn = Button.new()
	_restore_view_btn.text = "恢复视角"
	_restore_view_btn.custom_minimum_size = Vector2(90, 36)
	_restore_view_btn.pressed.connect(_on_restore_view_pressed)
	top_bar_row.add_child(_restore_view_btn)
	# 投屏开关:两个态都能按,不归 ModeGate 管。按一下开/关玩家视角窗口。
	_cast_btn = Button.new()
	_cast_btn.text = "投屏 ⧉"
	_cast_btn.custom_minimum_size = Vector2(80, 36)
	_cast_btn.toggle_mode = false
	_cast_btn.pressed.connect(_on_cast_btn_pressed)
	top_bar_row.add_child(_cast_btn)
	_test_btn = Button.new()
	_test_btn.text = "测试 ▶"
	_test_btn.custom_minimum_size = Vector2(80, 36)
	_test_btn.tooltip_text = "临时运行，返回编辑后丢弃测试变化"
	_test_btn.pressed.connect(_on_test_btn_pressed)
	top_bar_row.add_child(_test_btn)
	_mode_btn = Button.new()
	_mode_btn.text = "开始 ▶"
	_mode_btn.custom_minimum_size = Vector2(90, 36)
	_mode_btn.pressed.connect(_on_mode_btn_pressed)
	top_bar_row.add_child(_mode_btn)
	_mode_label = Label.new()
	_mode_label.text = "编辑态"
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mode_label.custom_minimum_size = Vector2(60, 36)
	top_bar_row.add_child(_mode_label)
	# 属性面板:选中物件后右侧弹,绑 EntityProperties 字段。编辑态才显示选中。
	_build_prop_panel()


func _build_gm_media_surface() -> void:
	_gm_media_backdrop = ColorRect.new()
	_gm_media_backdrop.name = "GmMediaBackdrop"
	_gm_media_backdrop.color = Color.BLACK
	_gm_media_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gm_media_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gm_media_backdrop.hide()
	_ui_layer.add_child(_gm_media_backdrop)

	_gm_media_surface = TextureRect.new()
	_gm_media_surface.name = "GmMediaSurface"
	_gm_media_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gm_media_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gm_media_surface.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gm_media_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gm_media_surface.hide()
	_ui_layer.add_child(_gm_media_surface)


func _hide_gm_media_surface() -> void:
	if _gm_media_surface != null and is_instance_valid(_gm_media_surface):
		_gm_media_surface.texture = null
		_gm_media_surface.hide()
	if _gm_media_backdrop != null and is_instance_valid(_gm_media_backdrop):
		_gm_media_backdrop.hide()


func _sync_gm_media_surface(kind: int) -> void:
	if (
		_player_output_controller == null
		or kind != PlayerOutputController.OutputKind.IMAGE
		and kind != PlayerOutputController.OutputKind.VIDEO
	):
		_hide_gm_media_surface()
		return
	var texture: Texture2D = _player_output_controller.get_active_media_texture()
	if texture == null:
		_hide_gm_media_surface()
		return
	_gm_media_surface.texture = texture
	_gm_media_backdrop.show()
	_gm_media_surface.show()


func _sync_module_context_ui() -> void:
	_sync_playthrough_list()
	_sync_media_list()
	if _act_library_panel != null and is_instance_valid(_act_library_panel):
		_act_library_panel.refresh()
	if _current_module_label == null:
		return
	var module_name: String = ModuleGate.current_module_name()
	_current_module_label.text = module_name
	_current_module_label.tooltip_text = "当前模组：" + module_name if module_name != "" else ""
	if _app_menu_btn == null:
		return
	var popup: PopupMenu = _app_menu_btn.get_popup()
	var has_module: bool = ModuleGate.has_open_module()
	_set_popup_command_disabled(popup, APP_MENU_SAVE_MODULE_ID, not has_module or ModeGate.is_run())
	_set_popup_command_disabled(popup, APP_MENU_SELECT_MODULE_ID, not has_module)
	if _test_btn != null and is_instance_valid(_test_btn):
		_test_btn.disabled = not has_module
	if _mode_btn != null and is_instance_valid(_mode_btn):
		_mode_btn.disabled = not has_module
	_sync_playthrough_entry_ui()


func _sync_playthrough_list() -> void:
	if _playthrough_list == null or not is_instance_valid(_playthrough_list):
		return
	for child: Node in _playthrough_list.get_children():
		_playthrough_list.remove_child(child)
		child.queue_free()
	var can_manage: bool = ModuleGate.has_open_module() and ModeGate.is_edit()
	if _add_table_button != null and is_instance_valid(_add_table_button):
		_add_table_button.disabled = not can_manage
	if not ModuleGate.has_open_module():
		_playthrough_list.add_child(_playthrough_status_label("未打开模组。"))
		return
	var entries: Array[Dictionary] = ModuleGate.list_playthroughs()
	if entries.is_empty():
		_playthrough_list.add_child(_playthrough_status_label("还没有带团记录。"))
		return
	for entry: Dictionary in entries:
		_playthrough_list.add_child(_playthrough_row(entry, can_manage))


func _playthrough_status_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	return label


func _playthrough_row(entry: Dictionary, can_enter: bool) -> HBoxContainer:
	var session_id: String = String(entry.get("session_id", ""))
	var session_name: String = String(entry.get("session_name", "")).strip_edges()
	var load_error: int = int(entry.get("error", FAILED))
	if session_name == "":
		session_name = session_id.left(8)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "TableRow_" + session_id.left(8)
	row.add_theme_constant_override("separation", 4)
	row.set_meta("gvtt_session_id", session_id)
	row.set_meta("gvtt_session_name", session_name)
	var name_label: Label = Label.new()
	name_label.name = "TableName"
	name_label.text = session_name if load_error == OK else session_name + "（无法读取）"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = name_label.text
	row.add_child(name_label)
	var enter_button: Button = Button.new()
	enter_button.name = "EnterTable"
	enter_button.text = "进入"
	enter_button.custom_minimum_size = Vector2(58, 32)
	enter_button.disabled = not can_enter or load_error != OK
	enter_button.tooltip_text = (
		"进入“%s”" % session_name
		if load_error == OK
		else String(entry.get("message", "带团记录损坏"))
	)
	enter_button.pressed.connect(_continue_playthrough_from_dialog.bind(session_id))
	row.add_child(enter_button)
	return row


func _valid_playthrough_entries() -> Array[Dictionary]:
	var valid_entries: Array[Dictionary] = []
	for entry: Dictionary in ModuleGate.list_playthroughs():
		if int(entry.get("error", FAILED)) == OK:
			valid_entries.append(entry)
	return valid_entries


func _sync_playthrough_entry_ui() -> void:
	if _mode_btn == null or not is_instance_valid(_mode_btn) or ModeGate.is_run():
		return
	_mode_btn.text = "开始 ▶"
	_mode_btn.tooltip_text = "进入记录运行并自动保存进度"
	if _test_btn != null and is_instance_valid(_test_btn):
		_test_btn.text = "测试 ▶"
		_test_btn.tooltip_text = "临时运行，返回编辑后丢弃测试变化"


func _set_popup_command_disabled(popup: PopupMenu, command_id: int, disabled: bool) -> void:
	var item_index: int = popup.get_item_index(command_id)
	if item_index >= 0:
		popup.set_item_disabled(item_index, disabled)


func _build_media_section(parent: VBoxContainer) -> void:
	_media_section = _add_section(parent, "媒体", true)
	var output_row: HBoxContainer = HBoxContainer.new()
	output_row.add_theme_constant_override("separation", 4)
	_media_output_status_label = Label.new()
	_media_output_status_label.name = "MediaOutputStatus"
	_media_output_status_label.text = "投屏：未打开"
	_media_output_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_media_output_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_media_output_status_label.add_theme_color_override(
		"font_color",
		Color(0.65, 0.65, 0.65)
	)
	output_row.add_child(_media_output_status_label)
	_media_return_map_button = Button.new()
	_media_return_map_button.name = "MediaReturnMapButton"
	_media_return_map_button.text = "返回地图"
	_media_return_map_button.tooltip_text = "结束当前媒体演出并恢复玩家地图"
	_media_return_map_button.disabled = true
	_media_return_map_button.pressed.connect(_on_media_return_map_pressed)
	output_row.add_child(_media_return_map_button)
	_media_section.add_child(output_row)
	var video_control_row: HBoxContainer = HBoxContainer.new()
	video_control_row.name = "MediaVideoControls"
	video_control_row.add_theme_constant_override("separation", 4)
	_media_video_pause_button = Button.new()
	_media_video_pause_button.name = "MediaVideoPauseButton"
	_media_video_pause_button.text = "暂停"
	_media_video_pause_button.tooltip_text = "暂停或继续当前视频"
	_media_video_pause_button.disabled = true
	_media_video_pause_button.pressed.connect(_on_media_video_pause_pressed)
	video_control_row.add_child(_media_video_pause_button)
	_media_video_stop_button = Button.new()
	_media_video_stop_button.name = "MediaVideoStopButton"
	_media_video_stop_button.text = "停止"
	_media_video_stop_button.tooltip_text = "停止当前视频并恢复玩家地图"
	_media_video_stop_button.disabled = true
	_media_video_stop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_media_video_stop_button.pressed.connect(_on_media_video_stop_pressed)
	video_control_row.add_child(_media_video_stop_button)
	_media_video_pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_media_video_pause_button.custom_minimum_size = Vector2(0, 32)
	_media_video_stop_button.custom_minimum_size = Vector2(0, 32)
	_media_section.add_child(video_control_row)

	var volume_row: HBoxContainer = HBoxContainer.new()
	volume_row.name = "MediaVolumeControls"
	volume_row.add_theme_constant_override("separation", 6)
	_media_volume_label = Label.new()
	_media_volume_label.name = "MediaVolumeLabel"
	_media_volume_label.text = "音量 100%"
	volume_row.add_child(_media_volume_label)
	_media_volume_slider = HSlider.new()
	_media_volume_slider.name = "MediaVolumeSlider"
	_media_volume_slider.min_value = 0.0
	_media_volume_slider.max_value = 1.0
	_media_volume_slider.step = 0.01
	_media_volume_slider.value = _player_output_controller.get_video_volume_linear()
	_media_volume_slider.custom_minimum_size = Vector2(90, 0)
	_media_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_media_volume_slider.tooltip_text = "调整视频声音，不影响地图或其他声音"
	_media_volume_slider.value_changed.connect(_on_media_volume_changed)
	volume_row.add_child(_media_volume_slider)
	_media_section.add_child(volume_row)
	var add_row: HBoxContainer = HBoxContainer.new()
	_media_edit_row = add_row
	add_row.add_theme_constant_override("separation", 4)
	var add_image_button: Button = Button.new()
	add_image_button.text = "＋ 图片"
	add_image_button.tooltip_text = "登记电脑上的外部图片，只保存路径和元数据"
	add_image_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_image_button.pressed.connect(
		_show_media_file_dialog.bind(ExternalContentRef.ContentType.IMAGE)
	)
	add_row.add_child(add_image_button)
	var add_video_button: Button = Button.new()
	add_video_button.text = "＋ 视频"
	add_video_button.tooltip_text = "登记外部视频；当前支持 OGV、MP4、MOV、M4V"
	add_video_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_video_button.pressed.connect(
		_show_media_file_dialog.bind(ExternalContentRef.ContentType.VIDEO)
	)
	add_row.add_child(add_video_button)
	var refresh_button: Button = Button.new()
	refresh_button.text = "↻"
	refresh_button.tooltip_text = "重新检查媒体文件状态"
	refresh_button.custom_minimum_size = Vector2(34, 32)
	refresh_button.pressed.connect(_sync_media_list)
	add_row.add_child(refresh_button)
	_media_section.add_child(add_row)
	_media_list = VBoxContainer.new()
	_media_list.name = "MediaList"
	_media_list.add_theme_constant_override("separation", 4)
	_media_section.add_child(_media_list)


func _show_media_file_dialog(content_type: ExternalContentRef.ContentType) -> void:
	if not ModuleGate.has_open_module() or ModeGate.is_run():
		return
	_media_import_type = content_type
	if _media_file_dialog == null or not is_instance_valid(_media_file_dialog):
		_media_file_dialog = FileDialog.new()
		_media_file_dialog.name = "MediaFileDialog"
		_media_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_media_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_media_file_dialog.deleting_enabled = false
		_media_file_dialog.file_selected.connect(_on_media_file_selected)
		add_child(_media_file_dialog)
	_media_file_dialog.clear_filters()
	if content_type == ExternalContentRef.ContentType.IMAGE:
		_media_file_dialog.title = "登记图片"
		_media_file_dialog.add_filter(
			MEDIA_IMAGE_FILTER,
			"图片",
			"image/bmp,image/jpeg,image/png,image/svg+xml,image/tga,image/webp"
		)
	else:
		_media_file_dialog.title = "登记视频"
		_media_file_dialog.add_filter(MEDIA_VIDEO_FILTER, "视频")
	_media_file_dialog.popup_file_dialog()


func _on_media_file_selected(path: String) -> void:
	if ModeGate.is_run():
		return
	var result: Dictionary = ModuleGate.register_external_content(path, _media_import_type)
	var error: int = int(result.get("error", FAILED))
	if error != OK:
		_tool_label.text = String(result.get("message", "媒体登记失败")) + " code=" + str(error)
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return
	var inspection: Dictionary = result.get("inspection", {}) as Dictionary
	_tool_label.text = "媒体已登记 · " + String(inspection.get("status_text", ""))
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _sync_media_list() -> void:
	if _media_list == null or not is_instance_valid(_media_list):
		return
	for child: Node in _media_list.get_children():
		_media_list.remove_child(child)
		child.queue_free()
	var entries: Array[Dictionary] = ModuleGate.list_external_content_entries()
	if entries.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "尚未登记媒体"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_media_list.add_child(empty_label)
		return
	for entry: Dictionary in entries:
		var content: ExternalContentRef = entry.get("content") as ExternalContentRef
		if content == null:
			continue
		var status: StringName = StringName(String(entry.get("status", "")))
		var title_row: HBoxContainer = HBoxContainer.new()
		var name_label: Label = Label.new()
		name_label.text = content.display_name
		name_label.tooltip_text = content.display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(name_label)
		if content.content_type == ExternalContentRef.ContentType.IMAGE:
			var play_button: Button = Button.new()
			play_button.name = "MediaPlayButton_" + content.content_id
			play_button.text = "投放"
			play_button.tooltip_text = "在玩家投屏窗口显示这张图片"
			play_button.custom_minimum_size = Vector2(54, 28)
			play_button.pressed.connect(_on_media_image_play_pressed.bind(content.content_id))
			title_row.add_child(play_button)
		elif content.content_type == ExternalContentRef.ContentType.VIDEO:
			var play_video_button: Button = Button.new()
			play_video_button.name = "MediaPlayButton_" + content.content_id
			play_video_button.text = "播放"
			play_video_button.tooltip_text = "在玩家投屏窗口播放这个视频"
			play_video_button.custom_minimum_size = Vector2(54, 28)
			play_video_button.disabled = status != MediaRegistry.STATUS_PLAYABLE
			play_video_button.pressed.connect(_on_media_video_play_pressed.bind(content.content_id))
			title_row.add_child(play_video_button)
		if ModeGate.is_edit():
			var action_button: MenuButton = MenuButton.new()
			action_button.text = "⋮"
			action_button.tooltip_text = "媒体操作"
			action_button.custom_minimum_size = Vector2(32, 28)
			var action_popup: PopupMenu = action_button.get_popup()
			action_popup.add_item("重命名", MEDIA_ACTION_RENAME_ID)
			action_popup.add_item("删除登记", MEDIA_ACTION_DELETE_ID)
			action_popup.id_pressed.connect(_on_media_action_pressed.bind(content.content_id))
			title_row.add_child(action_button)
		_media_list.add_child(title_row)
		var type_status_label: Label = Label.new()
		type_status_label.text = "类型：%s    状态：%s" % [
			MediaRegistry.content_type_text(content.content_type),
			String(entry.get("status_text", "未知")),
		]
		type_status_label.add_theme_color_override("font_color", _media_status_color(status))
		_media_list.add_child(type_status_label)
		var source_label: Label = Label.new()
		source_label.text = "来源：%s · %s" % [
			"模组内" if content.source_kind == ExternalContentRef.SourceKind.MODULE_RELATIVE else "外部",
			content.source_path.get_file(),
		]
		source_label.tooltip_text = MediaRegistry.source_text(content)
		source_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		_media_list.add_child(source_label)
		_media_list.add_child(HSeparator.new())


func _media_status_color(status: StringName) -> Color:
	match status:
		MediaRegistry.STATUS_PLAYABLE:
			return Color(0.3, 0.8, 0.3)
		MediaRegistry.STATUS_MISSING:
			return Color(0.95, 0.55, 0.25)
		MediaRegistry.STATUS_DAMAGED:
			return Color(0.9, 0.3, 0.3)
		MediaRegistry.STATUS_UNSUPPORTED:
			return Color(0.75, 0.65, 0.3)
	return Color(0.7, 0.7, 0.7)


func _on_media_action_pressed(action_id: int, content_id: String) -> void:
	if ModeGate.is_run():
		return
	match action_id:
		MEDIA_ACTION_RENAME_ID:
			_show_media_rename_dialog(content_id)
		MEDIA_ACTION_DELETE_ID:
			_show_media_delete_dialog(content_id)


func _on_media_image_play_pressed(content_id: String) -> void:
	var content: ExternalContentRef = _find_media_content(content_id)
	if content == null or content.content_type != ExternalContentRef.ContentType.IMAGE:
		_set_media_output_error("图片登记不存在")
		return
	if _player_output_controller == null or not is_instance_valid(_player_output_controller):
		_set_media_output_error("投屏控制器不可用")
		return
	if not _player_output_controller.is_open():
		var open_result: Dictionary = _player_output_controller.open_output()
		if int(open_result.get("error", FAILED)) != OK:
			_set_media_output_error(String(open_result.get("message", "投屏窗口打开失败")))
			return
	_media_output_error_active = false
	_set_media_output_status("正在载入图片 · " + content.display_name, Color(0.75, 0.75, 0.75))
	_player_output_controller.show_image(content)


func _on_media_video_play_pressed(content_id: String) -> void:
	var content: ExternalContentRef = _find_media_content(content_id)
	if content == null or content.content_type != ExternalContentRef.ContentType.VIDEO:
		_set_media_output_error("视频登记不存在")
		return
	if _player_output_controller == null or not is_instance_valid(_player_output_controller):
		_set_media_output_error("投屏控制器不可用")
		return
	if not _player_output_controller.is_open():
		var open_result: Dictionary = _player_output_controller.open_output()
		if int(open_result.get("error", FAILED)) != OK:
			_set_media_output_error(String(open_result.get("message", "投屏窗口打开失败")))
			return
	_media_output_error_active = false
	_set_media_output_status("正在载入视频 · " + content.display_name, Color(0.75, 0.75, 0.75))
	_player_output_controller.show_video(content)


func _on_media_video_pause_pressed() -> void:
	if _player_output_controller == null:
		return
	var error: int = ERR_UNCONFIGURED
	if _player_output_controller.phase == PlayerOutputController.OutputPhase.PAUSED:
		error = _player_output_controller.resume_video()
	else:
		error = _player_output_controller.pause_video()
	if error != OK:
		_set_media_output_error("视频暂停或恢复失败")


func _on_media_video_stop_pressed() -> void:
	if _player_output_controller == null:
		return
	var request_id: int = _player_output_controller.stop_video()
	if request_id <= 0:
		_set_media_output_error("视频停止失败")


func _on_media_volume_changed(value: float) -> void:
	if _player_output_controller != null:
		_player_output_controller.set_video_volume_linear(value)
	_on_video_volume_changed(value)


func _on_media_return_map_pressed() -> void:
	if _player_output_controller == null or not _player_output_controller.is_open():
		return
	_media_output_error_active = false
	_player_output_controller.return_to_map()


func _show_media_rename_dialog(content_id: String) -> void:
	var content: ExternalContentRef = _find_media_content(content_id)
	if content == null:
		return
	_close_media_rename_dialog()
	_pending_media_id = content_id
	_media_rename_dialog = ConfirmationDialog.new()
	_media_rename_dialog.name = "MediaRenameDialog"
	_media_rename_dialog.title = "重命名媒体"
	_media_rename_dialog.dialog_text = "只修改列表名称，不移动或改名原文件。"
	_media_rename_dialog.ok_button_text = "保存名称"
	_media_rename_dialog.cancel_button_text = "取消"
	_media_rename_edit = LineEdit.new()
	_media_rename_edit.text = content.display_name
	_media_rename_edit.select_all()
	_media_rename_dialog.add_child(_media_rename_edit)
	_media_rename_dialog.register_text_enter(_media_rename_edit)
	_media_rename_dialog.confirmed.connect(_on_media_rename_confirmed)
	_media_rename_dialog.canceled.connect(_close_media_rename_dialog)
	add_child(_media_rename_dialog)
	_media_rename_dialog.popup_centered(Vector2i(420, 0))
	_media_rename_edit.grab_focus()


func _on_media_rename_confirmed() -> void:
	var new_name: String = _media_rename_edit.text if _media_rename_edit != null else ""
	var error: int = ModuleGate.rename_external_content(_pending_media_id, new_name)
	_close_media_rename_dialog()
	if error != OK:
		_tool_label.text = "媒体重命名失败 code=" + str(error)
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _close_media_rename_dialog() -> void:
	if _media_rename_dialog != null and is_instance_valid(_media_rename_dialog):
		_media_rename_dialog.queue_free()
	_media_rename_dialog = null
	_media_rename_edit = null
	_pending_media_id = ""


func _show_media_delete_dialog(content_id: String) -> void:
	var content: ExternalContentRef = _find_media_content(content_id)
	if content == null:
		return
	if _media_delete_dialog != null and is_instance_valid(_media_delete_dialog):
		_media_delete_dialog.queue_free()
	_pending_media_id = content_id
	_media_delete_dialog = ConfirmationDialog.new()
	_media_delete_dialog.name = "MediaDeleteDialog"
	_media_delete_dialog.title = "删除媒体登记"
	_media_delete_dialog.dialog_text = "从列表删除“%s”？原文件不会被删除。" % content.display_name
	_media_delete_dialog.ok_button_text = "删除登记"
	_media_delete_dialog.cancel_button_text = "取消"
	_media_delete_dialog.confirmed.connect(_on_media_delete_confirmed)
	_media_delete_dialog.canceled.connect(_close_media_delete_dialog)
	add_child(_media_delete_dialog)
	_media_delete_dialog.popup_centered(Vector2i(420, 0))


func _on_media_delete_confirmed() -> void:
	var error: int = ModuleGate.remove_external_content(_pending_media_id)
	_close_media_delete_dialog()
	if error != OK:
		_tool_label.text = "删除媒体登记失败 code=" + str(error)
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _close_media_delete_dialog() -> void:
	if _media_delete_dialog != null and is_instance_valid(_media_delete_dialog):
		_media_delete_dialog.queue_free()
	_media_delete_dialog = null
	_pending_media_id = ""


func _find_media_content(content_id: String) -> ExternalContentRef:
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		return null
	for content: ExternalContentRef in manifest.external_contents:
		if content.content_id == content_id:
			return content
	return null


## 建一个模型类栏位（Token/地形/墙体/装饰/交互物体/光源 共用）。
## cfg = MODEL_PANELS 的一项 {label, category, builtin_dir}。
## 栏位 = 可折叠节 + 导入按钮 + 列表容器。状态存进 _model_panelss[category]。
func _build_model_section(parent: VBoxContainer, cfg: Dictionary) -> void:
	var category: String = cfg["category"]
	var items: Array[Dictionary] = _rebuild_model_items(category, cfg["builtin_dir"])
	var count: int = items.size()
	var sec: VBoxContainer = _add_section(parent, "%s (%d)" % [cfg["label"], count])
	# 导入按钮：栏位顶部。点下弹文件选择框，选 GLB/glTF 复制进素材库。
	# 主推 GLB（贴图嵌文件内），FBX 兼容但贴图可能丢（见 memory gvtt_model_embedded_textures_only）。
	var import_btn: Button = Button.new()
	import_btn.text = "＋ 导入模型"
	import_btn.custom_minimum_size = Vector2(0, 32)
	import_btn.tooltip_text = "从电脑选 GLB（推荐，自带贴图）或 glTF 模型，存进素材库反复用"
	import_btn.pressed.connect(_on_model_import_pressed.bind(category))
	sec.add_child(import_btn)
	# 列表容器：刷新时往里填物件按钮
	var list_container: VBoxContainer = VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 4)
	sec.add_child(list_container)
	# 状态存进 _model_panelss，供刷新/选中/放置用
	_model_panelss[category] = {
		"items": items,
		"active_idx": -1,
		"container": list_container,
		"import_btn": import_btn,
		"label": cfg["label"],
		"builtin_dir": cfg["builtin_dir"],
	}
	_rebuild_model_buttons(category)


## 建地面纹理栏：可折叠节 + 导入按钮 + 平铺控件 + 纹理按钮列表。
## 地面纹理导入按文件夹（PBR 多图一组），复用 _classify_texture 文件名分类。
func _build_ground_section(parent: VBoxContainer) -> void:
	var ground_sec: VBoxContainer = _add_section(parent, "地面纹理")
	# 导入按钮：选一个文件夹（里面多张图按文件名分类成颜色/法线/粗糙等）
	var ground_import_btn: Button = Button.new()
	ground_import_btn.text = "＋ 导入纹理文件夹"
	ground_import_btn.custom_minimum_size = Vector2(0, 32)
	ground_import_btn.tooltip_text = "选一个文件夹（里面多张图按文件名自动分类成颜色/法线/粗糙等 PBR 贴图）"
	ground_import_btn.pressed.connect(_on_ground_import_pressed)
	ground_sec.add_child(ground_import_btn)
	_ground_import_btn = ground_import_btn
	# 平铺尺寸控制区（不选纹理时隐藏）——分成上下两行
	_tile_control_area = VBoxContainer.new()
	_tile_control_area.add_theme_constant_override("separation", 6)
	_tile_control_area.visible = false
	# 第一行：标签 + 数字输入框
	var _tile_top_row: HBoxContainer = HBoxContainer.new()
	_tile_top_row.add_theme_constant_override("separation", 6)
	var _tile_label: Label = Label.new()
	_tile_label.text = "平铺尺寸"
	_tile_label.custom_minimum_size = Vector2(80, 0)
	_tile_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tile_top_row.add_child(_tile_label)
	_tile_spinbox = SpinBox.new()
	_tile_spinbox.min_value = 0.1
	_tile_spinbox.max_value = 100.0
	_tile_spinbox.step = 0.25
	_tile_spinbox.value = ground_tile_size
	_tile_spinbox.custom_minimum_size = Vector2(60, 30)
	_tile_spinbox.value_changed.connect(_on_tile_changed)
	_tile_top_row.add_child(_tile_spinbox)
	_tile_control_area.add_child(_tile_top_row)
	# 第二行：滑条单独占满宽度
	_tile_slider = HSlider.new()
	_tile_slider.custom_minimum_size = Vector2(0, 32)
	_tile_slider.min_value = 0.5
	_tile_slider.max_value = 100.0
	_tile_slider.step = 0.5
	_tile_slider.value = ground_tile_size
	_tile_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 给滑条轨道的样式，一眼能看见条在哪
	var slider_box: StyleBoxFlat = StyleBoxFlat.new()
	slider_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	slider_box.content_margin_top = 2
	slider_box.content_margin_bottom = 2
	slider_box.corner_radius_top_left = 4
	slider_box.corner_radius_top_right = 4
	slider_box.corner_radius_bottom_left = 4
	slider_box.corner_radius_bottom_right = 4
	_tile_slider.add_theme_stylebox_override("slider", slider_box)
	_tile_slider.add_theme_stylebox_override("grabber_area", slider_box)
	# 滑块圆点做大，高亮
	var grabber_box: StyleBoxFlat = StyleBoxFlat.new()
	grabber_box.bg_color = Color(0.5, 0.5, 0.5)
	grabber_box.content_margin_left = 8
	grabber_box.content_margin_right = 8
	grabber_box.content_margin_top = 10
	grabber_box.content_margin_bottom = 10
	grabber_box.corner_radius_top_left = 12
	grabber_box.corner_radius_top_right = 12
	grabber_box.corner_radius_bottom_left = 12
	grabber_box.corner_radius_bottom_right = 12
	var grabber_hl: StyleBoxFlat = grabber_box.duplicate()
	grabber_hl.bg_color = Color(0.7, 0.7, 0.7)
	_tile_slider.add_theme_stylebox_override("grabber", grabber_box)
	_tile_slider.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	_tile_slider.add_theme_stylebox_override("grabber_pressed", grabber_hl)
	_tile_slider.value_changed.connect(_on_tile_changed)
	_tile_control_area.add_child(_tile_slider)
	ground_sec.add_child(_tile_control_area)
	# 纹理按钮列表容器（刷新时往里填）
	_ground_list_container = VBoxContainer.new()
	_ground_list_container.add_theme_constant_override("separation", 4)
	ground_sec.add_child(_ground_list_container)
	_rebuild_ground_buttons()


## 属性面板:右侧弹一栏,字段绑选中物件的 EntityProperties。
## 选中物件 = 该物件根上挂的 EntityProperties 组件。改控件回写属性。
func _build_prop_panel() -> void:
	_prop_panel = PanelContainer.new()
	_prop_panel.name = "PropPanel"
	_prop_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE, true)
	_prop_panel.set_offset(SIDE_TOP, 50)
	_prop_panel.set_offset(SIDE_BOTTOM, -10)
	_prop_panel.set_offset(SIDE_RIGHT, -10)
	_prop_panel.set_offset(SIDE_LEFT, -260)
	_prop_panel.custom_minimum_size = Vector2(240, 0)
	_prop_panel.visible = false
	_ui_layer.add_child(_prop_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_prop_panel.add_child(scroll)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)
	_prop_title = Label.new()
	_prop_title.text = "未选中物件"
	_prop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_prop_title)
	vbox.add_child(HSeparator.new())
	_prop_runtime_box = VBoxContainer.new()
	_prop_runtime_box.visible = false
	_prop_runtime_box.add_theme_constant_override("separation", 8)
	_prop_runtime_type_label = Label.new()
	_prop_runtime_status_label = Label.new()
	_prop_runtime_detail_label = Label.new()
	_prop_runtime_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prop_runtime_light_toggle_btn = Button.new()
	_prop_runtime_light_toggle_btn.text = "切换光源"
	_prop_runtime_light_toggle_btn.toggle_mode = true
	_prop_runtime_light_toggle_btn.custom_minimum_size = Vector2(0, 36)
	_prop_runtime_light_toggle_btn.tooltip_text = "运行态开关选中的光源物件"
	_prop_runtime_light_toggle_btn.visible = false
	_prop_runtime_light_toggle_btn.pressed.connect(_on_runtime_light_toggle_pressed)
	_prop_runtime_wall_toggle_btn = Button.new()
	_prop_runtime_wall_toggle_btn.text = "破坏墙体"
	_prop_runtime_wall_toggle_btn.custom_minimum_size = Vector2(0, 36)
	_prop_runtime_wall_toggle_btn.tooltip_text = "运行态破坏或修复选中的墙体"
	_prop_runtime_wall_toggle_btn.visible = false
	_prop_runtime_wall_toggle_btn.pressed.connect(_on_runtime_wall_toggle_pressed)
	_prop_runtime_box.add_child(_prop_runtime_type_label)
	_prop_runtime_box.add_child(_prop_runtime_status_label)
	_prop_runtime_box.add_child(_prop_runtime_detail_label)
	_prop_runtime_box.add_child(_prop_runtime_light_toggle_btn)
	_prop_runtime_box.add_child(_prop_runtime_wall_toggle_btn)
	vbox.add_child(_prop_runtime_box)
	# 显示名
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	var nlbl: Label = Label.new()
	nlbl.text = "名字"
	nlbl.custom_minimum_size = Vector2(50, 0)
	nlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(nlbl)
	_prop_name_edit = LineEdit.new()
	_prop_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_name_edit.text_changed.connect(_on_prop_name_changed)
	name_row.add_child(_prop_name_edit)
	vbox.add_child(name_row)
	_prop_editor_controls.append(name_row)
	# 玩家可见(勾选框):勾上=玩家+GM 都看得到(visibility=BOTH);
	# 勾掉=仅 GM 看,投屏那头被 cull_mask 关掉(visibility=GM_ONLY)。
	_prop_vis_chk = CheckBox.new()
	_prop_vis_chk.text = "玩家可见"
	_prop_vis_chk.toggled.connect(_on_prop_vis_toggled)
	vbox.add_child(_prop_vis_chk)
	_prop_editor_controls.append(_prop_vis_chk)
	_prop_light_box = VBoxContainer.new()
	_prop_light_box.add_theme_constant_override("separation", 6)
	var light_title: Label = Label.new()
	light_title.text = "光源"
	light_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prop_light_box.add_child(light_title)
	_prop_light_on_chk = CheckBox.new()
	_prop_light_on_chk.text = "默认开启"
	_prop_light_on_chk.toggled.connect(_on_prop_light_on_toggled)
	_prop_light_box.add_child(_prop_light_on_chk)
	var light_color_row: HBoxContainer = HBoxContainer.new()
	light_color_row.add_theme_constant_override("separation", 6)
	var light_color_label: Label = Label.new()
	light_color_label.text = "颜色"
	light_color_label.custom_minimum_size = Vector2(80, 0)
	light_color_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	light_color_row.add_child(light_color_label)
	_prop_light_color_picker = ColorPickerButton.new()
	_prop_light_color_picker.custom_minimum_size = Vector2(96, 32)
	_prop_light_color_picker.edit_alpha = false
	_prop_light_color_picker.edit_intensity = true
	_prop_light_color_picker.tooltip_text = "调整这盏光源的颜色"
	_prop_light_color_picker.color_changed.connect(_on_prop_light_color_changed)
	light_color_row.add_child(_prop_light_color_picker)
	_prop_light_box.add_child(light_color_row)
	var light_energy_row: HBoxContainer = HBoxContainer.new()
	light_energy_row.add_theme_constant_override("separation", 6)
	var light_energy_label: Label = Label.new()
	light_energy_label.text = "亮度"
	light_energy_label.custom_minimum_size = Vector2(80, 0)
	light_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	light_energy_row.add_child(light_energy_label)
	_prop_light_energy_spin = SpinBox.new()
	_prop_light_energy_spin.min_value = 0.0
	_prop_light_energy_spin.max_value = 20.0
	_prop_light_energy_spin.step = 0.1
	_prop_light_energy_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_light_energy_spin.value_changed.connect(_on_prop_light_energy_changed)
	light_energy_row.add_child(_prop_light_energy_spin)
	_prop_light_box.add_child(light_energy_row)
	var light_range_row: HBoxContainer = HBoxContainer.new()
	light_range_row.add_theme_constant_override("separation", 6)
	var light_range_label: Label = Label.new()
	light_range_label.text = "范围"
	light_range_label.custom_minimum_size = Vector2(80, 0)
	light_range_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	light_range_row.add_child(light_range_label)
	_prop_light_range_spin = SpinBox.new()
	_prop_light_range_spin.min_value = 0.1
	_prop_light_range_spin.max_value = 100.0
	_prop_light_range_spin.step = 0.1
	_prop_light_range_spin.suffix = " 米"
	_prop_light_range_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_light_range_spin.value_changed.connect(_on_prop_light_range_changed)
	light_range_row.add_child(_prop_light_range_spin)
	_prop_light_box.add_child(light_range_row)
	_prop_light_shadow_chk = CheckBox.new()
	_prop_light_shadow_chk.text = "投射阴影"
	_prop_light_shadow_chk.toggled.connect(_on_prop_light_shadow_toggled)
	_prop_light_box.add_child(_prop_light_shadow_chk)
	vbox.add_child(_prop_light_box)
	_prop_editor_controls.append(_prop_light_box)
	# 可透光(勾选框):勾上=透光→los_occluder=false(不挡视线,战争迷雾不算它);
	# 勾掉=不透光→los_occluder=true(挡视线)。引擎无法从 mesh 自动判透光,
	# 只能 GM 手标(2026-07-09 推翻旧"物理事实"判定)。默认勾掉(不透光)。
	_prop_los_chk = CheckBox.new()
	_prop_los_chk.text = "可透光"
	_prop_los_chk.toggled.connect(_on_prop_los_toggled)
	vbox.add_child(_prop_los_chk)
	_prop_editor_controls.append(_prop_los_chk)
	# 可破坏(勾选框)
	_prop_destructible_chk = CheckBox.new()
	_prop_destructible_chk.text = "可破坏"
	_prop_destructible_chk.toggled.connect(_on_prop_destructible_toggled)
	vbox.add_child(_prop_destructible_chk)
	_prop_editor_controls.append(_prop_destructible_chk)
	# 掩体由模型真实高度自动分类，面板只显示结果。
	_prop_cover_chk = CheckBox.new()
	_prop_cover_chk.text = "自动掩体（高于 1 米）"
	_prop_cover_chk.disabled = true
	vbox.add_child(_prop_cover_chk)
	_prop_editor_controls.append(_prop_cover_chk)
	# 最大生命(放最下面)
	_prop_max_hp_row = HBoxContainer.new()
	_prop_max_hp_row.add_theme_constant_override("separation", 6)
	var hlbl: Label = Label.new()
	hlbl.text = "最大生命"
	hlbl.custom_minimum_size = Vector2(80, 0)
	hlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prop_max_hp_row.add_child(hlbl)
	_prop_max_hp_spin = SpinBox.new()
	_prop_max_hp_spin.min_value = 1
	_prop_max_hp_spin.max_value = 9999
	_prop_max_hp_spin.value = 10
	_prop_max_hp_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_max_hp_spin.value_changed.connect(_on_prop_max_hp_changed)
	_prop_max_hp_row.add_child(_prop_max_hp_spin)
	vbox.add_child(_prop_max_hp_row)
	_prop_editor_controls.append(_prop_max_hp_row)
	# CPR Token 的 MOVE 规则字段只在对应组件存在时显示。
	_prop_move_row = HBoxContainer.new()
	_prop_move_row.add_theme_constant_override("separation", 6)
	var move_label: Label = Label.new()
	move_label.text = "MOVE"
	move_label.custom_minimum_size = Vector2(80, 0)
	move_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prop_move_row.add_child(move_label)
	_prop_move_spin = SpinBox.new()
	_prop_move_spin.min_value = 0
	_prop_move_spin.max_value = 20
	_prop_move_spin.step = 1
	_prop_move_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_move_spin.value_changed.connect(_on_prop_move_changed)
	_prop_move_row.add_child(_prop_move_spin)
	vbox.add_child(_prop_move_row)
	_prop_editor_controls.append(_prop_move_row)
	# 通行标签属于几何语义，规则提供器只负责解释不同标签的耗费。
	_prop_traversal_row = HBoxContainer.new()
	_prop_traversal_row.add_theme_constant_override("separation", 6)
	var traversal_label: Label = Label.new()
	traversal_label.text = "通行"
	traversal_label.custom_minimum_size = Vector2(80, 0)
	traversal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prop_traversal_row.add_child(traversal_label)
	_prop_traversal_option = OptionButton.new()
	_prop_traversal_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option_text: String in ["可走", "阻挡", "困难", "攀爬", "跳跃", "游泳"]:
		_prop_traversal_option.add_item(option_text)
	_prop_traversal_option.item_selected.connect(_on_prop_traversal_selected)
	_prop_traversal_row.add_child(_prop_traversal_option)
	vbox.add_child(_prop_traversal_row)
	_prop_editor_controls.append(_prop_traversal_row)


## 加一个可折叠的栏位。返回它的内容容器——栏位里的按钮/控件都挂这个容器上,
## 别直接挂总 vbox。点标题切内容容器显隐,标题前的 ▼/▶ 标展开/收起态。
## 依据:Button.flat=true 既保留按钮的可点性又去掉框线,视觉上等同原 Label;
## lambda 闭包捕获 content/btn/title,GDScript 4.x 支持(离线文档 gdd_1590 @GDScript)。
func _add_section(
		parent: VBoxContainer,
		title: String,
		runtime_visible: bool = false
) -> VBoxContainer:
	var separator: HSeparator = HSeparator.new()
	parent.add_child(separator)
	var btn: Button = Button.new()
	btn.text = "▼ " + title
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.flat = true
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	parent.add_child(btn)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	parent.add_child(content)
	_panel_sections.append({
		"separator": separator,
		"button": btn,
		"content": content,
		"title": title,
		"runtime_visible": runtime_visible,
	})
	btn.pressed.connect(func() -> void:
		content.visible = not content.visible
		btn.text = ("▼ " if content.visible else "▶ ") + title
	)
	return content


func _btn_ground(ts: Dictionary) -> Button:
	var btn: Button = Button.new()
	btn.text = str(ts["_base"]).capitalize()
	btn.custom_minimum_size = Vector2(0, 44)
	if ts.has("albedo"):
		var texture: Texture2D = _load_texture_runtime(ts["albedo"])
		var img: Image = texture.get_image() if texture != null else null
		if img != null and not img.is_empty():
			img.resize(48, 48, Image.INTERPOLATE_LANCZOS)
			btn.icon = ImageTexture.create_from_image(img)
			btn.expand_icon = true
	btn.pressed.connect(_on_ground_clicked.bind(ts))
	# 存元数据供右键删除用（跟模型栏同一套：_unhandled_input 里 gui_get_hovered_control 找按钮读 meta）
	btn.set_meta("kind", "ground")
	btn.set_meta("group", str(ts["_base"]))
	btn.set_meta("source", ts.get("source", "builtin"))
	return btn


func _delete_ground_item(group_name: String) -> void:
	var deleting_active: bool = (
		_active_ground_ts.get("_base", "") == group_name
		and _active_ground_ts.get("source", "") == "imported"
	)
	if not _library_mgr.delete_ground_texture(group_name):
		_tool_label.text = "删除失败：" + group_name
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return
	# 正在使用的纹理被删除后立即回到默认地面，避免画面与存档状态悬空。
	if deleting_active:
		if is_instance_valid(_content_root) and _content_root.get_script() != null:
			_content_root.ground_tex_base = DEFAULT_GROUND_TEX_BASE
			_content_root.ground_tex_source = "builtin"
			_content_root.ground_tile = 0.0
		_apply_ground_texture_for_scene(DEFAULT_GROUND_TEX_BASE, 0.0, "builtin")
		_mark_scene_dirty()
	_rebuild_ground_buttons()
	_tool_label.text = "已删除纹理：" + group_name
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _on_ground_clicked(ts: Dictionary) -> void:
	if not _has_editable_scene():
		return
	if _active_ground_ts == ts:
		return  # 同一纹理重复点击不重建材质
	_active_ground_ts = ts
	var base_name: String = ts.get("_base", "")
	var source: String = ts.get("source", "builtin")
	# 铺满模式(默认贴图):一张图永远铺满整个地面,跟场景拉伸。平铺控件藏掉(铺满模式调平铺没意义)。
	# 重复模式(其他纹理):按 ground_tile_size 格数重复铺,默认每张 5m×5m 一格,显示平铺控件给 GM 调。
	var is_fill: bool = base_name == DEFAULT_GROUND_TEX_BASE
	_tile_control_area.visible = not is_fill
	if is_fill:
		# 铺满模式:ground_tile_size 不参与 UV(见 _ground_uv_scale),存个占位值随场景存盘即可
		ground_tile_size = 0.0
	else:
		ground_tile_size = 5.0
	# 同步平铺控件值(不触发 value_changed 递归)
	if _tile_slider != null:
		_tile_slider.set_value_no_signal(ground_tile_size)
	if _tile_spinbox != null:
		_tile_spinbox.set_value_no_signal(ground_tile_size)
	# 把"用了哪套纹理"写进内容层 SceneProps,随场景存盘(修 bug1)。
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		_content_root.ground_tex_base = base_name
		_content_root.ground_tex_source = source
		_content_root.ground_tile = ground_tile_size
	_mark_scene_dirty()
	_apply_ground_texture()


func _on_tile_changed(value: float) -> void:
	if not _has_editable_scene():
		return
	ground_tile_size = value
	# 滑条和数字框双向同步，锁住递归
	if _tile_slider.value != value:
		_tile_slider.set_value_no_signal(value)
	if _tile_spinbox.value != value:
		_tile_spinbox.set_value_no_signal(value)
	# 把平铺尺寸写进内容层 SceneProps,随场景存盘(修 bug1)。
	if is_instance_valid(_content_root) and _content_root.get_script() != null:
		_content_root.ground_tile = value
	_mark_scene_dirty()
	_apply_ground_texture()
	_tool_label.text = "地面平铺：%.1f 格" % value
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 算当前地面贴图的 UV 平铺缩放(Vector3，前两维给 uv1_scale.x/y)。
## 两种模式:
##   - 铺满模式(默认贴图):一张图永远铺满整个地面,场景变长方形/改大小贴图都跟着拉伸。
##     UV 缩放 = 场景宽高(一张图覆盖整个地面,不重复)。依据:uv1_scale 是 UV 坐标乘数,
##     scale=尺寸时整张贴图被映射到 [0,尺寸] 即整个 PlaneMesh(gdd_0407 StandardMaterial3D.uv1_scale)。
##   - 重复模式(其他纹理):按 ground_tile_size 格数重复铺(一张图覆盖 tile_size 米,场景大就重复多次)。
##     UV 缩放 = 尺寸 / tile_size。
## base = 当前纹理组名; w/h = 场景真实宽高; tile = 平铺格数。
func _ground_uv_scale(base: String, w: float, h: float, tile: float) -> Vector3:
	if base == DEFAULT_GROUND_TEX_BASE:
		# 默认贴图:一张铺满整个地面,场景变长方形/改大小都跟着 PlaneMesh 拉伸。
		# uv1_scale=(1,1) 让贴图整张映射到 PlaneMesh 的 [0,1] UV 范围(整个平面),
		# PlaneMesh size 变了 UV 范围不变,贴图自动跟着拉伸铺满。
		# 依据:gdd_0864 BaseMaterial3D.uv1_scale="UV 坐标乘以这个值",PlaneMesh 默认 UV=[0,1]。
		# (此前误写成 Vector3(w,h) → UV 变 [0,w]×[0,h] 贴图重复 w×h 次,是重复不是铺满,已修)
		return Vector3(1.0, 1.0, 1.0)
	return Vector3(1.0 / tile * w, 1.0 / tile * h, 1.0)


func _apply_ground_texture() -> void:
	if _ground == null or not is_instance_valid(_ground):
		return
	var g: MeshInstance3D = _ground
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	_apply_texture_set(_active_ground_ts, mat)
	var requested_base: String = _active_ground_ts.get("_base", "")
	if requested_base != "" and mat.albedo_texture == null:
		push_error("地面纹理材质绑定失败: %s" % requested_base)
	# UV 平铺:默认贴图铺满拉伸,其他纹理按 ground_tile_size 重复。
	# 场景真实宽高从 _content_root 的 SceneProps 读(点纹理按钮时不改尺寸,读当前存值)。
	var w: float = _current_scene_width()
	var h: float = _current_scene_height()
	mat.uv1_scale = _ground_uv_scale(_active_ground_ts.get("_base", ""), w, h, ground_tile_size)
	g.set_surface_override_material(0, mat)


## 切场景读回后按"纹理组名 + 平铺尺寸"重建地面材质上到骨架 Ground。
## 修 bug1:每场景纹理独立。base=""=没贴纹理用裸色(ground_color);否则按组名在
## _ground_sets 里找对应那套 ts。tile=平铺尺寸。同步左栏平铺控件值(不触发递归)。
func _apply_ground_texture_for_scene(
		base: String,
		tile: float,
		source: String = ""
) -> void:
	ground_tile_size = tile
	var found_ts: Dictionary = _find_ground_texture_set(base, source)
	_active_ground_ts = found_ts
	# 旧存档没有来源字段。恢复成功后回写真正来源，下次保存时自动升级。
	if (
			not found_ts.is_empty()
			and is_instance_valid(_content_root)
			and _content_root.get_script() != null
	):
		_content_root.ground_tex_source = found_ts.get("source", "")
	# 同步左栏平铺控件(不触发 value_changed 递归)
	if _tile_slider != null:
		_tile_slider.set_value_no_signal(tile)
	if _tile_spinbox != null:
		_tile_spinbox.set_value_no_signal(tile)
	if _tile_control_area != null:
		# 平铺控件只在"重复模式"(非默认贴图)显示;没贴纹理 或 默认贴图(铺满模式)都藏。
		_tile_control_area.visible = (base != "" and base != DEFAULT_GROUND_TEX_BASE)
	_apply_ground_texture()


func _find_ground_texture_set(base: String, source: String = "") -> Dictionary:
	if base == "":
		return {}
	if source == "" or source == "builtin":
		for builtin_set: Dictionary in _ground_sets:
			if builtin_set.get("_base", "") == base:
				var result: Dictionary = builtin_set.duplicate()
				result["source"] = "builtin"
				return result
	if source == "" or source == "imported":
		var imported_sets: Array[Dictionary] = LibraryManager.scan_ground_textures()
		for imported_set: Dictionary in imported_sets:
			if imported_set.get("_base", "") == base:
				return imported_set
	return {}


func _on_test_btn_pressed() -> void:
	if not _has_editable_scene() or not ModeGate.is_edit():
		return
	var test_result: Dictionary = _scene_session_controller.begin_test_run()
	if int(test_result.get("error", FAILED)) != OK:
		_show_playthrough_error(test_result, "进入测试失败")
		return
	ModeGate.switch_to(ModeGate.AppMode.RUN)
	_tool_label.text = "测试中"
	_tool_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))


func _on_mode_btn_pressed() -> void:
	if not _has_editable_scene():
		return
	if ModeGate.is_edit():
		if _playthrough_controller.is_session_active():
			ModeGate.switch_to(ModeGate.AppMode.RUN)
		else:
			_show_playthrough_dialog()
	elif _scene_session_controller.is_test_run_active():
		var test_result: Dictionary = _scene_session_controller.end_test_run()
		if int(test_result.get("error", FAILED)) != OK:
			_show_playthrough_error(test_result, "结束测试失败")
			return
		ModeGate.switch_to(ModeGate.AppMode.EDIT)
		_tool_label.text = "测试已结束"
		_tool_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		var leave_result: Dictionary = _playthrough_controller.leave_session_for_edit()
		if int(leave_result.get("error", FAILED)) != OK:
			_show_playthrough_error(leave_result, "返回编辑态失败")
			return
		ModeGate.switch_to(ModeGate.AppMode.EDIT)


# —— 子模式切换 / 保存视角 / 恢复视角 ——
func _on_sub_btn_pressed() -> void:
	if not _has_editable_scene():
		return
	# 在 地图 ↔ 自由视角 之间切。两态都能按。真值交给 ModeGate。
	if ModeGate.is_sub_map():
		ModeGate.switch_edit_sub_mode(ModeGate.EditSubMode.ORBIT)
	else:
		ModeGate.switch_edit_sub_mode(ModeGate.EditSubMode.MAP)


func _on_save_view_pressed() -> void:
	# 编辑态专用:把当前自由视角四量存为"游玩视角"权威(saved)。
	# 之后切运行态自动套用、运行态"恢复视角"也回到这套。
	_camera_view_controller.save_play_view()
	_tool_label.text = "已保存游玩视角"
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _on_restore_view_pressed() -> void:
	# 运行态专用:GM 临场转飘了,一按回到 saved 的游玩视角。
	_camera_view_controller.restore_play_view()
	_tool_label.text = "已恢复游玩视角"
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


# —— 投屏开关 ——
# 投屏窗口旁路于 ModeGate(见 docs/architecture.md 3.6),编辑/运行两态都能按。
# 本地窗口,不联网;腾讯会议可「只共享这个窗口」。
func _on_cast_btn_pressed() -> void:
	if not _has_editable_scene():
		return
	if _player_output_controller == null or not is_instance_valid(_player_output_controller):
		return
	if _player_output_controller.is_open():
		_player_output_controller.close_output()
		_cast_btn.text = "投屏 ⧉"
		_tool_label.text = "投屏已关闭"
		_tool_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		var open_result: Dictionary = _player_output_controller.open_output()
		if int(open_result.get("error", FAILED)) != OK:
			_tool_label.text = String(open_result.get("message", "投屏窗口打开失败"))
			_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			return
		_cast_btn.text = "停止投屏"
		_tool_label.text = "投屏窗口已开（玩家视角）"
		_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _on_player_output_requested(
	_request_id: int,
	_kind: int,
	_content_id: String
) -> void:
	_hide_gm_media_surface()


func _on_player_output_changed(kind: int, content_id: String) -> void:
	_sync_gm_media_surface(kind)
	if _cast_btn != null:
		_cast_btn.text = "投屏 ⧉" if kind == PlayerOutputController.OutputKind.NONE else "停止投屏"
	if _media_return_map_button != null:
		_media_return_map_button.disabled = (
			kind != PlayerOutputController.OutputKind.IMAGE
			and kind != PlayerOutputController.OutputKind.VIDEO
			and kind != PlayerOutputController.OutputKind.TEXT
		)
	_sync_media_video_controls(kind, _player_output_controller.phase)
	match kind:
		PlayerOutputController.OutputKind.NONE:
			_media_output_error_active = false
			_set_media_output_status("投屏：未打开", Color(0.65, 0.65, 0.65))
		PlayerOutputController.OutputKind.MAP:
			if not _media_output_error_active:
				_set_media_output_status("投屏：地图", Color(0.3, 0.8, 0.3))
		PlayerOutputController.OutputKind.IMAGE:
			_media_output_error_active = false
			var image_content: ExternalContentRef = _find_media_content(content_id)
			var image_name: String = image_content.display_name if image_content != null else "已登记图片"
			_set_media_output_status("投屏：图片 · " + image_name, Color(0.3, 0.8, 0.3))
		PlayerOutputController.OutputKind.VIDEO:
			_media_output_error_active = false
			var video_content: ExternalContentRef = _find_media_content(content_id)
			var video_name: String = video_content.display_name if video_content != null else "已登记视频"
			_set_media_output_status("投屏：视频 · " + video_name, Color(0.3, 0.8, 0.3))
		PlayerOutputController.OutputKind.TEXT:
			_media_output_error_active = false
			var text_name: String = (
				_act_library_panel.get_item_display_name(content_id)
				if _act_library_panel != null
				else "幕内文字"
			)
			_set_media_output_status("投屏：文字 · " + text_name, Color(0.3, 0.8, 0.3))


func _on_video_playback_changed(phase_value: int) -> void:
	var kind: int = (
		_player_output_controller.active_kind
		if _player_output_controller != null
		else PlayerOutputController.OutputKind.NONE
	)
	_sync_media_video_controls(kind, phase_value)
	if kind != PlayerOutputController.OutputKind.VIDEO:
		return
	var content: ExternalContentRef = _find_media_content(_player_output_controller.active_content_id)
	var video_name: String = content.display_name if content != null else "已登记视频"
	if phase_value == PlayerOutputController.OutputPhase.PAUSED:
		_set_media_output_status("投屏：视频已暂停 · " + video_name, Color(0.95, 0.65, 0.2))
	elif phase_value == PlayerOutputController.OutputPhase.PLAYING:
		_set_media_output_status("投屏：视频 · " + video_name, Color(0.3, 0.8, 0.3))


func _sync_media_video_controls(kind: int, phase_value: int) -> void:
	var controllable: bool = (
		kind == PlayerOutputController.OutputKind.VIDEO
		and (
			phase_value == PlayerOutputController.OutputPhase.PLAYING
			or phase_value == PlayerOutputController.OutputPhase.PAUSED
		)
	)
	if _media_video_pause_button != null:
		_media_video_pause_button.disabled = not controllable
		_media_video_pause_button.text = (
			"继续" if phase_value == PlayerOutputController.OutputPhase.PAUSED else "暂停"
		)
	if _media_video_stop_button != null:
		_media_video_stop_button.disabled = not controllable


func _on_video_volume_changed(volume_linear: float) -> void:
	if _media_volume_label != null:
		_media_volume_label.text = "音量 %d%%" % roundi(volume_linear * 100.0)


func _on_player_output_failed(
		_request_id: int,
		content_id: String,
		_error: int,
		message: String
) -> void:
	var content: ExternalContentRef = _find_media_content(content_id)
	var media_name: String = "已登记媒体"
	if content != null:
		media_name = content.display_name
	elif _act_library_panel != null:
		media_name = _act_library_panel.get_item_display_name(content_id)
	_set_media_output_error("媒体演出失败：%s（%s）" % [media_name, message])


func _set_media_output_error(message: String) -> void:
	_media_output_error_active = true
	_set_media_output_status(message, Color(0.9, 0.3, 0.3))
	if _tool_label != null:
		_tool_label.text = message
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _set_media_output_status(message: String, color: Color) -> void:
	if _media_output_status_label == null or not is_instance_valid(_media_output_status_label):
		return
	_media_output_status_label.text = message
	_media_output_status_label.add_theme_color_override("font_color", color)


func _on_edit_sub_mode_changed(_sub: ModeGate.EditSubMode) -> void:
	# 子模式变了:刷新顶栏按钮文字 + 重算相机(正交↔透视)。
	_apply_topbar_for_mode(ModeGate.current())
	_apply_camera_for_mode(ModeGate.current())


func _on_mode_changed(mode: ModeGate.AppMode) -> void:
	# 只做协调：每个跨态功能自己关自己的开关，互不干扰。
	if mode == ModeGate.AppMode.RUN:
		_close_playthrough_dialog()
	_record_application_contract_step("mode_change:begin")
	_cancel_pointer_gestures()
	_record_application_contract_step("mode_change:pointer")
	_deselect()
	_record_application_contract_step("mode_change:selection")
	_apply_topbar_for_mode(mode)
	_record_application_contract_step("mode_change:topbar")
	_apply_panel_for_mode(mode)
	_record_application_contract_step("mode_change:panel")
	_apply_camera_for_mode(mode)
	_record_application_contract_step("mode_change:camera")
	_apply_gizmo_for_mode(mode)
	_record_application_contract_step("mode_change:gizmo")
	_apply_wall_state_for_mode(mode)
	_record_application_contract_step("mode_change:walls")
	_apply_token_drag_for_mode(mode)
	_record_application_contract_step("mode_change:token_drag")
	_apply_pick_proxy_markers_for_mode(mode)
	_record_application_contract_step("mode_change:pick_proxy")
	_sync_scene_list()
	_sync_module_context_ui()
	_record_application_contract_step("mode_change:end")


# —— 功能自报归属规矩示范 ——
# 每个跨态功能写一个自己的 _apply_xxx_for_mode(mode)，只管自己那一摊。
# 新加功能（Token/光源/破坏）照此各加一个，不准把开关逻辑堆进 _on_mode_changed。

func _apply_topbar_for_mode(mode: ModeGate.AppMode) -> void:
	_main_ui_controller.apply_topbar_for_mode(mode, _camera_view_controller.is_map_view())
	if _mode_label != null and is_instance_valid(_mode_label) and mode == ModeGate.AppMode.RUN:
		_mode_label.text = "测试中" if _scene_session_controller.is_test_run_active() else "记录中"
	_sync_playthrough_entry_ui()


func _apply_panel_for_mode(mode: ModeGate.AppMode) -> void:
	_main_ui_controller.apply_panel_for_mode(mode)
	if _left_panel != null and is_instance_valid(_left_panel):
		_left_panel.visible = true
	for section: Dictionary in _panel_sections:
		var separator: Control = section.get("separator") as Control
		var button: Button = section.get("button") as Button
		var content: Control = section.get("content") as Control
		var runtime_visible: bool = bool(section.get("runtime_visible", false))
		if mode == ModeGate.AppMode.RUN and content != null:
			section["edit_content_visible"] = content.visible
		if separator != null and is_instance_valid(separator):
			separator.visible = mode == ModeGate.AppMode.EDIT or runtime_visible
		if button != null and is_instance_valid(button):
			button.visible = mode == ModeGate.AppMode.EDIT or runtime_visible
		if content != null and is_instance_valid(content):
			content.visible = (
				bool(section.get("edit_content_visible", content.visible))
				if mode == ModeGate.AppMode.EDIT
				else runtime_visible
			)
		if button != null and content != null:
			button.text = ("▼ " if content.visible else "▶ ") + String(section.get("title", ""))
	if _media_edit_row != null and is_instance_valid(_media_edit_row):
		_media_edit_row.visible = mode == ModeGate.AppMode.EDIT
	if _act_library_panel != null and is_instance_valid(_act_library_panel):
		_act_library_panel.apply_mode(mode)


## 全场唯一共享 gizmo(单选模式)。左键点中物件 → clear+select 目标;
## 点空白 → clear_selection(手柄全没)。与 Godot 编辑器/Blender 的"点哪个
## 出现哪个"单选做法一致(一套手柄绑当前 active 物件)。多选(Shift 加选)暂不做。
var _gizmo: Gizmo3D = null

func _apply_gizmo_for_mode(mode: ModeGate.AppMode) -> void:
	# 编辑态开放完整变换手柄；运行态 mode=0，只保留选中框。
	if _gizmo == null or not is_instance_valid(_gizmo):
		return
	_gizmo.clear_selection()
	_gizmo.mode = Gizmo3D.ToolMode.ALL if mode == ModeGate.AppMode.EDIT else 0
	_gizmo.show_axes = mode == ModeGate.AppMode.EDIT
	_gizmo.show_selection_box = true
	_gizmo.set_process(true)
	_gizmo.visible = false


func _apply_wall_state_for_mode(mode: ModeGate.AppMode) -> void:
	if _content_root == null or not is_instance_valid(_content_root):
		return
	_apply_wall_state_for_mode_recursive(
		_content_root,
		mode == ModeGate.AppMode.EDIT
	)


func _apply_wall_state_for_mode_recursive(
		node: Node,
		show_destroyed_visual: bool
) -> void:
	if node is Node3D:
		var root: Node3D = node as Node3D
		var properties: EntityProperties = _get_entity_properties(root)
		if (
			properties != null
			and properties.get_effective_entity_type() == EntityProperties.EntityType.WALL
		):
			_wall_state_controller.sync_wall(root, show_destroyed_visual)
	for child: Node in node.get_children():
		_apply_wall_state_for_mode_recursive(child, show_destroyed_visual)


func _apply_token_drag_for_mode(mode: ModeGate.AppMode) -> void:
	if mode == ModeGate.AppMode.EDIT:
		_clear_runtime_token_drag()
		_destroy_movement_service()
		_restore_runtime_token_edit_snapshot()
		return
	_capture_runtime_token_edit_snapshot()
	if not _rebuild_movement_service():
		_tool_label.text = "移动导航生成失败"
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _apply_pick_proxy_markers_for_mode(mode: ModeGate.AppMode) -> void:
	if _content_root == null or not is_instance_valid(_content_root):
		return
	var marker_visible: bool = mode == ModeGate.AppMode.EDIT
	_set_pick_proxy_markers_visible_recursive(_content_root, marker_visible)


func _set_pick_proxy_markers_visible_recursive(node: Node, marker_visible: bool) -> void:
	if node is PickProxy:
		var proxy: PickProxy = node as PickProxy
		proxy.set_edit_visible(marker_visible)
	for child: Node in node.get_children():
		_set_pick_proxy_markers_visible_recursive(child, marker_visible)


func _input(event: InputEvent) -> void:
	if (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
	):
		var left_press: InputEventMouseButton = event as InputEventMouseButton
		_latest_left_press_position = left_press.position
	if (
			ModeGate.is_run()
			and (
				_pointer_controller.is_runtime_token_candidate()
				or _pointer_controller.is_runtime_token_drag()
			)
	):
		var runtime_target: Node3D = _pointer_controller.get_runtime_token_target()
		if runtime_target == null or not is_instance_valid(runtime_target):
			_clear_runtime_pointer_candidate()
			_clear_runtime_token_drag()
			return
		if (
				event is InputEventMouseButton
				and event.button_index == MOUSE_BUTTON_LEFT
				and not event.pressed
		):
			if _pointer_controller.is_runtime_token_drag():
				_finish_runtime_token_drag()
			else:
				_select_entity(runtime_target)
			_clear_runtime_pointer_candidate()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseMotion:
			var token_motion: InputEventMouseMotion = event as InputEventMouseMotion
			if _pointer_controller.is_runtime_token_drag():
				_update_runtime_token_drag(token_motion.position)
			elif _runtime_pointer_exceeded_drag_threshold(token_motion.position):
				var drag_target: Node3D = runtime_target
				if _begin_runtime_token_drag(drag_target, token_motion.position):
					_select_entity_for_runtime_token_drag(drag_target)
				else:
					_select_entity(drag_target)
					_clear_runtime_pointer_candidate()
			get_viewport().set_input_as_handled()
			return
	if (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and not event.pressed
	):
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		var mouse_pos: Vector2 = mouse_event.position
		if _pointer_controller.is_model_drag():
			_finish_model_drag(mouse_pos)
			return
		if _pointer_controller.is_model_candidate():
			_finish_model_pointer_candidate(mouse_pos)
			return
	if (
			event is InputEventMouseMotion
			and (
				_pointer_controller.is_model_drag()
				or _pointer_controller.is_model_candidate()
			)
	):
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if _pointer_controller.is_model_drag():
			_update_drag_preview(motion_event.position)
		elif _model_pointer_exceeded_drag_threshold(motion_event.position):
			_begin_model_drag(motion_event.position)
		return
	# 右键菜单：最先处理。右键按下 + 鼠标在左栏 → 弹删除菜单，标记已处理（不转相机）。
	# 必须在下面"右键转相机"逻辑之前，否则右键按下会被转相机抢走、菜单弹不出。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var right_press: InputEventMouseButton = event as InputEventMouseButton
		if _main_ui_controller.is_over_left_panel(right_press.position):
			_handle_right_click_menu(right_press.position)
			get_viewport().set_input_as_handled()
			return
	# 滚轮缩放:两个子模式都吃滚轮,但意义不同。
	# 地图模式调整正交视野范围；自由视角调整轨道距离。
	if event is InputEventMouseButton and event.pressed:
		var wheel_up: bool = event.button_index == MOUSE_BUTTON_WHEEL_UP
		var wheel_dn: bool = event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		if wheel_up or wheel_dn:
			var dir: float = -1.0 if wheel_up else 1.0   # 向上滚=拉近
			# 等比缩放:每滚一格乘 1.12(~12%变化),比例手感全程一致。
			# 线性加减(+=常数)的毛病:近处一跳巨大、远处几乎不动。
			_camera_view_controller.zoom(dir)
			return
	# 中键/右键按下:记下"开始拖拽"标记和起始鼠标位置(用 event.position 差分)。
	# 鼠标在左栏面板上时不抢右键/中键——让 UI 自己处理（右键弹删除菜单）。
	if event is InputEventMouse and _main_ui_controller.is_over_left_panel(event.position):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_pointer_controller.begin_camera_orbit(event.position)
		elif _pointer_controller.is_camera_orbit():
			_pointer_controller.reset()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			_pointer_controller.begin_camera_pan(event.position)
		elif _pointer_controller.is_camera_pan():
			_pointer_controller.reset()
		return
	# 鼠标拖动位移:用 event.relative(每帧增量,文档原文推荐用法)。
	# Windows 松键会发假 motion(relative=0),用差分天然不受影响。
	if event is InputEventMouseMotion:
		_handle_orbit_mouse_motion(event)


func _handle_orbit_mouse_motion(event: InputEventMouseMotion) -> void:
	# 地图模式:中键拖=平移相机焦点(在地面平面挪)。
	# 自由视角:右键拖=转 yaw/pitch,中键拖=平移 focus(用相机自身朝向投影)。
	_pointer_controller.update_camera_position(event.position)
	if ModeGate.is_sub_map():
		if _pointer_controller.is_camera_pan():
			# 符号修正(2026-07-14):鼠标往哪拖画面往哪走(直接操纵感)。
			# 地图模式下鼠标右→画面右→相机左移→focus 减小,故用 -=。
			_camera_view_controller.pan(event.relative)
		return
	# 自由视角
	if _pointer_controller.is_camera_orbit():
		# 按屏幕高度归一化(社区踩坑提醒:否则不同分辨率手感不一致)。
		# 符号修正(2026-07-14):鼠标往右拖→画面右转(直接操纵感),yaw 减小。
		_camera_view_controller.orbit(event.relative)
	elif _pointer_controller.is_camera_pan():
		# 平移 = 沿相机右方向 + 相机前方向(投影到地面)移动焦点,距离越远移得越多。
		_camera_view_controller.pan(event.relative)


func _unhandled_input(event: InputEvent) -> void:
	if ModeGate.is_run():
		if (
				event is InputEventKey
				and event.pressed
				and not event.echo
				and event.keycode == KEY_ESCAPE
		):
			if _unlock_combat_line_preview() or _exit_combat_aim_mode():
				get_viewport().set_input_as_handled()
				return
		if (
				event is InputEventMouseButton
				and event.button_index == MOUSE_BUTTON_LEFT
				and event.pressed
		):
			var runtime_press: InputEventMouseButton = event as InputEventMouseButton
			if _pointer_controller.should_block_entity_selection():
				_toggle_combat_line_lock()
				get_viewport().set_input_as_handled()
				return
			var runtime_target: Node3D = _pick_entity_at_screen_position(runtime_press.position)
			if runtime_target == null:
				if not _toggle_combat_line_lock():
					_deselect()
			elif _can_runtime_move_token(runtime_target):
				_pointer_controller.begin_runtime_token_candidate(
					runtime_target, runtime_press.position)
			else:
				_select_entity(runtime_target)
			get_viewport().set_input_as_handled()
		return
	# 放置/选中/删除是编辑态专属操作。
	# 权限真值由 ModeGate 持有，不再用本地 current_mode 变量。
	# 缩放选中物件：] / = 放大， [ / - 缩小，三轴等比改根节点 scale。
	# 删除选中物件：Backspace / Delete / X 任一键按下触发。
	# 安全点：GM 在属性面板"名字"输入框打字时按退格/X是删字，不能删物件——
	# 用 gui_get_focus_owner 拿当前焦点控件，是输入类控件则不响应（文档 gdd_0774 第1341行）。
	# 键码常量依据 gdd_1591 @GlobalScope。
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _unlock_combat_line_preview() or _exit_combat_aim_mode():
				get_viewport().set_input_as_handled()
				return
		if event.keycode in [KEY_BRACKETRIGHT, KEY_EQUAL]:
			if _can_scale_selected():
				_scale_selected_uniform(SELECTED_SCALE_STEP)
				get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_BRACKETLEFT, KEY_MINUS]:
			if _can_scale_selected():
				_scale_selected_uniform(1.0 / SELECTED_SCALE_STEP)
				get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_BACKSPACE, KEY_DELETE, KEY_X]:
			if _can_delete_selected():
				_delete_selected()
			return
	if _pointer_controller.is_model_drag() or _pointer_controller.is_model_candidate():
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var edit_press: InputEventMouseButton = event as InputEventMouseButton
	var screen_position: Vector2 = edit_press.position
	if _main_ui_controller.is_over_left_panel(screen_position):
		return
	if _main_ui_controller.is_over_property_panel(screen_position):
		return
	if _pointer_controller.should_block_entity_selection():
		_toggle_combat_line_lock()
		get_viewport().set_input_as_handled()
		return
	# 左键的两种含义:选了仓库物件 → 放置;没选 → 选中已放物件弹属性面板。
	var active: Dictionary = _get_active_model_item()
	if not active.is_empty():
		_place_model(active["category"], active["index"], true, screen_position)
	else:
		var edit_target: Node3D = _pick_entity_at_screen_position(screen_position)
		if edit_target == null and _toggle_combat_line_lock():
			get_viewport().set_input_as_handled()
		else:
			_try_select_at_mouse(screen_position)


## 判断当前能不能删选中物件：得有控制器选中对象，且焦点不在输入类控件上
## （GM 在名字框打字时按退格是删字不是删物件）。输入类控件：LineEdit/TextEdit/SpinBox
## 都能接收键盘输入。依据 gdd_0774 Viewport.gui_get_focus_owner(第1341行)。
func _can_delete_selected() -> bool:
	var target: Node3D = _get_selected_target()
	if target == null:
		return false
	if _is_text_input_focused():
		return false
	return true


func _can_scale_selected() -> bool:
	if not ModeGate.is_edit():
		return false
	if _pointer_controller.is_model_drag() or _pointer_controller.is_model_candidate():
		return false
	if _is_text_input_focused():
		return false
	var target: Node3D = _get_selected_target()
	return target != null and is_instance_valid(target)


func _is_text_input_focused() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner()
	return focus != null and (focus is LineEdit or focus is TextEdit or focus is SpinBox)


func _scale_selected_uniform(factor: float) -> void:
	var target: Node3D = _get_selected_target()
	if target == null or not is_instance_valid(target):
		return
	var current_scale: Vector3 = target.scale
	var next_scale: Vector3 = current_scale * factor
	next_scale.x = clampf(next_scale.x, SELECTED_SCALE_MIN, SELECTED_SCALE_MAX)
	next_scale.y = clampf(next_scale.y, SELECTED_SCALE_MIN, SELECTED_SCALE_MAX)
	next_scale.z = clampf(next_scale.z, SELECTED_SCALE_MIN, SELECTED_SCALE_MAX)
	if next_scale.is_equal_approx(current_scale):
		return
	target.scale = next_scale
	_refresh_selection_views()
	_mark_scene_dirty()
	_tool_label.text = "已缩放：" + str(target.name)
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 删除当前选中物件：从内容层摘下并释放 → 清手柄 → 关属性面板 → 置脏（场景有改动）。
## 选中真值在 SelectionController。删后选中清空。
func _delete_selected() -> void:
	var target: Node3D = _get_selected_target()
	if target == null:
		return
	# 先清选中状态（手柄/属性面板），免得释放节点后引用悬空
	_deselect()
	# 从父节点摘下并释放。物件挂在 _content_root 下（_place_building 里 add_child 的）
	target.get_parent().remove_child(target)
	target.queue_free()
	_mark_scene_dirty()
	_tool_label.text = "已删除物件"
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


## 右键在素材按钮上弹"删除"菜单。
## 用 gui_get_hovered_control 拿鼠标下的控件（文档 gdd_0774 第1349行），
## 沿父链找带 "kind" meta 的按钮（hovered 可能是按钮的图标/文字子控件），
## 读 meta 知道删哪个素材。自带素材"删除"灰掉——res:// 打包后只读。
## 用坐标命中检测找按钮（不靠 gui_get_hovered_control——实测在本项目窗口配置下
## 返回 null）。遍历所有素材按钮，鼠标坐标落在哪个按钮的矩形里就弹那个的菜单。
## 跟左键放置判 _left_panel 矩形同源，已被验证可靠。
func _handle_right_click_menu(mouse_pos: Vector2) -> void:
	var mp: Vector2 = mouse_pos
	# 遍历模型栏位所有按钮，找鼠标命中的那个
	for category: String in _model_panelss:
		var panel: Dictionary = _model_panelss[category]
		var container: VBoxContainer = panel["container"]
		for c: Node in container.get_children():
			if not (c is Button) or not c.has_meta("kind"):
				continue
			if c.get_global_rect().has_point(mp):
				_popup_delete_menu_model(c, category, c.get_meta("index"))
				return
	# 地面纹理栏按钮
	if _ground_list_container != null:
		for c: Node in _ground_list_container.get_children():
			if not (c is Button) or not c.has_meta("kind"):
				continue
			if c.get_global_rect().has_point(mp):
				_popup_delete_menu_ground(c, c.get_meta("group"), c.get_meta("source"))
				return


## 给命中的模型按钮弹删除菜单。
func _popup_delete_menu_model(_btn: Button, category: String, index: int) -> void:
	var is_imported: bool = _model_panelss[category]["items"][index]["source"] == "imported"
	var menu: PopupMenu = PopupMenu.new()
	add_child(menu)
	menu.add_item("删除", 0)
	if not is_imported:
		menu.set_item_disabled(0, true)
		menu.set_item_tooltip(0, "自带素材打包后只读，删不掉")
	else:
		menu.set_item_tooltip(0, "从素材库删除这个模型")
	menu.id_pressed.connect(func(id: int) -> void:
		if id == 0 and is_imported:
			_delete_model_item(category, index)
	)
	menu.close_requested.connect(menu.queue_free)
	# 弹在鼠标位置。用屏幕坐标（DisplayServer.mouse_get_position）——本项目
	# embed_subwindows=false，PopupMenu 是独立 OS 窗口，position 要屏幕坐标；
	# get_viewport().get_mouse_position() 是窗口内局部坐标，会偏到窗口外（曾因此 bug）。
	menu.popup(Rect2(DisplayServer.mouse_get_position(), Vector2.ZERO))


## 给命中的地面纹理按钮弹删除菜单。
func _popup_delete_menu_ground(_btn: Button, group_name: String, source: String) -> void:
	var is_imported: bool = source == "imported"
	var menu: PopupMenu = PopupMenu.new()
	add_child(menu)
	menu.add_item("删除", 0)
	if not is_imported:
		menu.set_item_disabled(0, true)
		menu.set_item_tooltip(0, "自带素材打包后只读，删不掉")
	else:
		menu.set_item_tooltip(0, "删除素材库里的「" + group_name + "」纹理文件夹")
	menu.id_pressed.connect(func(id: int) -> void:
		if id == 0 and is_imported:
			_delete_ground_item(group_name)
	)
	menu.close_requested.connect(menu.queue_free)
	menu.popup(Rect2(DisplayServer.mouse_get_position(), Vector2.ZERO))


## 射线拾取:从鼠标位置射一条线,命中场景里的物件根就选中它。
## 拾取靠物理层 + Area3D(CollisionObject3D._input_event 要求 collision_layer 有位,
## 见 gdd_0554 第 163 行)。放物件时给物件根挂了一个拾取 Area3D(见 _place_building)。
func _update_combat_line_preview() -> void:
	if _combat_line_preview == null or not is_instance_valid(_combat_line_preview):
		return
	if not ModeGate.is_run():
		_pointer_controller.end_combat_aim()
		_combat_line_preview.call("clear_preview")
		return
	var shooter: Node3D = _get_selected_target()
	var properties: EntityProperties = _get_selected_properties()
	if not _pointer_controller.is_combat_aiming_for(shooter):
		_combat_line_preview.call("hide_preview")
		return
	if bool(_combat_line_preview.call("is_locked")):
		if (
				shooter != null
				and properties != null
				and properties.get_effective_entity_type() == EntityProperties.EntityType.TOKEN
				and bool(_combat_line_preview.call("is_locked_for", shooter))
		):
			return
		_combat_line_preview.call("clear_preview")
	if (
			shooter == null
			or properties == null
			or properties.get_effective_entity_type() != EntityProperties.EntityType.TOKEN
			or _is_combat_preview_interaction_blocked()
	):
		_combat_line_preview.call("hide_preview")
		return
	var token_properties: TokenProperties = shooter.get_node_or_null(
		"TokenProperties"
	) as TokenProperties
	if token_properties == null or not token_properties.can_show_aim_line:
		_combat_line_preview.call("hide_preview")
		return
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var aim_origin: Vector3 = _get_entity_combat_aim_point(shooter)
	var aim_direction: Vector3 = _combat_line_preview.call(
		"get_screen_aim_direction", camera, aim_origin, mouse_position
	) as Vector3
	if aim_direction.length_squared() < 0.0001:
		_combat_line_preview.call("hide_preview")
		return
	_combat_line_preview.call(
		"show_aim_guide",
		camera.unproject_position(aim_origin),
		COMBAT_AIM_GUIDE_RADIUS
	)
	_combat_line_preview.call(
		"show_preview",
		shooter,
		aim_origin + aim_direction * COMBAT_AIM_TEST_DISTANCE
	)


func _toggle_combat_line_lock() -> bool:
	if not ModeGate.is_run():
		return false
	if _combat_line_preview == null or not is_instance_valid(_combat_line_preview):
		return false
	if not _pointer_controller.is_combat_aim_active():
		return false
	if bool(_combat_line_preview.call("is_locked")):
		_combat_line_preview.call("unlock")
		_tool_label.text = "战斗线已解除锁定"
		return true
	if _is_combat_preview_interaction_blocked():
		return false
	if not bool(_combat_line_preview.call("lock_current")):
		return false
	_tool_label.text = "战斗线已锁定；右键旋转相机可多角度查看"
	return true


func _unlock_combat_line_preview() -> bool:
	if (
			_combat_line_preview == null
			or not is_instance_valid(_combat_line_preview)
			or not bool(_combat_line_preview.call("is_locked"))
	):
		return false
	_combat_line_preview.call("unlock")
	_tool_label.text = "战斗线已解除锁定"
	return true


func _exit_combat_aim_mode() -> bool:
	if not _pointer_controller.is_combat_aim_active():
		return false
	_pointer_controller.end_combat_aim()
	if _combat_line_preview != null and is_instance_valid(_combat_line_preview):
		_combat_line_preview.call("clear_preview")
	_tool_label.text = "已退出战斗线瞄准"
	return true


func _is_combat_preview_interaction_blocked() -> bool:
	if _gizmo != null and is_instance_valid(_gizmo):
		if _gizmo.editing or _gizmo.hovering:
			return true
	if (
			_pointer_controller.is_model_drag()
			or _pointer_controller.is_model_candidate()
			or _pointer_controller.is_runtime_token_drag()
			or _pointer_controller.is_runtime_token_candidate()
			or _pointer_controller.is_camera_orbit()
			or _pointer_controller.is_camera_pan()
	):
		return true
	return get_viewport().gui_get_hovered_control() != null


func _get_entity_combat_aim_point(entity: Node3D) -> Vector3:
	return CombatLinePreview.get_entity_aim_point(entity)


func _project_screen_to_ground(screen_position: Vector2) -> Variant:
	if camera == null or not is_instance_valid(camera):
		return null
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var ground_plane: Plane = Plane(Vector3.UP, 0.0)
	return ground_plane.intersects_ray(ray_origin, ray_direction)


func _try_select_at_mouse(screen_position: Vector2) -> void:
	var root: Node3D = _pick_entity_at_screen_position(screen_position)
	if root == null:
		_deselect()
		return
	_select_entity(root)


func _pick_entity_at_screen_position(screen_position: Vector2) -> Node3D:
	var from: Vector3 = camera.project_ray_origin(screen_position)
	var to: Vector3 = from + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, 1 << (GvttRenderLayers.PICK_PHYSICS_LAYER - 1))
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hit: Dictionary = space.intersect_ray(params)
	if hit.is_empty():
		return null
	var collider: Object = hit["collider"]
	if not (collider is Area3D):
		return null
	# 命中的 Area3D 是物件根的 PickProxy 或实体物件的拾取代理 → 向上找到物件根。
	return _find_entity_root(collider as Area3D)


func _begin_runtime_token_drag(root: Node3D, screen_position: Vector2) -> bool:
	if not _can_runtime_move_token(root):
		return false
	if _movement_service == null or not is_instance_valid(_movement_service):
		return false
	if not bool(_movement_service.call("begin_preview", root)):
		_tool_label.text = "Token 没有可用移动距离"
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.2))
		return false
	if not _pointer_controller.begin_runtime_token_drag(root):
		_movement_service.call("clear_preview")
		return false
	_runtime_token_drag_has_moved = false
	_update_runtime_token_drag(screen_position)
	_tool_label.text = "拖动选择移动路线"
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	return true


func _runtime_pointer_exceeded_drag_threshold(screen_position: Vector2) -> bool:
	return _pointer_controller.is_runtime_token_drag_threshold_met(screen_position)


func _clear_runtime_pointer_candidate() -> void:
	if _pointer_controller.is_runtime_token_candidate():
		_pointer_controller.reset()


func _cancel_pointer_gestures() -> void:
	_cancel_model_gesture()
	_clear_runtime_pointer_candidate()
	_clear_runtime_token_drag()
	_pointer_controller.reset()
	_pointer_controller.end_combat_aim()
	if _combat_line_preview != null and is_instance_valid(_combat_line_preview):
		_combat_line_preview.call("clear_preview")


func _update_runtime_token_drag(screen_position: Vector2) -> void:
	var drag_target: Node3D = _pointer_controller.get_runtime_token_target()
	if not _pointer_controller.is_runtime_token_drag():
		return
	if drag_target == null or not is_instance_valid(drag_target):
		_clear_runtime_token_drag()
		return
	_pointer_controller.update_runtime_token_position(screen_position)
	if _movement_service == null or not is_instance_valid(_movement_service):
		return
	var preview: Dictionary = _movement_service.call("update_preview", camera, screen_position)
	if preview.is_empty():
		_tool_label.text = "这里没有可达路线"
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.2))
		return
	_runtime_token_drag_has_moved = float(preview["cost"]) > 0.001
	var over_budget: bool = bool(preview["over_budget"])
	_tool_label.text = "路线 %.1f / %.1f 米%s" % [
		float(preview["cost"]),
		float(preview["budget"]),
		"（已截停在范围边界）" if over_budget else "",
	]
	_tool_label.add_theme_color_override(
		"font_color",
		Color(0.95, 0.65, 0.2) if over_budget else Color(0.3, 0.8, 0.3)
	)


func _finish_runtime_token_drag() -> void:
	var committed: bool = false
	if _movement_service != null and is_instance_valid(_movement_service):
		committed = bool(_movement_service.call("commit_preview"))
	if committed and _runtime_token_drag_has_moved:
		_mark_scene_dirty()
		_tool_label.text = "Token 正沿路线移动"
		_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	_clear_runtime_token_drag()


func _clear_runtime_token_drag() -> void:
	if _movement_service != null and is_instance_valid(_movement_service):
		_movement_service.call("clear_preview")
	if _pointer_controller.is_runtime_token_drag():
		_pointer_controller.reset()
	_runtime_token_drag_aim_suppression_target = null
	_runtime_token_drag_has_moved = false


func _get_horizontal_plane_hit(screen_position: Vector2, plane_y: float) -> Dictionary:
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return {}
	var distance: float = (plane_y - origin.y) / direction.y
	if distance <= 0.0:
		return {}
	return {"position": origin + direction * distance}


func _can_runtime_move_token(root: Node3D) -> bool:
	if root == null or not is_instance_valid(root):
		return false
	var props: EntityProperties = _get_entity_properties(root)
	if props == null or props.get_effective_entity_type() != EntityProperties.EntityType.TOKEN:
		return false
	var token_props: Node = root.get_node_or_null("TokenProperties")
	return token_props != null and bool(token_props.get("can_move"))


func _capture_runtime_token_edit_snapshot() -> void:
	_runtime_token_edit_snapshots.clear()
	if _content_root == null or not is_instance_valid(_content_root):
		return
	var pending: Array[Node] = [_content_root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child: Node in current.get_children():
			pending.append(child)
			if not (child is Node3D):
				continue
			var root: Node3D = child as Node3D
			var props: EntityProperties = _get_entity_properties(root)
			if props == null:
				continue
			if props.get_effective_entity_type() != EntityProperties.EntityType.TOKEN:
				continue
			_runtime_token_edit_snapshots.append({
				"token": root,
				"global_transform": root.global_transform,
			})


func _restore_runtime_token_edit_snapshot() -> void:
	for snapshot: Dictionary in _runtime_token_edit_snapshots:
		var token: Node3D = snapshot.get("token", null) as Node3D
		if token == null or not is_instance_valid(token):
			continue
		if not snapshot.has("global_transform"):
			continue
		var saved_transform: Transform3D = snapshot["global_transform"]
		token.global_transform = saved_transform
		token.reset_physics_interpolation()
	_runtime_token_edit_snapshots.clear()


func _rebuild_movement_service() -> bool:
	_destroy_movement_service()
	_movement_rule_provider = _create_movement_rule_provider()
	if _movement_rule_provider == null:
		return false
	_movement_service = _movement_service_script.new() as Node3D
	_movement_service.name = "MovementService"
	_movement_service.set_meta("gvtt_runtime_only", true)
	add_child(_movement_service)
	return bool(_movement_service.call(
		"rebuild",
		_content_root,
		Vector2(_current_scene_width(), _current_scene_height()),
		_movement_rule_provider
	))


func _create_movement_rule_provider() -> MovementRuleProvider:
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	var ruleset_id: StringName = manifest.ruleset_id if manifest != null else &"cpr"
	if ruleset_id == &"cpr":
		return _cpr_movement_rule_provider_script.new() as MovementRuleProvider
	push_warning("没有移动规则提供器: %s" % ruleset_id)
	return _movement_rule_provider_script.new() as MovementRuleProvider


func _destroy_movement_service() -> void:
	if _movement_service != null and is_instance_valid(_movement_service):
		if _movement_service.get_parent() != null:
			_movement_service.get_parent().remove_child(_movement_service)
		_movement_service.queue_free()
	_movement_service = null
	_movement_rule_provider = null
	if _pointer_controller.is_runtime_token_drag():
		_pointer_controller.reset()
	_runtime_token_drag_has_moved = false


## 命中的 Area3D 往上找「挂了 EntityProperties 的物件根」。
func _find_entity_root(area: Area3D) -> Node3D:
	var node: Node = area
	while node != null:
		for c in node.get_children():
			if c is EntityProperties:
				return node as Node3D
		node = node.get_parent()
	return null


func _get_entity_properties(root: Node3D) -> EntityProperties:
	for c: Node in root.get_children():
		if c is EntityProperties:
			return c as EntityProperties
	return null


func _get_selected_target() -> Node3D:
	return _selection_controller.get_current_target()


func _get_selected_properties() -> EntityProperties:
	return _selection_controller.get_current_properties()


func _is_runtime_token_operation_allowed(
		target: Node3D,
		props: EntityProperties
) -> bool:
	return (
		ModeGate.is_run()
		and target != null
		and is_instance_valid(target)
		and props != null
		and props.get_effective_entity_type() == EntityProperties.EntityType.TOKEN
	)


func _is_entity_category(root: Node3D, category: String) -> bool:
	var props: EntityProperties = _get_entity_properties(root)
	return props != null and props.category == category


## 选中某物件根:绑手柄(只有它的手柄出现)+ 弹属性面板绑它的 EntityProperties。
func _select_entity(root: Node3D) -> void:
	if root == null or not is_instance_valid(root):
		_selection_controller.clear()
		return
	var props: EntityProperties = _get_entity_properties(root)
	_selection_controller.select(root, props)
	if (
			_is_runtime_token_operation_allowed(root, props)
			and not _pointer_controller.is_combat_aim_active()
			and not _is_runtime_token_aim_suppressed(root)
	):
		_pointer_controller.begin_combat_aim(root)


func _select_entity_for_runtime_token_drag(root: Node3D) -> void:
	if root == null or not is_instance_valid(root):
		return
	_runtime_token_drag_aim_suppression_target = root
	_pointer_controller.end_combat_aim()
	if _combat_line_preview != null and is_instance_valid(_combat_line_preview):
		_combat_line_preview.call("clear_preview")
	_select_entity(root)


func _is_runtime_token_aim_suppressed(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if (
			_runtime_token_drag_aim_suppression_target == null
			or not is_instance_valid(_runtime_token_drag_aim_suppression_target)
	):
		_runtime_token_drag_aim_suppression_target = null
		return false
	return (
		target == _runtime_token_drag_aim_suppression_target
		and _pointer_controller.is_runtime_token_drag()
	)


func _on_selection_changed(target: Node3D, props: EntityProperties) -> void:
	if _combat_line_preview != null and is_instance_valid(_combat_line_preview):
		_combat_line_preview.call("clear_preview")
	_pointer_controller.end_combat_aim()
	if (
			target != null
			and is_instance_valid(target)
			and props != null
			and props.get_effective_entity_type() == EntityProperties.EntityType.TOKEN
			and _los_service != null
			and is_instance_valid(_los_service)
	):
		_los_service.call("set_token_observer", target)
	if (
			_is_runtime_token_operation_allowed(target, props)
			and not _is_runtime_token_aim_suppressed(target)
	):
		_pointer_controller.begin_combat_aim(target)
	_refresh_selection_views()


func _refresh_selection_views() -> void:
	var root: Node3D = _get_selected_target()
	var props: EntityProperties = _get_selected_properties()
	if root == null:
		if _gizmo != null and is_instance_valid(_gizmo):
			_gizmo.clear_selection()
			_gizmo.show_selection_box = true
		_main_ui_controller.hide_property_panel()
		return
	var entity_type: EntityProperties.EntityType = EntityProperties.EntityType.UNKNOWN
	if props != null:
		entity_type = props.get_effective_entity_type()
	var is_light: bool = entity_type == EntityProperties.EntityType.LIGHT
	if _gizmo != null and is_instance_valid(_gizmo):
		_gizmo.mode = Gizmo3D.ToolMode.ALL if ModeGate.is_edit() else 0
		_gizmo.show_axes = ModeGate.is_edit()
		_gizmo.show_selection_box = not is_light
		_gizmo.set_process(true)
		_gizmo.clear_selection()
		_gizmo.select(root)
	_main_ui_controller.show_property_panel()
	var runtime_selection: bool = ModeGate.is_run()
	_set_prop_panel_runtime_mode(runtime_selection)
	if props == null:
		_prop_title.text = "无属性组件"
		return
	if runtime_selection:
		_populate_runtime_selection_panel(root, props)
		return
	_updating_prop_panel = true
	_prop_title.text = "选中:" + (props.display_name if props.display_name != "" else str(root.name))
	_prop_name_edit.set_text(props.display_name)
	_prop_vis_chk.set_pressed_no_signal(props.visibility == EntityProperties.Visibility.BOTH)
	_prop_los_chk.set_pressed_no_signal(not props.los_occluder)
	_prop_destructible_chk.set_pressed_no_signal(props.destructible)
	_prop_cover_chk.set_pressed_no_signal(props.cover_level == EntityProperties.CoverLevel.FULL)
	_prop_max_hp_spin.set_value_no_signal(props.max_hp)
	var wall_properties: WallProperties = root.get_node_or_null(
		"WallProperties"
	) as WallProperties
	if wall_properties != null:
		_prop_los_chk.set_pressed_no_signal(not wall_properties.blocks_los)
		_prop_destructible_chk.set_pressed_no_signal(wall_properties.destructible)
		_prop_cover_chk.set_pressed_no_signal(wall_properties.blocks_shot)
		_prop_max_hp_spin.set_value_no_signal(wall_properties.durability_max)
	_prop_light_box.visible = is_light
	_prop_vis_chk.visible = not is_light
	_prop_los_chk.visible = not is_light
	_prop_destructible_chk.visible = not is_light
	_prop_cover_chk.visible = not is_light
	_prop_max_hp_row.visible = not is_light
	if is_light:
		_populate_light_editor(root)
	var cpr_properties: Node = root.get_node_or_null("CprTokenProperties")
	_prop_move_row.visible = cpr_properties != null and not is_light
	if cpr_properties != null:
		_prop_move_spin.set_value_no_signal(float(cpr_properties.get("move_stat")))
	var traversal: Node = root.get_node_or_null("TraversalProperties")
	_prop_traversal_row.visible = (
		traversal != null
		and entity_type not in [EntityProperties.EntityType.TOKEN, EntityProperties.EntityType.LIGHT]
	)
	if traversal != null:
		_prop_traversal_option.select(int(traversal.get("traversal_mode")))
	_updating_prop_panel = false


func _set_prop_panel_runtime_mode(runtime_mode: bool) -> void:
	_prop_runtime_box.visible = runtime_mode
	if _prop_runtime_light_toggle_btn != null:
		_prop_runtime_light_toggle_btn.visible = false
	if _prop_runtime_wall_toggle_btn != null:
		_prop_runtime_wall_toggle_btn.visible = false
	for editor_control: Control in _prop_editor_controls:
		editor_control.visible = not runtime_mode


func _populate_light_editor(root: Node3D) -> void:
	var light_properties: Node = root.get_node_or_null("LightProperties")
	if light_properties == null:
		return
	_sync_light_marker(root, light_properties)
	var light_color: Color = light_properties.get("color")
	_prop_light_on_chk.set_pressed_no_signal(bool(light_properties.get("is_on")))
	_prop_light_color_picker.color = light_color
	_prop_light_energy_spin.set_value_no_signal(float(light_properties.get("energy")))
	_prop_light_range_spin.set_value_no_signal(float(light_properties.get("light_range")))
	_prop_light_shadow_chk.set_pressed_no_signal(bool(light_properties.get("casts_shadow")))


func _populate_runtime_selection_panel(root: Node3D, props: EntityProperties) -> void:
	var display_name: String = props.display_name if props.display_name != "" else str(root.name)
	var entity_type: EntityProperties.EntityType = props.get_effective_entity_type()
	_prop_title.text = "选中：" + display_name
	_prop_runtime_type_label.text = "类型：" + _get_entity_type_display_name(entity_type)
	_prop_runtime_status_label.text = "状态：正常"
	_prop_runtime_detail_label.text = ""
	if _prop_runtime_light_toggle_btn != null:
		_prop_runtime_light_toggle_btn.visible = false
	if _prop_runtime_wall_toggle_btn != null:
		_prop_runtime_wall_toggle_btn.visible = false
	match entity_type:
		EntityProperties.EntityType.TOKEN:
			var token_properties: Node = root.get_node_or_null("TokenProperties")
			var can_move: bool = token_properties != null and bool(token_properties.get("can_move"))
			_prop_runtime_status_label.text = "状态：可移动" if can_move else "状态：不可移动"
			var cpr_properties: Node = root.get_node_or_null("CprTokenProperties")
			if cpr_properties != null:
				var move_stat: int = int(cpr_properties.get("move_stat"))
				var budget: float = float(move_stat * 2)
				if _movement_rule_provider != null:
					budget = _movement_rule_provider.get_movement_budget_meters(root)
				_prop_runtime_detail_label.text = "MOVE %d · 预算 %.1f 米" % [move_stat, budget]
		EntityProperties.EntityType.WALL:
			var wall_properties: WallProperties = root.get_node_or_null(
				"WallProperties"
			) as WallProperties
			if wall_properties != null:
				var wall_states: Array[String] = ["完整", "受损", "已破坏"]
				var wall_state: int = clampi(int(wall_properties.wall_state), 0, 2)
				_prop_runtime_status_label.text = "状态：" + wall_states[wall_state]
				_prop_runtime_detail_label.text = "耐久 %d / %d" % [
					wall_properties.durability_current,
					wall_properties.durability_max,
				]
				if _prop_runtime_wall_toggle_btn != null:
					var destroyed: bool = (
						wall_properties.wall_state == WallProperties.WallState.DESTROYED
					)
					_prop_runtime_wall_toggle_btn.visible = true
					_prop_runtime_wall_toggle_btn.disabled = (
						not destroyed and not wall_properties.destructible
					)
					_prop_runtime_wall_toggle_btn.text = (
						"修复墙体" if destroyed else "破坏墙体"
					)
		EntityProperties.EntityType.LIGHT:
			var light_properties: Node = root.get_node_or_null("LightProperties")
			if light_properties != null:
				var existing_light: Light3D = light_properties.call("find_first_light", root) as Light3D
				if existing_light != null:
					light_properties.call("apply_to", root)
				var light_is_on: bool = bool(light_properties.get("is_on"))
				_prop_runtime_status_label.text = (
					"状态：开启" if light_is_on else "状态：关闭"
				)
				_prop_runtime_detail_label.text = "范围 %.1f 米 · 亮度 %.1f" % [
					float(light_properties.get("light_range")),
					float(light_properties.get("energy")),
				]
				if _prop_runtime_light_toggle_btn != null:
					_prop_runtime_light_toggle_btn.visible = true
					_prop_runtime_light_toggle_btn.set_pressed_no_signal(light_is_on)
					_prop_runtime_light_toggle_btn.text = "关闭光源" if light_is_on else "开启光源"
		EntityProperties.EntityType.INTERACTABLE:
			var interactable: Node = root.get_node_or_null("InteractableProperties")
			if interactable != null:
				var interaction_states: Array[String] = ["待机", "已触发", "已禁用"]
				var interaction_state: int = clampi(
					int(interactable.get("interaction_state")), 0, 2)
				_prop_runtime_status_label.text = "状态：" + interaction_states[interaction_state]
				_prop_runtime_detail_label.text = str(interactable.get("interaction_label"))
		_:
			var traversal: Node = root.get_node_or_null("TraversalProperties")
			if traversal != null:
				var traversal_names: Array[String] = [
					"可走", "阻挡", "困难", "攀爬", "跳跃", "游泳",
				]
				var traversal_mode: int = clampi(int(traversal.get("traversal_mode")), 0, 5)
				_prop_runtime_detail_label.text = "通行：" + traversal_names[traversal_mode]


func _get_entity_type_display_name(entity_type: EntityProperties.EntityType) -> String:
	match entity_type:
		EntityProperties.EntityType.TOKEN:
			return "Token（标记）"
		EntityProperties.EntityType.TERRAIN:
			return "地形"
		EntityProperties.EntityType.WALL:
			return "墙体"
		EntityProperties.EntityType.DECOR:
			return "装饰"
		EntityProperties.EntityType.INTERACTABLE:
			return "交互物体"
		EntityProperties.EntityType.LIGHT:
			return "光源"
		_:
			return "未知"


func _on_runtime_light_toggle_pressed() -> void:
	if not ModeGate.is_run():
		return
	var root: Node3D = _get_selected_target()
	var props: EntityProperties = _get_selected_properties()
	if root == null or props == null:
		return
	if props.get_effective_entity_type() != EntityProperties.EntityType.LIGHT:
		return
	var light_properties: Node = root.get_node_or_null("LightProperties")
	if light_properties == null:
		return
	light_properties.call("toggle", root)
	_mark_scene_dirty()
	_populate_runtime_selection_panel(root, props)
	_tool_label.text = "光源已" + ("开启" if bool(light_properties.get("is_on")) else "关闭")
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _on_runtime_wall_toggle_pressed() -> void:
	if not ModeGate.is_run():
		return
	var root: Node3D = _get_selected_target()
	var props: EntityProperties = _get_selected_properties()
	if root == null or props == null:
		return
	if props.get_effective_entity_type() != EntityProperties.EntityType.WALL:
		return
	var wall_properties: WallProperties = root.get_node_or_null(
		"WallProperties"
	) as WallProperties
	if wall_properties == null:
		return
	var changed: bool = false
	if wall_properties.wall_state == WallProperties.WallState.DESTROYED:
		changed = bool(_wall_state_controller.repair_wall(root))
	else:
		changed = bool(_wall_state_controller.destroy_wall(root))
	if not changed:
		return
	var movement_rebuilt: bool = _rebuild_movement_service()
	_mark_scene_dirty()
	_populate_runtime_selection_panel(root, props)
	_tool_label.text = (
		"墙体已修复"
		if wall_properties.wall_state == WallProperties.WallState.INTACT
		else "墙体已破坏"
	)
	if movement_rebuilt:
		_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	else:
		_tool_label.text += "；移动导航生成失败"
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _deselect() -> void:
	_selection_controller.clear()


func _mark_scene_dirty() -> void:
	if ModeGate.is_run():
		_playthrough_controller.mark_runtime_dirty()
		_schedule_playthrough_autosave()
		return
	_scene_dirty = true
	_scene_session_controller.mark_dirty()


func _on_gizmo_transform_end(_mode: int) -> void:
	var target: Node3D = _get_selected_target()
	if target == null:
		return
	target.force_update_transform()
	var combat_node: Node = target.get_node_or_null("CombatBody")
	if combat_node != null:
		combat_node.call("sync_transform_from_target")
	_placement_controller.sync_los_occluder(target)
	_mark_scene_dirty()


# —— 属性面板回写:改控件 → 写回 EntityProperties → 触发投屏可见层同步 ——
func _on_prop_name_changed(new_text: String) -> void:
	var props: EntityProperties = _get_selected_properties()
	var target: Node3D = _get_selected_target()
	if _updating_prop_panel or props == null:
		return
	props.display_name = new_text
	if target != null:
		_prop_title.text = "选中:" + (new_text if new_text != "" else str(target.name))
	_mark_scene_dirty()


func _on_prop_destructible_toggled(pressed: bool) -> void:
	var props: EntityProperties = _get_selected_properties()
	var target: Node3D = _get_selected_target()
	if _updating_prop_panel or props == null:
		return
	props.destructible = pressed
	if target != null:
		var wall_properties: WallProperties = target.get_node_or_null(
			"WallProperties"
		) as WallProperties
		if wall_properties != null:
			wall_properties.destructible = pressed
	_mark_scene_dirty()


## 可透光勾选框回写:勾上=透光→los_occluder=false;勾掉=不透光→los_occluder=true。
## 走 set_los_occluder 统一入口(发信号,将来战争迷雾系统订阅重算)。
func _on_prop_los_toggled(pressed: bool) -> void:
	var props: EntityProperties = _get_selected_properties()
	var target: Node3D = _get_selected_target()
	if _updating_prop_panel or props == null:
		return
	if target != null:
		props.set_los_occluder(target, not pressed)
		var wall_properties: WallProperties = target.get_node_or_null(
			"WallProperties"
		) as WallProperties
		if wall_properties != null:
			wall_properties.set_blocks_los(not pressed)
			_placement_controller.sync_los_occluder(target)
	else:
		props.set_los_occluder(null, not pressed)
	_mark_scene_dirty()


func _on_prop_max_hp_changed(value: float) -> void:
	var props: EntityProperties = _get_selected_properties()
	var target: Node3D = _get_selected_target()
	if _updating_prop_panel or props == null:
		return
	props.max_hp = int(value)
	if target != null:
		var wall_properties: WallProperties = target.get_node_or_null(
			"WallProperties"
		) as WallProperties
		if wall_properties != null:
			wall_properties.durability_max = props.max_hp
			if wall_properties.wall_state != WallProperties.WallState.DESTROYED:
				wall_properties.durability_current = props.max_hp
	_mark_scene_dirty()


func _on_prop_move_changed(value: float) -> void:
	var target: Node3D = _get_selected_target()
	if _updating_prop_panel or target == null:
		return
	var cpr_properties: Node = target.get_node_or_null("CprTokenProperties")
	if cpr_properties == null:
		return
	cpr_properties.set("move_stat", int(value))
	_mark_scene_dirty()


func _on_prop_traversal_selected(index: int) -> void:
	var target: Node3D = _get_selected_target()
	if _updating_prop_panel or target == null:
		return
	var traversal: Node = target.get_node_or_null("TraversalProperties")
	if traversal == null:
		return
	traversal.set("traversal_mode", index)
	_mark_scene_dirty()


func _on_prop_cover_toggled(pressed: bool) -> void:
	var props: EntityProperties = _get_selected_properties()
	var target: Node3D = _get_selected_target()
	if _updating_prop_panel or props == null:
		return
	props.cover_level = EntityProperties.CoverLevel.FULL if pressed else EntityProperties.CoverLevel.NONE
	if target != null:
		var wall_properties: WallProperties = target.get_node_or_null(
			"WallProperties"
		) as WallProperties
		if wall_properties != null:
			wall_properties.cover_level = (
				WallProperties.CoverLevel.FULL if pressed else WallProperties.CoverLevel.NONE
			)
			wall_properties.set_blocks_shot(pressed)
			_placement_controller.sync_combat_body(target)
			_wall_state_controller.sync_wall(target, ModeGate.is_edit())
		else:
			_placement_controller.sync_combat_body(target)
	_mark_scene_dirty()


func _on_prop_vis_toggled(pressed: bool) -> void:
	var props: EntityProperties = _get_selected_properties()
	var target: Node3D = _get_selected_target()
	if _updating_prop_panel or props == null:
		return
	# 勾上=玩家可见(玩家+GM=Visibility.BOTH);勾掉=仅 GM(Visibility.GM_ONLY)。
	props.visibility = EntityProperties.Visibility.BOTH if pressed else EntityProperties.Visibility.GM_ONLY
	# 改可见层 → 同步物件所有 VisualInstance3D 的渲染层 → 投屏相机按 cull_mask 自动筛。
	if target != null:
		props.apply_render_layer_to(target)
	_mark_scene_dirty()


func _get_selected_light_properties() -> Node:
	var props: EntityProperties = _get_selected_properties()
	var target: Node3D = _get_selected_target()
	if props == null or target == null:
		return null
	if props.get_effective_entity_type() != EntityProperties.EntityType.LIGHT:
		return null
	return target.get_node_or_null("LightProperties")


func _apply_selected_light_properties(light_properties: Node) -> void:
	var target: Node3D = _get_selected_target()
	if target == null or light_properties == null:
		return
	light_properties.call("apply_to", target)
	_sync_light_marker(target, light_properties)
	_mark_scene_dirty()


func _sync_light_marker(root: Node3D, light_properties: Node) -> void:
	if root == null or light_properties == null:
		return
	if not bool(root.get_meta("gvtt_builtin_light", false)):
		return
	var proxy_node: Node = root.get_node_or_null("PickProxy")
	if not (proxy_node is PickProxy):
		return
	var proxy: PickProxy = proxy_node as PickProxy
	proxy.set_marker_enabled(true)
	proxy.set_marker_color(light_properties.get("color"))
	proxy.set_edit_visible(ModeGate.is_edit())


func _on_prop_light_on_toggled(pressed: bool) -> void:
	if _updating_prop_panel:
		return
	var light_properties: Node = _get_selected_light_properties()
	if light_properties == null:
		return
	light_properties.set("is_on", pressed)
	_apply_selected_light_properties(light_properties)


func _on_prop_light_color_changed(color: Color) -> void:
	if _updating_prop_panel:
		return
	var light_properties: Node = _get_selected_light_properties()
	if light_properties == null:
		return
	light_properties.set("color", color)
	_apply_selected_light_properties(light_properties)


func _on_prop_light_energy_changed(value: float) -> void:
	if _updating_prop_panel:
		return
	var light_properties: Node = _get_selected_light_properties()
	if light_properties == null:
		return
	light_properties.set("energy", value)
	_apply_selected_light_properties(light_properties)


func _on_prop_light_range_changed(value: float) -> void:
	if _updating_prop_panel:
		return
	var light_properties: Node = _get_selected_light_properties()
	if light_properties == null:
		return
	light_properties.set("light_range", value)
	_apply_selected_light_properties(light_properties)


func _on_prop_light_shadow_toggled(pressed: bool) -> void:
	if _updating_prop_panel:
		return
	var light_properties: Node = _get_selected_light_properties()
	if light_properties == null:
		return
	light_properties.set("casts_shadow", pressed)
	_apply_selected_light_properties(light_properties)


## 放置模型物件（所有模型栏位共用）。按来源分流加载模型实例：
##   builtin（自带）= ResourceLoader.load 拿 PackedScene 再 instantiate（开发时已导入）；
##   imported（导入）= LibraryManager 导入时生成的持久 PackedScene 缓存；
##   旧素材缺缓存时首次使用迁移一次，后续启动和拖动都复用 .scn。
## 后续缩放 + 挂 EntityProperties + PickProxy 两来源共用。
func _place_model(
		category: String,
		index: int,
		use_surface_snap: bool = false,
		mouse_pos: Vector2 = Vector2.INF
) -> void:
	if not _has_editable_scene():
		return
	var item: Dictionary = _model_panelss[category]["items"][index]
	var path: String = item["path"]
	var result: Dictionary = _placement_controller.place_model(
		category, index, use_surface_snap, mouse_pos
	)
	if result.is_empty():
		return
	if result.get("error", "") == "load_failed":
		_tool_label.text = "模型加载失败：" + path.get_file()
		_tool_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return
	var placed_root: Node3D = result.get("root", null) as Node3D
	_mark_scene_dirty()
	_clear_all_model_selections()
	if placed_root != null and is_instance_valid(placed_root):
		_select_entity(placed_root)
	if result.get("snapped_to_wall", false):
		_tool_label.text = "已吸附到墙面：" + path.get_file().get_basename()
	else:
		var placed_label: String = result.get("label", path.get_file().get_basename())
		_tool_label.text = "已放置：" + placed_label
	_tool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _attach_entity_type_properties(root: Node3D, props: EntityProperties) -> void:
	_placement_controller.attach_entity_type_properties(root, props)


func _attach_ruleset_token_properties(root: Node3D) -> void:
	_placement_controller.call("_attach_ruleset_token_properties", root)


func _attach_traversal_properties(root: Node3D, props: EntityProperties) -> void:
	_placement_controller.call("_attach_traversal_properties", root, props)


func _migrate_loaded_entity_type_properties() -> int:
	var migrated_count: int = 0
	var pending: Array[Node] = [_content_root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child: Node in current.get_children():
			if not (child is Node3D):
				continue
			var root: Node3D = child as Node3D
			var props: EntityProperties = _get_entity_properties(root)
			if props == null:
				pending.append(child)
				continue
			var migrated: bool = _repair_empty_loaded_model(root, props)
			if _ensure_entity_type_properties_for_root(root, props):
				migrated = true
			if _ensure_readable_entity_name(root, props):
				migrated = true
			if migrated:
				migrated_count += 1
	return migrated_count


func _repair_empty_loaded_model(root: Node3D, props: EntityProperties) -> bool:
	if root == null or props == null or _count_visual_instances(root) > 0:
		return false
	var entity_type: EntityProperties.EntityType = props.get_effective_entity_type()
	if entity_type == EntityProperties.EntityType.LIGHT:
		return false
	var category: String = props.category
	if category == "" or not _model_panelss.has(category):
		return false
	var candidate_names: Array[String] = []
	_append_unique_model_name(candidate_names, str(root.name))
	for child: Node in root.get_children():
		if child is Node3D and not _is_entity_helper_node(child):
			_append_unique_model_name(candidate_names, str(child.name))
	var item_index: int = _find_unique_model_item_index(category, candidate_names)
	if item_index < 0:
		push_warning(
			"无法恢复空模型实体 '%s'：类别 '%s' 中没有唯一同名素材" % [root.name, category]
		)
		return false
	var replacement: Node = _placement_controller.load_model_instance(category, item_index)
	if replacement == null or _count_visual_instances(replacement) == 0:
		if replacement != null:
			replacement.free()
		push_warning("无法恢复空模型实体 '%s'：素材加载后仍无可见网格" % root.name)
		return false
	var model_name: String = str(
		(_model_panelss[category]["items"] as Array)[item_index]["path"]
	).get_file().get_basename()
	var old_shell: Node3D = _find_empty_model_shell(root, model_name)
	var insert_index: int = 0
	if old_shell != null:
		insert_index = old_shell.get_index()
		if replacement is Node3D:
			(replacement as Node3D).transform = old_shell.transform
		root.remove_child(old_shell)
		old_shell.queue_free()
	root.add_child(replacement)
	replacement.set_owner(_content_root)
	root.move_child(replacement, mini(insert_index, root.get_child_count() - 1))
	props.apply_render_layer_to(root)
	var proxy: PickProxy = root.get_node_or_null("PickProxy") as PickProxy
	if proxy != null:
		proxy.target_node = root
		proxy.fit_from_target_synced()
	return true


func _find_unique_model_item_index(category: String, candidate_names: Array[String]) -> int:
	var panel: Dictionary = _model_panelss[category]
	var items: Array[Dictionary] = panel["items"]
	var found_index: int = -1
	for index: int in range(items.size()):
		var item_name: String = str(items[index]["path"]).get_file().get_basename()
		if not candidate_names.has(item_name):
			continue
		if found_index >= 0:
			return -1
		found_index = index
	return found_index


func _find_empty_model_shell(root: Node3D, model_name: String) -> Node3D:
	for child: Node in root.get_children():
		if (
				child is Node3D
				and str(child.name) == model_name
				and not _is_entity_helper_node(child)
				and _count_visual_instances(child) == 0
		):
			return child as Node3D
	return null


func _append_unique_model_name(names: Array[String], candidate: String) -> void:
	var clean_name: String = candidate.strip_edges()
	if clean_name != "" and not names.has(clean_name):
		names.append(clean_name)


func _is_entity_helper_node(node: Node) -> bool:
	return str(node.name) in ["PickProxy", "CombatBody", "CombatLinePreview"]


func _count_visual_instances(node: Node) -> int:
	var count: int = 1 if node is VisualInstance3D else 0
	for child: Node in node.get_children():
		count += _count_visual_instances(child)
	return count


func _ensure_readable_entity_name(root: Node3D, props: EntityProperties) -> bool:
	if root == null or props == null or not str(root.name).begins_with("@"):
		return false
	var readable_name: String = props.display_name.strip_edges()
	if readable_name == "":
		for child: Node in root.get_children():
			if child is Node3D and child.name != "PickProxy":
				readable_name = str(child.name).strip_edges()
				break
	if readable_name == "" or readable_name.begins_with("@"):
		readable_name = "对象"
	root.name = readable_name
	return not str(root.name).begins_with("@")


func _ensure_entity_type_properties_for_root(
		root: Node3D,
		props: EntityProperties
) -> bool:
	if root == null or props == null:
		return false
	if props.entity_type == EntityProperties.EntityType.UNKNOWN:
		props.entity_type = EntityProperties.entity_type_from_category(props.category)
	props.schema_version = maxi(props.schema_version, EntityProperties.SCHEMA_VERSION)
	var before_count: int = root.get_child_count()
	_attach_entity_type_properties(root, props)
	var migrated: bool = root.get_child_count() > before_count
	if props.get_effective_entity_type() == EntityProperties.EntityType.WALL:
		_wall_state_controller.sync_wall(root, ModeGate.is_edit())
	if props.get_effective_entity_type() == EntityProperties.EntityType.LIGHT:
		var light_properties: Node = root.get_node_or_null("LightProperties")
		if light_properties != null:
			var existing_light: Light3D = light_properties.call("find_first_light", root) as Light3D
			if existing_light != null:
				light_properties.call("apply_to", root)
	return migrated


func _load_model_instance(category: String, index: int) -> Node:
	return _placement_controller.load_model_instance(category, index)


func _prepare_model_instance(instance: Node) -> void:
	_placement_controller.call("_prepare_model_instance", instance)


func _align_model_to_drop_origin(instance: Node) -> void:
	_placement_controller.call("_align_model_to_drop_origin", instance)


func _get_model_local_bounds(node: Node) -> Dictionary:
	return _placement_controller.call("_get_model_local_bounds", node) as Dictionary


func _get_cached_packed_scene(path: String) -> PackedScene:
	return _placement_controller.get_cached_packed_scene(path)


func _get_model_drop(
		category: String,
		use_surface_snap: bool,
		mouse_pos: Vector2 = Vector2.INF
) -> Dictionary:
	return _placement_controller.get_model_drop(category, use_surface_snap, mouse_pos)


func _raycast_wall(from: Vector3, to: Vector3) -> Dictionary:
	return _placement_controller.call("_raycast_wall", from, to) as Dictionary
## 只归零导入场景根节点。子节点变换是模型层级的一部分，递归清零会破坏合法模型。
func _reset_all_transforms(node: Node) -> void:
	if node is Node3D:
		var n: Node3D = node as Node3D
		n.position = Vector3.ZERO
		n.rotation = Vector3.ZERO
		n.scale = Vector3.ONE

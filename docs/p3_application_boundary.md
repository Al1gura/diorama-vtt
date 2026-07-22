# P3 应用装配与职责边界

> 状态：2026-07-19 P3.0 架构真值、代码迁移、自动回归和可见窗口验证已完成。本文继续作为 P3.1-P3.4 的依赖方向约束，不替代 `docs/roadmap.md`。

## 一、结论

Gvtt 不需要新增万能框架。保留当前单主场景结构：

- `ModeGate（模式闸门）` 与 `ModuleGate（模组闸门）` 是仅有的业务自动加载单例。
- `Main` 是应用组合根，负责创建普通模块、注入依赖和协调跨模块流程。
- 普通模块只拥有自己的状态；父级调用子模块，子模块用信号上报。
- GM 界面只显示状态和发命令，不保存第二份业务真值。
- 玩家输出只路由地图、图片和视频，不拥有三维世界或媒体数据。

P3.0 的重点不是继续增加控制器数量，而是消除镜像真值、叶子模块直接访问全局状态和不明确的退出清理顺序。

## 二、当前真实应用树

静态 `scenes/main.tscn`：

```text
Main (Node3D, main.gd)
├── Camera3D
├── DirectionalLight3D
├── WorldEnvironment
├── CameraPivot
└── Ground
```

`main.gd::_ready()` 运行时继续创建：

```text
root
├── ModeGate                 # 自动加载，业务全局
├── ModuleGate               # 自动加载，业务全局
├── _mcp_game_helper         # 开发工具，不属于产品架构
└── Main                     # 应用组合根
    ├── SceneRoot            # 共享三维舞台，不直接存盘
    │   └── ContentRoot      # 当前地点内容，单独 PackedScene 存读
    ├── PointerInteractionController
    ├── SelectionController
    ├── PlacementController
    ├── WallStateController
    ├── SceneSessionController
    ├── CameraViewController
    ├── MainUiController
    ├── GridManager
    ├── LOSService
    ├── PlayerFogOverlay
    ├── GMToolOverlay
    ├── SharedGizmo
    ├── CombatLinePreview
    ├── CastView             # 打开时再创建玩家 Window
    └── MainUI               # 大量节点仍由 main.gd 运行时创建
```

## 三、P3.0 收口结果与剩余问题

| 已收口问题 | 当前实现 | 防回退证据 |
|---|---|---|
| 场景状态镜像 | `_current_scene_name/_scene_dirty` 只转发 `SceneSessionController`，不再存第二份值 | P1 覆盖新建、取消、保存、切换、关模组 |
| 相机状态镜像 | 轨道、焦点、地图缩放和保存视角只由 `CameraViewController` 持有；Main 同名字段已删除 | P1 检查控制器状态与 `main.gd` 源码 |
| 叶子模块直连全局闸门 | `SceneSessionController` 与 `PlacementController` 由 Main 注入窄 `Callable`，脚本内没有 `ModuleGate.` | P1 静态合同与 `rg` 双重检查 |
| 装配/清理顺序不明确 | 启动、切模式、切场景、关模组和退出写入可读取的合同日志 | P1 按完整顺序断言；Main 可见运行再次验证 |
| 不可达旧流程与空镜像入口 | `_switch_to_scene()` 提前返回后的旧流程和 `_sync_scene_session_mirror()` 空入口已删除 | Godot 4.7 解析与 P1/P2 回归 |

| 仍有问题 | 当前证据 | 后续边界 |
|---|---|---|
| 主入口职责仍多 | `main.gd` 仍约 4100 行、228 个函数 | 不在 P3.0 一次重写；新功能继续向明确控制器委托 |
| 注入接口仍偏宽 | 放置控制器仍注入内容根、相机、缓存和多类脚本 | 等真实消费者稳定后再按职责拆小，不造万能服务定位器 |
| UI 与装配仍混在一起 | `_build_ui()`、模组首页、属性面板、素材列表仍在 `main.gd` | 后续按真实工作流迁移，不提前实现 P3.1-P3.4 |

## 四、目标应用树

目标不是一次把所有节点搬进 `.tscn`，而是固定逻辑所有权：

```text
root
├── ModeGate                         # 权限状态
├── ModuleGate                       # 当前模组与会话状态
└── Main                             # 组合根，只做装配和跨模块协调
    ├── WorldHost                    # 三维舞台
    │   ├── SceneRoot
    │   │   └── ContentRoot
    │   ├── Camera3D
    │   ├── WorldEnvironment
    │   └── GridManager
    ├── RuntimeServices              # 普通节点，由 Main 注入
    │   ├── SceneSessionController
    │   ├── PlacementController
    │   ├── SelectionController
    │   ├── PointerInteractionController
    │   ├── MovementService
    │   ├── WallStateController
    │   └── LOSService
    └── Presentation                 # 普通节点，不拥有模组数据
        ├── GMInterface
        ├── PlayerOutputRouter       # P3.3 建立
        ├── CastView
        └── MediaPresenter           # P3.3/P3.4 建立最小骨架
```

`WorldHost`、`RuntimeServices`、`Presentation` 先作为职责分组；只有当分组拥有独立生命周期和测试价值时才拆成单独场景，不为了树形好看创建空节点。

## 五、唯一状态所有者

| 状态 | 唯一所有者 | 允许的读写方式 |
|---|---|---|
| 编辑/运行模式与编辑子模式 | `ModeGate` | `Main` 发切换命令；模块消费注入的模式值或由 `Main` 调用 `apply_for_mode()` |
| 当前模组、模组清单、当前带团会话 | `ModuleGate` | `Main`/明确的数据服务发命令；叶子呈现模块不直接访问 |
| 当前地点名、场景脏标记 | `SceneSessionController` | `Main` 查询公开方法；删除 `main.gd` 镜像真值 |
| 当前选中对象 | `SelectionController` | 信号 `selection_changed` 上报；Gizmo/属性面板只按信号刷新 |
| 当前鼠标手势 | `PointerInteractionController` | 输入协调层发开始/取消命令；其他模块不保存平行布尔值 |
| 相机轨道、焦点、地图缩放和保存视角 | `CameraViewController` | `Main` 转发输入命令；删除 `main.gd` 镜像参数 |
| 当前地点节点树 | `SceneSessionController` 管流程，`ContentRoot` 持有节点 | 场景存读只经 `ModuleGate/ModuleIo` 边界 |
| 玩家当前输出类型 | `PlayerOutputRouter` | GM 界面发命令；`CastView`/媒体呈现器只执行显示 |
| 媒体播放状态 | `MediaPresenter` | 输出路由调用；`CastView` 不保存播放业务状态 |

## 六、main.gd 职责分类

### 保留协调

- 启动顺序和依赖注入。
- 连接 `ModeGate`、`ModuleGate` 与普通模块的信号。
- 协调开模组、切地点、切模式、开关投屏和退出。
- 把用户输入分派给指针、选择、相机、放置和运行规则模块。

### 已经委托，但仍需删除镜像

- 指针手势 → `PointerInteractionController`。
- 当前选择 → `SelectionController`。
- 场景切换/保存/脏标记 → `SceneSessionController`。
- 相机状态 → `CameraViewController`。
- 顶栏和面板显隐 → `MainUiController`。
- 放置与组件挂载 → `PlacementController`。

### 待迁移

- 模组首页和模组操作界面。
- 素材扫描、缓存状态和素材面板。
- 属性面板构建与各类型编辑器。
- 运行态移动/枪线/LOS 的创建销毁协调。
- 玩家输出路由和媒体呈现生命周期。
- 应用退出时的统一停止、取消、释放与信号解绑。

## 七、固定生命周期

### 7.1 启动

1. Godot 创建 `ModeGate`、`ModuleGate` 并挂到根节点。
2. Godot 加载/实例化 `Main`。
3. `Main` 创建普通模块和三维内容根。
4. `Main` 创建 GM 界面所需节点。
5. `Main` 注入依赖并连接信号。
6. `Main` 应用当前模式，保持空桌面；不得自动打开历史模组。

### 7.2 打开模组

1. GM 界面把请求交给 `Main`。
2. `Main` 调用 `ModuleGate.open/create/import`。
3. `ModuleGate` 完成清单与会话加载后发 `module_changed`。
4. `Main` 要求场景会话打开起始地点。
5. 场景就绪后刷新 UI、运行服务和玩家输出。
6. 任一步失败都保留原状态或回到空桌面，不暴露半加载模组。

### 7.3 切地点

1. 处理未保存提示。
2. 取消指针手势、移动预览和枪线。
3. 停止当前临时演出并让玩家输出回到地图/空闲安全态。
4. 保存或放弃当前地点。
5. 清理 `ContentRoot` 和地点级服务。
6. 加载目标地点并重建组件/导航/LOS。
7. 更新当前地点真值并刷新界面。

### 7.4 切模式

1. `Main` 请求 `ModeGate` 切换。
2. `ModeGate` 更新唯一真值并发过去式信号。
3. `Main` 按固定顺序应用相机、面板、Gizmo、墙体、Token 拖动和拾取代理。
4. 进入运行态时创建地点级规则服务；退出运行态时恢复编辑底本并释放服务。

### 7.5 开关玩家输出

1. `Main` 请求 `PlayerOutputRouter` 打开。
2. 路由创建/复用 `CastView` 承载窗口。
3. 路由按当前输出类型显示地图或媒体。
4. 关闭时先停止媒体/临时演出，再清空画面、释放窗口和信号。

### 7.6 退出应用

1. 禁止新输入和新加载请求。
2. 取消未完成的资源请求和后台缓存任务。
3. 停止移动、枪线、媒体、音频和临时演出。
4. 关闭玩家输出窗口。
5. 按产品规则保存/提示当前场景与会话。
6. 保存窗口状态。
7. 普通模块随 `Main` 反向退出；自动加载最后释放。

## 八、迁移顺序与门槛

| 批次 | 修改范围 | 自动证据 | 可见窗口证据 |
|---|---|---|---|
| A | 增加装配合同测试和统一退出入口，不改用户操作 | 启动顺序、唯一实例、重复初始化/退出幂等 | 启动空桌面、正常关闭 |
| B | 删除场景名/脏标记镜像，调用方改读 `SceneSessionController` | 新建、取消、保存、切换、读回 | 场景高亮和未保存弹窗正确 |
| C | 删除相机参数镜像，调用方只经 `CameraViewController` | 地图/自由视角、保存/恢复视角 | 滚轮、旋转、平移手感不变 |
| D | 叶子控制器不再直接读取全局闸门，由 `Main` 注入明确值/窄接口 | 控制器可在无全局单例夹具中测试 | 模组、放置和模式流程不变 |
| E | 建立玩家输出路由与统一退出清理 | 重复开关、切地点、异常退出无残留 | 主窗/投屏切换可靠 |

每批通过 P1/P2 回归后才能进入下一批。P3.1 模组持久化可在 A/B 的明确边界上实现，不等待所有 UI 拆分完成。

2026-07-19 实施状态：A-D 已完成；E 属于 P3.3/P3.4 的玩家输出与生命周期范围，本轮没有提前实现。

## 九、四层依据

### 项目现状

- `project.godot`：业务自动加载只有 `ModeGate`、`ModuleGate`。
- `scenes/main.tscn`：静态主场景只有 6 个节点。
- `scripts/main.gd::_ready()`：创建内容树、普通控制器、界面、投屏、LOS 和规则预览。
- `scripts/module_gate.gd`、各 `*controller.gd`：显示当前全局访问、镜像状态和注入接口。

### Godot 4.7 源码

- `main/main.cpp::Main::start()`：自动加载注册、资源加载/实例化、根节点挂载和主场景加载顺序。
- `scene/main/node.cpp::_propagate_enter_tree/_propagate_ready/_propagate_exit_tree()`：进入、子先就绪和反向退出顺序。

### 官方资料

- `gdd_0045_Scene_organization.md`：自包含场景、高层注入、信号响应和祖先协调。
- `gdd_0047_Autoloads_versus_regular_nodes.md`：自动加载的全局访问风险，以及普通节点/Resource 替代方式。

### 英文社区

- <https://github.com/abmarnie/godot-architecture-organization-advice>：Godot 4.x 自包含场景、祖先注入、公开命令/信号和 KISS/YAGNI 原则。该仓库是建议文档而非可安装框架；本项目选择性采用，不做大规模重构。

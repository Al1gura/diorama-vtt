# P3 外部内容与玩家输出合同

> 状态：2026-07-20 P3.3/P3.4 合同已实现并完成自动证明，GM 已明确接受现有证据与剩余风险，P3 完成。项目现状、Godot 4.7-stable 源码、官方资料和英文社区/插件均已核查。

## 一、目标与边界

P3.3 固定第一版所有演出功能都会依赖的两条合同：

1. 模组如何引用外部图片/视频，但不把大文件塞进清单或带团存档。
2. 玩家窗口如何在 `MAP（地图）`、`IMAGE（图片）`、`VIDEO（视频）` 之间切换，并在失败、取消、结束或关闭时可靠回到安全状态。

P3.3/P3.4 只用测试图片和原生 OGV（Ogg Theora 视频）证明合同能运行，不交付正式媒体功能。

明确不做：

- 正式文件选择、批量登记、缩略图、搜索、排序、重命名或删除界面。
- MP4、MOV、WebM 等常见格式承诺，或安装 Godot VLC 扩展。
- 淡入淡出、音量面板、暂停/拖动进度、字幕、章节和播放列表。
- 地图内电视/广告牌视频材质；P3 玩家输出是全窗口呈现。
- 把 `MAP/IMAGE/VIDEO` 变成第三个 `AppMode`。它们只描述玩家窗口显示内容，与 GM 编辑/运行权限正交。

## 二、所有权

| 数据/节点 | 唯一所有者 | 不能负责 |
|---|---|---|
| 外部内容引用 | `ModuleManifest.external_contents` | 文件解码、播放状态、窗口节点 |
| 当前输出种类、请求和阶段 | `PlayerOutputController` | 模组清单写盘、具体后端解码 |
| 原生玩家窗口与承载面 | `CastView` | 当前业务内容、播放状态、失败回退 |
| 地图相机与迷雾 | `MapOutputPresenter` | 图片/视频加载 |
| 图片纹理节点 | `ImageOutputPresenter` | 视频播放、媒体目录 |
| 视频节点与后端 | `VideoOutputPresenter` + `VideoPlaybackBackend` | 模组清单、GM 控件 |
| GM 命令与状态显示 | `Main`/GM 界面 | 保存第二份输出真值、直接调用播放器专有 API |

`CastView` 当前拥有地图相机和迷雾，P3.0/P3.3 实施时迁给 `MapOutputPresenter`。`CastView` 最终只创建/销毁原生 `Window`，提供可挂三维节点的窗口视口与可挂二维呈现的全屏承载根，并转发用户关闭请求。

## 三、外部内容引用

### 3.1 manifest.json 字段

```json
{
  "external_contents": [
    {
      "content_id": "33333333333333333333333333333333",
      "content_type": "image",
      "display_name": "酒馆线索图",
      "source_kind": "external_file",
      "source_path": "C:/Users/GM/Pictures/clue.png",
      "metadata": {
        "natural_width": 1920,
        "natural_height": 1080
      }
    },
    {
      "content_id": "44444444444444444444444444444444",
      "content_type": "video",
      "display_name": "开场 OGV",
      "source_kind": "module_relative",
      "source_path": "content/opening.ogv",
      "metadata": {}
    }
  ]
}
```

约束：

- `content_id` 使用与模组/地点/会话相同的 32 位小写十六进制稳定标识，在当前模组内唯一。
- `content_type` 第一版只允许 `image` 或 `video`。地图来自当前 `World3D`，没有 `ExternalContentRef`。
- `display_name` 可修改，不改变 ID 或来源。
- `source_kind=external_file` 时，`source_path` 必须是规范化后的本机绝对文件路径，不允许 `res://`、`user://` 或相对路径。
- `source_kind=module_relative` 时，路径规范化后必须仍位于当前模组目录内，禁止绝对路径、`..` 和目录逃逸。
- `metadata` 只保存可重算提示。`natural_width/natural_height/duration_seconds` 若存在必须为非负数；加载成功后以真实解码结果为准。
- 清单只保存引用和元数据，不复制文件字节，不把文件嵌入 `manifest.json` 或 `session.json`。
- 文件缺失不等于清单损坏：保留引用，运行时 `available=false`，输出请求返回明确错误。

### 3.2 内存类型

新增 `ExternalContentRef` 强类型容器：

- `content_id: String`
- `content_type: ContentType`，值为 `IMAGE/VIDEO`
- `display_name: String`
- `source_kind: SourceKind`，值为 `EXTERNAL_FILE/MODULE_RELATIVE`
- `source_path: String`
- `metadata: Dictionary`
- `resolved_path: String`，运行时计算，不写盘
- `available: bool`，运行时计算，不写盘

### 3.3 路径解析结果

`ExternalContentResolver` 只做引用校验和路径解析，不加载图片/视频：

```text
{
  error: int,
  content_id: String,
  content_type: int,
  resolved_path: String,
  available: bool,
  message: String
}
```

解析失败不能修改清单、删除引用或创建占位文件。Presenter 只接收成功解析的绝对路径，不自己读取 `ModuleManifest`。

## 四、玩家输出状态

### 4.1 输出种类

```text
NONE  投屏窗口关闭，没有活动 Presenter
MAP   当前三维世界、玩家相机和迷雾
IMAGE 外部图片全窗口呈现
VIDEO 外部视频全窗口呈现
```

### 4.2 生命周期阶段

```text
IDLE       没有请求或已稳定显示 MAP
LOADING    引用已接受，Presenter 正在准备
READY      图片已绑定，或视频首帧/尺寸已就绪
PLAYING    视频正在播放
PAUSED     视频后端暂停（P3 合同保留，正式 GM 控件归 P4）
FAILED     本次请求失败，准备回到 MAP
RELEASING  正在停止、断信号、清引用和释放节点
```

`PlayerOutputController` 持有：

- `active_kind: OutputKind`
- `phase: OutputPhase`
- `active_content_id: String`
- `active_request_id: int`
- `active_presenter: PlayerOutputPresenter`

这些值不得在 `Main`、`CastView` 或 GM 控件中镜像成第二份真值。

## 五、场景树目标

```text
Main
├── CastView                         # 只管理窗口壳
│   └── CastWindow (Window)
│       ├── MapOutputPresenter       # MAP 时启用
│       │   ├── CastCamera
│       │   └── CastFogOverlay
│       └── PlayerOutputCanvas
│           └── MediaRoot (Control)  # IMAGE/VIDEO 时显示
│               ├── BlackBackdrop
│               └── PresenterHost
└── PlayerOutputController           # 唯一输出状态与路由
```

`MediaRoot` 全屏、纯黑、不接收鼠标。显示图片/视频前先停用地图相机与迷雾；回到地图时先释放媒体，再隐藏媒体根并重新启用地图 Presenter。玩家窗口永远不挂 GM 顶栏、属性面板或播放控制。

## 六、公开命令与信号

### 6.1 命令

```text
open_output() -> Dictionary
show_map() -> int
show_image(content_ref: ExternalContentRef) -> int
show_video(content_ref: ExternalContentRef) -> int
return_to_map() -> int
cancel_request(request_id: int, reason: StringName) -> bool
close_output() -> Dictionary
```

每个 `show_*` 返回严格递增的 `request_id`。`0` 保留为“无请求”。调用方只保存请求 ID，不保存 Presenter 或播放器节点引用。

### 6.2 信号

```text
output_requested(request_id, kind, content_id)
output_progressed(request_id, kind, content_id, progress, stage)
output_ready(request_id, kind, content_id)
output_completed(request_id, kind, content_id)
output_changed(kind, content_id)
output_failed(request_id, content_id, error, message)
output_interrupted(request_id, content_id, reason)
output_cancelled(request_id, kind, content_id, reason)
output_released(request_id, kind, content_id)
video_finished(request_id, content_id)
```

`output_interrupted` 保留旧兼容语义；P3.4 的统一生命周期消费者使用 `output_progressed`、`output_completed` 和 `output_cancelled` 分别表达进度、成功完成和明确取消。

旧请求的异步回调若 `request_id != active_request_id`，只能释放自己的结果，不能改变当前输出或发 `output_changed`。

## 七、Presenter 合同

三类 Presenter 都实现同一最小接口：

```text
prepare(request_id, resolved_content) -> void
activate() -> int
deactivate(reason) -> void
release() -> void
is_released() -> bool
get_natural_size() -> Vector2i
```

并发出：

```text
prepared(request_id)
failed(request_id, error, message)
finished(request_id)
released(request_id)
```

`release()` 必须幂等；重复调用不重复发声、不重复释放窗口、不访问已销毁节点。

### 7.1 MapOutputPresenter

- 接管当前 `CastView` 的玩家相机同步、玩家可见渲染层和迷雾叠层。
- `activate()` 注册/启用相机和迷雾；`deactivate()` 关闭相机 current 与迷雾显示，不销毁主 `World3D`。
- `release()` 断开 LOS 信号并释放自己的相机/叠层，不关闭 `CastWindow`。

### 7.2 ImageOutputPresenter

- 使用 `Image.load_from_file()` 读取外部文件，失败返回实际错误。
- 成功后转换为 `ImageTexture`，绑定全屏 `TextureRect`。
- `TextureRect.expand_mode = EXPAND_IGNORE_SIZE`，`stretch_mode = STRETCH_KEEP_ASPECT_CENTERED`，背景为黑色。
- `release()` 先令 `texture = null`，再释放控件并清本地 `Image/ImageTexture` 引用。

### 7.3 VideoOutputPresenter

- 视频控件放在 `AspectRatioContainer` 中；首帧取得真实尺寸后更新比例，外层黑底形成 letterbox（黑边适配），禁止拉伸画面。
- P3 原生后端只接收 `video` 类型和 `.ogv` 测试文件，不把扩展名当作完整解码成功证明。
- `READY` 至少要求文件可读、后端实例有效、视频纹理尺寸大于 0；只创建节点但没有首帧不能宣布就绪。
- P3 测试视频自然结束后发 `video_finished`，随后走统一 `return_to_map()`；P4 可在不改 Presenter 接口的前提下增加结束策略。

## 八、视频后端隔离

`VideoOutputPresenter` 只依赖项目自有 `VideoPlaybackBackend`：

```text
load_file(path: String, audio_bus: StringName) -> void
play() -> int
set_paused(paused: bool) -> int
stop() -> void
release() -> void
is_playing() -> bool
get_natural_size() -> Vector2i
get_duration_seconds() -> float
get_view() -> Control
```

信号：

```text
ready(natural_size, duration_seconds)
finished
failed(error, message)
released
```

### 原生 OGV 后端

- 创建 `VideoStreamTheora`，设置外部文件路径，再赋给 `VideoStreamPlayer.stream` 并显式 `play()`。
- 不依赖 autoplay；官方说明流在后设置时应显式播放。
- 监听 `finished`；停止时调用 `stop()`，清空 `stream`，断开信号，最后释放节点。
- 音频总线作为参数进入后端。P3 可使用 `Master` 完成冒烟；P4 建立正式 `Media` 总线和音量控制，不改变上层接口。
- 文件可读但不是合法 Theora 时，以后端失败或首帧超时返回错误；不能只按 `.ogv` 后缀宣布成功。

### 后续 VLC 后端

- P4 若验证 Godot VLC，通过新适配器把 `VLCMedia/VLCMediaPlayer` 映射到上述接口。
- 上层不得导入、类型判断或调用 VLC 类；原生后端与 VLC 后端不能同时成为状态真值。
- P3/P4 文档和界面只有在 4.7、Windows 双窗口、导出包、停止/释放和许可证检查全部通过后，才可写“支持常见格式”。

## 九、切换顺序

### MAP → IMAGE/VIDEO

1. 分配新请求 ID，标记旧请求 superseded（被替代）。
2. 停止并释放旧媒体 Presenter；地图 Presenter 停用相机/迷雾。
3. 显示纯黑 `MediaRoot`，进入 `LOADING`。
4. 解析外部引用并创建对应 Presenter。
5. Presenter 就绪后确认请求 ID 仍为当前，才 `activate()` 并提交 `active_kind/content_id`。
6. 发 `output_ready` 和 `output_changed`。

### IMAGE ↔ VIDEO 或重复切换

1. 先递增请求 ID，使旧回调失效。
2. 旧视频必须先停声，再清流、断信号和释放节点；旧图片先清纹理。
3. 旧 Presenter 发 `released` 后才创建/激活新 Presenter。
4. 任何时刻最多一个视频后端和一个活动 Presenter。

### 返回 MAP

1. 递增请求 ID并释放媒体。
2. 隐藏/清空 `MediaRoot`。
3. 激活地图相机与迷雾并同步一次当前相机状态。
4. 提交 `MAP/IDLE`，发 `output_changed`。

### 关闭投屏或退出程序

1. 取消当前请求并使所有旧回调失效。
2. 释放媒体 Presenter；视频必须停止音频并清空流。
3. 释放地图 Presenter，断开 LOS/相机引用。
4. `PlayerOutputController` 进入 `NONE/IDLE`。
5. 最后由 `CastView` 释放 `Window`。OS 的 `close_requested` 只转成控制器命令，不能直接跳过前四步。

## 十、失败、取消与安全回退

- 引用非法、文件缺失、图片解码失败、视频后端失败或首帧超时：发 `output_failed`，释放半成品并自动请求 `MAP`。
- 显式取消：发 `output_interrupted`，释放后回到 `MAP`。
- 被新请求替代：旧请求只释放，不额外切回地图，以免覆盖新请求。
- 地图 Presenter 自身失败：保持黑色安全画面并报告 GM；不得循环“失败 → 回地图 → 再失败”。
- 错误详情只显示在 GM 主窗口；玩家窗口不显示路径、堆栈或控制按钮。
- 切场景不关闭投屏窗口，但必须取消媒体并回到地图后再替换三维地点，避免旧媒体声音遮住切场景错误。

## 十一、P3 与 P4 的交付边界

| P3 必须完成 | P4 才完成 |
|---|---|
| `ExternalContentRef` 数据与路径校验 | 正式文件选择/登记/删除和媒体库 |
| MAP/IMAGE/VIDEO 状态与 Presenter 合同 | 完整 GM 播放控制、淡入淡出、音量和缩略图 |
| 原生测试图片与 OGV 冒烟 | 用户常见格式与 Godot VLC 兼容性 |
| 首帧、失败、取消、结束和释放 | 字幕、章节、播放列表与演出编排 |
| 两种窗口尺寸比例正确 | 正式视觉样式和长时间播放体验 |

## 十二、自动测试与可见验证

### 数据合同

- 外部内容 ID 合法且唯一；重命名不改 ID。
- 外部绝对路径与模组相对路径分别正确解析。
- `..`、错误来源种类、错误类型和目录逃逸拒绝。
- 文件缺失保留引用并返回不可用，不修改清单。
- 清单和会话 JSON 不包含媒体文件字节。

### 输出状态

- 打开投屏默认为 `MAP`，GM 控件不在玩家窗口树中。
- 地图 → 图片 → 视频 → 地图的请求 ID 严格递增，状态顺序正确。
- 两种窗口尺寸下图片/视频保持宽高比，黑边区域与内容区域像素可区分。
- 视频首帧真实非空、播放帧会变化、自然结束后停止并回地图。
- 缺失图片、损坏图片、缺失 OGV、伪 OGV 和首帧超时均失败并回地图。
- 快速 IMAGE → VIDEO → IMAGE 时，旧视频回调不能覆盖最终图片。
- 反复切换至少十轮，Presenter/播放器/纹理节点数量不增长。
- 关投屏、切场景和退出时，视频 `is_playing=false`、stream 为空、信号断开、窗口最后释放。
- 返回地图后地图相机、迷雾和玩家可见层恢复，P2 投屏行为不回退。

### 可见窗口

1. 打开投屏，确认正常地图与迷雾。
2. 切测试图片，确认完整画面居中且无拉伸。
3. 切带音频的测试 OGV，确认首帧、运动和声音。
4. 视频结束后确认回地图且声音停止。
5. 播放中关闭投屏，再打开，确认没有残留声音、黑帧或第二个播放器。
6. 在 `1280 × 720` 和另一种不同比例窗口重复，确认布局与 GM 控件隔离。

## 十三、四层依据与插件取舍

- 项目：`CastView` 已有 Windows 原生双窗口、共享 `World3D`、相机和迷雾；`LibraryManager` 不扩成媒体库；现有外部图片加载只作为加载 API 经验。
- Godot 4.7 源码：`Image::load_from_file()` → `ImageLoader`；`TextureRect` 管纹理引用；`VideoStreamPlayer::set_stream()` 先停旧流并实例化后端，进入/退出树注册/移除音频混合并停播；Theora 后端释放文件、解码器与音频缓冲；`Window` 退出树清原生窗口。
- 官方：`Runtime file loading and saving` 支持外部图片和 Theora 文件；`Playing videos` 说明核心只支持 Ogg Theora、使用 CPU 解码，并建议 `AspectRatioContainer` 处理窗口比例；`TextureRect` 提供保持宽高比模式。
- 社区/插件：Godot VLC 1.2.0（2026-05、Godot 4.3+、Windows/Linux、LGPLv2.1）使用独立 VLC 类，未验证本项目 4.7/双窗口/导出/清理，故 P3 不安装；只据此固定后端适配边界，P4 再隔离试验。

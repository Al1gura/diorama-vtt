# P3 生命周期与最小证明合同

> 状态：2026-07-20 P3.4 已实现并完成自动证明，GM 已明确接受现有证据与剩余风险，P3 完成。本文件同时记录行为合同、Godot 4.7-stable 源码对照、实际夹具和测试证据。

## 一、目标与边界

P3.4 不是再增加一批功能，而是证明 P3.0-P3.3 的底座在真实生命周期中成立：

1. 模组、地点、外部内容和带团会话能关闭后读回。
2. 玩家输出能走完 `MAP（地图） -> IMAGE（图片） -> VIDEO（视频） -> MAP`。
3. 缺失、损坏、取消、快速替换、切场景、关投屏和退出都不会留下声音、纹理、播放器、信号或原生窗口。
4. 结构测试能在无窗口环境运行；真实图片/视频显示必须在可见渲染环境验证。

P3.4 不交付正式媒体库、常见视频格式、完整播放控制、淡入淡出或正式 `Media（媒体）` 音频总线。

## 二、完整行为链

### 2.1 打开与地图输出

1. `Main` 创建并注入 `CastView`、`MapOutputPresenter` 和 `PlayerOutputController`。
2. `PlayerOutputController.open_output()` 命令 `CastView` 创建原生 `Window`。
3. `MapOutputPresenter.activate()` 绑定当前 `World3D`、相机和迷雾。
4. 控制器在地图呈现成功后提交 `MAP/IDLE`；窗口创建成功本身不等于地图输出成功。

### 2.2 图片输出

1. 控制器递增请求 ID，使旧异步结果失效。
2. `ExternalContentResolver` 校验引用并解析绝对路径。
3. 地图 Presenter 停用，黑色媒体承载面显示。
4. `ImageOutputPresenter` 调用 `Image.load_from_file()`，成功后创建 `ImageTexture` 并绑定 `TextureRect`。
5. 纹理尺寸有效且请求仍为当前时提交 `IMAGE/READY`。
6. 返回地图或释放时先令 `texture = null`，再释放图片与节点引用。

### 2.3 原生 OGV 视频输出

1. 控制器递增请求 ID，解析视频引用并创建 `VideoOutputPresenter`。
2. 后端创建 `VideoStreamTheora`，设置外部文件路径后赋给树内的 `VideoStreamPlayer.stream`。
3. `VideoStreamPlayer::set_stream()` 先停止旧播放，再调用 `VideoStreamTheora::instantiate_playback()`。
4. `VideoStreamPlaybackTheora::set_file()` 打开文件、识别 Ogg/Theora/Vorbis 头、创建解码器、纹理和音频缓冲；没有视频流时清理并失败。
5. 后端显式调用 `play()`；播放器内部处理逐帧调用 `VideoStreamPlaybackTheora::update()`。
6. Theora 后端解码视频并 `texture->update()`，同时通过混音回调送出音频。
7. 纹理尺寸大于 0、取得非空绘制帧且请求仍为当前后，提交 `VIDEO/READY`，随后进入 `VIDEO/PLAYING`。
8. 文件结束时 Theora 后端停止，播放器观察到 `is_playing=false` 后发 `finished`；控制器再走统一返回地图流程。

### 2.4 取消、替换与关闭

1. 新请求先递增 ID；旧回调只能清理自己，不能提交输出状态。
2. 视频释放顺序固定为：`stop()` -> 清空 `stream` -> 断开业务信号 -> 释放播放器节点与后端引用。
3. 图片释放顺序固定为：清空纹理 -> 断开信号 -> 释放控件与图片引用。
4. 媒体释放完成后，才恢复地图 Presenter。
5. 关投屏或退出时还要释放地图 Presenter；`CastView` 最后释放原生 `Window`。
6. `Window.close_requested` 只转成控制器命令，不直接 `queue_free()`。

## 三、Godot 4.7-stable 源码对照卡

### 3.1 精确版本

- 标签：`4.7-stable`
- 提交：`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`
- 本项目运行版：`4.7.stable.official.5b4e0cb0f`

### 3.2 文件、类、函数和调用顺序

| 阶段 | Godot 源码 | 调用顺序与行为 |
|---|---|---|
| 流替换 | `scene/gui/video_stream_player.cpp`，`VideoStreamPlayer::set_stream()` | 先 `stop()`，断旧流/纹理信号，再 `stream->instantiate_playback()`，取得后端纹理并安装音频混音回调 |
| 后端实例化 | `modules/theora/video_stream_theora.h`，`VideoStreamTheora::instantiate_playback()` | 创建 `VideoStreamPlaybackTheora`，设置音轨，再把 `file` 交给 `set_file()` |
| 文件加载/转换 | `modules/theora/video_stream_theora.cpp`，`VideoStreamPlaybackTheora::set_file()` | `FileAccess::open()` -> 识别流 -> 读取头 -> 创建 Theora 解码器、RGBA 纹理和 Vorbis 音频缓冲；无视频流时清理并报错 |
| 播放 | `scene/gui/video_stream_player.cpp`，`VideoStreamPlayer::play()`/`_notification()` | 必须在树内；启用内部处理，每帧调用后端 `update()`；最后一帧后发 `finished` |
| 帧与音频 | `modules/theora/video_stream_theora.cpp`，`VideoStreamPlaybackTheora::update()`/`video_write()` | 解码 Ogg/Theora/Vorbis，`texture->update()` 写入帧，通过混音回调输出音频；音视频均结束后 `stop()` |
| 停止 | 同上，`VideoStreamPlayer::stop()`、`VideoStreamPlaybackTheora::stop()` | 停止内部处理、清混音缓存；Theora 后端把播放位置 seek 到 0，但不保证当前画面成为首帧 |
| 后端清理 | 同上，`VideoStreamPlaybackTheora::clear()`/析构 | 释放文件、Vorbis/Ogg 状态、Theora 解码器、音频缓冲并清播放标志 |
| 进退树 | `scene/gui/video_stream_player.cpp`，`VideoStreamPlayer::_notification()` | 进树注册音频混合回调；退树先 `stop()`，再移除音频回调 |
| 原生窗口 | `scene/main/window.cpp`，`Window::_event_callback()`/`_clear_window()` | OS 关闭只发 `close_requested`；真正清理时 `delete_sub_window()`，然后禁用视口更新 |
| 可见帧 | `main/main.cpp::Main::iteration()`、`servers/rendering/rendering_server_default.cpp::_draw()` | 有窗口可绘制时执行渲染；绘制尾部才发 `frame_post_draw` |

### 3.3 加载、缓存、实例化和清理边界

- 外部图片由 `ImageLoader` 读入内存，再转换为项目持有的 `ImageTexture`；不进入模组 JSON 或场景资源缓存。
- 外部视频路径写入 `VideoStreamTheora`，真正文件打开和头解析发生在播放后端实例化阶段；不能用扩展名或节点存在代替解码成功。
- 每次设置新流都会先停止旧流并创建新的播放后端；P3 上层不得缓存 `VideoStreamPlaybackTheora`。
- 纹理尺寸在头部解析后可以出现，但真实可见内容要等解码写入和可见绘制完成。
- 视频结束会发 `finished`，但不会替应用释放 Presenter、恢复地图或关闭窗口；这些必须由项目生命周期补齐。

## 四、本项目逐步映射

| Godot 行为 | 本地目标文件/函数 | 验证 |
|---|---|---|
| `set_stream()` 先停旧流再实例化 | `scripts/native_ogv_playback_backend.gd::load_file()/release()` | 假后端顺序测试；真实十轮切换后仅一个播放器 |
| `set_file()` 解析并可能失败 | `NativeOgvPlaybackBackend.load_file()` | 缺失 OGV、伪 OGV、无首帧超时均明确失败 |
| `update()` 写纹理并送音频 | `VideoOutputPresenter` + 原生后端 | 可见窗口取得非空首帧、后续帧变化、临时音频总线出现峰值 |
| `finished` 只表示自然结束 | `PlayerOutputController._on_video_finished()` | 状态按 `VIDEO -> RELEASING -> MAP`，声音和流停止 |
| 退树时停播/移除混音 | `VideoPlaybackBackend.release()` | 播放中关投屏、切场景、退出后 `is_playing=false`、流为空 |
| OS 关闭只发请求 | `CastView` 转发关闭命令 | 窗口最后释放，媒体/地图 Presenter 先释放 |
| `frame_post_draw` 才能取可靠像素 | `tests/p3_4_player_output_smoke.gd` | 只在 Windows 可见渲染运行；无窗口测试不等待该信号 |

以上目标文件与函数均已落地；实际文件、调用链和验证结果见第十节。

## 五、无法照搬的差异

- Godot 只管理单个播放器节点，不知道 Gvtt 的地图、图片、视频三类输出，也不会自动回地图；由 `PlayerOutputController` 补业务路由。
- Godot 的 `finished` 没有请求 ID；Gvtt 必须在回调外层绑定请求 ID，拒绝旧请求覆盖新输出。
- Godot 的错误会进入引擎错误通道，但原生播放器没有满足 Gvtt 所需的统一失败结果；后端用首帧超时和状态检查转换为项目错误。
- `stop()` 后当前画面可能为空，不能要求停播后仍显示首帧。安全回退画面是黑底或地图，不依赖播放器残留纹理。
- Godot 不替 Gvtt 决定窗口释放顺序；项目必须先停声音和释放媒体，最后删除原生窗口。
- 无窗口显示服务器不会绘制，也不会发 `frame_post_draw`；像素与真实视频测试必须使用可见渲染器。

## 六、测试夹具

### 6.1 独立测试模组

测试运行时在隔离 `user://` 目录创建 `__p3_4_lifecycle_fixture__`，测试结束后清理，不修改真实模组：

- 两个地点，分别有稳定 `location_id`。
- 一个合法外部图片引用、一个合法模组相对 OGV 引用。
- 一个缺失图片引用、一个损坏图片、一个缺失 OGV、一个存在但无 Theora 视频流的伪 OGV。
- 一条 `..` 路径逃逸引用和一个未来 schema 版本副本。
- 一次最小带团变化，供关闭重开验证。

### 6.2 图片夹具

- `640 x 480`，四象限使用明显不同颜色，中心有非黑标记，便于验证方向、内容和黑边。
- `1280 x 720` 窗口下应为左右黑边；`1024 x 768` 下应完整铺满而不拉伸。
- 由 Godot `Image` API 生成 PNG，记录尺寸和 SHA-256；不依赖外部版权素材。
- 固定产物：`tests/fixtures/p3_4/quadrants_640x480.png`，2,396 字节，SHA-256 `6cad696fde8ff9f226297d8637a3af20dea4787b4aeee28ea81d17c5c0e1a14b`。

### 6.3 OGV 夹具

- `640 x 360`、30 FPS、约 9 秒，画面有平滑移动图形、进度条和状态标记；音轨为 18 音原创短旋律和四小节低音伴奏，并带淡入淡出，便于人工点击暂停、恢复和停止。
- 使用 Godot 4.7 编辑器内置 `MovieWriter（影片写出器）` 生成 Ogg Theora + Vorbis；不依赖本机不存在的 FFmpeg。
- 生成命令使用 `--write-movie`、`--resolution 640x360` 和 `--fixed-fps 30`；生成场景在固定帧数后调用 `SceneTree.quit()`，保证写出器正常收尾。
- `1024 x 768` 窗口下应为上下黑边；`1280 x 720` 下应完整铺满而不拉伸。
- 生成后记录文件大小、时长、尺寸和 SHA-256；运行测试只消费固定夹具，不在每次回归时重新编码。
- 固定产物：`tests/fixtures/p3_4/motion_audio_320x180.ogv`，693,642 字节、271 帧、约 9.0333 秒，SHA-256 `3a14a04c0cdf193458fbfe38ccbe2b8add016b197dd6880991b1d0aefcec6142`。
- 生成工具：`tools/p3_4_fixture_generator/` 独立 Godot 小工程；用 `.gdignore` 与正式项目导入隔离，不修改正式窗口设置。

### 6.4 临时音频总线

- 测试开始时用 `AudioServer.add_bus()` 创建唯一临时总线并传给原生后端。
- 播放期间读取左右声道峰值，证明 OGV 音轨实际进入混音。
- 释放后确认播放器停止，并在清理阶段删除临时总线。
- 自动峰值只能证明有音频信号；“人耳没有残留声音”仍属于可见窗口人工验收。

## 七、两层自动测试

### 7.1 无窗口合同测试

实际文件：`tests/p3_4_lifecycle_contracts.gd/.tscn`；P3.3 兼容基线仍由 `tests/p3_3_player_output_contracts.gd/.tscn` 覆盖。

- 用可控假 Presenter 和假视频后端验证状态、信号、请求 ID、取消、失败、旧回调和幂等释放。
- 快速执行 `IMAGE -> VIDEO -> IMAGE`，旧视频的 ready/finished/failed 回调均不能改变最终图片。
- 重复释放不重复发信号、不访问已销毁节点。
- 模组清单、迁移、会话关闭重开、缺失引用和路径逃逸在隔离用户目录验证。
- 所有异步等待使用单调时钟截止时间和明确失败信息，不使用固定睡眠冒充完成。

### 7.2 可见渲染冒烟

实际文件：`tests/p3_4_player_output_smoke.gd/.tscn`。

- 强制要求 `DisplayServer.get_name() != "headless"` 且 `Engine.get_frames_drawn()` 增长，否则测试失败，不降级为假成功。
- 打开投屏后等待 `frame_post_draw`，从玩家 `Window` 纹理读取像素。
- 验证地图、图片四象限、图片黑边、视频首帧非空、两次视频帧图像不同、视频黑边和音频峰值。
- 验证自然结束后回地图，`is_playing=false`、流为空且临时总线可清理。
- 快速切换和连续十轮图片/视频切换后，Presenter、播放器、纹理节点数回到基线。
- 播放中依次验证切场景、关投屏和退出清理；原生窗口必须最后释放。
- 每个 ready/finished/released 等待都有超时；真实 OGV 就绪上限初定 5 秒，自然结束上限为夹具时长加 2 秒，首次实测后只可基于证据调整。

## 八、人工可见验收

1. 打开投屏，确认地图、相机和迷雾与 P2 一致。
2. 切换测试图片，在两种窗口比例下确认完整、居中、无拉伸。
3. 切换测试 OGV，确认运动连续、测试音可听见且玩家窗口没有 GM 控件。
4. 等视频自然结束，确认自动回地图且声音停止。
5. 播放中关闭投屏，再打开，确认无残留声音、黑帧或第二个播放器。
6. 快速反复切图片/视频，确认最终内容正确且操作不越来越慢。
7. 最后重做 P2 的 Token、光源、瞄准、LOS 和破墙关键路径，确认结构迁移没有回退。

2026-07-20 GM 明确表示接受现有自动证明并将本阶段视为完成，同时指出任何验收都不能保证以后没有 bug（程序缺陷）。该判断作为剩余风险接受记录，不扩张自动测试能证明的范围。

## 九、四层调研与取舍

- 项目现状：现有 P1/P2 使用独立测试场景、结构化结果和进程退出码；P2.5 已实证无窗口环境不会发 `frame_post_draw`。继续沿用该运行方式，新增可见媒体冒烟，不另造平行测试框架。
- Godot 源码：采用第三节的 4.7-stable 完整播放/结束/释放/窗口链；外部图片链沿用 `docs/p3_player_output_contract.md` 的 `ImageLoader` 与 `TextureRect` 对照。
- 官方资料：`Playing videos（播放视频）`、`Runtime file loading and saving（运行时文件加载与保存）`、`MovieWriter（影片写出器）`、`Viewport（视口）`、`AudioServer（音频服务器）` 文档分别支持原生 OGV、外部文件、固定帧率含音频夹具、绘制后取像素和总线峰值。
- 英文社区/开源：Godot 问题 #92050 在 4.3.dev6 复现播放前/停止后空画面，当前仍为开放讨论，只作为停止画面风险依据；本地 gdUnit4 6.2.0-rc2 提供带超时信号等待，但现有项目不是用它运行 P1/P2，且它是候选版，故不引入 P3 核心测试链。Godot 官方 demo 仓库是 MIT，但没有找到可直接复用且满足本合同的短含音频 OGV，故用官方 MovieWriter 自产夹具。

社区来源：

- <https://github.com/godotengine/godot/issues/92050>
- <https://github.com/godotengine/godot-demo-projects>

## 十、当前证据与完成标准

### 10.1 自动证明

- 无窗口生命周期合同：`64/64`，覆盖请求、进度、完成、失败、取消、旧回调失效、幂等释放、关闭重开、缺失视频引用与十轮切换；日志 `build/crash_matrix/20260720_224906_original_direct/godot.log`。
- Windows 可见媒体冒烟：`133/133`，`display_server=Windows`、`frames_drawn=6275`、最大音频峰值约 `-8.97 dB`、视频时长约 `1.2333 s`；日志 `build/crash_matrix/20260720_225401_original_direct/godot.log`。
- 最终回归：P1 `352/352`、P2.4 `56/56`、P2.5 `54/54`、P2.6 `64/64`、P2 指标 `20/20`、P3.1 `75/75`、P3.2 数据/控制器/可见 `39/39 + 39/39 + 32/32`、P3.3 `47/47`。
- 上述最终运行均退出码 0、0 转储、无超时、无强制清理、无残留 Godot 进程。伪 OGV“没有视频流”、损坏 PNG 和损坏 P3.2 快照错误均为测试故意触发的失败路径。
- 静态检查确认本轮相关 GDScript（Godot 脚本）没有 `:=`、没有漏写变量类型，`git diff --check` 通过。单独干净导入探针在 60 秒超时并被探针清理，0 转储、无残留；相关脚本随后均被上述真实场景成功解析并执行，不能把该导入探针记为通过。

### 10.2 P3 完成闸门

只有以下各项同时成立，P3 才能宣布完成：

- P2 GM 可见窗口闸门已给出接受结论。
- P3.0-P3.3 功能和失败测试全部实现。
- 无窗口合同测试与 Windows 可见媒体冒烟均通过。
- 图片、视频、音频、自然结束、快速替换、十轮释放、切场景、关投屏和退出均有证据。
- P1、P2.4、P2.5、P2.6 与 P3 全量回归通过，历史泄漏警告单独如实记录。
- GM 完成可见窗口人工验收，开发日志写入四层来源、采用/未采用方案和源码行为到本地验证的逐项映射。GM 已于 2026-07-20 明确接受现有证据与剩余风险，本项完成，P3 可以宣布完成。

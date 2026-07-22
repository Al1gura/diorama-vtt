# P4 推进对话稿

> 状态：2026-07-21。用于把 P4 媒体演出闭环分批推进。每段可直接复制给 Codex 新任务；不要跳过 P4.0。

## 使用顺序

1. 先发“总控对话”，让新任务重新核查当前真值。
2. 再发 `P4.0`，完成四层调研、Godot 4.7 源码对照卡和最小验证方案。
3. `P4.1-P4.5` 只有在前一段完成、日志和测试证据写入后再推进。

## 总控对话

```text
我们现在进入 Gvtt 的 P4：媒体演出闭环。

先不要写代码。请先交叉核查：
- docs/roadmap.md
- docs/p3_player_output_contract.md
- docs/p3_lifecycle_test_contract.md
- devlog/DEVLOG.md 最新条目
- project.godot
- scenes/main.tscn
- scripts/main.gd
- scripts/player_output_controller.gd
- scripts/image_output_presenter.gd
- scripts/video_output_presenter.gd
- scripts/video_playback_backend.gd
- scripts/native_ogv_playback_backend.gd
- scripts/cast_view.gd
- .agents/skills/
- .codex/
- addons/

目标不是重做 P3。P3 已完成，只提供 MAP/IMAGE/VIDEO 输出合同和测试图片/OGV 最小证明。P4 要把它升级成 GM 桌边可用的正式图片/MV 功能。

请先回答：
1. 当前 P3 已经有哪些输出骨架和测试证据。
2. P4 不能越界做哪些事。
3. P4 应该按哪些小批次推进。
4. 第一批 P4.0 是否触发现成方案调研和 Godot 源码一致性门禁。

回答后继续执行 P4.0，不要等我再确认，除非发现范围冲突、数据风险或需要系统权限。
```

## P4.0 前置调研与源码对照

```text
执行 P4.0：媒体演出闭环的前置调研、Godot 4.7 源码对照卡和最小验证方案。

本轮必须完成四层调研回执，调研完成前禁止修改功能代码：

1. 项目现状：
   - 核查 P3 的 PlayerOutputController、Presenter、VideoPlaybackBackend、CastView 和 ExternalContentRef 当前职责。
   - 找出现有 P3 测试图片/OGV 证明和 P4 仍缺的正式功能。

2. Godot 4.7 源码：
   - 锁定 4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88。
   - 对照 VideoStreamPlayer、VideoStreamTheora、TextureRect、AudioServer、Window 的加载、播放、暂停、停止、音频混合、释放和窗口关闭链。
   - 如果涉及 VLC 扩展，只能作为候选后端，不能把插件行为说成 Godot 原生行为。

3. 官方资料：
   - 查离线 Godot 4.7 文档，确认 Playing videos、Runtime file loading and saving、TextureRect、AspectRatioContainer、AudioServer、Window、FileDialog 或相关 UI API 的现行名称和签名。

4. 英文社区/插件：
   - 核查 Godot VLC 当前版本、Godot 版本兼容、Windows 支持、导出限制、许可证风险和维护状态。
   - 查是否有更稳妥的 Godot 4.x 媒体播放方案。没有就明确没有，不要伪造共识。

交付内容：
- 调研回执表。
- 源码对照卡：Godot 行为 -> 本地现状 -> P4 目标实现 -> 自动测试/可见验证。
- P4 分批实施计划：P4.1 媒体登记、P4.2 图片演出、P4.3 视频演出、P4.4 GM 控制界面、P4.5 回归验收。
- 明确哪些结论只是候选，尤其是 MP4/MOV/WebM 和 Godot VLC。

完成后更新 devlog/DEVLOG.md。除非调研暴露新的范围冲突，否则继续进入 P4.1 的实现准备。
```

## P4.1 媒体登记

```text
执行 P4.1：媒体登记。

前提：P4.0 调研、源码对照卡和 devlog 已完成。

目标：
- GM 能把外部图片和视频登记到当前模组。
- 列表能看到名称、类型、来源和状态：可播放、缺失、损坏或暂不支持。
- 只保存引用和元数据，不把媒体字节写进 manifest.json、session.json 或 .scn。
- 不承诺 MP4 支持；如果 VLC 还没通过 P4.0 隔离验证，视频先按 OGV 回退策略处理。

实现前请先核查：
- ModuleManifest.external_contents 当前格式。
- ExternalContentRef / ExternalContentResolver 当前能力。
- Main 或 MainUiController 左栏/面板现有 UI 结构。
- Godot 4.7 FileDialog、Button、Label、VBoxContainer、Popup/Menu API 离线文档。

交付：
- 代码和必要场景/UI 修改。
- 自动测试覆盖：登记、重命名、缺失文件、路径逃逸、清单读回、媒体字节不入库。
- 可见窗口验收说明：用户在主窗口点哪里、选择什么、预期看到什么。
- devlog/DEVLOG.md 记录四层来源、采用/未采用方案和验证证据。
```

## P4.2 图片演出

```text
执行 P4.2：图片演出。

前提：P4.1 媒体登记完成且回归通过。

目标：
- GM 从已登记媒体中选择图片，投屏窗口显示图片。
- 图片保持宽高比，黑边正确，不拉伸。
- 支持淡入淡出和返回地图。
- 图片缺失、损坏或解码失败时，GM 主窗口明确提示，玩家投屏可靠回地图或保持安全黑底，不显示路径堆栈。

实现前请复核：
- P3 ImageOutputPresenter 当前加载和释放链。
- TextureRect、AspectRatioContainer 或等效布局的 Godot 4.7 文档。
- P3.4 图片像素/黑边测试方法。

交付：
- 图片播放入口和状态显示。
- 淡入淡出最小实现；不要做复杂播放列表。
- 自动测试覆盖：正常显示、两种窗口比例、缺失/损坏失败、快速返回地图、十轮切换释放。
- 可见验收：地图 -> 图片 -> 返回地图，确认无拉伸、无 GM 控件、无残留。
- 更新 devlog/DEVLOG.md。
```

## P4.3 视频演出

```text
执行 P4.3：视频演出。

前提：P4.2 图片演出完成且回归通过。

目标：
- GM 从已登记媒体中播放视频。
- 支持播放、暂停、恢复、停止、自然结束、音量和返回地图。
- 音频走独立产品媒体总线，不继续使用 P3 的临时测试总线。
- 切媒体、切场景、关投屏和退出程序时必须停止声音、断信号、清流并释放节点。
- 如果 Godot VLC 未通过隔离验证，只交付 OGV；不要把 MP4/MOV/WebM 写成已支持。

实现前请复核：
- P3 NativeOgvPlaybackBackend、VideoOutputPresenter、PlayerOutputController 当前生命周期。
- AudioServer、AudioStream、VideoStreamPlayer、Window 的 Godot 4.7 文档和源码链。
- P4.0 对 VLC 的结论。

交付：
- 播放/暂停/恢复/停止/音量控制。
- 视频自然结束回地图。
- 自动测试覆盖：首帧、帧变化、音频峰值、暂停不继续推进、恢复继续、停止静音、自然结束、十轮切换、窗口关闭清理。
- 可见验收：地图 -> MV -> 暂停/恢复 -> 停止 -> 返回地图。
- 更新 devlog/DEVLOG.md。
```

## P4.4 幕式内容管理与 GM 控制界面

```text
执行 P4.4：幕式内容管理与 GM 控制界面。

前提：P4.1-P4.3 的数据、图片和视频能力已完成。

目标：
- “幕”是 GM 可反复查看和使用的第一层内容资料夹，不是 PPT、自动播放列表或剧情状态机。
- 幕可以没有地图；图片、视频、文本和地图都作为内容服务于幕。
- 幕之间没有剧情顺序、完成、解锁或自动推进；选择另一个幕只切换 GM 资料视图，不改变玩家输出。
- 主窗口提供幕列表、幕内图片/视频/文本/地点引用、类型/状态显示和手动投放控制。
- 排序只服务于整理和上一项/下一项选择；GM 可以任意跳转，不自动播放、不记录剧情完成度。
- 同一内容可以跨幕复用；删除幕或移除条目不移动、不改名、不删除原文件或地点。
- 控件只在 GM 主窗口显示，玩家投屏不显示任何 GM 按钮、路径或错误堆栈。
- 运行态桌边操作要快：选择幕、搜索内容、任意投放图片/视频、切换地图、暂停/恢复、停止、返回地图。
- 编辑态和运行态权限要清楚；不要新增第三个 AppMode。

实现前请复核：
- MainUiController、左栏、顶栏、属性栏现有职责。
- PlayerOutputController 的唯一状态所有权。
- ModuleManifest、ModuleIo、ModuleGate 的清单版本迁移和可恢复保存链。
- Godot 4.7 Control 容器、Tree、Button、Slider、Tooltip、禁用和拖放源码/文档。

交付：
- 幕数据合同、旧清单迁移和 GM 管理界面。
- 状态与按钮禁用规则。
- 自动测试覆盖：幕增删改排、同一内容复用、同一幕反复使用、无地图幕、无当前/完成/解锁状态、切换幕不改变玩家输出、缺失引用保留、删除幕不删源文件、玩家窗口树无 GM 控件、多状态按钮可用性、错误提示只在 GM 侧。
- 可见验收：用户创建幕、加入内容、排序、任意投放并完成媒体流程。
- 更新 devlog/DEVLOG.md。
```

## P4.5 回归与阶段验收

```text
执行 P4.5：P4 总回归与阶段验收。

前提：P4.1-P4.4 全部完成。

目标：
- 证明 P4 完整闭环：地图 -> 图片 -> MV -> 暂停/恢复 -> 返回地图。
- 证明异常可靠：缺失媒体、损坏媒体、快速切换、切场景、关投屏、退出程序都不会留下声音、黑帧、播放器、信号或失控窗口。
- 证明 P4 没有回退 P1/P2/P3。

必须运行并报告：
- P4 媒体登记测试。
- P4 图片演出测试。
- P4 视频演出测试。
- P4 UI/投屏隔离测试。
- P1、P2.4、P2.5、P2.6、P2 指标、P3.1、P3.2、P3.3、P3.4 关键回归。
- Windows 可见窗口媒体验收。

完成报告必须包含：
- 做了什么。
- 没做什么及原因。
- 产出物在哪。
- 自动测试跑了哪些。
- GM 在 Godot 可见窗口里怎么验收：点哪里、选什么、按什么、预期看到什么。
- Godot 源码行为 -> 本地实现 -> 自动测试/运行验证映射。
- devlog/DEVLOG.md 已更新。
```

## 2026-07-22 Codex P5 最新状态索引

- [x] 当前 P5 真值已改为五阶段：十项 CPR 属性与自动参战 → 地形加权自动移动 → 一键/手动先攻 → 远程攻击提示与 CPR DV → 回合整合和退出。
- [x] 正式计划位于 `docs/p5_plan.md`；路线图、设计和文档入口已同步。
- [x] 五个独立 Codex 研究任务已创建，首轮均只调研、不改功能代码；完整四层依据、任务编号与许可证取舍见本文件中的“Codex P5 十属性定案、完整五阶段计划与研究任务创建”。
- [ ] P5 功能代码、场景、自动测试和运行验收尚未开始；下一步按 P5.1 → P5.5 顺序推进。

## 2026-07-22 Codex P5 范围再审：复用现有 Token/战斗线并删除过早记录

### 四层调研回执
- [x] 项目现状：已有 `TokenProperties`、`CprTokenProperties`、`MovementService`、`CombatLinePreview/Query`和整地点会话快照；P5 不需要新建 Token 系统或远程检测。Token 当前只有 MOVE（移速）等有限 CPR 字段，没有 REF（反应）/先攻字段和单体稳定 ID。
- [x] CPR 规则：核心规则书 PDF p.144-145、187（书内 p.126-127、169）确认先攻为 `REF+1D10`、每回合 `MOVE×2`、游泳/攀爬/助跑跳每 1 米消耗 2 米移动预算、立定跳距离为助跑跳的一半。
- [x] Godot 源码：锁定 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`NavigationLink3D::_link_enter_navigation_map()`向导航服务器登记链接起终点；`GodotNavigationServer3D::query_path()`调用 `NavMeshQueries3D::map_query_path()`；`NavigationPathQueryResult3D.path_types/path_rids`标记链接段。项目已读取链接段及标签，但 Token 跟随仍为逐点线性移动，尚未完成跳跃弧线/攀爬表现和助跑/立定区分。
- [x] 官方资料：Godot 4.7 `NavigationLink3D`与 `NavigationPathQueryResult3D`确认导航链接只提供路径连接、成本和链接元数据；实际角色如何跨越链接由项目的路径跟随器实现。
- [x] 英文社区：Foundry 现行 Combat Tracker（战斗追踪器）提供 Roll All（一键掷全部先攻）、手动改值、Previous Turn（上一回合）和 End Combat（结束战斗）；CPR 社区追踪器还自动化 HP、护甲、伤势与保存。采用一键先攻与手动改值；不因社区存在就照搬上一回合、伤害管线和战斗持久化。

### 拟议 P5 收缩
- [x] 复用现有 Token：战斗列表只保存本次运行中的 Token 节点引用；若不做战斗跨程序恢复，本轮不增加单体稳定 ID。
- [x] 先攻改为自动/手动并存：计划增加“一键先攻”，同时保留逐行手填、修改和重掷；自动先攻所需 REF 数据如何保存仍待用户最终确认。
- [x] 回合只保留当前角色高亮与“下一位”；删除“上一位/上一轮”和悔棋历史。误点修正可直接指定当前行，不建立状态回滚系统。
- [x] 移动继续扩展现有 `MovementService`：普通移动、困难地形、游泳、攀爬、助跑跳和立定跳按 CPR 计费；链接段根据标签显示跳跃弧线或攀爬过程，不创建第二套移动控制器。
- [x] 删除动作合法性警告、ROF（开火速率）警告和动作记录；GM 的特殊设定不应被反复提示。
- [x] 远程攻击复用现有 `CombatLinePreview/Query`，只补目标选择、实际距离和可选 DV（难度值）查表显示；不重写射线检测，不自动判断命中。
- [x] 战斗专用保存/恢复后置；现有地点会话快照继续保存场景和 Token 位置，但不保存先攻队列、回合或动作历史。
- [x] “结束战斗”改义为“退出战斗模式”：只清空内存队列、当前角色高亮、回合移动余额、目标选择和战斗线；不删除 Token、不回滚位置、不修改场景/会话数据，也不需要破坏性确认。
- [x] 本轮未修改 `docs/p5_plan.md`或功能代码；待用户确认自动先攻数据方式后，再正式重写 P5 计划与验收门槛。

## 2026-07-22 Codex CPR 核心时序复核与 P5/GM 分工审查

### 规则可信度
- [x] 使用 PDF（便携式文档格式）核验流程重新渲染并视觉检查核心规则书 PDF p.186、187、198、204、205、206；确认先攻队列、每回合动作、分段移动、火场、电击、伤势状态、严重伤势、致命伤和死亡豁免的原页内容。
- [x] 不宣称“100% 无问题”：速查的五个回合检查点是 GM 操作整理，不是原书正式阶段名；特殊武器、弹药、职业能力与具体条目可以覆盖通用规则；中文 PDF 另有已记录的射程区间排版重叠。

### P5 与 GM 分工
- [x] P5 程序处理：稳定参战者标识、手填先攻后的排序/平手标记、轮次与当前角色、分段移动预算、简化动作记录、远程攻击测距/射线/DV（难度值）表提示、保存恢复和清理。
- [x] P5 只提示：回合开始/结束检查、ROF（开火速率）和动作合法性、射线阻挡、射程区间、霰弹/爆炸范围，以及“若目标 REF（反应）≥8 则可选择闪避”；GM 必须能修正或覆盖提示。
- [x] GM 手动处理：全部掷骰、闪避选择、命中、伤害、SP（护甲值）/HP（生命值）/弹药/掩体耐久、严重伤势、伤势状态、死亡豁免、燃烧/电击/环境伤害、近战/擒拿/武术、稳定与治疗，以及特殊能力和自定义规则。
- [x] 发现现计划数据漏洞：P5 第一版明确不做角色卡和技能库，当前 Token 只有 MOVE（移速）等有限 CPR 数据，因此程序不能自动判断目标是否 `REF ≥ 8`；P5.4 应只显示条件提醒，除非以后另行批准新增 REF 数据字段。
- [x] 本轮未修改 P5 功能代码、场景、测试或 `p5_plan.md`；仅记录审查结论，待用户确认分工后再收紧正式计划。

## 2026-07-22 Codex 战斗时序与状态结算补全

### 修正结论
- [x] 更正此前把整理清单说成“规则固定几步”的错误：CPR 原书规定一次性的先攻队列和反复进行的角色回合，但没有正式命名固定四步/五步制度。
- [x] 为 GM 桌边防漏结算，把每名角色回合整理为五个检查点：回合开始判生死、确认动作资源、执行并即时结算动作、回合结束结算持续/条件效果、推进队列。
- [x] 明确时点：致命伤死亡豁免在自己的回合开始；攻击造成的护甲、HP（生命值）、严重伤势和伤势状态当场结算；火场伤害、未分离电击及徒步超过 4 米触发的特定严重伤势在回合结束检查。
- [x] 明确死亡衔接：角色在动作或回合结束效果中降至 0 HP 或更低时立即进入致命伤，通常到其下一个回合开始才做死亡豁免；死亡豁免一次失败立即死亡。
- [x] 本轮只修正规则速查和开发日志，未修改功能代码、场景或测试，未启动 Godot。

## 2026-07-22 Codex 战斗流程层级修正

### 修正结论
- [x] 用户指出原“30 秒战斗流程”把只执行一次的先攻排序，与每名角色反复执行的回合检查并列成同一循环层级；问题成立。
- [x] 进一步修正攻击层级：攻击与伤害不是每回合必经步骤，而是角色选择攻击动作后才进入的子流程；装填、起身、擒拿和稳定伤势等可以取代攻击。
- [x] 速查现拆成“战斗开始：只执行一次”和“每名角色的回合：反复循环”；回合循环只有开始检查、执行动作、结束检查、推进队列四个必经阶段，攻击缩进为执行动作中的可选子流程。
- [x] 本轮仅修正文档结构与开发日志，未修改功能代码、场景或测试，未启动 Godot。

## 2026-07-22 Codex CPR 速查与 P5 路线一致性复核

### 复核结论
- [x] `combat_quick_reference.md`定位为 GM 桌边手册与开发查证底稿，符合 `docs/design.md:42-56` 的 CPR 资料门禁；它不是 P5 功能清单，也不代表其中全部规则都要进入软件。
- [x] P5 仍只实现参战者、手填先攻、轮次、分段移动/动作记录、距离/DV（难度值）/二元遮挡提示和保存恢复；掷骰、闪避选择、命中、伤害、护甲、严重伤势与治疗继续由 GM 裁决。
- [x] 发现实施边界风险：速查覆盖的近战、护甲、伤害、严重伤势、死亡和治疗超出 P5 自动化范围；后续不得把速查目录直接当作开发待办。
- [x] 后续实现门槛补充：重复实体、缺失先攻、损坏存档等数据完整性问题可以硬拦截；动作合法性、ROF（开火速率）、DV、遮挡和闪避资格属于 CPR 辅助，应显示依据并保留 GM 修正/覆盖入口，避免局部辅助演变成替 GM 裁决的规则引擎。
- [x] 本轮仅复核现有设计、路线、计划、速查和已有基础服务；未修改 P5 功能代码、场景或测试，未启动 Godot。

## 2026-07-22 Codex CPR 战斗规则速查

### 完成内容
- [x] 新建 `docs/cpr_reading/combat_quick_reference.md`，按 GM 桌边裁定顺序整理 30 秒战斗流程、基础判定、动作、移动、远程/近战、掩体、护甲、伤害、严重伤势、死亡豁免、稳定与治疗。
- [x] 速查保留每组规则的 `PDF p.X / 书内 p.Y` 双页码，并增加原书快速索引；同步 `docs/cpr_reading/README.md`、`docs/README.md` 和 `docs/p5_plan.md` 的入口。
- [x] 核对来源：战斗章 PDF p.185-206 / 书内 p.167-188，基础判定 PDF p.147-148 / 书内 p.129-130，治疗 PDF p.240-241 / 书内 p.222-223，FAQ PDF p.9-11；直接渲染核对 PDF p.189-206 的表格与正文。
- [x] 明确四处易误读规则：火场每轮按固定烈度扣血、举盾作为掩体时的行动限制、致命伤实际受到攻击伤害时追加严重伤势、瞄准手持物/腿部的护甲判定口径。
- [x] 中文单发射程表原文存在 `26-50` 与 `50-100` 的 50 米/码重叠；结合相邻档位与同页全自动表，速查显式整理为连续的 `26-50 / 51-100`，并在文首保留修订说明。
- [x] 静态验收通过：525 行、18 个连续主章节、53 个标题、154 行表格；表格列数一致，无尾随空白、待办占位或缺失来源文件。
- [x] 本任务仅整理规则文档；未修改功能代码、场景或测试，未启动 Godot，也未使用 Godot MCP（运行态接口）。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-22 | 中文单发射程表的 `26-50` / `50-100` 在 50 米/码重叠。 | 速查显式改为连续区间 `26-50 / 51-100`，原书排版问题与整理依据均已记录。 |
| 2026-07-22 | 火场累计、盾牌限制、致命伤追加伤势和瞄准部位容易被简写误导。 | 已回到原文逐条收紧措辞，并保留对应页码供 GM 复核。 |

## 2026-07-22 Codex P5.0 CPR 战斗操作闭环重新调研与规划

### 阶段结论
- [x] 流程纠错：上一版把 P5 定为“三维气氛 + 火球/闪电/治疗”，未遵守 `docs/design.md:42-56` 的 CPR 优先原则，也没有按 GM 实际操作写明确步骤；现撤销该 P5.0 完成结论并完成补救。
- [x] 重写 `docs/p5_plan.md`：P5 改为“参战者 → 手填先攻 → 轮次 → 分段移动/动作 → 远程攻击距离/DV/遮挡提示 → 保存/结束”的 CPR 战斗操作闭环。
- [x] 同步 `docs/roadmap.md`、`docs/design.md`、`docs/architecture.md` 和 `docs/README.md`；气氛与演出后移为第一版后 CPR 风格候选，不再以奇幻法术定义 P5。
- [x] 明确边界：操作顺序、术语、距离、DV（难度值）和状态提示按 CPR；掷骰、平手重掷、闪避选择、命中、伤害、护甲和最终裁决仍由 GM 完成。
- [ ] P5 功能代码、场景、自动测试、Godot MCP（运行态接口）、Windows 可见窗口和 GM 真人验收均未开始；下一批是 P5.1“稳定实体标识 + 建立参战列表”。

### 四层调研回执与取舍
- [x] 项目现状：`MovementService.begin_preview()`每次重新取得整份 `MOVE（移速）× 2` 预算，尚不能累计分段移动；`CprMovementRuleProvider`已有基础和双倍地形成本；`CombatLinePreview/Query`已有射线与二元遮挡；`PlaythroughController.save_current_session()`已有“快照→索引→提交”保存链；`EntityProperties`只有显示名、没有稳定 `entity_id（实体标识）`。因此 P5 必须先补稳定 ID，再增加唯一战斗状态所有者，并复用而非重写现有三条链。
- [x] CPR 规则：核心规则书 PDF p.144-145、186-187（书内 p.126-127、168-169）确认 2 米/码一格、`MOVE × 2`、先攻降序/平手重掷、每回合一次移动 + 一次其他动作、“跑”和分段移动；PDF p.190-192（书内 p.172-174）确认按武器/距离查 DV、`REF（反应）≥8`可选闪避和各开火模式；PDF p.200-201（书内 p.182-183）确认二元掩体。索引块均为 `needs_pdf_check=false`。
- [x] Godot 源码：精确基线 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`Viewport::push_input()`按 `_input → GUI → _unhandled_input`分发；`ItemList::gui_input()`先 `select()`再发 `item_selected/multi_selected`，最后发 `item_clicked`；`BaseButton::on_action_event()`默认在合格松开时进入 `_pressed()`并发 `pressed`。规划据此要求面板只发意图、消费 GUI 事件、不让点击穿透到地图。
- [x] 官方资料：离线 Godot 4.7 `gdd_0633_ItemList.md`、`gdd_0532_BaseButton.md`确认列表和按钮信号签名及发出语义；P5.1 写代码前仍需按实际节点补查 `SpinBox（数字输入框）`等属性。
- [x] 英文社区：采用 Foundry Combat Tracker（战斗追踪器）的“加参战者→先攻→开始→推进→结束”交互骨架；CPR Encounter Tracker（遭遇追踪器，MIT、96 次提交）只参考 GM 界面；FVTT Cyberpunk RED Core（Foundry CPR 核心系统）只参考术语和数据分层。不采用 Evasion Workflow（闪避工作流）的自动对抗骰/命中/伤害，也不复制社区工具的 HP（生命值）、SP（护甲值）、弹药和严重伤势自动化。

### Godot/项目行为 → 本地规划 → 验证映射
| Godot/项目行为 | P5 本地规划 | 实现后验证 |
|---|---|---|
| `ItemList`先选择再发信号 | 列表显示行不是真值；控制器按稳定 ID 持有参战者 | 排序/重命名后仍指向同一 Token；单击恰好一次 |
| `BaseButton.pressed`默认在松开发出 | 每个按钮只连接一个命令入口 | 按下拖出再松开不误触；正常点击恰好一次 |
| GUI 未处理才进入地图输入 | 战斗面板消费事件，目标选择用独占状态 | 点面板不拖 Token、不旋转相机、不误选目标 |
| 移动服务每次默认取得整份预算 | 战斗控制器传剩余预算，提交后累计实际路径成本 | 三段移动不超 `MOVE × 2`；“跑”后恰为 `MOVE × 4` |
| 战斗线只返回几何结果 | DV 提供器组合距离、武器模式和二元遮挡，仅提示 | 所有表边界通过；永不把“射线清晰”写成“命中” |
| 带团保存先快照后索引 | `Playthrough`版本化增加活跃战斗，不造平行存档 | 同地点重开恢复；故障回滚；切地点清理 |

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-22 | 上一版 P5 规划违反 CPR 优先原则，并把奇幻法术当成核心。 | 已撤销完成结论；主规划及四份交叉文档已重写，开发日志保留违规与补救记录。 |
| 2026-07-22 | 场景实体没有稳定 `entity_id`，无法可靠恢复参战 Token。 | 已列为 P5.1 第一硬门槛；先写迁移/重复/重命名/读回失败测试，再实现。 |
| 2026-07-22 | 当前 Codex 对话未暴露 Godot MCP（运行态接口）。 | 规划任务不依赖 MCP；界面/输入实现不得在缺少 `game_eval`等运行态证据时宣布完整完成。 |
| 2026-07-22 | 气氛和 VFX（视觉特效）目录仍在，但已不属于 P5。 | 目录保留；改列第一版后 CPR 风格候选，不进行功能代码或资产修改。 |

## 2026-07-22 GitHub v0.4.0-p4 版本快照

### 发布范围
- [x] 版本标签定为 `v0.4.0-p4`，表示 P1-P4 功能阶段完成；P5-P9 不包含在本版本完成范围内。
- [x] 纳入当前 P1-P4 源码、场景、自动测试、设计/验收文档、Godot AI（Godot 人工智能）开发插件更新，以及 Native Video v0.2.1 修复版的 Windows debug/release DLL（调试版/发行版动态链接库）。
- [x] 保留 P4.5 已有验收结论：P1 `358/358`，P2/P3 关键回归全部零失败，P4.1 `50/50`、P4.2 `58/58`、P4.3 `146/146`、P4.4 `91/91`、真实 MP4 `36/36`。
- [x] 发布形态保持 Windows 单目录便携应用：一个 ZIP 下载物，解压即用；运行时为 `Gvtt.exe + 约 1.57 MiB Native Video release DLL`，不采用 VLC。

### 仓库清理边界
- [x] `.gitignore` 已排除 `build/`、`tmp/`、`artifacts/`、离线 Godot 源码/文档、导出模板、编辑器本地状态、个人资产、CPR 规则正文与生成阅读包、Python 缓存；这些都不是 GitHub 源码版本的一部分。
- [x] 没有删除上述本地文件，只阻止它们被纳入本次提交。
- [x] 本轮不重跑 Godot；功能代码在 P4.5 已完成自动、Windows 可见窗口和 release（发行版）实跑，本轮只制作可追溯的 GitHub 版本快照。

## 2026-07-22 Codex P4.5 Native Video 修复与最终阶段验收

### 阶段结论
- [x] P4 功能闭环完成：地图 -> 图片 -> 真实 MP4 MV -> 暂停/恢复 -> 返回地图；缺失/损坏媒体、三轮快速切换、切场景、关投屏和退出程序均通过自动及 Windows 可见回归。
- [x] 正式视频格式现为 OGV、MP4、MOV、M4V。WebM/MKV/AVI 仍不支持；VLC 不采用，不再携带约 231.5 MiB VLC 运行库。
- [x] 修复 `claytercek/godot-native-video v0.2.1` 的退出挂死：`DecodeScheduler.shutdown()` 幂等停止线程、清空队列并关闭后端，扩展终止时主动调用，静态析构不再执行危险媒体清理。上游基线提交 `d5491b8484ce36cdb19d01bce79054c96dd52f7d`，修复源码快照位于 `build/p45_acceptance/godot_native_video_source/godot-native-video-0.2.1/`。
- [x] 正式集成位于 `addons/native-video/`、`scripts/native_video_playback_backend.gd`、`scripts/media_registry.gd`、`scripts/player_output_controller.gd`、`scripts/main.gd`、`project.godot` 及 P4.5 测试。debug/release DLL 分别为 `1,733,120` / `1,647,104` 字节，源码目录合计约 3.22 MiB；发行运行只需约 1.57 MiB release DLL。
- [x] Windows D3D12 实播在 NVIDIA `nvwgf2umx.dll` 发生 `0xC0000005`，转储位于 `build/p45_acceptance/formal_p4_5_crash_dump/`；Vulkan 路径完整通过，因此 `project.godot` 正式默认 `rendering_device/driver.windows="vulkan"`。
- [x] 用户已接受 Windows 单目录便携包：提供一个 ZIP，解压即用、无需安装；正式运行结构为 `Gvtt.exe + 约 1.57 MiB release DLL`。严格物理单 EXE、自定义引擎模块和自解压封装不再是待办。
- [ ] 当前 Codex 对话未暴露 Godot MCP 运行态工具，因此没有 `game_eval` 证据；命令行自动回归、Windows 可见窗口和 release 程序实跑均已完成，GM 亲手双屏体感仍需按下方步骤确认。

### 四层调研回执
- [x] 项目现状：正式链路为 `MediaRegistry -> PlayerOutputController -> VideoOutputPresenter -> VideoPlaybackBackend`；Native Video 复用标准 `VideoStreamPlayer`，不改变 P3 输出所有权和清理合同。
- [x] Godot 源码：锁定 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。播放沿 `VideoStreamPlayer::set_stream -> instantiate_playback -> update/mix -> stop`；导出沿 `GDExtensionExportPlugin::_export_file -> add_shared_object -> EditorExportPlatformPC::export_project_data`；运行加载沿 `GDExtensionLibraryLoader::open_library -> OS_Windows::open_dynamic_library -> LoadLibraryExW`。
- [x] 官方资料：Godot 4.7 `VideoStreamPlayer` / `VideoStreamPlayback` / `.gdextension file` 文档确认核心原生格式边界、扩展注册、按 feature tag 选择 debug/release 共享库和依赖复制规则；Microsoft Media Foundation 提供系统 H.264/AAC 解码路径。
- [x] 英文社区/开源：采用 Native Video v0.2.1（MIT、Godot 4.4+、Windows Media Foundation、发行 ZIP 约 4.66 MB）；未采用 Godot VLC（约 231.5 MiB 且门禁失败）、EIRTeam.FFmpeg（更重构建链与 H.264 专利提示）和 GoZen（GPLv3 Alpha 视频编辑器，不是小型播放器插件）。

### 自动与运行验收
- [x] Native Video 类、真实/损坏 MP4 探针 `8/8`；P4.1 媒体登记 `50/50`；P4.2 图片演出 `58/58`；P4.3 OGV 视频演出 `146/146`；P4.4 UI/投屏隔离 `91/91`；P4.5 真实 MP4 `36/36`。
- [x] P1 `358/358`；P2.4 `56/56`；P2.5 Windows Vulkan `54/54`；P2.6 `64/64`；P2 指标 Windows Vulkan `20/20`；P3.1 `79/79`；P3.2 数据/控制器/Windows 可见 `39/39 + 39/39 + 66/66`；P3.3 `47/47`；P3.4 生命周期/Windows 媒体冒烟 `64/64 + 133/133`。
- [x] release 导出成功：正式包位于 `build/p45_acceptance/p4_export_native/`，release DLL SHA-256 `1470EB9B79828FCAB2D430D69AA85C7524B72B00A567A763B9B3C178A12B16C8`，与源 release DLL完全一致，无 VLC/FFmpeg/libav 文件。
- [x] release 运行探针位于 `build/p45_acceptance/p4_export_runtime_probe_project/`：真实外部 MP4 `36/36`、Windows Vulkan、音频峰值约 `-47.44 dB`、暂停位置差 `0.0`、退出码 0，启动前后均无同名残留进程。
- [x] `Unexpected NUL character` 只出现在加载 `godot_ai` 开发插件的测试运行；业务文本扫描无 NUL，最终 release 日志为 0 条。Godot 4.7 报警入口是 `core/string/ustring.cpp`，插件启动时会解析 Windows `netstat/tasklist/PowerShell` 输出；不改第三方开发插件，不把它算作发行问题。

### 源码行为到验证映射
| Godot/插件行为 | 本地实现 | 自动/运行验证 |
|---|---|---|
| `VideoStreamPlayer` 先停旧流、实例化 playback、逐帧更新并混音 | `NativeVideoPlaybackBackend.load_file/play/set_paused/release` | 类探针 `8/8`；编辑器与 release MP4 各 `36/36` |
| 插件解码调度器退出时必须停止线程并关闭后端 | 修复后的 `DecodeScheduler.shutdown()` 与 `uninitialize_native_video_module()` | 最小探针退出码 0；快速切换、关投屏、程序退出后无残留进程 |
| GDExtension 按 release feature 选择并复制共享库 | `addons/native-video/native-video.gdextension` 的 `windows.release.x86_64` | 正式导出 DLL 大小/哈希与源 release DLL一致；release MP4 `36/36` |
| P3 输出控制器唯一持有 MAP/IMAGE/VIDEO，替换前释放旧媒体 | `PlayerOutputController` 按扩展名选择 OGV 或 Native Video 后端 | P3.3 `47/47`、P3.4 `64/64 + 133/133`、P4.3 `146/146`、P4.5 `36/36` |
| Windows 动态库必须是磁盘文件，PCK 嵌入不含共享库 | Godot 标准导出保留相邻 release DLL | 导出产物清单实证；采用单目录便携包，不再要求严格单 EXE |

### GM 可见窗口验收步骤
- [ ] 打开 Godot 4.7 并运行 Gvtt，进入一个模组；左栏“媒体”分别登记正常图片、正常 MP4、损坏 MP4 和移动后缺失的媒体，预期状态清楚且失败不会改变当前玩家画面。
- [ ] 打开投屏，先显示地图，再投放图片，再投放 MP4；预期玩家窗只有内容，GM 控制仍只在主窗。播放中执行暂停/恢复和音量调节，画面应冻结/继续，声音应同步停止/恢复。
- [ ] 连续三次执行“视频 -> 返回地图 -> 视频”，再切地图、关投屏并退出；预期无黑帧、旧声音、遗留播放器或失控窗口。任务管理器中不应留下本轮 Gvtt/Godot 进程。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-22 | Native Video v0.2.1 原版退出挂死。 | 已修复并通过编辑器、Windows 可见及 release 退出门禁；此前“候选否决”结论作废。 |
| 2026-07-22 | D3D12 + NVIDIA 实播访问冲突。 | 正式默认切换 Vulkan；D3D12 转储保留，未伪装为已修复。 |
| 2026-07-22 | Godot 标准 GDExtension 导出不是严格单 EXE。 | 已决策；用户接受 `EXE + 1.57 MiB DLL` 的单目录便携包，不再另立引擎模块移植任务。 |
| 2026-07-22 | 正式验收导出约 822 MB。 | 与 MP4 后端无关；预设 `all_resources` 打入大量测试/个人素材，发布前需单独收紧资源过滤。 |

### 单 EXE 可行性补充（历史调研，当前决策已覆盖）
- [x] 更正“不能融合”的绝对说法：Godot 4.7 的标准 GDExtension 导出不能把 Windows DLL 嵌入 PCK 或 exe，但可以把 Native Video 适配层移植为自定义 C++ 引擎模块，并重新编译 Windows editor/release template，从而得到运行时不释放 DLL 的真正单 exe。
- [x] 源码依据：`GDExtensionExportPlugin::_export_file()` 登记共享库，`EditorExportPlatformPC::export_project_data()` 把它复制到 exe 同目录，`OS_Windows::open_dynamic_library()` 最终使用 `LoadLibraryExW`；官方 4.7 `Custom modules in C++` 文档提供 `custom_modules` 编译入口并要求重编运行所需导出模板。
- [x] 当前 Native Video 约 7060 行/50 个 C++ 文件，其中 19 个文件直接包含 `godot_cpp` 头；Windows Media Foundation 解码核心可复用，主要工作是把 GDExtension 绑定层改为引擎内部类、建立自定义模板构建和完整回归，不是从零重写播放器，也不是一项导出开关。
- [x] 自解压/SFX 可把 exe 与 DLL 包成一个下载文件，但启动时仍会释放临时文件，并带来杀毒误报、崩溃残留和更新问题；它属于“单文件分发”，不等于真正静态融合。
- [x] 2026-07-22 用户决定不再把严格物理单 EXE 作为硬约束，不启动引擎模块移植或自解压封装。标准发布目录为：

```text
Gvtt/
├─ Gvtt.exe
├─ native-video.windows.template_release.x86_64.dll
└─ licenses/native-video.txt
```

- [x] ZIP 是面向用户的单一下载物；内置资源仍随 PCK/EXE 发布，原生 DLL 与 EXE 相邻，用户模组和媒体留在用户内容目录。
- [x] P1-P4 功能阶段全部完成；P5 及后续产品阶段尚未开始。GM 亲手双屏观感仅保留为非阻塞体验确认，不改变 P4 完成状态。

## 2026-07-22 Codex P4.5 回归与阶段验收

### 验收结论
- [x] P4 原生 OGV 产品边界已形成完整闭环：地图 -> 图片 -> MV -> 暂停/恢复 -> 返回地图；媒体登记、图片演出、视频演出、GM/玩家窗口隔离、幕管理以及 P1/P2/P3 关键回归均通过，所有结构化结果均为 `failed: 0`。
- [x] 异常闭环已有自动与运行态证据：缺失/损坏媒体、快速切换、切场景、关闭投屏、退出测试场景后，旧 Presenter、纹理、播放器、完成信号、原生玩家窗口和声音均按合同释放；主场景清理探针为玩家窗口 `0`、媒体节点 `0`、`Media` 总线索引 `-1`、音频峰值 `-200 dB`。
- [ ] P4 路线图尚不能无条件整阶段勾完：Godot VLC 仍未完成 Godot 4.7、Windows 原生投屏窗口、导出包、清理链和许可证隔离实验。当前继续只承诺 OGV；MP4/MOV/WebM/MKV/AVI 仍为“暂不支持”。除非明确把 VLC 实验移出 P4，否则 P4 的最终状态是“核心闭环通过，扩展格式门禁未完成”。

### 四层依据与采用范围
- [x] 项目现状：交叉核对 `docs/design.md`、`docs/CCxGodot.md`、`docs/roadmap.md`、`project.godot`、`scenes/main.tscn`、`scripts/main.gd`、P4 Presenter/Backend/Controller、P4.1-P4.4 测试及既有日志；前置 P4.1-P4.4 均已有代码、专项测试、Windows 可见运行和开发日志证据。
- [x] Godot 源码：精确基线 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`；复用既有完整对照链 `Image::load_from_file()` -> `ImageLoader::load_image()`、`TextureRect::_notification()`/纹理释放、`VideoStreamPlayer::set_stream()` -> Theora `instantiate_playback()/set_file()/update()/stop()`、音频混合回调注册/移除、`Window::_event_callback()` -> `_clear_window()`。
- [x] 官方资料：复用离线 4.7 `Playing videos`、`Runtime file loading and saving`、`Image`、`ImageTexture`、`TextureRect`、`VideoStreamPlayer`、`VideoStreamTheora`、`AudioServer`、`Window` 文档；原生正式边界仍是 Ogg Theora `.ogv`，常见格式需要扩展或转码。
- [x] 英文社区/开源：复用已核查的 Godot VLC 1.2.0、EIRTeam.FFmpeg、Godot issue #92050、`random_image_viewer` 与 `stable_diffusion_image_viewer`。图片加载/等比/补间模式可复用；VLC/FFmpeg 因原生库、导出、许可证与清理链尚未隔离验证，本轮不安装、不宣称支持。

### 自动回归与 Windows 可见验收
- [x] P1：`P1_RUNTIME_RESULT 358/358`。
- [x] P2.4：`P2_4_COMBAT_RESULT 56/56`；P2.5 Windows：`P2_5_LOS_RESULT 54/54`；P2.6：`P2_6_WALL_RESULT 64/64`；P2 指标 Windows：`P2_ACCEPTANCE_METRICS 20/20`，投屏窗口可见。
- [x] P3.1：`P3_1_MODULE_MANIFEST_RESULT 79/79`；P3.2 数据/控制器/Windows：`39/39`、`39/39`、`66/66`；P3.3：`47/47`；P3.4 生命周期/Windows：`64/64`、`133/133`。
- [x] P4.1 媒体登记：无窗口与 Windows 均 `43/43`；P4.2 图片演出 Windows：`58/58`、`frames_drawn=493`；P4.3 视频演出 Windows：`146/146`、`pause_position_delta=0.0`、`frames_drawn=9122`；P4.4 幕与 UI/投屏隔离：无窗口 `77/77`、Windows `91/91`。
- [x] P4.4 经 Godot MCP（Godot 运行态接口）再次运行：会话 `gvtt@6ddd`，运行 `r14206486-4`，`91/91`，正常退出，无启动或运行错误。
- [x] P4.3 经 Godot MCP 再次运行：`r14254504-5` 与 `r14298715-6` 均为 `146/146`、暂停位置增量 `0.0`。播放中 `game_eval` 实测 `active_kind=VIDEO`、`phase=PLAYING`、投屏已开、玩家窗口 `1`、`Media` 总线索引 `1` 且未静音、后端有流/视图且正在播放、未释放、`finished` 信号已连接、播放位置约 `5.8149 s`。
- [x] 正式主场景清理探针：启动后位于 `res://scenes/module_home.tscn`，玩家窗口 `0`、媒体节点 `0`、`Media` 总线索引 `-1`、音频峰值 `-200 dB`；项目正常停止，最终游戏日志仅有 Helper 注册，编辑器回到 `ready/stopped`。
- [x] 产出物位于 `build/p45_acceptance/`：每个专项都有隔离用户目录和 `godot.log`，P2 指标另有 `p2_acceptance_metrics.json`。

### Godot 源码行为 -> 本地实现 -> 自动测试/运行验证
- [x] 图片真实解码、等比居中和纹理释放 -> `MediaRegistry._inspect_image()`、`ImageOutputPresenter.prepare()/activate()/release()` -> P4.1 合法/缺失/损坏登记，P4.2 两种窗口比例、淡入淡出、快速返回与十轮释放。
- [x] `VideoStreamPlayer.set_stream()` 先停旧流再实例化后端，退树停止并移除音频混合回调 -> `NativeOgvPlaybackBackend.load_file()/stop()/release()` 与 `VideoOutputPresenter.release()` -> P4.3 播放、暂停、恢复、停止、自然结束、十轮快速切换、关投屏与退出清理，MCP 播放中状态和主场景清理探针。
- [x] `AudioServer` 运行时总线、音量、静音和峰值 -> 产品 `Media` 总线及 GM 音量控制 -> P4.3 音量/静音/峰值断言，清理后总线索引 `-1`、峰值 `-200 dB`。
- [x] `Window.close_requested` 只发请求，原生窗口最终由 `_clear_window()` 删除 -> `CastView` 转交 `PlayerOutputController.close_output()`，先释放媒体/地图 Presenter 再释放窗口 -> P3.4/P4.3/P4.4 的关闭、切场景、退出、窗口计数和残留节点断言。
- [x] Godot 不提供 Gvtt 的 GM/玩家内容路由和幕语义 -> `PlayerOutputController`、`ActManagementController` 与 `main.gd` 负责选择、投放、错误隔离和返回地图 -> P4.4 无地图幕、重复投放、跨幕复用、按钮状态、玩家端无 GM 控件/路径/堆栈验证。

### 未做与问题状态
- [x] 本轮 P4.5 没有修改功能代码、场景、测试或真实模组数据；验收使用现有实现和隔离目录，避免为了“通过验收”改变被验对象。
- [ ] 未由 Codex 冒充 GM 完成人工桌边体感判断；Windows 可见自动专项已完成，但真实双屏布局、声音观感和连续操作效率仍需 GM 在 Godot 可见窗口中确认。
- [ ] 未安装或验证 Godot VLC，也未制作导出包验证 MP4；原因是这是独立原生扩展、导出和许可证工作，现有 OGV 通过不能替代该证据。
- [x] 编辑器现存非阻塞警告：`module_io.gd` 枚举转换、`media_registry.gd` 三元类型、`module_gate.gd` 名称遮蔽、抽象 Presenter/Backend 未使用信号，以及 P4.3 测试的名称遮蔽/整数除法；本轮运行无对应失败，按验收范围不顺手修改。

| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-22 | P4 核心媒体闭环与 VLC 常见格式实验在路线图中同属 P4，但证据范围不同。 | 原生 OGV 核心闭环通过；VLC 复选框保持未勾选，未把 OGV 结果冒充 MP4 支持。 |
| 2026-07-22 | 损坏图片和故意缺失场景会写入 Godot 引擎错误日志。 | 属于专项主动触发的异常路径；结构化结果均 `failed: 0`，产品 UI 不暴露路径或堆栈。 |

## 2026-07-21 Codex P4.2 图片演出

### 前置与四层调研回执
- [x] P4.1 前置通过：媒体登记专项 `43/43`、P3.1 `77/77`、主界面可见回归 `62/62` 已写入日志；GM 本轮明确 P4.1 已完成。
- [x] 项目现状：P3 已有 `PlayerOutputController.show_image()` -> `ExternalContentResolver` -> `ImageOutputPresenter.prepare()/activate()` -> 失败释放并恢复地图的链，P3.4 已用四象限固定 PNG 在 `1280 x 720` 与 `1024 x 768` 投屏窗口取像素；真正缺口是 P4.1 媒体列表没有投放/返回入口、GM 未监听失败、图片没有淡入淡出。
- [x] Godot 4.7 源码：精确基线 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`Image::load_from_file()` -> `ImageLoader::load_image()` -> `FileAccess::open()`/扩展加载器解码；`ImageTexture::create_from_image()/set_image()` -> `RenderingServer::texture_2d_create()`；`TextureRect::_notification()` 按较小缩放比计算目标宽高并居中；`TextureRect::set_texture(null)` 断开纹理变化信号，`ImageTexture::~ImageTexture()` 最终 `free_rid()`；`SceneTree::create_tween()` 注册补间，`Tween::bind_node()/kill()` 负责绑定和终止。
- [x] 官方资料：离线 4.7 `gdd_0762_TextureRect.md` 确认 `EXPAND_IGNORE_SIZE` 与 `STRETCH_KEEP_ASPECT_CENTERED`；`gdd_0525_AspectRatioContainer.md` 确认其 `STRETCH_FIT` 是对子控件再做比例约束；`gdd_0947_Image.md`、`gdd_0948_ImageTexture.md`、`gdd_1518_Tween.md` 确认外部图片、运行时纹理和补间生命周期接口。
- [x] 英文社区/开源：`michal2229/random_image_viewer`（Godot 4.4、MIT、最后推送 2025-06）使用 `Image.load_from_file()` -> `ImageTexture.create_from_image()`，但静态纹理缓存与十轮释放目标冲突；`vr-voyage/stable_diffusion_image_viewer`（Godot 4.0、MIT、最后推送 2023-01）采用 `STRETCH_KEEP_ASPECT_CENTERED` 与 `create_tween()`；Godot 英文论坛 2024/2025 的运行时图片帖子同样使用该加载链。没有成熟且值得引入的图片演出插件，因此复用模式、不新增依赖。
- [x] 社区来源：<https://github.com/michal2229/random_image_viewer>、<https://github.com/vr-voyage/stable_diffusion_image_viewer>、<https://forum.godotengine.org/t/image-loading-from-user/64976>、<https://forum.godotengine.org/t/load-a-texturerect-texture-into-the-code/102608>。

### 已实现
- [x] `scripts/main.gd` 媒体区新增投屏状态、每张图片的“投放”按钮和“返回地图”按钮；点投放时若投屏未开则自动打开，成功后显示当前图片名称，失败时 GM 主窗口保留“图片投放失败”友好文案，不显示源路径或堆栈。
- [x] `scripts/image_output_presenter.gd` 新增 `0.18 s` 淡入；返回地图时先终止旧淡入，再创建绑定自身生命周期的短命淡出叠层，控制器立即恢复地图，叠层结束后自动释放纹理引用和节点。关闭投屏、切媒体、失败和切场景不创建淡出残留。
- [x] `scripts/player_output_controller.gd` 只把 `return_to_map` 原因传入既有释放链；请求 ID、失败回退、视频完成、媒体/地图/窗口清理顺序均保持原合同。
- [x] 未增加 `AspectRatioContainer`：Godot 4.7 `TextureRect::_notification()` 已实现同等的等比居中计算，重复容器没有收益；宿主黑底自然形成上下或左右黑边。
- [x] 新增 `tests/p4_2_image_presentation_regressions.gd/.tscn`：真实 Windows 双窗口覆盖正常图片、淡入、`1280 x 720` 左右黑边、`1024 x 768` 铺满、淡出返回地图、快速返回、缺失/损坏、错误文案不含路径/堆栈、十轮切换后 Presenter/纹理/淡出节点归零。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] `ImageLoader::load_image()` 真实打开并解码 -> `ImageOutputPresenter.prepare()` 每次请求创建独立 `Image/ImageTexture` -> 合法 PNG、缺失 PNG、损坏 PNG 专项验证。
- [x] `TextureRect::_notification()` 等比居中 -> `EXPAND_IGNORE_SIZE + STRETCH_KEEP_ASPECT_CENTERED` -> 两种投屏比例逐像素验证黑边与四象限方向，无拉伸。
- [x] `SceneTree::create_tween()`/`Tween::bind_node()/kill()` -> Presenter 淡入和短命淡出叠层 -> 测试检查初始透明、最终不透明、返回后叠层归零和快速返回无旧回调。
- [x] `TextureRect::set_texture(null)` 与 `ImageTexture::~ImageTexture()` 释放引用/RID -> Presenter 先清控件纹理再清 `ImageTexture/Image`，淡出只延长一个短命引用 -> 十轮后所有图片输出组归零。
- [x] Godot 不知道 Gvtt 的 MAP/IMAGE 路由和 GM/玩家双窗口 -> `PlayerOutputController` 失败后统一恢复地图，`main.gd` 只向 GM 显示安全消息 -> 专项检查玩家端仍有安全地图，消息不含 `user://`、`res://` 或 `Stack Trace`。

### 自动测试与可见窗口
- [x] P4.2 Windows 可见专项：MCP 运行 `r1469037-2`，`P4_2_IMAGE_PRESENTATION_RESULT {"assertions":56,"failed":0}`，`display_server=Windows`、`frames_drawn=744`、固定 PNG SHA-256 `6cad696fde8ff9f226297d8637a3af20dea4787b4aeee28ea81d17c5c0e1a14b`。
- [x] P3.4 生命周期合同：运行 `r1503974-3`，`64/64`；P3.4 Windows 可见媒体冒烟：运行 `r1528786-4`，`133/133`、`frames_drawn=6779`、音频峰值约 `-8.97 dB`、视频时长约 `1.2333 s`。
- [x] 邻接回归：P4.1 `43/43`（`r1565539-5`）、P3.3 `47/47`（`r1586662-6`）、P3.2 完整主界面可见回归最终 `62/62`（`r1756518-8`）。所有场景自行退出，Godot 编辑器最终 `ready/stopped`，仅保留编辑器进程，无残留游戏进程。
- [x] 损坏 PNG 与伪 OGV 的引擎错误是测试主动触发；产品 `output_failed` 文案不含路径/堆栈。新增脚本无 `:=`、变量均有静态类型；相关差异格式检查通过。
- [x] GM 手动可见验收完成：2026-07-21 GM 实际确认图片投放与返回地图“好像没什么问题”；结合自动失败专项，P4.2 的“地图 -> 图片 -> 返回地图”、比例/黑边、淡入淡出及失败安全回退验收收口。

### 未做与问题状态
- [x] 未实现播放列表、缩略图、搜索排序或复杂转场；P4.2 只交付最小淡入淡出。
- [x] 未实现视频暂停、音量、正式控制入口、独立媒体音频总线或 VLC；这些仍属于 P4.3/P4.4，未提前勾选。

| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-21 | Godot 解码损坏 PNG 时仍会在引擎错误通道打印真实测试路径。 | 产品 UI 只消费安全业务消息；P4.2 自动测试明确断言 GM 消息不含路径/堆栈，玩家端恢复地图。 |
| 2026-07-21 | 淡出期间需要短暂保留一份纹理引用，否则立即释放会让淡出消失。 | 采用绑定淡出节点的 `0.18 s` 短命引用；十轮切换后节点与引用归零，不做长期缓存。 |

## 2026-07-21 Codex P4.1 桌面验收素材

### 已完成
- [x] 使用内置图片生成工具生成三张无文字、无水印、不同宽高比的 P4.1 登记测试图：奇幻酒馆俯视横图 `1536 x 1024`、赛博街巷俯视宽图 `1672 x 941`、赛博角色竖图 `1024 x 1536`；逐张打开确认非空且内容正常。
- [x] 把项目自产并通过 P3.4 播放验证的带声音 OGV 复制到同一桌面目录；副本为 `320 x 180`、57,349 字节，SHA-256 `29bd2b2f63f2e3155a093c4bc142eec8c3dfa78d6d2f66b23f368f0856d93119`，与固定夹具一致。
- [x] 产出目录：`C:/Users/Admin/Desktop/Gvtt_P4_测试素材/`；包含三张 PNG 和一段 OGV，未修改 P4.1 功能代码、场景、测试或真实模组数据。

## 2026-07-21 Codex P4.1 媒体登记

### 前置与四层调研回执
- [x] 前置通过：本文件上一条 P4.0 已完成四层调研、Godot `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88` 源码对照和 OGV 回退结论；旧位置的 P4.0 未勾选项属于阶段启动时历史状态，不再代表当前状态。
- [x] 项目现状：`ModuleManifest.external_contents` 已保存稳定 ID、类型、显示名、来源类型、路径和元数据；`ExternalContentResolver` 已区分外部绝对路径与模组相对路径并拒绝 `..` 逃逸；真正缺口是登记/重命名/删除事务、四态检查和 GM 左栏入口。
- [x] Godot 4.7 源码：`scene/gui/file_dialog.cpp::FileDialog::_action_pressed()` 验证文件后发 `file_selected`；`core/io/image.cpp::Image::load_from_file()` -> `core/io/image_loader.cpp::ImageLoader::load_image()` 按扩展名选择加载器并解码；`scene/gui/video_stream_player.cpp::set_stream()` -> `modules/theora/video_stream_theora.cpp::VideoStreamTheora::instantiate_playback()` -> `VideoStreamPlaybackTheora::set_file()/find_streams()/read_headers()` 打开 OGV、识别流并要求三组 Theora 头。
- [x] 官方资料：离线 4.7 `FileDialog`、`Button`、`Label`、`VBoxContainer`、`MenuButton`、`PopupMenu`、`Image`、`Runtime file loading and saving`、`Playing videos`、`VideoStream` 和 `VideoStreamPlayback` 文档确认本轮属性、方法、信号与运行时外部图片/OGV边界；官方 demo 仓库只找到 `misc/multiple_windows/scenes/file_dialog/file_dialog.tscn`，没有可直接复用的媒体登记库。
- [x] 英文社区/插件：Godot VLC `v1.2.0`（2026-05-09，Godot 4.3+，Windows/Linux，LGPL-2.1，仓库 2026-07-09 仍更新）支持外部文件但使用独立 `VLCMedia/VLCMediaPlayer` 和原生库；EIRTeam.FFmpeg 最新自动构建为 2025-11-12、Godot >4.1、MIT，但原仓库明确提示 H.264 专利风险和更重构建链。两者均不进入 P4.1。

### 已实现
- [x] 新增 `scripts/media_registry.gd`：统一返回 `可播放/缺失/损坏/暂不支持`；图片按 Godot 4.7 支持扩展名实际解码并记录宽高，OGV 通过临时 `VideoStreamPlayer` 实例化 Theora 后端并要求非零纹理尺寸，探查后立即清空流并释放；MP4/MOV/WebM/MKV/AVI 只登记为暂不支持，不宣传可播放。
- [x] 扩展 `ModuleGate`：登记、重命名和删除都遵循“复制候选清单 -> `save_manifest_recoverable()` -> 成功后替换当前真值”；保存失败不污染内存。删除只移除引用，不删除源文件；新增 `external_contents_changed` 供 UI 刷新。
- [x] `scripts/main.gd` 左栏新增“媒体”折叠节：登记图片、登记视频、刷新状态；每条显示名称、类型、来源和状态，并通过 `⋮` 菜单重命名或删除登记。重命名不移动原文件，删除登记不删除原文件。
- [x] `FileDialog` 使用 `ACCESS_FILESYSTEM`、`FILE_MODE_OPEN_FILE`、4.7 格式过滤器和 `file_selected(path)`；图片过滤 BMP/JPEG/PNG/SVG/TGA/WebP，视频过滤 OGV 与常见候选格式，后者按 OGV 回退策略显示状态。
- [x] 新增 `tests/p4_1_media_registration_regressions.gd/.tscn`，复用项目自产固定 PNG/OGV，在隔离 `user://` 创建临时模组和外部文件，结束后清理，不接触真实模组。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] `FileDialog::_action_pressed()` 只在文件存在时发 `file_selected` -> `main.gd::_show_media_file_dialog/_on_media_file_selected` -> 可见窗口手动选择图片/视频，取消不新增条目。
- [x] `Image::load_from_file()` -> `ImageLoader::load_image()` 实际解码 -> `MediaRegistry._inspect_image()` -> 自动测试覆盖合法 PNG 与损坏 PNG，宽高元数据为 `640 x 480`。
- [x] `VideoStreamPlayer::set_stream()` -> Theora `set_file/find_streams/read_headers` -> `MediaRegistry._inspect_video()` 只探查、不播放、立即释放 -> 自动测试覆盖合法 `320 x 180` OGV、伪 OGV 和 MP4 暂不支持。
- [x] Godot 不提供模组媒体清单或四态业务 -> `ModuleGate` 复制候选清单并可恢复保存 -> 自动测试覆盖登记、稳定 ID 重命名、删除登记不删源文件、路径逃逸、关闭重开。
- [x] 外部解码对象不进入 `ResourceLoader` 缓存，清单只序列化引用/元数据 -> `ModuleManifest.to_json_dict()` 维持既有合同 -> 自动测试用唯一媒体字节标记确认 `manifest.json`、`session.json` 和 `.scn` 均不含媒体字节。

### 自动测试与可见窗口
- [x] Godot 4.7 无窗口导入：退出码 0、无超时、0 转储、无残留；日志 `build/crash_matrix/20260721_101803_original_direct/godot.log`。
- [x] P4.1 专项：`P4_1_MEDIA_REGISTRATION_RESULT {"assertions":43,"failed":0}`；退出码 0、无超时、0 转储、无残留；日志 `build/crash_matrix/20260721_101833_original_direct/godot.log`。损坏 PNG 和伪 OGV 的引擎错误是测试故意触发的失败路径。
- [x] P3.1 清单回归：`77/77`；日志 `build/crash_matrix/20260721_101930_original_direct/godot.log`。
- [x] Windows 可见主界面/带团回归：`62/62`、`window_observed=true`、退出码 0、无超时、0 转储、无残留；日志 `build/crash_matrix/20260721_102014_original_direct/godot.log`。证明新左栏构建未静默中断旧 UI 与带团流程。
- [ ] GM 手动验收仍需执行：从模组首页打开任一模组 -> 左栏展开“媒体” -> 点“＋ 图片”选正常图片 -> 点“＋ 视频”分别选 OGV 与 MP4 -> 确认列表显示名称/类型/来源及“可播放/暂不支持” -> 在系统中移动一个已登记文件后点 `↻`，确认变“缺失” -> 用 `⋮` 重命名和删除登记，确认原文件未改名、未删除。

### 未做与问题状态
- [x] 未复制、转码或缓存媒体字节；未修改 `session.json` 或 `.scn` 数据合同；未实现缩略图、搜索、排序、播放、暂停、音量、淡入淡出或播放列表，这些属于 P4.2-P4.4。
- [x] 未安装 Godot VLC 或 FFmpeg；VLC 未通过 P4.3 的 Godot 4.7、Windows 双窗口、导出、清理和许可证验证前，MP4/MOV/WebM/MKV/AVI 继续显示“暂不支持”。

| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-21 | 实际解码损坏 PNG/伪 OGV 时 Godot 会把预期失败写入错误日志。 | 已由结构化测试结果区分：最终 `43/43`；产品 UI 只显示“损坏”，不显示路径堆栈。 |
| 2026-07-21 | 大型 OGV 状态刷新需要读取并解析头部，文件很多时可能产生短暂等待。 | P4.1 采用正确性优先的同步检查；后续只有实测出现可感知卡顿时再引入后台探查，不提前增加线程复杂度。 |

## 2026-07-21 Codex P4.0 前置调研与源码对照

### 已完成
- [x] 触发现成方案调研和 Godot 4.7 源码一致性门禁；调研完成前未修改功能代码、场景、测试或模组数据。
- [x] 核查 `docs/roadmap.md`、`docs/p3_player_output_contract.md`、`docs/p3_lifecycle_test_contract.md`、`project.godot`、`scenes/main.tscn`、`scripts/main.gd`、`scripts/player_output_controller.gd`、`scripts/image_output_presenter.gd`、`scripts/video_output_presenter.gd`、`scripts/video_playback_backend.gd`、`scripts/native_ogv_playback_backend.gd`、`scripts/cast_view.gd` 和当前开发日志，确认 P3 只交付 MAP/IMAGE/VIDEO 输出合同、测试图片和原生 OGV 最小证明；P4 才交付正式媒体登记、播放控制、音量、淡入淡出和常见格式实验。
- [x] 锁定本地 Godot `4.7-stable` 源码包；`version.py` 为 `major=4`、`minor=7`、`patch=0`、`status=stable`。从 `reference/godot-4.7-stable-full.zip.zip` 临时抽取媒体/窗口/音频源码到 `tmp/p4_godot_source_probe/` 便于逐行对照，不作为项目功能产物。
- [x] 完成源码对照：`VideoStreamPlayer::_notification()` 进树注册 `AudioServer.add_mix_callback`，退树先 `stop()` 再移除混音回调；`VideoStreamPlayer::set_stream()` 先停旧流、断开旧流变化信号，再 `instantiate_playback()`；`VideoStreamPlaybackTheora::set_file()` 用 `FileAccess.open()` 读文件并要求存在视频流；`update()` 解码 Theora 帧并送 Vorbis 音频；`Window::_event_callback()` 的关闭事件只发 `close_requested`，真正原生窗口释放在 `_clear_window()` 调 `delete_sub_window()`。
- [x] 核查离线文档 `Playing videos`、`Runtime file loading and saving`、`TextureRect`、`AspectRatioContainer`、`VideoStreamPlayer`、`VideoStreamTheora`、`AudioServer`、`Window`、`FileDialog`：Godot 核心只原生支持 Ogg Theora `.ogv`，常见格式需要 GDExtension 插件；`TextureRect.expand_mode/stretch_mode`、`AspectRatioContainer.ratio/stretch_mode`、`FileDialog.file_mode/access/add_filter`、`Window.title/size/position/close_requested` 为 4.7 现行接口。
- [x] 核查英文社区/插件：Godot VLC v1.2.0 是 Godot 4.3+、Windows/Linux、LGPLv2.1 候选，尚未验证 Gvtt 的 Godot 4.7、Windows 原生投屏窗口、导出包、清理链和许可证说明；FFmpeg/GDExtension 类方案同样需要原生库和导出验证，不能替代 P4 自有媒体库、输出路由和生命周期控制。

### 源码行为映射
- [x] `VideoStreamPlayer.set_stream()` 先停旧流再实例化后端 -> `NativeOgvPlaybackBackend.load_file()/release()` 必须保持“停播 -> 清空 stream -> 断信号 -> 释放节点”顺序 -> P4.3/P4.5 需要十轮快速切换和播放中关投屏验证。
- [x] `VideoStreamPlayer.stop()` 只归零位置，官方文档说明不会自动把首帧变成当前帧 -> P4 不能依赖停播残留画面，必须切回黑底或地图 -> 可见验收检查无黑帧残留、无旧帧误显示。
- [x] Theora 后端必须实际解析出视频流和非零纹理尺寸 -> P4 不能凭扩展名或节点存在宣布视频可播 -> 测试覆盖缺失、伪 OGV、首帧超时和自然结束。
- [x] `AudioServer` 支持运行时总线、音量和峰值读取 -> P4 应建立独立 `Media` 总线，不继续把正式媒体混进 `Master` 冒烟路径 -> 验证音量、静音、峰值和释放后无残留声音。
- [x] `Window.close_requested` 只是关闭请求 -> `CastView` 必须继续转给 `PlayerOutputController.close_output()`，先释放媒体和地图 Presenter，最后释放原生 `Window` -> 验证窗口关闭、切场景和退出程序顺序。

### P4 分批计划
- [x] P4.1 媒体登记：基于现有 `ExternalContentRef/Resolver` 做 GM 文件选择、登记、重命名、删除、缺失/损坏/可播状态；只保存路径和元数据，不保存媒体字节。
- [x] P4.2 图片演出：复用 `ImageOutputPresenter`，补 GM 可操作入口、淡入淡出、错误提示和两种窗口比例可见验证；保持 `TextureRect.EXPAND_IGNORE_SIZE` 与 `STRETCH_KEEP_ASPECT_CENTERED`。
- [ ] P4.3 视频演出：先巩固原生 OGV 后端的播放、暂停、恢复、停止、自然结束、音量和清理；建立 `Media` 音频总线；Godot VLC 只做隔离适配实验，不通过导出和清理验证前不进入正式支持列表。
- [ ] P4.4 GM 控制界面：主窗口提供媒体列表、状态、播放控制、音量和返回地图；玩家窗口只显示地图/图片/视频，不显示 GM 控件或路径/堆栈错误。
- [ ] P4.5 回归验收：覆盖重复切换、快速取消、失败回退、切场景、关投屏、窗口关闭、退出程序和 P1/P2/P3 回归；最终由 GM 可见完成“地图 -> 图片 -> 视频 -> 暂停/恢复 -> 返回地图”。

### 未做
- [x] 没有修改功能代码、场景、测试或模组数据。
- [x] 没有运行 Godot 自动测试或可见窗口测试；本轮是 P4.0 调研与源码对照。
- [x] 没有承诺 MP4/MOV/WebM 已支持；Godot VLC、FFmpeg/GDExtension 和常见格式播放仍是 P4.3 隔离实验候选。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-21 | Godot VLC 能播放常见格式，但尚未验证 Gvtt 的 4.7、Windows 原生投屏窗口、导出包、许可证说明和清理链。 | 候选；P4.3 隔离实验通过前不写入正式支持，不宣传 MP4/MOV/WebM。 |
| 2026-07-21 | `VideoStreamPlayer.stop()` 不保证当前画面回到首帧，依赖停播残留会造成黑帧或旧帧误判。 | P4 采用显式黑底/地图回退，并把旧帧残留纳入 P4.5 可见验收。 |
| 2026-07-21 | 当前 P3 原生后端只接受 `.ogv`，`VideoPlaybackBackend.set_paused()` 已有接口但尚无 GM 控制闭环。 | P4.3 先补正式 OGV 控制和 `Media` 总线，再决定是否接入 VLC 适配器。 |

## 2026-07-21 Codex P4 推进对话稿

### 已完成
- [x] 核查 `docs/roadmap.md`、`docs/p3_player_output_contract.md`、`docs/p3_lifecycle_test_contract.md` 和最新开发日志，确认 P4 当前目标仍是“媒体演出闭环”，不是重做 P3。
- [x] 新增 `docs/p4_dialogue_prompts.md`，按“总控对话 -> P4.0 前置调研与源码对照 -> P4.1 媒体登记 -> P4.2 图片演出 -> P4.3 视频演出 -> P4.4 GM 控制界面 -> P4.5 回归验收”生成可复制推进文本。
- [x] 对话稿明确写入 P4.0 必须先做四层调研、Godot 4.7 源码对照和 VLC 兼容/许可证验证；调研完成前禁止修改功能代码。
- [x] 对话稿明确防止误判：P3 只完成 MAP/IMAGE/VIDEO 输出合同和测试图片/OGV 最小证明，正式图片/MV 登记、控制、音量、淡入淡出和常见格式实验归 P4。

### 未做
- [x] 本轮没有修改功能代码、场景、测试或模组数据。
- [x] 本轮没有运行 Godot 自动测试；只生成推进对话稿和更新开发日志。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-21 | 后续推进容易直接从 P4.1 写代码，跳过媒体后端、窗口和音频清理的源码对照。 | 已把 P4.0 单独列为第一段必跑对话，要求调研完成前禁止改功能代码。 |
| 2026-07-21 | P4 可能被误写成“支持 MP4”。 | 对话稿已要求 VLC 通过 4.7、Windows 投屏、导出包和许可证验证前，不得承诺 MP4/MOV/WebM。 |

## 2026-07-21 Codex P3 复盘与 P4 布置

### 已完成
- [x] 交叉核查 `docs/roadmap.md`、`docs/README.md`、`docs/design.md`、`docs/CCxGodot.md`、`project.godot`、`scenes/main.tscn`、`scripts/main.gd`、`.agents/skills/`、`.codex/` 和 `addons/`，确认当前真值以 2026-07-21 路线图、文档入口和最新开发日志为准。
- [x] 确认 2026-07-19 日志中的 P3 阻塞记录已经被 2026-07-20/21 的完成记录取代，不能再当作当前状态；`docs/README.md` 已明确旧日志只作历史。
- [x] 确认 P3 当前收口证据：P3.4 无窗口 `64/64`、Windows 可见 `133/133`，P1 `352/352`、P2.4 `56/56`、P2.5 `54/54`、P2.6 `64/64`、P2 指标 `20/20`、P3.1/P3.2/P3.3 均有对应回归；P3.2 后续多桌入口调整为 P3.1 `77/77`、P3.2 数据层 `39/39`、控制器 `39/39`、可见主界面 `62/62`。
- [x] 确认当前代码里已存在 P3 输出骨架：`PlayerOutputController`、`MapOutputPresenter`、`ImageOutputPresenter`、`VideoOutputPresenter`、`VideoPlaybackBackend`、`NativeOgvPlaybackBackend` 和 `CastView`；`scripts/main.gd` 已接入 `_player_output_controller` 和 `_playthrough_controller`。
- [x] 布置 P4 为“媒体演出闭环”：从 P3 的测试图片/OGV 最小证明升级到 GM 可登记、播放、暂停、停止、调音量、淡入淡出、返回地图并可靠清理的桌边图片/MV 工作流。

### P4 起步边界
- [ ] P4.0 前置调研与源码对照：复核 Godot 4.7 `VideoStreamPlayer`、`TextureRect`、`AudioServer`、`Window` 清理链，隔离验证 Godot VLC 在 Godot 4.7、Windows 原生投屏窗口、导出包和许可证上的可用性；失败时保留 OGV 回退，不虚报 MP4 支持。
- [ ] P4.1 媒体登记：把外部图片/视频登记进当前模组，显示名称、类型、来源、缺失/损坏/可播放状态；不把媒体字节塞进存档。
- [ ] P4.2 图片演出：图片保持宽高比，支持淡入淡出、返回地图、缺失/损坏失败提示和双窗口显示验证。
- [ ] P4.3 视频演出：视频支持播放、暂停、恢复、停止、自然结束、音量和返回地图；音频走独立产品总线，切媒体、切场景、关投屏和退出时停止声音并释放实例。
- [ ] P4.4 GM 控制界面：主窗口提供媒体选择和播放控制，玩家投屏只显示地图/图片/视频，不显示 GM 控件。
- [ ] P4.5 回归与可见验收：覆盖重复切换、快速取消、失败回退、声音清理、窗口关闭和退出；最终由 GM 连续完成“地图 -> 图片 -> MV -> 暂停/恢复 -> 返回地图”。

### 未做
- [x] 本轮没有修改功能代码、场景、测试或模组数据。
- [x] 本轮没有运行 Godot 自动测试；这是状态复盘和阶段布置，未改变运行行为。
- [x] 没有承诺 MP4/MOV/WebM 已支持；正式常见格式必须等 P4 隔离实验通过。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-21 | 旧日志顶部仍保留 2026-07-19 的 P3 阻塞记录，单看文件开头容易误判当前阶段。 | 已在本条复盘中明确：当前状态以 2026-07-21 路线图、文档入口和 2026-07-20/21 完成记录为准，旧阻塞条目只作历史。 |
| 2026-07-21 | P3 已完成容易被误解成正式图片/MV 功能已经交付。 | 已澄清：P3 只完成输出合同和最小证明，P4 才交付正式媒体登记、控制、音量、淡入淡出和常见格式实验。 |

## 2026-07-19 Codex P3.4 前置门禁复核暂停

### 已完成
- [x] 按委派要求先核查权威范围：`docs/roadmap.md` 的 P3.4、`docs/p3_lifecycle_test_contract.md` 和 `docs/p3_player_output_contract.md`。
- [x] 交叉核查 `docs/roadmap.md`、`docs/design.md`、`docs/CCxGodot.md`、`project.godot`、`scenes/main.tscn`、`scripts/main.gd`、`.agents/skills/`、`.codex/`、`addons/` 与当前开发日志。
- [x] 确认 P3.4 四层调研、Godot 4.7-stable 源码对照卡和测试夹具合同已有文档记录；但这些仍是实现前依据，不是功能完成证据。
- [x] 确认前置条件不满足：P2 GM 可见窗口接受仍未完成；P3.0-P3.3 多处明确记录为功能代码、失败测试和验收尚未开始；项目脚本中也没有正式 `PlayerOutputController`、`ImageOutputPresenter`、`VideoOutputPresenter` 或原生 OGV 后端实现。
- [x] 本轮没有修改 P3.4 功能代码、测试、场景或模组数据；没有创建图片/OGV 夹具，没有运行 P3.4 冒烟测试，也没有宣布 P3 完成。

### 当前状态
- [ ] P3.4 生命周期、测试夹具与最小证明继续等待；必须先有 P2 GM 可见窗口接受记录，并完成 P3.0-P3.3 的功能实现、失败测试和验收证据后，才能生成夹具、写测试脚本、重跑 P1/P2/P3 并进入 P3 总验收。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | P3.4 已委派，但前置条件要求 P2 与 P3.0-P3.3 均有完成证据；当前文件证据显示这些条件未满足。 | 阻塞；等待 P2 可见验收接受，以及 P3.0-P3.3 功能实现、失败测试和验收完成后再继续。 |

## 2026-07-19 Codex P3.3 闸门复核暂停

### 已完成

- [x] 按委派要求先核查 P3.3 前置条件：P2、P3.0、P3.1、P3.2 必须都有完成证据后才能实现外部内容与玩家输出底座。
- [x] 交叉核查 `docs/roadmap.md`、`docs/p3_player_output_contract.md`、`docs/p3_lifecycle_test_contract.md`、`docs/p3_application_boundary.md`、`docs/p3_persistence_contract.md`、`docs/p3_playthrough_contract.md` 和当前开发日志。
- [x] 确认当前只能把 P3.3 维持在“实现前合同”状态：P2 的 GM（游戏主持人）可见窗口接受仍未完成；P3.0、P3.1、P3.2 均只有调研、源码对照和合同记录，没有功能代码与失败测试完成证据。
- [x] 本轮未修改 P3.3 功能代码、测试、场景或模组数据；未创建 `ExternalContentRef`、`ExternalContentResolver`、`PlayerOutputController`、Presenter（呈现器）或视频后端脚本。

### 当前状态

- [ ] P3.3 外部内容与玩家输出底座继续等待；必须先完成 P2 GM（游戏主持人）可见窗口验收，并完成 P3.0、P3.1、P3.2 的功能实现与测试证据。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | P3.3 已委派，但前置条件要求 P2、P3.0、P3.1、P3.2 均有完成证据；当前文件证据显示这些条件未满足。 | 阻塞；等待 P2 可见验收接受，以及 P3.0-P3.2 功能实现和失败测试完成后再继续。 |

## 2026-07-19 Codex P3.2 前置门禁复核暂停

### 已完成
- [x] 按委派要求先核查 `docs/roadmap.md`、`docs/p3_playthrough_contract.md`、`docs/p3_persistence_contract.md` 与 `devlog/DEVLOG.md`，确认本轮触发 P3.2 现成方案调研和 Godot 4.7-stable 源码一致性门禁；但前置证据未满足前不得进入功能实现。
- [x] 交叉核查结果：P2 自动回归、性能基线和 P3.0/P3.1/P3.2 合同/源码对照卡有记录；但 P2 GM 可见窗口人工接受仍是未完成项，P3.0 与 P3.1 也明确记为因 P2 门禁未开而尚未开始功能实现。
- [x] 本轮没有修改 P3.2 功能代码、测试、场景或模组数据；只追加本开发日志，避免把合同完成误判为功能完成。

### 当前状态
- [ ] P3.2 最小带团会话继续等待：需要先有 P2 GM 可见窗口接受记录，并且 P3.0、P3.1 具备功能实现与验证完成证据后，才能继续写 `PlaythroughController`、`session.json` 和地点快照代码。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | P3.2 委派任务到达，但 P2/P3.0/P3.1 前置完成证据不满足。 | 阻塞；等待 GM 明确接受 P2 可见窗口清单，并等待 P3.0/P3.1 功能实现验收完成。 |

## 2026-07-19 Codex P3.0 闸门复核暂停

### 已完成

- [x] 按 `docs/roadmap.md` 先核查 P2 收口验收闸门：自动回归、性能基线和文档审计已有完成记录，GM 可见窗口确认仍未勾选。
- [x] 交叉核查 `devlog/DEVLOG.md` 顶部记录：P2 人工验收已被连续确认阻塞，仍需 GM 完成选择、Token 拖动、光源、瞄准、LOS、破墙/修墙、保存读回与性能体感接受。
- [x] 核对 P3.0 现有合同：`docs/p3_application_boundary.md` 与最新开发日志已记录四层调研、Godot 4.7-stable 源码对照卡和迁移批次；但这些只允许作为通过闸门后的实现依据。
- [x] 本轮未修改 P3 功能代码、测试、场景或模组数据；只追加本开发日志。

### 当前状态

- [ ] P2 GM 可见窗口接受未完成，因此 P3.0 功能代码迁移继续等待。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | P3.0 任务已委派，但 P2 GM 可见窗口闸门仍无明确接受记录。 | 阻塞；等待 GM 明确接受全部人工清单，或列出失败项先回修 P2。 |

## 2026-07-19 Codex P2 人工验收阻塞确认

### 状态

- [x] 连续三轮确认同一阻塞条件：P2 自动回归、性能基线、可见项目实例、日志和调试端口均已就绪，项目进程仍正常响应。
- [ ] 必须由 GM 完成选择、Token 拖动、光源、瞄准、LOS、破墙/修墙、保存读回与性能体感接受；当前线程没有可用的 Godot 画面操作工具，不能替代该结论。
- [ ] 任务按规则标记为阻塞等待用户输入；用户回复 `1` 表示全部接受并恢复 P3.0，或回复失败项以先修复 P2。
- [x] 本轮没有修改功能代码、场景、测试或模组数据。

## 2026-07-19 Codex P2 GM 可见验收实例核查

### 已完成

- [x] 核查当前可见运行环境：Godot 编辑器进程 6408 以 `--editor` 打开 Gvtt；项目运行实例 47968 以当前工作区启动，未误把编辑器或旧测试进程当作验收窗口。
- [x] 核查调试通道：`127.0.0.1:6005` 与 `127.0.0.1:6006` 均由当前编辑器进程监听，没有 `Already in use` 端口冲突，不需要结束进程或重启电脑。
- [x] 只读检查最新运行日志：Godot `4.7.stable.official.5b4e0cb0f`、D3D12、Forward+ 与 NVIDIA RTX 4090 初始化正常；`godot_ai game_helper` 已注册，最新日志没有项目错误文本。
- [x] 本轮没有修改功能代码、场景、测试或用户模组；P3 实施闸门保持关闭。

### 当前状态

- [ ] 当前线程没有可调用的 Godot 运行树/画面控制工具，不能替 GM 完成选择、拖动、破墙、保存读回和体感判断。
- [ ] P2 仍等待 GM 在当前可见项目窗口完成 `docs/roadmap.md` 的人工清单，并明确接受或报告失败项；启动正常不等于人工验收通过。

## 2026-07-19 Codex P3.4 生命周期与最小证明合同

### 已完成

- [x] 新增 `docs/p3_lifecycle_test_contract.md`，固定地图/图片/视频完整行为链、Godot 4.7-stable 源码对照、项目映射、不可照搬差异、独立测试模组、图片/含音频 OGV 夹具和两层测试方法。
- [x] 明确测试拆分：无窗口环境只测状态、请求、失败、取消和释放；真实首帧、像素、比例、帧变化与音频必须在 Windows 可见渲染环境验证，不能把节点存在或无窗口循环速度当成显示成功。
- [x] 决定用 Godot 4.7 编辑器内置 `MovieWriter` 自产 `320 x 180 / 30 FPS / 约 1.2 秒` 的 Theora + Vorbis 夹具，不依赖本机缺失的 FFmpeg，也不下载许可证不明的媒体。
- [x] 规定图片/视频在 `1280 x 720` 和 `1024 x 768` 下分别产生可验证黑边；OGV 播放期间用临时测试音频总线峰值证明音轨进入混音，测试结束删除临时总线。
- [x] 同步 `docs/README.md` 阅读入口。

### 四层调研回执

- [x] 项目现状：P1/P2 已使用独立测试场景、结构化结果和进程退出码；P2.5 已实证无窗口显示服务器不会发 `frame_post_draw`，因此 P3.4 必须保留可见渲染冒烟。
- [x] Godot 4.7 源码：官方标签 `4.7-stable` 经 GitHub 标签元数据确认指向 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。完整链为 `VideoStreamPlayer::set_stream()` -> `VideoStreamTheora::instantiate_playback()` -> `VideoStreamPlaybackTheora::set_file()` -> `play()` -> 每帧 `update()`/纹理写入/音频混合 -> 后端停止 -> `finished`；退树先停播再移除混音回调，析构 `clear()` 释放文件、解码器、Ogg/Vorbis 状态和音频缓冲；OS 关闭只发请求，`Window::_clear_window()` 最后删除原生窗口。
- [x] 官方资料：离线 `Playing videos`、`Runtime file loading and saving`、`MovieWriter`、`Creating movies`、`Viewport` 与 `AudioServer` 文档确认原生 OGV、显式播放、固定帧率含音频写出、绘制后取像素及音频总线峰值 API。
- [x] 英文社区/开源：Godot 问题 #92050 在 4.3.dev6 复现播放前/停止后空画面且仍开放，只用于风险佐证；本地 gdUnit4 6.2.0-rc2 有带超时信号等待，但属于候选版且现有 P1/P2 不依赖它；官方 MIT demo 仓库未找到满足本合同的短含音频 OGV。

### 采用与未采用

- [x] 采用现有独立测试场景，并把“信号等待必须有超时”写入自有测试助手；不把 gdUnit4 候选版接入 P3 核心回归。
- [x] 采用可控假后端测并发/失败，真实原生 OGV 只负责解码、渲染、音频和清理冒烟；避免每个状态测试都依赖真实时间。
- [x] 不要求 `stop()` 后显示首帧；源码、官方文档和社区问题均表明当前画面可能为空。
- [x] 不在 P3 建正式 `Media` 总线；只创建并删除测试总线，P4 再实现产品音量与总线结构。

### 当前状态

- [x] P3.4 调研、源码对照卡、测试夹具设计和实现前合同已完成。
- [ ] P2 GM 可见窗口验收未完成，因此夹具生成、测试脚本和功能代码尚未开始。

## 2026-07-19 Codex P3.3 外部内容与玩家输出合同

### 已完成

- [x] 新增 `docs/p3_player_output_contract.md`，固定外部图片/视频引用、`MAP/IMAGE/VIDEO` 玩家输出、请求 ID、Presenter（呈现器）、视频后端隔离，以及失败、取消、结束、切场景、关投屏和退出程序的释放顺序。
- [x] 把 `CastView` 收窄为原生窗口壳；`PlayerOutputController` 作为输出状态唯一所有者；地图相机/迷雾、图片和视频分别由独立 Presenter 持有，不在 `Main` 或 GM 控件镜像第二份状态。
- [x] 扩充 `ModuleManifest.external_contents` 合同：外部绝对路径与模组相对路径分开校验，清单只保存稳定标识、引用和可重算元数据，不保存媒体字节。
- [x] 固定 P3 最小证明：只用测试图片和原生 OGV 完成地图 → 图片 → 视频 → 地图冒烟；正式文件选择、媒体库、常见格式和完整播放控制归 P4。
- [x] 同步 `docs/p3_persistence_contract.md` 与 `docs/README.md`，并完成差异空白检查及关键合同检索。

### 四层调研回执

- [x] 项目现状：当前 `CastView` 同时持有原生 `Window`、地图相机和迷雾，没有媒体节点或统一输出状态所有者；`LibraryManager` 仍面向模型与地面纹理，不应被扩成媒体播放中心。
- [x] Godot 4.7 源码：精确基线 `4.7-stable / 5b4e0cb0f`；`Image::load_from_file()` 进入 `ImageLoader::load_image()`；`TextureRect::set_texture()` 断开旧纹理信号并替换引用；`VideoStreamPlayer::set_stream()` 先停止旧播放再实例化后端，进树注册音频混合回调、退树停止并移除回调；Theora 后端停止归零，析构释放文件、解码器、Ogg/Vorbis 状态和音频缓冲；`Window` 退树时清理原生窗口。
- [x] 官方资料：核心视频仅支持 Ogg Theora，扩展可增加格式；外部图片使用 `Image.load_from_file()` 再创建 `ImageTexture`；`TextureRect` 可保持图片宽高比，官方视频指南建议使用 `AspectRatioContainer`；Theora 解码由 CPU 执行。
- [x] 英文社区/插件：Godot VLC 1.2.0 于 2026-05 发布，标明 Godot 4.3+、Windows/Linux 与 LGPLv2.1；其 `VLCMedia/VLCMediaPlayer` API 与原生播放器不同，尚未验证 Godot 4.7、双原生窗口、导出和释放行为。

### 采用与未采用

- [x] 采用项目自有 `VideoPlaybackBackend` 接口隔离原生 OGV 与未来 VLC，Presenter 和上层业务不得依赖具体播放器类型。
- [x] 采用严格递增请求 ID 和旧回调失效规则，避免快速切换时旧图片/视频覆盖当前输出。
- [x] 采用“媒体先停声并释放、地图再恢复、原生窗口最后释放”的生命周期，不允许 OS 关闭请求直接释放窗口。
- [x] P3 不安装 Godot VLC，也不承诺 MP4/MOV/WebM；P4 只有通过 4.7、Windows 双窗口、导出、清理和许可证验证后才能启用。

### 当前状态

- [x] P3.3 调研、源码行为链、实现前合同和文档收尾已完成。
- [ ] P2 GM 可见窗口验收未完成，因此 P3.3 功能代码和失败测试尚未开始。

## 2026-07-19 Codex P3.2 最小带团会话合同

### 已完成

- [x] 新增 `docs/p3_playthrough_contract.md`，定义模组底本/带团会话/临时演出三层真值、`session.json`、每地点会话快照、职责边界、保存/切地点/回编辑/退出顺序、恢复错误和测试矩阵。
- [x] 明确编辑态保存与运行态保存分流：编辑态“保存场景”只写 `_canonical` 底本；运行态“保存带团”只写 `sessions/<session_id>`，`main.gd` 不持有第二份脏标记。
- [x] 采用“每个已访问地点一份会话场景快照 + 版本化 JSON 索引”，不采用当前阶段的按对象差异协议，也不复制整个模组所有地点。
- [x] 规定会话快照必须在恢复运行态 Token、清内容树或释放服务之前保存；回编辑态重新加载底本，不能只恢复 Token 而让破墙/光源状态留在底本视图。
- [x] 补充 `docs/p3_persistence_contract.md` 的 `.tmp.scn/.bak.scn` 命名与提交顺序，并同步 `docs/README.md` 入口。

### 四层调研回执

- [x] 项目现状：`Playthrough` 仍是显示名/路径字典骨架，`ModuleIo.save_playthrough()/load_playthrough()` 未接入；当前切场景和回编辑态会先恢复 Token，墙体破坏会标脏，保存按钮在两种模式下均写底本，必须在 P3.2 分离保存路线和脏状态。
- [x] Godot 4.7 源码：精确基线 `4.7-stable / 5b4e0cb0f`；`PackedScene::pack()` → `SceneState::pack()`/`_parse_node()` 只保存场景根 owned 子树，`SceneState::instantiate()` 重建树，`ResourceLoader::_load_start()` 的 `CACHE_MODE_IGNORE` 绕开旧缓存，`Node::set_owner()` 强制 owner 为祖先。
- [x] 官方资料：离线 `Saving games` 的对象字段方案要求每个持久对象有场景来源、父路径和自己的保存字段；`PackedScene` 文档明确支持把节点及 owned 子树保存到 `user://`。当前没有稳定对象 ID 和统一对象保存接口，因此 P3.2 不强行采用对象差异。
- [x] 英文社区/开源：Tabletop Club 0.1.4 把资产包与 `.tc` 可恢复桌面状态分开，并支持把预制存档放进资产包；仓库代码搜索未能可靠读取，故只作为产品行为参考，不宣称照搬内部实现。SaveState Lite 仍只借鉴版本、临时文件和备份，不安装。

### 采用与未采用

- [x] 采用地点快照：复用已通过 P1/P2 的 `ModuleIo.save_scene_tree()` 所有权与运行节点排除链，以 `location_id` 索引，不依赖显示名或进程内 ObjectID。
- [x] 不采用按对象差异：当前必须同时新增跨保存对象 ID、所有对象保存接口和重建协议，超过“最小会话”；P8 若实测需要，可在不改变上层会话命令的前提下替换内部格式。
- [x] 不采用整个模组快照：每次复制未访问地点浪费空间并扩大失败范围。
- [x] 不虚报跨 JSON/场景文件原子性：先验证并提交固定路径快照，再提交 `session.json`；首次中断可能留下未登记孤立快照，下次只报告/清理，不自动并入会话。

### 当前状态

- [x] P3.2 调研、源码对照与实现前合同已完成。
- [ ] P2 GM 可见窗口接受未完成，因此 P3.2 功能代码与失败测试尚未开始。

## 2026-07-19 Codex P2 收口性能基线

### 已完成

- [x] 新增 `tests/p2_acceptance_metrics.gd/.tscn`，在隔离用户目录复制现有“测试模组”的两张真实场景，测量四次切场景、打开主窗口与 `1280 × 720` 投屏窗口、连续三轮采样、关闭投屏和夹具清理。
- [x] 真实 Windows / D3D12 / Forward+ / NVIDIA GeForce RTX 4090 可见运行通过 `17/17` 断言；Godot 精确版本为 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。
- [x] 切到下一可见帧四次为 `33.254 / 139.033 / 86.161 / 130.402 ms`；同步调用部分为 `6.080 / 125.941 / 63.859 / 119.126 ms`。
- [x] 双窗口三轮 `Engine.get_frames_per_second()` 为 `42 / 54 / 43 FPS`，平均 `46.33 FPS`；同周期真实绘制帧计数换算为 `45.76 / 54.26 / 39.57 FPS`，平均 `46.53 FPS`。
- [x] 保留已量化的破墙/修墙同步导航重建：约 `2.02 s / 1.81 s`。本轮只补普通切场景和双窗口数据，没有改变产品性能行为。
- [x] 结构化结果写入隔离目录 `build/p2_gate_profile/Godot/app_userdata/Gvtt/p2_acceptance_metrics.json`；测试结束关闭投屏、清空引用、关闭模组并删除夹具。

### 四层调研回执与源码映射

- [x] 项目现状：复用 `Main._switch_to_scene()` → `SceneSessionController.switch_to_scene()` 与 `CastView.open()/close()` 的真实入口，不在测试里复制业务实现，不触碰正在运行的真实用户模组。
- [x] Godot 4.7 源码：`ResourceLoader::load()` → `_load_start()`/`_load_complete()` 负责加载与缓存；`Window::_make_window()` → `DisplayServer::create_sub_window()` 创建原生窗口；`Main::iteration()` 在 `can_any_window_draw()` 后调用 `RenderingServer::draw()` 并递增绘制帧；约每秒把统计写入 `Engine::_fps`，`Engine::get_frames_per_second()` 返回该值。
- [x] 官方资料：离线 `Time` 文档确认 `get_ticks_usec()` 单调递增；`Engine` 文档确认 `get_frames_per_second()` 是平均渲染帧率、`get_frames_drawn()` 在无窗口或禁用渲染时固定为 0。
- [x] 英文社区：Godot 4 FPS 示例在运行循环中读取 `Engine.get_frames_per_second()`；只借鉴持续采样方式，不安装性能插件。参考 `https://gist.github.com/brettchalupa/4dd3107163da29a8158c3cdb4974d521`。
- [x] 源码行为 → 本地测量 → 证据：场景资源完成加载 → 切换后校验当前场景名并等待两个可见帧 → 四个耗时样本；原生窗口进入可见绘制 → 校验 `CastView.is_open()`/窗口可见并连续采样 → 两套 FPS 样本；`CastView.close()` 清理 → 校验关闭状态和窗口引用为空。

### 反证与剩余验收

- [x] 同一场景无窗口试跑时 `Engine.get_frames_per_second()` 仍报告约 `144 FPS`，但 `get_frames_drawn()` 三轮均为 0 并触发失败；证明无窗口循环速率不能冒充真实投屏性能。
- [x] 加载现有场景时出现三次“网行者test 缺少唯一同名 Token 素材”历史警告；切换、投屏、清理断言仍全部通过。该警告是隔离用户素材库没有旧导入素材，不是本次测量代码错误。
- [x] 交叉审计 `docs/design.md`、`docs/CCxGodot.md`、`docs/README.md`、`docs/p2_task_schedule.md`、`docs/CODEX_HANDOFF.md`、`docs/architecture.md` 和 `docs/roadmap.md`；清除“本轮没有重跑”和“性能仍未记录”两处过时当前口径。历史日志按时间保留，并由顶部最新条目声明当前结果。
- [ ] 平均约 `46.3 FPS` 和破墙/修墙约 `1.8-2.0 s` 是否满足现场体感，仍需 GM 在可见窗口判断；自动测量只记录事实，不替代接受结论。

## 2026-07-19 Codex P3.1 模组持久化合同

### 已完成

- [x] 新增 `docs/p3_persistence_contract.md`，固定模组目录、`manifest.json` 字段、稳定标识、相对路径约束、恢复顺序、旧 `_canonical` 迁移、结构版本迁移、事务边界和错误结果。
- [x] 决定内存中继续复用已有 `ModuleManifest`、`LocationRef`、`Playthrough` 类型；磁盘元数据使用经过领域校验的 JSON，场景本体继续使用 `.scn` `PackedScene`，不把用户可编辑清单作为带脚本的 `.tres` 加载。
- [x] 稳定标识固定为 `Crypto.new().generate_random_bytes(16).hex_encode()` 产生的 32 位小写十六进制字符串；不使用仅面向 Godot 工程资源路径注册的 `ResourceUID.create_id()`。
- [x] 明确 Windows 下不能虚报“原子写入”：采用“写 `.tmp` → 读回校验 → 复制正式文件为 `.bak` → 提交临时文件 → 失败立即恢复 → 下次启动按正式/备份/首次临时文件顺序恢复”的可恢复写入。
- [x] 同步 `docs/README.md` 文档入口；完成差异空白检查、尾随空格检查和关键合同检索，均通过。

### 四层调研回执

- [x] 项目现状：`ModuleIo` 已有 `save_playthrough()`、`load_playthrough()`、`load_manifest()`，但 `ModuleGate._open_module_state()` 仍每次新建清单和带团记录并扫描 `_canonical`；现有读取能力没有进入真实打开流程，稳定标识、结构版本和损坏恢复也未形成合同。
- [x] Godot 4.7 源码：精确基线 `4.7-stable / 5b4e0cb0f`；核查 `ResourceSaver::save()`、文本资源保存器、Windows `DirAccessWindows::rename()` 和 `FileAccess::flush()`。源码表明资源保存没有提供安全替换，Windows 重命名会先删除目标，`flush()` 只调用 `fflush`，因此本项目只能承诺可恢复写入，不能承诺断电级原子性。
- [x] 官方资料：离线 `Saving games`、`FileAccess`、`Crypto` 和 `ResourceUID` 文档支持 Dictionary（字典）+ JSON + 文件读写、密码学安全随机字节，并限定 `ResourceUID` 服务于工程资源路径身份。
- [x] 英文社区/插件：核查 SaveState Lite 1.2.0（MIT，标明 Godot 4.3-4.6）。它提供临时写、校验、备份和结构迁移思路，但全局 `SaveManager`、通用键值存档、未覆盖 4.7，以及提交失败后不立即恢复正式文件均与 Gvtt 冲突。

### 采用与未采用

- [x] 采用 SaveState Lite 的“临时文件 + 校验 + 备份”思路，但不安装插件、不复制其全局存档模型；实现 Gvtt 领域字段校验和失败恢复。
- [x] 采用显式逐版本迁移；遇到未来结构版本、路径逃逸、重复标识、无效起始地点或全部副本损坏时明确失败，不静默扫描覆盖。
- [x] 不一次提交清单和场景两个文件并假装跨文件原子：先保存清单，再保存场景；场景失败时保留可见的缺失引用，允许 GM 重试或删除。

### 当前状态

- [x] P3.1 调研、源码对照和磁盘合同已完成。
- [ ] P2 GM 可见窗口验收未完成，因此 P3.1 失败测试与功能实现尚未开始；性能基线已经补齐。

## 2026-07-19 Codex P3.0 应用装配边界审计

### 已完成

- [x] 新增 `docs/p3_application_boundary.md`，记录当前静态/运行时应用树、目标职责分组、唯一状态所有者、`main.gd` 职责分类、六条生命周期和五批迁移门槛。
- [x] 明确 P3.0 不新增万能框架：保留 `ModeGate`、`ModuleGate` 两个业务自动加载；`Main` 作为组合根；其他控制器和呈现模块继续是由父级注入的普通节点。
- [x] 确认当前结构债：`main.gd` 为 4107 行/217 函数；场景名/脏标记和相机参数仍有镜像；`SceneSessionController`/`PlacementController` 直接访问 `ModuleGate`；UI 与装配、退出清理仍混在主入口。
- [x] 确定迁移原则：不一次重写主脚本，不引入服务定位器或万能事件总线；按装配合同、场景镜像、相机镜像、全局访问、玩家输出五批迁移，每批重跑 P1/P2。
- [x] 同步 `docs/README.md` 文档入口和 `docs/architecture.md` 当前实现/目标边界说明。

### 四层调研回执

- [x] 项目现状：核对 `project.godot`、`scenes/main.tscn`、`scripts/main.gd::_ready()`、`module_gate.gd` 和全部控制器公开接口；业务自动加载只有 `ModeGate`/`ModuleGate`，其余模块由 `Main` 运行时创建。
- [x] Godot 4.7 源码：精确基线 `4.7-stable / 5b4e0cb0f`；核查 `main/main.cpp::Main::start()` 的自动加载注册/加载/实例化/根挂载、主场景 `ResourceLoader::load()`/`PackedScene::instantiate()`/`add_current_scene()`，以及 `node.cpp` 的进入、子先就绪和反向退出传播。
- [x] 官方资料：离线 `Scene organization` 和 `Autoloads versus regular nodes` 支持自包含场景、高层注入、信号上报、普通节点优先和少量广域自动加载。
- [x] 英文社区：`abmarnie/godot-architecture-organization-advice` 为 Godot 4.x 建议文档，支持祖先注入、公开命令/信号和 KISS/YAGNI；它不是可安装框架，并明确不应被当作大规模重构命令。

### 当前状态

- [x] P3.0 架构真值和源码对照卡已完成。
- [ ] P2 GM 可见窗口验收未完成，因此 P3.0 功能代码迁移尚未开始；性能基线已经补齐。

## 2026-07-19 Codex P2 收口闸门自动回归复跑

### 已完成

- [x] 恢复 Godot 4.7 控制台入口：`C:\Program Files\Godot_v4.7-stable_win64_console.exe`；当前精确版本输出为 `4.7.stable.official.5b4e0cb0f`。
- [x] 使用项目内隔离用户目录 `build/p2_gate_profile` 运行当前工作区真实代码，避免修改正在运行的 Godot 编辑器设置。
- [x] P1 主回归通过：`P1_RUNTIME_RESULT {"assertions":302,"failed":0,"failures":[]}`。退出仍有历史已知的 9 个 ObjectDB 对象和 4 个资源占用提示，保留为稳定性观察项。
- [x] P2.4 战斗遮挡专项通过：`P2_4_COMBAT_RESULT {"assertions":56,"failed":0,"failures":[]}`。
- [x] P2.5 LOS（视线判定）专项在真实 Windows 显示驱动 / D3D12 / Forward+ 下通过：`P2_5_LOS_RESULT {"assertions":52,"failed":0,"failures":[]}`。
- [x] P2.6 墙体破坏专项通过：`P2_6_WALL_RESULT {"assertions":64,"failed":0,"failures":[]}`。

### P2.5 测试通道调研回执

- [x] 项目现状：`tests/p2_5_los_regressions.gd::_test_main_overlay_contract()` 等待 `RenderingServer.frame_post_draw` 后读取遮罩像素；无窗口运行超过一分钟无结果，终止后退出码 1，没有断言汇总。
- [x] Godot 4.7 源码：`servers/display/display_server_headless.cpp::DisplayServerHeadless::create_func()` 安装 `RasterizerDummy`；`display_server_headless.h::can_any_window_draw()` 固定返回 false；`main/main.cpp::Main::iteration()` 因而不调用 `RenderingServerDefault::draw()`；`servers/rendering/rendering_server_default.cpp::_draw()` 末尾才发 `frame_post_draw`。
- [x] 官方资料：离线命令行、DisplayServer、RenderingServer 和 Viewport 文档明确 `--headless` 禁用渲染/窗口管理，读取视口纹理需等待真实绘制完成。
- [x] 英文社区：Godot 官方仓库 issue `#106957` 采用让 SubViewport 实际更新并等待绘制完成后读取图片；没有让空渲染器产生真实像素的可靠方案。
- [x] 采用分离测试通道：P1/P2.4/P2.6 用无窗口模式；P2.5 用短暂真实渲染窗口。不跳过像素断言，也不为“全套无窗口”削弱覆盖。

### 未完成

- [ ] GM 可见窗口仍需确认选择、Token 移动、光源投屏同步、瞄准线、墙后暗区、破墙/修墙和保存读回。
- [x] 已记录普通切场景时间、破墙/修墙导航重建时间和双窗口帧率，并完成文档去矛盾；P2 现在只剩 GM 可见操作与体感接受，仍不能进入 P3 功能代码修改。

## 2026-07-19 Codex P3 执行任务建立

### 已完成

- [x] 按 `docs/roadmap.md` 统一架构审计版建立 P3 执行目标，范围为“P2 收口验收闸门 + P3 最小可持续底座”。
- [x] 将任务拆成七个验收节点：P2 当前证据闸门、P3.0 应用装配、P3.1 模组持久化、P3.2 最小带团会话、P3.3 外部内容与玩家输出、P3.4 生命周期/测试夹具、P3 总验收。
- [x] 锁定边界：P3 只用测试图片和原生 OGV 验证输出合同；正式媒体库、常见格式正式支持、气氛、特效、高级迷雾、楼层和发布优化分别留在 P4-P9。
- [x] 锁定实施纪律：每个涉及 Godot 既有行为的节点先提交 Godot 4.7-stable 源码对照卡，再实现、自动回归、可见窗口验收和日志维护。

### 当前状态

- [x] Godot 4.7 测试入口、P2 自动回归、性能基线和文档统一已完成；P3 功能实现尚未开始，P2 只剩 GM 可见窗口接受。
- [ ] 本条只建立任务目标和执行顺序，没有修改 GDScript、场景、插件或项目配置，也没有运行功能测试。

## 2026-07-19 Codex 后续路线统一架构审计

> 当前真值：`docs/roadmap.md` 的“统一架构审计版”。本条以下同日的“后续路线图重排”“架构优先路线二次重排”“媒体播放结构边界修正”保留为历史过程，其 P3-P8 阶段结论均已作废，不得继续作为排期依据。

### 已完成

- [x] 接受用户对“凭记忆补阶段、像亡羊补牢”的质疑，不再维护旧路线；从产品需求树、系统所有权、状态持久化和依赖关系重新审计。
- [x] 重建四条用户工作流：备团编辑、现场运行、玩家输出、模组/带团持久化；确认媒体横跨玩家输出、现场操作和模组内容，高级迷雾横跨三维世界、规则状态、投屏和存档，不能仅按功能外观分组。
- [x] 发现根本依赖错误：`scripts/module_gate.gd::_open_module_state()` 每次打开模组都会新建 `ModuleManifest` 和 `Playthrough`，再扫描 `_canonical` 场景；完整模组清单和带团状态没有真实读回。旧路线却把完整数据地基放在媒体、迷雾之后。
- [x] 盘点实际架构：`scripts/main.gd` 为 4107 行、217 个函数；R1-R5 控制器只完成部分职责迁移，主入口仍负责界面、模组、素材、场景、输入、运行规则和投屏，不能宣称应用框架已经收口。
- [x] 修正文档矛盾：当前 `CastView` 是独立原生 `Window` 直接共享主窗口 `World3D`，没有额外 `SubViewport`；只有迷雾遮罩内部使用子视口。已同步 `docs/design.md` 与 `docs/architecture.md`。
- [x] 建立系统依赖图与三层状态：模组底本、一次带团会话、临时演出；玩家输出只路由地图/图片/视频，不拥有地图或媒体业务数据。
- [x] 比较三种路线并采用“最小可持续底座 + 工作流闭环”：不采用完整万能框架先行，也不继续按图片/特效/迷雾等功能类别堆阶段。
- [x] 重写 `docs/roadmap.md`：P2 收口闸门 → P3 最小可持续底座 → P4 媒体演出 → P5 三维演出 → P6 备团与内容管理 → P7 高级视野 → P8 完整冒险 → P9 第一版发布。
- [x] P3 提前纳入真实模组清单、稳定标识、版本迁移、最小带团会话、外部内容引用、玩家输出合同、统一失败/取消/清理和测试夹具；P8 只扩展完整楼层/长期状态，不再第一次引入带团存档。
- [x] 同步 `docs/design.md`、`docs/README.md`、`docs/p2_task_schedule.md`、`docs/CODEX_HANDOFF.md`、`docs/architecture.md` 的阶段编号、投屏实现和当前架构口径。

### 四层调研回执

- [x] 项目现状：核对 `project.godot`、`scenes/main.tscn`、`scripts/main.gd`、`scripts/module_gate.gd`、`scripts/cast_view.gd`、四套 P1/P2 测试和当前文档；确认已有基础多场景、场景保存、三维交互和投屏，但模组/会话真实持久化、媒体引用和跨地点长期状态缺失。
- [x] Godot 4.7 源码：精确基线 `4.7-stable` / `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`；核对 `Main::start()`、Node 进入/就绪/退出传播、`ResourceLoader::_load_start()`、`ResourceSaver::save()`、`SceneState::instantiate()`、Viewport 世界绑定、VideoStreamPlayer 播放/停止与后端实例化链。
- [x] 官方资料：核对离线 `Scene organization`、`Autoloads versus regular nodes`、`Resources`、`Runtime file loading and saving`、`Playing videos`、`Using Viewports`；采用自包含场景、高层装配、少量自动加载、外部内容与工程资源分开和播放器后端隔离原则。
- [x] 英文社区/开源：核对 Tabletop Club 素材包与保存文件组织、Godot 4.x 架构建议、Godot VLC 1.2.0 和保存/素材插件；只借鉴内容包和后端隔离，不照搬 Godot 3.x 多人物理沙盒，也不把播放器或保存插件误当完整产品架构。

### 采用与不采用

- [x] 采用最小可持续底座：只建立第一版已经确定有消费者的数据、装配、输出和生命周期合同，并用测试图片/原生 OGV 冒烟链证明边界可运行。
- [x] 不采用“所有未来框架一次做完”：没有消费者的万能事件总线、万能加载器和规则框架无法可靠验收。
- [x] 不采用“维持旧 P3-P8 再继续补”：旧路线把媒体播放器骨架补进 P3，却仍把真实模组/会话地基放晚，根问题没有解决。
- [x] 不安装新插件、不修改 GDScript、场景或项目配置；Godot VLC 只保留为 P4 隔离实验候选。

### 验证与未做

- [x] 本轮完成文档残留搜索，旧“应用框架收口 / 投屏演出闭环 / 备团效率闭环”阶段名已从当前专题文档清除；投屏额外 `SubViewport` 的错误描述已修正。
- [ ] 当前命令行没有找到可用的 Godot 执行程序，当前会话也未暴露 Godot MCP（模型上下文协议）工具，因此没有重跑 P1、P2.4、P2.5、P2.6。历史通过记录只作为历史证据，P2 收口闸门仍待当前复跑和 GM 可见窗口验收。
- [ ] 尚未开始 P3 功能实现；下一步是先完成 P2 收口闸门，再为 P3.0/P3.1 提交 Godot 4.7 源码对照卡并进入实现。

### 问题状态

| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | 后续路线多次局部补丁，阶段依赖和“何时做完”不清晰。 | 已统一重建；旧 P3-P8 路线作废，当前以 P3-P9 依赖路线为准。 |
| 2026-07-19 | 模组清单与带团对象打开时重新创建，完整持久化被错误后置。 | 已提前到 P3 作为底座任务；功能尚未实现。 |
| 2026-07-19 | `docs/design.md` 把当前投屏误写成 `Window + SubViewport`。 | 已修正为独立 `Window` 直接共享 `World3D`；迷雾遮罩子视口单独说明。 |
| 2026-07-19 | 本轮无法运行 Godot 自动回归。 | 已由后续任务解决：找到 4.7-stable 执行入口并完成四套回归、真实绘制测试与性能基线；仍保留 GM 人工验收。 |

## 2026-07-19 Codex 媒体播放结构边界修正

### 已完成

- [x] 核查用户担心“媒体播放本身也算结构”：结论成立。上一版 P3 虽已有地图/图片/视频输出路由、`MediaRef` 和资源加载合同，却没有播放器唯一所有者、播放状态、音频路线、结束/失败信号和退出清理，媒体结构仍不完整。
- [x] 项目现状：`CastView` 当前只创建/销毁玩家窗口、三维相机和迷雾叠层，没有媒体节点或播放状态；因此不能把媒体生命周期藏进 `CastView`，也不能继续交给 `main.gd`。
- [x] Godot 4.7 源码依据：`VideoStreamPlayer::set_stream()` 先停止旧流再调用 `VideoStream::instantiate_playback()` 建立后端；进入场景树注册音频混合，退出时 `stop()` 并注销；内部处理完成后发出 `finished`。这证明播放实例、状态、音频与清理属于框架合同。
- [x] 官方资料依据：核心仅支持 Ogg Theora，其他格式依赖扩展；视频由 CPU 解码，并有宽高比、音频、循环与结束处理要求。
- [x] 英文社区依据：Godot VLC 1.2.0 是近期维护的 Godot 4.3 / Windows / Linux 社区扩展，但使用独立 `VLCMediaPlayer` 节点和 LGPL 2.1 许可证；不能把 Gvtt 上层结构直接绑定到它。
- [x] 修订 `docs/roadmap.md`：P3 新增“媒体呈现骨架”，包含唯一所有者、播放状态机、统一命令/信号、独立媒体音频总线、换媒体/切场景/关投屏/退出清理和可替换后端；用真实 OGV 贯通加载、播放、暂停、恢复、结束和返回地图。
- [x] P4 边界保留为正式功能：文件选择和登记、常见 MP4/VLC 兼容性、完整 GM 控制界面、缩略图、淡入淡出和桌边演出流程。
- [x] 同步 `docs/design.md`、`docs/README.md` 和 `docs/CODEX_HANDOFF.md`。

### 未做与下一步

- [x] 本轮只修正规划和日志，没有实现播放器、安装插件或修改 Godot 场景，因此没有运行功能测试。
- [ ] 实施 P3 媒体骨架前仍须提交源码对照卡，并用原生 OGV 建立可自动验证的最小样本；Godot VLC 继续留在 P4 隔离实验。

### 问题状态

| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | P3 只有媒体输出/数据合同，没有真实播放器生命周期，框架无法被验证。 | 已修正路线；实现待 P3。 |

## 2026-07-19 Codex 架构优先路线二次重排

### 已完成

- [x] 接受并核查用户质疑：上一版 P3 同时放入三维气氛/特效与图片/MV，却把依赖的媒体管理、场景绑定和长期状态放在后续阶段，存在依赖倒挂；不能继续把它当最终路线。
- [x] 交叉核对项目代码、场景与文档：已有 `ModeGate`、`ModuleGate`、`ModuleIo`、`CastView` 和 R1-R5 控制器，但 `scripts/main.gd` 实际已达 4107 行、217 个函数，仍执行界面、素材、场景、输入、运行态规则和投屏等具体业务；现状是“骨架已立但边界未收口”。
- [x] 完成 Godot 4.7 源码对照：基线 `4.7-stable` / `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`；核查 `main/main.cpp::Main::start()` 的 Autoload 挂载顺序，`scene/main/node.cpp` 的进入/就绪/退出传播，`core/io/resource_loader.cpp::_load_start()` 的加载缓存，`scene/resources/packed_scene.cpp::SceneState::instantiate()` 的场景实例化，以及 `scene/main/viewport.cpp::find_world_3d()/set_world_3d()` 的窗口世界绑定。
- [x] 完成官方资料核查：采用 `Scene organization`、`Autoloads versus regular nodes`、`Resources`、`Using Viewports` 和 `Background loading` 对数据、节点、全局服务、输出与后台加载的分工。
- [x] 完成英文社区/插件核查：采用 Godot 4.x 社区的自包含场景、父级依赖注入、信号上报和 YAGNI 原则；Yet Another Scene Manager 只借鉴加载阶段信号；Tabletop Club 因 Godot 3.x 定制引擎、多人和物理沙盒边界冲突而不照搬；AssetPlus/Global Asset Manager 属编辑器插件，不用于导出后的 GM 运行时媒体库。
- [x] 重写 `docs/roadmap.md`：新顺序为“P2 收口闸门 → P3 应用框架收口 → P4 投屏演出 → P5 备团效率 → P6 高级视野 → P7 完整冒险 → P8 第一版发布”。
- [x] 当时为 P3 写明架构职责表、主协调层收口、唯一状态所有者、地图/图片/视频输出路由、数据版本与 `MediaRef` 合同、统一加载/失败/取消/释放、最小测试模组和 P1/P2 迁移回归；其中“P3 不实现真实播放器”的边界已被本文件顶部“媒体播放结构边界修正”推翻，现改为 P3 用原生 OGV 验证媒体骨架，P4 交付正式功能。
- [x] 同步 `docs/design.md`、`docs/README.md`、`docs/p2_task_schedule.md`、`docs/CODEX_HANDOFF.md`、`docs/architecture.md` 的阶段编号和真实架构口径。

### 采用与不采用

- [x] 采用“先补第一版确定需要的最小完整框架，再用 P4 第一批真实演出模块验证”的方案。
- [x] 不采用“先把所有未来框架一次做完”：没有真实消费者的万能事件总线、万能媒体/效果抽象和规则框架无法可靠验收，容易提前过度设计。
- [x] 不采用“维持旧 P3，边写气氛/视频边顺手补框架”：当前主入口职责已过载，会继续扩大状态所有权和清理风险。

### 未做与下一步

- [x] 本轮只重排规划和修正文档，没有修改 GDScript、场景、插件或项目配置，因此没有运行 Godot 功能回归。
- [ ] 下一步仍先执行 P2 收口验收闸门；通过后进入 P3.0 架构真值与职责表，不直接开始图片/MV 或三维特效。

### 问题状态

| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | 旧 P3 将框架依赖和具体演出功能混在一起，且媒体/长期状态依赖后置。 | 已通过 P3-P8 架构优先路线修正。 |
| 2026-07-19 | 架构文档仍把 `main.gd` 写成 3068/3744 行并暗示主协调层已收口，与 4107 行/217 函数的实际代码不符。 | 已修正文档；具体收口列为 P3 验收目标。 |

## 2026-07-19 Codex 后续路线图重排

### 已完成
- [x] 根据用户反馈重新梳理 P2 之后任务；确认旧 P3/P4 把投屏演出、备团工具、高级迷雾、模组状态和媒体编排混在一起，阶段完成线不清楚。
- [x] 新增 `docs/roadmap.md` 作为 P2 后续阶段真值，改为“P2 收口闸门 → P3 投屏演出 → P4 备团效率 → P5 高级视野 → P6 完整冒险 → P7 第一版发布”。
- [x] 为 P3-P7 分别写明子任务、依赖、明确不做项、自动/人工验收标准和实施时应调用的 Godot 技能。
- [x] 同步 `docs/design.md`、`docs/README.md`、`docs/p2_task_schedule.md` 与 `docs/CODEX_HANDOFF.md`；修正旧入口仍称“破墙不重建导航”的矛盾，当前真值为 P2.6 已重建移动服务并通过 `64/64` 专项断言，但全量重建仍有约 1.8-2.0 秒停顿。

### 四层调研依据
- [x] 项目现状：P0-P2 主体、基础多场景和基础投屏已落地；当前真正前置是 P2 可见验收、文档一致性和性能基线，而不是继续扩 P2 功能。
- [x] Godot 源码：精确版本 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。核对 `WorldEnvironment::_notification()/set_environment()`、`GPUParticles3D::restart()`、`Window::set_visible()/_make_window()`、`VideoStreamPlayer::set_stream()/play()/_notification()`、Theora 资源加载注册，以及 `PackedScene::pack()/SceneState::_parse_node()/instantiate()`。
- [x] 官方资料：环境资源与唯一 `WorldEnvironment`、GPU/CPU 粒子、`VideoStreamPlayer` 仅原生支持 Ogg Theora、`SubViewport` 输出、`PackedScene`/`ResourceSaver` 持久化、后台导航烘焙与主线程几何解析限制。
- [x] 英文社区/开源：`xiSage/godot-vlc` 1.2.0 是常见视频格式候选但需验证 4.7/Windows/单程序；`blackears/cyclopsLevelBuilder` 是 Godot 编辑器插件不适合直接接入运行时；`d-bucur/godot-vision-cone` 只支持二维，采用模式不装插件；Tabletop Club 采用外部图片/模型/音乐资源包思路，但其多人、物理沙盒和定制引擎不照搬。

### 采用与未采用
- [x] 采用按 GM 实际工作流分阶段，而不是继续给旧 P3/P4 增加功能；每个阶段必须形成独立用户闭环。
- [x] 当时计划优先 Godot 原生环境、粒子、窗口/视口和场景存档能力，并把 Godot VLC 放入 P3.0 隔离实验；该阶段编号已被顶部“媒体播放结构边界修正”替代，现为 P3 用原生 OGV 验证骨架、Godot VLC 留 P4.0 隔离实验。
- [x] 不直接采用 Cyclops Level Builder 或二维视野插件；前者属于编辑器，后者不能替代 Gvtt 的三维投屏和现有 LOS 服务。

### 本轮边界
- [x] 本轮只重排路线与修正文档，没有实现 P3-P7 功能、安装插件、修改场景或业务脚本。
- [ ] 下一步应先执行 `docs/roadmap.md` 的 P2 收口验收闸门；未通过前不把 P3 标记为已开始。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | 旧 P3/P4 按功能堆放，用户无法判断做到哪里才算一阶段完成。 | 已重排为 P3-P7 六个可验收闭环（含 P2 收口闸门）。 |
| 2026-07-19 | `docs/README.md` 仍写破墙后 Token 不能穿过，与最新实现和测试冲突。 | 已修正；功能已完成，1.8-2.0 秒重建停顿归 P7 性能收尾。 |

## 2026-07-19 Codex 媒体演出路线补充

### 已完成
- [x] 确认用户新增产品目标：Gvtt 除 3D 地图外，还要覆盖复杂跑团中的图片展示和 MV（音乐视频）播放；此前路线图只有投屏模式，没有独立媒体演出能力。
- [x] 更新 `docs/design.md`：P3 增加“媒体演出基础”，负责本地图片/MV 一键投屏和基础控制；P4 增加“媒体库 + 演出编排”，负责模组/场景绑定、缩略图、播放列表、演出顺序和引用持久化。
- [x] 项目现状核对：`scripts/cast_view.gd` 当前仅以独立 `Window` + 共享 `World3D` 同步 3D 世界，`scripts/main.gd` 只有投屏开关，没有图片/视频播放器或媒体库。
- [x] Godot 4.7 源码核对：官方 `4.7-stable` 标签对应提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`；`scene/gui/video_stream_player.cpp::set_stream()/play()/_notification()` 依次创建播放对象、启动并逐帧 `update()`、结束后发 `finished`；`modules/theora/video_stream_theora.cpp::update()` 解码并同步视频/音频；`modules/theora/register_types.cpp` 与 `ResourceFormatLoaderTheora` 只注册 `.ogv` 内置加载器。
- [x] 官方资料核对：`gdd_0144_Playing_videos.md` 明确核心仅支持 Ogg Theora；`gdd_0187_Runtime_file_loading_and_saving.md` 给出外部图片经 `Image.load_from_file()` + `ImageTexture` 显示，以及外部 Ogg Theora 视频运行时加载路径。
- [x] 英文社区/插件核对：`xiSage/godot-vlc` 1.2.0（2026-05）支持 Godot 4.3+、Windows/Linux 和外部文件，当前最贴合单 exe 的常见格式播放候选；`EIRTeam/EIRTeam.FFmpeg` 最新 1.1.4（2025-11）支持 Godot >4.1，但 Windows 构建与 H.264 专利风险更高；GoZen 仍为 Alpha 且 GPLv3，不直接依赖。

### 边界与待确认
- [x] 本轮只补产品路线与调研依据，没有安装媒体插件、修改功能代码、场景或投屏实现。
- [ ] 实现前确认第一种呈现目标：全屏替换投屏地图，还是作为 3D 地图内的一块屏幕；两者节点结构和交互完全不同。
- [ ] 采用 `godot-vlc` 前必须在 Godot 4.7、Windows 导出和现有原生投屏窗口中做最小兼容性实验；未通过前保留原生 `.ogv` 回退，不宣称 MP4 已支持。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | 当前路线图漏掉图片/MV 等跑团演出能力。 | 已补 P3 基础播放与 P4 媒体库/编排边界；实现待排期。 |
| 2026-07-19 | Godot 核心视频只识别 Ogg Theora，无法直接满足 GM 随手选择常见 MP4 的体验。 | 候选采用 Godot VLC；必须先做 4.7 + Windows 导出兼容性验证。 |

## 2026-07-18 Codex P3 下一阶段口径核对

### 已完成
- [x] 回答用户“2 阶段做完之后三阶段做什么”：P3 应接在 P2.0-P2.6 基础版之后，优先做特效触发、场景气氛、高级 LOS/战争迷雾和色块布局工具，而不是新增第三个 AppMode。
- [x] 依据核对：`docs/README.md` 记录 P2.0-P2.6 基础版已落地并把高级 LOS 归 P3/P4；`docs/design.md` 的优先级表列出 P3 四项；`docs/p2_task_schedule.md` 写明 P2.5/P2.6 的后置边界；`devlog/DEVLOG.md` 记录 P2 收口结论与仍需 GM 可见窗口体感确认。
- [x] 同步核对当前项目入口：`project.godot` 仍是 Godot 4.7、Jolt Physics、3D 第 20/21 层分别给 PickProxy/CombatBody；`scenes/main.tscn` 和 `scripts/main.gd` 已有基础 WorldEnvironment、LOSService、PlayerFogOverlay、墙体破坏和 CombatBody 入口，但未显示 P3 特效/气氛/高级迷雾已经完成。

### 验证与边界
- [x] 本轮只做文件核查和日志记录，没有修改功能代码、场景或插件。
- [ ] P3 开始前仍需按项目门禁重新做四层调研；涉及 Godot 现成行为时必须补 Godot 4.7 源码对照卡。
- [ ] P2 仍有一个独立后置问题：破坏墙体后 Token 移动导航重建尚未实现，不能混进“P3 已开始”的完成口径。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | P3 容易被误解成第三个运行模式。 | 已澄清：P3 是功能优先级阶段；投屏窗口只是运行态输出层，不是第三个 AppMode。 |

## 2026-07-18 Codex 文档顺序与重复口径整理

### 已完成
- [x] 新增 `docs/README.md` 作为文档入口，明确最新阅读顺序、历史档案和 P2 当前口径。
- [x] 补齐空白 `docs/CCxGodot.md`，把它改成 Codex 与 Godot 工具链核查入口，避免空文件被误判为缺资料。
- [x] 修正 `docs/CODEX_HANDOFF.md` 中仍写“文档/资产整理待做”、`.claude/CLAUDE.md` 为当前规则、`CombatBody/LOSOccluder（将来）`、`main.gd 约 2000 行` 等旧口径。
- [x] 修正 `docs/CODEX_HANDOFF.md` 的关键文档清单，把 `AGENTS.md` 和 `docs/README.md` 放到当前阅读顺序前列。
- [x] 修正 `docs/design.md` 中 P2.3 光源开关未标基础版已完成的漏项。
- [x] 修正 `docs/architecture.md` 的入口说明、命名规范来源和文档目录树，避免继续把 `.claude/CLAUDE.md` 当当前规则入口。
- [x] 修正 `docs/entity_properties_schema.md` 顶部状态，明确它是属性边界文档，不替代 P2 验收文档。
- [x] 修正 `docs/entity_properties_schema.md` 运行态面板段落中光源/墙体按钮仍写“将来出现”的旧口径。

### 验证与边界
- [x] 本轮只改文档和开发日志，不改功能代码，不移动素材。
- [ ] 历史日志中的旧状态原样保留；它们是过程档案，不作为当前状态真值。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 正式文档入口分散，新对话容易先读到旧顺序或空文件。 | 已新增 `docs/README.md` 和 `docs/CCxGodot.md` 入口说明 |
| 2026-07-18 | 部分正式文档仍残留 P2.3/P2.4/P2.5/P2.6 落地前的“将来/待做”说法。 | 已同步主要文档为 2026-07-18 当前口径；旧 devlog 作为历史保留 |

## 2026-07-18 Codex P2 收口核查与资产整理

### 已完成
- [x] 回应用户澄清：本轮核查范围是 P2（二阶段），不是整个项目全部阶段。
- [x] 对照 `docs/design.md`、`docs/p2_task_schedule.md`、`docs/CODEX_HANDOFF.md`、`docs/architecture.md`、`devlog/DEVLOG.md`、`.agents/skills/`、`.codex/`、`addons/`、`project.godot`、`scenes/main.tscn` 和 `scripts/main.gd` 核查 P2 状态。
- [x] 结论收口：P2.0-P2.6 基础版均已有代码和文档依据；P2.3 光源、P2.4 CombatBody、P2.5 LOS、P2.6 墙体破坏不需要再作为新功能从头做。
- [x] 发现并修正文档矛盾：旧 `docs/CODEX_HANDOFF.md` 仍写 P2.3-P2.6 待做；`docs/p2_task_schedule.md` 的总表未把 P2.3/P2.4 标成已完成。已统一到 2026-07-18 当前口径。
- [x] 新增 `docs/asset_inventory.md`，记录 `assets/`、`个人资产/`、`2K_Gravel01/` 的分工、重复项和安全整理边界。

### 验证与边界
- [x] 本轮只做状态核查、文档收口和资产清单，不改功能代码，不移动真实素材路径。
- [ ] 仍需 GM 可见窗口最终确认：P2.1 选择面板、P2.3 光源投屏同步、P2.4 瞄准线、P2.5 墙后暗区、P2.6 破坏/保存读回体感。
- [ ] 未整理到物理移动资产：`个人资产/` 被 CPR 资料索引引用，`2K_Gravel01/` 尚未确认是否纳入内置地面纹理；贸然移动会破坏路径或改变 Godot 导入状态。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 旧交接文档把 P2.3-P2.6 写成待做，与最新代码和设计文档冲突。 | 已修正；当前以 `docs/design.md`、`docs/p2_task_schedule.md` 和本日志为准 |
| 2026-07-18 | `个人资产/` 与 `2K_Gravel01/` 等源素材目录未形成安全整理口径。 | 已新增资产清单；暂不移动真实文件，后续按“复制精选内置素材、保留源素材仓”处理 |

## 2026-07-18 Codex Godot 0x58 应用程序错误定位

### 已完成
- [x] 回答用户的 Godot 崩溃弹窗问题：`0x0000000000000058` 读内存失败属于 Godot 进程原生层崩溃，不是普通 GDScript 红字。
- [x] 项目现状核查：`project.godot` 当前运行版本特征为 Godot 4.7、启用 `Jolt Physics`、Windows 渲染驱动为 `d3d12`，编辑器插件列表只启用 `godot_ai`；但 `.godot/extension_list.cfg` 仍登记 `res://addons/gdstyle/gdstyle.gdextension`。
- [x] 崩溃线索核查：`devlog/DEVLOG.md` 已多次记录原项目命令行/无窗口启动在 `godot-rust` / `gdstyle` GDExtension 初始化阶段 `signal 11` 崩溃，其中最新记录明确显示 `Initialize godot-rust (API v4.5.stable.official, runtime v4.7.stable.official)` 后崩溃，发生在脚本测试执行前。
- [x] 官方资料核查：Godot 4.7 离线 Troubleshooting 文档说明“打开项目后频繁或立即崩溃”可能由 editor plugin 或 GDExtension addon 引起，并建议用 recovery mode 排查。
- [x] 回答“关掉是否影响工作”：`gdstyle` 是 GDScript lint/format 辅助工具，会影响编辑器内格式检查、手动格式化、保存时检查和诊断跳转；但不会影响 Gvtt 运行功能、场景保存/加载或 Godot 脚本执行。项目核心代码规范仍由 `AGENTS.md` 和人工/自动静态检查维护。
- [x] 核查当前没有 `.gdstyle.toml` / `gdstyle.toml` 项目配置文件；因此 `gdstyle` 当前不是承载 Gvtt 自定义格式规范的唯一来源。
- [x] 决策口径更新：如果崩溃只在低频、非关键操作中出现，且不造成未保存数据丢失，可把它作为短期可接受代价；但由于它已阻断过命令行回归和无窗口测试，不能把它视为健康状态，进入发布/稳定验收前仍应停用、升级或替换。
- [x] 回答“是否官方/为何不兼容”：本地 `addons/gdstyle/plugin.cfg` 标注作者为 `Piero Molino`、版本 `0.1.7`，不是 Godot 官方内置工具；公开 Asset Library 当前条目也标注为 Community 工具。其 `.gdextension` 只写 `compatibility_minimum=4.6`，没有 `compatibility_maximum`，因此 Godot 4.7 会尝试加载；但日志显示该 DLL 初始化时报 `godot-rust API v4.5` 对 `Godot 4.7 runtime`，说明实际二进制与当前运行时接口不匹配。
- [x] 已按用户要求升级 `gdstyle`：从 GitHub/Asset Library 下载 `gdstyle-godot-plugin.zip`，将 `addons/gdstyle` 从 `0.1.7` 替换为 `0.2.3`；旧版完整备份在 `build/gdstyle_upgrade_20260718/gdstyle_0.1.7_backup` 和 `build/gdstyle_upgrade_20260718/gdstyle_0.1.7_original_dir`。
- [x] 给升级临时目录加 `build/gdstyle_upgrade_20260718/.gdignore`，并清理 `.godot/extension_list.cfg`，避免 Godot 同时扫描 active 新版、解压临时版和旧版备份的多个 `.gdextension`。
- [x] 验证：`Godot_v4.7-stable_win64_console.exe --headless --import --quit --path ...` 在项目内临时 `APPDATA`/`LOCALAPPDATA` 下退出码 0；新版仍打印 `godot-rust API v4.5 / runtime v4.7`，但没有复现此前 `signal 11` 崩溃。
- [x] 静态收尾：`git diff --check -- addons\gdstyle .godot\extension_list.cfg build\gdstyle_upgrade_20260718 devlog\DEVLOG.md` 通过。
- [x] 按用户要求继续盘点其他插件：`addons/godot_ai` 原为 `2.9.1`，`addons/Gizmo3DScript` 为 `1.0.0`，`addons/gdUnit4` 为 `6.2.0-rc2`，`addons/gdstyle` 已为 `0.2.3`；当前 `project.godot` 只启用 `godot_ai` 编辑器插件，`.godot/extension_list.cfg` 只登记 `res://addons/gdstyle/gdstyle.gdextension`。
- [x] 原生扩展风险核查：`addons/` 里只有 `gdstyle` 带 `.gdextension` 和平台动态库；`godot_ai`、`Gizmo3DScript`、`gdUnit4` 没有 `.dll/.so/.dylib/.gdextension`，因此没有看到与 `0x58` 内存崩溃同类的原生加载风险。
- [x] 已升级 `Godot AI`：从 `2.9.1` 替换为 GitHub `hi-godot/godot-ai` 的 `v3.0.3` 插件目录；旧版备份在 `build/godot_ai_upgrade_20260718/godot_ai_2.9.1_backup`，下载和解压副本留在 `build/godot_ai_upgrade_20260718/`，并已添加 `.gdignore` 防止 Godot 扫描临时副本。
- [x] 验证：`addons/godot_ai/plugin.cfg` 已显示 `version="3.0.3"`；新版 `godot_ai` 插件目录未新增原生扩展；`Godot_v4.7-stable_win64_console.exe --headless --import --quit --path ...` 退出码 0。无窗口模式下 `godot_ai` 正常提示 `plugin disabled in headless mode`，这是上游设计，不是错误。
- [x] 补查用户追问的“CP 插件”：按 `cp` / `cpr` / `codex` / `cowork` / `mcp` 关键词搜索后，`addons/` 中不存在单独的 `CP` Godot 插件。项目里的 `CPR` 是规则资料与脚本（`docs/cpr_reading/`、`scripts/cpr_token_properties.gd`、`scripts/cpr_movement_rule_provider.gd`），不属于编辑器插件，也没有原生扩展文件。

### 四层调研回执
- [x] 项目现状：当前最强证据指向 `addons/gdstyle/gdstyle.gdextension` 的原生 DLL/ABI 兼容问题；`godot_ai` 和 Jolt/D3D12 仍需作为次级排查项保留，不能只看弹窗地址就断言。
- [x] Godot 源码/版本：当前日志锁定 Godot `4.7.stable.official.5b4e0cb0f`；本轮没有修改复刻 Godot 行为的功能代码，因此未新增源码对照卡。
- [x] 官方资料：离线 `gdd_0055_Troubleshooting.md` 支持“插件或 GDExtension 可导致项目启动崩溃”的判断；`.gdextension` 文件本身显示 Windows 加载 `gdstyle_gdext.dll`。
- [x] 社区/现成方案：既有项目记录显示此前已用“无 gdstyle 隔离项目 + 恢复模式导入”绕开验证；更稳的后续处理是升级/重编译 gdstyle 到 Godot 4.7 兼容版本，或从项目中移除该 GDExtension，而不是改业务脚本。`godot_ai` 上游 `v3.0.3` 为当前最新 3.0 系列，README 标注 Godot 4.7+ 推荐；3.0 系列重点强化启动、WebSocket、重载、导出和端口占用处理，符合本项目 MCP 调试通道的实际痛点，因此升级它，但不把它判定为 `0x58` 崩溃主因。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | Godot 弹出 `0x0000000000000058` 读内存失败应用程序错误。 | 已定位为高概率原生扩展兼容崩溃；尚未移除或升级 `gdstyle`，需单独执行修复与回归验证 |
| 2026-07-18 | 用户担心关掉 `gdstyle` 会失去代码格式参照。 | 已澄清；会失去编辑器内自动 lint/format 辅助，但不影响项目运行，格式规范仍在 `AGENTS.md` 中，可用外部/人工检查替代 |
| 2026-07-18 | 用户提出若只是偶发崩溃，是否可把 `gdstyle` 作为有用工具的代价暂时保留。 | 可短期容忍；前提是勤保存、不用于关键验收、不把命令行测试崩溃误判为业务失败 |
| 2026-07-18 | 用户追问 `gdstyle` 是否官方、为何看似 Godot 4.x 工具仍不兼容 4.7。 | 已解释；这是社区工具，本地 0.1.7 原生 DLL 与 4.7 运行时存在版本/API 风险，最新版可能已修但需单独升级验证 |
| 2026-07-18 | 本地 `gdstyle` 旧版原生扩展阻断 Godot 4.7 命令行验证。 | 已升级到 0.2.3；无窗口导入验证不再崩溃，仍需用户重启可见编辑器确认日常保存/格式检查体感 |
| 2026-07-18 | 用户要求检查其他插件是否也有类似崩溃风险，并判断 `godot_ai` 2.9.1 是否要跟进 3.0。 | 已盘点；未发现除 `gdstyle` 外的原生扩展崩溃证据。`godot_ai` 已升到 3.0.3，理由是 MCP 调试通道稳定性收益明确；`Gizmo3DScript` 与 `gdUnit4` 暂不升级 |
| 2026-07-18 | 用户追问“CP 插件”是否漏查。 | 已补查；`addons/` 中没有单独 CP 插件，`CPR` 只是规则资料和脚本，不是插件且无原生扩展风险 |

## 2026-07-17 Codex 运行态 Token 移动不污染编辑态修复

### 已完成
- [x] 修复运行态 Token 移动写回编辑态的问题：进入运行态时记录 Token 的编辑态 `global_transform`；运行态拖动后切回编辑态会恢复原位置。
- [x] 运行态 Token 拖动不再标记场景未保存；编辑态移动/缩放/属性修改仍照常标记未保存并可保存读回。
- [x] 切场景前也会先恢复运行态 Token 快照，再清理移动服务和内容根，避免临时跑团位置被带进下一次场景保存。
- [x] 补回归断言：运行态改动 Token 位置后切回编辑态必须复原，且 `_scene_dirty` 与 `SceneSessionController.is_dirty()` 不能被运行态移动置脏。
- [x] 更新 `docs/design.md`、`docs/p2_task_schedule.md`、`docs/entity_properties_schema.md`、`docs/architecture.md`、`docs/CODEX_HANDOFF.md`：统一说明“编辑态底稿持久化，运行态移动临时化”。

### 四层调研回执
- [x] 项目现状：`MovementService` 运行态直接改 `token.global_position`，旧 `_finish_runtime_token_drag()` 还会标脏，导致跑团移动泄漏进编辑底稿。
- [x] Godot 源码：Godot 4.7-stable 中 `Node3D::set_global_position()` 会写回节点变换；`PackedScene::pack()`/`SceneState::pack()` 保存当前 owned 场景树；`SceneTree::change_scene_to_packed()`/`PackedScene::instantiate()` 是重新实例化链路。结论：Godot 不会自动区分“演示移动”和“编辑底稿”，应用层必须显式快照/恢复。
- [x] 官方资料：离线 `Node3D`、`PackedScene`、`SceneTree`、`ResourceSaver` 文档确认变换写入、打包保存、实例化与资源保存语义。
- [x] 社区方案：常见做法是把运行态临时状态与持久场景数据分离；本项目采用快照/恢复，不引入插件。

### 验证与边界
- [x] 收尾检查：`git diff --check -- scripts/main.gd tests/p1_runtime_regressions.gd docs/design.md docs/p2_task_schedule.md docs/entity_properties_schema.md docs/architecture.md docs/CODEX_HANDOFF.md devlog/DEVLOG.md` 通过。
- [x] 收尾检查：`rg -n ":=" scripts/main.gd tests/p1_runtime_regressions.gd` 无命中，未引入项目禁用写法。
- [x] Godot 编辑器内 `test_run` 复跑通过：`p1_editor_contracts` 3/3。
- [x] 本轮再次启动运行态回归场景 `res://tests/p1_runtime_regressions.tscn`，`helper_live=true`；启动响应仍带旧的 retained `SceneSessionController` 解析红字，工具标注可能早于本次运行。未在本轮日志读取到新的 `P1_RUNTIME_RESULT` 行，因此不把本轮运行态场景说成“已全绿”。
- [x] 运行态回归场景执行到业务断言：`P1_RUNTIME_RESULT` 共 260 项断言、5 项失败；本次新增 Token 复原/不标脏断言未失败，失败项集中在既有材质/模型手势用例，需另案处理。
- [x] 本轮不做移动范围高亮、速度规则校验、行动点、自动战斗轮次，也不把运行态位置持久化为带团存档。

## 2026-07-17 Codex P2.2 状态核查

### 已完成
- [x] 核对 `docs/design.md`、`docs/p2_task_schedule.md`、`docs/CODEX_HANDOFF.md`、`devlog/DEVLOG.md`、`project.godot`、`scenes/main.tscn`、`scripts/main.gd`、`scripts/movement_service.gd`、`scripts/pointer_interaction_controller.gd`、`scripts/token_properties.gd`、`scripts/cpr_token_properties.gd`、`.agents/skills/`、`.codex/` 与 `addons/`。
- [x] 结论：P2.2 不需要从头再做；当前代码已有运行态 Token 拖动、路线预览、CPR MOVE 预算、超距截停、绕障、体型导航、路线播放。2026-07-17 后口径修订为：编辑态 Token 位置保存/读回，运行态移动是临时演示状态。
- [x] 发现计划口径变化：早期“吸附网格”已被 2026-07-17 计划修订为“不强制吸附/自由测距”，并在 `TokenProperties.snap_to_grid` 中只保留旧存档兼容字段；因此“没吸附网格”不是当前 P2.2 缺口，而是已明确改口的设计。
- [x] 发现并修正文档矛盾：旧 `docs/CODEX_HANDOFF.md` 曾把 Token 拖动列为未完成，已改为 P2.2 基础版完成；后续判断以更新后的设计、排期和代码为准。

### 验证与边界
- [x] 本次只做状态核查和开发日志记录，不改功能代码。
- [ ] 本次未重新运行 Godot 回归；依据来自已有代码、计划文档和最新开发日志。若要把 P2.2 标为“可发布验收”，仍需重跑当前环境可用的自动回归或在可见窗口做一次 GM 拖动体感确认。

## 2026-07-17 Codex P2 运行态按钮归属澄清

### 已完成
- [x] 更新 `docs/p2_task_schedule.md`：新增“运行态按钮归属”小节，明确 P2.1 只做运行态选择和只读面板，不继续塞玩法按钮。
- [x] 明确后续按钮落点：光源开关归 P2.3，Token 射击线/瞄准线归 P2.4，墙体破坏/修复归 P2.6，Token 技能后置，交互物体触发/启用禁用可作为 P2.3 前置小任务或同轮按钮框架用例。

### 验证与边界
- [x] 本次只改工作计划和开发日志，不改功能代码。

## 2026-07-17 Codex 验收说明提示词修正

### 已完成
- [x] 按用户要求更新 `AGENTS.md`：每次功能完成或 bug 修复后，最终报告必须明确写出用户如何验证成果，包括已跑自动测试、Godot 可见窗口里的操作步骤、预期现象，以及哪些仍需人工体感确认。

### 验证与边界
- [x] 本次只改协作提示词和开发日志，不改功能代码。

## 2026-07-17 Codex P2.1 收口与确认流程修正

### 已完成
- [x] 按用户反馈修正 `AGENTS.md`：调研回执、源码对照卡和计划说明只作为进展汇报，不再当成“等用户确认”的暂停点；用户已经明确开始后，继续完成调研、实现、验证和日志维护。
- [x] 复核 P2.1 当前实现：`scripts/main.gd` 已有运行态只读面板 `_prop_runtime_box`，运行态选择刷新 `_populate_runtime_selection_panel()`，Token 短按选择/超过 6 像素转移动，普通对象运行态点击进入选择。
- [x] 修正并复验控制器类型缓存问题：`main.gd` 中 `PointerInteractionController`、`SelectionController`、`PlacementController`、`SceneSessionController`、`CameraViewController`、`MainUiController` 均改为 `load("res://...").new()` 创建，避免 Godot 全局类缓存滞后导致启动解析失败。
- [x] 停掉旧的半挂运行状态后重新启动主场景；Godot AI 运行助手返回 `helper_live=true`，说明主场景已进入可探查运行态。 retained 日志里仍有旧 `SceneSessionController` 解析错误，但磁盘第 73 行已是 `load(...)`，与旧报错不对应，按脏缓存旧日志处理。
- [x] 补强 `tests/p1_runtime_regressions.gd`：新增 `_test_runtime_selection_panel_entity_variants()`，让回归同时覆盖墙体、光源、交互物体的运行态面板映射；Token 原有 MOVE/预算和 6 像素拖动阈值覆盖保留。

### 验证与边界
- [x] `git diff --check -- AGENTS.md scripts/main.gd scripts/pointer_interaction_controller.gd scripts/selection_controller.gd tests/p1_runtime_regressions.gd docs/design.md docs/p2_task_schedule.md devlog/DEVLOG.md` 通过。
- [x] `rg -n ":=" scripts/main.gd scripts/pointer_interaction_controller.gd scripts/selection_controller.gd tests/p1_runtime_regressions.gd AGENTS.md` 仅命中 `AGENTS.md` 的规则说明，没有代码违规。
- [x] 运行态最小求值确认：当前主场景 `Main` 可读到 `_prop_runtime_box`，运行助手通道可用。
- [ ] 本轮未跑完完整 Godot 回归：编辑器测试工具入口调用不稳定；本机 PATH 和桌面搜索均未找到 `Godot_v4.7-stable_win64_console.exe`/`godot`，无法改走命令行回归。最终可见窗口体感仍以 GM 手动点击为准。

## 2026-07-17 Codex 选中物件等比缩放快捷键

### 已完成
- [x] 新增编辑态快捷键：选中物件后按 `]` 或 `=` 放大 10%，按 `[` 或 `-` 缩小 10%；改的是物件根节点 `scale`，不是递归改模型内部子节点。
- [x] 缩放只在编辑态生效；素材拖放中、素材候选中、属性输入框/数字框有焦点时不响应，避免 GM 打字时误缩放。
- [x] 缩放后刷新当前选择视图，`Gizmo3D` 继续绑定当前选中对象，并标记场景为未保存。
- [x] 在运行态回归脚本里补断言：连续放置同点同名模型后，当前选中新对象；按 `]` 后三轴等比变大、Gizmo 仍绑定新对象、场景变脏。

### 四层调研回执
- [x] 项目现状：当前 `main.gd` 已有单选真值 `SelectionController`，Gizmo 缩放依赖 `Gizmo3D` 手柄；用户痛点是“只能通过手柄缩放，不方便三轴一起缩放”。最小安全解是给当前选中根节点增加步进式等比缩放快捷键，不重写 Gizmo。
- [x] Godot 源码：Godot 4.7-stable（提交 `5b4e0cb0f`）`editor/scene/3d/node_3d_editor_plugin.cpp` 中有 `TOOL_MODE_SCALE` / `TRANSFORM_SCALE` / `set_scale` 链路；Scale Mode 绑定为 `spatial_editor/tool_scale`，并有 `get_scale_snap()` 缩放吸附。说明 Godot 编辑器也把缩放作为独立编辑工具处理，而不是混进选择/放置逻辑。
- [x] 官方资料：离线 `gdd_0512_Node.md` 说明键盘输入可走 `_unhandled_key_input()` / `_unhandled_input()`，GUI 先消费；`gdd_0673_Node3D.md` 说明 `Node3D.scale: Vector3`；`gdd_1591_@GlobalScope.md` 确认 `KEY_BRACKETLEFT/RIGHT`、`KEY_MINUS`、`KEY_EQUAL` 常量。
- [x] 社区方案：Godot 3D 编辑器与 Asset Placer 类插件常见做法是提供快捷键/步进调整缩放；本项目不引入新插件，因为需求只是当前选中对象的便捷等比缩放。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] Godot：缩放是选择后进入 `TRANSFORM_SCALE` 并写回节点 `set_scale` -> 本地：`_scale_selected_uniform()` 直接写当前选中 `Node3D.scale` -> 测试：按 `]` 后三轴同时变大。
- [x] Godot：缩放工具不改变当前选择集合 -> 本地：缩放后调用 `_refresh_selection_views()`，让 Gizmo 仍绑定当前对象 -> 测试：`Gizmo3D._selections` 仍含当前对象。
- [x] Godot：编辑操作进入撤销/变更链路 -> 本地：缩放后 `_mark_scene_dirty()` -> 测试：`_scene_dirty == true`。

### 验证与边界
- [x] Godot 编辑器内 `test_run` 通过：`p1_editor_contracts` 3/3。
- [x] `git diff --check -- scripts/main.gd tests/p1_runtime_regressions.gd devlog/DEVLOG.md` 通过。
- [x] `rg -n ":=" scripts/main.gd tests/p1_runtime_regressions.gd` 未发现禁用写法。
- [ ] 完整运行态回归未能完成：`Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/p1_runtime_regressions.tscn` 在 Godot/godot-rust 原生层 signal 11 崩溃，未进入 `P1_RUNTIME_RESULT` 业务断言。
- [ ] 未做多选统一缩放、缩放 UI 面板、连续拖拽式缩放或 Gizmo 源码重写；本轮只做当前单选对象的快捷键等比缩放。

### 手动验收门槛
- [ ] 运行项目，放一个模型并选中；按 `]` 或 `=` 应整体变大，按 `[` 或 `-` 应整体变小。
- [ ] 光标点进属性名称框后按这些键，不应缩放模型。
- [ ] 缩放后直接保存/切场景，应被识别为“有未保存改动”。

## 2026-07-17 Codex 放置后 Gizmo 仍绑定旧对象修复

### 已完成
- [x] 承认本问题不是“新 bug”，而是 P2.0 编辑态点选/Gizmo 输入链问题的同类复发：放入同点同名汽车后，旧对象和新对象重叠，第一次拖动时当前选择/Gizmo 仍可能停在旧对象，视觉上像“拖得动 Gizmo、拖不动模型”。
- [x] 在 `tests/p1_runtime_regressions.gd` 的连续同名模型用例中补失败断言：先放第一辆并选中，再同点放第二辆；要求当前选择目标和 `Gizmo3D` 内部选中项都切到第二辆。
- [x] 在 `scripts/main.gd::_place_model()` 成功获得 `PlacementController.place_model()` 返回的新 `root` 后，立即调用 `_select_entity(placed_root)`，让 `SelectionController`、Gizmo（变换手柄）和属性面板统一绑定新放置对象。

### 四层调研回执
- [x] 项目现状：`PlacementController.place_model()` 已返回新对象根，但 `main.gd::_place_model()` 只清素材按钮和提示文本，没有同步当前选择；现有回归只检查“生成两个同名对象”和“根移动带动模型”，没覆盖放置后的选中归属。
- [x] Godot 源码：沿用本项目已核对的 `4.7-stable` 提交 `5b4e0cb0f` 对照链；Godot 编辑器中对象实例化、选择集合和 Gizmo 刷新是分阶段的，本项目对应 `place_model()` -> `_select_entity()` -> `SelectionController.selection_changed` -> `_refresh_selection_views()` -> `Gizmo3D.select()`。
- [x] 官方资料：离线 Godot 4.7 `PackedScene.instantiate()` / `Node.add_child()` 只负责生成与挂树，不会自动改变编辑选择；选择和属性面板必须由上层状态显式更新。
- [x] 社区方案：Godot Asset Placer 一类放置器采用“放置完成后聚焦新实例/进入变换”的交互思路；本轮不引入插件，只补本项目漏掉的放置后选择同步。

### 验证与边界
- [x] `git diff --check -- scripts/main.gd tests/p1_runtime_regressions.gd` 通过。
- [x] `rg -n ":=" scripts/main.gd tests/p1_runtime_regressions.gd` 未发现项目禁用写法。
- [ ] 运行态完整回归未能完成：命令行运行 `Godot_v4.7-stable_win64_console.exe` 启动测试场景时在 Godot/godot-rust 原生层 signal 11 崩溃；编辑器导入检查受沙箱限制无法写 `AppData/Roaming/Godot` 与 `AppData/Local/Godot` 缓存。两者都未进入业务断言，不能算测试失败，也不能算完整通过。
- [ ] 尚未由用户手动验证当前窗口体感：请重新放一辆汽车，放下后不要再点第二次，直接拖 Gizmo；预期属性栏名称和 Gizmo 都应指向新放置的 `破损汽车3D模型2`，模型应立刻跟着动。

## 2026-07-17 Codex R5 UI 与相机收口

### 已完成
- [x] 先写失败测试：`tests/p1_runtime_regressions.gd` 新增 R5 控制器契约测试，要求存在 `CameraViewController`（相机视图控制器）和 `MainUiController`（主界面控制器）及公开方法；红灯确认为两个脚本缺失。
- [x] 新增 `scripts/camera_view_controller.gd`：收口地图/自由视角状态、滚轮缩放、右键旋转、中键平移、保存/恢复游玩视角和网格刷新。
- [x] 新增 `scripts/main_ui_controller.gd`：收口顶栏按钮状态、运行态左栏显隐、左栏/属性栏命中判断和属性栏显示/隐藏。
- [x] `scripts/main.gd` 接入两个控制器，保留旧函数入口作兼容包装；继续负责创建节点、连接信号、投屏按钮、Gizmo、选择、放置、场景会话和跨模块协调。
- [x] `docs/p2_task_schedule.md` 标记 R5 完成；`docs/architecture.md` 增补 R5 控制器职责边界。

### 四层调研回执
- [x] 项目现状：R4 后 `main.gd` 仍直接维护 `_map_size/_map_focus/_orbit_*`、顶栏按钮、左栏/属性栏命中判断和属性栏显示隐藏；测试仍直接读取部分 UI 私有成员。R5 目标是迁移相机和 UI 状态维护，不大删旧兼容入口。
- [x] Godot `4.7-stable` 源码（提交 `5b4e0cb0f`，本地源码包 `reference/godot-4.7-stable-full.zip.zip`）：`scene/gui/control.cpp` 的锚点/全局矩形链路，`scene/gui/container.cpp` 的布局排序，`scene/3d/camera_3d.cpp` 的 current/projection/fov/size 与射线投影，`scene/main/viewport.cpp` 的可见矩形、输入传播和 active camera，`scene/main/window.cpp` 的窗口显示链路，`editor/scene/3d/node_3d_editor_plugin.cpp::Node3DEditorViewport::_sinput()` 与 `View3DController` 的 3D 视角状态集中管理。
- [x] 官方离线资料：`gdd_0565_Control.md`、`gdd_0538_Button.md`、`gdd_0540_Camera3D.md`、`gdd_0774_Viewport.md`、`gdd_0786_Window.md`、`gdd_0296_Using_Viewports.md`、`gdd_0512_Node.md` 确认 Control（界面控件）、Button（按钮）、Camera3D（3D 相机）、Viewport（视口）和 Window（窗口）的现行 4.7 API。
- [x] 英文社区/现成方案：Godot UI 组件常见做法是把界面行为拆到 Control/CanvasLayer 相关组件；orbit camera（轨道相机）常见做法是让相机控制脚本保存 yaw/pitch/distance/focus 状态，主场景只调用控制器。R5 采用“控制器挂在 Main 下”的轻量拆分，不引入全局 UI autoload 或新插件。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] Control 使用全局矩形参与命中判断 -> `MainUiController.is_over_left_panel()` / `is_over_property_panel()` 统一左栏和属性栏命中 -> 回归覆盖素材拖放、右键菜单和左键地图点击路径不被 UI 误抢。
- [x] Button 文案和显隐是界面组件职责 -> `MainUiController.apply_topbar_for_mode()` / `apply_panel_for_mode()` 维护模式按钮、子模式按钮、保存/恢复视角按钮和运行态左栏隐藏 -> 运行态/编辑态回归仍通过。
- [x] Camera3D 每个视口使用当前相机和投影参数 -> `CameraViewController.apply_for_mode()` 维护正交地图视角与自由透视视角，主相机仍是原 `Camera3D`，投屏继续镜像同一个主相机 -> 隔离导入和运行态回归通过。
- [x] Godot 编辑器 3D 视图把视角状态集中到视图控制器 -> 本地 `CameraViewController.zoom()` / `orbit()` / `pan()` / `save_play_view()` / `restore_play_view()` 持有视角真值 -> 滚轮、右键、中键和保存/恢复视角旧入口保持可用。

### 验证与边界
- [x] 失败测试红灯：隔离回归先失败于 `R5 camera view controller script is missing` 和 `R5 main UI controller script is missing`。
- [x] Godot 导入解析通过：`Godot v4.7.stable.official.5b4e0cb0f` 已注册 `CameraViewController` 与 `MainUiController`。
- [x] 隔离无窗口回归通过：`P1_RUNTIME_RESULT {"assertions":237,"failed":0,"failures":[]}`。
- [x] `git diff --check -- scripts/main.gd scripts/camera_view_controller.gd scripts/main_ui_controller.gd tests/p1_runtime_regressions.gd` 通过。
- [x] `rg -n ":=" scripts/main.gd scripts/camera_view_controller.gd scripts/main_ui_controller.gd tests/p1_runtime_regressions.gd` 未发现禁用写法。

### 未做
- [ ] 未做 P2.3-P2.6 新功能：没有新增光源开关、战斗碰撞、LOS（视线遮挡）或墙体破坏。
- [ ] 未一次性删除 `main.gd` 的旧 `_map_size/_map_focus/_orbit_*` 兼容镜像，也未清理 R4 留下的旧死代码；后续若删除，需先把仍直接访问 `main.gd` 私有成员的测试迁到控制器公开接口。
- [ ] 未把 UI 节点本身搬进 `.tscn` 或单独场景；R5 只迁移行为控制权，保持当前运行时创建 UI 的外观和操作方式不变。

### 下一阶段门槛
- [ ] R0-R5 结构治理阶段已完成。进入 P2.3 前必须重新确认目标功能范围，按项目门禁先完成四层调研和 Godot 4.7 源码对照卡；不得把结构清理和新功能混成一轮。

## 2026-07-17 Codex R4 场景会话收口

### 已完成
- [x] 新增 `scripts/scene_session_controller.gd`，作为 `SceneSessionController`（场景会话控制器）：统一当前场景名、未保存标记、新建、保存、切换、默认空场景、内容根清理、存档读回搬运、owner（归属节点）重设和旧对象迁移触发。
- [x] `scripts/main.gd` 保留左栏按钮、未保存弹窗、工具栏文案和兼容包装函数；新建/保存/切换/默认空场景已委托给 `_scene_session_controller`。旧 `_current_scene_name` / `_scene_dirty` 暂作为 UI 和既有测试镜像保留，不在 R4 大删。
- [x] `tests/p1_runtime_regressions.gd` 先加入 R4 合约测试，要求控制器存在并暴露 `configure()`、`apply_default_scene()`、`switch_to_scene()`、`save_current_scene()`、`mark_dirty()`、`is_dirty()`、`clear_dirty()`、`set_current_scene_name()`、`get_current_scene_name()`。
- [x] 补上脏场景新建取消保护：当前场景有未保存改动时点“新建场景”，不再提前调用 `ModuleGate.add_scene()`；只有用户选择“保存后切换”或“不保存直接切换”后才真正创建新场景，取消不会偷偷改全局当前地点。
- [x] 修复 R3 遗留的解析阻塞：`scripts/placement_controller.gd` 继承 `Node`，不能直接调用 `get_world_3d()`；已改为通过已配置的 `_content_root.get_world_3d()` 获取 3D 世界。该修复只为恢复 R3 控制器可编译，不新增放置功能。
- [x] 更新 `docs/p2_task_schedule.md`，将 R4 标为完成，并记录隔离回归 `217/217` 通过。
- [x] 更新 `docs/architecture.md`，补充 `SceneSessionController` 的职责边界，明确 `ModuleGate` 仍持有模组/地点真值，`ModuleIo` 仍负责 `PackedScene` 存读盘，`main.gd` 继续做 UI 与跨模块协调。

### Godot 4.7 行为映射
- [x] 项目现状：R3 后 `main.gd` 仍直接管新建、切换、保存、dirty（未保存标记）、加载、清理；`ModuleGate` 管模组/地点真值；`ModuleIo` 管 `PackedScene` 存读盘。R4 目标是把场景会话流程收口，不动 UI/相机。
- [x] Godot 源码：本地 4.7 stable 源码包，运行提交 `5b4e0cb0f`；对照链路为 `scene/resources/packed_scene.cpp::PackedScene::pack()` -> `SceneState::pack()` -> `_parse_node()`，`PackedScene::instantiate()` -> `SceneState::instantiate()`，`scene/main/node.cpp::add_child/remove_child/set_owner/queue_free()`，`scene/main/scene_tree.cpp::change_scene_to_file()` -> `ResourceLoader::load()` -> `change_scene_to_packed()` -> `instantiate()` -> `change_scene_to_node()`，以及 `editor/editor_node.cpp::_save_scene()` / `open_scene()`。
- [x] 官方离线文档：`gdd_1006_PackedScene.md`、`gdd_0512_Node.md`、`gdd_1476_ResourceLoader.md`、`gdd_1477_ResourceSaver.md`、`gdd_1481_SceneTree.md`。
- [x] 社区方案：常见 Godot Scene Manager（场景管理器）/保存系统做法是集中入口、明确当前场景状态、不让 UI 直接操纵节点树；本项目不引入插件，采用轻量控制器，因为当前需求是桌面 GM 工具内的单 exe 场景会话，不是通用游戏关卡管理框架。

### 验证
- [x] 隔离工程导入：`Godot_v4.7-stable_win64_console.exe --headless --import --quit` 通过，脚本全局类注册包含 `PlacementController` 和 `SceneSessionController`。
- [x] 运行态回归：`P1_RUNTIME_RESULT {"assertions":217,"failed":0,"failures":[]}`。
- [x] 禁用写法检查：`rg -n ":=" scripts/placement_controller.gd scripts/scene_session_controller.gd scripts/main.gd tests/p1_runtime_regressions.gd` 无结果。
- [ ] Godot 退出时仍报告测试夹具级别的 `ObjectDB instances leaked` 与 `resources still in use` 提示；回归进程退出码为 0，断言无失败，本轮未把它作为 R4 阻塞。

### 未做
- [ ] 未进入 R5：UI 构建、左栏/属性栏/顶栏拆分、相机轨道与地图视角控制器仍未迁移。
- [ ] 未新增 P2.3-P2.6 功能：没有做光源开关、战斗碰撞、LOS（视线遮挡）或墙体破坏。
- [ ] 未一次性删除 `_apply_default_scene()` / `_switch_to_scene()` 后面的旧死代码；R4 只在入口委托控制器并保留兼容镜像，避免一次大删影响用户操作路径。后续可在 R5 或专门清理阶段删除。

### 下一阶段门槛
- [ ] R5 开始前先写 UI/相机控制器失败测试，再拆左栏、顶栏、属性栏和相机参数维护；不得顺带做 P2.3-P2.6 新功能。
- [ ] R5 仍需先公开 Godot 4.7 源码对照卡，重点覆盖 Control（界面控件）、Camera3D（3D 相机）、Window/Viewport（窗口/视口）相关行为。

## 2026-07-16 Codex P2.1 运行态选择 + 操作面板规划

### 已完成的规划
- [x] 核对 `docs/design.md` 与 `docs/p2_task_schedule.md`：最新口径为运行态单击对象显示 GM 专用名称、类型、状态和当前真正可用操作；Token 移动继续直接拖动，不新增重复移动按钮，也不提前放射击线、技能、墙体破坏或光源开关占位按钮。
- [x] 核对 `scripts/main.gd`：现有拾取真值为 `_pick_entity_at_screen_position()` -> `_find_entity_root()`，编辑态选择走 `_try_select_at_mouse()` -> `_select_entity()`，运行态左键目前优先 `_try_begin_runtime_token_drag()`，因此 P2.1 应补运行态点击选择分支，并避免和 Token 拖拽互抢鼠标。
- [x] 核对 `scripts/mode_gate.gd`：编辑/运行真值只在 `ModeGate`，新面板应按既有“功能自报归属”模式新增自己的 `_apply_runtime_action_panel_for_mode()`，不把逻辑塞进 `_on_mode_changed()`。
- [x] 核对 P2.0 组件：`EntityProperties.get_effective_entity_type()` 是类型分派入口；Token/墙体/光源/交互物体分别读 `TokenProperties` + `CprTokenProperties`、`WallProperties`、`LightProperties`、`InteractableProperties`，不再按 `category` 字符串散落判断。

### Godot 4.7 源码对照卡
- [x] Godot 4.7 源码链：`editor/scene/3d/node_3d_editor_plugin.cpp::Node3DEditorViewport::_sinput()` 在鼠标按下时用 `_select_ray()` 查命中，鼠标松开且不是变换时走 `_select_clicked()`；多候选路径用 `_find_items_at_pos()` -> `_list_select()`。
- [x] Godot 选择真值：`editor_data.cpp::EditorSelection::add_node/remove_node/clear/update/_emit_change()` 维护统一选择集合并发 `selection_changed`；`scene_tree_editor.cpp::set_editor_selection()` 订阅该信号，`_selection_changed()` 反向刷新树项选择。
- [x] 本项目映射：Godot `Camera3D.project_ray_origin/project_ray_normal` 与射线选择对应本地 `_pick_entity_at_screen_position()`；Godot `EditorSelection` 对应本地计划新增的运行态当前对象状态；Godot `EditorNode::edit_node()`/检查器刷新对应本地运行态操作面板刷新。
- [x] 无法照搬处：本项目是 GM 运行工具，不暴露 Godot 编辑器检查器、不需要多选/锁定/编辑器 owner 过滤；P2.1 只做运行态单选和 GM 面板，投屏窗口仍只显示 3D 世界。

### 面板方案
- [x] 建议新增独立运行态操作面板，放在主窗口 `_ui_layer` 下；编辑态隐藏，运行态无选择时隐藏或显示空状态；投屏窗口是独立 `Window` + 共享 `World3D`，不会承载主窗口 CanvasLayer，因此 GM 控件不进玩家画面。
- [x] 对象到内容映射：Token 显示名称、类型、`MOVE`/预算、`can_move` 与“直接拖动移动”的状态说明；墙体显示状态、可破坏、耐久、挡视线/挡枪线/掩体；光源显示开关状态、类型、亮度、范围、阴影；交互物体显示启用、交互标签、状态、触发模式；地形/装饰显示可见性与通行标签。
- [x] 当前按钮口径：P2.1 不放尚未实现按钮。交互物体的触发/启用禁用若要做成可点击动作，应在实现前再次确认是否并入 P2.1；否则先作为状态/入口显示。

### 待实现与验证
- [ ] 未写功能代码；等待后续确认或继续任务时再实现。
- [ ] 验证方法：运行态点击 Token/墙体/光源/交互物体/地形/装饰分别刷新面板；点击空地取消；按住拖 Token 不误触普通选择；编辑态仍显示原属性面板；投屏窗口不出现 GM 面板；保存/加载不引入新的运行期 UI 节点。

## 2026-07-16 CPR 资料门禁 + P2.2 范围纠正

### 用户质疑与结论
- [x] 用户新增 `docs/cpr_reading/` 规则资料包，并明确要求：今后凡涉及游戏规则必须先查该资料。
- [x] 查阅 `agent_index/agent_readme.md`、`agent_keyword_index.json`、`agent_chunks.jsonl` 与核心规则文字版；相关正文块为 `cyberpunk_red_core-p0144-c001`、`cyberpunk_red_core-p0145-c001`，均标记 `needs_pdf_check=false`。
- [x] CPR 依据：《赛博朋克 RED 核心规则书》PDF p.144（书内 p.126）规定基础移动动作上限为 MOVE × 2 米/码，网格模式为 MOVE 格、允许斜向移动，并规定每格 2 米/码；PDF p.145（书内 p.127）说明每回合一次移动动作，“跑”消耗其他动作再获得一次移动动作。
- [x] 撤回“P2.2 核心已完成”的结论。当前代码只完成拾取、拖拽、保存和旧 Token 迁移底层；没有 MOVE 字段、范围显示、超距阻止和移动起点/重置语义，不能称为完整 Token 移动。
- [x] 当前 1 米吸附来自本项目 `GridManager.BASE_STEP`，不是 CPR 规则。CPR 网格模式应按 2 米/码一格；若采用自由测距则不应强制吸附。
- [x] 进一步纠正 schema 边界：CPR 没有要求软件自动吸附；是否使用网格属于场景/本次移动模式，不是 Token 固有属性。现有 `TokenProperties.snap_to_grid` 只视为拖拽底层兼容字段，P2.2 应迁出或停用。
- [x] 当时指出连续拖动会绕过完整轮次记账，并曾建议 GM 手动开始/结束；该交互随后被用户否决，最终方案改为“每次直接拖动是一条移动命令，是否允许下一条由 GM 决定”，不增加开始/结束按钮。

### 文档修改
- [x] `docs/design.md` 加入 CPR 规则资料查阅门禁，并把产品边界修正为“不做完整自动规则引擎”，而不是禁止所有局部规则辅助。
- [x] `docs/p2_task_schedule.md` 把 P2.2 改回进行中，补齐 CPR MOVE 移动的完成条件。
- [x] 当时草案把 `move_stat` 放入 `TokenProperties`；后续因多规则集边界纠正为 `CprTokenProperties.move_stat`，并把移动会话状态与永久属性分开。

### 当轮未做（后续状态已回填）
- [x] 当轮没有继续修改功能代码；其后 P2.2 已停用 1 米吸附、加入范围限制并完成验收。
- [x] 障碍绕行和困难地形已在 P2.2 落地；擒拿拖行、伤势减速和“跑”的第二次移动仍按原结论后置。

### 问题状态
| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-16 | 把自由拖拽底层误报为 P2.2 Token 移动完成。 | 已撤回完成结论，P2.2 恢复为进行中 |
| 2026-07-16 | 1 米吸附没有 CPR 规则依据。 | 已确认 CPR 为 2 米/码一格；功能代码待后续修正 |
| 2026-07-16 | 连续拖动可反复刷新移动范围。 | 已列为 P2.2 必须解决的动作起点/重置边界 |

## 2026-07-16 Codex P2.2 Token 运行态拖拽底层

### 已完成的底层
- [x] `scripts/main.gd` 增加运行态 Token 直接拖动：左键按下通过既有 `PickProxy` 拾取对象，只有对象类型为 Token 且 `TokenProperties.can_move=true` 才进入拖动；鼠标移动投影到 Token 当前高度的水平面，保持抓取偏移和 Y 高度，松手后把场景标记为未保存。
- [x] `TokenProperties.snap_to_grid=true` 时按 `GridManager.BASE_STEP=1.0` 吸附 X/Z。此项测试只证明当前代码行为稳定；后经 CPR 资料核对，1 米吸附不符合 CPR 2 米/码一格，不能作为最终规则验收。
- [x] 输入分层：开始拖动走 `_unhandled_input()`，避免点击 GUI 时穿透；拖动与松手走 `_input()`，避免鼠标松在面板上导致拖动状态残留；切回编辑态会清理拖动状态。
- [x] `_try_select_at_mouse()` 的射线拾取抽成 `_pick_entity_at_screen_position()`，编辑态选中与运行态 Token 拖动复用同一拾取真值，没有新建第二套碰撞层。
- [x] 旧场景加载时按 `EntityProperties.category` 补齐明确 `entity_type` 与缺失的专属组件；已有组件不重复挂。真实场景中的两个旧 Token 均补出 `TokenProperties`，地形汽车没有误挂。
- [x] `tests/p1_runtime_regressions.gd` 增加旧 Token 迁移、重复迁移保护、网格吸附、保持高度、`can_move=false`、非 Token 拦截、移动位置和专属组件保存/读回验证。

### Godot 4.7 行为映射
- [x] 项目运行版本由日志锁定为 `Godot 4.7.stable.official.5b4e0cb0f`，不是只按 `project.godot` 推测。
- [x] 既有源码对照记录 `editor/scene/3d/node_3d_editor_plugin.cpp` 的 `_select_ray()` -> `_find_items_at_pos()` -> `_select_clicked()`，对应本地 `_pick_entity_at_screen_position()` -> `_find_entity_root()` -> 运行态 Token 拖动目标。
- [x] Godot 4.7 离线文档 `gdd_0540_Camera3D`、`gdd_0255_Ray-casting`、`gdd_1407_PhysicsRayQueryParameters3D`，对应本地屏幕点转世界射线、`Area3D` 拾取与水平面投影；运行测试覆盖 Token/非 Token/禁用移动分流。
- [x] `scene/main/node.cpp::Node::add_child()` / `Node::set_owner()` 与 `scene/resources/packed_scene.cpp::PackedScene::pack()` / `SceneState::_parse_node()`，对应加载迁移补组件及 `ModuleIo.save_scene_tree()`；运行测试覆盖移动位置和组件保存/读回。
- [ ] 公开 GitHub 无法解析本机 4.7 构建的 `4.7-stable` 标签或提交 `5b4e0cb0f`，两次官方 raw 地址均返回 404。本轮不宣称完整复刻 Godot 编辑器变换提交链；只沿用已记录的选择链，并用本机 4.7 离线 API 与运行态结果验证本地实现。

### 验证
- [x] `script_manage(find_symbols)`：`scripts/main.gd` 与 `tests/p1_runtime_regressions.gd` 均由 Godot 4.7 成功解析。
- [x] 编辑器契约测试：`p1_editor_contracts` 3/3 通过。
- [x] 运行态回归：`P1_RUNTIME_RESULT {"assertions":70,"failed":0,"failures":[]}`。
- [x] 主场景启动：`helper_live=true`、`current_run_errors=[]`；真实存档两个旧 Token 自动补挂组件，地形不挂；本次运行未保存正式场景。
- [x] `git diff --check` 通过；本轮修改文件无 `:=`。

### 未做
- [ ] 自动输入工具能发送鼠标事件，但没有驱动本项目独立原生窗口的 GUI，无法自动切换运行态完成可见窗口拖动；最终鼠标手感待 GM 手动拖一次确认。
- [x] 当轮尚未实现这些内容；后续已完成移动范围、路径规划和碰撞阻挡。P2.1 通用运行态操作面板与 Token 选中标记仍是下一项。
- [ ] 未加入生命值、伤害、行动点、速度、命中率、技能或其他规则系统内容。

### 问题状态
| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-16 | 旧存档 Token 缺少 `TokenProperties`，新移动入口会拒绝它。 | 已在场景加载时幂等补组件，并用真实存档与回归测试验证 |
| 2026-07-16 | 精确 4.7 构建提交无法从公开 Godot 仓库取回源码。 | 已明确记录为来源风险；不宣称完整编辑器行为一致 |
| 2026-07-16 | 自动鼠标事件未驱动独立原生窗口 GUI。 | 不以自动输入冒充通过；保留 GM 手动手感确认 |

## 2026-07-16 Codex P2.0 对象类型系统代码落地
### 已完成
- [x] 在 `docs/entity_properties_schema.md` 补齐 P2.0 schema：通用 `EntityProperties` 只保留对象共性和兼容字段，Token/墙体/光源/交互物体分别走专属属性组件。
- [x] `scripts/entity_properties.gd` 增加 `SCHEMA_VERSION=2`、`EntityType` 枚举、`schema_version`、`entity_type`，以及按素材栏 `category` 映射对象类型的入口；旧字段继续保留为兼容层，没有删除旧存档字段。
- [x] 新增 `scripts/token_properties.gd`、`scripts/wall_properties.gd`、`scripts/light_properties.gd`、`scripts/interactable_properties.gd`。其中 `LightProperties` 使用 `light_range`，避开 GDScript 内置 `range()` 同名警告。
- [x] `scripts/main.gd::_place_model()` 在新放置物件时写入对象类型，并自动挂载对应专属属性组件；地形和装饰目前只保留通用 `EntityProperties`。
- [x] 为避免 Godot 新 `class_name` 全局缓存滞后，`main.gd` 和 `tests/p1_runtime_regressions.gd` 改为按脚本路径 `load()` 后创建专属组件，不直接依赖 `TokenProperties` 等全局类名。
- [x] `tests/p1_runtime_regressions.gd` 覆盖 schema 版本、对象类型、`WallProperties` 从旧墙体字段迁入以及存读持久化。
### Godot 4.7 源码映射
- [x] `scene/main/node.cpp::Node::add_child()` / `Node::set_owner()` -> 本项目 `main.gd::_place_model()` / `_attach_entity_type_properties()`：组件必须挂到内容树下，且 owner 指向内容根，才能被后续保存链路正确识别。
- [x] `scene/resources/packed_scene.cpp::PackedScene::pack()` / `SceneState::_parse_node()` -> 本项目 `ModuleIo.save_scene_tree()` 与 P2.0 持久化测试：只保存 owner 范围内的属性组件。
- [x] `editor/inspector/editor_inspector.cpp` 的“对象属性按对象/组件分组展示”思路 -> 本项目只做数据组件边界，不在 P2.0 做运行态操作面板。
- [x] `editor/scene/3d/node_3d_editor_plugin.cpp` / 既有拖放链路记录 -> 本轮不改 3D 视口拖放行为，只在放置完成后补挂属性组件。
### 验证
- [x] `script_manage(find_symbols)` 通过：`entity_properties.gd`、四个专属属性脚本、`main.gd`、`tests/p1_runtime_regressions.gd` 均可被 Godot 4.7 解析。
- [x] `test_run` 通过：`p1_editor_contracts` 3/3。
- [x] `project_run(mode=main, autosave=false)` 通过：`helper_live=true`，`current_run_errors=[]`。
- [x] 运行态临时检查通过：`token/wall/light/interactable` 分别挂载 `TokenProperties/WallProperties/LightProperties/InteractableProperties`；`terrain/decor` 不挂专属组件。
- [x] 运行态 game log 干净，仅有 Godot AI helper 注册和窗口移动提示；编辑器日志游标检查无本轮新增错误。编辑器 Errors 面板仍能读到旧测试插件历史错误行，不属于本轮 P2.0 改动。
### 未做
- [ ] 未实现 P2.1 运行态选择/操作面板；本轮只落 schema 和组件边界。
- [ ] 未迁移全量旧场景；仅在新放置物件和回归测试路径中覆盖墙体旧字段迁入。
- [ ] 未实现 Token 移动、射击线/命中、LOS、墙体破坏算法或规则系统字段。
- [ ] 用户审核结论：Token 下一步先做移动，不做生命值/行动点/伤害；交互物体后置项需要包含电箱爆炸、打翻火盆、燃烧、伤害等具体效果；光源优先做 Godot 点光源，聚光可预留，方向光/太阳光暂归到全局光照或 P3 气氛系统。
### 问题状态
| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-16 | Godot 新 `class_name` 脚本可能在运行态全局类表注册滞后，直接写 `TokenProperties` 曾导致启动期解析断点。 | 已用脚本路径 `load()` 绕开，并完成重启验证 |
| 2026-07-16 | 光源字段原名 `range` 与 GDScript 内置函数同名，产生黄色警告。 | 已改为 `light_range` 并同步 schema |
| 2026-07-16 | P2.0 只定义数据边界，尚不能让 GM 在运行态点击对象执行不同操作。 | 留给 P2.1 |

## 2026-07-16 Codex P2.3 光源开关规划

### 已完成
- [x] 核对 `docs/design.md` 与 `docs/p2_task_schedule.md`：P2.3 是跑团运行态的光源物件开关，状态必须随场景保存/加载，不等同于 P3 场景气氛或复杂环境预设。
- [x] 核对当前代码：光源已有素材栏位 `category="light"`；物件放置进入 `_content_root`，保存通过 `ModuleGate.save_current_scene()` / `ModuleIo.save_scene_tree()` 打包内容层；投屏窗口通过 `CastView` 共享主窗口 `World3D` 并用玩家相机 `cull_mask` 过滤 GM-only 层。
- [x] Godot 4.7 离线 API 对照完成：`Light3D.light_energy/light_color/shadow_enabled/light_size`、`OmniLight3D.omni_range`、`SpotLight3D.spot_range/spot_angle`、`Viewport.world_3d`、`Camera3D.cull_mask/current`、`VisualInstance3D.layers`、`PackedScene.pack()`、`Node.owner`、`@export` 存储字段均有离线文档依据。
- [x] 规划结论：新增 `LightProperties` 光源专属组件承载开关状态与基础光参；运行态操作面板只提供开关按钮，亮度/颜色先作为入口或后置，不做 P3 场景气氛。

### 待确认
- [ ] 等用户明确确认后才写功能代码：创建 `scripts/light_properties.gd`、放置光源时挂组件、运行态点击光源显示开关按钮、保存/读回后自动应用开关状态、验证投屏同步。
- [ ] 实现前若要宣称“按 Godot 源码行为”，仍需补 Godot 4.7-stable 引擎源码对照卡；本轮只完成项目代码与 Godot 离线 API 对照，未改功能代码。

### 问题状态
| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-16 | 光源开关必须只作用于光源物件自身，不能改骨架层 DirectionalLight3D 或 WorldEnvironment，否则会越界成 P3 场景气氛。 | 规划中 |

## 2026-07-16 Codex P2 开发顺序构思
### 已完成
- [x] 重新核对 `docs/design.md`、`devlog/DEVLOG.md`、`project.godot`、`scenes/main.tscn`、`scripts/main.gd`、`.agents/skills/`、`.codex/`、`addons/` 与空文件 `docs/CCxGodot.md`，确认 P1 已完成、P2 入口应从 Token 运行态拖拽开始，再进入 LOS（视线遮挡）和墙体破坏。
- [x] 初步排序理由：Token 拖拽只依赖现有 Token 分类、ModeGate（编辑/运行切换）和保存链路；LOS 依赖 `EntityProperties.los_occluder` 与未来遮挡轮廓；墙体破坏依赖墙体对象、生命值/可破坏属性、LOS 重算和视觉/光照反馈，因此不宜先做。
- [x] 二次复查后承认原计划仍有系统性缺漏：`scripts/entity_properties.gd` 注释已明确“token 那套 20+ 字段留 P2”，说明 Token 专属数据不是新发现，而是 P2 前置地基；`docs/design.md` 的运行态清单有光源开关和投屏模式，但优先级表未单列光源开关，容易漏排；`docs/design.md` 同时把 LOS 列 P2、把 `LOSOccluder` 列 P3/P4，阶段定义存在矛盾。
- [x] 已把修正后的 P2 任务安排写入 `docs/design.md`：P2.0 对象类型系统/schema、P2.1 运行态操作面板、P2.2 Token 移动、P2.3 光源开关、P2.4 CombatBody/挡枪线、P2.5 LOS 基础、P2.6 墙体破坏最小闭环。
- [x] 新增 `docs/p2_task_schedule.md`，用作后续 P2 开工顺序的固定依据；不需要用户再手动整理口头结论。
- [x] 按用户更正“Codex 的任务安排”后，已在 Codex 侧创建并命名 7 个项目任务：P2.0 `019f69fd-6c5d-7521-b2d8-39be73cad073`，P2.1 `019f69fd-8d24-7000-82a4-59b27bef77c5`，P2.2 `019f69fd-ab34-7a01-b67d-f39e7796f640`，P2.3 `019f69fd-c08d-7410-bd93-a32d84b41d10`，P2.4 `019f69fd-e044-7f33-90a9-b6079e233f1c`，P2.5 `019f69fd-ff0a-74a1-96b7-3cd7bcba247d`，P2.6 `019f69fe-2dc5-79e0-9819-abd2965b2c79`。每个任务的初始提示都要求先做规划/源码对照卡，不允许直接改功能代码。
### 当时待确认（后续状态已回填）
- [x] P2 顺序已经确认；涉及拖拽、选中、3D 视口、运行态交互、遮挡或破坏行为时仍须先完成 Godot 4.7 源码对照卡。2026-07-16 起，用户已明确授权任务后不再为普通文件修改重复等待固定确认口令。
- [ ] 射击命中暂不并入 LOS（视线遮挡）一起做：LOS 解决“看不看得见”，射击命中会牵涉武器、距离、掩体、命中判定、伤害和规则口径，容易越过项目“不做骰子/规则系统”的边界。可先预留 CombatBody（战斗碰撞体）/射线查询接口，等 LOS 和 Token 运行态移动稳定后再决定是否只做“挡枪线”几何判定。
- [x] P2.0 已补齐对象类型档案和专属组件设计；Token 的 CPR MOVE 已放入规则集专属 `CprTokenProperties`，技能、命中、伤害继续后置。
- [x] P2.0 已拆出对象类型系统：通用 `EntityProperties` 与 Token、墙体、光源、交互物体专属组件边界已经落地并完成迁移验证。
- [ ] P2 需要补“运行态选择/操作面板”：编辑态属性面板已有，但运行态点击 Token/墙体/光源/交互物体时应出现不同操作按钮；按钮内容必须按对象类型生成，不能只靠 `category` 字符串散落判断。
- [x] 光源开关已单列为 P2.3：“光源对象组件 + 开关状态 + 保存读回”，不等同于 P3 场景气氛。
- [x] `docs/entity_properties_schema.md` 已补成正式 schema，并用于 P2.0 对象类型组件实现和迁移验证。

## 2026-07-16 Codex P1 V4 最终闭环

### 结论
- [x] **P1 已完成，可以进入 P2。** 最终测试件为 `build/windows/p1_test_v4/Gvtt-P1-test-v4.exe`，109,548,688 bytes（104.47 MiB），SHA-256 `5F7E2A3A38EF9AA2DB7B871A7A6C5F453721FDD9AC8E8A021949EE2186037C89`。
- [x] `docs/design.md` 的五项 P1 优先级已同步标记为 2026-07-16 完成，设计总表与本日志最终结论一致。
- [x] Godot 4.7 发布导出退出码 0，错误输出 0 bytes；同一 EXE 使用全新隔离用户目录无界面启动，退出码 0，没有错误、警告、泄漏或孤儿节点，并实际迁移生成两份内置场景。
- [x] P1 运行态回归重跑为 `P1_RUNTIME_RESULT {"assertions":47,"failed":0,"failures":[]}`；编辑器契约测试重跑 3/3 通过、6 个断言、0 失败、0 跳过。
- [x] `scripts/` 与 `tests/` 无 `:=`；`git diff --check` 通过。旧日志里的 V3 哈希、7/7、9/9、10/10 测试结果均为历史快照，本节的 V4、47 项运行断言和 3 项编辑器测试是最终口径。

### 本轮最终修复
- [x] `ModuleIo` 在临时摘下运行期节点前先清除旧 `owner`，恢复时先挂回父节点再恢复 `owner`，消除真实的 owner 不一致警告；运行态存读测试证明持久节点不丢、运行期拾取节点不入存档、恢复后父节点与 owner 正确。
- [x] `SceneProps` 增加 `ground_tex_source`；导入地面纹理保存来源，切场景按“来源 + 名称”恢复，旧存档可自动识别来源；删除正在使用的导入纹理会立即恢复默认地面并置脏。
- [x] 导入 GLB 在导入阶段转换并持久保存为 `.scn` 缓存；启动时只后台预热现有原生缓存，拖动和正式放置复用 `PackedScene`，覆盖、失效、重建和删除清理均有运行态回归覆盖。
- [x] Windows 导出预设去掉本机绝对模板路径，保留单 EXE 内嵌 PCK；排除提示词、离线资料、测试、开发文档和纯编辑器插件。`godot_ai` 只随包保留运行探查必需的 `game_helper.gd`、`game_logger.gd`、`log_backtrace.gd`。

### Godot 4.7 源码映射
- [x] `scene/main/node.cpp::Node::add_child()` / `Node::set_owner()` → `scripts/module_io.gd::_detach_runtime_nodes()` / `_restore_runtime_nodes()` → 运行态保存后父节点与 owner 恢复断言。
- [x] `scene/resources/packed_scene.cpp::SceneState::pack()` / `PackedScene::pack()` → `ModuleIo.save_scene_tree()` 的持久节点与运行期节点边界 → 场景存读、PickProxy 重连、运行期节点排除断言。
- [x] `editor/import/3d/resource_importer_scene.cpp::ResourceImporterScene::import()` 的“导入阶段 pack 并保存 `.scn`” → `LibraryManager._pack_model_runtime()` / `_save_model_cache()` → 缓存生成、失效、重建、删除断言。
- [x] `editor/scene/3d/node_3d_editor_plugin.cpp::_create_preview_node()` / `_create_instance()` 的“加载原生资源后实例化预览与正式节点” → `main.gd::_warm_model_cache_for_path()` / `_get_cached_packed_scene()` / `_load_model_instance()` → 拖动入口和模型缓存实例化断言。
- [x] 额外核对 `editor/file_system/editor_file_system.cpp::_is_test_for_reimport_needed()` / `_test_for_reimport()`：Godot 用修改时间做快速筛选，再在需要时比较内容摘要。该对照用于确认当前缓存方向，没有继续扩大 P1 业务改动。

### 未做/非阻塞项
- [ ] 自动化环境无法替代 GM 在可见窗口里的最终鼠标手感确认；V4 已完成无界面主场景启动和退出烟测，但拖真实大模型、窗口显示、导入按钮及关闭后重开存档仍建议人工点一遍。
- [ ] V4 是未签名测试件，不是正式发行包；Windows SmartScreen（智能筛选）可能提示未知发布者。
- [ ] Token 运行态拖拽、LOS（视线遮挡）和墙体破坏按 `docs/design.md` 属于 P2，不作为 P1 缺陷继续拖延。

### 问题状态
| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-16 | 旧回归套件在非 `@tool` 脚本上可能得到占位实例，10/10 结果不可靠 | 已替换为 3 项编辑器契约测试 + 47 项真实运行测试 |
| 2026-07-16 | V3 导出包仍混入 `.claude.json`、测试/文档和大量编辑器工具 | 已由 V4 导出过滤关闭 |
| 2026-07-16 | 导出预设写死本机发布模板绝对路径 | 已清除，预设恢复可移植 |
| 2026-07-16 | 缓存源码对照一度扩大到非 P1 阻塞的内容摘要细节 | 已停止扩大范围；源码对照完成，未追加业务改动 |

## 2026-07-16 Codex 导入模型持久缓存完成

### 结论
- [x] 新导入 GLB 的首次拖出停顿已从拖动阶段移到导入阶段：导入时解析一次，打包为 Godot 原生 `PackedScene`，保存到 `user://library_cache/models/<category>/`；之后启动、拖动和放置均读取 `.scn` 缓存。
- [x] 缓存场景名带源文件 SHA-256 指纹前缀，元数据记录缓存版本、源路径、修改时间、大小和完整指纹；源文件变化、元数据损坏、缓存缺失或版本变化时不会复用旧缓存。
- [x] 主界面启动时只用 `ResourceLoader.load_threaded_request()` 后台预热已经存在的 `.scn`，不在启动阶段全量解析原始 GLB；旧版本已经导入但没有缓存的素材会在首次使用时迁移一次，此后跨启动复用。
- [x] 覆盖同名素材会切换到新的指纹缓存并清旧版本；删除素材会删除原始 GLB、`.scn` 和 `.cfg`；删除/覆盖前会先收束可能仍在进行的后台加载，避免 Windows 文件占用残留。

### 验证
- [x] `p1_regressions` 10/10 通过、0 失败、0 跳过；新增真实 GLB 链路用例含 17 个断言：现场生成最小 GLB、导入、保存/加载/实例化缓存、经主界面拖动入口实例化、破坏元数据触发重建、删除联动清理。
- [x] 主场景两轮启动均为 `helper_live=true`、`current_run_errors=[]`；停止后本次运行没有新增缓存/脚本错误或退出泄漏。
- [ ] 本轮没有重新导出 Windows EXE，也无法代替用户在桌面上手动拖真实大模型确认体感；自动测试验证的是同一套 `user://`、GLTF 解析、`PackedScene` 保存与拖动加载代码路径。
- [ ] 回归测试仍会触发一条既有的 `ModuleIo._restore_runtime_nodes()` owner 不一致警告，来源是旧存档运行期节点恢复测试，与模型缓存无关，本轮未扩大范围修改存档逻辑。

### 查证依据与取舍
- [x] 采用 Godot 源码 `editor/import/3d/resource_importer_scene.cpp::ResourceImporterScene::import()` 的“导入时 pack 并保存 `.scn`”思路，以及 `editor/scene/3d/node_3d_editor_viewport.cpp` 的“拖动时加载已导入资源并实例化预览”边界。
- [x] 采用 `editor/inspector/editor_resource_preview.cpp` 的“预览缓存与完整场景缓存分离”原则；没有把缩略图预热误当成完整模型预热。
- [x] API 依据：Godot 4.7 离线 `gdd_0929_GLTFDocument`、`gdd_1477_ResourceSaver`、`gdd_1476_ResourceLoader`、`gdd_1291_FileAccess`、`gdd_1239_ConfigFile`。未直接采用社区“给 GLTFDocument 套工作线程”的片段，因为场景节点生成的线程边界没有同等可靠保证；导入时同步转换、之后后台加载原生资源更可控。

## 2026-07-16 Codex 首次拖出优化方案与 Godot 源码对照

### 结论
- [x] 建议优化，但不采用“启动时同步/后台全量解析所有原始 GLB”。更合适的是把解析成本放到用户主动导入时：GLB 只解析一次，打包并持久化为 `user://` 下的 Godot 原生 `PackedScene` 缓存；后续拖动只加载/实例化缓存。
- [x] 这项是素材工作流的体验问题，不是 P1 正确性阻塞；约半秒已经超过可忽略的即时反馈范围，建议作为 P2 前段性能收尾处理。
- [ ] 本轮只完成方案核查，未修改功能代码；持久缓存命名、源文件修改时间/哈希失效、删除素材时清缓存、旧素材首次迁移和真实大模型耗时仍需实现与测试。

### Godot 源码依据
- [x] `editor/scene/3d/node_3d_editor_viewport.cpp`：`can_drop_data_fw()` 在首次进入 3D 视口时用 `ResourceLoader::load()` 读取资源并临时 `instantiate()` 做循环依赖检查，随后 `_create_preview_node()` 再实例化拖动预览；`drop_data_fw()` 最终通过 `_perform_drop_data()` / `_create_instance()` 放置实例。Godot 的拖动也依赖同步加载，但读取的是已导入资源并受全局资源缓存复用。
- [x] `editor/import/3d/resource_importer_scene.cpp`：`ResourceImporterScene::import()` 在导入阶段处理 3D 源文件；`PackedScene` 类型的保存扩展名为 `scn`，最终执行 `packer->pack(scene)` 并用 `ResourceSaver::save(... + ".scn")` 保存引擎原生场景。也就是说，Godot 把原始 GLB 的重活放在导入阶段，而不是每次首次拖动时。
- [x] `editor/inspector/editor_resource_preview.cpp`：`queue_resource_preview()` 使用独立队列和预览缓存，`start()` 可启动预览线程；这是缩略图缓存，不等于把可实例化的完整模型场景提前加载。

### 官方文档与社区对照
- [x] Godot 4.7 离线文档 `gdd_0184_Background_loading` / `gdd_1476_ResourceLoader`：标准加载会阻塞；已是 Godot 资源的场景可用 `load_threaded_request()` 后台加载并用 `CACHE_MODE_REUSE` 复用缓存。
- [x] Godot 4.7 离线文档 `gdd_0187_Runtime_file_loading_and_saving` / `gdd_0929_GLTFDocument`：外部 GLB 运行时仍需 `append_from_file()` 解析，再由 `generate_scene()` 生成节点树，正是当前首次拖动的主要工作。
- [x] 官方 Import process 文档：非原生资产会先自动导入，处理后的资源隐藏保存在 `.godot/imported/`；社区关于运行时 GLB 的案例也普遍指出 `await`（等待）本身不会把同步解析变成后台任务。未直接采用社区的简单工作线程片段，因为场景节点生成/挂树的线程边界仍需按 Godot 4.7 API 实测，不能把线程化当成无风险替换。

## 2026-07-16 Codex 导入模型首次拖出延迟核查

### 结论
- [x] 用户观察属实：导入的 GLB 第一次拖出时同步解析并生成场景，再打包进 `_model_scene_cache`；同一模型第二次拖出直接实例化缓存，所以明显更快。
- [x] 当前不是“没有缓存”，而是刻意采用“首次使用时建缓存”：`_warm_model_cache_for_path()` 会跳过 `source == "imported"`，避免软件启动或素材栏刷新时同步解析全部导入模型。
- [ ] 首次使用约半秒的停顿仍是性能待办；尚未决定后台逐个预热、交互前预热或占位预览方案，本轮未修改功能代码、未做性能优化。
- [x] 旧审计中“导入模型会在素材栏同步全量预热”的描述属于修复前快照；当前磁盘代码与本日志顶部后续记录均以“首次使用加载并缓存”为准。

## 2026-07-16 Codex P1 Windows EXE 收尾验收

### 结论
- [x] **P1 单 EXE 导出收尾完成，可以进入 P2。** 最终测试件为 `build/windows/p1_test_v3/Gvtt-P1-test-v3.exe`，110,237,832 bytes（105.13 MiB），SHA-256 `E38C27A62A4776D95289FEB179799F4DD25635C81C51C117E3B97B845A45DC4A`。
- [x] 新增 `export_presets.cfg` 的 Windows x86_64 单文件预设，使用 `embed_pck=true` 且不签名；Godot 4.7 导出命令退出码 0，导出日志无错误/警告，未生成额外运行 DLL。
- [x] 导出过滤排除 `gdUnit4`、`gdstyle`、测试/文档/参考目录、旧地面图、重复建筑贴图与本地个人素材；只保留 P1 定义的内置 `uv_checker_4096_v2`。EXE 从 573,379,000 bytes 降到 110,237,400 bytes。
- [x] 删除未被代码使用且序列化格式无效的 `input/ui_drag`，消除导出时的 `Attempted to load invalid input action` 警告。实际拖拽继续由 `InputEventMouseButton/InputEventMouseMotion` 直接处理。
- [x] 默认地面纹理改为确定 `res://` 路径，用 `ResourceLoader.exists/load` 走导出重映射，不再依赖 `DirAccess` 枚举原始 PNG。编辑器运行画面已直接确认 UV 色块和 `M13/N13/M14/N14` 标记实际显示；v3 EXE 日志明确加载原 PNG 路径及对应 `.ctex`，材质绑定保护未报错。烟测未超时、退出码 0、错误通道 0 bytes。
- [x] 烟测首次暴露 Gizmo `EditData` 继承 `Object` 但从未 `free()` 的真实退出泄漏；改为 `RefCounted` 后，3 个 ObjectDB 泄漏、1 个占用资源和 PagedAllocator 告警全部消失。回归测试扩为 9/9 通过、0 失败、0 跳过。

### 查证依据与取舍
- [x] Godot 4.7 引擎源码：`editor/export/editor_export_platform.cpp::_export_find_resources()` 证实 all-resources 会递归收集资源，`_edit_files_with_filter()` 证实排除器按逗号分隔通配规则删除；`core/object/ref_counted.cpp::unreference()` 与 `core/object/ref_counted.h::Ref::_unref()` 证实引用归零后自动销毁；`core/io/resource_loader.cpp::exists()` 会先调 `_path_remap()`，因此原 PNG 路径可在导出后解析到 CTEX。
- [x] 官方文档/离线文档：Godot 4.7 Exporting projects 的资源过滤模式；Godot 4.7 `DirAccess` 明确警告导出后原始资源不在 PCK 预期位置，项目资源应使用 `ResourceLoader`；`gdd_0196_Using_InputEvent`、`gdd_0304_GDScript_reference`、`gdd_0048_When_and_how_to_avoid_using_nodes_for_everything` 的 InputMap/Object/RefCounted 约束。
- [x] 社区方案：采用 gdUnit4 维护文档“导出时排除测试插件”与 Godot Forum “`Object` 未释放会在退出时报 leaked”的成熟做法。未改用 selected-scenes，因为默认地面贴图是字符串动态路径，依赖扫描可能漏包；未在本测试件剥离 `godot_ai` 运行探针，因其是当前运行态验证通道且已在无调试器时静默待机；正式发行版再做条件自动加载。

### 未做/待人工确认
- [x] P1 导出阻塞已修复：默认地面纹理改用确定资源路径与 `ResourceLoader` 重映射，并增加 `albedo_texture` 绑定失败报错。`ground_tile=0.0` 保持为铺满模式占位值。
- [ ] 自动化桌面会话不能把 GUI 窗口显示到用户交互桌面；已完成同一 EXE 的无界面加载/退出烟测，窗口视觉、鼠标拖拽、导入按钮与关闭后重开存档仍由用户手动验收。
- [ ] 这是未签名 P1 测试件，不是对外发行包；Windows SmartScreen（智能筛选）可能提示未知发布者。

## 2026-07-16 Codex P1 收尾修复完成

### 结论
- [x] **P1 代码收尾完成，项目可以进入 P2。** 本轮只关闭 P1 保存/加载、场景 UI、属性编辑、素材导入和网格阻塞项；Token 运行态拖拽、LOS、墙体破坏等仍属于 P2-P4，未混入完成范围。
- [x] 自动回归测试新增 `tests/test_p1_regressions.gd`，Godot AI `test_run` 最终 7/7 通过、0 失败、0 跳过。
- [x] 主场景最终启动 `helper_live=true`、`current_run_errors=[]`；连续停止/重启后，场景1仍为 1 个模型、1 个 PickProxy、1 个 PickProxyArea，没有重复增长；游戏日志无脚本错误和内置贴图导出警告。

### 已完成修复
- [x] 场景存盘从只读的 `res://modules/...` 迁到 `user://modules/...`；首次启动只复制目标不存在的旧 `.scn`，不删除、不覆盖仓库原件或已有用户存档；启动扫描磁盘重建清单，新场景编号同时避开内存和磁盘重名。
- [x] 开机直接加载扫描到的首场景，不再出现“场景名是场景1、舞台实际为空”的假状态；运行日志证实读回场景1纹理、100×100 尺寸和已放置模型。
- [x] 场景列表动态按钮改用 `gvtt_scene_button` 元数据清理，不再依赖 `get_child(2)` 魔法索引；运行态场景栏为 4 个固定控件+2 个场景按钮，宽/高 SpinBox 均保留。
- [x] 存档前临时摘下 `gvtt_runtime_only` 节点、打包后原位挂回；PickProxy 加载旧存档时先清旧 Area3D/标记再重建。真实存→读测试证明运行期节点不进 PackedScene，旧重复拾取区只剩一套。
- [x] 场景切换搬节点前递归清旧 owner，再挂入当前 ContentRoot 并重建 owner，消除 owner 不一致警告。
- [x] 属性名称、可见、透光、可破坏、掩体、生命值回调全部置脏；连接 Gizmo3D `transform_end`，移动/旋转/缩放后会触发未保存提示；面板回填期间用 `_updating_prop_panel` 防止误置脏。
- [x] 删除“内容层必须有子节点才保存”的限制；空场景只改纹理、尺寸或平铺时也会保存。
- [x] `res://` 内置贴图改用 `ResourceLoader.load(Texture2D)`；`Image.load_from_file()` 只保留给外部 `user://` 图片。三次运行日志均不再出现 Godot `core/io/image.cpp` 的导出警告。
- [x] P1 模型入口只公开自包含 `.glb`；不再承诺只复制主文件就能可靠工作的 `.gltf/.fbx`。导入模型不在 UI 重建时同步全量解析，改为第一次预览/放置时加载并缓存。
- [x] 模型准备和 `PostImportCenter` 都只调整场景根节点，保留模型内部合法位移/旋转/缩放；后导入包围盒遍历修正为每层变换只乘一次。
- [x] 长方形网格 X/Z 次线与主线循环均改用对应轴步数；20×100 回归用例验证顶点数 168。
- [x] 清理 P1 涉及文件中的 owner/name/tr 遮蔽、未使用参数和 String/StringName 三元类型警告；本轮改动仍遵守显式类型且无 `:=`。

### 查证依据与取舍
- [x] Godot 引擎源码：`scene/resources/packed_scene.cpp::SceneState::_parse_node()` 的 owner 过滤用于确定持久/运行期节点边界；`editor/scene/3d/node_3d_editor_plugin.cpp::_init_grid()` 用于核对网格轴向步数；`scene/main/node.cpp` 与 `core/io/image.cpp` 用于核对节点所有权和导出图片告警行为。
- [x] 官方文档/演示：`gdd_0185_File_paths_in_Godot_projects` 与 `gdd_0372_File_system` 的 `user://` 可写约束；`gdd_1006_PackedScene`、`gdd_1476_ResourceLoader`、`gdd_1477_ResourceSaver`；`gdd_0947_Image` 的运行时图片限制；`godot-demo-projects/loading/serialization` 的运行时序列化结构。
- [x] 社区方案只采用“用户存档放 `user://`”这一成熟共识；未采用无版本迁移的简单 SaveManager/Gist 写法。`.gltf` 未自写半套依赖复制器，P1 选择只公开 `.glb`；未保留递归清模型子变换的旧策略。

### 问题状态
| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-16 | P1 场景写入 res://、磁盘编号碰撞、开机不加载真场景 | ✅ 已修复并运行验证 |
| 2026-07-16 | 场景列表误删固定控件并重复按钮 | ✅ 已修复，自动测试+运行树验证 |
| 2026-07-16 | PickProxy 运行期节点写入存档并在读回后翻倍 | ✅ 已修复，存读测试+重启验证 |
| 2026-07-16 | 属性/Gizmo 不置脏、空场景切换前不保存 | ✅ 已修复 |
| 2026-07-16 | 内置贴图导出警告、gltf 依赖丢失、模型预热卡 UI | ✅ 已修复/收紧入口 |
| 2026-07-16 | 递归清模型子变换、长方形网格轴步数交叉 | ✅ 已修复并自动测试 |

### 本轮未做
- [x] 真实单 EXE 导出包烟测已于 2026-07-16 补完；见本文顶部“P1 Windows EXE 收尾验收”。
- [ ] 未把大型 GLB 解析搬到工作线程：`GLTFDocument` 首次放置仍是同步解析，只是已从“启动全量卡顿”降为“首次使用单个素材时加载”；这是后续性能压力测试项。
- [x] 没有删除或覆盖仓库现有 `modules/*.scn`，也没有回退工作区里用户已有的大量权限位/内容改动。

## 2026-07-16 Codex P1 全盘收尾审计

### 结论
- [ ] **P1 暂不能判定收尾。** 本轮只按 `docs/design.md` 的五项 P1 验收，不把 Token 运行态拖拽、LOS、墙体破坏等 P2 功能算作缺陷；但 P1 自身仍有保存、场景列表、地面贴图、脏状态和运行期节点序列化阻塞项。
- [x] 编辑/运行切换通过运行态验证：主场景启动后 `helper_live=true`，切到运行态时素材面板隐藏、状态文字变为“运行态”，没有新增红色错误。
- [x] 15 个项目脚本均能被 Godot 4.7 解析并列出符号；主场景可以启动。
- [ ] 自动回归测试缺失：`test_run` 返回 `res://tests/` 不存在，项目虽带 gdUnit4，但没有项目测试用例。

### P1 阻塞项
- [ ] **导出后无法保存场景。** `scripts/module_gate.gd::_module_dir()` 把运行时场景写到 `res://modules/...`；Godot 4.7 离线文档 `gdd_0372_File_system.md` 第 63/69 行说明导出后 `res://` 只读、`user://` 始终可写。此项直接违反 `docs/design.md` 第 130 行“GM 搭完必须能存”和单 exe 目标。
- [ ] **“新建场景”会读入同名旧文件。** `ModuleGate` 每次启动重建内存清单并从“场景1”编号，但 `main.gd::_switch_to_scene()` 又按同名 `res://modules/.../_canonical/场景N.scn` 读取旧文件。本轮点一次“新建”后，场景2实际出现上次遗留的 3 栋建筑，证明注释“不会撞名”与真实行为相反。
- [ ] **场景列表刷新会破坏 UI。** `main.gd::_sync_scene_list()` 注释要求保留前 4 个固定控件，代码却循环删除 `get_child(2)`。运行实测：点一次“新建”后宽/高输入栏和分隔线消失，场景1/场景2各重复两次。
- [ ] **存读会累加拾取区域。** `ModuleIo._ensure_ownership()` 把 `PickProxy._ready()` 动态创建的 `Area3D/CollisionShape3D` 也设为可保存；读回时 `_ready()` 再创建一套。本轮读回的 3 个建筑每个都已有 2 个拾取 `Area3D`，反复存读会继续膨胀。Godot 源码 `scene/resources/packed_scene.cpp::SceneState::_parse_node()` 会过滤非目标 owner 节点；离线文档 `gdd_1006_PackedScene.md` 第 31-45/135-137 行也明确按 owner 决定保存范围。
- [ ] **多类编辑不会触发未保存提示。** 属性面板的名称/可见/透光/可破坏/掩体/生命回调均未写 `_scene_dirty=true`；Gizmo3D 已提供 `transform_end` 信号，但 `main.gd` 未连接，所以移动/旋转/缩放也不置脏。直接切场景会无提示丢改动。
- [ ] **空场景的“保存后切换”会跳过保存。** `_on_switch_dialog_save()` 只有 `_content_root.get_child_count() > 0` 才保存；只改地面纹理、平铺或场景尺寸而没有物件时，会直接切走并丢失这些场景属性。
- [ ] **默认地面贴图不兼容导出。** `main.gd` 对 `res://` 内置贴图使用 `Image.load_from_file()`；本轮启动由 Godot `core/io/image.cpp` 连续报出“导出后不可用”警告。离线 `gdd_0947_Image.md` 第 774 行也限定该方法主要用于编辑器或 `user://` 外部图片。

### 其他高风险与清理项
- [ ] `_reset_all_transforms()` 对导入模型整棵树递归清 position/rotation/scale，会破坏合法的多节点层级变换；`post_import_center.gd` 也有同类过度归零策略。Node3D 离线文档 `gdd_0673_Node3D.md` 第 13/154 行说明子节点变换处于父空间，不能普遍当作脏数据清零。
- [ ] `.gltf` 导入只复制被选中的单个文件，未复制外置 `.bin` 和贴图依赖；UI 却公开允许 `.gltf`，非自包含模型可能导入后加载失败。当前推荐 `.glb` 不足以消除这个承诺缺口。
- [ ] 导入模型的缓存预热在 `_warm_model_cache_for_path()` 中同步解析并打包每个模型；素材库大时会在建 UI/刷新栏位时卡主线程，现无大库压力测试。
- [ ] `grid_manager.gd` 长方形网格把 X/Z 方向的步数变量交叉使用；正方形看不出，宽高差大时一侧网格线覆盖不全。
- [ ] 编辑器当前还有 10 条 GDScript 警告（遮蔽、未使用参数、三元类型不兼容）及切场景时 owner 不一致警告；无红色解析错误不等于已清零告警。
- [ ] Git 工作区显示约 786 个变更，其中绝大多数是 `100755 -> 100644` 文件权限位变化，`core.filemode=true`；实际内容变更集中在 `main.gd`、`entity_properties.gd`、开发日志、着色器和场景文件。功能不因此失效，但会污染后续提交和代码审查，本轮未改 Git 索引。

### 本轮未做
- [x] 未修改业务代码、第三方插件或现有 `.scn` 文件；运行态只做启动、模式切换、新建场景和节点检查，随后已停止项目。
- [x] 未把 P2-P4 缺失项混入 P1 结论。
- [x] Godot 源码核查来源：`godotengine/godot` 的 `scene/main/node.cpp`、`scene/resources/packed_scene.cpp`、`core/io/image.cpp`；采用其 owner/打包过滤和导出资源约束作为审计依据。本轮没有实现修复，因此没有采用社区近似方案。

## 2026-07-16 Codex P1 remainder + external assets

### Done
- [x] P1 status rechecked against `docs/design.md`, `devlog/DEVLOG.md`, `project.godot`, `scenes/main.tscn`, and `scripts/main.gd`: P1 has no hard blocker left. Remaining items are cleanup/future-phase work, not P1 blockers.
- [x] Asset policy tightened in runtime scanning and Git handoff: only `assets/textures/ground/uv_checker_4096_v2/` is the built-in default ground asset. Older/local sample assets are external assets.
- [x] `scripts/main.gd` model panels no longer scan `res://assets/...` as built-in model libraries; model assets now come from the external import library (`user://library/<category>/`).
- [x] `scripts/main.gd` ground built-ins now scan only `DEFAULT_GROUND_TEX_BASE` (`uv_checker_4096_v2`), so old local ground folders are not shown as built-in ground choices.
- [x] `.gitignore` now ignores `assets/textures/ground/uv_checker_4096/` in addition to `assets/models/`, `assets/textures/buildings/`, `stone_floor/`, and old `uv_checker/`.
- [x] `docs/CODEX_HANDOFF.md` updated so future Claude Code handoff recognizes `uv_checker_4096/` as an external ground texture.

### P1 non-blocking leftovers
- [ ] User hand-feel checks remain useful, but drag/drop has passed runtime verification and is not blocking P1.
- [x] `Image.load_from_file` 导出警告已在 P1 收尾中修复：内置图走 ResourceLoader，外部图才走 Image。
- [ ] `gdstyle` command-line executable is still missing; lint remains tool-blocked, not P1-blocking.
- [ ] Runtime token drag, LOS, destructible walls, VFX, atmosphere, and layer switching belong to P2-P4.

### Notes
- [x] No local asset files were deleted. This change means old/local assets are not scanned as built-in software assets and are not pushed as built-in project assets.

# Gvtt 开发日志

> 实时更新。每次会话结束前由 Claude 更新。

---

## 当前状态

- **当前优先级：** 迁移到 Codex 准备。项目推上 GitHub 完成（代码+docs+addons 已推，assets 仅有默认 UV 贴图进仓库）。交接文档 `docs/CODEX_HANDOFF.md` 已准备。
- **本轮（2026-07-15 迁移准备）**：把项目从 Claude Code 迁移到 Codex。做了两件事：①推 GitHub——核心代码+docs+addons 全推了，assets 仅默认 UV 贴图进仓库（其余外部导入素材不推），最后一个 commit `4899f70`（默认UV贴图 + 资产目录骨架）因网络断连未推成功，下次网络好时 `git push origin master` 即可；②Codex 交接文档 `docs/CODEX_HANDOFF.md` + MCP 配置 `.codex/settings.json`。交接文档包括：项目进度/架构/关键技术栈/Git 状态/地雷清单/给新 AI 的建议。
- **本轮（2026-07-14 网格重构）**：网格系统从旧 PlaneMesh+fragment shader 替换为 Godot 几何体路线（SurfaceTool 生成网格线几何体 + 顶点颜色 fade）。 移植自 Godot 引擎 node_3d_editor_plugin.cpp 的 _init_grid()。 新增 scripts/grid_manager.gd + shaders/grid_line.gdshader， 改 main.gd（_draw_grid → _init_grid_manager+_refresh_grid，滚轮/切模式触发刷新）。 MAP 正交/ORBIT 透视都支持。⚠待你手动确认视觉效果。
- **复盘教训写入 CLAUDE.md**：①搜索现成方案必须三层（引擎源码→官方文档→社区），涉编辑器行为时引擎源码是权威；②用户说"去看某来源"是停止符和转向指令；③疑问句不一定在提问。
- **当前任务：** 素材库运行时导入系统（用户需求"给每个栏位加导入按钮存进素材库反复用"）。**第一轮**跑通装饰栏位验证整条链路（见下）。**第二轮（本轮）扩到全部 7 栏位**：用户手动测装饰通了后拍板"全部都做了"。**用户两条设计决定**：①模型只支持内置贴图（GLB 嵌入式），FBX 外部贴图路径不管——已存 memory gvtt_model_embedded_textures_only；②地面纹理按文件夹导入（PBR 多图一组），接口留好支持多图，复用自带 _classify_texture 文件名分类——已存 memory gvtt_ground_texture_folder_import。**实现（抽通用逻辑避免代码复制六遍）**：main.gd 加 MODEL_PANELS 常量配置 6 个模型栏位（token/terrain/wall/decor/interactable/light，各带 label/category/builtin_dir）、_model_panels 字典存各栏位运行时状态（items/active_idx/container/import_btn）。通用函数：_build_model_section 循环建栏位、_rebuild_model_items 合并自带+导入、_rebuild_model_buttons/_btn_model 刷新按钮、_on_model_clicked 选中（跨栏位单选，_clear_all_model_selections）、_get_active_model_item 查当前选中、_place_model 按来源分流加载（builtin=ResourceLoader.load(PackedScene)，imported=load_model_runtime）、_on_model_import_pressed/_show_import_dialog/_on_import_file_selected 导入文件。地面纹理独立：_build_ground_section 建栏、_on_ground_import_pressed/_show_import_dir_dialog/_on_import_dir_selected 导入文件夹（FILE_MODE_OPEN_DIR + dir_selected 信号）、_rebuild_ground_buttons 合并自带 _ground_sets + LibraryManager.scan_ground_textures。LibraryManager 加 import_texture_folder（复制整个文件夹）+ scan_ground_textures + _scan_one_ground_folder + _classify_one_texture（跟 main.gd _classify_texture 同规则）。删旧 _decor_items/_decor_list_container/_active_decor_idx/_decor_import_btn/_building_list/_scan_models/_rebuild_decor_items/_rebuild_decor_buttons/_btn_decor/_on_decor_clicked/_on_decor_import_pressed/_place_decor 全部死代码。栏位顺序保持原左栏：场景→Token→地形→地面纹理→墙体→装饰→交互物体→光源（地面纹理插在 terrain/wall 间，循环里判 category=="wall" 时插建）。**game_eval 全验证通过**：①_model_panels 6 栏位全建（cats=[token,terrain,wall,decor,interactable,light]）；②各栏位 items+导入按钮都在（decor=5items=4自带FBX+1用户真导的"网行者test.glb"，其余0items对应 res 空目录）；③地面纹理 ground_sets=2自带+0导入、导入按钮在；④import_texture_folder 复制 stone_floor 文件夹成功、scan_ground_textures 扫到；⑤用户真导的 GLB load_model_runtime 加载返回 Node3D kids=1 无贴图报错（坐实 GLB 稳）。测试导入的 stone_floor 已清理。⚠未验：真人点 7 个导入按钮+选文件/文件夹（game_eval 不能真点 UI），待你手动实操认体感。⚠小瑕疵：导入纹理文件夹名跟自带重了会显示两个同名按钮（如 stone_floor），属使用习惯，导入时换不同文件夹名即可，不堵。下一步：你手动跑游戏测 7 栏位导入体感
- **Git 状态：** 有未提交改动（上一轮全部 + 本轮 main.gd 大改：MODEL_PANELS 常量+_model_panels 字典+_build_model_section/_build_ground_section 循环建栏+通用模型栏位函数族+地面纹理文件夹导入函数族+删旧装饰专用死代码；library_manager.gd 加 import_texture_folder/scan_ground_textures/_scan_one_ground_folder/_classify_one_texture；docs/memory 改）

---

## 开发环境

| 组件 | 状态 | 备注 |
|------|------|------|
| Godot 4.7-stable | ✅ | |
| Godot AI MCP v2.9.1 | ✅ | batch_execute 一次确认 |
| godot-skill | ✅ | GDScript 规范 |
| godot45-gdscript | ✅ | 1050+ 类 API 参考（4.5 版） |
| GodotPrompter | ✅ | 54 技能（2026-07-07） |
| gdstyle v0.1.7 CLI | ✅ | 54 规则 |
| gdstyle 编辑器插件 | ✅ | 编辑器内实时诊断 |
| GdUnit4 v6.x | ✅ | 测试框架 |
| Godot 4.7 离线文档 | ✅ | 1593 文件，15MB（reference/） |
| Gizmo3D v1.0.0 | ✅ | Godot 4.7 零报错加载。集成完成：放置建筑自动绑定 gizmo 手柄（移动/旋转/缩放）。接口：Gizmo3D.select(target)/deselect(target)/clear_selection() |

---

## P1 启动前检查（全部完成）

- [x] .editorconfig（utf-8, LF, GDScript tab, Markdown space）
- [x] .gitignore（*.uid, sandbox/, export_presets.cfg）
- [x] 项目骨架（entities/walls/ terrain/ tokens/, maps/, ui/, sandbox/）
- [x] 命名规范写入 CLAUDE.md
- [x] 拖拽输入由 `InputEventMouseButton/InputEventMouseMotion` 直接处理；无效且未使用的 Input Map `ui_drag` 已于 2026-07-16 清理。
- [x] 文件结构（已创建功能分组骨架）
- [ ] gdstyle lint（不阻塞 P1）
- [x] 冒烟测试（2026-07-16：7/7 自动测试 + 三次主场景启动/重启）

---

## 功能进度

### P0（✅ 2026-07-04）
- [x] 正交相机 + 倾斜视角 + 缩放/平移
- [x] 网格地面 + 光源 + 阴影 + 天空照明
- [x] main.tscn + main.gd

### P1（✅ 2026-07-16 收尾完成）
- [x] 编辑↔运行切换（2026-07-07）
- [x] 地面纹理替换（已完成 2026-07-07）
- [x] 地面纹理管理改子文件夹结构（2026-07-08）：每个纹理一个子文件夹，文件夹名=纹理名。单文件→当整张贴图；多文件→分类 albedo/normal/roughness 等
- [x] 地面纹理平铺控制 UI（2026-07-08）：标签+数字输入框+滑条上下两行布局，默认 2.0 格。用 StyleBoxFlat 给滑条轨道和滑块做大圆点样式
- [x] ModeGate 权限闸（2026-07-08）：新增 autoload `scripts/mode_gate.gd` 持有编辑/运行唯一真值；main.gd 的 `_on_mode_changed` 拆成 `_apply_topbar/_apply_panel/_apply_camera/_apply_gizmo` 四个分派，确立"功能自报归属"规矩
- [x] Gizmo3D 运行态禁用手柄修复（2026-07-08）：根因是 gizmo3D `_process` 每帧重置 visible，单纯 visible=false 无效；改用 clear_selection + set_process(false) + visible=false 三连；用 `_building_to_gizmo` 泛型字典管理绑定，切回编辑态用 `_gizmo_selections_snapshot` 恢复选中（实现策略 B「玩完留下」的 gizmo 部分）
- [x] 运行态自由视角相机（2026-07-09）：mode_gate.gd 加 `EditSubMode {MAP,ORBIT}` 子模式 + `edit_sub_mode_changed` 信号；main.gd 删 `camera_angle/height/size` 改球坐标四量(yaw/pitch/dist/focus) + saved 四量(游玩视角权威) + `_map_size/_map_focus`(地图模式)。相机投影按子模式切正交/透视。输入:右键拖改 yaw/pitch、滚轮按子模式改 size/dist、中键拖按子模式平移 map_focus 或用相机 basis 投影平移 orbit_focus。删了 `_physics_process` 速度轮询(Input 文档说每 0.1s 才更新会卡顿)。顶栏加三按钮:子模式切换(两态)/保存视角(只编辑态)/恢复视角(只运行态)。依据:three.js OrbitControls 数学模型(见 LucaJunge/godot_orbit_controls,GPL 不兼容本仓 MIT 故只参考思路自实现)。API 经离线文档 4.7 核对:ProjectionType 枚举、event.relative、Input.is_mouse_button_pressed、look_at 每帧重调、pitch 须 clamp。**已 game_eval 实证验证**:开机地图模式(proj=1 正交,pos=(0,25,0)正上方)正确;切自由视角(proj=0 透视,pos=球坐标算出值)正确;改 yaw/pitch/dist/focus 后相机到焦点距离=设的 dist,look_at 对焦正确
- [x] 物件系统（选中、属性面板、素材栏拖放与放置已完成；见 2026-07-16 P1 收口验收）
- [x] 物件属性标记（schema、EntityProperties、属性面板、可见层与脏标记已接通）
- [x] 资产栏位结构定稿 + 可折叠（2026-07-09）：main.gd `_build_ui` 左栏顺序定为「场景(0)/Token(0)/地形(0)/地面纹理/墙体(0)/装饰(N)/交互物体(0)/光源(0)」。建筑栏并入装饰（4 个旧 FBX 暂留 `_building_list`，将来扫 `assets/props/` 往里加）。`_add_section` 改可折叠——返回一个 VBoxContainer 内容容器，标题做成 flat Button，点一下切内容容器 visible、标题前 ▼/▶ 标展开/收起态；原平铺挂总 vbox 的地面纹理控件/建筑按钮改挂到各 section 返回容器。API 全经离线文档 4.7 核对：Button.alignment/flat（gdd_0538 第 50/55 行）、CanvasItem.visible（gdd_0542 第 407 行，Control 第 15 行明说继承）、Button.pressed 信号、GDScript lambda 闭包。**本会话 godot-ai MCP 未连，未跑 game_eval 验证，仅逻辑自查无报错——待重连后或用户手动跑游戏确认折叠交互**
- [x] 场景保存/加载（2026-07-16 收尾：user:// 持久化、旧数据迁移、存读隔离、空场景保存、开机真加载、重启验证均通过）

### P2-P4
- [x] P2.0 对象类型系统 + schema 收口
- [x] P2.1 运行态选择 + GM 只读操作面板基础版
- [x] P2.2 CPR Token 移动基础版：MOVE 预算、路线预览、绕障、超距截停、体型导航、运行/编辑位置隔离
- [ ] P2.3 光源开关
- [x] P2.4 CombatBody（战斗碰撞体）+ 挡枪线接口基础版
- [x] P2.5 LOS 视线遮挡基础版
- [x] P2.6 墙体破坏最小闭环：破坏/修复、LOS/挡枪线同步、保存读回已完成；碎裂视觉与移动导航重建后置
- [ ] 特效触发
- [ ] 场景气氛
- [ ] 色块布局工具
- [x] 多场景基础管理：场景列表、新建、切换、保存/读回、未保存提醒和 `SceneSessionController` 会话收口已接入；带团存档、叙事进度和地点层级增强后置
- [ ] 层级切换
- [x] 投屏窗口基础版：独立原生窗口共享 `World3D`，GM 控件不进投屏；投屏画质/玩家可见层增强后置

---

## 问题记录

| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-09 | **资源库框架搭建。** 用户确认物种类清单，在 assets/ 下新增 8 个子目录占位：walls(可破坏墙体)、terrain(地形)、props(装饰)、lights(光源物件)、interactables(可交互物件,火药桶/配电箱等主动触发型,用户拍板单列)、tokens(Token)、vfx(P3 特效预留)、environment(P3 气氛预留)。每目录写 README.md 说明放什么/格式/对应design.md哪条 + .gitkeep。依据 design.md 第77行物件种类(墙体/地形/装饰/光源/Token)+ 第78行属性标记(可交互是属性标签,用户决定在资源库层单列 interactables 而非贴标签,两者并存不冲突)。保留旧两模块 models/(4FBX建筑) + textures/ground/(地面纹理,main.gd扫描中)。发现 textures/buildings/ 与 models/textures/ 疑似同一批贴图存两份,本次未动待物件系统落地合并。根目录空骨架(entities/maps/objects/resources/ui/sandbox/gvtt/)未动待用户决定。architecture.md 文件结构图已更新(补漏写的 buildings + 新增8模块 + 空骨架标注) | ✅ |
| 2026-07-09 | architecture.md 文件结构图与磁盘不符：漏写 assets/textures/buildings/；未记空骨架目录。已更新补全 | ✅ |
| 2026-07-08 | Gizmo3D `_draw()` 三角化失败（gizmo3D.gd:338）——三点退化跳过不画已修 | ✅ 已修(加面积保护跳过退化三角形) |
| 2026-07-08 | `_building_to_gizmo` 字典只增不 erase，将来删建筑必须同步 erase 否则坏账 | 📌 潜伏债，已在代码注释提醒 |
| 2026-07-08 | `*.bak` 备份被 Git 跟踪——已加 .gitignore 并删 main.gd.bak | ✅ 已清 |
| 2026-07-08 | ModeGate 改造 + gizmo 运行态禁用 + 地面纹理结构改造 + 平铺 UI | ✅ |
| 2026-07-09 | **投屏窗口（玩家视角第三块）落地。** 架构定调：投屏窗口旁路于 ModeGate，是运行态的输出层，不是第三个 AppMode。新增 `scripts/cast_view.gd`：独立原生 `Window` + 只读 `Camera3D`，显式 `cast_window.world_3d = main_vp.world_3d` 共享同一 World3D 资源对象实现同步。main.gd 加顶栏"投屏⧉"按钮接 `_cast_view.open(self)/close()`，旁路 mode_changed 不订阅。每帧 `_sync_cast_camera` 把投屏相机姿态镜到主相机。API 全经离线文档 4.7 核对（Window/Viewport/Camera3D 三个类）。**game_eval 双轮实证**:open 后 is_open=true、cast_window_world3d_is_main=true（两窗口共享同一世界）、cast_cam_current + main_cam_current 都 true（两窗各一 active 相机不抢）。**踩坑:** 要让投屏窗变独立 OS 窗口（能拖第二屏/被腾讯会议单独共享），`Window.force_native` 实测在 `embed_subwindows=true`（项目默认）下被引擎强制保持 false、走不通；最终改全局 `display/window/subwindows/embed_subwindows=false` 解决，实测改后 is_embedded=false、cast_window_id=1≠main_window_id=0。代价：所有 Window 派生类（含将来对话框）都变独立 OS 窗，对 GM 桌面工具反而合适。design.md 三、3.1/3.2 与 architecture.md 3.6 已更新 | ✅ 已验证 |
| 2026-07-09 | 投屏 bug：GM 在地图（正交）模式缩放后，投屏窗看到的范围跟主窗不一致。根因 `_sync_cast_camera` 只复制了 position/rotation/projection/fov/near/far，漏了正交相机专属的 `size`（正交视野范围）。GM 滚轮改 `_map_size→main.camera.size`，投屏相机 size 一直停在默认 1。修：正交模式下加 `_cast_camera.size = _main_camera.size`。game_eval 实证修后 main_size=25 == cast_size=25 | ✅ 已修 |
| 2026-07-09 | **降画质预案留框架（默认关闭）。** 担心 GM 机双窗口双倍 GPU 绘制卡。cast_view.gd 加 `_low_quality` 开关 + `set_low_quality(bool)` + `_apply_low_quality()`。开时关投屏窗的 `positional_shadow_atlas_size=0`(实时阴影)、msaa/use_taa 关、`mesh_lod_threshold=2.0` 粗 LOD；GM 主窗不受影响。API 全经 gdd_0774 核对（第 809/835/955/1104/231-242 行）。**但有实测要求**：原生 Window 节点上调这些 Viewport 属性是否真生效无文档明示（类比 force_native 坑），日后拨开关跑游戏验证阴影确实掉才算坐实；不生效则退回 SubViewport 方案（gdd_0296 第 173-185 行）。当前默认 false 不影响体验。ARCHITECTURE.md 3.6 + cast_view.gd 已记 | 📌 留框架待实测 |
| 2026-07-09 | 运行态自由视角相机改造（mode_gate.gd 加子模式 + main.gd 球坐标相机 + 三按钮） | 🔄 代码已写入、编辑器无报错加载，等重连 godot-ai MCP 后跑游戏验证 |
| 2026-07-09 | 编辑器 GDScript 脏缓存：逐块 script_patch 改 main.gd 时，编辑器报"Cannot call non-static is_edit() on ModeGate"等错，行号与磁盘代码对不上。根因是 GDScript 脚本缓存层脏，非代码错。重启 Godot 后缓存清、干净运行(recent_errors 全空、helper live) | ✅ 重启 Godot 解决 |
| 2026-07-09 | godot-ai MCP 在本会话未加载（工具列表无 `mcp__godot-ai__*`），无法直接跑游戏验证。需重连 MCP 或新开会话 | ⏳ 待重连 |
| 2026-07-09 | **教训：不准用断链手段"冲"编辑器缓存报错。** 上一会话误用 editor_reload_plugin 想清脏缓存报错，结果报错没清(根因在脚本缓存)、MCP 连接反断、用户被迫重启 Godot。已写入 CLAUDE.md 禁断链规矩 | 📌 已立规矩 |
| 2026-07-09 | 保存视角 bug：保存视角按了但切运行态用的是编辑态当前视角。根因是 `_sync_orbit_to_saved_if_fresh()` 有 `_orbit_inited` 守门，首次切自由视角后就再不从 saved 套用，导致切运行态直接继承编辑态临场转动。修复：删 `_orbit_inited` 守门和 `_sync_to_saved_if_fresh`，改成每次切进自由视角都从 `_saved_orbit_*` 套用。GM 临场转动保护靠"运行态只改 _orbit_* 不动 saved"自然实现。已 game_eval 双闭环验证：保存→切运行态用 saved；恢复视角→回 saved | ✅ 已修 |
| 2026-07-09 | **物件属性标记 schema 落地。** 新增 gvtt_render_layers.gd / entity_properties.gd / pick_proxy.gd 三个 class_name 脚本。改 main.gd 加选中+属性面板，cast_view.gd 投屏相机接 cull_mask=CULL_MASK_PLAYER。schema 决策：①token 与战术物件两个独立 schema 不凑共通层(交集只名字)；②起源——penetrable 枚举原想加，经用户反问"什么叫 GM 脑子里记能不能穿"推翻——可穿透性是物件类型+破坏后状态的物理事实(玻璃型不进LOS、墙进),不是 GM 手标属性,据 design.md 第81-82行 LOS 定义最好自动算,故删字段；③cover_level 按赛博红掩体三定律只用 NONE/FULL 两值(用户引原话"没有部分掩体一说")；④可见层 visibility BOTH/GM_ONLY 接投屏 cull_mask，GM-only 物件投屏那头不渲染。选中方案据 godot-ai subagent 搜证：CollisionObject3D._input_event 要 collision_layer 有位(gdd_0554)，无实体光源靠 PickProxy 代理(Area3D+BoxShape3D 拾取层 monitoring=false) | 🔄 骨架落地 |
| 2026-07-09 | 编辑器脏缓存（同前几次）：scan 后 global_classes_registered_delta=0、main.gd 报"EntityProperties not found"一堆，但 find_symbols 能解析各新脚本、game_eval 里 EntityProperties.new()/GvttRenderLayers.CULL_MASK_PLAYER==524287/PickProxy Area3D collision_layer=524288 全通——确认编辑器报错纯脏缓存、游戏实跑脚本正常。按 CLAUDE.md 规矩承认"编辑器报错、游戏实跑正常"不重启 | ✅ 实证确认 |
| 2026-07-09 | godot-ai `filesystem_manage write_text` 把 gvtt_render_layers.gd 写坏(末尾追加一堆 NUL 字节，报"class_name can only be used once"假错)。改用 Write 工具重写解决。教训：写 GDScript 文件优先 Write 工具，godot-ai write_text 偶发写坏 | ✅ 已修 |
| 2026-07-09 | **选中点不到物件**（用户报"点了没反应"）+ **投屏编辑态还看见 gizmo 手柄**。两个真 bug/game_eval 实证定位：①PickProxy Area3D 我设了 monitoring=false 想省算力，实测 intersect_ray **不检测 monitoring=false 的 Area3D**(射线命中空)。印象"monitoring 只控信号不影响射线"是错的。改 monitoring=true，靠 collision_mask=0 兜底不被触。②gizmo 是场景 3D 节点属共享 World3D 投屏看得见，改 Gizmo3D.layers=1<<19 放 GM-only 渲染层，投屏 cull_mask 关第20层看不到手柄。game_eval 实证监测改后射线命中 PickProxyArea@pos(0,0.3,0)、_select_entity 流程面板可见+title="选中:物件甲"+各字段读回全对 | ✅ 已修 |
| 2026-07-09 | **属性面板改 CheckBox + 顺序 + 加可透光字段 + 默认值调**（用户拍板）。①"可当掩体"OptionButton→CheckBox(勾上=FULL/勾掉=NONE)；②"可见层"→"玩家可见"CheckBox(勾上=BOTH/勾掉=GM_ONLY)；③顺序改 名字→玩家可见→可透光→可破坏→可当掩体→最大生命(血量放最下)。④新增 `los_occluder` 字段(GM 手标挡视线,面板表"可透光"勾上=透光=不挡、勾掉=不透光=挡)。**战争迷雾接口**:entity_properties.gd 加 `signal los_occluder_changed(target, occluder)`+`set_los_occluder(root,bool)` 统一入口,将来 LOS/迷雾系统 connect 它重算、破坏系统砸毁物件调它设 false。⑤默认值调:max_hp 10→20、cover_level NONE→FULL、visibility BOTH、destructible false、los_occluder true(物件默认不透光)。**判定更正(推翻旧记录)**:旧草稿曾定性"是不是玻璃是物理事实不进 schema",2026-07-09 GM 反问点破"引擎无法从 mesh 分辨透不透光,只能 GM 手标"——正式推翻,los_occluder 进 schema。**game_eval 全实证**:面板顺序正确、6 字段默认值全对(20/fa­lse/FULL/BOTH/true)、勾选状态读回正确。schema 草稿 2.0 段+字段表更新,2.3 玻璃预留位删 | ✅ 已实证 |
| 2026-07-09 | **黄圈真因+修**：放房后物件脚下飘黄圈,根因=PickProxy 可视标记球(show_marker)原一概建且被同步缩成大球(从上俯看似圆圈趴脚底)。修:pick_proxy.gd 加 `@export var show_marker: bool = false`,_ready 里仅 show_marker=true 时建标记球。实体物件(墙/房有 mesh 自带外观)默认 false→不建、脚下干净;无实体物件(将来的光源/机关)显式设 true,GM 才有"这里有的点"视觉提示。game_eval 实证放房后 show_marker=false、无 PickProxyMarker 子节点 | ✅ 已实证 |
| 2026-07-09 | **【根因二+闭环】选中点不到物件真因=拾取盒写死 0.6 贴脚底原点**（用户报"点了没反应"，前一轮修 monitoring=true 仍点不中）。game_eval 实证：放出的物件根是空 Node3D，孩子是模型实例(缩放后约 10 大)+EntityProperties+PickProxy；PickProxy 的 Area3D 拾取盒 **写死 0.6 贴物件根原点(脚底一点)**，射线点房身必擦过命中空。修法：pick_proxy.gd 加 `_fit_from_target()`——_ready 里自扫 target_node 子树所有 GeometryInstance3D 的本空间 AABB(get_aabb())经 global_transform 换世界角点合并总盒，再用 PickProxy.global_transform.affine_inverse() 折回本空间，喂 fit_to_aabb 让 BoxShape3D.size=真实尺寸、Area3D.position=真实中心。API 经离线文档 4.7 核对(BoxShape3D.size/GeometryInstance3D.get_aabb/global_transform)。**game_eval 闭环三步实证**:①拾取盒从 0.6 变为真实尺寸(8.57×10.50×5.65、中心(0.31,4.75,0.0));②从物件中心投影屏幕再反推射线 → 命中 PickProxyArea;③调 _select_entity 后 gizmo.select 上+手动触发 _update_transform_gizmo→visible=true 手柄出、_prop_panel.visible=true。另证实 global_transform 在 add_child 同帧已同步(盒贴合准)。`_building_to_gizmo` 字典+`_gizmo_selections_snapshot` 废弃删除,改全场一套共享 gizmo(main._ready 建 `_gizmo`/SharedGizmo),_select_entity 里 `_gizmo.clear_selection()+select(target)`,_deselect 里 `clear_selection()`,_place_building 删掉每房 new gizmo。多选能力(Shift 加选)暂不做记债。**待用户手动实操最终认**(机器模拟射线通了,真实体感以你为准) | 🔄 待手动认 |
| 2026-07-07 | FBX 贴图路径问题——FBX 文件里写死 F:\download...，Godot 找不对贴图。以后模型导出必须勾"嵌入贴图"，旧四个 FBX 不修 | 📌 立素材标准 |
| 2026-07-07 | 设计更正：地面材质笔刷 → 地面纹理替换 | ✅ |
| 2026-07-07 | 设计更正：地面材质笔刷 → 地面纹理替换 | ✅ |
| 2026-07-07 | Godot AI 配置路径不匹配（Claude-3p） | ✅ |
| 2026-07-10 | **左栏老栏位消失真因坐实+修。** 现象:跑游戏左栏只剩"场景"格,Token/地形/地面纹理/墙体/装饰/交互物体/光源七栏完全不显示(完全空白,非折叠)。交接总结方向A(每帧节点暴涨)静态读码筛不到元凶(main.gd 无 `_process`、`_physics_process`空、cast_view/gizmo3D 每帧函数均不造节点);方向b(某段动态清老格子孩子)也筛不到。真凶=main.gd 第475/479行用 Godot 3.x 旧属性名 `hint_tooltip` 给 Button 赋字符串——Godot 4.7 已改名 `tooltip_text`(离线文档 gdd_0565_Control 第103/1311行:`String tooltip_text`,setter `set_tooltip_text`)。该赋值非法→`_build_ui` 在场景格(466行)建完后到475行中断→后面七栏没建。修:两行 `hint_tooltip`→`tooltip_text`。game_eval 实证修后左栏 vbox 孩子=25(=1工具标签+8栏×(1分隔线+1标题按钮+1内容容器)),八栏全回 | ✅ 已修 |
| 2026-07-10 | **godot-ai 探运行态全废的真因坐实。** 前几场 helper_live 恒 false、logs_read(source=game) 恒 0 行、game_eval 连不上——交接总结归因"节点暴涨卡死"_被推翻(游戏明明活着能滚轮)。真因=僵尸 Godot 进程占着 6006(调试适配器)/6005(GDScript语言服务)端口,Godot 启动报 `Failed to start Debug adapter server on port 6006: Already in use` + `port 6005: Already in use`。交接总结"netstat 查无输出=端口非根因"_被推翻(端口就是工具链根因)。交接总结怀疑 `embed_subwindows=false` 把游戏赶独立窗断调试通道_也被推翻(独立窗照样 helper_live=true,embed_subwindows 跟调试通道无关)。解法:让用户重启电脑清掉僵尸进程(对零基础最省事)或任务管理器结束残留 Godot 进程。重启后 project_run 立即 helper_live=true/status=live/game_eval 通。已写 memory gvtt_debug_channel_root_cause | ✅ 已解 |
| 2026-07-10 | **game_eval 代码缩进必须用 tab。** 连续3次 EVAL_COMPILE_ERROR,报错 `Mixed use of tabs and spaces for indentation`。根因:game_eval 包装器把用户代码包进 execute() 协程、每行前加一个 tab 做外层缩进;若我的代码内层用空格→拼成 tab+空格混合→GDScript 解析报错。改纯 tab 缩进即通。已写 memory gvtt_game_eval_tab_indent。教训:写 game_eval 的 code 参数缩进一律 tab(JSON 里写成 `\t`) | ✅ 已知 |
| 2026-07-07 | gdstyle cargo 编译失败 | ✅ 改用预编译 zip |
| 2026-07-07 | 两个 project.godot 不同步 | ✅ |
| 2026-07-07 | 离线文档冗余（2.3GB→15MB） | ✅ |
| 2026-07-14 | **网格改 shader 方案(屏幕恒定宽，对标 Godot/Blender)。** 用户问"近粗远细、屏幕恒定宽"怎么实现，并问 Blender/Godot 怎么做的。查证讲清原理：编辑器/Blender 网格都是 shader 在屏幕空间画的(非画3D线段调粗细——GL 线段恒1像素无厚度属性)；核心是片段着色器里对地面坐标取模算到最近线距离 + fwidth() 算每像素覆盖米数，线宽=fwidth 倍数→屏幕恒定。用户提"搞两个地面不就没事了"——采纳：第二层 PlaneMesh 盖在纹理地面上挂网格 shader，shader 不画线处 alpha=0 透出下层纹理，换纹理只动下层 Ground、网格不受影响。**查证 shader API 依据**(离线文档 gdd_0384_Spatial_shaders)：render_mode unshaded/depth_test_disabled/blend_mix(第30/22/13行)、片段内置 in vec2 UV(第264行)、fwidth 是 GLSL 标准、MODEL/VIEW_MATRIX 等。GridMap(gdd_0619)查证是摆方块非画线、EditorNode3DGizmo 编辑器专用打包不存在——坐实"无现成可移植网格"。**实现**：①新增 shaders/grid_shader.gdshader——spatial shader，uniform grid_size/minor_step/major_step/各级颜色(辅灰0.45/主偏白0.9/X红/Z蓝)/line_px(屏幕像素宽1.5)；片段用 UV*grid_size 得米坐标，grid_line() 取模算距离场，smoothstep 转线强度，轴线用 coord-grid_size/2 算以原点为中心的坐标判断|cz|/|cx|；合成按优先级 if 覆盖(辅→主→X→Z)。②main.gd _draw_grid 整块重写：删旧 _build_grid_layer/_build_grid_axes/_axis_mat 三个函数+四级 ImmediateMesh 节点方案，改成建一个 GridOverlay MeshInstance3D(PlaneMesh 100×100)挂 ShaderMaterial，set_shader_parameter 传 grid_size，y0.02。③_adopt_scene_content reparent 改回只认 GridOverlay(不再认 Major/Axes/AxesZ)。**踩坑**：首跑 shader 编译失败 `Unknown identifier 'm'`(grid_shader.gdshader:67)——改合成逻辑时删了用 m/M 的旧段但新段仍引用 m/M 未补定义，补 `float m=max(minor_x,minor_z); float M=max(major_x,major_z);` 后通过。**game_eval 验证通过**(零报错)：GridOverlay 在/visible/y0.02/mesh100×100/材质是 ShaderMaterial/shader_path=res://shaders/grid_shader.gdshader/grid_size参数=100/shader代码3119字符可取=编译成功。⚠shader 视觉效果(线宽屏幕恒定/近粗远细/红蓝轴位)game_eval 看不到画面，待用户手动看体感 | ✅ game_eval 验证通过(机器层)+待用户体感 |
| 2026-07-14 | **新 UV 图设默认地面 + 网格线改三级(辅线/主线/XZ轴线)。** 用户需求三件：①用桌面新 UV 图替换旧的、②设为默认地面、③网格线加回来且换纹理时网格一直在。**查证**：原 UV 图在 assets/textures/ground/uv_checker/UV-3-790x790.jpg(790²)，默认地面 DEFAULT_GROUND_TEX_BASE=""(裸色无纹理)。GridOverlay 节点 game_eval 实测**在**(_scene_root 下、visible=true、参数全对)，用户看不见的根因=线太淡太密：alpha 仅 0.3、地面放大到 100 后 100 条线挤屏幕糊成一片，不是节点丢了。换纹理不会冲网格(_apply_ground_texture 只改 Ground 材质不碰 GridOverlay 节点)。**改动**：①桌面新图 UV_Checker_4096x4096.png(4096²) 复制进项目——旧图 rm 被拦(Operation not permitted)、allow_cowork_file_delete 工具不认路径，改用单独新文件夹 assets/textures/ground/uv_checker_4096/ 放新图(避免多图同组 _classify_texture 按扫目录顺序不确定哪张生效)，旧 uv_checker 文件夹留旧图不碍事；②main.gd 第31行 DEFAULT_GROUND_TEX_BASE "" → "uv_checker_4096"(纹理组标识=_base=文件夹名，_scan_texture_folder 第759行坐实)。**网格三级(本轮从两级升级)**：第一版做两级(辅线alpha0.25+主线alpha0.9)用户反馈"只有粗线、跟gd不一样、gd有XY轴专门的线"。查证 Godot 无现成可移植网格——GridMap(gdd_0619)是摆方块的不是画线的、EditorNode3DGizmo 类编辑器专用打包不存在、编辑器网格是 C++ 引擎层画的无脚本可抄，诚实告知用户只能自己画。改三级：_draw_grid 建4个 MeshInstance3D——辅线 GridOverlay(每1米,alpha0.45调亮,灰,y0.02)、主线 GridOverlayMajor(每5米,alpha0.9,偏白,y0.03)、X轴 GridOverlayAxes(穿过原点沿X,红(0.95,0.35,0.35),alpha1.0,y0.04)、Z轴 GridOverlayAxesZ(穿过原点沿Z,蓝(0.35,0.45,0.95),alpha1.0,y0.04)；逐层抬高y避免z-fighting；不做距离淡出(投屏要恒定可见)。_build_grid_axes 两条轴各一节点各一色材质(避免同材质无法红蓝分开)，辅以 _axis_mat 工厂方法。_adopt_scene_content reparent 按名认列表加 GridOverlayAxes/GridOverlayAxesZ。中途一次 _build_grid_axes 写成"建了又queue_free再调未定义函数"的垃圾代码,自查发现后重写干净。**game_eval 全闭环验证**：ground_has_texture=true、tex_size=[4096,4096]、active_ground_ts_base=uv_checker_4096；四层网格全在——辅线(visible/100×100/alpha0.45/灰/y0.02)、主线(visible/100×100/alpha0.9/偏白/y0.03)、X轴(visible/aabb100×0×0沿X/alpha1.0/红/y0.04)、Z轴(visible/aabb0×0×100沿Z/alpha1.0/蓝/y0.04)。⚠待用户手动看三级网格+UV默认地面体感 | ✅ game_eval 验证通过 |
| 2026-07-14 | **拿掉模型强制归一化 + 默认场景地面 50×50 改 100×100 + 地图模式初始视野缩到 10。** 起因：用户导 1.7m 行者与 1.4m 汽车，放场景后大小差距反常（人显得比车大）。读码定位元凶=main.gd `_place_model` 第1804-1807行强制归一化：取模型三轴最大边长(maxf(x,y,z))统一缩放到 target_size=10。行者最大边长 1.703→放大 5.87 倍到 10；汽车最大边长 4.70(车长)→只放大 2.13 倍到 10。归一化把真实比例抹平，且取"最大边长"而非"高度"使扁平车按长度算、瘦高人按高度算，基准不一致。**改动前先 game_eval 实测坐实链路**（不靠猜）：调 LibraryManager.load_model_runtime 把两 glb 读进来、不经过归一化直接量原始 AABB——网行者test.glb=0.51×1.703×0.76、破损汽车3d模型.glb=4.70×1.465×2.08，证明 Blender→glb→Godot 单位即真实米（1单位=1米），无需换算，用户"对接 Blender 尺寸标准用 glb"的直觉对。**改动**：①删 main.gd 1802-1807 归一化四行（target_size/max_extent/scale_factor/instance.scale），换说明注释记依据；②顺改 1831-1833 行 force_update_transform 注释（原写"instance.scale 刚设"已不设 scale）；③grid_size 默认 50→100（地面 PlaneMesh.size 与网格 half 都读它，自动跟着变）；④_map_size 默认 25→10（用户要地图模式初始显示范围小一点，物件显大好摆；滚轮缩放范围 5-80 不变够拉远看全 100 地面）。`_calc_instance_aabb` 函数成死代码（仅自递归无外部调用），暂留不删避免扩大改动。**game_eval 全闭环验证**（停游戏重跑让新代码生效，MCP stop 未断连）：grid_size=100、Ground PlaneMesh=100×100、_place_model 摆行者后 inst_scale=[1,1,1]（未缩放）、真实世界 AABB=0.51×1.703×0.76（与 glb 原始值一致，未被归一化成 10）、函数跑到底无报错、proxy.fit_from_target_synced 照常调；_map_size=10、camera.size=10、projection=1(正交)。⚠用户已手动摆模型认真实比例体感=对 | ✅ game_eval 验证通过 + 用户体感确认 |
| 2026-07-09 | **代码体检+真坑修复+多场景骨架落地。** 体检五脚本按 CLAUDE.md"所有 Godot API 须有离线文档依据"规矩，逐行对离线文档 4.7 实读核对。**真坑**：①`flags_unshaded` 在 Godot 4.7 已废弃（grep gdd_0864_BaseMaterial3D 零命中，4.x 改名 `shading_mode`，取 `ShadingMode.SHADING_MODE_UNSHADED`=0，文档第 112/317/1670 行）——main.gd 第 300 行网格线材质、pick_proxy.gd 第 172 行标记球材质两处都用着废弃 API。②`flags_no_depth_test` 也属 3.x 旧名，4.7 改 `no_depth_test`（文档第 90/1462 行，property+set_flag/get_flag）。③main.gd `_place_building` 第 977 行 add_child 未设 owner——pack 场景存盘会漏物件（gdd_1006 第 31-45 行原文），即多场景草案坑1，本会话收进 module_io._ensure_ownership。**已修**：①② 两处 API 改对（main.gd/pick_proxy.gd 各一处材质 flag 修复），行为不变仅用对 4.7 API 名。③ 暂不在 main.gd 修（不影响现行游戏），改收进 module_io 存盘时统一补 owner。**用户拍板"理顺分寸"**：主线是结构,顺手真坑修,孤立单脚本能跑的不动。**骨架落地 5 文件**（用途见功能进度那条），全留 TODO、未接 main.gd、未注册 autoload、不改 project.godot 不改 main.gd 行为，现行游戏不受影响。architecture.md 文件结构图已补这 5 文件标注"骨架占位"。**未做**：未 game_eval 验证骨架方法体（未调用无副作用，待接入时验）；未跑 gdstyle lint；project.godot autoloading 未动需 GM 下次会话决定是否注册 ModuleGate | 🔄 骨架立待接 |
| 2026-07-07 | 项目启动前自查 8 项 | ✅ 全部完成 |
| 2026-07-10 | **多场景系统第一段接入+class_name 遮蔽坑。** 用户拍板：开机默认一个"测试模组"（临时硬编码名待"导入/新建模组"UI 移除），场景存进它；场景加时自动起名场景N+1；保存语义=左栏点哪个选中、保存覆盖那个；场景文件内容=相机+地面纹理+网格+灯物+物件（不含 gizmo/投屏/UI 这些 GM 工具），用户点破"做关卡当然存相机"。**实现**：①main.gd 加 `_scene_root`(Node3D) 容器，相机/方向光/WorldEnvironment/CameraPivot/Ground/GridOverlay 在 `_adopt_scene_content` 里 reparent(依据 gdd_0512 Node.reparent 第142/1668行)进它+set_owner=它；`_place_building` 物件进它+set_owner=它，**正面修了 owner 陷阱**（gdd_0512 第691行 pack 只存 owner=根的节点）。UI/gizmo/cast_view 留 Main 不设 owner→pack 不收。②左栏"场景"节加"新建"+"保存此场景"按钮+场景列表订阅 ModuleGate.scene_list_changed 刷新。③module_gate.gd 加默认模组开机建+add_scene/save_current_scene/list_scene_names/set_current_location。④project.godot 注册 ModuleGate autoload。**真坑(2026-07-10 定性)**：module_gate.gd 同时声明 `class_name ModuleGate` **和** autoload 单例名 `ModuleGate` 重名 → Godot 解析 main.gd 时把 ModuleGate 当"脚本类"非 autoload 实例 → 报"Cannot call non-static function on class ModuleGate directly, make an instance"，连带第125行"Cannot find member scene_list_changed in base ModuleGate"。**修法**：删掉 module_gate.gd 的 `class_name ModuleGate` 行——autoload 单例名本身即全局访问名，不需要 class_name（依据 gdd_0374 Singletons）。script_patch 触发 main.gd 重解析后 diagnostics=none 确认文件层已干净。**但跑游戏仍报同样 parse error**——根因是编辑器脚本缓存脏：用户今早重启 Godot 时 module_gate.gd 还带 class_name，Godot 启动时把 ModuleGate 注册成脚本类；本会话删 class_name 后 Godot 未重启、缓存未刷新。**待用户重启 Godot 一次**让编辑器重读 module_gate.gd、认到无 class_name，跑游戏才能起。重启后做 game_eval 实测存→读（PickProxy.target_node 节点引用重连那个最大未知点）。未跑 gdstyle lint。+ ⚠ **2026-07-10 续会话证伪：上面那个"待重启 Godot"定性不对。** 重启 Godot（磁盘 module_gate.gd 已干净无 class_name、autoload list 实测 ModuleGate 在）后跑游戏，现象跟重启前**完全一样**——helper 始终 not_live、game_eval 连不上。证明 class_name 脏缓存**不是**游戏起不来的根因，是从上一份交接总结继承的错误假说，已推翻。详见 `docs/session_handoff_2026-07-10_round2.md`。真正的卡点见下一条 | 🔄 待查真正根因 |
| 2026-07-10 | **【续会话】游戏僵死卡顿循环 + MCP 重连规律 + 左栏坏体验初查。** 详见 `docs/session_handoff_2026-07-10_round2.md`。摘要：①MCP 断连**优先重启 Cowork 客户端(Claude Desktop)而非 Godot**——服务端通常还活只掉会话，重启客户端拿新会话即连（用户原话"以后别让我重启 gd，重启你就行"，已存 memory `gvtt_mcp_reconnect_shortcut`）。②跑游戏触发的"僵死卡顿循环"实测链：游戏窗弹出、`is_playing=true` 但 `game_status.status` 自相矛盾(stopped/not_live)、helper_live 恒 false、右上角播放键变刷新按钮关不掉、Debugger Errors 面板空、netstat 查 6006/6005 端口**未占**、调 `project_manage(op=stop)` 反触发 MCP 断链。helper 不通报活的根因**未坐实**（源码第63-90行/654-681行读过：助手靠 EngineDebugger 调试通道发 mcp:hello，编辑器收到才记 live；hello 跟 MCP 8000 端口是两套线）。runtime monitors 实测 object/count 84333、render 2700 物件/帧——某处造巨量物件，`_draw_grid`(第414-440行)只调一次已排除非元凶，元凶疑在 `_process` 反复 new()+add_child 不撤旧，**下次查证方向 A**。③`editor_reload_plugin` 不准用（断链）已写 CLAUDE.md，**本次新增：`project_manage(op=stop)` 也不准用来停僵死游戏**（已证明触发断链），停游戏优先让用户手动在 Godot 操作。④左栏坏体验初查（用户报"左边只剩场景格、点场景1弹更多场景1"）：磁盘代码第870-874行坐实——左栏整条 `_left_panel` 受 ModeGate 控制、运行态整条藏；场景格也属 `_left_panel`(第466行)按理该一起藏，用户却见场景格孤在，**疑似运行态异常未坐实**。点场景1增场景的根**磁盘代码查不出**（grep 实测 add_scene 只在开机第109行+"新建"按钮第183行调、`_on_scene_selected` 第170-177行不调），要 game_eval 看运行态真值。⑤用户拍板"先修左栏坏体验"未做完，因为要 game_eval 才能坐实、game_eval 要先解卡顿，两条线交缠。⑥用户提大问题"这项目跟 gd 多少关系、是不是很多该多依托 gd"——本次回应：main.tscn 几乎空骨架(6节点)、相机/光照/地面/网格/UI 全靠 main.gd 运行时 new() 挂(第96-483行)，是逆 Godot 常规做法，灵活但反噬(难调难查、节点暴涨难追)。辩证判断：静态部分(相机/光照/地面/UI)可考虑回 .tscn、GM 工具层(投屏/拾取/ModeGate/ModuleGate)Godot 没现成须自造。已存 memory `gvtt_all_code_scene_arch`/`gvtt_game_freeze_symptom`。本次会话教训：违反过"不准堆英文"规矩被批评、凭交接总结假说一路查到底浪费用户时间、EVAL_GAME_NOT_READY 时 Glob/Read（直接读磁盘文件）能用（参考路径见上）；任何会话因工具节制思路卡顿**不要硬挤乱字符输出，停手让用户给一句话再动** | 🔄 待查真正根因 |
| 2026-07-09 | **多场景/关卡系统架构草案。** 起因用户提出"跑团一幕一幕，参照剧情关卡/游乐园类项目结构把大逻辑理顺"。经多轮辩证+确认：①丢弃"线性关卡推进"参照（跑团是 GM 任意跳，非通关顺序），取"游乐园式任意选项目进场"模型——但更进一步用户反驳"主区"概念不成立，一场跑团会走很多不同地点，最终定地点=场景文件、模组=一场跑团装所有地点、一幕=地点+当前进度组合（不分主区，A 跨地点切与 B 时段推进天然都支持）。②两套存档=模组底本（备团成果出厂布置）+带团存档（一次实际跑团快照能接续），用户确认都要。③自动保存=切幕那一刻写盘+手动按钮兜底（不走每步实时盘写，理由：磁盘IO卡顿违反维度④+实时覆盖等同无撤销保护）。④叙事文本暂不做UI但留 `notes/historical_notes` 字段占位（Resource 加 String 字段近零成本，将来加 UI 只是挂 TextEdit）。⑤新增全局真值建议 autoload `ModuleGate`（持有当前模组/地点/session，广播 current_location_changed），对齐 ModeGate"功能自报归属"规矩，不塞进 ModeGate 混职责。依据：design.md 第③维度"GM 管理一个完整冒险非孤立地图"+Godot 4.7 离线文档 gdd_1006_PackedScene(pack/instantiate 第129/135行、pack owner陷阱第31-45行)、gdd_1477_ResourceSaver、gdd_1476_ResourceLoader。揭示未落地地基坑：①pack 只打包有 owner 的子节点，main.gd `_place_building` 放物件未设 owner 存盘会漏（须正面修不许绕）；②EntityProperties/PickProxy 含 NodePath 引用，序列化加载后须重连验证；③切地点主相机/投屏 CastView 共享 World3D 须重连（architecture 3.6）；④编辑态切地点=换舞台备团 vs 运行态切地点=带团走到新地点（触发切幕写盘）须按 ModeGate 分流。依赖关系确认正确：多场景(P4)须盖在 P1 单场景存读盘成熟之上。**网页搜索工具本会话多次无结果返回**，"游乐园类/剧情关卡现成项目结构参考"无外部依据拿到，草案主体基于官方 API+项目自身设计决策，不装懂；待查点已标进草案第10节。本次未动任何代码，仅写 `docs/multi_scene_draft.md` 草案 + 更新 DEVLOG，待用户批阅后下次会话动手 | ✅ 草案立 |
| 2026-07-10 | **【存→读闭环实测坐实 + PickProxy.target_node 加 @export 修复】** 接 session_handoff_2026-07-10_round3 开场白做优先级1（存→读闭环）。**通道**：新会话不假设通，project_run 后 helper_live=true/status=live（僵尸进程未复发，通道通）。**静态读码**：module_io.gd save_scene_tree（_ensure_ownership 补 owner + PackedScene.pack + ResourceSaver.save）/load_scene_tree（ResourceLoader.load CACHE_MODE_IGNORE + instantiate）；module_gate.gd save_current_scene/add_scene/list_scene_names；main.gd _scene_root/_adopt_scene_content（相机/光/WorldEnv/CameraPivot/Ground/GridOverlay reparent+set_owner）/_place_building（root+instance+props+proxy 四个都 set_owner(_scene_root)）/三个场景按钮回调。**离线文档核对**（gdd_1006_PackedScene 第31-50行 pack 只存 owner 节点+第135行 pack 签名+第129行 instantiate、gdd_1477_ResourceSaver 第19/90行 save+第98行运行时不存UID、gdd_1476_ResourceLoader 第165行 load+第63行 CACHE_MODE_IGNORE、gdd_0306_exported_properties **第519行关键**:普通 var 不存进文件+第308行 @export Node 合法+第314-319行 NodePath 老办法）。**实测6步闭环**（game_eval 缩进用 tab）：①造物件查基线 ②save_current_scene 存盘 ③load_scene_tree 读回不挂树查结构 ④查 target_node 读回值 ⑤清树挂回 ⑥查挂回后状态。**第一轮（空 Node3D 测试物件）结果**：存盘✅(5467字节落盘)、owner陷阱处理✅(节点没漏)、EntityProperties @export字段✅(6字段全对)、**PickProxy.target_node❌读回丢成null**（根因坐实:第21行 `var target_node` 普通var没@export,gdd_0306第519行明文不存文件）、挂回后拾取盒退回0.6针孔(因target丢→_fit_from_target没跑)。**修法**:用户选路线A(加@export最小改动)→pick_proxy.gd 第21行改 `@export var target_node: Node3D = null`+补注释。**第二轮（重启游戏加载新脚本后，用带真FBX模型的物件重测）结果**:存盘✅(5703字节)、读回挂回后 target_node✅重连(target_name=TestEntity)、模型GeometryInstance3D✅(1个没丢)、**拾取盒✅贴合(9.53×10×5.72 与存盘前一致没退化)**、EntityProperties✅(真物件乙/30全对)。**结论:路线A成立,不用走路线B(NodePath)**。⚠未验:真人点鼠标选中(game_eval没法真点,拾取盒尺寸对+target重连是必要条件,最终待用户手动跑游戏点一下认体感)。⚠暴露的架构点:存盘pack的是_scene_root本身,读回得到一个新SceneRoot,挂回时套两层(Main/SceneRoot/SceneRoot/TestEntity)—"怎么挂回去"是切场景换树(switch_location)要解的问题,本轮未展开。⚠game_eval坑:长闭环代码触发包装器"Standalone lambdas cannot be accessed"Parser Error致游戏卡break,改拆小步短代码即避。改文件用Write工具(DEVLOG记过godot-ai write_text偶发写坏) | ✅ 存读闭环通 |
| 2026-07-10 | **【切场景换树真实现】** 用户实测踩到"新建场景2后还看到场景1东西/点切换无效果"——坐实交接文档优先级2没做(_on_scene_selected只挪指针不换树、_on_new_scene_pressed不清舞台,代码注释自承认)。**架构决策(方案乙,用户拍板)**:两层分离——骨架层(相机/方向光/WorldEnvironment/CameraPivot/Ground/GridOverlay)所有场景共用**不存盘**;内容层(_content_root Node3D)装建筑物件,**存盘只pack这一棵**。理由:相机/光/地面是GM看场景的眼睛不是场景内容,切场景时骨架不动→相机/投屏/gizmo引用全不用重连,连带影响最小。推翻上一场"pack整个_scene_root含骨架"的存读(旧场景1/2/3.scn旧格式含骨架被删)。**切场景动作设计(用户拍板:切时弹窗三选一)**:平时操作不存盘(防卡,符合维度④);点切场景→弹窗"保存后切换/不保存直接切换/取消切换";选存或不存后才真换舞台。新场景没存过=空内容层(用户拍板"清空成空舞台")。地面纹理第一版不随场景存(只换建筑)。**代码改动**:①main.gd加`_content_root`(_scene_root下,owner=_scene_root),`_place_building`物件改挂_content_root+owner=_content_root,`_on_save_scene_pressed`传_content_root;②`_switch_to_scene(target)`:清_content_root孩子+queue_free→_deselect→ResourceLoader.exists判存过则load_scene_tree读回把**孩子搬进当前_content_root**(不套两层)+`_ensure_owner_recursive`重设owner→更新_current_scene_name+ModuleGate.set_current_location+_sync_scene_list;③`_on_scene_selected`改弹窗(_pending_switch_to记目标);④`_on_new_scene_pressed`新建后走切换;⑤`_show_switch_dialog`+三个回调(_on_switch_dialog_save/custom/cancel)。弹窗API:gdd_0513 AcceptDialog ok_button_text/add_cancel_button(canceled信号)/add_button(custom_action信号)/popup_centered(gdd_0786第1400行)。**坑**:旧 场景1/2/3.scn 是改架构前pack整个_scene_root存的(含骨架),新代码读会把相机/光/地面当物件塞进_content层=骨架重复。用户批准删3个旧文件,新格式只存物件(场景1新存1706字节 vs 旧1.87MB)。game_eval坑:`break`在for循环里触发包装器"Expected end of statement, found break"Parser Error致卡break,改拼字符串路径不循环即避。**game_eval闭环全通**:场景1放带FBX模型物件+存盘(新格式)→切到新场景2(内容层清0、无骨架残留)→切回场景1(物件读回、target_node重连、拾取盒9.53×10×5.72贴合、EntityProperties属性对)。⚠未验:真人手点切场景认体感(game_eval只直调_switch_to_scene,没手动操作弹窗UI);切场景后投屏窗CastView么同窗重显未验(骨架没动理论上不影响)。下一步:用户手动跑游戏实操认体感,再优先级3切场景提示UI优化/4重命名删除场景/5模组UI | 🔄 代码通待手认 |
| 2026-07-10 | **【修两 bug：地面纹理随场景存 + 脏标记】** 用户实测报两个 bug。**bug1 地面纹理不随场景存**(所有场景按最后一套纹理):根因纹理状态在 Ground 骨架层不存盘。→ 新建 scene_props.gd(class_name SceneProps,@export ground_tex_base/ground_tile)挂 _content_root(set_script),换纹理/改平铺写进它,存盘 pack _content_root 时随场景序列化,切场景读回按它重建 Ground 材质(_apply_ground_texture_for_scene)。**bug2 存过了切场景还问要不要存**:加 _scene_dirty 脏标记(放物件/换纹理/改平铺置脏;存盘成功/切场景完成清脏;切场景只 dirty 时弹窗)。game_eval 双验通过:场景1 stone_floor/场景2 uv_checker 各自独立切回不变;存盘后切直接切不弹窗。**踩坑**:改完代码编辑器缓存脏报"_apply_ground_texture_for_scene not found"行号偏移→重启 Godot 编辑器清(不断 MCP) | ✅ 两 bug 修 |
| 2026-07-10 | **【默认空场景专门记录 + 开机不扫盘】** 用户报 bug1"新建场景2不是默认空白、是之前保存的场景、保存过再打开程序不清空"+ bug2"新建场景3跟一开始空场景不一样、默认场景该有专门记录"。bug1 根因:add_scene 起名"场景N"可能撞磁盘旧 .scn 文件名,撞上就读到旧内容。bug2 根因同 bug1(撞名)+用户点破"默认场景该有专门记录"。**修法(用户拍板"做新模组从干净开始、要用旧模组靠将来导入模组")**:①开机不扫磁盘、建全新空模组(ModuleGate._ready 已是建空 manifest,确认不改);②add_scene 起名跳过清单已用名(防撞);③main.gd 加 DEFAULT_GROUND_TEX_BASE/TILE 常量集中记默认场景长相(纯空舞台=无物件+默认纹理/裸色+默认平铺),_apply_default_scene() 统一入口(开机/新建/切到没存过场景都走它,将来改默认只改这处)。删了上几轮残留 场景1/2/3/4.scn。game_eval 实测:开机场景1纯空(0物件/默认纹理)→新建场景2纯空→新建场景3纯空→清单名不撞递增→磁盘有场景3.scn但新建场景4空(没读旧内容)→切回场景3读到物件+target重连。**踩坑**:改完代码又缓存脏报"_apply_default_scene not found"→重启 Godot 编辑器清(第二次同坑)。⚠未验:真人重启游戏认"保存过再打开程序新建是空白"(game_eval 不能重启程序,但代码+实测双证:开机不扫盘+add_scene 防撞) | ✅ 默认场景修 |
| 2026-07-13 | **【bug3 模型偏移从导入源头清 + 复盘为何修这么久】** 用户报"保存场景切回来模型偏移"。**根因坐实**:FBX 模型 mesh 子节点自带 position(实测 CP Building_001 的 Front_Building_01B position=-95),_reset_all_transforms 清成0、存盘存0,但 Godot pack/instantiate 读回时变回模型原值-95,几何飘 -95×scale=-19(实测 diff=-19.04 X轴)。模型 AABB 原点也偏(-36,-0,-14.4),几何中心不在 mesh 原点。**修法(用户从一开始就给的正解)**:从导入源头清模型自带位置信息——新建 scripts/post_import_center.gd(@tool extends EditorScenePostImport,API 依据 gdd_1276 _post_import(scene) 拿根节点改后 return):导入 FBX 后自动 ①_置所有子节点 position/rotation=0(scale 保留) ②算整棵合并 AABB 中心(_walk 用 local transform 累加,不用 global_transform——post-import 时节点没进场景树 global_transform 报 !is_inside_tree)给根节点设 position=-(中心) 让几何居中到原点。挂给四个 FBX:改 .import 的 import_script/path=res://scripts/post_import_center.gd + filesystem_manage(op=reimport) 触发。重导后 mesh 子节点 position=0、根节点带居中位移(12.22,-24.98,0.17),game_eval 存读闭环 diff=0 不偏。**为何修这么久(逐步复盘,不朦胧)**:①方向偏——用户说"软件根本不认模型自带位置信息、原点归0"是设计指令,我当猜测去查 _switch_to_scene 读回逻辑,机器读 root.position 没变就说没复现,绕几轮;②加 @export 修 PickProxy 拾取盒(_box_size/_box_center)治标不治本(手柄偏≠模型几何偏,混着改);③加抵消位移(算 AABB 中心设 instance.position=-(中心×scale))治标——脏在 mesh 子节点不在顶层,且子节点 position 存0读回变-95 存不住;④BuildingData+读回重建(不存模型实例只存数据)造屎山,重建跟残留叠加多出一份模型;⑤查"Allow Geometry Helper Nodes"导入选项判断错——它本就 false(查 .import 第44行);⑥post-import 第一版用 global_transform 但节点没进树报错;⑦改脚本后编辑器缓存脏、重导还跑旧脚本,重启 Godot 才重读。**总教训**:用户给的设计方向优先于我查的技术细节;简单事别绕成跟引擎存读搏斗;post-import 脚本改了要重启 Godot 重读。回退了屎山(BuildingData/抵消位移删除,building_data.gd 文件删),保留合理改动(PickProxy @export 拾取盒、post_import_center.gd、.import 挂脚本) | ✅ bug3 修 |
| 2026-07-12 | **审阅吸收 UnorthodoxHacks。** 品鉴 GitHub 项目 [Muigoochen/UnorthodoxHacks](https://github.com/Muigoochen/UnorthodoxHacks)——一个 Godot 4 工具函数库，封装 FileAccess/DirAccess/ConfigFile 的静态方法集。评价：写得扎实（静态类型全覆盖、防御性编程到位、备份轮转机制完整、跨平台路径处理细致），但项目和 Gvtt 不是同一层面产物（它是工具库，Gvtt 是完整产品）。吸收三处进开发文档：①备份+轮转策略写入 `docs/multi_scene_draft.md` 第 4.1 节（后缀 `.bak`、保留 5 份、copy vs rename 权衡）；②顺序命名空缺编号算法记入同一节；③`#region` 分区习惯 + 防御性编程纪律写入 `docs/architecture.md` 第 7 节。不采纳其全部：工具函数以 static func 直调为中心，不认 ModeGate/ModuleGate 权限约束，不适合作为依赖引入。DEVLOG.md 此条记毕 | ✅ 已吸收进文档 |
| 2026-07-13 | **【bug4 地面纹理导入法线图被当颜色图显示】** 用户报"导入 2K_Gravel01 文件夹后以法线贴图样子展示，不是把法线当贴图"。测试文件夹 3 文件：gravel_diffuse_xtm.jpg（颜色/diffuse）、gravel_displace_xtm.jpg（位移）、gravel_normal_xtm.jpg（法线）。**根因坐实（game_eval）**：原分类逻辑用"后缀结尾匹配"（ends_with），只认 _diffuse/_normal 这种类型词在文件名**结尾**的；但这批素材类型词在**中间**（结尾是 _xtm），三个文件全匹配不上→全走"认不出默认当 albedo"→字典 albedo 键被连续覆盖，字母顺序最后的 gravel_normal_xtm 赢→法线图被存成颜色图。**修法（用户拍板"搜关键词"）**：library_manager.gd _classify_one_texture + main.gd _classify_texture 两处都从"后缀结尾匹配"改成"关键词子串搜索"（find>=0），文件名里出现 normal 就当法线、diffuse/albedo/basecolor/color 就当颜色图，不管词在哪个位置。关键词按长度降序排（basecolor 比 color 长先匹配）避免短词误吃长词。另修覆盖 bug：_scan_one_ground_folder + _scan_texture_folder 多张同类型图加"只认第一个不覆盖"保护（if not group.has(type)）。game_eval 实测修后：2K_Gravel01 分类成 albedo=gravel_diffuse_xtm.jpg + normal=gravel_normal_xtm.jpg（displace 被默认当 albedo 但已被 diffuse 占→忽略，合理位移图不当贴图），_apply_texture_set 贴上 albedo_tex=true + normal_on=true 正常。displace（位移图）分类规则未收录，默认当 albedo 再被忽略——日后要支持位移图再单独加规则 | ✅ bug4 修 |
| 2026-07-13 | **【右键删除素材功能】** 用户需求"左栏栏位里右键弹出删除"。**用户拍板**：①只删导入的（user:// 下），自带素材（res:// 打包后只读 gdd_0372 第60-63行）右键"删除"灰掉提示"自带素材打包后只读删不掉"——推翻用户反问"有必要分自带导入吗"，辩证说明：打包后自带素材物理只读，不分就会给打包后失灵的按钮，带 📥 标记导入素材一眼可辨，UI 无需额外做识别；②点"删除"即删不额外弹窗确认（右键这一步当确认）。**实现**：查实 API——Button 继承 Control.gui_input 信号捕获 InputEventMouseButton 右键、PopupMenu（gdd_0707）add_item(label,id)+id_pressed 信号+set_item_disabled 灰显+set_item_tooltip+popup(Rect2) 弹鼠标位置。LibraryManager 加 delete_model（删 user://library/<cat>/<文件>，DirAccess.remove_absolute）+ delete_ground_texture（删整文件夹：先逐文件删再删空文件夹）。main.gd _btn_model + _btn_ground 各加 gui_input 连右键回调 _on_model_btn_gui_input/_on_ground_btn_gui_input：建一次性 PopupMenu add_item"删除"→导入的可点+自带的 set_item_disabled 灰掉+tooltip 说明→id_pressed 回调 _delete_model_item/_delete_ground_item 删文件+重建列表+menu.close_requested queue_free 释放。地面纹理 _rebuild_ground_buttons 给 set 加 source 标记（builtin/imported）供右键判能否删；_delete_ground_item 若当前地面正用这套纹理则清选中+藏平铺控件避免指向已删文件。**game_eval 实测**：delete_ground_texture("2K_Gravel01") before=1 deleted=true after=0；delete_model("decor","网行者test.glb") before=1 deleted=true after=0。删除方法闭环通。⚠未验：真人右键点按钮弹菜单选删除（game_eval 不能真点鼠标右键，PopupMenu UI 交互待你手动实操认），用的全是查实 API | ✅ 删除功能加 |
| 2026-07-14 | **【右键删除菜单 bug：绕四轮终于修通+复盘】** 用户需求"左栏素材按钮右键弹删除菜单"。**最终方案**：_input 最开头判"右键按下+鼠标在左栏(_left_panel 全局矩形)"→调 _handle_right_click_menu 坐标命中检测(遍历 _model_panels 各栏 container + _ground_list_container 的按钮，鼠标坐标落在哪个按钮 get_global_rect 里就弹那个的菜单)+set_input_as_handled+return(不转相机)；菜单弹在 DisplayServer.mouse_get_position()（屏幕坐标，因 embed_subwindows=false PopupMenu 是独立 OS 窗要屏幕坐标，用 get_viewport().get_mouse_position() 窗口内坐标会偏到窗外——用户实测"菜单飞到游戏窗口外"坐实）。自带素材"删除"set_item_disabled 灰掉+tooltip"自带素材打包后只读删不掉"。按钮靠 set_meta("kind"/"category"/"index" 或 "group"/"source")存身份，右键时读 meta 知道删哪个。**绕四轮的复盘(教训)**：①第一轮用按钮 gui_input 信号连右键回调——game_eval print 实测 gui_input 只收 InputEventMouseMotion、收不到 InputEventMouseButton(项目里所有 MouseButton 都被上层截走，左键能用是走 _unhandled_input 不靠 gui_input)，方向错；②第二轮改用 _unhandled_input + gui_get_hovered_control 找按钮——print 实测 gui_get_hovered_control 返回 null(疑 embed_subwindows=false 致 Viewport 错位)，方向又错；③第三轮改 _unhandled_input + 坐标命中检测——print 实测右键到不了 _unhandled_input(只有 pressed=false 松开到，pressed=true 按下被 _input 抢去转相机)，_input 里"左栏判断"用 event.position(相对坐标)跟 _left_panel.get_global_rect()(全局矩形)比，坐标系不一致判断永远不成立；④第四轮才对：直接在 _input 最开头处理右键菜单(_input 本来就收得到右键按下，它一直在抢就是证据)，在转相机逻辑之前，set_input_as_handled 标记已处理。**总教训**：①用户说"走了歪路"是对的——没先搜现成方案(CLAUDE.md 规矩)就自己推理绕四轮；②`_input` 抢走事件时，在 `_input` 里处理是正解，别绕到下游 _unhandled_input/gui_input；③embed_subwindows=false 下独立窗口的 popup 位置要屏幕坐标(DisplayServer.mouse_get_position)，不是窗口内坐标；④坐标比较要统一坐标系(event.position 相对 vs get_global_rect 全局)；⑤加 print 探针时别读键盘事件的 position(InputEventKey 无 position 会崩把游戏搞进 break)。LibraryManager 加 delete_model/delete_ground_texture 两方法已 game_eval 验过(删前1删后0)。⚠未验：真人右键弹菜单+点删除(菜单位置这次改屏幕坐标应贴鼠标，但用户关对话前未确认弹对位置，待下次手动认)。代码已清干净 debug print | ✅ 右键菜单修通(位置待手认) |

| 2026-07-14 | **【shader 网格"近粗远细"无效果诊断+待修】** 接前几场 shader 网格工作。用户报"网格没跟随相机/地面远近变粗细"。**已验证**：shader 挂在 GridOverlay（运行态 /root/Main/SceneRoot/GridOverlay），grid_size=100 参数对；两次截图（cam.size=5 拉近 / cam.size=40 拉远）都能看到网格（辅线灰/主线白/红蓝轴线）+UV 纹理。**根因坐实（读 shader 代码）**：`shaders/grid_shader.gdshader` 第20行 `uniform float world_line = 0.04`（4厘米）太细——拉近看10米地面时线才约3像素粗，拉远掉到保底1.5像素，3→1.5像素变化肉眼基本无感。正交相机（地图模式）单帧无透视变化，粗细只在"拉远近动作"时变，这点设计本身对。**待修（一行）**：world_line 从 0.04 改 0.15（15厘米）→预期拉近约10像素/拉远1.5像素，变化明显。⚠未做：值没改、没 game_eval 验证改后效果（用户要开新对话，留给下一场）。game_eval 缩进必须 tab；场景修改合并一个 batch_execute；禁断链 MCP | 🔄 待改 world_line |

---

## 十大未解之谜 🕵️

> 留案待查。记的不是已修好的 bug，是**没坐实根因就自己好了/偶发的怪现象**。再犯时回来翻这里，能省一堆瞎查。破一个就标 ✅ 挂日期，凑齐十个看会不会召唤神龙。

### 谜 #1：右键删除"打开不拖就不弹，拖一下窗口就好，后来又自己好了"（2026-07-14）

**现象：** 用户报右键不出删除菜单。发现"拖动一下窗口"就恢复正常能删。再后来用户说"现在又好了，打开不拖也能删了"——啥都没改自己好了。

**当时查到的：**
- 右键菜单代码完整没被弄掉（_input 第1446-1450行 + _handle_right_click_menu + _popup_delete_menu_model/ground 都在）。
- game_eval 查初始状态：窗口1280×720、左栏矩形(0,10,200,710)、按钮矩形正常、content_scale_factor=1，看着都对。
- game_eval 喂模拟右键事件到按钮中心坐标，菜单没弹出（popup_count=0）——但发现 _input 判"鼠标在左栏"用的是 `get_viewport().get_mouse_position()`（真实鼠标位置），不是事件自带坐标，所以模拟喂事件验不出来（game_eval 改不了真实鼠标）。

**最强嫌疑（未坐实）：** 窗口记忆功能（_ready 里设 win.size/win.position）启动时设了窗口位置，但 Godot 内部"窗口屏幕位置/内容尺寸状态"没立刻同步 → 弹菜单用的 DisplayServer.mouse_get_position()（屏幕坐标）算出错误位置 → 菜单弹飞到看不见的地方（看着像"没反应"）。拖窗口强制重同步 → 菜单位置对了 → "恢复"。

**"自己又好了"的一个可能解释：** 复盘发现我在一次 game_eval 里设过 `win.content_scale_size = Vector2i(1280, 720)`，设这个属性可能触发了 Godot 重新同步窗口/布局状态（等价于拖窗口的效果）。但用户记不清"又好了"是哪次跑游戏，无法坐实是这个动作治好的还是偶发。

**为什么没改代码：** 根因没坐实 + 功能自己好了 + game_eval 没法终验（改不了真实鼠标、看不到菜单弹哪）。没复现就改=瞎改，违反"不绕远"规矩。

**再犯时怎么查：** ①第一时间问用户"游戏窗口弹在屏幕什么位置"（飞偏了=屏幕坐标没同步嫌疑大）；②在 _popup_delete_menu_model 临时加 print 打印 DisplayServer.mouse_get_position() 和 get_window().position + get_viewport().get_mouse_position()，对比三个坐标差，看屏幕坐标是不是算飞了；③若坐实是 content_scale_size 同步问题，预防性修法=_ready 设完窗口后主动设 content_scale_size 跟窗口尺寸一致（一行，低风险）。

**状态：** 🕵️ 待再犯抓现行

---

## 2026-07-15 修 main.gd 被截断 + 场景宽×高改造收尾

### 起因
用户报"昨天搞坏了，问题可能在 main.gd / grid_manager.gd / scene_props.gd 三个文件里"。

### 查证根因（editor logs_read source=editor 实拿 parse error，非缓存猜测）
编辑器报 3 个 parse error（main.gd）：
1. 第386行 `set_grid_size()` 调用只传1参，函数要2参。
2. 第1893行 调 `_reset_all_transforms()` 但该函数在 main.gd 里不存在。
3. 第1934行 用 `_model_panels`（少个 s），声明的变量是 `_model_panelss`。

**根因**：上一场把"场景尺寸"从单一 `scene_size` 改造成宽×高（`scene_width`/`scene_height`，长方形场地），但 **main.gd 只改了一半就断了**：grid_manager.gd 的 `set_grid_size` 已改成 `(width,height)` 两参、scene_props.gd 已加 `scene_width`/`scene_height` 字段，但 main.gd 还全程用旧 `scene_size` 单值（`set_grid_size(size)` 只传1参→报错1）、`_content_root.scene_size=xxx` 赋不存在的字段；且 `_place_model` 写到一半**文件被截断**，`_reset_all_transforms` 定义整个丢了、末尾留半截 `_model_panels`（报错2、3）。git HEAD 无 main.gd（从未提交），main.gd.bak 大小同当前坏版（救不了），三条还原路全断，只能据上下文补。

### 用户拍板方向
问用户"回退到单一尺寸 vs 改造到底（宽≠高）"，用户选**改造到底**。

### 改动（main.gd）
1. 常量 `DEFAULT_SCENE_SIZE` → `DEFAULT_SCENE_WIDTH`/`DEFAULT_SCENE_HEIGHT`。
2. 成员 `_scene_size_input`（单 SpinBox）→ `_scene_width_input`/`_scene_height_input`（两个）。
3. `_on_scene_size_changed(new_size)` → `_on_scene_width_changed(new_w)` + `_on_scene_height_changed(new_h)` 两个回调，各自只改自己那一维；加 `_current_scene_width()`/`_current_scene_height()` 取另一维真值（读 _content_root SceneProps，避免回调里读输入框旧值互相覆盖）。
4. `_apply_scene_size(size)` → `_apply_scene_size(width,height)`：地面 PlaneMesh 用 `Vector2(w,h)`、`set_grid_size(w,h)` 传两参、UV 平铺按宽高各算、`grid_size` 取 `maxf(w,h)` 兼容旧 @export。
5. `_apply_default_scene` / `_switch_to_scene` 所有 `scene_size` 单值改 `scene_width`/`scene_height`；`_switch_to_scene` 读回加**老存档兼容**：有 `scene_width` 读新字段，没有则退回 `scene_size` 当正方形（宽=高=老值），老存档不坏。
6. 左栏输入框 UI 从单个"场景大小"改成"宽"+"高"两个 SpinBox（5–500，步进5）。
7. 补全 `_place_model` 被截断的尾巴：`_scene_dirty=true` + `_clear_all_model_selections()` + 工具提示。
8. 补回 `func _reset_all_transforms(node)` 定义：递归把子树 Node3D 的 position/rotation 清0、scale 设 ONE（不缩放，保留 glb 真实尺寸，2026-07-14 改的延续）。

### 踩坑（写文件两次末尾被截断）
- 第一次用 Python 补 `_place_model` 尾巴 + `_reset_all_transforms`，写回报告 93196 字节，但之后文件末尾又停在半截（`_tool_label.add_theme_color_override("font_co`），定义又丢了。疑 `filesystem_manage(op=reimport)` 重扫时把文件末尾搞截。
- 第二次同样手法补，落盘 94349 字节完整。
- **教训**：写 GDScript 大文件后必须 `tail -c 20 | xxd` 验末尾完整 + `grep func 定义` 验关键函数在 + utf-8 合法性，不能信写回报告的字节数。

### 验真（game_eval 实证，非靠编辑器无报错）
- `script_manage(op=find_symbols)` 返回完整 90 函数符号表（含 `_on_scene_width_changed`/`_on_scene_height_changed`/`_apply_scene_size`/`_place_model`/`_reset_all_transforms`）→ 编辑器对新版解析通过。
- `project_run` 跑游戏：helper_live=true/status=live；`recent_errors_may_predate_run=true` 标明那 4 条 parse error 是**跑前留存的旧错**。
- `game_manage(op=get_scene_tree)` 运行态树：SceneRoot/ContentRoot/Camera3D/Ground/GridManager/GridOverlay/SharedGizmo/UI_Layer/ItemPanel/PropPanel 全在 → **main.gd _ready 完整跑到底**（脚本加载失败这些节点一个不会建）。
- `game_eval` 实测真值：`ground_size=(100.0,100.0)`、`has_w_input=true`/`has_h_input=true`、`w_val=100`/`h_val=100`、`scene_width_prop=100`/`scene_height_prop=100`、`grid_w=100`/`grid_h=100` → **宽高改造全链路运行态跑通**。

### 编辑器脏缓存残留（认"编辑器报错、实跑正常"）
- `logs_read(source=editor)` 仍显示那 4 条旧 parse error（行号386/1893/1934 对应旧版内容），但同一批日志里 main.gd 929/1097/1524 行报的是 **warning**（UNUSED_PARAMETER/SHADOWED_VARIABLE，新版本行号）→ 编辑器同时在 parse 旧缓存实例（报 parse error）和新磁盘脚本（只报 warning，通过）。
- `filesystem_manage(op=scan)` + `script_patch` 触发 reload 都没清掉旧缓存实例的报错。
- 按 CLAUDE.md 规矩：温和办法试过 + 不准断链（editor_reload_plugin），认"编辑器报错、实跑正常"，**留待用户下次重启 Godot 编辑器清缓存**（关掉重开 Godot，不断 MCP）。

### 未做 / 待用户确认
- ⚠️ 未让用户手动实操认体感：左栏宽/高两个输入框改值后地面/网格是否真跟着变长方形（game_eval 只验了默认100×100，没验改值）。
- ⚠️ 编辑器 Errors 面板仍显示旧 parse error 红字（脏缓存），实跑无影响，待重启 Godot 编辑器清。
- 未跑 gdstyle lint。


## 2026-07-15 默认贴图铺满拉伸 + 换默认贴图

### 需求
用户：默认贴图要一直占满整个场景，不管场景是不是长方形、大小怎么变，贴图都跟着拉伸铺满（不重复）；顺便换一张默认贴图（用户放桌面 Gvtt 文件夹里了）。

### 换默认贴图
- 用户桌面 `C:\Users\Admin\Desktop\Gvtt\UV_Checker_4096x4096 (2).png`（4096×4096 RGBA）。AskUserQuestion 确认候选三张（UV检测图(2)/汽车生成图/砾石PBR）后用户选 UV 检测图(2)。
- 复制进 `assets/textures/ground/uv_checker_4096_v2/uv_checker_4096_v2.png`（按项目规矩一个纹理一个子文件夹、英文名避免括号空格）。`_scan_texture_folder` 单文件当 albedo 整张贴图。
- 常量 `DEFAULT_GROUND_TEX_BASE` 从 `uv_checker_4096` → `uv_checker_4096_v2`。

### 铺满拉伸模式（核心改动）
**旧问题**：UV 算 `1.0/ground_tile_size*尺寸`，ground_tile_size=一张图覆盖多少米。场景 100m+tile=100 正好一张铺满；但场景变 150m 时 UV=1.5，贴图**重复 1.5 次**不是拉伸铺满。
**用户要的**：默认贴图永远一张铺满整个地面，场景变长方形/改大小贴图跟着拉伸。
**设计取舍**：只给默认贴图开"铺满模式"，其他纹理（砾石 PBR 等）保持按 ground_tile_size 格数重复铺——因为真实材质按真实尺寸重复才有意义，硬拉伸成一张铺满 100m 会糊。
**实现**：
- 新增 `_ground_uv_scale(base,w,h,tile)`：base==DEFAULT_GROUND_TEX_BASE 时返回 `Vector3(w,h,1)`（一张图=整个地面）；否则 `Vector3(1/tile*w,1/tile*h,1)`（按格数重复）。依据 gdd_0407 StandardMaterial3D.uv1_scale（UV 坐标乘数，scale=尺寸时整张贴图映射到 [0,尺寸]=整个 PlaneMesh）。
- `_apply_scene_size` 和 `_apply_ground_texture` 两处 UV 都改调 `_ground_uv_scale`（统一逻辑，改尺寸/换纹理两条路径都不打架）。`_apply_ground_texture` 原来用 grid_size 整数算 UV，改从 `_current_scene_width/height()` 读真实宽高（铺满模式要真实尺寸）。
- `_on_ground_clicked`：点默认贴图时判 `base==DEFAULT_GROUND_TEX_BASE`（不再写死 "uv_checker_4096"），铺满模式 ground_tile_size 存 0 占位、**平铺控件藏掉**（铺满模式调平铺没意义）；其他纹理 tile=5、显示平铺控件。
- `_apply_ground_texture_for_scene`：平铺控件可见性改 `(base != "" and base != DEFAULT_GROUND_TEX_BASE)`（默认贴图也藏）。
- `_apply_default_scene`：默认场景存 ground_tile=0（占位，铺满模式不参与 UV）。

### 老存档兼容
老存档 ground_tex_base 可能是旧 `uv_checker_4096`，读回后 base != 新 DEFAULT，走重复模式（tile=100 时 1/100*100=1 正好一张铺满 100m，视觉等同铺满），不破坏。新场景才用新默认贴图铺满模式。

### 验真（game_eval 实测）
- 新贴图扫到：`ground_bases=[stone_floor,uv_checker,uv_checker_4096,uv_checker_4096_v2]`、`has_v2=true`、`active_base=uv_checker_4096_v2`、`active_has_albedo=true`。
- 铺满模式默认：`uv_scale=(100,100,1)` + `ground_mesh_size=(100,100)` → UV=场景尺寸，一张铺满。
- `sp_base=uv_checker_4096_v2`/`sp_tile=0`/`sp_w=100`/`sp_h=100`、`tile_ctrl_visible=false`（平铺控件藏）。
- **改尺寸拉伸验真（第一版，结论错误，见下条订正）**：`call("_apply_scene_size",150,60)` 后 `uv_after=(150,60,1)`，当时误判为"铺满"。实际是重复——见下条。

### 未做 / 待用户确认
- ⚠️ 未让用户手动实操认体感：肉眼看默认贴图是否真铺满（game_eval 只验了 UV 数值=场景尺寸，没法看画面）；改宽高输入框后贴图拉伸的视觉效果待用户跑游戏认。
- 编辑器脏缓存旧 parse error 残留仍在（同上条，实跑无影响，待重启 Godot 编辑器清）。

### 2026-07-15 订正：铺满模式 UV 方向搞反了（重复→铺满）
**用户反馈**："没有做到啊，现在是重复不是拉伸"。用户对。
**真根因**：`_ground_uv_scale` 铺满模式返回 `Vector3(w,h,1)` 是**反的**。查离线文档 gdd_0864 BaseMaterial3D.uv1_scale 原文："How much to scale the UV coordinates. This is multiplied by UV"——是 UV 坐标的**乘数**。PlaneMesh 默认 UV 范围 [0,1]（整张贴图映射整个平面）。`uv1_scale=(100,100)` → UV 变 [0,100] → 贴图在 0..1 区间**重复 100 次**，不是铺满一张。我上一版凭感觉写成 (w,h) 把方向搞反了，game_eval 看到 uv=(150,60) 误判"铺满"，实际是重复 150×60 次。
**正确逻辑**：一张铺满 = `uv1_scale=(1,1,1)`，UV 保持 [0,1]，整张贴图映射整个 PlaneMesh。PlaneMesh 的 size 改了但 UV 范围仍是 [0,1] 映射整个 mesh，所以**贴图自动跟着 PlaneMesh 拉伸铺满，UV 缩放恒为 (1,1) 不用动场景尺寸**。重复模式（其他纹理）不变，仍是 `1/tile*size`。
**修法**：`_ground_uv_scale` 铺满分支 `return Vector3(w,h,1.0)` → `return Vector3(1.0,1.0,1.0)`，加注释记文档依据和"此前搞反"教训。
**验真（game_eval 重跑新代码）**：默认 100×100 `uv1_scale=(1,1,1)`；改 150×60 后 `mesh_after=(150,60)`、`uv_after=(1,1,1)`、贴图仍 4096×4096 整张 → 一张贴图映射整个 150×60 PlaneMesh，跟着拉伸铺满，不重复。✅
**教训**：①uv1_scale 是 UV 乘数不是"贴图覆盖米数"，UV=(1,1) 才是一张铺满；②game_eval 只看数值不看画面，UV=(150,60) 我没核对语义就判"铺满"是错的，数值对但理解错——下次改 UV/材质参数必须先查文档确认语义再判结果。



## 2026-07-15 Codex 项目迁移到桌面 GVTT

### 已完成
- [x] 将 `C:\Users\Admin\Claude\Projects\Gvtt` 合并复制到 `C:\Users\Admin\Desktop\GVTT`。
- [x] 保留桌面 `GVTT` 里原有素材文件，没有删除或清空。
- [x] 确认 `docs/CODEX_HANDOFF.md`、`.claude/CLAUDE.md`、`.codex/settings.json` 已复制到位。
- [x] 将交接文档里的项目路径更新为桌面新路径。

### 说明
- `robocopy` 返回码 `1` 表示复制成功且有新增文件，并非失败。
- 当前 Codex 会话的默认工作区仍显示为 `C:\Users\Admin\Documents\Gvtt`；后续最好从桌面 `GVTT` 文件夹重新打开 Codex，避免每次访问项目都需要额外授权。


## 2026-07-15 Codex 首轮环境体检

### 已完成
- [x] 读取 `docs/CODEX_HANDOFF.md` 和 `.claude/CLAUDE.md`，确认项目协作规矩与桌面目标路径。
- [x] 确认 Codex 已加载 Godot MCP 工具，`session_activate("Gvtt")` 成功连接到 `gvtt@5d0f`。
- [x] 确认 Godot MCP 会话版本：Godot 4.7-stable，Godot AI 插件/服务版本 2.9.1。
- [x] 确认编辑器当前场景是 `res://scenes/main.tscn`，场景树骨架与磁盘 `scenes/main.tscn` 一致。
- [x] 运行当前会话主场景做烟测：`helper_live=true`，运行态树生成 `SceneRoot`、`GridManager`、`UI_Layer`、`SharedGizmo` 等节点，说明当前会话主场景可启动。
- [x] 烟测后已停止运行，编辑器回到 ready 状态。

### 发现的问题
| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-15 | Godot 编辑器当前打开路径是 `C:/Users/Admin/Claude/Projects/Gvtt/`，不是目标桌面路径 `C:/Users/Admin/Desktop/GVTT/`。两个目录当前 `scripts/main.gd` SHA256 一致，但后续必须从桌面项目重新打开 Godot，避免继续改旧目录。 | 待用户重开 Godot 到桌面项目 |
| 2026-07-15 | 编辑器 Errors 面板仍显示 `main.gd:1987` 的旧解析红字，但磁盘 `main.gd` 只有 1675 行，且运行态可 live，判断为旧缓存/旧错误面板残留，不能当作当前磁盘代码行号。 | 待重启 Godot 编辑器清缓存 |
| 2026-07-15 | 本次运行日志没有红色运行错误，但有多条黄色警告：贴图通过 `Image.load_from_file` 加载，Godot 提示导出单 exe 时不可用，需要后续改成导入资源加载方式。 | 后续导出前处理 |
| 2026-07-15 | `docs/CCxGodot.md` 存在但文件长度为 0，信息核查时不能提供有效内容。 | 记录在案 |

### 复查（用户重新打开 Godot 后）
- [x] 2026-07-15 复查 Codex 侧 Godot MCP：工具已加载，连接到新会话 `gvtt@83d0`。
- [x] 复查主场景：编辑器当前场景仍是 `res://scenes/main.tscn`，骨架节点 `Main/Camera3D/DirectionalLight3D/WorldEnvironment/CameraPivot/Ground` 齐全。
- [x] 复查运行：`project_run(mode=main, autosave=false)` 成功，`helper_live=true`，运行态树生成 `SceneRoot`、`ContentRoot`、`GridManager`、`UI_Layer`、`SharedGizmo` 等节点。
- [x] 复查日志：本次启动没有红色解析错误，旧 `main.gd:1987 mp` 红字已消失；仍有贴图 `Image.load_from_file` 导出风险黄字。
- [ ] 路径问题未解决：MCP 会话仍报告 `project_path=C:/Users/Admin/Claude/Projects/Gvtt/`，不是桌面 `C:/Users/Admin/Desktop/Gvtt/`。后续不要在确认路径前做功能修改。

### 复查（用户确认重新打开桌面 Godot 工程后）
- [x] 2026-07-15 再次复查 Godot MCP：当前唯一会话为 `gvtt@dc78`，`project_path=C:/Users/Admin/Desktop/Gvtt/`，路径问题已纠正。
- [x] 当前场景为 `res://scenes/main.tscn`，编辑器场景骨架 `Main/Camera3D/DirectionalLight3D/WorldEnvironment/CameraPivot/Ground` 齐全。
- [x] 主场景烟测通过：`project_run(mode=main, autosave=false)` 成功，`helper_live=true`，运行态树生成 `SceneRoot`、`ContentRoot`、`GridManager`、`UI_Layer`、`SharedGizmo` 等节点。
- [x] 运行结束后已停止项目，编辑器回到 ready 状态。
- [ ] 当前无红色解析/运行错误；仍有黄色警告待后续整理：`module_io.gd/module_gate.gd/main.gd` 的变量遮蔽/未使用参数/三元表达式类型提示，以及贴图 `Image.load_from_file` 导出风险。


## 2026-07-15 Codex 拖动放置 + 墙面吸附

### 已完成
- [x] 实现左键按住模型资产按钮开始拖动：模型按钮接 `button_down`，记录当前栏位和资产索引。
- [x] 实现拖到地图区域松开左键放置：松手在左栏/属性栏内只取消拖动，松手在地图上调用放置逻辑。
- [x] 保留旧交互：单击资产按钮仍可选中，再点击地图放置。
- [x] 给 `EntityProperties` 增加 `category` 导出字段，放置时写入 `token/terrain/wall/decor/interactable/light`，后续保存场景能记住物件类别。
- [x] 给交互物体增加墙面吸附：放置 `interactable` 时先用鼠标射线查拾取层里的墙体，命中墙体则贴到命中点并沿墙面法线偏出 0.05，射不中才落到地面。
- [x] 依据核查：按钮按下信号查 `gdd_0532_BaseButton.md`；屏幕到 3D 射线和 `intersect_ray` 查 `gdd_0255_Ray-casting.md`、`gdd_1407_PhysicsRayQueryParameters3D.md`；物件朝向查 `gdd_0673_Node3D.md`。

### 验证
- [x] `script_manage(find_symbols)` 解析 `scripts/main.gd` 成功，看到 `_on_model_drag_started`、`_finish_model_drag`、`_get_model_drop`、`_raycast_wall` 等新函数。
- [x] `script_manage(find_symbols)` 解析 `scripts/entity_properties.gd` 成功，看到新增导出字段 `category`。
- [x] `logs_read(source=editor)` 未出现本次新增代码造成的红色解析错误；仅有既有黄色警告（变量遮蔽/未使用参数/贴图导出风险/owner 提醒）。
- [ ] 未完成运行态手感验证：当前 Godot 状态矛盾，编辑器显示 `is_playing=true`，但 `helper_live=false/status=stopped`，不能安全用 `game_eval` 验证拖放手感；按项目规矩没有使用会断链或强停的手段。
- [ ] 未跑 `gdstyle` 命令行检查：`addons/gdstyle/` 只有编辑器插件和动态库，未找到交接文档提到的 CLI 可执行文件。

### 新问题
| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-15 | 当前 Godot 编辑器状态矛盾：`is_playing=true`，但运行助手 `helper_live=false/status=stopped`。编辑器写入会被拒绝，运行态 `game_eval` 不能验证。 | 待用户在 Godot 里手动停止/重新运行主场景后复测 |
| 2026-07-15 | `addons/gdstyle/` 未发现 CLI 可执行文件，只有插件文件和动态库；交接文档中的 `addons/gdstyle/gdstyle` 路径不成立。 | 待后续确认 gdstyle CLI 安装位置 |


## 2026-07-15 Codex 拖动实时预览补强

### 已完成
- [x] 针对用户反馈“拖出来后看不到物体，拖动没意义”，补上拖动过程中的实时 3D 预览。
- [x] 左键按住资产按钮时创建临时 `DragPreview` 节点，放在 `SceneRoot` 下，不设置 owner，不会保存进场景文件。
- [x] 鼠标移动时持续调用同一套落点计算：普通物体投到地面，交互物体仍走墙面吸附检测；预览会跟着当前位置更新。
- [x] 预览使用实际模型实例，设置半透明并关闭阴影，避免和松手后生成的正式物体混淆。
- [x] 松手放置时仍重新加载正式模型实例，避免把半透明/临时状态带进保存内容。

### 验证
- [x] `script_manage(find_symbols)` 解析 `scripts/main.gd` 成功，确认 `_create_drag_preview`、`_update_drag_preview`、`_clear_drag_preview` 等函数已被 Godot 识别。
- [x] `script_manage(find_symbols)` 解析 `scripts/entity_properties.gd` 成功，确认 `category` 字段已被 Godot 识别。
- [x] `project_run(mode=main, autosave=false)` 成功，`helper_live=true`，运行助手可用。
- [x] 运行态调用拖动开始逻辑后，确认 `DragPreview` 已创建且 `visible=true`。
- [x] 鼠标从地图中心附近移动到另一处后，`DragPreview.position` 从 `(-1.35, 0.0, -0.22)` 变为 `(19.47, 0.0, 13.04)`，确认预览会实时跟随鼠标更新。
- [ ] 松手生成正式物体未完成自动化验证：最后一次 `input_mouse` 松手事件被 MCP 工具层限流拒绝（429 Too Many Requests），按项目规矩没有继续绕路模拟同一操作；待用户手动拖拽确认手感。

### 新问题
| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-15 | Godot MCP 工具在本轮末尾出现 429 Too Many Requests，导致无法继续用自动化输入验证松手放置阶段。 | 待稍后/下轮恢复后复测，或由用户手动拖拽确认 |
## 2026-07-15 Codex 拖放反馈提速

### 已完成
- [x] 针对用户反馈“拖出去约半秒才显示模型、快操作时松手没有东西”，把拖动开始阶段改成先创建轻量 `DragPreviewPlaceholder` 占位预览，不再把真实模型加载卡在鼠标按下第一拍。
- [x] 真实模型预览改为下一帧延迟加载：如果拖动仍然有效，就替换占位预览；如果用户已经快速松手，则直接放弃预览加载，避免旧协程回头创建脏预览。
- [x] 快速松手放置不依赖预览是否加载完成，仍使用记录的 `category/index` 和当前鼠标落点调用正式放置逻辑。
- [x] `script_manage(find_symbols)` 已识别新增/修改函数：`_create_drag_preview_placeholder`、`_load_drag_preview_deferred`、`_create_drag_preview_model` 等。
- [x] `project_run(mode=main, autosave=false)` 启动成功，`helper_live=true`。
- [x] 运行态验证：拖动开始后立刻存在 `DragPreview` 与 `DragPreviewPlaceholder` 且可见。
- [x] 运行态验证：下一帧真实模型可替换占位预览，取消拖动后临时节点清理。
- [x] 运行态验证：模拟“开始拖动后立刻松手”，`ContentRoot` 子节点数从 0 增至 1，说明正式物体已放置；下一帧 `DragPreview` 已清除。

### 未做 / 待确认
- [ ] 真人手动拖放体感仍需用户在 Godot 窗口里确认：自动化验证证明链路可用，但鼠标真实手感以用户操作为准。
- [ ] `git update-index --chmod=+x scripts/main.gd` 试图恢复 Windows 下被补丁工具改变的 Git 可执行位，但当前沙箱不能写 `.git/objects`，所以没有完成；功能代码不受影响。

### 新问题
| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-15 | 沙箱只能读 `.git`，无法写 Git 索引，导致无法恢复 `scripts/main.gd` 的 Git 文件模式元数据。 | 待需要提交时在有 Git 写权限的环境处理 |

## 2026-07-15 Codex 按 Godot 拖放思路改为轻预览

### 已完成
- [x] 复查 Godot 拖放思路：拖放预览应是轻量预览与数据载荷，不应在拖动第一时间加载重资源。
- [x] 删除拖动下一帧加载真实模型预览的逻辑，拖动过程中只保留 `DragPreviewPlaceholder` 占位预览。
- [x] 正式模型加载只发生在松手放置阶段，避免拖出时半秒卡顿。
- [x] `script_manage(find_symbols)` 验证 `scripts/main.gd` 解析通过，相关真实预览加载函数已移除。
- [x] 运行态验证：开始拖动后 `DragPreview` 只有 1 个 `DragPreviewPlaceholder` 子节点；过一帧仍然只有占位预览，确认拖动中不再加载真实模型。
- [x] 运行态验证：模拟快速松手仍可生成正式物体，临时预览下一帧清除。

### 取舍
- [ ] 当前拖动时显示的是轻量占位体，不是完整模型。要拖动时显示真实模型，需要做素材预缓存或缩略代理模型，不能再在拖动开始时同步加载 GLB/FBX。

## 2026-07-16 Codex 协作规则补充

### 已完成
- [x] 在 `AGENTS.md` 的“功能实现”段落补充规则：无论创造、修补、优化、调手感，都必须先查 Godot 自身、开源软件和社区成熟做法，不能因为是 bug 修补或小体验优化就跳过调研。

### 背景
- [x] 本次规则补充来自拖放预览优化复盘：先前只做局部补丁，没有第一时间对照 Godot 原生拖放思路，导致同类问题绕了一圈才修到本质。

## 2026-07-16 Codex P0/P1 状态核查

### 结论
- [x] P0 按 `docs/design.md` 与 `devlog/DEVLOG.md` 记录均可判定完成：正交相机、倾斜视角、缩放/平移、网格地面、光源、阴影、天空照明、`main.tscn/main.gd` 已落地。
- [x] P1 已由 2026-07-16 收口验收改判完成：编辑/运行切换、地面纹理、物件栏位/导入/拖放、属性标记、保存/加载主体链路均已落地并通过本轮自动验收；真人体感、导出前贴图加载整理、命令行 lint 工具缺位不再阻塞 P1。

### 核查依据
- [x] `docs/design.md` P0 明确标为 2026-07-04 已完成；P1 清单包含编辑/运行切换、地面纹理替换、物件系统、物件属性标记、场景保存/加载。
- [x] `devlog/DEVLOG.md` 后续记录显示物件拖放、轻预览、导入栏位、场景保存/加载闭环已有运行态验证，但部分条目仍写“待用户手动确认”。
- [x] `project.godot` 已注册 `ModeGate` autoload；`scripts/main.gd` 有 `_build_model_section`、`_on_model_drag_started`、`_place_model`、`_on_save_scene_pressed`、`_switch_to_scene` 等 P1 关键实现。

## 2026-07-16 Codex P1 收口验收

### 已完成
- [x] P1 正式收口：按 `docs/design.md` 的 P1 清单，编辑/运行切换、地面纹理替换、物件系统、物件属性标记、场景保存/加载均已有实现与验证依据。
- [x] Godot 解析验收：`scripts/main.gd` 与 `scripts/entity_properties.gd` 均可被 `script_manage(find_symbols)` 正常解析。
- [x] 运行态烟测：`project_run(mode=main, autosave=false)` 成功，`helper_live=true`，无本轮启动错误。
- [x] 栏位验收：运行态确认模型分类齐全 `decor/interactable/light/terrain/token/wall`，地面纹理按钮存在，场景按钮存在，当前为编辑态。
- [x] 拖放验收：模拟拖放时 `DragPreviewPlaceholder` 出现，松手后正式物体生成，且带 `EntityProperties`、`PickProxy`，`category` 写入正确。
- [x] 保存入口验收：运行态调用 `_on_save_scene_pressed()` 成功，当前场景 `场景1` 内容层存在已放置物件。

### 非阻塞后续
- [ ] 真人体感确认仍建议做，但不再作为 P1 完成阻塞项。
- [ ] `addons/gdstyle/bin` 只有 Godot 扩展动态库，没有命令行可执行文件；因此 `gdstyle lint` 暂按工具缺位处理，不阻塞 P1。
- [ ] 贴图 `Image.load_from_file` 的单 exe 导出风险归入导出前整理，不阻塞 P1 功能闭环。
- [ ] Token 运行态拖拽、LOS、墙体破坏、特效、场景气氛、层级切换继续留在 P2-P4。

## 2026-07-16 Codex 按 Godot 编辑器方式恢复真实模型拖放预览

### 已完成
- [x] 接用户严肃要求：拖放必须按 Godot 编辑器体感实现，按住资产拖进 3D 窗口时立刻显示真实模型，而不是小方块占位。
- [x] 重新核对依据：Godot `Control.set_drag_preview()` 是自定义预览；`ResourceLoader.load_threaded_request/load_threaded_get_status/load_threaded_get` 支持后台准备资源；`GLTFDocument/GLTFState` 支持运行时把 GLB/glTF 解析成 Godot 场景。
- [x] `scripts/main.gd` 新增模型预热缓存：自带 `res://` 模型用 `PackedScene` 缓存和后台加载；导入 `user://` GLB/glTF/FBX 缓存已解析的 `GLTFState/FBXState`。
- [x] 左栏模型按钮刷新、导入成功、删除素材时同步维护缓存。拖动开始不再创建 `DragPreviewPlaceholder`，而是从缓存生成真实模型实例挂到 `DragPreview`。
- [x] 正式放置也优先复用同一缓存生成模型，仍保留原有 `EntityProperties`、`PickProxy`、分类写入、墙面吸附和保存链路。

### 验证
- [x] `script_manage(find_symbols)` 解析 `res://scripts/main.gd` 成功，识别 `_warm_model_cache_for_path`、`_poll_model_cache_requests`、`_create_drag_preview_model`、`_instantiate_imported_model` 等函数。
- [x] 运行态验证：`project_run(mode=main, autosave=false)` 成功，`helper_live=true`。
- [x] 运行态验证：开始拖动第一个可用资产后，`DragPreview` 的子节点是 `网行者test:Node3D`，`has_placeholder=false`，不是小方块。
- [x] 运行态验证：缓存状态 `import_cache_ready=2`、`scene_cache_ready=4`、`thread_pending=0`，说明拖动时资源已准备好。
- [x] 运行态验证：调用 `_finish_model_drag()` 后 `ContentRoot` 生成正式物体，且带 `EntityProperties`、`PickProxy`，`category=token`。
- [x] 日志复查：此前导入模型 Node 模板 `duplicate()` 触发的 `!is_inside_tree()` 红错已消失。最后一轮只剩既有黄色警告：变量遮蔽/未用参数/三元类型提示、地面贴图 `Image.load_from_file` 导出风险。

### 待确认
- [ ] 真人手动体感仍需用户在 Godot 窗口里拖一次确认：自动化已验证节点和链路，但鼠标实际手感以用户操作为准。

## 2026-07-16 Codex 强化 Godot 源码优先规则

### 已完成
- [x] 根据用户追问“为什么又没有按照 GD 原来的代码参考”，承认此前规则仍不够硬：只写了三层搜索，但没有写死“拿不到 Godot 源码就停”。
- [x] 更新 `AGENTS.md` 的“功能实现”段落：涉 Godot/GD 既有行为时，必须先拿到 Godot 引擎源码的具体文件、类/函数名和关键逻辑摘要，再设计实现。
- [x] 明确禁止把“行为相似”说成“参考了 Godot”。只有读过 Godot 源码并能指出来源文件/函数，才允许说“按 Godot/GD 做法”。
- [x] 要求任务完成报告和 `devlog/DEVLOG.md` 记录 Godot 源码来源、采用思路、未采用内容及原因；没有这段记录不能判定功能完成。

### 新问题
| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-16 | 当前真实模型拖放预览实现已按 Godot 编辑器体感和官方 API 改完，但尚未补齐 Godot 引擎源码对照，不能严谨称为“按 Godot 源码实现”。 | 待后续补源码对照审查 |

## 2026-07-16 Codex 迁移后变更清单

### 已完成
- [x] 新增 `docs/codex_migration_change_list.md`，给以后切回 Claude Code 时识别 Codex 迁移后文件变化使用。
- [x] 清单区分了“明确 Codex 新增/修改”的文件和“Git 状态里可能只是权限位或迁移噪音”的文件，避免把大量 `mode change 100755 => 100644` 误判成功能改动。
- [x] 明确记录 `AGENTS.md` 不是 `.claude/CLAUDE.md` 的完全平替；切回 Claude Code 时应把 Codex 新增硬规则同步回 `.claude/CLAUDE.md`。

### 待后续
- [ ] 切回 Claude Code 前，建议让 CC 先读 `docs/codex_migration_change_list.md`、`AGENTS.md`、`devlog/DEVLOG.md` 的 2026-07-15/16 Codex 段落，再处理 Git 状态。

## 2026-07-16 Codex 拖放导入模型修复

### 已完成
- [x] 修复导入 GLB 模型拖不出来的问题：`scripts/main.gd` 不再缓存复用 `GLTFState/FBXState`，改为导入时生成一次正常运行时节点并打包为内存 `PackedScene`，拖动预览和正式放置都从该缓存实例化。
- [x] 修复鼠标和物体错位的主要原因：加载模型后计算可见 `VisualInstance3D.get_aabb()` 总边界，把模型水平中心对齐到放置根节点，并让底部贴到 `y=0`；建筑、网行者、汽车现在几何中心 `x=0,z=0`，底部 `min_y=0`。
- [x] 保留导入模型兜底：如果缓存打包失败，仍调用 `LibraryManager.load_model_runtime()` 现场加载，避免特殊模型完全不可用。

### Godot 源码 / 文档依据
- [x] Godot 引擎源码：`editor/scene/3d/node_3d_editor_viewport.cpp`。关键点：`can_drop_data_fw()` 在确认可拖文件的第一帧调用 `_create_preview_node(files)` 创建真实预览；`drop_data_fw()` 保存 `drop_pos = p_point` 后执行放置；`update_transform()` 使用视窗鼠标点转射线（`get_ray_pos/get_ray`），与本项目 `Camera3D.project_ray_origin/project_ray_normal` 的做法一致。
- [x] 离线文档：`gdd_1006_PackedScene.md` 确认 `PackedScene.pack()` 只打包被 root 拥有的子节点、`instantiate()` 可重复实例化；`gdd_0929_GLTFDocument.md` 确认 `append_from_file()` 和 `generate_scene()` 的运行时加载流程；`gdd_0780_VisualInstance3D.md` 与 `gdd_1551_AABB.md` 确认可见节点边界框和 `AABB.position/size/get_endpoint()`。

### 验证
- [x] `script_manage(find_symbols)` 解析 `res://scripts/main.gd` 成功，识别 `_pack_imported_model_for_cache`、`_prepare_model_instance`、`_align_model_to_drop_origin`、`_get_model_local_bounds`。
- [x] 运行态验证：网行者 `user://library/token/网行者test.glb` 和汽车 `user://library/terrain/破损汽车3d模型.glb` 现在实例化后子节点均为 `MeshInstance3D`，`visual_count=1`，缓存为 `PackedScene`。
- [x] 运行态验证：网行者、汽车、内置建筑拖动预览均存在、可见，且正式放置后均有 `EntityProperties.category` 和可见模型。
- [x] 日志复查：没有本次新增红字；仍有既有警告（地面贴图 `Image.load_from_file` 导出风险、未用参数/变量遮蔽/三元类型提示），不属于本次拖放修复。

### 待用户手测
- [ ] 请在 Godot 窗口里手动从左栏拖一次网行者、汽车、内置建筑到 3D 地图，确认真实鼠标手感是否已经贴住光标。

## 2026-07-16 Codex 拖放错位与快拖丢失修复

### 已完成
- [x] 修复拖放坐标滞后：`scripts/main.gd` 不再在拖拽移动/松手时重新读取 `get_viewport().get_mouse_position()`，改为使用本次 `InputEventMouseMotion.position` / `InputEventMouseButton.position`，并把该点一路传给预览更新、最终放置和 `_get_model_drop()`。
- [x] 保留普通点击放置兼容：非拖拽点击仍可不传鼠标点，`_get_model_drop()` 用 `Vector2.INF` 作为默认哨兵，回退到当前视口鼠标位置。
- [x] 运行态验证：网行者、破损汽车、自带建筑三类均通过自动拖放测试；预览位置和最终放置位置回投屏幕坐标均等于传入事件点。

### Godot 源码 / 文档依据
- [x] Godot 引擎源码依据沿用并收窄到拖放坐标链路：`editor/scene/3d/node_3d_editor_viewport.cpp` 中拖放回调使用传入的视窗点 `p_point`，预览和落点更新不依赖另行轮询全局鼠标。
- [x] 离线文档：`gdd_0255_Ray-casting.md` 确认 `Camera3D.project_ray_origin/project_ray_normal` 用屏幕点生成射线；`gdd_0540_Camera3D.md` 确认两个 API 签名；`gdd_1582_Vector2.md` 与 `gdd_1591_@GlobalScope.md` 确认 `Vector2.INF` 和 `is_finite()` 可用。

### 验证
- [x] `project_run(mode=main, autosave=false)` 成功，`helper_live=true`。
- [x] 快拖验证：只调用拖拽开始后直接松手，不经过 motion 更新，物体仍按松手事件点放置。
- [x] 分类验证：`token/网行者test.glb`、`terrain/破损汽车3d模型.glb`、`decor/CP Building_001.fbx` 的预览和最终物体屏幕坐标均与事件点一致。
- [x] 日志复查：无本次新增红字；仍有既有 `Image.load_from_file` 导出警告和旧的未用参数/变量遮蔽/三元类型提示。

### 待用户手测
- [ ] 请手动快速拖出网行者、汽车、内置建筑各一次，重点看“刚出左栏是否立刻贴鼠标”和“松手后是否落在鼠标点”。

## 2026-07-16 Codex 地图模式网格遮挡模型修复

### 已完成
- [x] 修复地图模式下网格线盖住模型的问题：`shaders/grid_line.gdshader` 移除 `depth_test_disabled`，让当前 `GridManager/GridOverlay` 使用正常深度检测，模型在网格前方时会遮住网格线。
- [x] 同步修复旧备用网格 shader：`shaders/grid_shader.gdshader` 也移除 `depth_test_disabled`，避免以后切回旧 PlaneMesh 网格方案时同类问题复发。

### 依据
- [x] 当前实际网格来源：`scripts/grid_manager.gd` 中 `GridManager._ready()` 加载 `res://shaders/grid_line.gdshader`，`GridOverlay` 高度为 `y=0.03`，因此保留正常深度检测仍能压在地面上，但不会穿透模型。
- [x] Godot 4.7 离线文档依据：`gdd_0384_Spatial_shaders.md` 说明 `depth_test_disabled` 会关闭深度检测，`depth_test_default` 会丢弃位于其他像素后方的像素；`gdd_0864_BaseMaterial3D.md` 也说明关闭深度检测会按绘制顺序显示在其他对象上。
- [x] Godot 源码依据沿用此前网格重构记录：网格几何生成思路来自 Godot 引擎 `node_3d_editor_plugin.cpp::_init_grid()`；本次 bug 的直接原因不是几何生成，而是本项目 shader 渲染模式错误。

### 验证
- [x] 磁盘复查：两个 shader 的 `render_mode` 已不再包含 `depth_test_disabled`。
- [ ] 运行态视觉待用户手动确认：当前 Godot 编辑器状态显示 `is_playing=true` 但运行助手 `helper_live=false/status=stopped`，不能安全用 `game_eval` 做视觉闭环；未调用断链或强停工具。
## 2026-07-16 Codex CPR 规则资料阅读包

### 已完成
- [x] 确认首个运行模组方向为 CPR，并读取用户提供的两份资料：`个人资产/赛博朋克红2.50.14规则书精修版-高清版(1).pdf` 与 `个人资产/赛博装备图鉴.pdf`。
- [x] 抽样核查 PDF 结构：核心规则书 486 页、装备图鉴 31 页，均未加密且已有可抽取文字层，不是纯扫描图。
- [x] 生成 `docs/cpr_reading/` 阅读包：按页 Markdown、逐页 `pages.jsonl` 检索数据、本地 `reader.html` 搜索阅读页，以及工具判断记录。
- [x] 在阅读包中保留原 PDF 路径和页码链接；复杂表格、分栏、图标、勾选框和装饰标题以原 PDF 页面为最终校对依据，避免纯文本误判。
- [x] 查证 PDF 转文字/版面工具方向：Docling、Marker、olmOCR、OCRmyPDF/Tesseract、PaddleOCR，以及非开源常见工具 Adobe Acrobat、ABBYY FineReader；记录在 `docs/cpr_reading/tool_research.md`。

### 验证
- [x] `docs/cpr_reading/pages.jsonl` 共 517 行，匹配核心规则书 486 页 + 装备图鉴 31 页。
- [x] 搜索抽查成功：`夜之城装备图鉴`、`网行者`、`创伤小队医疗扫描`、`掩体` 均能命中对应资料页。
- [x] UTF-8 读取 `docs/cpr_reading/README.md` 正常；PowerShell 直接显示时中文乱码属于终端编码显示问题，不是文件损坏。

### 未完成 / 风险
- [ ] 尚未安装或运行 Docling/Marker/olmOCR 等重型版面模型；当前环境网络受限，且现有 PDF 已有文字层，所以先用本机可用工具完成第一版。
- [ ] 阅读包不是“排版无损复刻”；凡涉及图标、表格边框、复杂分栏和插图的页面，需要点击原 PDF 页码回看。
- [ ] 如后续要把规则拆成游戏内数据库或 GM 快查卡，需要再做人工分类、术语表和页码索引。

## 2026-07-16 Codex CPR 规则资料查阅模式补强

### 已完成
- [x] 根据用户指出“你好阅读的模式”不是给人看的 HTML，而是给 Codex 后续查具体规则用的资料形态，补充 `docs/cpr_reading/agent_index/`。
- [x] 新增 `tools/build_cpr_agent_reading_index.py`，从既有 `pages.jsonl` 生成更适合后续检索的分块资料。
- [x] 生成 `agent_chunks.jsonl`：按页切成 546 个小块，每块保留资料名、原 PDF 路径、页码、正文和 `needs_pdf_check` 状态。
- [x] 生成 `agent_keyword_index.json`：把 50 个常用 CPR/地图实现关键词映射到块 ID 和页码，例如伏击、掩体、网行者、创伤小队、赛博殖装、自动开火。
- [x] 生成 `agent_page_catalog.json` 和 `agent_readme.md`，用于后续快速判断每页是否需要回看原 PDF。
- [x] 在 `docs/cpr_reading/README.md` 中补充 `agent_index/`，明确 HTML 是人读入口，`agent_index/` 才是 Codex 查规则入口。

### 验证
- [x] `agent_chunks.jsonl` 共 546 块，首块为 `cyberpunk_red_core-p0001-c001`，末块为 `night_city_catalog-p0031-c001`。
- [x] 关键词抽查成功：`伏击`、`掩体`、`网行者`、`创伤小队`、`赛博殖装`、`自动开火` 都能返回资料名和页码。
- [x] 抽查 `掩体` 命中块可读取来源、页码、校对状态和正文片段。

### 未完成 / 风险
- [ ] 关键词表仍是第一版人工清单，后续做 CPR 快查或具体系统时需要继续扩充术语、同义词和英文术语。
- [ ] 分块索引用于查阅，不等于规则数据库；涉及表格、图标、分栏、页边注时仍须回看原 PDF。

## 2026-07-18 Codex CPR PDF 敌人立绘检查

### 已完成
- [x] 使用 `docs/cpr_reading/agent_index/agent_chunks.jsonl` 搜索敌人、敌对、怪物、NPC、帮派、佣兵、赛博精神病、黑冰、地狱猎犬等关键词，确认核心规则书有大量敌对单位/遭遇/黑冰文字内容。
- [x] 使用 `pdfplumber` 检查图片页：核心规则书 486 页中有 209 页含图片；`赛博装备图鉴.pdf` 未检测到嵌入位图图片页。
- [x] 渲染并目检核心规则书含图页缩略图，确认第 48-57 页有职业全身人物图，第 71 页有小头像组，后半本有多处场景/组织/冒险插图。

### 结论
- [x] PDF 里有可作为 CPR 人物/职业 Token 参考的立绘或头像，但没有“敌人图鉴式”的成套敌人立绘库。
- [x] 敌人/NPC 数据更多以文字、表格或遭遇描述出现，例如第 177 页是后备支援 NPC 数据，第 230/236 页是使魔/黑冰和防御系统，第 418 页是 GM 遭遇中使用敌人的建议；这些页不是立绘页。

### 未完成 / 风险
- [ ] 目前未从 PDF 中裁切图片作为项目资产；若要使用书内美术，需要先处理版权/授权边界，或改用自制/可商用素材。
- [ ] 若后续需要“敌人 Token 素材库”，需要另建素材来源或生成占位图，不能指望这两本 PDF 直接提供完整敌人立绘。

## 2026-07-16 Codex P2.2 战棋移动基础版

### 已完成
- [x] 通用 `TokenProperties` 与 CPR 规则字段拆分：新增 `CprTokenProperties.move_stat`，`ModuleManifest.ruleset_id` 默认 `cpr`，以后换规则集不改通用 Token schema。
- [x] 新增 `MovementRuleProvider` 与 `CprMovementRuleProvider`。CPR 基础移动预算为 `MOVE × 2` 米/码；困难、攀爬、跳跃、游泳按双倍耗费解释。
- [x] 新增可选 `TraversalProperties`：可走、阻挡、困难、攀爬、跳跃、游泳；地形默认可走，墙/装饰/交互物体默认阻挡。
- [x] 新增运行期 `MovementService`：独立导航图、同步烘焙、鼠标目标查询、绕障碍路线、绿/红路线预览、预算截断、地形高度贴合、胶囊体扫掠防穿模、松手沿路线移动。
- [x] `scripts/main.gd` 的旧平面直拖和 1 米吸附已停用；直接拖动自动固定起点，松手提交，不增加开始/结束按钮。
- [x] 编辑属性面板新增 CPR `MOVE` 数字框和通行标签下拉框；旧场景加载会自动补 `TokenProperties`、`CprTokenProperties`、`TraversalProperties`。
- [x] `snap_to_grid` 仅以 `@export_storage` 兼容旧场景，P2.2 不读取。
- [x] 核心文档写入规则资料门禁：规则实现必须先查 `docs/cpr_reading/agent_index/agent_chunks.jsonl`。

### CPR 依据
- [x] 核心规则书 PDF p.144（书内 p.126）：一次移动动作上限 `MOVE × 2` 米/码；网格为 MOVE 格、每格 2 米/码、允许斜向。
- [x] 核心规则书 PDF p.145（书内 p.127）：“跑”用其他动作换第二次移动动作；基础 P2.2 不自动赠送。
- [x] 核心规则书 PDF p.187（书内 p.169）：游泳、攀爬、助跑跳跃 1 米消耗 2 米移动距离。

### Godot 4.7 源码对照
- [x] `mesh_instance_3d.cpp::create_trimesh_collision_node()` + `mesh.cpp::Mesh::create_trimesh_shape()`：采用静态三角碰撞生成思路。
- [x] `godot_navigation_server_3d.cpp::parse_source_geometry_data()/bake_from_source_geometry_data()/query_path()` + `nav_mesh_generator_3d.cpp`：采用解析、烘焙和可复用查询对象链路。
- [x] `navigation_obstacle_3d.cpp::navmesh_parse_source_geometry()`：阻挡物只挖空，不把墙顶误作可走面。
- [x] `navigation_link_3d.cpp`：攀爬/跳跃使用带端点、方向和耗费的导航连接。
- [x] `shape_cast_3d.cpp::_update_shapecast_state()` + Jolt `cast_motion()`：提交前按 Token 胶囊体扫掠。
- [x] `nav_region_3d.cpp::_build_iteration()`：实测发现地图与区域各有独立异步迭代开关；改用独立导航图并同时关闭两层异步，修复“资源已有 16 个多边形但服务器区域边界仍为零”。
- [x] 没采用第三方路径显示插件：候选版本早、验证少或只适合编辑器静态路径；动态路线使用官方 `ImmediateMesh`。

### 验证
- [x] 运行回归 `P1_RUNTIME_RESULT`：85 项断言、0 失败；覆盖 MOVE 6=12 米、超距截断、攀爬双倍耗费、禁止移动、非 Token 拒绝、组件保存/读回、属性面板回写。
- [x] 真导航测试：起终点直线 8 米，中间放 2 米方箱；路线必须大于 8.1 米、到达墙后目标且终点贴地。
- [x] 编辑器测试：3 项通过、0 失败。
- [x] 主场景启动 `helper_live=true`，本轮游戏日志无红字/黄字；旧网行者运行态确认三类组件均已补挂。

### 未完成 / 风险
- [ ] 真人拖动手感和路线颜色仍需用户在可见窗口确认。
- [ ] 攀爬/跳跃连接点已有数据与运行期节点接口，普通属性面板尚未提供端点编辑工具，需在实际测试地形专题补。
- [ ] 困难/游泳区域当前按路线段中点识别；很小区域的精确边界切分后置。
- [x] 当时的固定 0.75 米导航半径风险已于 2026-07-17 解决：改为按 Token 半径/高度缓存独立导航图，并保留真实胶囊扫掠复核；见“Token 多体型导航与阻挡边界收口”。
- [ ] 运行态进入时同步烘焙；超大高面数地图的分块缓存需用真实场景性能数据再做。
- [ ] 交互物体的伤害、爆炸、燃烧效果只记入后置 schema，尚未实现自动伤害或规则效果。

### 新问题
| 日期 | 问题 | 状态 |
|------|------|------|
| 2026-07-16 | 攀爬/跳跃连接点缺普通 GM 编辑工具，当前只能通过组件数据配置。 | 后续地形连接编辑专题 |
| 2026-07-16 | 困难/游泳小区域使用路线段中点计费可能低估边界耗费。 | 后续精确区域计费 |

## 2026-07-16 Codex P2.2 默认范围、限时移动与朝向

### 已完成
- [x] `scripts/cpr_token_properties.gd` 将新建/补挂 CPR 组件的模板默认值从 `MOVE=6` 改为 `MOVE=5`，按既有 `MOVE × 2` 规则得到默认 10 米/码；已有存档中明确保存的 MOVE 不迁移、不覆盖。
- [x] `scripts/movement_service.gd` 在提交路线时统计实际三维路线长度；短路线保持基础 6 米/秒，长路线使用 `max(6, 路线长度 / 2秒)`，保证已提交路线最多播放 2 秒。
- [x] Token 移动前按当前水平路线段转向，本地 `+Z` 作为统一模型正面；忽略路线高度分量，因此坡地移动不会让 Token 前后倾斜。零长度路线不调用转向。
- [x] 路线结束时清空 Token/路线并把临时移动速度恢复为基础值，不把表现层速度写进 Token 或 CPR schema。

### Godot 4.7 源码对照
- [x] 源码标签 `4.7-stable`，本地源码包 `reference/godot-4.7-stable-full.zip.zip`。
- [x] 调用链：`scene/3d/node_3d.cpp::Node3D::look_at()/look_at_from_position()` → `core/math/basis.cpp::Basis::looking_at()` → `core/math/transform_3d.cpp::Transform3D::looking_at()`。
- [x] 采用：`use_model_front=true` 时本地 `+Z` 指向目标，`Node3D` 在旋转后保留原缩放；本地实现对应 `MovementService._face_movement_direction()`。
- [x] 未采用 `NavigationAgent3D`：现有 `MovementService` 已直接持有完整查询路线；未采用 Tween（补间动画）：多段绕障路线继续由现有逐帧 `move_toward()` 精确推进。2 秒封顶是 Gvtt 表现层要求，不写成 Godot 或 CPR 原规则。

### 验证
- [x] 运行回归 `P1_RUNTIME_RESULT`：最终 100 项断言、0 失败；新增覆盖默认 `MOVE=5` 直接换算 10 米预算、已保存 MOVE 不被模板默认值覆盖、6 米短程保持基础速度、20 米带 5 米高差路线 2 秒到达、本地 `+Z` 朝向、坡地保持直立、零长度不乱转和结束后速度复位。
- [x] 编辑器测试：3 项通过、0 失败，测试套件 `p1_editor_contracts`。
- [x] 主场景在 Godot `4.7-stable` 真正启动，`helper_live=true`；运行态生成 129 个节点，现有 Token 的 `TokenProperties`、`CprTokenProperties`、`TraversalProperties` 均存在；本轮游戏日志没有脚本错误或警告。

### 未完成 / 风险
- [ ] 仍需用户在可见窗口拖动一次确认体感，重点检查具体导入模型是否确实按本地 `+Z` 建模；方向做反的素材应在导入/素材层校正，不给 CPR 规则组件增加模型方向字段。
- [ ] 路线拐角当前逐段即时转向，没有做平滑旋转；先以战棋工具的清晰方向为准，是否需要平滑只按真人手感决定。

## 2026-07-16 Codex P2.2 Token 拖动范围圈

### 已完成
- [x] `scripts/movement_service.gd` 新增独立运行态 `MovementRangePreview`，使用 64 段 `ImmediateMesh` 闭合线显示本次移动的基础距离圈；颜色与绿/红路线区分。
- [x] `begin_preview()` 在拿到当前规则提供器预算后画圈，圆心固定为本次 Token 起点，半径直接使用规则预算；默认 `MOVE=5` 时为 10 米/码，换规则提供器不需要修改绘制代码。
- [x] 范围圈顶点沿既有 `SURFACE_LAYER_MASK` 向下贴合可走地表；圈与路线使用独立网格，`clear_preview_path()` 只清路线，鼠标短暂移到无效区域时圈不闪烁；`clear_preview()` 在松手、取消或切换对象时清圈。
- [x] 范围节点带 `gvtt_runtime_only` 标记，不加入场景 schema、不保存，不修改 `main.gd` 或 CPR 数据组件。

### Godot 4.7 源码 / 官方文档对照
- [x] 源码标签 `4.7-stable`，本地源码包 `reference/godot-4.7-stable-full.zip.zip`。
- [x] `scene/resources/immediate_mesh.cpp`：`surface_begin()` 开始表面，`surface_add_vertex()` 逐点缓存，`surface_end()` 通过 `RenderingServer` 提交表面，`clear_surfaces()` 同时清理渲染网格、表面记录与暂存顶点。
- [x] 离线官方文档 `gdd_0101_Using_ImmediateMesh.md`、`gdd_0951_ImmediateMesh.md`：`ImmediateMesh` 适合简单且经常变化的动态几何；重画前应调用 `clear_surfaces()`。
- [x] 未采用第三方网格战棋插件：成熟方案通常用洪水填充/Dijkstra 标出真实可达格，但 Gvtt 当前是连续 3D 导航且允许自由测距，直接搬用会改写移动底层。当前圈只表达几何距离，真实可达性继续由现有路径查询和规则耗费判断。

### 验证
- [x] 运行回归 `P1_RUNTIME_RESULT`：108 项断言、0 失败；新增验证默认 10 米半径、64 段/65 个闭合顶点、运行态标记、拖动期间生成、路线清空仍保留、结束拖动后清空。
- [x] 编辑器测试：3 项通过、0 失败，测试套件 `p1_editor_contracts`。
- [x] Godot `4.7-stable` 主场景启动 `helper_live=true`，本次启动错误为 0，游戏日志无脚本错误或警告。

### 未完成 / 风险
- [ ] 范围圈不是绕墙后的精确可达区域；圈内目标仍可能因绕路或困难地形而显示红色路线，这是当前设计的明确边界，不应把圈改称绝对可达区。
- [ ] 实际线条颜色、粗细和地形贴合观感仍需用户在可见窗口拖动一次确认；自动测试验证了几何与生命周期，不能代替肉眼体感。

## 2026-07-16 Codex P2.2 超距路线与范围圈统一

### 问题与结论
- [x] 用户指出范围圈出现后，圈外完整红线仍追随鼠标，交互上仍像允许拖到圈外，范围圈失去约束意义。核对确认提交本来已使用 `_preview_reachable_path`，真正矛盾是 `_draw_preview()` 同时绘制 `_preview_full_path`；视觉与实际提交终点不一致。
- [x] 撤销“超距显示红色完整路线”的旧交互结论。超距时只显示预算内可提交路线；直线移动终点落在线与范围圆的交点，绕障或高耗费地形按实际路线成本更早截停。

### 已完成
- [x] `scripts/movement_service.gd::_draw_preview()` 不再绘制圈外 `_preview_full_path`，只绘制 `_preview_reachable_path`；移除不再使用的红色路线材质。
- [x] `scripts/main.gd::_update_runtime_token_drag()` 的超距提示改为“已截停在范围边界”，颜色从错误式红色改为提醒式橙色；路线数值仍显示已使用预算/总预算。
- [x] 提交链保持单一真值：`MovementRuleProvider.truncate_path()` 产生截断终点，预览和 `commit_preview()` 共用同一条路线，不另算鼠标落点。

### Godot 4.7 源码对照
- [x] `core/math/vector3.h::Vector3::distance_to()` 按三维段长累计路线，`Vector3::lerp()` 分别对 X/Y/Z 做线性插值；本地截断函数用剩余预算占当前段成本的比例计算精确段内边界点。
- [x] `scene/resources/immediate_mesh.cpp` 的提交/清理链沿用上一轮；本轮只减少提交表面，不新增 Godot API。
- [x] 没有改成纯几何 `limit_length()`：那会忽略绕墙、坡地和困难/攀爬等成本，错误赠送移动距离。直线路径才与圆周相交；曲线路径按实际路线长度可停在圈内。

### 验证
- [x] 最终运行回归 `P1_RUNTIME_RESULT`：115 项断言、0 失败。新增真实导航用例：20 米直线目标、10 米预算，必须标记超距、终点距起点 10 米、预览只有一个表面且没有圈外顶点、提交成功、Token 最终位置等于预览截断点。
- [x] 第一轮曾出现 115 项中 1 项失败“保存 MOVE 被默认值覆盖”；实查是新增测试临时把 MOVE 改为 5 后未在旧保存测试前恢复 10，属于测试状态污染。恢复测试数据后重跑 115/115，产品代码没有覆盖存档值。
- [x] 编辑器测试 3 项通过、0 失败；Godot `4.7-stable` 主场景启动 `helper_live=true`，本次启动错误为 0，游戏日志无脚本错误或警告。

### 用户手测
- [x] GM 已在可见窗口测试范围圈与超距拖动；指出圈外红线问题后完成修正，并接受当前“路线截停在预算边界、松手落在同一截断点”的版本，P2.2 暂时冻结。

## 2026-07-16 Codex 文档与确认流程收口

### 已完成
- [x] 修正 `docs/design.md` 与 `docs/p2_task_schedule.md` 的 P2.1 旧按钮口径：Token 继续直接拖动，面板只显示 MOVE/预算，不放尚未实现的射击、技能、破坏和光源开关占位按钮。
- [x] 回填 P2.0 已完成、P2.2 已由 GM 手动验收并暂时冻结的状态，清理会误导后续进度判断的旧待办。
- [x] 修改 `AGENTS.md`：用户已经明确授权功能、修复或文档目标后，普通文件修改直接连续完成，不再重复索要固定确认；Godot 4.7 源码对照卡保留为实现前质量门禁，但不再自动暂停等待口令。

### 未改变
- [ ] 平台要求的系统权限、危险操作和数据破坏风险确认不受项目提示词控制，无法由 `AGENTS.md` 取消。

## 2026-07-16 Codex 旋转阻挡物导航占用修复

### 问题与实测
- [x] 用户反馈墙与汽车形成夹角后，目测仍有很大空间，但 Token 无法进入。运行态读取确认 Token `collision_radius=0.45` 米；当前重新加载的“场景1”只有两个 Token 和一辆汽车，没有墙体实例，因此不能冒充已对用户原夹角做逐点复测。
- [x] 根因定位到 `MovementService`：精确三角碰撞只用于最后胶囊扫掠，导航挖洞却把旋转后模型的世界 AABB 再画成轴对齐矩形；斜放长汽车/墙体会凭空多出四个不可见的大角。
- [x] 曾尝试把导航 `agent_radius` 从 0.75 米降到 Token 的 0.45 米；运行回归出现墙角提前截停，证明路径简化后只留约 0.05 米余量不足。该尝试已完整撤回，0.75 米继续作为导航路线与 0.45 米实体胶囊之间的安全余量。

### Godot 4.7 源码对照
- [x] 标签 `4.7-stable`；`scene/3d/navigation/navigation_obstacle_3d.cpp::navmesh_parse_source_geometry()` 读取障碍局部顶点，应用缩放、Y 轴旋转和世界位置，再调用 `add_projected_obstruction()`。
- [x] `modules/navigation_3d/3d/nav_mesh_generator_3d.cpp` 先把非 carve 障碍标成不可走，再调用 `rcErodeWalkableArea()` 按 `agent_radius` 留边；项目无需提前把障碍轮廓膨胀。
- [x] 离线文档：`gdd_0668_NavigationObstacle3D.md`、`gdd_0981_NavigationMesh.md`、`gdd_0220_Using_NavigationObstacles.md`。社区旧版脚本会手工把旋转乘进顶点，但 4.7 已原生处理 Y 轴旋转，因此未采用，避免重复旋转。

### 已完成
- [x] `scripts/movement_service.gd::_get_local_bounds()` 在物体根局部坐标中合并可见模型边界；`_create_navigation_obstacle()` 使用局部 XZ 四点轮廓并复制物体根变换。旋转汽车和墙的导航脚印现在跟着模型旋转，不再使用世界轴对齐胖方盒。
- [x] 保留精确三角碰撞与 `_apply_clearance_limit()` 胶囊扫掠，修正导航脚印不会允许 Token 穿模。
- [x] `tests/p1_runtime_regressions.gd` 把真实绕障夹具改为 4×1 米、旋转 45°的长障碍，并验证轮廓尺寸、旋转、绕障终点和原有移动链。

### 验证
- [x] Godot 静态解析通过：`token_properties.gd`、`movement_service.gd`、`p1_runtime_regressions.gd` 均被识别。
- [x] 编辑器测试 3/3 通过；运行回归 `P1_RUNTIME_RESULT` 为 118 项断言、0 失败。
- [x] Godot `4.7-stable` 主场景启动成功，`helper_live=true`，本轮游戏日志只有运行助手注册信息，无脚本错误或新增警告。

### 剩余边界
- [ ] 用户原来的墙体没有保存在当前“场景1”中，需重新摆出墙与汽车夹角做可见窗口体感确认。
- [ ] L 形、U 形等凹模型当前仍使用随物体旋转的局部矩形脚印，可能偏保守；后续用可选手工导航轮廓或多凸形处理，不阻塞本次斜放长物体修复。

## 2026-07-16 Codex 编辑框与导航判定复核

### 用户反馈与结论
- [x] 用户重新搭建墙与汽车夹角，观察到编辑态橙色选择框彼此没有接触，但 Token 仍无法进入，说明上一轮消除旋转世界 AABB 后仍有额外保守范围。
- [x] 源码确认编辑框来自 `addons/Gizmo3DScript/gizmo3D.gd::_calculate_spatial_bounds()`：递归读取 `VisualInstance3D.get_aabb()`，折回选中物体根坐标后合并，并随根变换旋转。`MovementService._get_local_bounds()` 当前采用等价算法，因此基础物体框已经一致。
- [x] 真正差异是导航烘焙会在基础框外按 `agent_radius=0.75` 米侵蚀可走区；两个物体之间需约 1.5 米中心通道才会保留，而默认 Token `collision_radius=0.45` 米、直径 0.9 米，当前余量确实偏保守。
- [x] 不直接复用 `PickProxy` 作为移动碰撞：它属于点击容错层，且旧 `_fit_from_target()` 先合并世界 AABB 再折回本地，旋转时也可能虚胖。正确边界是共享同一份模型局部边界数据，但选择、移动、战斗、LOS 继续使用独立组件。

### 下一步边界
- [ ] 不能把导航半径直接改成 0.45：上一轮运行回归已证明该值在 0.25 米导航单元下会让胶囊扫掠在墙角提前截停。下一轮应联合调整导航 `cell_size` 与标准安全半径，并新增“指定净宽可通过/更窄净宽不可通过”的走廊回归。
- [ ] 当前运行助手已停止且编辑器仍残留 playing 状态；为避免丢失用户刚搭的未保存夹角，本轮没有重启游戏或修改功能代码，因此尚未量到该夹角的实际净宽。

## 2026-07-16 Codex 破墙模型导入文件说明

### 已完成
- [x] 核查 `个人资产/模型/破墙/`：当前目录含 3 个源文件（参考 PNG、GLB 模型、抽出的 basecolor JPG）和 3 个 Godot `.import` 导入配置文件；对应 `.godot/imported/` 下还有 7 个内部缓存文件。
- [x] 对照 Godot 4.7 离线文档 `gdd_0147_Import_process.md`、`gdd_1470_ResourceImporterScene.md`、`gdd_1473_ResourceImporterTexture.md`：确认 `.import` 是导入参数和元数据，`.godot/imported/` 是可再生成的内部导入缓存，图片/3D 场景会分别转成 `CompressedTexture2D` 与 `PackedScene` 资源。
- [x] 结论：不是用户误操作；Godot 导入外部资产时本来就会生成“账本文件”和“运行用缓存”。参考 PNG 若只是提示图，可移到项目外或设为跳过导入；GLB、其实际贴图源文件以及对应 `.import` 不建议随手删。

### 未改动
- [ ] 未删除任何资产或缓存；本次只回答导入行为与文件必要性。

## 2026-07-16 Codex 现成方案调研门禁收口

### 已完成
- [x] 修改 `AGENTS.md`：把“现成方案先行”从仅约束功能实现，扩展为同时约束方案问答、功能设计、bug 修复、性能/手感优化和代码修改的最高优先级门禁。
- [x] 新增强制“调研回执”：结论或写项目文件前，必须公开项目现状、Godot 精确版本源码、官方文档/演示、英文社区/插件四层来源与实际查得内容；只搜索不展示视为未完成。
- [x] 保留 Godot `4.7-stable` 源码一致性对照卡，并明确为写相关功能代码前的第二道门；保留“用户已明确目标后，普通文件修改不重复索要确认”规则。

### 未改动
- [ ] 本轮未修改任何 GDScript、场景或功能行为；修改的是 Codex 协作/调研流程，不会直接改变 Gvtt 运行效果。

## 2026-07-17 Codex Token 多体型导航与阻挡边界收口

### 问题与结论
- [x] 用户在墙与汽车夹角中发现：橙色选择框尚有空隙，但默认 Token 仍不能进入。确认橙色 Gizmo（操纵框）与移动服务都采用物体根局部 AABB（轴对齐包围盒）思路；真正的额外占用来自旧导航半径和导航网精度，而不是必须再造一个比可见框更肥的物体边界。
- [x] 不把 Token 半径写成全局固定值。每个 Token 继续保存自己的 `collision_radius/collision_height`；移动服务按体型缓存导航图，肥大 Token 不会借用默认 Token 的窄路路线。
- [x] 非地形阻挡物每次移动服务重建只计算一次局部边界，导航轮廓和运行态 `BoxShape3D`（盒形碰撞体）共用该缓存并保留根旋转/缩放。地形、坡面和台阶继续用三角网格，避免丢失高度。

### 四层调研回执
- [x] 项目现状：`addons/Gizmo3DScript/gizmo3D.gd::_calculate_spatial_bounds()` 递归读取模型边界并折回物体根局部坐标；旧 `MovementService` 虽已改为随根旋转的局部矩形脚印，但仍使用单一保守导航半径，导致默认 Token 在可见有余量的夹角或走廊中被提前挡住。
- [x] Godot `4.7-stable` 源码：`editor/scene/3d/mesh_instance_3d_editor_plugin.cpp::MeshInstance3DEditor::create_shape_from_mesh()` 的边界框模式读取 `Mesh.get_aabb()` 并创建 `BoxShape3D`；`scene/3d/mesh_instance_3d.cpp::MeshInstance3D::get_aabb()` 返回局部边界；`modules/navigation_3d/3d/nav_mesh_generator_3d.cpp` 把 `agent_radius` 交给 `rcErodeWalkableArea()` 侵蚀可走区；`modules/navigation_3d/3d/nav_mesh_queries_3d.cpp` 负责路径走廊漏斗与后处理。
- [x] 官方资料：离线 `gdd_0225_Support_different_actor_types.md` 明确支持源几何解析一次、为不同角色尺寸烘焙独立导航图；`gdd_0216_Using_navigation_meshes.md`、`gdd_0981_NavigationMesh.md` 和 `gdd_0558_CollisionShape3D.md` 用于核对导航精度、角色尺寸与碰撞形状边界。
- [x] 英文社区/现成项目：3D Auto Collision Generator 是 Godot 4.1 编辑器批处理工具，不能处理 Gvtt 的 4.7 运行态导入与多体型导航；`godotdetour` 面向 Godot 3/GDNative（原生脚本扩展）且处于维护模式。两者均不直接采用，保留其“复用已生成几何、按角色类型分图”的成熟思路。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] `Mesh.get_aabb()` + `BoxShape3D` -> `MovementService._get_cached_local_bounds()`、`_add_bounds_collision()`、`_create_navigation_obstacle()` -> 4×1 米旋转阻挡物的运行碰撞、导航轮廓尺寸和旋转一致。
- [x] 源几何解析与多图烘焙 -> `rebuild()` 只保存一份 `_source_geometry_data`，`_create_navigation_profile()` 按量化体型键缓存地图 -> 默认 Token 与半径 0.9 米的肥大 Token 生成两张图；默认 Token 可过 1.5 米净宽，肥大 Token 不能错误穿过。
- [x] `agent_radius` 侵蚀与路径查询 -> 水平 `cell_size=0.1` 米、垂直 `cell_height=0.25` 米；默认 `0.45 × 1.8` 米体型量化为 `0.5 × 2.0` 米；真实胶囊扫掠否决时才尝试半径增加 `0.2` 米的安全档 -> 独立墙角测试确认基础 0.5 米档可用，0.7 米安全档消除墙角碰撞误判。
- [x] Godot RID（资源标识符）生命周期 -> `MovementService._exit_tree()` 兜底调用 `_clear_navigation_runtime()`，显式释放每张图的地图与独立区域，并断开连接节点 -> 重建、退出运行态和切场景不遗留导航资源。

### 未采用方案
- [x] 未采用 `EDGE_CENTERED`（边中心）路径后处理：在当前大块连续导航面上会把路线拉到远处多边形边中心，绕路明显。
- [x] 未直接复用 PickProxy（点击代理）：它服务点击容错，不是橙色 Gizmo 本身，也不应承担移动、战斗或 LOS（视线遮挡）职责。
- [x] 未在每次拖动时重新扫描所有模型或烘焙导航图：局部边界每次重建算一次，同体型 Token 复用缓存地图，避免鼠标移动造成重复开销。

### 验证
- [x] Godot `4.7-stable` 独立静态解析退出码 0；受限环境下把 Godot 配置目录重定向到临时可写目录后，解析日志无脚本错误。
- [x] 最终运行回归 `P1_RUNTIME_RESULT`：129 项断言、0 失败，约 2.8 秒完成；新增销毁后等待导航服务器同步并检查本服务创建的地图均已释放。
- [x] 修复前进程退出明确报告 3 个 `NavMap3D` 和 1 个 `NavRegion3D` RID 泄漏；增加 `_exit_tree()` 所有者清理后，这两类导航泄漏均消失。
- [x] 临时多档半径扫描和调试输出已删除，只保留固定回归断言。
- [ ] 编辑器契约测试在最终补丁前为 3/3；最终补丁后 Godot MCP（模型上下文协议）测试工具暂时不可用，因此没有冒充已重跑。

### 导航退出泄漏补救调研
- [x] 项目现状：`main.gd::_destroy_movement_service()` 移除并排队释放服务，但旧服务没有离树清理回调；最后一批手动 `map_create/region_create` 资源因此未进入现有 `_clear_navigation_runtime()`。
- [x] Godot `4.7-stable` 源码：`scene/main/node.cpp::Node::_propagate_exit_tree()` 先递归退出子节点，再调用父节点脚本 `_exit_tree()`；`navigation_region_3d.cpp` 和 `navigation_link_3d.cpp` 退出时断开地图、析构时释放节点自有 RID。
- [x] 官方文档：离线 `gdd_1342_NavigationServer3D.md` 明确 `free_rid()` 销毁手动 RID，并说明导航服务器修改通常在下一物理帧后生效；测试因此等待物理帧和处理帧后再查 `get_maps()`。
- [x] 社区/官方问题库：Godot GitHub 的 `World3D` 所有者实现同样在析构时释放自己创建的导航图；RID 生命周期讨论 #103073 强调手动创建资源需要明确所有者和释放顺序。未找到需要引入的导航清理插件。
- [x] 未采用只在 `main.gd` 临时补调用的方案：资源所有权在 `MovementService`，由服务 `_exit_tree()` 兜底才能覆盖切模式、切场景和未来其他销毁入口。

### 新问题
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-17 | 详细退出日志仍显示 4 个来自 `addons/Gizmo3DScript/selected_item.gd` 的选择辅助对象和 1 个对应脚本资源未释放。导航 RID 已清零；该问题与本轮移动服务无关。 | 待单独调研 Gizmo 生命周期；本轮不跨范围修改插件。 |

## 2026-07-17 Codex 运行态点选与 Gizmo 状态核对

### 用户反馈与项目现状
- [x] 用户在运行态点击物体时看不到选择框和 Gizmo（操纵框），询问是否已经无法点选。
- [x] `main.gd::_apply_gizmo_for_mode()` 进入运行态时会 `clear_selection()`、停止 Gizmo 逐帧处理并隐藏；`_unhandled_input()` 的运行态分支只尝试 `_try_begin_runtime_token_drag()`，随后直接返回。因此普通墙、汽车、灯和交互物体当前确实没有运行态点选入口；这不是 P2.2 移动清理造成的回归，而是 P2.1 尚未实现。
- [x] 编辑态点选链仍存在：`_pick_entity_at_screen_position()` 射线命中 `PickProxy` -> `_select_entity()` -> Gizmo `select()` -> 属性面板绑定。若编辑态也无法显示，才应作为独立 bug 用运行态状态探查定位。

### 四层依据
- [x] Godot `4.7-stable` 源码：`editor/scene/3d/node_3d_editor_plugin.cpp` 的 `Node3DEditorViewport::_select_ray()`、`_find_items_at_pos()` 和 `_select_clicked()` 把“命中对象、更新选中集、显示编辑 Gizmo”拆成不同阶段。
- [x] 官方离线文档：`gdd_0540_Camera3D.md` 与 `gdd_0255_Ray-casting.md` 支持当前屏幕点转射线和 `intersect_ray()` 点选方式；`gdd_0774_Viewport.md` 明确输入被提前标记处理后不会继续传播到后续 `_unhandled_input()`。
- [x] 社区方案：当前 `addons/Gizmo3DScript` 为 Gizmo3D 1.0.0，Godot 资产库标记为 Godot 4.6 Community（社区）插件；其选择框与移动/旋转/缩放手柄可以分别开关，可复用选择视觉，但不能把完整编辑权限原样开放到跑团运行态。

### P2.1 边界
- [x] 运行态点击对象建立选中状态，显示橙色选择框并打开 GM 只读操作面板；不显示允许任意移动、旋转、缩放场景物件的编辑 Gizmo。
- [x] Token 输入按 6 像素位移阈值区分短按与拖动：短按选择，达到阈值才开始移动路线预览；普通墙、灯和交互物体直接进入运行态选择。
- [x] 面板显示名称、对象类型和当前组件状态；Token 显示 CPR MOVE 与本次预算。不放射击、技能、破坏和光源开关占位按钮。

## 2026-07-17 Codex 编辑态点选修复与 P2.1 基础落地

### 纠错与根因
- [x] 用户反馈“点选没有框和 Gizmo”时，Codex 先错误理解成运行态；用户随后明确是编辑态。该误判属于沟通错误，不是用户操作错误。
- [x] 用真实迁移场景 `modules/测试模组/_canonical/场景1.scn` 自动复现完整点击链：`PickProxyArea` 能重建、屏幕点射线能命中真实物体、`_prop_target` 能建立；旧 Gizmo3D `select()` 只登记选中项，必须等下一帧 `_process()` 才更新 `visible`，且模式/处理开关一旦状态滞后，没有选中时自恢复兜底。
- [x] 修复为 `Gizmo3D.select()` 登记后立即 `_update_transform_gizmo()`；`main.gd::_select_entity()` 每次按当前模式强制恢复 Gizmo 模式、坐标轴和逐帧处理。编辑态同一帧显示完整框与手柄，运行态同一帧只显示选择框。

### P2.1 已实现
- [x] 运行态普通对象点击即选中，点击空地取消；Token 短按选择，鼠标位移达到 6 像素后才启动既有移动预览。
- [x] 复用同一 Gizmo3D：编辑态 `ToolMode.ALL`，运行态 `mode=0` 且关闭坐标轴，只保留橙色选择框。
- [x] 复用右侧属性面板：编辑态保留原可编辑字段；运行态切成只读名称、类型、状态和组件摘要，Token 显示 MOVE 与预算。
- [x] 修复 Gizmo3D `SelectedItem` 普通对象泄漏：`deselect()` 与 `clear_selection()` 在释放四个渲染 RID 后调用 `item.free()`。

### 四层调研回执
- [x] 项目现状：编辑态 `_pick_entity_at_screen_position()` 使用第 20 物理层 `PickProxy`；运行态旧分支只尝试 Token 拖动并直接返回；Gizmo3D 1.0.0 的 `select()` 未立即刷新可见状态。
- [x] Godot `4.7-stable` 源码：`Node3DEditorViewport::_select_ray()` 命中对象，`_select_clicked()` 更新选中集；命中、选中状态和 Gizmo 显示是分开的阶段。
- [x] 官方离线文档：`gdd_0540_Camera3D.md`、`gdd_0255_Ray-casting.md` 支持屏幕点转射线与 `intersect_ray()`；`gdd_0774_Viewport.md` 说明 `_input()` 到 `_unhandled_input()` 的传播和提前处理规则。
- [x] 社区方案：Gizmo3D 1.0.0 为 Godot 4.6 Community 插件，选择框、坐标轴与变换模式可独立配置；本项目复用其选择框，不在运行态开放变换权限。

### 源码行为 -> 本地实现 -> 验证
- [x] Godot 射线命中与选中集分离 -> `_pick_entity_at_screen_position()` + `_select_entity()` -> 真实 `场景1.scn` 点击盒中心投影后命中同一物体，并建立 `_prop_target`。
- [x] 选择变化立即更新 Gizmo -> `Gizmo3D.select()` 同步 `_update_transform_gizmo()` -> 编辑态选中同一帧 `visible=true`，稳定两帧后仍有 1 个选中项且逐帧处理开启。
- [x] 点击/拖动分流 -> `_runtime_pointer_target` + 6 像素阈值 -> 5 像素抖动不启动拖动，6 像素进入拖动判定。
- [x] 运行态权限隔离 -> Gizmo `mode=0` + 只读面板 -> 运行态有选择框但无坐标轴和编辑字段；切回编辑态恢复 `ToolMode.ALL`。
- [x] 选中项清理 -> `SelectedItem.free()` -> 取消选择后对象失效，详细退出日志不再有 `selected_item.gd`、ObjectDB 或资源泄漏。

### 验证
- [x] Godot `4.7-stable` 完整运行回归 `P1_RUNTIME_RESULT`：147 项断言、0 失败，约 3 秒完成。
- [x] 详细退出日志仅有通过结果，无脚本错误、失败、RID、ObjectDB、资源或分页分配器泄漏。
- [ ] 项目级编辑器解析被当前已打开的 Godot 占用 `addons/gdstyle/bin/gdstyle_gdext.dll` 干扰，出现动态库复制失败；运行场景已实际加载并执行全部脚本，因此不是本次 GDScript 解析错误。未关闭用户编辑器强行重跑。
- [ ] 仍需 GM 在可见窗口确认编辑态点击框、运行态短按/拖动手感和右侧只读面板观感。

### 风险与后续
- [ ] Token 体积目前读取自己的配置值，不会根据可见模型胖瘦自动推导；肥大模型需要 GM 设置对应半径/高度。未来可提供“从模型边界建议体积”，但不能静默覆盖用户配置。
- [ ] 每种新体型首次出现时需要烘焙一张导航图；源几何只解析一次且同体型复用。只有真实模组出现大量不同尺寸时，才需要增加缓存上限或预热。
- [ ] L 形、U 形等凹阻挡物仍按保守局部矩形占用；后续可增加手工导航轮廓或多凸形组件，不在运行时为所有模型做昂贵分解。

## 2026-07-17 Codex 编辑态真实点击链补救

### 撤回与根因
- [x] 撤回上一节“编辑态点选已修复”的完成结论：旧 147 项测试直接调用 `_pick_entity_at_screen_position()` 和 `_select_entity()`，绕过了真实鼠标输入传播，不能证明用户窗口里的编辑态点击可用。
- [x] 新增 `Viewport.push_input()` 完整传播测试后稳定复现用户现象：直接射线能命中当前 `user://modules/测试模组/_canonical/场景1.scn` 的真实对象，但真实输入不能建立 `_prop_target`，Gizmo 也不显示。
- [x] 根因是编辑态 `_unhandled_input()` 收到 `InputEventMouseButton` 后丢弃 `event.position`，转而重新读取 `get_viewport().get_mouse_position()`；嵌入窗口或人工注入时两者可能不同，导致边栏判断和拾取射线使用错误坐标。
- [x] `scripts/main.gd` 现统一使用同一个 `InputEventMouseButton.position` 完成左栏/属性面板排除、普通点击放置和对象拾取；`_try_select_at_mouse()` 改为显式接收屏幕点，不再二次查询鼠标。

### 四层调研回执
- [x] 项目现状：用户实际场景真值位于 `user://modules/测试模组/_canonical/`；真实场景的 `PickProxyArea` 能重建，直接射线和直接选中均通过，故碰撞盒与 Gizmo 创建不是本次阻断点，缺口位于输入入口。
- [x] Godot `4.7-stable` 源码（提交 `5b4e0cb0f`）：此前源码对照的 `editor/scene/3d/node_3d_editor_plugin.cpp` 中 `_select_ray()`、`_find_items_at_pos()`、`_select_clicked()` 沿传入视口点完成命中与选择，不在链中重新查询鼠标位置。
- [x] 官方离线文档：`gdd_0774_Viewport.md` 第 1407-1425 行说明 `push_input()` 依次传播到 `_input()`、GUI、快捷键和 `_unhandled_input()`，前序处理会阻断后序；`gdd_1306_Input.md` 第 852-870 行说明人工输入不会移动系统鼠标，验证了事件坐标与另行查询鼠标可能分离。
- [x] 社区方案：继续使用项目已有 Gizmo3D 1.0.0 的选择视觉；该插件只负责收到目标后的选择框/手柄，不负责 Gvtt 的场景点选入口，因此没有引入新选择插件，也没有修改碰撞范围。

### 源码行为 -> 本地实现 -> 验证
- [x] 视口事件携带点击位置 -> `main.gd::_unhandled_input()` 保存 `edit_press.position` -> 左栏/属性面板排除、放置和拾取共用同一点。
- [x] 编辑器沿传入点做射线选择 -> `_try_select_at_mouse(screen_position)` -> `_pick_entity_at_screen_position(screen_position)` -> `_select_entity()` -> `Gizmo3D.select()`。
- [x] 完整输入传播验证 -> `tests/p1_runtime_regressions.gd` 使用 `Viewport.push_input()` 向真实对象屏幕点发送左键 -> `_prop_target` 指向命中对象且 Gizmo 同帧可见。

### 验证与剩余状态
- [x] 修复前新增真实输入测试：149 项断言中 2 项失败，分别为“真实输入未建立选中状态”和“Gizmo 未显示”。
- [x] 修复后 Godot `4.7-stable` 完整运行回归：`P1_RUNTIME_RESULT {"assertions":149,"failed":0,"failures":[]}`。
- [x] 未修改 `PickProxy` 尺寸、对象 schema、导航碰撞或 Gizmo 渲染算法；本次只修复编辑态点击坐标来源并补齐真实输入测试。
- [ ] 当前 Godot MCP（模型上下文协议）运行助手未监听，无法用 `game_eval` 读取用户现有窗口；最终可见窗口体感仍以 GM 本次手动点击确认，但不再以直接函数测试冒充现场验证。

## 2026-07-17 Codex 同名对象重叠与 Gizmo 假性脱离修复

### 用户现场与根因
- [x] 用户在编辑态放入汽车后发现第一次拖 Gizmo（操纵框）时汽车看似不动；再次点击后可拖动，并观察到两次选中名称分别为 `破损汽车3d模型` 与 `@Node3D@127`。
- [x] 当前可见窗口截图确认汽车上存在橙色选择框和完整 Gizmo；右侧属性栏因嵌入调试窗口超出屏幕，只能看到“选中：”开头，未伪称从截图读到完整名称。
- [x] 只读加载汽车原生缓存确认：缓存根为 `破损汽车3d模型`，内部仅一个 `MeshInstance3D`，所有节点 `top_level=false`，对象根移动时模型会正常继承；不存在 Gizmo 与可见模型断链。
- [x] 只读加载当前 `user://modules/测试模组/_canonical/场景1.scn` 发现同类证据：已有 `网行者test` 与 `@Node3D@99` 两个独立对象根；后者自己的 `EntityProperties` 和 `PickProxy.target_node` 均指向自己。由此确认 `@Node3D@127` 是第二辆同名汽车对象根，不是第一辆汽车的内部节点。
- [x] 两辆汽车完全重叠时，移动其中一辆后另一辆仍留在原位，视觉上会像“只有 Gizmo 移动”；再次点击会选中另一辆，因此名称改变且第二次移动显现。

### 四层调研回执
- [x] 项目现状：`main.gd::_btn_model()` 同时连接 `button_down -> _on_model_drag_started()` 与 `pressed -> _on_model_clicked()`；`_finish_model_drag()` 落地后虽清空活动素材，但迟到的按钮回调可重新激活；`_on_model_clicked()` 又在判断是否点中同一素材前先清空索引，导致“再次点击取消”永远失效。
- [x] Godot `4.7-stable` 源码（提交 `5b4e0cb0f`）：`scene/gui/base_button.cpp::BaseButton::on_action_event()` 按下发 `button_down`、默认松开发 `pressed`；`scene/main/node.cpp::Node::add_child()` 调 `_validate_child_name()`，默认 `force_readable_name=false` 时同名节点明确生成 `@类名@数字`。
- [x] 官方离线文档：`gdd_0565_Control.md` 的 `_get_drag_data()`、`_can_drop_data()`、`_drop_data()` 和 `set_drag_preview()` 只定义 Control（界面控件）之间的原生拖放；Gvtt 裸 3D 地图不是 Control 接收端，整套替换需要增加全屏输入层，可能改变刚修复的 3D 点选传播。
- [x] 英文社区/现成项目：Godot Asset Placer 1.5.4（2026-07-12，MIT，Godot 4）维护活跃，采用明确的放置模式、预览与“放置后聚焦变换”分离；它是 Godot 编辑器插件，不能直接装进 Gvtt 运行工具，本次只采用“放置结束状态明确、重复对象身份可读”的模式。来源：`https://github.com/levinzonr/godot-asset-placer`。

### 源码行为 -> 本地实现 -> 验证
- [x] `BaseButton` 的按下/松开双信号 -> `_finish_model_drag()` 在本次输入链帧末再次 `_clear_all_model_selections()` -> 模拟拖放后迟到 `_on_model_clicked()`，下一帧活动素材为空，后续场景点击不会再放一份。
- [x] 同一按钮可切换放置状态 -> `_on_model_clicked()` 在清空前保存 `was_active` -> 第一次点击进入放置模式，第二次点击退出。
- [x] `Node::add_child(force_readable_name)` -> `_place_model()` 改用 `_content_root.add_child(root, true)` -> 连续同点放置两份同名模型仍保留两个对象，但第二份使用可读递增名，不再是 `@Node3D@数字`。
- [x] 旧数据兼容 -> `_ensure_readable_entity_name()` 只处理带 `EntityProperties` 且名称以 `@` 开头的对象根，优先使用显示名或模型子节点名；不删除、合并、移动对象 -> 旧匿名夹具迁移后名称可读且节点数量不变。
- [x] 变换继承 -> 测试移动第一份对象根 3 米 -> 内部可见模型的世界位置同步移动 3 米。

### 验证与边界
- [x] 修复前新增回归：`P1_RUNTIME_RESULT` 153 项断言、2 项失败，失败项为“第二个同名对象被命名成 `@Node3D@数字`”和“拖放结束后的按钮回调重新激活放置工具”。
- [x] 修复后 Godot `4.7-stable` 完整运行回归：`P1_RUNTIME_RESULT {"assertions":158,"failed":0,"failures":[]}`。
- [x] 未采用全屏 Control 原生拖放层，也未引入 Asset Placer 编辑器插件；保留当前真实 3D 模型预览和射线落点实现。
- [x] 未自动删除当前场景中的重叠对象，因为多辆同型汽车叠放可能是 GM 有意布局；修复只阻止拖放状态残留并让每个对象身份可读。
- [ ] 当前 `Gvtt (DEBUG)` 窗口仍运行启动时的旧脚本，且用户可能有未保存场景；本轮没有擅自停止或重启游戏。新行为需下次安全重启后生效。

## 2026-07-17 Codex 素材按钮单一手势根修

### 撤回旧止血结论与实现
- [x] 撤回上一节把帧末 `call_deferred("_clear_all_model_selections")` 视作完整修复的结论：它依赖 `button_down` 与 `pressed` 的到达顺序，只能压住迟到回调造成的重复放置，没有消除同一手势同时进入点击和拖放两套逻辑的根因。
- [x] `scripts/main.gd::_btn_model()` 已删除 `pressed -> _on_model_clicked()` 业务连接，只保留 `button_down -> _on_model_pointer_pressed()` 作为唯一入口。
- [x] 按下只登记按钮、素材类别、索引和事件按下坐标；移动达到 `MODEL_DRAG_THRESHOLD_PIXELS=6.0` 才调用 `_begin_model_drag()` 创建 3D 预览。未过阈值且在原按钮内松开才调用 `_on_model_clicked()`，超过阈值后的地图松开只调用 `_finish_model_drag()`。
- [x] 拖放成功后立即清空连续放置选择，不再依赖下一帧补清；切换编辑/运行状态统一调用 `_cancel_model_gesture()` 清理候选、拖动状态和预览。

### 四层调研回执
- [x] 项目现状：旧 `_btn_model()` 同时连接 `button_down` 和 `pressed`；旧 `_on_model_drag_started()` 在按下瞬间就创建预览，`_finish_model_drag()` 又靠帧末清理抵消迟到点击，结构上无法保证点击/拖放互斥。
- [x] Godot `4.7-stable` 源码（提交 `5b4e0cb0f`）：`scene/gui/base_button.cpp::BaseButton::on_action_event()` 在按下阶段发 `button_down`，在合格松开阶段发 `pressed`；本地实现不再让两个阶段各自启动一套业务。视口输入链继续由 `_input()` 跟踪移动和松开，按钮信号只登记候选。
- [x] 官方资料：离线 `gdd_0565_Control.md` 的 `_get_drag_data()`、`_can_drop_data()`、`_drop_data()`、`set_drag_preview()` 适用于 Control（界面控件）接收端；Gvtt 的落点是裸 3D 地图，故保留现有射线落点与真实模型预览，只采用候选/阈值/提交互斥结构。`gdd_0774_Viewport.md` 与 `gdd_1306_Input.md` 继续作为事件坐标和输入传播依据。
- [x] 英文社区/现成项目：Godot Asset Placer 1.5.4（MIT、Godot 4、2026-07-12 仍维护）可复用“明确放置状态、预览和提交生命周期”思路；其实现属于 Godot 编辑器插件，未直接引入运行工具。来源：`https://github.com/levinzonr/godot-asset-placer`。

### Godot 源码行为 -> 本地实现 -> 自动验证
- [x] `BaseButton` 按下阶段 -> `_on_model_pointer_pressed()` 只建候选 -> 真实输入测试断言刚按下时 `_drag_model_active=false` 且候选按钮正确。
- [x] 视口持续派发鼠标移动 -> `_input()` 用事件坐标和 6 像素阈值调用 `_begin_model_drag()` -> 测试覆盖移动 2 像素仍是点击、跨到地图后才出现 3D 预览。
- [x] 点击松开与拖放松开互斥 -> `_finish_model_pointer_candidate()` 或 `_finish_model_drag()` 二选一 -> 测试覆盖再次点击取消、一次拖放只生成一个对象、结束后候选/活动状态/预览全部为空。
- [x] 模式切换清理 -> `_on_mode_changed()` 调 `_cancel_model_gesture()` -> 保留现有编辑/运行模式完整回归。

### 验证与边界
- [x] 修复前真实输入红灯：`P1_RUNTIME_RESULT` 167 项中 7 项失败；其中 5 项直接命中本轮手势根因（候选缺失、按下即拖、轻微移动即拖、轻微移动不能点击、再次点击不能取消），另 2 项为首次隔离运行的导航异步断言，后续未复现，不作为手势结论依据。
- [x] 修复后 Godot `4.7-stable` 隔离无窗口完整回归连续两轮均为 `P1_RUNTIME_RESULT {"assertions":167,"failed":0,"failures":[]}`；`git diff --check` 通过，修改文件无 `:=`。
- [x] 原项目直接启动测试会在加载 `addons/gdstyle/gdstyle.gdextension` 时发生 Godot Rust 4.5 API / Godot 4.7 运行时崩溃；改用不加载该扩展、但目录链接同一份 `scripts/scenes/tests/assets` 的隔离测试壳，未把引擎崩溃冒充产品测试结果。
- [x] 未修改模型加载/缓存、汽车碰撞、PickProxy、Gizmo、对象 schema、Token 移动或场景数据；没有删除当前重叠汽车。
- [ ] 当前可见 `Gvtt (DEBUG)` 若仍是修复前启动的进程，不会热加载这次脚本；为保护未保存场景，本轮仍未擅自关闭或重启。

## 2026-07-17 Codex 输入与主场景代码结构只读审查

### 结论
- [x] 本轮只读审查，不改功能代码。当前素材单一手势根修连续两轮 167/167 通过，应保留；结构治理不采用一次性重写 `main.gd`。
- [x] `scripts/main.gd` 当前 3068 行、147 个函数，同时负责场景存读、素材/缓存、素材拖放、Token 移动入口、选择、Gizmo、属性面板、相机和 UI。`_input()` 依靠分支顺序裁决 Token、素材、右键菜单、缩放、旋转和平移，`_unhandled_input()` 又负责同批手势起点；正确性已依赖共享状态和调用顺序。
- [x] 建议第一步只抽 `PointerInteractionController`（指针交互控制器）：用明确枚举状态统一 `IDLE / MODEL_CANDIDATE / MODEL_DRAG / TOKEN_CANDIDATE / TOKEN_DRAG / CAMERA_ORBIT / CAMERA_PAN`，由它独占一次鼠标手势并向现有放置、移动、选择、相机逻辑发命令。暂不搬场景存读、素材缓存和属性面板。

### 发现（按风险）
- [ ] 高：`_input()`、`_unhandled_input()`、Button 信号共同拥有一条手势，且模型、Token、相机各自保存布尔/引用状态；新增光源开关、墙体破坏等运行态操作时，存在再次双重消费输入的结构风险。
- [ ] 高：右键路径仍在事件回调中使用 `get_viewport().get_mouse_position()` 判断左栏和定位命中按钮（`main.gd:2109-2111, 2132-2136, 2273-2274`）。Godot 4.7 `gdd_0962_InputEventMouse.md` 明确 `Node._input()` 的 `event.position` 已是当前 Viewport 坐标；现有注释称其坐标系不匹配，与刚修复的左键问题相矛盾，且没有右键真实输入回归。
- [ ] 中：相机 `_orbit_dragging_yaw/_orbit_dragging_pan` 没有统一取消入口；`_notification()` 只处理关闭窗口，窗口失焦时若收不到松键，状态可能残留。后续应由统一指针状态机处理失焦、切模式、切场景和目标失效。
- [ ] 中：`tests/p1_runtime_regressions.gd` 有 65 处直接 `get/set/call` `main.gd` 私有成员；能抓现有回归，但会让结构拆分等同于重写测试。应保留少量真实输入集成测试，并把状态转换下沉成可通过公开接口测试的控制器单元测试。
- [ ] 中：`docs/architecture.md` 仍称 `main.gd` 约 400 行、`ModuleGate` 未注册；实际为 3068 行且 `project.godot` 已注册 `ModeGate/ModuleGate`。架构真值失真会继续误导后续实现边界。

### 四层依据
- [x] 项目现状：`main.gd` 函数/状态清单、`tests/p1_runtime_regressions.gd` 私有访问统计、`docs/architecture.md` 与 `project.godot` 交叉核对。
- [x] Godot `4.7-stable` 源码记录（提交 `5b4e0cb0f`）：`BaseButton::on_action_event()` 分按下/松开信号；Viewport 输入按 `_input -> GUI -> _unhandled_input` 传播。公开 raw 当前仍无法取得该未来提交，未拿 master 冒充 4.7；精确版本沿用本机运行版本和此前源码对照记录。
- [x] 官方离线资料：`gdd_0196_Using_InputEvent.md` 第 70-94 行确认输入传播次序与消费规则；`gdd_0962_InputEventMouse.md` 确认 `_input/_unhandled_input` 中 `event.position` 的 Viewport 坐标语义；`gdd_0565_Control.md` 确认原生拖放适用 Control 接收端。
- [x] 英文社区：Godot Asset Placer 1.5.4（MIT、Godot 4）明确区分放置模式、预览、左键提交和放置后变换；只采用明确生命周期思路，不直接引入编辑器插件。

## 2026-07-17 Codex P2.0 后结构治理排期与任务移交

- [x] `docs/p2_task_schedule.md` 新增 R0-R5 结构治理阶段表：行为护栏、统一指针输入、选择/Gizmo/属性面板、素材放置与缓存、场景会话、UI/相机与主脚本收口。
- [x] 决定采用逐段迁移，不一次重写 `main.gd`；每阶段先写失败测试，保持用户操作不变，完整回归、保存读回和关键手感通过后才进入下一阶段。
- [x] 结构治理期间不混入 P2.3-P2.6 新功能；Godot 行为继续执行四层调研与 4.7 源码对照卡门禁。
- [x] 已创建独立 Codex 任务 `019f6e22-4e8f-79c3-a13a-c8aefa0cbadd`，从 R0 行为基线开始，再进入 R1 `PointerInteractionController`（指针交互控制器）。

## 2026-07-17 Codex R0 行为基线与结构护栏

### 已完成
- [x] R0 已按 `docs/p2_task_schedule.md` 完成：保留 P2.0 素材按钮单一手势根修的真实输入回归，并把回归从 167 项扩展到 182 项。
- [x] `scripts/main.gd` 新增 `_cancel_pointer_gestures()`，统一清理素材候选/拖放、运行态 Token 拖动、右键/中键相机拖动等指针状态。
- [x] `_notification()` 在窗口失焦、鼠标离开窗口、应用失焦时调用统一清理；`_on_mode_changed()` 与 `_switch_to_scene()` 切模式/切场景时也调用统一清理，避免收不到松键后状态残留。
- [x] 右键菜单路径改用 `InputEventMouseButton.position`，左栏排除也改用事件自带坐标，不再在同一事件回调里另查 `get_viewport().get_mouse_position()`。
- [x] `tests/p1_runtime_regressions.gd` 增加 R0 真实输入回归：切模式清相机拖动、窗口失焦清素材/Token/相机手势、切场景清手势、右键素材菜单使用事件坐标命中真实左栏按钮。
- [x] `docs/architecture.md` 修正旧事实：`main.gd` 不再描述为约 400 行，`ModeGate/ModuleGate` 已注册；补充 R0 结构基线和 R1 协作接口。
- [x] `docs/p2_task_schedule.md` 将 R0 标为完成，R1 仍保持未开始。

### 四层调研回执
- [x] 项目现状：`scripts/main.gd` 当前约 3068 行、147 个函数，仍同时承担输入、场景、素材、选择、Gizmo、属性面板、相机与 UI；`_input()` 和 `_unhandled_input()` 依赖分支顺序与多组状态共同裁决同一鼠标手势。右键路径仍使用另查鼠标位置，与刚修复的左键事件坐标问题矛盾。
- [x] Godot `4.7-stable` 源码（提交 `5b4e0cb0f`，本地源码包 `reference/godot-4.7-stable-full.zip.zip`）：`scene/gui/base_button.cpp::BaseButton::on_action_event()` 区分按下与松开信号；`scene/main/viewport.cpp` 负责输入传播；`editor/scene/3d/node_3d_editor_plugin.cpp` 的 3D 编辑器交互以明确状态管理鼠标拖动；`scene/main/node.cpp` 与 `doc/classes/Node.xml` 确认窗口/应用通知可作为清理入口。
- [x] 官方离线资料：`gdd_0962_InputEventMouse.md` 确认 `event.position` 是当前 Viewport（视口）坐标；`gdd_0774_Viewport.md` 与 `gdd_0196_Using_InputEvent.md` 作为输入传播依据；`gdd_0532_BaseButton.md` 作为按钮按下/松开语义依据；Node 通知文档作为失焦清理依据。
- [x] 英文社区/现成方案：Godot Asset Placer 与 GoPlacer 类插件采用“候选、预览、提交、取消”的生命周期，适合复用思路；但它们是 Godot 编辑器插件，不直接引入 Gvtt 运行时工具，避免改变当前 GM 操作方式和现有插件边界。

### Godot 源码行为 -> 本地实现 -> 自动验证
- [x] 输入事件携带事件发生时的坐标 -> 右键菜单和左栏排除统一使用 `InputEventMouseButton.position` -> 新增真实输入测试把系统鼠标位置与事件位置分开，仍能命中左栏素材按钮。
- [x] 3D 视口拖动需要明确开始/取消边界 -> `_cancel_pointer_gestures()` 统一取消素材、Token 和相机手势 -> 新增窗口失焦、切模式、切场景回归验证所有相关状态清空。
- [x] 窗口/应用通知是丢失松键时的清理机会 -> `_notification()` 覆盖窗口失焦、鼠标离开窗口、应用失焦 -> 新增回归验证候选模型、预览、运行态拖动和相机拖动不会残留。
- [x] Button（按钮）按下/松开语义继续保留上一轮根修 -> 本轮只加 R0 取消护栏，没有恢复 `button_down + pressed` 双业务入口 -> 连续回归仍包含素材单一手势用例。

### 验证与边界
- [x] R0 修改前，隔离测试壳基线为 `P1_RUNTIME_RESULT {"assertions":167,"failed":0}`。
- [x] R0 修改后，Godot `4.7-stable` 隔离无窗口回归为 `P1_RUNTIME_RESULT {"assertions":182,"failed":0,"failures":[]}`。
- [x] `git diff --check` 覆盖 `scripts/main.gd`、`tests/p1_runtime_regressions.gd`、`docs/architecture.md`、`docs/p2_task_schedule.md`、`devlog/DEVLOG.md`，未发现空白格式问题。
- [x] 原项目直接启动测试仍会在加载 `addons/gdstyle/gdstyle.gdextension` 时触发 Godot Rust 4.5 API / Godot 4.7 运行时不兼容崩溃；本轮继续使用不加载 `gdstyle`、但共享同一份项目脚本/场景/测试资源的隔离测试壳，未把扩展崩溃冒充产品代码失败。
- [ ] 未进入 R1：尚未新增 `PointerInteractionController`（指针交互控制器），也未迁移选择、Gizmo、属性面板、素材缓存、场景会话、UI 或相机模块。
- [ ] 当前仍有文件权限噪音：`devlog/DEVLOG.md`、`docs/architecture.md` 与 `scripts/main.gd` 的 Git 可执行位显示从 `100755` 变为 `100644`；已尝试 `git update-index --chmod=+x` 和 Git for Windows 的 `chmod +x`，Windows 工作区仍报告模式差异。普通文件内容已完成，权限噪音不影响 R0 运行结果。
- [ ] R1 门槛：先保持 R0 182/182 通过，再写 `PointerInteractionController` 的失败测试；只迁移鼠标手势裁决，不顺带做 P2.3-P2.6 新功能。

## 2026-07-17 Codex R1 统一指针交互控制器

### 已完成
- [x] 先写失败测试：`tests/p1_runtime_regressions.gd` 新增 `PointerInteractionController` 合约测试，验证素材候选/拖放、运行态 Token 候选/拖动、相机旋转/平移互斥；初始红灯为“R1 指针交互控制器脚本不存在”。
- [x] 新增 `scripts/pointer_interaction_controller.gd`：用 `IDLE / MODEL_CANDIDATE / MODEL_DRAG / RUNTIME_TOKEN_CANDIDATE / RUNTIME_TOKEN_DRAG / CAMERA_ORBIT / CAMERA_PAN` 统一保存当前鼠标手势拥有者。
- [x] `scripts/main.gd` 移除素材拖放、运行态 Token 候选/拖动、相机右键/中键拖动的多组散落状态，改为向 `_pointer_controller` 登记、查询、切换和取消。
- [x] 保留用户操作方式：素材按钮轻微移动仍按点击处理，超过 6 像素才拖放；Token 短按仍选中，超过 6 像素才移动；右键旋转、中键平移和滚轮缩放手感不改。
- [x] `tests/p1_runtime_regressions.gd` 相关断言改为检查控制器公开接口，不再直接读写已迁出的旧私有变量；仍保留真实鼠标输入回归。
- [x] `docs/p2_task_schedule.md` 标记 R1 完成；`docs/architecture.md` 补充 `PointerInteractionController` 的职责边界。

### 四层调研回执
- [x] 项目现状：R0 后 `main.gd` 已有统一取消入口，但 `_input()`、`_unhandled_input()` 和素材按钮仍依赖多组私有状态裁决同一鼠标手势；测试也直接读写这些私有状态，阻碍拆分。
- [x] Godot `4.7-stable` 源码（提交 `5b4e0cb0f`，本地源码包 `reference/godot-4.7-stable-full.zip.zip`）：`scene/main/viewport.cpp::Viewport::push_input()` 体现 `_input -> GUI -> _unhandled_input` 链；`scene/gui/base_button.cpp::BaseButton::on_action_event()` 区分按钮按下与合格松开；`editor/scene/3d/node_3d_editor_plugin.cpp` 与 `modules/navigation_3d/editor/navigation_obstacle_3d_editor_plugin.cpp` 的 3D 视口交互用明确状态和事件坐标裁决拖动。
- [x] 官方离线资料：`gdd_0774_Viewport.md` 与 `gdd_0196_Using_InputEvent.md` 作为输入传播依据；`gdd_0962_InputEventMouse.md` 确认 `event.position` 的 Viewport 坐标语义；`gdd_1421_ProjectSettings.md` 记录 Godot 自带 `gui/common/drag_threshold`，本项目继续使用既有 6 像素阈值以保持手感。
- [x] 英文社区/现成方案：Godot Asset Placer 与 GoPlacer 类编辑器插件采用“选择资产 -> 预览 -> 放置/取消”的生命周期；R1 只吸收“明确生命周期和唯一手势拥有者”思路，不引入编辑器插件。

### Godot 源码行为 -> 本地实现 -> 自动验证
- [x] 视口输入会按阶段传播，已处理事件应阻断后续分支 -> `main.gd` 先由控制器判断当前手势拥有者，再决定是否消费事件 -> 真实输入回归覆盖素材按钮、Token 和相机路径。
- [x] Button 按下和松开是不同阶段 -> 素材按钮按下只登记 `MODEL_CANDIDATE`，松开时由控制器状态决定点击或拖放 -> 回归覆盖轻微移动仍点击、超过阈值才拖放、拖放后不激活连续放置。
- [x] 3D 视口拖动需要开始、更新、取消边界 -> 控制器保存相机旋转/平移互斥状态，失焦、离窗、切模式、切场景统一 `reset()` -> 回归覆盖相机手势不会残留。
- [x] Token 移动应和短按选择互斥 -> 控制器保存 `RUNTIME_TOKEN_CANDIDATE` 与 `RUNTIME_TOKEN_DRAG`，`MovementService` 只在拖动状态提交路线 -> 回归覆盖 5 像素不拖、6 像素触发拖动判定。

### 验证与边界
- [x] 隔离测试壳导入通过，Godot `4.7-stable.official.5b4e0cb0f` 已注册 `PointerInteractionController`。
- [x] 隔离无窗口完整回归通过：`P1_RUNTIME_RESULT {"assertions":187,"failed":0,"failures":[]}`。
- [x] 未使用 `:=`；未恢复 `button_down + pressed` 双业务入口。
- [x] 原项目直接启动仍受 `addons/gdstyle/gdstyle.gdextension` 的 Godot Rust 4.5 API / Godot 4.7 运行时不兼容影响；本轮继续用隔离测试壳验证项目脚本行为。
- [ ] 未进入 R2：选择、Gizmo、属性面板仍在 `main.gd`；没有迁移素材放置缓存、场景会话、UI 或相机模块。
- [ ] 未做 P2.3-P2.6 新功能；没有新增光源开关、战斗碰撞、LOS 或墙体破坏。
- [ ] 下一阶段 R2 门槛：先写选择/Gizmo/属性面板失败测试，确认运行态只读选择、编辑态 Gizmo、点击空地取消和切模式清理行为，再迁移唯一选择控制器。
## 2026-07-17 Codex R2 选择、Gizmo 与属性面板收口

### 已完成
- [x] 先写失败测试：`tests/p1_runtime_regressions.gd` 新增 `SelectionController`（选择控制器）契约测试，红灯确认为缺少 `scripts/selection_controller.gd`。
- [x] 新增 `scripts/selection_controller.gd`：统一保存当前选中对象与 `EntityProperties`（实体属性组件），发出 `selection_changed`（选择变化）信号，并在选中节点 `tree_exiting` 时自动清空。
- [x] `scripts/main.gd` 不再保存 `_prop_target` / `_prop_target_props` 第二份选中账本；`_select_entity()`、`_deselect()`、删除、Gizmo 结束和属性面板回写都通过 `_get_selected_target()` / `_get_selected_properties()` 读取控制器状态。
- [x] `Gizmo3D`（变换手柄）和右侧属性面板改为由 `_refresh_selection_views()` 统一刷新；运行态仍只读，编辑态仍显示完整属性字段。
- [x] `docs/p2_task_schedule.md` 标记 R2 完成；`docs/architecture.md` 增补 R2 控制器边界。

### 四层调研回执
- [x] 项目现状：R1 后 `main.gd` 仍同时承担选择真值、Gizmo 和属性面板刷新；测试仍直接读旧私有状态。R2 目标是收口选择真值，不重写素材、场景、UI 或相机。
- [x] Godot `4.7-stable` 源码（提交 `5b4e0cb0f`）：`Node3DEditorViewport::_find_items_at_pos()` / `_select_ray()` / `_select_clicked()` 完成拾取与选择更新；`EditorSelection::add_node()` / `remove_node()` / `clear()` 保存选择集合并发 `selection_changed`；`EditorNode::edit_node()` / `_edit_current()` 与 `EditorInspector::edit()` 把当前对象交给检查器；`Node3DEditor::_selection_changed()` 响应选择变化刷新 Gizmo。
- [x] 官方资料：离线 Godot 4.7 `EditorSelection` 文档说明 `add_node()` 不会自动编辑 Inspector（检查器），需要 `EditorInterface.edit_node()`；`EditorInspector` 文档说明属性面板编辑对象和属性列表的关系；`InputEventMouse.position` 仍作为当前 Viewport（视口）坐标真值。
- [x] 社区/插件：本项目已有 `addons/Gizmo3DScript`，`plugin.cfg` 明确其目标是运行时 3D move/scale/rotation gizmo；Godot Asset Library 的 Gizmo3D 仍是运行时插件方向。未引入新插件，继续复用现有 Gizmo3D。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] Godot 选择集合是唯一真值 -> 本地 `SelectionController` 是当前选中唯一真值 -> 控制器契约测试验证选中、清空、对象释放后失效。
- [x] Godot 选择变化后刷新 Inspector/Gizmo -> 本地 `selection_changed` 后调用 `_refresh_selection_views()` -> 编辑态真实点击选中、Gizmo 可见、选中数为 1。
- [x] Godot 清空选择会同步清理显示端 -> 本地 `_deselect()` 只清控制器，视图统一刷新 -> 运行态取消选择后面板隐藏、Gizmo 选中数为 0，`SelectedItem` 不泄漏。
- [x] Godot 不把检查器当选择真值 -> 本地属性面板回写只从控制器取对象和属性组件 -> MOVE、可见性、LOS（视线遮挡）等原有回写保持。

### 验证
- [x] 失败测试红灯：隔离 Godot 4.7 回归先失败于 `R2 selection controller script is missing`。
- [x] 导入解析通过：Godot `4.7.stable.official.5b4e0cb0f` 注册 `SelectionController`。
- [x] 最终隔离无窗口回归通过：`P1_RUNTIME_RESULT {"assertions":194,"failed":0,"failures":[]}`。

### 未做
- [ ] 未进入 R3：素材预览、落点、墙面吸附、实例化和素材缓存仍留在后续阶段。
- [ ] 未进入 R4/R5：场景会话、UI 构建和相机参数仍未拆分。
- [ ] 未实现 P2.3-P2.6 新功能：没有新增光源开关、战斗碰撞、LOS 闭环或墙体破坏。

### 新问题
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-17 | `tests/p1_runtime_regressions.gd` 原有中文提示文本在一次重编码后暴露出多处旧乱码断裂；本轮只修复解析所需的测试提示与两个易受编码影响的断言，后续可单独做测试文本编码清理。 | 已补救，不阻塞 R2；不作为功能改动 |

## 2026-07-17 Codex R3 素材放置与缓存边界

### 已完成
- [x] 先写失败测试：`tests/p1_runtime_regressions.gd` 新增 `PlacementController`（放置控制器）契约测试，要求存在 `scripts/placement_controller.gd`，并暴露拖放预览、放置和清理入口。
- [x] 新增 `scripts/placement_controller.gd`，收口素材拖放预览、落点计算、交互物体墙面吸附、模型实例化、对象组件挂载、`TraversalProperties`（通行属性）和 `PickProxy`（拾取代理）创建。
- [x] `scripts/main.gd` 保留 `_place_model()`、`_create_drag_preview_model()`、`_get_model_drop()` 等兼容包装函数，但实际逻辑委托给 `_placement_controller`；`LibraryManager` 继续只负责素材库与持久缓存。
- [x] 测试不再直接读取 `_drag_preview_root`，改用 `PlacementController.has_drag_preview()` 检查预览生命周期。
- [x] `docs/p2_task_schedule.md` 标记 R3 完成；`docs/architecture.md` 补充 `PlacementController` 与 `LibraryManager` 的职责边界。

### 四层调研回执
- [x] 项目现状：R2 后 `main.gd` 仍保留 `_create_drag_preview_model()`、`_update_drag_preview()`、`_place_model()`、`_load_model_instance()`、`_get_model_drop()`、`_raycast_wall()` 和对象组件挂载逻辑；`LibraryManager` 已经负责 GLB 导入、运行时 GLTF 解析和 `user://library_cache/models/` 持久 `.scn` 缓存。
- [x] Godot `4.7-stable` 源码（提交 `5b4e0cb0f`，本地源码包 `reference/godot-4.7-stable-full.zip.zip`）：`core/io/resource_loader.cpp::load_threaded_request()` / `load_threaded_get_status()` / `load_threaded_get()` 负责资源加载；`modules/gltf/gltf_document.cpp::append_from_file()` -> `_parse()` -> `generate_scene()` 负责 GLTF 读入成节点树；`scene/resources/packed_scene.cpp::PackedScene::instantiate()` 负责实例化；`editor/docks/scene_tree_dock.cpp::_files_dropped()` -> `_perform_instantiate_scenes()` 用 `ResourceLoader::load()`、`PackedScene::instantiate()`、`add_child(..., true)`、`set_owner()` 完成编辑器场景实例化。
- [x] 官方离线资料：`gdd_1476_ResourceLoader.md` 确认线程加载与缓存模式；`gdd_0929_GLTFDocument.md` 确认 `append_from_file()` / `generate_scene()`；`gdd_1006_PackedScene.md` 确认 `instantiate()` / `pack()`；`gdd_1477_ResourceSaver.md` 确认资源保存；`gdd_0187_Runtime_file_loading_and_saving.md` 确认运行时 GLTF 加载路径。
- [x] 英文社区/插件：Godot Asset Placer 1.5.4（MIT，Godot 4.3+）和 GoPlacer（GPLv3，Godot 4.5）都采用“选择资产 -> 预览 -> 射线落点/吸附 -> 放置”的控制器式流程；它们是编辑器插件，不直接引入 Gvtt 运行时工具，只采用职责划分思路。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] `ResourceLoader` 负责加载和缓存 -> 本地 `LibraryManager` 继续负责导入素材和持久 `.scn` 缓存，`PlacementController` 只消费可实例化资源 -> 模型缓存回归仍覆盖导入、缓存重建和删除。
- [x] `PackedScene::instantiate()` 只生成节点树 -> 本地 `PlacementController.load_model_instance()` / `place_model()` 负责实例化，再把对象根放进 `_content_root` -> 连续同点放置两份同名模型仍生成两个可读对象。
- [x] Godot 编辑器 `_perform_instantiate_scenes()` 使用 `add_child(..., true)` 和 `set_owner()` -> 本地 `PlacementController.place_model()` 继续 `_content_root.add_child(root, true)` 并设置 owner -> 同名对象不退回 `@Node3D@数字`。
- [x] 编辑器/社区放置器把预览和确认放置分开 -> 本地 `create_drag_preview()` / `update_drag_preview()` / `clear_drag_preview()` / `place_model()` 分开 -> 拖放开始有预览、松开后清理预览、一次拖放只放一个对象。
- [x] 墙面吸附是落点阶段职责 -> 本地 `get_model_drop()` 和 `_raycast_wall()` 进入 `PlacementController` -> 原有交互物体吸附路径保留。

### 验证
- [x] 隔离工程导入解析通过：Godot `v4.7.stable.official.5b4e0cb0f` 无导入阶段脚本错误。
- [x] 隔离无窗口回归通过：`P1_RUNTIME_RESULT {"assertions":194,"failed":0,"failures":[]}`。
- [x] `git diff --check -- scripts/placement_controller.gd scripts/main.gd tests/p1_runtime_regressions.gd` 通过。
- [x] `rg -n ":=" scripts/placement_controller.gd scripts/main.gd tests/p1_runtime_regressions.gd` 未发现禁用写法。

### 未做
- [ ] 未改 `LibraryManager` 的缓存策略、文件指纹或删除语义；R3 只重划放置边界。
- [ ] 未进入 R4/R5：场景会话、UI 构建和相机参数维护仍在后续阶段。
- [ ] 未实现 P2.3-P2.6 新功能：没有新增光源开关、战斗碰撞、LOS（视线遮挡）闭环或墙体破坏。

### 下一阶段门槛
- [ ] R4 先写场景会话控制器失败测试，再迁移新建、切换、保存、脏标记、旧对象迁移和运行服务清理；不得顺带重做 UI 或相机。
- [ ] R4 先写场景会话控制器失败测试，再迁移新建、切换、保存、脏标记、旧对象迁移和运行服务清理；不得顺带重做 UI 或相机。

## 2026-07-17 Codex P2.3 光源物件运行态开关

### 已完成
- [x] 新增 `LightProperties`（光源专属组件）运行态方法：`is_on` 保存开关状态，`energy/color/light_range/casts_shadow/spot_angle` 保存基础灯光参数；`apply_to()` 把组件状态同步到已有真实灯光。
- [x] 光源栏新增内置“点光源”工具：放置时直接创建 Godot `OmniLight3D`（全向点光源）和可点选标记，不再依赖导入模型原点猜测发光位置。
- [x] `PlacementController` 放置内置点光源时会挂 `LightProperties` 并确保真实灯光节点存在；新放置的光源能随 `_content_root` owner 链进入 `PackedScene` 保存。
- [x] `main.gd` 运行态属性面板新增光源专用按钮：只在选中光源物件时显示；按钮切换 `LightProperties.is_on`，同步 `Light3D.light_energy` 与 `shadow_enabled`，刷新“开启/关闭”状态并标记场景已改。
- [x] 读回/迁移路径只会对已有 `Light3D` 应用保存的 `is_on` 状态；导入模型暂不自动补灯，复杂“模型外观 + 发光点偏移”后置。

### 四层调研回执
- [x] 项目现状：`docs/design.md` 与 `docs/p2_task_schedule.md` 明确 P2.3 是跑团运行态光源物件开关，状态随场景保存/加载；不是 P3 环境光、雾或场景气氛。现有 `CastView` 已共享主窗口 `World3D`，运行态面板已有只读光源状态但缺按钮和真实灯光应用。
- [x] Godot 源码：项目版本为 Godot `4.7.stable` / Forward+。本地源码包只完整覆盖 `PackedScene` 保存链；在线核对 Godot 官方 `4.7-stable` 源码后，确认 `Viewport` 通过 `world_3d` 绑定 3D 世界，`Camera3D` 在所属 viewport 内作为当前相机，`VisualInstance3D` 把可见性和层同步到渲染服务；本项目据此不复制场景，只改共享世界中的同一盏灯。
- [x] 官方离线文档：`gdd_0641_Light3D.md` 核对 `light_color/light_energy/shadow_enabled/light_cull_mask`；`gdd_0675_OmniLight3D.md` 核对 `omni_range`；`gdd_0742_SpotLight3D.md` 核对 `spot_range/spot_angle`；`gdd_0780_VisualInstance3D.md` 核对 `Light3D` 属于 `VisualInstance3D` 且受相机 `cull_mask`/层影响；`gdd_0774_Viewport.md`、`gdd_0786_Window.md`、`gdd_0540_Camera3D.md` 核对投屏 `World3D` 与相机链；`gdd_1006_PackedScene.md` 核对 owner 保存要求；`gdd_0532_BaseButton.md`、`gdd_0538_Button.md` 核对按钮行为。
- [x] 社区/现成方案：Godot 社区常见运行态开关做法是直接切 `Light3D.visible` 或调灯光能量；本项目采用“内置点光源对象 + 保存组件状态 + 把 `light_energy` 切到 0/恢复原值”的方式，避免把导入模型本身当作隐藏灯位，也避免把 P2.3 混成全局气氛系统。未引入插件。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] `Light3D` 参数驱动渲染中的灯光强度 -> `LightProperties._apply_to_light()` 设置 `light_energy = energy if is_on else 0.0`，并让阴影只在开灯时启用 -> Godot 符号解析识别 `LightProperties` 7 个导出字段、9 个函数、1 个信号。
- [x] `PackedScene.pack()` 只保存 owner 链中的节点 -> `PlacementController` 给内置点光源对象、`LightProperties` 和 `RuntimeLight` 设置 `_content_root` owner -> `git diff --check` 通过，脚本符号解析通过。
- [x] 投屏窗口共享同一 `World3D`，不是复制节点 -> P2.3 只改内容根中的真实 `Light3D`，`CastView` 不改 -> 需要在可见 Godot 窗口中人工确认投屏同步光照变化。

### 验证与边界
- [x] `script_manage(find_symbols)` 通过：`scripts/light_properties.gd`、`scripts/main.gd`、`scripts/placement_controller.gd` 均可被 Godot 解析出符号。
- [x] `rg -n ":=" scripts/light_properties.gd scripts/main.gd scripts/placement_controller.gd` 未发现禁用写法；`git diff --check -- scripts/light_properties.gd scripts/placement_controller.gd scripts/main.gd` 通过。
- [ ] 无窗口启动被 `godot-rust` 扩展初始化崩溃拦住，未能完成运行态自动回归；这不是 GDScript 解析错误，但本轮不能冒充运行验证通过。
- [ ] 仍需 GM 可见窗口验证：在光源栏选择“点光源” -> 放到地图 -> 进入运行态 -> 选中光源 -> 点“关闭/开启光源” -> 保存场景 -> 切走/切回或重启读回 -> 打开投屏确认光照同步且 GM 面板不出现在玩家窗口。
## 2026-07-17 Codex P2.3 点光源拖拽预览卡死修复
### 已完成
- [x] 用户反馈从光源栏拖出“点光源”时卡死并报错；本轮定位到拖拽预览函数把 `GeometryInstance3D`（几何体实例）的 `transparency` 和 `cast_shadow` 属性写到了所有 `VisualInstance3D`（可见 3D 节点）上，而 `OmniLight3D`（全向点光源）也是 `VisualInstance3D`，但不是几何体。
- [x] `scripts/placement_controller.gd::_apply_drag_preview_visuals()` 已改为只处理 `GeometryInstance3D`，因此点光源子节点不会再被写入几何体专属属性。
- [x] 离线 API 依据：`reference/Godot 4.7 Dooc/Godot Engine 4.7 documentation in English MD/gdd_0780_VisualInstance3D.md` 显示 `Light3D` 与 `GeometryInstance3D` 是 `VisualInstance3D` 的不同子类；`gdd_0602_GeometryInstance3D.md` 显示 `transparency` 与 `cast_shadow` 属于 `GeometryInstance3D`。
- [x] 验证：`rg -n ":=" scripts/placement_controller.gd scripts/main.gd scripts/light_properties.gd` 未发现禁用写法；`git diff --check -- scripts/placement_controller.gd scripts/main.gd scripts/light_properties.gd devlog/DEVLOG.md` 通过。
### 限制与后续
- [ ] 本轮一开始误清了 MCP 临时日志缓冲，未能保留用户现场那条红字原文；Godot Debugger 面板未被清空。后续若再次出现红字，应先读 `logs_read(source="editor", include_details=true)` 再做判断。
- [ ] 本地 `reference/godot_4_7_source` 片段缺少 `VisualInstance3D/GeometryInstance3D/Light3D` 对应 C++ 定义文件，本轮不能声称完成这几类的 Godot 源码级行为链对照；本修复依据为离线类文档与项目代码边界。
## 2026-07-17 Codex P2.3 光源编辑态属性栏补全
### 已完成
- [x] 修正用户反馈：选中内置“点光源”时右侧属性栏不应继续显示“最大生命/可破坏/可透光/可当掩体”等非光源字段。
- [x] `scripts/main.gd` 新增光源专属编辑区：默认开启、颜色、亮度、范围、投射阴影。颜色使用 Godot 原生 `ColorPickerButton`（颜色选择按钮），数值使用 `SpinBox`（数字输入框）。
- [x] 选中光源时只显示名称、玩家可见和光源专属参数；选中非光源时隐藏光源编辑区，保留原有字段。
- [x] 编辑态修改光源颜色/亮度/范围/阴影/默认开关时写回 `LightProperties`，并立即调用 `apply_to()` 同步到真实 `Light3D`。
### 调研依据
- [x] 项目现状：`main.gd::_build_prop_panel()` 原先固定创建通用属性控件；`_refresh_selection_views()` 只按运行态/编辑态切换，没有按光源实体类型分流。
- [x] 官方离线文档：`gdd_0560_ColorPickerButton.md` 确认 `ColorPickerButton.color` 与 `color_changed(color: Color)`；`gdd_0739_SpinBox.md` 与 `gdd_0710_Range.md` 确认数值输入和 `set_value_no_signal()`；`gdd_0641_Light3D.md`、`gdd_0675_OmniLight3D.md` 确认 `light_energy`、`shadow_enabled`、`omni_range`。
- [x] 社区/现成方案：本轮没有引入插件；采用 Godot 原生控件组成项目自己的属性栏，等价于“借 Godot 检查器常用控件”，不是复制完整 Godot Inspector。
### 验证与边界
- [x] `script_manage(find_symbols)` 成功解析 `scripts/main.gd`，识别新增 `_populate_light_editor()` 与 5 个光源属性回调。
- [x] `rg -n ":=" scripts/main.gd scripts/light_properties.gd scripts/placement_controller.gd` 未发现禁用写法；`git diff --check -- scripts/main.gd scripts/light_properties.gd scripts/placement_controller.gd devlog/DEVLOG.md` 通过。
- [ ] 本轮未成功完成启动级 `project_run` 验证；仍需在 Godot 可见窗口人工确认：选中点光源后右栏显示光源参数，调色盘改色、亮度/范围改变会实时影响地图和投屏。
## 2026-07-17 Codex P2.3 光源面板与可视标记精简
### 已完成
- [x] 按用户反馈，选中光源物件时右侧编辑态属性栏隐藏“玩家可见”。该字段仍保留给普通模型/Token/墙体等对象使用，不再出现在点光源的光源参数区。
- [x] 新放置的内置“点光源”不再显示 `PickProxyMarker` 可视标记；`PickProxy` 的隐藏拾取 `Area3D` 仍保留，用于点击选中光源。
- [x] 对已存在的光源物件，`PlacementController.attach_entity_type_properties()` 会把旧 `PickProxy.show_marker` 置为 `false`，并清理已有 `PickProxyMarker`。
### 验证与边界
- [x] `rg -n ":=" scripts/main.gd scripts/placement_controller.gd scripts/pick_proxy.gd` 未发现禁用写法；`git diff --check -- scripts/main.gd scripts/placement_controller.gd scripts/pick_proxy.gd devlog/DEVLOG.md` 通过。
- [ ] 本轮未完成 Godot 运行态/符号工具验证；仍需在可见窗口确认：选中点光源时不显示“玩家可见”，新放置或读回点光源不再显示额外标记框，但仍能被点击选中。
## 2026-07-17 Codex P2.3 光源标记与选中外框修正
### 已完成
- [x] 修正上一轮误判：用户说的“大大的框框”是 Gizmo3D 的选择外框，不是 `PickProxyMarker` 小圆球；内置点光源仍需要一个可见小圆球给 GM 点击和识别。
- [x] `scripts/main.gd::_refresh_selection_views()` 在选中光源时设置 `_gizmo.show_selection_box = false`，因此点光源不再显示巨大选择外框；切换模式或清空选择时恢复默认外框设置，普通模型不受影响。
- [x] `scripts/pick_proxy.gd` 增加 `marker_color`、`set_marker_enabled()`、`set_marker_color()`，标记球材质不再写死黄色，而是用 `LightProperties.color` 同步 `albedo_color` 与 `emission`。
- [x] `scripts/placement_controller.gd` 只给内置 `builtin_light` 点光源打开标记球，普通模型仍默认无标记；读回/迁移旧点光源时恢复标记球并同步颜色。
### 调研依据
- [x] 项目现状：`PlacementController` 上一轮把光源 `PickProxy.show_marker` 设为 `false` 并清理 `PickProxyMarker`，这与“无模型点光源需要可见锚点”的交互目标冲突。
- [x] 插件对照：`addons/Gizmo3DScript/gizmo3D.gd` 暴露 `show_selection_box`，并在 `_update_transform_gizmo()` 内把四个选择框渲染实例的可见性绑定到该布尔值；本轮不改插件源码，只在选中光源时切换该开关。
- [x] 官方离线文档：`gdd_0641_Light3D.md` 确认 `Light3D.light_color`；`gdd_1063_StandardMaterial3D.md` 与 `BaseMaterial3D` 文档确认标记球材质可设置 `albedo_color`、`emission`、透明和不受光照显示。
- [x] 社区/现成方案：本轮不引入新插件；沿用项目现有 PickProxy + Gizmo3D 方案，只修正“光源锚点显示”和“选中外框显示”的职责边界。
### 验证与边界
- [x] Godot 4.7-stable 编辑器连接正常；`script_manage(find_symbols)` 成功解析 `pick_proxy.gd`、`placement_controller.gd`、`main.gd`、`light_properties.gd`，识别新增字段和函数。
- [x] `rg -n ":=" scripts/main.gd scripts/placement_controller.gd scripts/pick_proxy.gd scripts/light_properties.gd` 未发现禁用写法；`git diff --check -- scripts/main.gd scripts/placement_controller.gd scripts/pick_proxy.gd` 通过。
- [ ] 未做可见窗口人工验证：仍需在 Godot 里放置点光源，确认小圆球颜色跟调色盘一致、巨大选择外框消失、普通模型选中外框仍正常。
## 2026-07-18 Codex P2.3 光源标记运行态隐藏
### 已完成
- [x] 按用户反馈修正：内置点光源的小球标记只作为 GM 编辑态定位辅助，运行态默认不可见；真实 `OmniLight3D` 仍继续照亮场景。
- [x] `scripts/main.gd::_on_mode_changed()` 新增 `_apply_pick_proxy_markers_for_mode()`，切到编辑态显示 `PickProxyMarker`，切到运行态隐藏所有 `PickProxy` 的可视标记。
- [x] `scripts/main.gd::_sync_light_marker()` 在同步光源颜色后立即按 `ModeGate.is_edit()` 重设标记显隐，避免运行态刷新颜色时把小球重新露出来。
### 调研依据
- [x] 项目现状：`PickProxy.set_edit_visible()` 已存在但没有统一接入 ModeGate；因此标记球创建后会一直可见。
- [x] 官方离线文档：`gdd_0673_Node3D.md` 确认 `Node3D.visible` / `set_visible()` / `hide()` 控制 3D 节点渲染；`PickProxyMarker` 是 `MeshInstance3D`，属于 `Node3D` 可见链。
- [x] 社区/现成方案：不引入插件；沿用项目既有 ModeGate“功能自报归属”模式，新增一个专管拾取标记显隐的小函数。
### 验证与边界
- [x] Godot 4.7-stable `script_manage(find_symbols)` 成功解析 `scripts/main.gd` 与 `scripts/pick_proxy.gd`，识别新增 `_apply_pick_proxy_markers_for_mode()` / `_set_pick_proxy_markers_visible_recursive()`。
- [x] `rg -n ":=" scripts/main.gd scripts/pick_proxy.gd scripts/placement_controller.gd` 未发现禁用写法；`git diff --check -- scripts/main.gd scripts/pick_proxy.gd scripts/placement_controller.gd` 通过。
- [ ] 未做可见窗口人工验证：需放置点光源后切到运行态确认小球消失、光照仍在、仍可通过拾取代理选中光源。
## 2026-07-18 Codex P2.3 光源标记球尺寸修正
### 已完成
- [x] 修正用户反馈：点光源编辑态小球过大且上下拉长。根因是 `SphereMesh` 只设置 `radius = 0.3`，未同步默认 `height = 1.0`。
- [x] `scripts/pick_proxy.gd` 新增 `MARKER_VISUAL_RADIUS = 0.15`，默认小球缩小一半；新增 `_set_sphere_mesh_radius()` 同时设置 `radius` 和 `height = radius * 2.0`，保持正球。
- [x] `docs/entity_properties_schema.md` 更新光源可视标记说明：编辑态半径 `0.15` 米、正球、运行态/投屏不可见，真实光照仍由 `OmniLight3D` 提供。
- [x] 按用户继续反馈，`PickProxyMarker` 材质启用 `BaseMaterial3D.fixed_size`，屏幕显示大小不再随相机远近变化。
### 调研依据
- [x] 项目现状：`PickProxy._create_marker()` 只设置 `SphereMesh.radius`，`fit_to_aabb()` 也只改半径，导致高度可能保留默认值。
- [x] 官方离线文档：`gdd_1059_SphereMesh.md` 确认 `SphereMesh.height` 默认 `1.0`、`radius` 默认 `0.5`，`height` 是球的完整高度。
- [x] 官方离线文档：`gdd_0864_BaseMaterial3D.md` 确认 `fixed_size` 会让对象不管距离远近都按同一屏幕大小渲染；当前本地 4.7 源码片段缺少材质实现文件，源码层不能补齐。
### 验证与边界
- [x] Godot 4.7-stable `script_manage(find_symbols)` 成功解析 `scripts/pick_proxy.gd`，识别 `_set_sphere_mesh_radius()`；`mat.fixed_size = true` 未导致脚本解析失败。
- [x] `rg -n ":=" scripts/pick_proxy.gd scripts/main.gd scripts/placement_controller.gd` 未发现禁用写法；`git diff --check -- scripts/pick_proxy.gd docs/entity_properties_schema.md devlog/DEVLOG.md` 通过。
- [ ] 未做可见窗口人工验证：需在编辑态放置点光源，确认小球约为原先一半、不再上下拉长，并且拉远/拉近相机时屏幕大小基本不变。
## 2026-07-18 Codex P2.4/P2.5 合并边界调研
### 调研回执
- [x] 项目现状：`docs/design.md` 已把拾取层、战斗层、迷雾层拆开；`PickProxy` 注释明确禁止用其旋转后会放大的 AABB（轴对齐包围盒）判断挡枪或 LOS（视线）。`WallProperties` 已分别保存 `blocks_shot` 与 `blocks_los`，证明两种遮挡语义需要独立开关。当前仅拾取层已落地，`CombatBody` 与 `LOSOccluder` 均未实现。
- [x] Godot `4.7-stable` 源码：`servers/physics_3d/physics_server_3d.h` 的 `PhysicsDirectSpaceState3D::RayParameters` 包含 `collision_mask`、`collide_with_bodies`、`collide_with_areas`；`RayResult` 返回位置、法线、碰撞对象和形状。`servers/physics_3d/physics_server_3d.cpp` 的 `PhysicsRayQueryParameters3D::create()` 保存查询参数，`PhysicsDirectSpaceState3D::_intersect_ray()` 将参数交给底层 `intersect_ray()`；`scene/3d/physics/collision_object_3d.cpp::set_collision_layer()` 把层号写入 `PhysicsServer3D` 的物理体或区域接口。
- [x] 官方资料：离线 `gdd_0255_Ray-casting.md`、`gdd_1407_PhysicsRayQueryParameters3D.md`、`gdd_0554_CollisionObject3D.md` 确认射线可按物理体/区域和 32 个碰撞层筛选；`gdd_0644_LightOccluder2D.md` 与 `gdd_0989_OccluderPolygon2D.md` 只覆盖二维光影遮挡。官方 `godot-demo-projects` 文件树有 2D/3D 光影和射线测试，但没有战争迷雾/可见多边形完整演示，`3d/visibility_ranges` 只是 HLOD（分层细节）渲染优化。
- [x] 英文社区/开源方案：`d-bucur/godot-vision-cone` 用多方向二维射线生成视野形状，支持 Godot 4、测试到 4.4.1、MIT/Apache-2.0，但只支持 2D，作者标注调试绘制仍有缺陷；`AreaOfSight2D 1.1` 是 Godot 4.0 社区二维视野插件，LGPLv3，2024-06-10 发布；`Visibility Polygon 1.0.0` 使用 O(N log N) 活动边扫描避免拐角漏视，Godot 4/CC0，但属于新发布、零评分的二维方案。三者只能借鉴“二维遮挡线段 -> 可见区域”的模式，不能原样接入 Gvtt 的 3D 世界。
### 方案结论
- [x] P2.4 与 P2.5 同一轮设计、分阶段实现：先完成 P2.4 的独立 3D `CombatBody` 和单条射击线查询，再做 P2.5 的地面投影 `LOSOccluder`、可见区域计算与迷雾显示。
- [x] 可共用“遮挡源”概念、物件生命周期、销毁/禁用通知，以及局部盒或轮廓的源几何提取；不得共用 `PickProxy` AABB，也不得让 `CombatBody` 直接兼任 `LOSOccluder`。
- [x] 算法保持分离：挡枪线是按战斗物理层执行一次 3D `intersect_ray()`；战争迷雾是把遮挡轮廓投影到地面后计算整片二维可见区域，再交给迷雾显示。即使 LOS 内部可能使用多条射线，也不是与挡枪线相同的查询合同。
- [x] 独立语义保留：玻璃、烟雾、矮掩体等会出现“挡枪不挡视线”或“挡视线不挡枪”，继续以 `blocks_shot` / `blocks_los` 分别控制；P2.6 的墙体破坏同时关闭两者，但不把两者合并成一个字段。
### 未做
- [ ] 本轮未修改功能代码、场景、碰撞层或测试；仅完成方案调研和边界决策。P2.4 实现前仍需提交完整源码对照卡与自动/运行态验证映射。
## 2026-07-18 Codex P2.4 CombatBody + 挡枪线接口基础版
### 已完成
- [x] 新增 `scripts/occlusion_geometry.gd`：从真实 `GeometryInstance3D` 子树计算物件根局部 AABB，跳过 `gvtt_runtime_only` 节点，并提供四角地面脚印；P2.5 后续必须复用该源几何，不再重做模型扫描。
- [x] 新增 `scripts/combat_body.gd`：保存局部边界与 `blocks_shot`，运行时重建独立 `StaticBody3D + CollisionShape3D + BoxShape3D`；物件缩放烘进形状尺寸，运行体保持单位缩放，物件旋转保留为战斗盒方向。
- [x] 新增 `scripts/combat_line_query.gd`：`cast(world, from, to, exclude)` 只查第 21 战斗物理层、只碰物理体、不碰 Area3D，统一返回遮挡状态、命中点、法线、碰撞体、CombatBody、实体根、形状编号和 RID。
- [x] `GvttRenderLayers` 与 `project.godot` 归口第 20 拾取层、第 21 战斗层；`PlacementController` 给墙体新放置/旧场景迁移统一补 `CombatBody`，并按 `WallProperties.blocks_shot` 启停；Gizmo 变换结束后同步战斗体旋转与缩放。
- [x] `docs/design.md`、`docs/entity_properties_schema.md`、`docs/p2_task_schedule.md` 写死 P2.4/P2.5 固定交接：共用 `OcclusionGeometry`，不共用运行体、查询接口或语义开关。
### 四层调研与采用结论
- [x] 项目现状：`docs/design.md`、`scripts/pick_proxy.gd` 已禁止复用 PickProxy AABB；`WallProperties` 已拆 `blocks_shot`/`blocks_los`；现有放置真值为 `PlacementController.place_model()`，旧场景补组件真值为 `main.gd::_migrate_loaded_entity_type_properties()`。
- [x] Godot `4.7-stable` 源码（提交 `5b4e0cb0f`）：`PhysicsBody3D::PhysicsBody3D()` 调 `body_create()`；`CollisionShape3D::_notification(NOTIFICATION_PARENTED)` 创建 shape owner 并挂形状；`CollisionObject3D::set_collision_layer()` 写入物理服务器；`PhysicsRayQueryParameters3D::create()` -> `PhysicsDirectSpaceState3D::_intersect_ray()` -> 底层 `intersect_ray()`；`CollisionObject3D::~CollisionObject3D()` 调 `free_rid()` 清理。
- [x] 官方离线文档：`gdd_0255_Ray-casting.md`、`gdd_1407_PhysicsRayQueryParameters3D.md`、`gdd_0554_CollisionObject3D.md`、`gdd_0558_CollisionShape3D.md`、`gdd_0753_StaticBody3D.md`、`gdd_0870_BoxShape3D.md`、`gdd_0673_Node3D.md`；采用碰撞层筛选、物理体/Area 分流、单位缩放形状和变换通知。
- [x] 英文社区/开源方案：核对 `d-bucur/godot-vision-cone`、`AreaOfSight2D 1.1`、`Visibility Polygon 1.0.0`；它们只提供 Godot 4 二维视野/可见多边形模式，不直接安装到 Gvtt。仅采用“源遮挡几何与最终查询/显示分离”的模式，P2.4 继续使用原生三维物理查询。
### Godot 源码行为 -> 本地实现 -> 验证
- [x] `body_create()` + 静态模式 -> `CombatBody._create_runtime_body()` -> 专项测试确认运行体位于独立战斗层且 `collision_mask=0`。
- [x] `CollisionShape3D` 直系挂到碰撞对象并注册 shape owner -> `CombatCollisionShape` 直系挂到 `CombatPhysicsBody` -> Godot 4.7 无插件恢复模式成功注册 41 个全局类并完整导入项目。
- [x] 查询参数按层、Bodies/Areas 分流 -> `CombatLineQuery.cast()` 使用战斗 mask、Bodies=true、Areas=false -> PickProxy Area 不命中、墙体中心命中、旁路线不命中。
- [x] Node3D 变换通知与物理形状禁止非均匀缩放 -> 根缩放烘进 `BoxShape3D.size`、运行体单位缩放、根旋转写入正交基 -> 缩放尺寸、旋转中心命中和旋转 AABB 假阳性旁路线均通过。
- [x] `free_rid()` 清理 -> CombatBody 随实体释放 -> 释放墙体后同一射线不再命中。
### 验证
- [x] P2.4 独立 Jolt Physics 运行态回归：`P2_4_COMBAT_RESULT {"assertions":19,"failed":0,"failures":[]}`。
- [x] 无插件全量回归壳成功解析真实 `main.gd`、Gizmo 与 41 个全局类，完整导入场景和素材，无脚本编译错误。
- [x] 现有跨模块运行态回归执行 251 项：250 项通过；唯一失败为隔离 `user://` 没有真实存档中的既有 PickProxy 测试物件，错误文本“真实读回场景没有可测试的 PickProxy”，与 P2.4 代码无关。其余 UI、保存、模型缓存、网格、移动和新配置参数链均跑完。
- [x] 新增/修改脚本无 `:=`；目标文件 `git diff --check` 通过。
### 未做与人工确认
- [ ] 没有射击按钮、瞄准线 UI、命中率、骰子、伤害、武器穿透或 P2.5 战争迷雾代码；本轮交付的是几何组件与查询接口。
- [ ] 仍需 GM 在可见 Godot 窗口重新运行项目后放置墙体，打开远程场景树确认墙体下有 `CombatBody/CombatPhysicsBody/CombatCollisionShape`；旋转/缩放墙体后打开“调试 -> 可见碰撞形状”，确认战斗盒跟随。当前没有面向 GM 的射击线按钮，因此挡枪查询以自动测试为准。
### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 原项目独立 headless 启动会在 `godot-rust`/gdstyle GDExtension 初始化阶段 signal 11 崩溃；沙箱内还会因 `user://logs` 无写权限提前失败。未重载或停用用户编辑器插件，改用无插件隔离项目 + 恢复模式导入 + 授权 user:// 写入完成真实物理与跨模块回归。 | ✅ 已绕开并完成验证；原插件独立 headless 崩溃仍属环境问题 |

## 2026-07-18 Codex P2.3 光源标记改为 Godot 灯光图标
### 纠正与完成
- [x] 撤回“固定尺寸 3D 小球就是最终方案”的结论。用户指出应直接核对 Godot 编辑器灯光图标；源码证明 Godot 使用贴图 billboard（始终朝相机），不是 `SphereMesh` 球体。
- [x] `scripts/pick_proxy.gd` 将 `PickProxyMarker` 从 `MeshInstance3D + SphereMesh` 改为 `Sprite3D`，使用 Godot 4.7 同源 `assets/lights/gizmo_light.svg`。开启 `billboard`、`fixed_size`、透明裁切和不受光照显示，图标宽度参数为 `0.1`，对应 Godot `add_unscaled_billboard(icon, 0.05)` 的完整边长。
- [x] 图标颜色按 Godot 灯光 Gizmo 做法保留灯光色相/饱和度并把亮度提满；`LightProperties.color` 改变后继续通过 `_sync_light_marker()` 同步。
- [x] 图标强制放在 GM-only 第 20 渲染层，运行态由既有 `set_edit_visible()` 隐藏，投屏相机的玩家 cull mask 不包含该层。
- [x] 纯显示图标带 `gvtt_runtime_only`，`owner == null`，不写入场景存档；`_walk_collect()` 忽略运行时辅助节点，图标不再影响拾取盒 AABB，内置灯拾取盒保持默认 `0.6 × 0.6 × 0.6`。
- [x] `assets/lights/LICENSE_GODOT.txt` 记录 Godot 图标来源、精确提交和 MIT 许可；`docs/entity_properties_schema.md` 已改为灯泡图标方案并补离线 API 依据。
### 四层调研回执
- [x] 项目现状：`PlacementController` 已创建真实 `OmniLight3D`、`LightProperties` 与独立 `PickProxy Area3D`；旧 `PickProxyMarker` 只是固定尺寸球，显示、拾取与真实光源职责混杂。
- [x] Godot 源码：官方 `4.7-stable` 标签，提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`Node3DEditor::_register_all_gizmos()` 注册 `Light3DGizmoPlugin`；其构造函数读取 `editor/icons/GizmoLight.svg`；`Light3DGizmoPlugin::redraw()` 对 `OmniLight3D` 调 `add_unscaled_billboard(icon, 0.05, color)`；`EditorNode3DGizmo::add_unscaled_billboard()` 建正方形贴图；`EditorNode3DGizmoPlugin::create_icon_material()` 开启 unshaded、alpha scissor、fixed size、billboard；`EditorNode3DGizmo::intersect_ray()` 另按屏幕矩形处理图标点击。范围圆线和手柄只在选中时创建。
- [x] 官方资料：离线 `gdd_0751_SpriteBase3D.md` 确认 `billboard`、`fixed_size`、`no_depth_test`、`pixel_size`、`modulate`；`gdd_0864_BaseMaterial3D.md` 确认固定屏幕尺寸与 billboard 材质行为；`gdd_1556_Color.md` 确认 `Color.from_hsv()` 及 `h/s` 属性。
- [x] 英文社区/开源方案：Godot Asset Library 的 Debug Draw 3D 1.7.3（Godot 4.4.1+、MIT、2026-04-04）支持 billboard 图形、no-depth-test、多 `World3D`/`Viewport`，GitHub 约 1k stars 且仍维护；但它是整套 C++ GDExtension 并带独立配置/可选遥测，为单个灯位图标引入过重，因此不采用。社区常见轻量模式同样是 `Sprite3D + billboard + fixed_size`。
### 源码行为 -> 本地实现 -> 验证
- [x] `GizmoLight.svg` + `add_unscaled_billboard(0.05)` -> `gizmo_light.svg` + `MARKER_ICON_WORLD_SIZE = 0.1` -> 运行探针读取贴图路径和 `world_width = 0.1000000015`。
- [x] `FLAG_FIXED_SIZE + BILLBOARD_ENABLED` -> `Sprite3D.fixed_size = true` + `billboard = BILLBOARD_ENABLED` -> 运行探针两项均为 true；5/15/30 单位三档可见截图中三枚灯泡像素大小一致且均正面朝相机。
- [x] 灯色 HSV 亮度提满 -> `Color.from_hsv(marker_color.h, marker_color.s, 1.0)` -> 蓝色探针得到同色相高亮 `Color(0.25, 0.5, 1, 1)`。
- [x] 编辑图标与选择范围分离 -> 图标 GM-only/runtime-only，拾取继续使用 `Area3D` -> 运行探针确认图标层掩码 `524288`、隐藏/显示切换正确、拾取盒仍为 `0.6`。
- [x] 编辑辅助不保存 -> 图标不设置 owner -> 运行探针确认 `owner_is_null = true`、`gvtt_runtime_only = true`；临时探针最终全部删除，未写入场景。
### 验证
- [x] Godot `4.7-stable (official)`：`script_manage(find_symbols)` 成功解析 `pick_proxy.gd`、`main.gd`、`placement_controller.gd`；ClassDB 实时确认 `SpriteBase3D` 属性和 `ALPHA_CUT_DISCARD` 枚举存在。
- [x] 本次项目运行 `helper_live = true`；游戏日志只有 helper 注册和嵌入窗口提示，无脚本错误。启动回执出现的 `SceneSessionController` 条目明确标记为本次运行前保留记录，当前场景树和运行探针均正常。
- [x] 可见截图验证：编辑态三档距离图标大小一致；调用 `set_edit_visible(false)` 后第二张截图三枚图标全部消失。
- [x] `rg -n ":=" scripts/pick_proxy.gd scripts/main.gd scripts/placement_controller.gd` 无命中；`git diff --check` 通过。
- [ ] 仍需 GM 最终手动确认真实操作体感：从左栏拖出点光源，拉远/拉近相机，调整颜色，切运行态并打开投屏；预期图标恒定大小且只在 GM 编辑态出现，真实光照继续同步。

## 2026-07-18 Codex P2.6 墙体破坏最小闭环调研
### 四层调研回执
- [x] 项目现状：P2.4 已存在 `CombatBody.set_blocks_shot()`、专用第 21 战斗碰撞层、`CombatLineQuery` 与回归测试；`WallProperties` 已保存 `wall_state`、耐久、`blocks_los`、`blocks_shot` 和掩体语义。P2.5 的 `LOSOccluder`、可见区域计算与迷雾显示尚未落地，因此 P2.6 不能在 P2.5 接口缺席时宣称 LOS 闭环完成。
- [x] Godot 源码：官方 `4.7-stable`，提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`scene/3d/physics/collision_object_3d.cpp::CollisionObject3D::set_collision_layer()` 把层值下发至 `PhysicsServer3D`；`modules/jolt_physics/jolt_physics_server_3d.cpp::body_set_collision_layer()` 更新 Jolt 物理体；`modules/jolt_physics/spaces/jolt_physics_direct_space_state_3d.cpp::intersect_ray()` 用查询碰撞掩码构造过滤器；`scene/resources/packed_scene.cpp::SceneState::_parse_node()` 保存 owner 正确且带 `PROPERTY_USAGE_STORAGE` 的属性，`SceneState::instantiate()` 读回后逐项 `node->set()`。
- [x] 官方资料：离线 `gdd_0554_CollisionObject3D.md`、`gdd_1407_PhysicsRayQueryParameters3D.md`、`gdd_0255_Ray-casting.md` 确认 32 层碰撞、射线掩码和 body/area 筛选；`gdd_0306_GDScript_exported_properties.md` 与 `gdd_1006_PackedScene.md` 确认 `@export` 字段随场景保存、owner 决定子节点是否打包。官方演示仓搜索未找到完整的 3D 墙体破坏、LOS 联动与持久化演示。
- [x] 英文社区/插件：`Jummit/godot-destruction-plugin` 支持 Godot 4+、MIT，最新 7.2 发布于 2024-06-23，但作者只在小场景测试；源码 `destroy()` 会释放墙体父节点并生成临时刚体碎块，和 Gvtt 保存墙体状态的需求冲突。`Destructibles CSharp 2.8.3` 面向 Godot 4.6、2026-02-20 发布，但要求 Godot Mono，会改变当前纯 GDScript 单 exe 构建链。`VoronoiShatter 0.3` 最新发布于 2026-06-01、项目标记 Godot 4.6、MIT/原生 GDScript，但作者明确标为高度实验、可能崩溃并建议预碎裂；不纳入 P2.6 最小闭环。
### 方案结论
- [x] P2.6 不安装破坏插件；插件只能作为后置视觉适配器，不能拥有墙体状态、删除墙体根节点或决定 LOS/挡枪线。
- [x] `WallProperties.wall_state` 作为破坏状态权威；`blocks_los` / `blocks_shot` 保留为完整墙体的基础语义，运行时有效值按 `wall_state != DESTROYED` 推导，避免破坏后覆盖基础配置导致无法正确修复玻璃墙等特殊墙体。
- [x] 推荐增加独立墙体状态控制器：运行态按钮请求破坏 -> 校验墙体类型与 `destructible` -> 状态设为 `DESTROYED`、耐久设为 0 -> `CombatBody.set_blocks_shot(false)` -> 调 P2.5 提供的 LOS 遮挡启停/重算接口 -> 标记场景已修改并刷新状态面板。重复破坏必须幂等。
- [x] 读回闭环：继续复用 `ModuleIo` 的 `PackedScene` 保存；读回挂树并补齐组件后必须统一调用墙体状态同步，重新关闭 CombatBody、LOS 遮挡和最小视觉，不能只验证 `wall_state` 字段值。
- [x] 最小视觉建议仅隐藏完整墙体模型，避免“墙还看得见但枪线和 LOS 已穿过”的因果矛盾；碎裂网格、刚体碎块、粒子、音效、复杂光照/GI 重算后置。
### 实现与验证（接续完成）
- [x] 新增 `scripts/wall_state_controller.gd`：墙体根保留，统一 `sync_wall()`、`destroy_wall()`、`repair_wall()`；破坏写 `DESTROYED` 和耐久 0，修复写 `INTACT` 并恢复最大耐久。
- [x] `WallProperties` 新增状态/枪线信号与有效 LOS/枪线查询；`LOSOccluder` 和 `PlacementController` 改读有效值，破坏不覆盖基础 `blocks_los` / `blocks_shot`，保留玻璃墙等独立语义。
- [x] `main.gd` 接入运行态“破坏墙体/修复墙体”按钮、场景脏标记、编辑字段同步与读档迁移后的 `sync_wall()`；不可破坏完整墙禁用按钮。
- [x] 新增 `tests/p2_6_wall_destruction_regressions.gd/.tscn`。编辑器运行结果：`P2_6_WALL_RESULT {"assertions":36,"failed":0,"failures":[]}`；覆盖破坏、幂等、修复、不可破坏拒绝、LOS/枪线、最小视觉、玻璃墙语义和 `ModuleIo` 保存读回。
- [x] P2.5 回归保持：`P2_5_LOS_RESULT {"assertions":52,"failed":0,"failures":[]}`。正式主场景 `helper_live=true`、`current_run_errors=[]`，运行界面树确认存在“破坏墙体”按钮。
- [ ] P2.4 本轮回跑只捕获测试助手注册，测试进程随后停止且未输出 `P2_4_COMBAT_RESULT`；命令行入口仍在 `godot-rust` 原生层 signal 11 崩溃，未取得新的通过/失败结论。P2.6 自身的真实 Jolt 枪线断言已通过。
- [ ] 仍需 GM 在可见窗口手动确认操作体感和投屏结果；本轮不做 Mesh 碎裂、刚体碎块、粒子、音效、复杂光照/GI 重算或 P2.2 移动导航重建。
### Godot 源码行为 -> 本地实现 -> 验证
- [x] `CollisionObject3D::set_collision_layer()` 下发物理层 -> `CombatBody.set_blocks_shot(false/true)` -> P2.6 专项真实射线确认破坏放行、修复恢复。
- [x] `PackedScene::_parse_node()` 保存存储属性、`SceneState::instantiate()` 读回 -> `WallProperties` 导出字段 + `ModuleIo` -> 专项确认 `DESTROYED`、耐久和基础双开关读回，随后 `sync_wall()` 重建关闭状态。
- [x] LOS 组件信号驱动重算 -> `set_wall_state()` 发有效 LOS 变化、`LOSOccluder` 清空/恢复线段 -> 专项确认重算次数增加且墙后点由不可见变可见。
### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | Godot 测试进程偶发只登记 helper 后退出；命令行稳定在 `godot-rust` 原生层 signal 11 崩溃 | 环境问题未解决；P2.6 冷却后复跑再次 `36/36` 通过，P2.4 本轮未取得新结论 |
| 2026-07-18 | 破坏墙体是否同时允许 Token 穿过 | 后置；P2.6 只关闭 LOS/枪线，P2.2 移动导航缓存重建另开任务 |
## 2026-07-18 Codex P2.4 Token 默认战斗线可视探针（已撤回）

> 2026-07-18 纠正：本节的“每个 Token 固定 10 米红/绿探针”没有明确目标，错误地把调试线、射程、目标前后遮挡和可射击结论混在一起；多 Token 还会生成多条线。下方保留原记录用于追溯，但其方案与完成结论均由后续“目标式单一战斗线纠正”取代。

### 已完成
- [x] 新增 `scripts/combat_line_probe.gd`：Token 半高处沿项目约定的本地 `+Z` 发出固定 10 米测试线；无战斗遮挡显示完整绿色，首个 `CombatBody` 命中时显示红色并截断到命中点。
- [x] 探针每个物理帧只调用既有 `CombatLineQuery.cast()`，没有新增第二套挡枪算法；自动排除 Token 自身未来可能存在的 `CombatBody` RID。
- [x] `CombatLineVisual` 使用 `ImmediateMesh + MeshInstance3D`，无光照、关闭深度测试和阴影，固定第 20 GM-only 渲染层；投屏相机继续排除该层。
- [x] `PlacementController.attach_entity_type_properties()` 给新放置和旧场景读回的 Token 统一补 `CombatLineProbe`；组件和可视节点标记 `gvtt_runtime_only`，探针不设置 owner，不写入场景存档。
- [x] `docs/design.md`、`docs/entity_properties_schema.md`、`docs/p2_task_schedule.md` 写明：该线只是 P2.4 可视验收探针，不是武器/射程/命中/伤害规则；P2.5 禁止重复实现探针、战斗射线或模型扫描。

### 四层调研与采用结论
- [x] 项目现状：`MovementService._create_preview_renderer()` / `_add_path_surface()` 已用 `ImmediateMesh` 绘制动态路线；`_face_movement_direction()` 与回归测试明确 Token 本地 `+Z` 为正前方；`TokenProperties` 已保存 `collision_height=1.8` 与 `can_show_aim_line=true`；投屏相机已用 `CULL_MASK_PLAYER` 排除第 20 层。因此复用项目绘线模式和现有 Token 字段，不新增 UI 或插件。
- [x] Godot `4.7-stable` 源码（提交 `5b4e0cb0f`）：`scene/3d/navigation/navigation_agent_3d.cpp::NavigationAgent3D::_update_debug_path()` 执行清旧表面、提交线段顶点、设置材质并把网格 RID 交给渲染实例；`scene/3d/mesh_instance_3d.cpp::MeshInstance3D::set_mesh()` 通过 `set_base(mesh->get_rid())` 注册网格；`scene/3d/visual_instance_3d.cpp::VisualInstance3D::set_layer_mask()` 下发渲染层；战斗查询继续沿用 P2.4 已核对的 `PhysicsRayQueryParameters3D::create()` -> `_intersect_ray()` -> Jolt `intersect_ray()`。
- [x] 官方离线文档：`gdd_0951_ImmediateMesh.md` 与 `gdd_0101_Using_ImmediateMesh.md` 确认动态简单几何可每帧 `clear_surfaces()` 后按 `surface_begin()`、`surface_add_vertex()`、`surface_end()` 重建；`gdd_0255_Ray-casting.md` 确认物理空间查询应在 `_physics_process()`，结果返回世界坐标命中点，碰撞掩码适合动态筛选。
- [x] 英文社区/开源方案：核对 `DmitriySalnikov/godot_debug_draw_3d`（1k stars、418 commits、最新 1.7.3 支持 Godot 4.4.1+，提供线、无深度测试和多 World3D/Viewport）；未采用，原因是单条固定探针不值得增加 C++ GDExtension、平台二进制、遥测配置和多视口配置，且项目已有同类即时网格模式。Godot proposal `godot-proposals#112` 也把通用 3D 调试绘制归为插件/辅助层问题，没有提供必须替代本地两顶点网格的核心 API。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] 调试路径脏时清表面并重提交线段 -> `CombatLineProbe._draw_line()` -> 专项测试验证 clear/blocked 两种线端点与颜色，真实运行态两枚旧 Token 的网格持续可见。
- [x] 网格注册到渲染实例 -> `_create_renderer()` 的 `MeshInstance3D.mesh = ImmediateMesh` -> Godot 4.7 导入与运行无脚本错误，运行场景树存在两组 `CombatLineProbe/CombatLineVisual`。
- [x] 渲染层下发 -> `CombatLineVisual.layers = 1 << 19` -> 自动断言与 `game_eval` 均返回 `524288`，投屏相机掩码排除该层。
- [x] 物理帧查询世界空间 -> `_physics_process()` 调 `CombatLineQuery.cast()` -> Jolt 测试验证无遮挡、首命中截断、Token 旋转后沿本地 `+Z`、`blocks_shot=false` 恢复畅通。
- [x] 运行时辅助节点随父节点释放 -> 探针不设置 owner、可视节点挂在探针下 -> 自动断言 owner 为空且 `gvtt_runtime_only=true`。

### 验证
- [x] Godot `4.7.stable.official.5b4e0cb0f` 导入通过，无新脚本错误。
- [x] P2.4 Jolt 专项回归：`P2_4_COMBAT_RESULT {"assertions":33,"failed":0,"failures":[]}`。
- [x] 跨模块回归执行 251 项，250 项通过；唯一失败仍为隔离 `user://` 缺少预存 PickProxy 样本，与 P2.4 基础版记录一致，没有新增失败。
- [x] 真实项目运行通道 `helper_live=true`，两枚旧 Token 自动补挂探针；运行态返回绿色、10 米、半高 0.9 米、第 20 层且可见，游戏日志无当前运行错误。
- [ ] 当前真实场景没有墙体，未取得“现有场景红线”截图；需 GM 在可见窗口放一堵墙到 Token 正前方，确认绿线变红并截断。红线几何已由专项 Jolt 测试覆盖。

### 未做
- [ ] 未添加射击按钮、目标选择、武器射程、命中率、骰子、伤害、穿透或任何 P2.5 战争迷雾代码。

## 2026-07-18 Codex P2.4 目标式单一战斗线纠正

### 用户指出的真实问题
- [x] 固定 10 米方向线没有目标，无法区分“3 米目标之前的遮挡”和“5 米处目标之后的遮挡”，因此红色不能证明目标射不到。
- [x] Token 的 PickProxy（拾取代理）或通用碰撞体不应自动算掩体；射手与明确目标自身也不能成为本次射线的首个环境遮挡。
- [x] 《赛博朋克 RED》掩体是二元语义，不存在由本工具自动计算的“半掩体百分比”。汽车等带孔资产不能由整体 AABB（轴对齐包围盒）推断掩体。
- [x] 每个 Token 挂探针会生成多条射线；探针进入 Token 子树还会干扰 Gizmo（变换手柄）的选择/旋转视觉。旧存档模型为空壳是另一条已存在的保存链损坏，视觉上会进一步造成“只转线、不转模型”。

### 四层调研回执与采用结论
- [x] 项目现状：`docs/design.md`、`scripts/pick_proxy.gd` 已禁止 PickProxy AABB 参与挡枪；第 20 层是拾取 Area3D，第 21 层是 CombatBody StaticBody3D；`CombatLineQuery.cast()` 已能按有限起点/终点、碰撞 mask（掩码）和 RID 排除列表查询。真正错误在可视验证层：旧 `CombatLineProbe` 没有目标且每 Token 一份。
- [x] Godot `4.7-stable` 源码，提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`：`PhysicsRayQueryParameters3D::create()` 保存 `from/to/collision_mask/exclude` -> `PhysicsDirectSpaceState3D::_intersect_ray()` 下发查询 -> `JoltPhysicsDirectSpaceState3D::intersect_ray()` 以 `to - from` 构造有限射线 -> `JoltQueryFilter3D::ShouldCollide()` 按碰撞层、body/area 和排除 RID 过滤 -> 返回最近命中。`PackedScene::pack()` -> `SceneState::pack()` -> `_parse_node()` 与 `PackedScene::instantiate()` -> `SceneState::instantiate()` 证明运行时辅助节点和持久模型必须分开管理。
- [x] 官方资料：离线 `gdd_1407_PhysicsRayQueryParameters3D.md`、`gdd_1402_PhysicsDirectSpaceState3D.md`、`gdd_0255_Ray-casting.md` 确认射线由明确世界坐标起终点、碰撞掩码、body/area 开关和排除列表组成；`gdd_1006_PackedScene.md`、`gdd_1571_Plane.md` 分别核对场景实例化和鼠标射线到地面投影。
- [x] 英文社区/开源实现：Godot 4.x 的 LOS/clear-shot（视线/清晰枪线）实现普遍以明确目标位置为终点，比较目标前的最近遮挡，并把“可见”“枪线清晰”“友军挡线”和调试绘制分开。`d-bucur/godot-vision-cone` 等现成项目解决二维多射线可见区域，只能给 P2.5 借鉴，不能替代 P2.4 的单条三维战斗查询。
- [x] CPR 官方依据：R. Talsorian Games 的 Gangs and Combat 说明“攻击者有 LOS（视线）时，目标不在掩体中”；采用二元掩体语义，不在 P2.4 引入半掩体或命中修正。

### 源码对照卡：引擎行为 -> 本地实现 -> 验证
- [x] 有限 `from -> to` 最近命中 -> `CombatLinePreview.show_preview(shooter, target_position, target_entity)` 调 `CombatLineQuery.cast()` -> 专项测试覆盖目标前遮挡命中、目标后遮挡不影响当前线段。
- [x] collision mask + body/area 分流 -> 查询只查第 21 战斗层 PhysicsBody3D -> 测试确认第 20 层 PickProxy Area3D 与普通 Token 不挡枪。
- [x] exclude RID -> 预览收集射手和明确目标的 CombatBody RID -> 测试确认目标自己的战斗体不被误报为目标前掩体。
- [x] 最近命中只描述几何 -> 青色显示终点前无登记遮挡；橙色画到首个命中点，灰色保留原目标余段 -> 自动测试检查端点、颜色材料和返回结果，不宣称命中率或武器能否射中。
- [x] 运行时显示与实体分离 -> `Main` 下只创建一个 `CombatLinePreview/CombatLineVisual`，不再给 Token 挂组件；Gizmo 悬停/编辑、拖放、Token 移动、相机操作和 UI 悬停时隐藏 -> 运行场景树确认全局一条线、Token 无 `CombatLineProbe`，Gizmo 操作不把线当模型。

### 代码与文档纠正
- [x] 删除 `scripts/combat_line_probe.gd`；`PlacementController` 停止给 Token 补探针。
- [x] 新增 `scripts/combat_line_preview.gd`，由 `main.gd` 在 `Main` 下创建唯一实例；选中 Token 为射手，鼠标指向实体时以实体半高为终点，否则投影到 y=0 地面。
- [x] 预览线固定 GM-only 第 20渲染层：青色表示有限线段内无登记遮挡，橙色到首个 CombatBody，灰色继续标出原目标；颜色不代表射程、命中、骰子、伤害或穿透。
- [x] 为旧存档的空模型壳增加保守恢复：仅在类别与素材 basename（基础文件名）唯一匹配时恢复可见模型；恢复后的场景保持未保存状态并提示 GM 保存，不自动覆盖旧文件。
- [x] 更新 `docs/design.md`、`docs/entity_properties_schema.md`、`docs/p2_task_schedule.md`：撤回固定 10 米验收，记录碰撞层、组件结构、查询接口、复杂掩体制作和 P2.5 非重复边界。

### 复杂汽车与未采用方案
- [x] 不采用 PickProxy AABB：旋转会产生假阳性，窗洞与空舱全部被封死。
- [x] 不直接把高面数视觉三角网格当战斗碰撞：性能不可控，而且视觉玻璃会被错误当成防弹实体。
- [x] 采用“人工低多边形战斗部件”合同：车门、发动机舱、金属车身可各自有形状；车窗、敞开驾驶舱和真实洞口不放形状；材质是否挡枪由 GM/资产配置决定。
- [ ] 当前基础版尚未提供汽车战斗部件编辑器，也不会自动把现有破损汽车宣称为 CPR 掩体。现在的汽车只恢复了视觉模型；精细 CombatBody 制作是后续明确任务。

### 验证
- [x] P2.4 Jolt Physics 专项回归：`P2_4_COMBAT_RESULT {"assertions":30,"failed":0,"failures":[]}`。
- [x] P1/跨模块完整运行回归：`P1_RUNTIME_RESULT {"assertions":267,"failed":0,"failures":[]}`；退出仍有既有测试夹具级 9 个 ObjectDB 对象与 4 个资源占用提示，不影响断言结果。
- [x] 真实项目运行 `helper_live=true`，无当前游戏脚本错误；运行态选中 `网行者test2` 后唯一 `CombatLineVisual.visible=true`，层掩码为 `524288`（第 20 渲染层），并带 `gvtt_runtime_only`。
- [x] 远程场景树确认 `网行者test`、`网行者test2`、`破损汽车3d模型` 均恢复 `MeshInstance3D`；Token 下没有 `CombatLineProbe`；全局只有 `/Main/CombatLinePreview/CombatLineVisual` 一条预览。
- [x] `git diff --check` 通过；功能脚本未引入 `:=`。
- [ ] 仍需 GM 可见窗口体感确认：选中一个 Token 后移动鼠标应只有一条线；遮挡物只在射手和终点之间时显示橙/灰；旋转 Token 时模型正常旋转且线隐藏。汽车当前不能作为精细掩体验收样本。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 固定 10 米红/绿探针没有明确目标，错误暗示“红色=射不到”。 | 已撤回，改为射手到明确终点的有限查询与中性颜色语义 |
| 2026-07-18 | 每个 Token 各挂探针导致两条线并干扰旋转判断。 | 已修复，全局唯一预览器，Gizmo 操作期间隐藏 |
| 2026-07-18 | 旧存档中的模型实例为空壳，视觉上只有辅助线在转。 | 已加唯一匹配恢复迁移；恢复后需 GM 保存场景 |
| 2026-07-18 | 汽车等带孔资产缺精细 CombatBody 制作入口。 | 未完成；禁止用整体 AABB 冒充，后续做人工低多边形战斗部件 |

## 2026-07-18 Codex P2.4 粗框汽车与可锁定自由瞄准验证

> 本节按用户后续明确选择，取代上一节“汽车必须先做精细战斗部件”和“鼠标吸附明确目标/地面”的当前实现结论。精细部件仍可后置，但不再阻塞 P2.4 临时验证。

### 四层调研回执
- [x] 项目现状：真实运行对象 `/Main/SceneRoot/ContentRoot/破损汽车3d模型` 属于 `TERRAIN`，此前没有 `CombatBody`，所以穿线不是程序识别了破窗，而是汽车完全未进入第 21 战斗层。视觉边界实测为 `4.702173 × 1.465081 × 2.084352` 米。`PickProxy` 继续只负责点击，不参与战斗查询。
- [x] Godot 源码：官方 `4.7-stable`，提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`scene/main/viewport.cpp::Viewport::_input()` 先分发 GUI，再进入 `_unhandled_input()`；`scene/3d/camera_3d.cpp::project_ray_origin()/project_ray_normal()` 提供屏幕到世界射线；`core/math/geometry_3d.h::segment_intersects_sphere()` 和 `editor/scene/3d/node_3d_editor_plugin.cpp` 的 trackball（轨迹球）处理证明相机右/上向量可把屏幕方向映射到世界方向；物理命中继续沿用已核对的有限射线与碰撞掩码链。
- [x] 官方资料：离线 Godot 4.7 `gdd_0540_Camera3D.md`、`gdd_1298_Geometry3D.md`、`gdd_0963_InputEventMouseButton.md`、`gdd_1571_Plane.md` 核对相机投影、几何求交和鼠标按键字段；官方 API 不提供“3D VTT（虚拟桌面）瞄准轮 + 世界线锁定”的整套控件，需要由项目组合现有几何与输入接口。
- [x] 英文社区/开源：未找到维护中的 Godot 4.x 3D VTT 瞄准/锁线插件。`DmitriySalnikov/godot_debug_draw_3d` 能画 3D 调试线，但对一条 GM-only（仅主持人）线过重；Godot 4 RTS（即时战略）相机的常见模式把左键选择与右键环绕分开，可复用交互分工但不能替代战斗查询。

### 采用与未采用
- [x] 采用独立视觉边界粗框：墙体以及勾选“可当掩体”的交互物体、地形、装饰挂 `CombatBody`；汽车粗框故意封住破窗、空舱和打开部件。Token 与光源默认不挡枪。
- [x] 粗框来源是 `OcclusionGeometry` 扫描真实视觉子树，不读取、不复用 `PickProxy` 的 AABB。形状随物件根旋转，缩放烘进 `BoxShape3D.size`。
- [x] 采用临时自由瞄准：视觉模型顶部向下 `1/9` 为眼睛位置；鼠标只决定水平世界方向；固定 20 米测试线和 96 像素上半圆，不吸附实体、地面或地图边缘。
- [x] 采用空白左键锁定、再次空白左键或 `Esc` 解锁。锁定保存世界起点/终点，鼠标、相机和 Gizmo（变换手柄）操作不能更新它。
- [ ] 未做命中率、骰子、伤害、武器射程、穿透、材质识别、目标选择或 P2.5 战争迷雾；20 米只用于临时几何验证。

### 源码行为 -> 本地实现 -> 验证
- [x] 独立碰撞层与有限最近命中 -> `CombatBody` + `CombatLineQuery.cast()` -> 专项测试覆盖第 20/21 层隔离、旋转盒、启停/释放和首命中。
- [x] 视觉边界转盒形物理体 -> `PlacementController.attach_entity_type_properties()/sync_combat_body()` -> 测试确认汽车尺寸地形对象得到独立粗框且整盒中心线被其自身拦截；真实汽车运行节点尺寸与视觉边界一致。
- [x] 相机屏幕方向映射 -> `CombatLinePreview.get_screen_aim_direction()` -> 俯视正交相机测试确认结果水平、单位化，重新投影后与请求屏幕方向点积大于 `0.99`。
- [x] 世界线锁定 -> `lock_current()/unlock()/is_locked_for()` 与 `main.gd::_toggle_combat_line_lock()` -> 自动测试确认锁定更新不改终点、解锁恢复更新；真实主场景确认锁定后鼠标移动/右键环绕仍保持线显示和半圆隐藏，`Esc` 后半圆恢复。
- [x] 画面叠加 -> 唯一 `CombatLinePreview` 下的 `CombatLineVisual + CombatAimGuide` -> 真实主场景确认半圆 33 点、预览线第 20 GM-only 渲染层，游戏日志无脚本错误。

### 验证与限制
- [x] P2.4 Jolt Physics（Jolt 物理）专项：`P2_4_COMBAT_RESULT {"assertions":42,"failed":0,"failures":[]}`。
- [x] 真实汽车：`blocks_shot=true`、`geometry_fitted=true`，粗框 `4.702173 × 1.465081 × 2.084352` 米；运行时存在 `CombatPhysicsBody/CombatCollisionShape`。
- [x] 主场景 `helper_live=true`，锁定/解锁链运行，游戏日志仅有 helper 注册和嵌入窗口提示，无脚本错误。
- [ ] 完整回归本轮未宣称全绿：编辑器内执行为 `262/267`，剩余 5 项都是嵌入窗口不更新 GUI hover（界面悬停）的合成按钮输入夹具失败；隔离控制台运行又在 `godot-rust/gdstyle` 原生层 signal 11 崩溃。P2.4 专项不依赖这些失效夹具。
- [ ] 仍需 GM 用真实鼠标做最终体感确认：选中 Token 后把方向扫过整辆车，观察橙色命中段是否停在粗框入口；空白左键锁线后右键转相机，从多角度观察世界线不动，再用 `Esc` 解锁。

## 2026-07-18 Codex P2.4 低汽车完整掩体与瞄准输入独占

### 用户指出的矛盾
- [x] 当前射击线固定在站立眼睛高度，真实高度约 1.465 米的汽车永远低于约 1.6 米眼睛线；如果项目又宣称汽车是二元完整掩体，两者不能同时成立。
- [x] 当前左键在运行态先调用 `_pick_entity_at_screen_position()`，只有点空白才锁线；所以瞄准点落在汽车上会切换选择，说明缺少持续瞄准输入模式。

### 四层调研回执
- [x] 项目现状：`PlacementController.attach_entity_type_properties()` 已为墙体和交互物体/地形/装饰生成候选 `CombatBody`，Token 与光源排除；真实汽车属于 `TERRAIN`。`CombatBody` 原先只按视觉局部边界生成盒，高度不做规则抽象。`main.gd::_unhandled_input()` 原先先拾取实体再判断是否锁线。
- [x] Godot 源码：官方 `4.7-stable`，提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`editor/import/3d/resource_importer_scene.cpp::ResourceImporterScene::_post_fix_node()` 按 `generate/physics`、`physics/body_type`、`physics/shape_type` 生成 `StaticBody3D/CollisionShape3D` 并设置 layer/mask，默认 `generate/physics=false`；`scene/main/viewport.cpp` 明确事件顺序为 `_input -> GUI -> _unhandled_input`，当前模式可 `set_input_as_handled()` 阻止后续拾取。
- [x] 官方/规则资料：离线 4.7 `gdd_0656_MeshInstance3D.md` 确认凸形/多凸形/三角碰撞辅助接口主要用于测试；`gdd_0558_CollisionShape3D.md` 要求避免非均匀缩放碰撞节点、应修改形状资源。CPR 核心规则书 PDF p.200（书内 p.182）规定整个人不可见才是掩体、没有部分掩体；PDF p.201（书内 p.183）列出车门 25HP、引擎组 50HP、普通挡风玻璃 0HP。R. Talsorian Games 官方 Gangs and Combat 同样说明有 LOS 就不在掩体中。
- [x] 英文社区/插件：Godot Asset Library 的 `3D Auto Collision Generator 1.0` 面向 Godot 4.1、发布于 2024-03-03，只做批量碰撞生成，不能判断战斗掩体语义；Godot 4 社区常见方案是导入碰撞加分类/手工低模，精确三角形成本更高。CPR 社区一致把低车掩体解释为角色缩到后面断开 LOS，而非站直时由视觉车顶直接挡眼睛。

### 采用方案
- [x] 每次放置/读回墙体、交互物体、地形、装饰都生成候选 `CombatBody`；Token 和光源不生成。候选体可禁用，不等于每个导入模型默认挡枪。
- [x] `CombatBody` 分离真实 `local_bounds`、`blocks_shot` 和 `provides_full_cover`。用户修正后撤回“补高到 1.8 米”的旧方案：真实视觉高度严格高于 `1.0` 米才自动算战斗掩体，低于或等于 `1.0` 米不挡枪；真实汽车边界、模型、运行盒高度和 PickProxy 均不变。
- [x] 一旦对象被分类为战斗掩体，`CombatLineQuery` 除了正常 Godot 3D 物理射线外，还会用随物件旋转的 XZ 地面占用框做二元挡线判断；因此射线即使在汽车上方，只要水平投影穿过汽车粗框，也会被判定为被掩体挡住。
- [x] `PointerInteractionController` 新增持续战斗瞄准状态，独立于一次鼠标手势；因此右键相机环绕可以临时进入/退出，瞄准所有权不会丢失。
- [x] 选中 Token 自动进入瞄准；瞄准时视口左键先锁定/解锁战斗线并标记事件已处理，完全不调用 PickProxy 拾取。锁定时第一次 `Esc` 解锁，活动瞄准时第二次 `Esc` 退出并恢复选择。

### 源码行为 -> 本地实现 -> 验证
- [x] 导入节点按配置生成独立物理节点 -> `PlacementController._ensure_combat_body()` 统一创建候选组件 -> 专项确认墙/地形/装饰路径生成，Token/光源排除。
- [x] 碰撞形状资源持有尺寸、节点保持单位缩放 -> `CombatBody.sync_transform_from_target()` 把根缩放烘入 `BoxShape3D.size` 并保留真实高度；二元掩体另走 XZ 地面粗框 -> 专项确认真实 1.47 米边界不变，高空测试线仍被粗框挡住。
- [x] 当前模式先消费事件 -> `main.gd::_unhandled_input()` 在拾取前检查 `should_block_entity_selection()` -> 真实窗口点击汽车后属性面板仍为 `网行者test2`，半圆隐藏表示锁线。
- [x] 持续工具模式与瞬时手势分离 -> `PointerInteractionController` 保存瞄准射手，`reset()` 只结束相机/拖动手势 -> 单元断言右键环绕与瞄准并存，结束瞄准后恢复普通选择。
- [x] 退出顺序 -> `_unlock_combat_line_preview()` / `_exit_combat_aim_mode()` -> 真实窗口第一次 `Esc` 恢复半圆、第二次关闭瞄准，再点汽车后属性面板变为 `破损汽车3d模型`。

### 验证
- [x] P2.4 Jolt Physics 专项：隔离测试项目同步当前脚本后通过 `P2_4_COMBAT_RESULT {"assertions":56,"failed":0,"failures":[]}`；覆盖真实高度保持、`0.99/1.00/1.01` 米阈值、高空射线穿过粗框被挡、旋转粗框不退化成世界 AABB。
- [x] 跨模块回归：`267` 项中 `262` 通过；剩余 5 项仍是既有嵌入窗口 GUI hover 不更新导致的素材按钮合成输入夹具失败，本轮没有新增失败。
- [x] 真实汽车判定口径：视觉高度约 `1.465081` 米，高于 `1.0` 米，自动 `provides_full_cover=true`；运行碰撞盒继续保留真实高度，挡枪线使用 XZ 地面粗框避免“从车顶上方穿过去”的测试错觉。
- [ ] 仍需 GM 用真实鼠标确认最终体感：选中 Token，方向穿过汽车应出现橙色命中段；直接左键汽车应锁线但不改选中，按两次 `Esc` 后再点汽车才恢复选择。

### 本轮收口补记
- [x] 用户确认“汽车只让门口挡、不让玻璃挡”这类精细资产部件暂时基本放弃，后面有需要再说。
- [x] 已更新 `docs/design.md`、`docs/p2_task_schedule.md`、`docs/entity_properties_schema.md`：P2.4 保持整物体粗框二元掩体；P2.5 不补做车门/玻璃/引擎盖材质识别，也不把战争迷雾扩成资产语义编辑器。
- [ ] 未来若重新需要精细汽车掩体，只能另开 GM 手工标注低多边形战斗部件任务；不自动解析模型材质、破窗、空舱、防弹区域或穿透规则。

## 2026-07-18 Codex P2.5 LOS 阶段定义 + 墙体基础遮挡

### 已完成
- [x] 解决阶段矛盾：P2.5 建立 `LOSOccluder`、摄像机自动单视点可见区域和主窗口/投屏当前暗区；P3 扩展多视点、阵营、视距/夜视、灯光/黑暗、烟雾、探索记忆、深度感知合成与性能索引；P4 负责多楼层、多场景长期迷雾状态。
- [x] 新增 `scripts/los_occluder.gd`：只挂墙体，直接消费 `OcclusionGeometry` 的物件根局部边界和四角地面脚印，按墙根世界变换输出 XZ 线段；不创建物理体，不读取 `PickProxy` 或 `CombatBody`。
- [x] 新增 `scripts/los_visibility_polygon.gd`：线段先在交点处分割并去重，再加入地图四边，使用活动边最小堆旋转扫描计算可见多边形；撤回深凹角可能跨墙直连的简单端点三射线草案。
- [x] 新增 `scripts/los_service.gd`：Main 场景级运行时服务，保存主摄像机引用，以所属视口中心射线与 y=0 地面的交点作为玩家观察点，监听墙遮挡体增删/变化；静止时不重算几何，摄像机中心地面点、地图尺寸或墙体事件变化才重算。
- [x] 新增并泛化 `scripts/cast_fog_overlay.gd`：主窗口和投屏窗口各用透明 `SubViewport + Polygon2D` 生成可见区纹理，全屏 `TextureRect` 材质把可见区外压暗；主窗口遮罩层 0、GM 操作 UI 层 1。
- [x] `PlacementController` 追加向后兼容的可选 LOS 脚本参数，只给墙体放置/迁移挂 `LOSOccluder`；`main.gd` 接入地图尺寸、Gizmo 变换、编辑态可透光回写、摄像机自动视点和主窗口/投屏服务。用户指出人工“设为视点/取消视点”不符合操作流程后已删除该按钮与状态。
- [x] `WallProperties.set_blocks_los()` 发出基础语义变化信号，`LOSOccluder` 立即同步并触发服务重算。P2.6 破坏/修复不得覆盖基础字段，必须从 `wall_state != DESTROYED && blocks_los` 推导有效值并驱动运行组件；挡枪层独立推导。
- [x] 更新 `docs/design.md`、`docs/p2_task_schedule.md`、`docs/entity_properties_schema.md`；`docs/drafts/p2_5_los_draft.md` 标记为历史草案并记录端点射线方案撤回。

### 四层调研回执
- [x] 项目现状：P2.4 已交付 `OcclusionGeometry`、独立 `CombatBody`、`CombatLineQuery` 与全局单条瞄准线；`WallProperties.blocks_shot/blocks_los` 已分离。运行态实证人工 Token 观察点设置成功，但当前场景只有两枚 Token 和一辆 `TERRAIN` 汽车、0 个 `LOSOccluder`，因此可见区域仍是整张地图；旧方案又只给投屏加暗区，和“玩家视角先作为默认成果”冲突。
- [x] Godot 源码：精确版本 `4.7-stable`，提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。新增核对 `scene/3d/camera_3d.cpp::project_ray_origin()/project_local_ray_normal()/project_ray_normal()`、`core/math/plane.cpp::Plane::intersects_ray()` 与 `scene/gui/texture_rect.cpp::TextureRect::_notification()`；正交相机统一取所属视口中心射线的地面交点，纹理矩形必须有非空 `texture` 才会提交绘制。显示链继续核对 `Viewport`、`CanvasLayer`、`Polygon2D` 与 `Geometry2D`。
- [x] 官方资料：离线 4.7 `gdd_0540_Camera3D.md`、`gdd_1571_Plane.md`、`gdd_0755_SubViewport.md`、`gdd_0774_Viewport.md`、`gdd_1095_ViewportTexture.md`、`gdd_0762_TextureRect.md`、`gdd_1297_Geometry2D.md` 确认摄像机射线、地面求交、子视口尺寸/更新、动态纹理、纹理矩形方向、世界到屏幕投影和线段交点接口。官方 `godot-demo-projects/viewport/3d_in_2d` 演示采用独立视口 `get_texture()` 后交给二维节点显示；官方没有三维 VTT 墙体 LOS 完整演示。
- [x] 英文社区/开源：`d-bucur/godot-vision-cone` 为 Godot 4、MIT/Apache-2.0、93 星、30 次提交，视野节点挂实体且只支持二维均匀物理射线；`Visibility Polygon 1.0.0` 为 Godot 4、CC0、活动边 `O(N log N)`，固定提交 `3666007881b6348142ddec7424ddc47bc8b0d5db`，移植自公开领域 `byronknoll/visibility-polygon-js`。未找到成熟的 3D VTT 摄像机视点插件；保留活动边算法，把摄像机中心地面点明确作为 Gvtt 当前简化规则，不安装插件。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] `Viewport::Viewport()` 创建渲染视口并取得纹理，`SubViewport` 入树激活/出树停用 -> `CastFogOverlay` 创建非零尺寸透明子视口，真实 `CastView` 先把隐藏 Window 挂树，再取得遮罩纹理，关闭窗口随场景树释放 -> 专项确认子视口尺寸等于投屏窗口，主/投屏视口不同，关闭测试窗口无残留。
- [x] `CanvasLayer::_notification()` 默认绑定 `Node::get_viewport()` 并在退出树时移除画布 -> 主窗口与投屏各挂一份遮罩，共享服务结果但不共享画布 -> 运行态确认主遮罩层 0、UI 层 1，投屏仍属于独立 Window 视口。
- [x] `Camera3D::project_ray_origin()/project_ray_normal()` -> `Plane::intersects_ray()` 取得摄像机中心地面点，`unproject_position()` 把世界可见多边形分别投回主/投屏 -> 专项确认摄像机移动重算、静止不重算；主场景确认观察相机路径为 `/Main/SceneRoot/Camera3D`。
- [x] `Geometry2D.segment_intersects_segment()` 返回线段交点 -> 本地先分割相交墙段，再做活动边扫描 -> 专项覆盖全高直墙、L/深凹共端点、确定性、平移/旋转/缩放和墙后点不可见。
- [x] 场景树退出与渲染 RID 自动清理 -> `LOSService` 监听节点移除并注销遮挡体，投屏关闭 `queue_free()` 整个窗口树 -> 专项确认删墙后原遮挡点立即重新可见。

### 验证
- [x] P2.5 专项运行态回归：`P2_5_LOS_RESULT {"assertions":42,"failed":0,"failures":[]}`；真实 `CastView.open()/close()` 生命周期确认投屏窗口完整释放，主窗口合同确认遮罩绑定主视口、层级/尺寸正确、遮罩像素分出可见/隐藏区，并要求 `LOSFog.texture` 真实绑定视口纹理。
- [x] P2.4 Jolt Physics 回归保持：`P2_4_COMBAT_RESULT {"assertions":56,"failed":0,"failures":[]}`。
- [x] 主场景运行 `helper_live=true`，当前运行日志只有 helper 注册与既有嵌入窗口提示；运行树确认 `/Main/LOSService` 存在，当前场景汽车仍只有 CombatBody、没有 LOSOccluder，说明 P2.5 未越界把非墙地形当遮挡。
- [x] 运行 UI 探查确认“设为视点/取消视点”按钮已删除。主场景临时通过真实 `PlacementController` 放置正式墙体后，`occluder_count=1`、墙前点可见、墙后点隐藏、主遮罩激活且投影多边形为 6 点；临时墙未写入存档。
- [x] 跨模块回归：`P1_RUNTIME_RESULT {"assertions":267,"failed":5}`，通过 262 项。5 项仍为嵌入窗口不更新 GUI hover 导致的素材按钮按下/轻移点击/拖拽阈值/3D 预览/单次放置合成输入夹具失败，与 P2.4 最新记录相同，没有新增失败。
- [x] 本轮功能脚本与测试 `rg -n ":="` 无结果；`git diff --check` 未报告本轮补丁空白错误。

### 未做与人工验收
- [ ] 未做多视点、阵营、规则视距、夜视、灯光/黑暗、烟雾、探索记忆、复杂缓存、跨楼层/场景迷雾、墙体破坏或汽车材质识别；分别留 P2.6、P3、P4。
- [ ] 地面多边形投到倾斜相机时，可见边界附近的高模型可能少量越界露出；P2.5 明确接受该基础限制，深度感知合成留 P3。
- [ ] 仍需 GM 可见窗口确认：放一面真正归类为“墙体”的模型后无需选择 Token，主窗口墙后应立即变暗，平移/旋转摄像机后边界跟随；打开投屏应看到相同暗区，主窗口按钮与属性面板保持清晰。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 端点前/后偏移射线在深凹角可能跨墙连边并漏视。 | 已撤回，改用活动边旋转扫描并新增深凹角回归 |
| 2026-07-18 | 嵌入窗口合成 GUI hover 不更新，导致真实投屏按钮和 5 个素材拖放夹具无法由 MCP 鼠标可靠触发。 | 既有测试通道限制；组件专项已覆盖，真实按钮留 GM 人工验收 |
| 2026-07-18 | 倾斜相机下地面遮罩不含三维深度，高模型边界可能少量露出。 | P2.5 已知限制；P3 深度感知合成待做 |
| 2026-07-18 | 人工“设为视点”脱离当前单机投屏操作流程，且暗区只在投屏显示。 | 已撤回按钮；主摄像机中心自动提供玩家视点，主窗口/投屏共享暗区 |
| 2026-07-18 | 主场景先绑定观察相机、随后 `_adopt_scene_content()` 重挂相机，节点移除事件清空观察源。 | 已改为相机重挂完成后绑定；运行态确认观察相机路径与遮罩层级正确 |
| 2026-07-18 | 用户测试场景看不到墙后黑区。 | 运行态确认当前存档 0 个墙体遮挡体；人工视点曾设置成功但无墙可遮挡。临时正式墙闭环验证通过 |
| 2026-07-18 | 墙体、可见多边形和遮罩 alpha 均正确，但最终画面开关遮罩像素完全相同。 | Godot 4.7 `scene/gui/texture_rect.cpp::TextureRect::_notification()` 在 `texture.is_null()` 时直接退出；已把 `LOSVisibilityMask` 纹理赋给 `LOSFog.texture`，最终帧最大亮度差 `0.776` |
| 2026-07-18 | 首次误判为视口纹理上下翻转，启用 `TextureRect.flip_v` 后黑区跑到墙体反方向。 | 已通过真实墙截图撤回翻转；最终黑区从屏幕中心穿过右下墙体向右下延伸 |

## 2026-07-18 Codex P2.5 最终方向修正：首个 Token 自动视点

### 用户最终规则与实现
- [x] 撤回“主摄像机中心作为玩家视点”的阶段性方案。P2.5 最终以场景树顺序中的第一个 Token 的世界 XZ 坐标为唯一观察点；不增加“设为视点”按钮，后续 Token 不抢占，当前 Token 删除后顺延，没有 Token 时关闭迷雾计算。
- [x] 当前资源栏 `Token (1)` 表示一个已导入 Token 资产，不等于场景只有一个实例。正式运行树确认当前场景有 `网行者test`、`网行者test2` 两个 Token 实例，顺序中的 `网行者test` 为自动观察源。
- [x] `LOSService` 改为持有 Token 引用，静止帧不重算；观察 Token 移动、地图尺寸或墙遮挡变化时重算世界可见多边形。摄像机只负责把同一世界多边形投影到主窗口和投屏，不再决定玩家站位。
- [x] `CastView` 只在存在有效观察 Token 时启用玩家暗区；`main.gd` 不再传入观察摄像机。

### 四层调研补卡
- [x] 项目现状：`ContentRoot` 直接子节点的 Token 都带 `TokenProperties`；正式场景当前是两枚 Token 加一辆地形类汽车，仍为 0 个墙体/`LOSOccluder`，所以截图全图可见是“没有遮挡物”的正确结果，不代表 Token 观察点失效。
- [x] Godot 源码：继续锁定 `4.7-stable` 提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`scene/3d/node_3d.cpp::Node3D::get_global_position()` 从 `get_global_transform().origin` 返回世界位置；`set_global_position()` 写回世界变换，`_propagate_transform_changed()` 负责把变换变化传播到节点。P2.5 只消费 Token 世界 XZ，不引入相机射线或额外物理查询。
- [x] 官方资料：离线 Godot 4.7 `gdd_0673_Node3D.md` 确认 `global_position: Vector3` 是节点世界坐标，并与 `position` 的父级局部坐标区分。当前实现直接读取 `global_position.x/z`，适配 Token 位于 `ContentRoot` 或未来带父变换的情况。
- [x] 英文社区/开源：`d-bucur/godot-vision-cone` 的视野节点随所属实体移动，证明“视野源跟随角色实体”是可复用模式；其二维多射线实现和插件节点结构不适合本项目已有活动边多边形与主/投屏遮罩，因此只采用实体跟随思路，不安装插件。

### 源码行为 -> 本地实现 -> 验证
- [x] `Node3D::get_global_position()` 取得 Token 世界位置 -> `LOSService._process()` 读取首个 Token 的 XZ 并只在坐标变化时 `recompute()` -> 专项覆盖自动选择、静止不重算和 Token 移动重算。
- [x] 场景树节点退出后对象失效 -> `LOSService._on_tree_node_removed()` 清当前观察源，下一帧按 `ContentRoot` 顺序查找下一个 Token -> 专项覆盖后续 Token 不抢占、删除后顺延和最后一个删除后关闭迷雾。
- [x] 摄像机投影与世界可见区分离 -> `CastFogOverlay`、主遮罩和投屏继续消费同一世界多边形 -> 投屏生命周期测试改用 Token 夹具并保持遮罩纹理、尺寸与视口隔离合同。

### 验证与未做
- [x] P2.5 专项运行态回归：`P2_5_LOS_RESULT {"assertions":43,"failed":0,"failures":[]}`。
- [x] P2.4 回归保持：`P2_4_COMBAT_RESULT {"assertions":56,"failed":0,"failures":[]}`。
- [x] 正式主场景 `helper_live=true`、`current_run_errors=[]`；运行树确认两个 Token、`/Main/LOSService` 和绑定非空 `ViewportTexture` 的 `/Main/PlayerFogOverlay/LOSFog` 均存在。运行截图确认当前场景没有墙，因此全图可见。
- [ ] 本轮远程输入可滚动到正式墙体资产，但嵌入窗口无法可靠触发该素材按钮的 `button_down` 和拖放状态，未重新完成 Token 版真实鼠标放墙。此前同一正式墙资产的放置、`occluder_count=1`、墙前可见/墙后变暗和最终帧亮度差已验证；仍需 GM 在可见窗口做最终体感确认。
- [ ] 未做多 Token 视野合并、手动指定主 Token、阵营/玩家权限、规则视距、探索记忆、复杂缓存或完整战争迷雾；分别留 P3/P4，不并入 P2.5。

## 2026-07-18 Codex P2.5 Token 不跟随问题诊断

### 已确认
- [x] 用户移动屏幕中央 Token 后暗区不变化。运行树证明场景实际有两个同资产实例：`网行者test` 位于世界 XZ 约 `(19.17, 3.89)`、在当前画面右侧之外；中央可见并被用户移动的是 `网行者test2`，位于约 `(0.10, -0.15)`。
- [x] 当前“场景树第一个 Token”规则选中的是画面外 `网行者test`，因此移动中央 `网行者test2` 不会触发观察点变化。问题属于观察实例选择规则错误，不是 Godot `global_position` 不更新。
- [x] 同次正式运行树仍只有两个 Token 和一辆地形类汽车，没有墙体、`WallProperties` 或 `LOSOccluder`；当前没有可产生墙后暗区的遮挡物。
- [x] `helper_live=true`、本次 `current_run_errors=[]`，遮罩 `TextureRect` 仍绑定非空视口纹理；排除运行通道和此前空纹理显示故障。

### 待确认修正
- [ ] 不再使用隐藏的“场景树第一个 Token”规则。建议改为当前选中或正在移动的 Token 自动成为观察源，不增加独立“设为视点”按钮；需要用户确认多 Token 下的这一交互口径后再改功能。

## 2026-07-18 Codex P2.5 当前 Token 自动接管修复

### 已完成
- [x] 用户确认采用“每个从 Token 栏拖出的对象都能驱动视野变化”的方向，不再增加第三个测试 Token 掩盖错误。`PlacementController` 既有 `attach_entity_type_properties()` 已保证 Token 类对象挂 `TokenProperties`，无需重复组件逻辑。
- [x] `main.gd::_on_selection_changed()` 在当前目标类型为 Token 时调用 `LOSService.set_token_observer()`。新放置对象、编辑态点击/Gizmo 移动、运行态短按/拖动原本都汇入同一选择信号，因此一次接入覆盖全部操作；选择非 Token 或空地保留上一个玩家视点。
- [x] 启动尚未选择时仍用场景树第一个 Token 作回退；一旦选择/移动任意 Token 就由它接管。当前观察 Token 删除后继续按场景顺序顺延，无 Token 时关闭迷雾计算。多 Token 可见区域合并仍留 P3。

### 验证
- [x] P2.5 专项回归扩展到 `P2_5_LOS_RESULT {"assertions":45,"failed":0,"failures":[]}`：第二个 Token 主动接管后，移动旧 Token 不重算，移动当前 Token 才重算；原有几何、墙体、投屏和清理合同保持。
- [x] P2.4 回归保持 `P2_4_COMBAT_RESULT {"assertions":56,"failed":0,"failures":[]}`。
- [x] 正式主场景运行态先确认观察路径从画面外 `/root/Main/SceneRoot/ContentRoot/网行者test` 切到中央 `/root/Main/SceneRoot/ContentRoot/网行者test2`。移动旧 Token 时重算次数保持 `2`，移动中央当前 Token 时从 `2` 增到 `3`。
- [x] 通过正式 `_place_model()` / `PlacementController.place_model()` 链在运行副本临时放置“混凝土破损机箱3d模型”：对象数 `3 -> 4`，同时具有 `WallProperties` 与 `LOSOccluder`，观察源仍为 `网行者test2`，可见多边形为 8 点。
- [x] 可见截图确认：Token 位于墙左侧时黑区从墙向右下扩散；把同一当前 Token 从世界 XZ 约 `(0.10, -0.15)` 移到 `(-3.90, 2.85)` 后，重算次数 `7 -> 8`，黑区改为从墙向右上扩散。临时墙和 Token 位移均未保存，停止运行后丢弃。
- [x] 跨模块 P1 回归保持 `P1_RUNTIME_RESULT {"assertions":267,"failed":5}`；仍是既有 5 条嵌入窗口素材按钮/拖放合成输入失败，没有新增选择或 LOS 失败。

### 问题状态修正
- [x] 上一节“待确认修正”已解决：隐藏的首个 Token 规则仅保留为启动回退，不再阻止用户当前操作的 Token 接管视野。

## 2026-07-18 Codex P2.5 暗区不得遮挡 Gizmo 修复

### 已完成
- [x] 采用用户提出的“Gizmo 最后画”方向，但不依赖场景树顺序：新增 `scripts/gm_tool_overlay.gd`，用透明 `SubViewport` 共享主窗口 `World3D`，镜像主摄像机且只渲染 GM 专用第 20 层，再由 `CanvasLayer` 合成到玩家暗区之上。
- [x] Gizmo 自带的二维旋转辅助线 `Control` 迁入同一 GM 工具前景层；全屏工具纹理和辅助线都设为鼠标穿透，不改变选择、拖动、旋转或缩放输入。
- [x] 主窗口显示顺序固定为：玩家暗区层 0、GM 工具前景层 1、GM 操作 UI 层 2。`CastView` 未接入 `GMToolOverlay`，玩家投屏继续通过相机遮罩排除第 20 层。

### 四层调研与源码对照
- [x] 项目现状：`PlayerFogOverlay` 是层 0 的 `CanvasLayer`，旧 `UI_Layer` 为层 1；Gizmo 的 3D 实例均在第 20 渲染层，插件另有 `_surface: Control` 绘制旋转辅助线。暗区不接鼠标但会在视觉上覆盖先完成的 3D 渲染，因此“能选中”与“看得清手柄”是两个问题。
- [x] Godot 源码：精确版本 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`scene/main/viewport.cpp` 负责 Viewport/World3D 场景与视口纹理；`scene/3d/camera_3d.cpp::set_cull_mask()` 把相机层遮罩交给 RenderingServer；`scene/main/canvas_layer.cpp` 按画布层独立排序，不能靠 3D 节点在场景树中的先后越过 CanvasLayer。Godot 编辑器 Gizmo 链继续对照 `editor/scene/3d/node_3d_editor_plugin.cpp` 与 `node_3d_editor_gizmos.cpp`。
- [x] 官方资料：离线 4.7 `gdd_0755_SubViewport.md`、`gdd_0774_Viewport.md`、`gdd_1095_ViewportTexture.md`、`gdd_0540_Camera3D.md`、`gdd_0780_VisualInstance3D.md` 与 `gdd_0081_Canvas_layers.md` 确认透明子视口、共享 World3D、动态纹理、相机 `cull_mask` 和画布层顺序合同。
- [x] 英文社区/开源：`s1lv3rdr4g0ngames/Outline-Demo` 与 `ualac/godot-outline3d` 都采用“透明第二视口 + 镜像相机 + 专用渲染层 + 纹理回贴”的 Godot 4 模式；只复用该合成结构，不引入其轮廓着色器或插件。Godot Forum 的多相机叠加方案也采用同一路径。

### Godot 行为 -> 本地实现 -> 验证
- [x] `Camera3D::set_cull_mask()` 隔离渲染层 -> `GMToolCamera.cull_mask=1 << 19`，每帧同步主相机变换、投影、视野角、正交尺寸和裁剪面 -> 专项确认遮罩为 `524288` 且相机变换/投影一致。
- [x] Viewport 共享 World3D 并输出 ViewportTexture -> `GMToolViewport.world_3d` 指向主视口世界，透明背景且持续更新，`GMToolTexture` 全屏回贴 -> 专项确认世界相同、尺寸跟随、纹理非空且 `mouse_filter=IGNORE`。
- [x] CanvasLayer 独立排序 -> `PlayerFogOverlay.layer=0`、`GMToolOverlay.layer=1`、`UI_Layer.layer=2` -> 运行态节点属性逐项确认 `0 < 1 < 2`。
- [x] Gizmo 二维辅助线原由 `_surface.get_canvas_item()` 直接提交 -> 保留原对象引用，只把 `_surface` 改挂到 GM 工具前景层 -> 专项确认归属与鼠标穿透；真实窗口选中 `网行者test2` 后，三轴箭头、旋转环、选择框和无限轴在暗区上保持明亮原色。

### 验证与边界
- [x] P2.5 专项：`P2_5_LOS_RESULT {"assertions":52,"failed":0,"failures":[]}`。
- [x] P2.4 回归：`P2_4_COMBAT_RESULT {"assertions":56,"failed":0,"failures":[]}`。
- [x] P1 跨模块：`267` 项中仍为既有 5 个嵌入窗口素材拖放夹具失败，没有新增失败。
- [x] 主场景 `helper_live=true`、本次 `current_run_errors=[]`；运行树确认 `SharedGizmo`、`GMToolOverlay/GMToolViewport/GMToolCamera/GMToolTexture` 和迁入的辅助线 Control 均存在。功能验证后已停止运行，未保存测试选择或场景变化。
- [ ] 远程合成鼠标未可靠触发“投屏”按钮，未完成玩家窗口截图；结构确认 `GMToolOverlay` 只由 `main.gd` 创建在主窗口，`cast_view.gd` 没有该接入。仍需 GM 手动点一次“投屏”，确认玩家窗口有暗区但没有 Gizmo。
- [ ] 本轮没有扩展多视点、阵营、规则视距、探索记忆、深度感知合成、复杂缓存或墙体破坏；继续分别留 P3/P4/P2.6。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 玩家暗区在编辑态视觉压黑 Gizmo、选择框和旋转辅助线。 | 已修复；GM 专用第 20 层通过透明第二视口在暗区之后合成，二维辅助线同步迁入前景层 |
| 2026-07-18 | 单纯把 Gizmo 节点移到场景树最后是否足够。 | 不足；3D 先于 CanvasLayer 合成，现以独立 GM 工具画布实现用户所说的“最后画” |

## 2026-07-18 Codex P2.5 收尾后“阴影反向/Token 不生效”复查

### 运行态证据与结论
- [x] 本次主场景 `helper_live=true`、`current_run_errors=[]`；正式内容仍只有 `网行者test`、`网行者test2` 和地形类汽车，共 3 个对象，没有墙体、`WallProperties` 或 `LOSOccluder`。
- [x] `/Main/PlayerFogOverlay/LOSVisibilityMask/VisiblePolygon` 实测为覆盖视口的大矩形四点，`LOSFog.flip_v=false` 且纹理非空；当前输出是“整张地图可见”，不存在可随 Token 改变方向的墙后暗区。
- [x] 两枚 Token 世界位置正常：`网行者test` 约 `(19.17, 3.89)`，`网行者test2` 约 `(0.10, -0.15)`。没有遮挡墙时，无论哪枚 Token 成为观察者，最终可见区域都是完整地图，因此移动看不出变化。
- [x] 上一轮方向正确的可见验证依赖运行副本里通过正式放置链临时创建的墙；日志当时已注明未保存。收尾停止运行后临时墙被释放，这是“刚才正确、重开后没有效果”的直接原因，不是 `GMToolOverlay` 改变了 LOS 算法或纹理方向。
- [x] 远程嵌入窗口再次无法可靠触发墙素材的点击/拖放，未在本次运行副本重建墙；不为绕过输入通道而修改功能代码。已停止运行，没有保存场景变化。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 收尾后用户看到阴影似乎反向或 Token 不再驱动变化。 | 已定位为正式场景没有墙；此前测试墙仅存在于未保存的运行副本，停止运行后消失。需在墙体栏正式放置并保存一面墙后再做体感验收 |

## 2026-07-18 Codex P2.5 编辑态 Token 观察者条件修复

> 更正上一节结论：正式场景没有墙只能解释本次重开后无法复现，不能解释用户在带墙画面中亲眼看到的反向结果。此前把“没有墙”直接判为根因属于过早结论，本节以独立可见对照和主场景代码链完成纠正。

### 四层复查与根因
- [x] 项目现状：`main.gd::_on_selection_changed()` 把 `LOSService.set_token_observer()` 包在 `_is_runtime_token_operation_allowed()` 中，而该条件第一项是 `ModeGate.is_run()`。因此编辑态点击或用 Gizmo 移动中央 Token 时，LOS 观察者仍可能停留在启动回退的画面外首个 Token，造成眼前 Token 不驱动阴影、方向像是反的。
- [x] Godot 源码：继续锁定 `4.7-stable` 提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`Node3D::get_global_position()` 与变换传播链确认 Token 世界位置会随 Gizmo 更新；`CanvasLayer`/Viewport 合成只改变绘制顺序，不会修改 LOS 观察者或世界多边形。
- [x] 官方资料：离线 4.7 `gdd_0673_Node3D.md`、`gdd_0755_SubViewport.md`、`gdd_0774_Viewport.md`、`gdd_0540_Camera3D.md` 继续支持“世界位置驱动可见区、子视口只负责显示”的职责边界。
- [x] 社区方案：Godot 4 透明第二视口方案仍只提供专用层合成，不参与视野源选择；独立可见诊断保留 GM 工具前景层后，Token 在横墙两侧时亮区/暗区均正确翻转，排除 `GMToolOverlay` 和纹理方向是根因。

### 修复
- [x] `main.gd::_on_selection_changed()` 现在只要选中有效 Token，就在编辑态和运行态统一调用 `LOSService.set_token_observer()`；战斗瞄准仍单独受 `_is_runtime_token_operation_allowed()` 限制，不会在编辑态启动。
- [x] `tests/p1_runtime_regressions.gd::_test_edit_token_selection_keeps_runtime_tools_off()` 新增真实 Main 场景断言：编辑态选中测试 Token 后，LOS 观察者必须立即等于该 Token，同时战斗瞄准仍关闭。
- [x] 临时可见诊断场景固定绿色 Token、红色横墙、真实 LOS 服务/遮罩和 GM 工具前景层；Token 从负 Z 移到正 Z 前后，两张截图均显示 Token 所在侧明亮、墙另一侧变暗。诊断文件已删除，不进入项目交付。

### 验证
- [x] P1 主场景回归：`P1_RUNTIME_RESULT {"assertions":272,"failed":5}`；新增编辑态 LOS 观察者断言通过，失败仍是既有 5 个嵌入窗口素材拖放夹具，没有新增失败。
- [x] P2.5 专项：`P2_5_LOS_RESULT {"assertions":52,"failed":0,"failures":[]}`。
- [x] P2.4 回归：`P2_4_COMBAT_RESULT {"assertions":56,"failed":0,"failures":[]}`。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 编辑态移动当前 Token 时暗区仍由画面外首个 Token 决定，视觉上像阴影反向。 | 已修复；Token 接管 LOS 不再受运行态条件限制，战斗瞄准权限保持不变 |
| 2026-07-18 | 复查时把“正式场景没有墙”过早当成用户现象根因。 | 已撤销该结论；独立两侧可见对照排除合成方向，主场景条件链定位并修复真实问题 |
## 2026-07-18 Codex 编辑态禁止运行态射击线

### 已完成
- [x] 修正 `main.gd`：编辑态选中 Token 不再自动进入战斗瞄准，不显示半圆/射击线，不允许锁线，也不会拦截普通 PickProxy 拾取。
- [x] 同步收紧 P2.5 玩家视点边界：编辑态点击/Gizmo 移动只用于备团编辑，不接管玩家视点；运行态选中或移动 Token 才触发玩家视点与迷雾重算。
- [x] 补回归：`tests/p1_runtime_regressions.gd` 新增编辑态 Token 选中断言，覆盖“不启动 combat aim / 不阻塞选择 / 不能锁线”。
- [x] 更新 `docs/design.md` 与 `docs/p2_task_schedule.md`：Token 射击线/瞄准线是运行态入口，编辑态不出现运行态才需要的操作。

### 调研依据
- [x] 项目现状：`main.gd::_select_entity()` 与 `_on_selection_changed()` 旧逻辑只看 Token 类型，不看 `ModeGate`，所以编辑态选中 Token 也会 `begin_combat_aim()`；P2.5 旧文档还写了编辑态点击/Gizmo 移动接管玩家视点，和“编辑态只备团”冲突。
- [x] Godot 源码：`4.7-stable` 完整源码包包含 `scene/main/viewport.cpp`、`scene/3d/camera_3d.cpp` 与 `editor/scene/3d/node_3d_editor_plugin.cpp`；`Viewport` 输入链支持前序处理后 `set_input_as_handled()` 阻止后续未处理输入，`Camera3D::project_ray_origin()/project_ray_normal()` 仍只作为运行态射击线几何依据。
- [x] 官方资料：离线 `gdd_0774_Viewport.md` 说明 `push_input()` 传播顺序为 `_input()`、`Control._gui_input()`、快捷键、`_unhandled_input()`，前序 `set_input_as_handled()` 会阻止后续调用；`gdd_0021_Listening_to_player_input.md` 说明 `_unhandled_input()` 适合处理离散输入事件。
- [x] 社区/常见模式：运行工具按当前模式启停，编辑态选中只维护编辑器选择/Gizmo，跑团预览、锁线、玩家视点属于运行态工具，不应混在备团编辑里。

### 验证
- [x] 静态检查：`rg -n ":=" scripts/main.gd tests/p1_runtime_regressions.gd` 无命中；`git diff --check -- scripts/main.gd tests/p1_runtime_regressions.gd docs/design.md docs/p2_task_schedule.md devlog/DEVLOG.md` 通过。
- [x] P2.4 专项：`P2_4_COMBAT_RESULT {"assertions":56,"failed":0,"failures":[]}`。
- [x] P1 场景回归执行到 `P1_RUNTIME_RESULT {"assertions":271,"failed":5}`；新增编辑态运行工具门禁断言未失败。剩余 5 项仍是既有嵌入窗口素材按钮/拖放合成输入夹具失败。
- [ ] 仍需 GM 可见窗口确认：切到编辑态，点选 Token 时只应看到编辑 Gizmo/属性面板，不应出现半圆或射击线；切到运行态再点 Token，才应出现 P2.4 的瞄准半圆/战斗线。

## 2026-07-18 Codex 场景/模组入口状态核查

### 已确认
- [x] 当前启动主场景固定为 `scenes/main.tscn`；它是 GM 工具外壳，不是用户地图本身。用户地图内容由 `SceneSessionController` 清空/读回 `ContentRoot`，再由 `ModuleGate` 扫描场景清单。
- [x] `ModuleGate` 仍硬编码默认模组名 `测试模组`，启动时扫描 `user://modules/测试模组/_canonical/*.scn`，并把排序后的第一个场景设为起始地点；如果用户数据目录里有旧 `.scn`，打开项目就会继续出现旧场景。
- [x] 本机 `user://` 实测存在 `场景1.scn` 与 `场景2.scn`；项目目录旧迁移源 `res://modules/测试模组/_canonical/` 也仍有 `场景1.scn`、`场景2.scn`。因此用户看到旧 `场景2` 不是错觉，而是当前扫描策略把旧测试模组残留当作当前真值。
- [x] 左栏“新建”当前调用 `SceneSessionController.create_scene()` -> `ModuleGate.add_scene()`，只会自动起名 `场景N` 并切到空内容层；它不是“新建工程/新建模组”入口，也不会弹出“导入模组”选择。
- [x] `docs/design.md` 的产品目标是“GM 管理完整冒险，不是一张张孤立地图”；`docs/architecture.md` 与 `docs/CODEX_HANDOFF.md` 说明当前只是基础场景保存/加载闭环，真正多场景/模组增强仍归 P4。`docs/multi_scene_draft.md` 当前为空文件，不能作为有效细节依据。

### 判断
- [x] 当前场景管理确实存在产品口径问题：技术上能保存/切换场景，但入口仍停留在旧“测试模组 + 场景N”的开发阶段；这与“打开应为空工程，新建工程后再导入/创建模组”的目标不一致。
- [ ] 尚未改代码：修正会涉及旧 `user://` 存档的保留/隐藏/迁移策略，以及新建/导入模组入口设计，不能作为普通清理直接删除用户数据。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 打开项目自动进入旧测试模组场景，而不是空工程入口。 | 已定位；根因是 `ModuleGate` 硬编码 `测试模组` 并扫描 `user://` 旧 `.scn` |
| 2026-07-18 | 左栏“新建”实际新建 `场景N`，不等于新建工程/模组。 | 已确认；需后续重做模组入口与旧存档处理策略 |

## 2026-07-18 Codex 场景/模组入口修复

### 已完成
- [x] `ModuleGate` 启动改为空状态：不再自动创建/打开 `测试模组`，不再启动时迁移旧测试场景，也不再自动选中排序第一个 `.scn`。
- [x] 新增显式入口：新建模组、导入模组文件夹、恢复旧测试数据。旧 `测试模组` 数据保留在磁盘上，只通过“恢复旧数据”手动打开，不删除、不覆盖。
- [x] `main.gd` 启动不再自动 `add_scene()`；没有打开模组时左栏显示入口提示，场景新建、保存、宽高编辑置灰或提示先打开模组。
- [x] 左栏按钮文案从“新建”改为“新建场景”，避免继续把“新建模组/工程”和“新建场景”混成一个动作。
- [x] `tests/p1_runtime_regressions.gd` 新增启动断言：开机不得自动打开模组、不得暴露旧场景名；后续测试显式创建临时模组 `_p1_runtime_regression_module`，结束只清理该临时目录。

### 四层调研与源码对照
- [x] 项目现状：`scripts/module_gate.gd` 原 `_ready()` 硬编码 `测试模组` 并扫描 `_canonical/*.scn`；`scripts/main.gd` 原启动兜底在场景列表空时自动建 `场景1`。这两处合起来导致旧 `场景1/场景2` 每次回来。
- [x] Godot 源码：锁定 `4.7-stable` 提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`editor/project_manager/project_manager.cpp` 的 `_new_project()`、`_import_project()`、`_scan_projects()` 和 `editor/project_manager/project_dialog.cpp` 的创建/导入模式显示：项目管理器提供显式入口，不自动打开历史列表第一项。
- [x] 官方资料：离线 4.7 文档确认 `FileDialog.ACCESS_FILESYSTEM`、`FILE_MODE_OPEN_DIR`、`use_native_dialog`、`dir_selected`、`DirAccess.make_dir_recursive_absolute()`、`DirAccess.copy_absolute()`、`FileAccess.file_exists()`、`user://` 存储位置和 Error 常量可用。
- [x] 社区/常见模式：启动页/项目列表应把“创建”和“导入”作为独立入口；旧数据恢复是显式迁移动作，不应混入普通启动流程。未引入插件，原因是本项目只需要轻量文件夹清单入口，插件级项目管理会扩大边界。

### Godot 行为 -> 本地实现 -> 验证
- [x] Godot 项目管理器不自动打开第一个旧项目 -> `ModuleGate._ready()` 只清空当前状态 -> 新增回归断言 `ModuleGate.has_open_module() == false`、场景列表为空。
- [x] Godot 创建/导入是显式入口 -> `main.gd` 增加“新建模组 / 导入模组 / 恢复旧数据”按钮 -> 手动验证路径：启动后先看到入口提示，点对应按钮才进入模组。
- [x] 旧数据不应静默迁移 -> `_migrate_legacy_scenes()` 只由 `recover_legacy_test_module()` 调用 -> 旧 `测试模组` 仍可恢复，但不会开机自动出现。

### 验证与边界
- [x] 静态检查：`rg -n ":=" scripts/module_gate.gd scripts/main.gd tests/p1_runtime_regressions.gd` 无命中；`git diff --check -- scripts/module_gate.gd scripts/main.gd tests/p1_runtime_regressions.gd` 通过。
- [ ] 自动运行测试未完成：命令行 Godot 4.7 控制台版在项目加载 `godot-rust` GDExtension 时崩溃，日志显示 `Initialize godot-rust (API v4.5.stable.official, runtime v4.7.stable.official)` 后 signal 11，发生在脚本测试执行前。
- [ ] 仍需 GM 可见窗口确认：启动应为空模组入口；点“恢复旧数据”才出现旧 `场景1/场景2`；点“新建模组”后场景列表为空，再点“新建场景”才创建 `场景1`。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 打开项目自动进入旧测试模组场景，而不是空工程入口。 | 已修复；启动不再打开任何模组，旧数据改为显式恢复 |
| 2026-07-18 | 左栏“新建”实际新建 `场景N`，不等于新建工程/模组。 | 已修复入口文案和层级；“新建模组”和“新建场景”拆开 |
| 2026-07-18 | 命令行测试被 GDExtension 初始化崩溃阻断。 | 待处理；与本次脚本变更无直接证据关联，但阻止自动回归完成 |

## 2026-07-18 Codex 场景入口取舍复查

### 结论
- [x] 当前“未打开模组/未选场景但仍可进入主编辑界面”的方向不够安全：拖放内容会落到运行中的 `ContentRoot`，但没有 `ModuleGate` 保存目标，本质是悬空内存草稿，关闭后不可恢复。
- [x] 推荐采用 Godot 式入口约束，但不完全照搬 Godot 的独立项目管理器：Gvtt 启动仍可在同一个窗口里显示“模组首页”，但在未打开模组并选择/创建场景前，模型拖放、地面编辑、保存、场景尺寸、运行态切换等内容编辑入口应全部禁用或被遮罩挡住。
- [x] 推荐流程：启动 -> 模组首页；新建模组时同时要求创建第一个场景或进入场景选择页；导入/恢复模组后若已有场景则选择一个场景进入编辑，若没有场景则先创建场景。进入编辑器后，内容在内存中编辑，保存目标明确为 `user://modules/<模组>/_canonical/<场景>.scn`。

### 调研依据
- [x] 项目现状：`main.gd::_finish_model_drag()` 仍可调用 `_place_model()`，后者通过 `PlacementController.place_model()` 写入 `_content_root` 并 `_mark_scene_dirty()`；但 `ModuleGate.save_current_scene()` 在无模组时返回 `ERR_UNCONFIGURED`，说明内容可进入内存却无保存归属。
- [x] Godot 源码：`4.7-stable` 的 `ProjectManager` 只在项目列表/入口页提供 Create、Import、Scan；打开/运行项目前均检查选中项目，空列表显示入口 placeholder，不让用户在无项目归属下编辑资源。
- [x] 官方资料：Godot 官方 Project Manager 文档说明启动先进入项目管理器，创建或导入项目后才打开编辑器；创建项目要求项目名和保存路径，导入已有项目要求选择包含 `project.godot` 的位置。
- [x] 社区/开源：Godot Launcher 等项目工具同样以项目列表为入口；新增/导入项目只注册或创建项目，再点击项目进入编辑，不把未归属内容混入编辑区。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 无模组/无场景时拖放会形成不可保存的内存草稿。 | 已确认；建议下一步加入口遮罩和全编辑入口门禁 |
| 2026-07-18 | 是否完全照抄 Godot 项目管理器。 | 不完全照抄；采用其“先选归属再编辑”的原则，界面形态按 Gvtt 单 exe 做模组首页 |

## 2026-07-18 Codex 模组首页与首场景落盘

### 已完成
- [x] 新建/导入/恢复模组入口已移出场景编辑栏，启动时显示独立模组首页；首页列出 `user://modules/` 下的已有模组，点击后才进入场景编辑器。场景栏只保留新建场景、保存场景、尺寸和场景列表。
- [x] 新建模组、导入空模组或打开历史空模组时，自动创建默认空场景 `场景1`，套用默认地面与 100×100 米尺寸，并立即保存到 `user://modules/<模组>/_canonical/场景1.scn`。
- [x] 导入已有 `.scn` 的模组时保留并打开原场景，不额外创建 `场景1`；空文件夹现在也可作为空模组导入，不再返回 `ERR_FILE_NOT_FOUND`。
- [x] 后续点击“新建场景”同样会在切入默认空场景后立即落盘，场景列表不再出现只有内存名字、关闭程序就消失的悬空条目。
- [x] 增加统一 `_has_editable_scene()` 门禁；无模组/无场景时，首页接管输入，模型点击/拖放/最终放置、地面纹理与平铺、场景宽高、运行态切换、视角子模式和投屏入口均不能修改场景。

### 四层调研与源码对照
- [x] 项目现状：`main.gd::_build_ui()` 原把模组按钮建在场景栏；`_open_first_scene_or_empty()` 对空模组只套默认舞台；`ModuleGate.add_scene()` 只创建 `LocationRef` 内存条目，只有 `save_current_scene()` 才真正调用 `ModuleIo.save_scene_tree()` 落盘。
- [x] Godot 源码：精确版本 `4.7-stable`，提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`editor/project_manager/project_manager.cpp` 的 `_update_list_placeholder()`、`_new_project()`、`_import_project()`、`_open_selected_projects()` 与 `editor/project_manager/project_dialog.cpp::ProjectDialog::ok_pressed()` 形成“入口页 -> 校验/创建或导入 -> 发出 project_created -> 启动编辑器”链；未选项目时打开检查直接返回。
- [x] 官方资料：离线 4.7 `gdd_0057_Using_the_Project_Manager.md` 明确启动先进入 Project Manager（项目管理器），创建/导入后才打开编辑器；`gdd_0185_File_paths_in_Godot_projects.md` 说明 `user://` 是可持久写目录，但不会替代文档的模组归属；`gdd_1241_DirAccess.md` 核对 `get_directories_at()`、`get_files_at()` 与递归建目录接口。
- [x] 英文社区/开源：Godot 官方 `godot-demo-projects` 仍通过 Project Manager 的 Import/Scan 注册项目；Yet Another Scene Manager 只处理游戏运行时换场景，Godot Project Management 是 Godot 3.4 看板插件，均不适合 Gvtt 的单机 GM 工作区入口。本轮不引入插件，只复用“先选归属再编辑”的成熟模式。

### Godot 行为 -> 本地实现 -> 验证
- [x] 项目列表/空首页 -> `_build_module_home()` + `_sync_module_home()` 构建已有模组列表和新建/导入/恢复入口 -> 启动断言确认 `ModuleHome.visible=true` 且 `_has_editable_scene()==false`。
- [x] 选择项目后进入编辑器 -> `_on_open_module_pressed()` / `_open_first_scene_or_create()` 只在模组与场景都有效时隐藏首页 -> 空目录导入回归确认编辑门禁随后解锁。
- [x] 新工程先建立持久归属 -> `_save_current_scene_if_missing()` 在首场景和所有新场景首次切入时立即保存 -> 回归确认 `场景1.scn` 文件真实存在。
- [x] 无项目不能编辑 -> `_place_model()` 等入口统一检查 `_has_editable_scene()` -> 无模组时用无效模型类别直调最终放置入口，`ContentRoot` 子节点数保持不变且未越界。

### 验证与边界
- [x] `rg -n ":=" scripts/main.gd scripts/module_gate.gd tests/p1_runtime_regressions.gd` 无命中；`git diff --check -- scripts/main.gd scripts/module_gate.gd tests/p1_runtime_regressions.gd devlog/DEVLOG.md` 通过。
- [x] Godot `4.7.stable.official.5b4e0cb0f` 正常权限恢复模式导入退出码 0，无 GDScript 解析错误；无扩展隔离工程刷新全局类缓存后完整运行 `res://tests/p1_runtime_regressions.tscn`，结果 `P1_RUNTIME_RESULT {"assertions":291,"failed":0,"failures":[]}`。
- [x] 主工程直接命令行运行仍在测试前崩溃：`godot-rust` 报 API `4.5`、runtime `4.7` 后 signal 11；已用仓库现有 `build/p2_4_full_regression_shell` 隔离旧扩展并完成真实脚本/场景回归，不把主工程原生层崩溃包装成通过。
- [ ] 仍需 GM 可见窗口体感确认：首页在 1024×576 最小窗口和常用桌面窗口下排版正常；新建模组后直接进入 `场景1`；重开程序后首页列表可再次打开该模组；导入已有场景的模组不多出场景。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 新建/导入模组入口混在场景编辑栏。 | 已修复；入口移到启动模组首页，编辑栏只管理场景 |
| 2026-07-18 | 空模组和新场景只有内存条目，可能关闭后消失。 | 已修复；首次创建即保存默认空场景文件 |
| 2026-07-18 | 无模组/无场景仍可通过放置链写入 `ContentRoot`。 | 已修复；首页输入阻挡加最终放置函数双层门禁 |
| 2026-07-18 | 前一节建议“新模组先空着再手动建场景”。 | 已由本节产品决定取代；空模组现在自动创建并保存 `场景1` |
| 2026-07-18 | 主工程命令行测试被 4.5/4.7 `godot-rust` 不兼容崩溃阻断。 | 业务回归已用无扩展隔离工程完成 291/291；原生扩展兼容问题仍待单独处理 |

## 2026-07-18 Codex 模组首页测试入口

### 已完成
- [x] 模组首页固定增加到场景编辑器右上顶栏“模组”按钮；首页增加“返回编辑器”，不再只能在启动时看见。
- [x] 从 Godot 编辑器以可见窗口运行项目时，自动打开或创建固定的“开发测试模组”，空模组继续自动生成并保存 `场景1`；日常 F5/F6 测试不再每次先点模组首页。
- [x] 点击右上“模组”前若当前场景有未保存改动，先保存再打开首页；保存失败则停留在编辑器，避免为了切页面丢数据。
- [x] 导出的正式 EXE 保持原产品流程：启动先显示模组首页，不自动进入开发测试模组。
- [x] 新增 `docs/module_workflow.md`，记录页面位置、开发测试路径、正式启动规则和无窗口测试边界；`docs/design.md` 已增加入口链接。

### 四层调研与源码对照
- [x] 项目现状：`main.gd` 原 `_build_module_home()` 只创建全屏启动页，顶栏没有返回入口；启动末尾始终 `_set_module_home_visible(not _has_editable_scene())`，导致每轮可见测试必须先选择模组。
- [x] Godot 源码：精确版本 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`core/os/os.cpp::OS::has_feature()` 在 `TOOLS_ENABLED` 下定义 `editor_runtime = !_in_editor`；`main/main.cpp` 解析 `--headless` 后把显示驱动设为 `headless`、音频设为 `Dummy`；`servers/display/display_server_headless.cpp::DisplayServerHeadless::create_func()` 创建无窗口显示服务器。
- [x] 官方资料：离线 4.7 `gdd_0170_Feature_tags.md` 明确列出 `editor_runtime`；`gdd_1287_Engine.md` 说明编辑器按 F5 运行与导出程序可用特征标签区分；`gdd_1242_DisplayServer.md` 说明 `--headless` 使用名为 `headless` 的显示服务器。
- [x] 英文社区/开源：Godot 社区常用特征标签在开发时跳过片头或启动页；社区同时指出泛用 `editor` 会覆盖手动启动编辑器二进制的情况。本地采用更窄的 `editor_runtime` 并叠加非 `headless` 条件，不引入插件。

### Godot 行为 -> 本地实现 -> 验证
- [x] 编辑器运行项目特征 -> `_is_development_workspace_run()` 检查 `OS.has_feature("editor_runtime")` 且 `DisplayServer.get_name() != "headless"` -> 无窗口回归断言此函数为 false。
- [x] 开发时跳过启动页 -> `_try_open_development_workspace()` 打开/创建 `开发测试模组`，复用 `_open_first_scene_or_create()` -> 正式模组和首场景保存链没有复制。
- [x] 启动页可再次进入 -> 顶栏 `_module_home_btn` 调 `_on_module_home_pressed()`，首页 `_module_home_back_btn` 调 `_on_module_home_back_pressed()` -> 回归确认首页可开、返回按钮可见且能回编辑器。
- [x] 容器稳定布局 -> 顶栏宽度从 440 调到 530，新增 70 像素“模组”按钮，仍由右上锚点和 `HBoxContainer` 排列 -> 不改现有模式、投屏与视角按钮职责。

### 验证与边界
- [x] `rg -n ":=" scripts/main.gd tests/p1_runtime_regressions.gd` 无命中；`git diff --check -- scripts/main.gd tests/p1_runtime_regressions.gd docs/design.md docs/module_workflow.md devlog/DEVLOG.md` 通过。
- [x] Godot `4.7.stable.official.5b4e0cb0f` 无扩展隔离工程完整运行 `res://tests/p1_runtime_regressions.tscn`，结果 `P1_RUNTIME_RESULT {"assertions":296,"failed":0,"failures":[]}`。
- [ ] 仍需用户可见窗口确认：在 Godot 中按 F5/F6 后应直接进入“开发测试模组/场景1”；右上应看到“模组”，点击后显示首页，再点“返回编辑器”回到原场景；顶栏在常用窗口宽度下不重叠。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 每轮 Godot 可见测试都先经过模组首页，操作繁琐。 | 已修复；可见编辑器运行自动进入固定开发测试模组 |
| 2026-07-18 | 进入编辑器后找不到模组首页。 | 已修复；固定入口为右上顶栏“模组”，首页可返回编辑器 |
| 2026-07-18 | 开发跳过可能污染正式 EXE 或无窗口回归。 | 已隔离；只在 `editor_runtime` 且非 `headless` 时触发 |

## 2026-07-18 Codex 停止运行报错与卡顿诊断

### 实测结论
- [x] 先清空 MCP 日志环与调试器错误：共清掉 500 条保留日志和 14 条调试器错误，证明用户看到的“大量错误”包含多轮运行累计的旧记录。
- [x] 清空后只运行一次主场景：`helper_live=true`、`current_run_errors=[]`；运行日志只有 Godot AI 助手注册信息和一条 `Embedded window can't be moved.` 提示，没有本轮脚本错误。
- [x] 本轮停止命令耗时约 104 ms；停止后第一次状态探查约 48 ms 即恢复 `readiness=ready`，随后 4 秒内持续可用，游戏日志和编辑器日志均未新增错误。本轮未复现“退出过程本身很慢”。
- [x] 运行时约 145 FPS、主循环约 1.82 ms；没有证据表明当前主场景负载导致停止卡顿。
- [x] 历史错误主要来自已删除的 `scripts/combat_line_probe.gd`、旧测试脚本、曾经未隔离的 `build/gdstyle_upgrade_20260718` 和 gdstyle 旧文件状态；其中多条与当前磁盘代码不符，属于缓存/调试器旧账，不能当成本轮关闭新报错。
- [x] `build/` 当前约 2.43 GB、1488 个文件；顶层没有 `.gdignore`。其中完整子工程会被 Godot 4.7 依据内含 `project.godot` 自动跳过，`gdstyle_upgrade_20260718` 现已有 `.gdignore`，但旧扫描错误仍留在保留日志中。该目录是后续工程卫生修复项，但本轮没有直接证明它造成 104 ms 停止耗时。

### 四层依据
- [x] 项目现状：`main.gd::_apply_window_state()` 在启动时无条件写入嵌入窗口的 `Window.position`，对应本轮唯一提示；`_notification()` 关闭时只保存一个很小的 `user://window.cfg`。本轮停止没有触发业务错误或重型清理日志。
- [x] Godot 源码：锁定 `4.7-stable` 提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`platform/windows/display_server_windows.cpp::window_set_position()` 在窗口被嵌入时只打印 `Embedded window can't be moved.` 并返回；`editor/file_system/editor_file_system.cpp::scan_changes()` 执行资源变化扫描，`_should_skip_directory()` 会跳过内含 `project.godot` 或 `.gdignore` 的目录。
- [x] 官方资料：离线 4.7 `gdd_0053_Project_organization.md` 明确说明在目录放空 `.gdignore` 可阻止 Godot 导入其内容并加快初次导入；`gdd_0202_Handling_quit_requests.md` 说明桌面窗口关闭通知及默认退出行为。
- [x] 英文社区：Godot 社区已有“删除脚本/插件后，停止运行时仍报 File not found（文件不存在）”的同类记录，常见来源是打开脚本、Autoload（自动加载）、全局脚本缓存或编辑器缓存残留；大型资源目录的社区性能讨论也确认 `EditorFileSystem`（编辑器文件系统）扫描会产生明显文件访问成本。现成方案以清理失效引用、隔离非工程目录和必要时重建 `.godot` 缓存为主，不需要新增插件。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 停止运行后调试器突然显示大量错误。 | 已定位：主要是跨多轮累计的历史/缓存错误；干净单轮为 0 条新错误。 |
| 2026-07-18 | `Embedded window can't be moved.` 看起来像退出错误。 | 已排除：这是项目启动时恢复窗口位置触发的普通提示，不是关闭失败。 |
| 2026-07-18 | 用户体感停止运行很卡。 | 本轮未复现；实测停止约 104 ms、编辑器约 48 ms 恢复。后续若复现需在同一轮立即抓时间点，不能再用累计日志反推。 |
| 2026-07-18 | `build/` 位于工程根目录且顶层无 `.gdignore`。 | 待单独修复；属于扫描噪声与未来卡顿风险，本轮诊断未改文件。 |

## 2026-07-18 Codex 停止运行噪声与扫描修复

### 已完成
- [x] 新增 `build/.gdignore`，让 Godot 4.7 在编辑器文件系统扫描阶段跳过约 2.43 GB 的构建产物、隔离测试工程、旧升级备份和源码卡目录；项目代码、场景和配置没有任何 `res://build` 运行依赖。
- [x] 修改 `main.gd::_apply_window_state()`：窗口大小仍在所有运行方式下恢复；窗口位置只在正式 EXE 恢复，`editor_runtime`（编辑器运行项目）不再向嵌入窗口写位置，因此不再输出 `Embedded window can't be moved.`。
- [x] 未删除 `.godot` 缓存、模组数据或场景数据；编辑器重连后日志自然从 0 开始，避免用破坏性缓存清理掩盖问题。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] `EditorFileSystem::_should_skip_directory()` 发现 `.gdignore` 后跳过目录 -> `build/.gdignore` -> 编辑器重启后就绪，编辑器日志 0 条，主场景启动无保留错误。
- [x] `DisplayServerWindows::window_set_position()` 对嵌入窗口打印提示并返回 -> `_apply_window_state()` 用 `OS.has_feature("editor_runtime")` 避免该无效调用 -> 干净主场景日志仅有 Godot AI 助手注册信息，窗口提示消失。
- [x] 正式 EXE 仍需恢复窗口位置 -> 非 `editor_runtime` 分支保留原 `x/y` 配置读取与 `Window.position` 写入 -> P1 无窗口隔离回归完整通过 `P1_RUNTIME_RESULT {"assertions":296,"failed":0,"failures":[]}`。

### 验证与边界
- [x] 主场景干净单轮：启动 `current_run_errors=[]`、`retained_errors=[]`；停止耗时约 79 ms，停止后 `readiness=ready`；游戏新增错误 0 条、编辑器新增错误 0 条。
- [x] 运行态保持约 145 FPS，主循环约 3.42 ms；本轮未复现关闭卡顿。
- [x] 静态检查：`git diff --check -- scripts/main.gd build/.gdignore` 通过，`scripts/main.gd` 未引入 `:=`。
- [x] 曾尝试在可见编辑器直接运行 P1 场景，但“开发测试模组直达”使无窗口前提失效并命中 `_missing` 测试夹具；已停止该无效运行，没有据此修改业务代码。随后改用仓库现成无扩展无窗口隔离工程，296/296 通过。
- [ ] 无窗口测试进程退出仍打印既有夹具清理提示：9 个 ObjectDB 对象、4 个资源仍占用；普通主场景真实停止没有这些提示，不属于本次用户可见关闭问题。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | `build/` 被主工程文件系统扫描。 | 已修复；顶层 `.gdignore` 统一隔离。 |
| 2026-07-18 | 嵌入运行每次输出窗口不能移动。 | 已修复；编辑器运行不再恢复位置，正式 EXE 行为保留。 |
| 2026-07-18 | 停止运行出现大量旧错误并卡顿。 | 干净重启与单轮验证通过；停止约 79 ms，停止后 0 条新错误。 |
## 2026-07-18 P2.6 破坏墙体后的 Token 通行闭环

### 现状与根因
- [x] 项目源码对照：`MovementService.rebuild()` 在进入运行态时重建移动导航；`_collect_runtime_geometry()` 同时为墙体生成参与导航烘焙的 `MovementObstacle` 和胶囊体通行检测使用的 `MovementBody`。P2.6 当前破坏流程只关闭 `CombatBody` 与 `LOSOccluder`，因此破坏后的墙仍残留导航网格缺口与移动物理阻挡两层旧状态。
- [x] 保存/读回对照：墙体破坏状态已经由 `wall_properties.wall_state` 保存和恢复；缺口在于移动服务重建时尚未按 `DESTROYED` 状态过滤墙体，不需要新增第二份“是否阻挡移动”保存字段。
- [x] 通行属性澄清：现有 `TraversalProperties.traversal_mode` 已提供 `BLOCKED` / `WALKABLE` 开关，墙体默认 `BLOCKED`，Token 与点光源默认 `WALKABLE`；此外 `_collect_runtime_geometry()` 明确整类跳过 `TOKEN` 与 `LIGHT`，所以点光源不会生成移动碰撞体或导航障碍。墙体破坏仍需在切换有效阻挡后触发重建，因为开关不会自动改写已经烘焙完成的导航网格。

### 四层调研与方案结论
- [x] 项目现状：复用现有 `scripts/movement_service.gd` 全量重建链和 `scripts/main.gd::_rebuild_movement_service()` 协调入口；破坏与修复成功后各触发一次重建，读档后的破坏墙由进入运行态时的既有重建自然处理。
- [x] Godot 源码：锁定 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。调用链为 `NavigationObstacle3D::navmesh_parse_source_geometry()` -> `NavMeshGenerator3D::generator_parse_source_geometry_data()` -> `NavMeshGenerator3D::bake_from_source_geometry_data()` -> `GodotNavigationServer3D::map_force_update()`；静态障碍只在解析/烘焙时改变导航网格，事后隐藏或禁用节点不会自动补回已经扣掉的可走区域。
- [x] 官方资料：Godot 4.7 导航文档与 `NavigationObstacle3D` 类文档确认，运行时静态拓扑变化需要重新解析/烘焙；场景树解析在主线程执行，异步烘焙也不能把解析阶段移出主线程。大型地图的局部更新方向是分块导航网格。
- [x] 英文社区/开源：Godot 导航维护者对同类问题的建议是静态拓扑变化后重烘焙；官方 `godot-demo-projects/3d/navigation_mesh_chunks` 展示可扩展的分块方案。动态避障不会修改寻路拓扑。未采用插件：现有 Godot 核心接口和项目重建链已覆盖需求，引入插件不会解决旧导航网格问题。
- [x] 最小方案：在 `_collect_runtime_geometry()` 中跳过 `wall_state == DESTROYED` 的墙，使其既不生成 `MovementObstacle`，也不生成 `MovementBody`；墙体破坏或修复成功后调用现有移动服务重建。默认 Token 尺寸立即重建，其他尺寸的缓存清空后按需重新生成。
- [x] 未采用方案：只关闭 `NavigationObstacle3D` 会留下已烘焙缺口；只移除 `MovementBody` 会留下寻路绕行；动态避障不能恢复可走拓扑；跨墙 `NavigationLink3D` 对任意墙宽、朝向和物理阻挡都较脆弱；分块重烘焙留作大地图性能优化。

### 验证与状态
- [x] 功能已实现：`scripts/movement_service.gd::_collect_runtime_geometry()` 跳过 `DESTROYED` 墙体；`scripts/main.gd::_on_runtime_wall_toggle_pressed()` 在破坏/修复成功后调用 `_rebuild_movement_service()`，失败时保留墙体状态并向 GM 显示“移动导航生成失败”。未新增保存字段。
- [x] Godot 源码行为 -> 本地实现 -> 验证：静态障碍在解析/烘焙阶段进入导航网格 -> 已破坏墙不进入源几何且状态切换后全量重建 -> P2.6 专项真实导航路线、胶囊体物理层和缓存 RID 断言通过。
- [x] P2.6 专项：`P2_6_WALL_RESULT {"assertions":61,"failed":0,"failures":[]}`。覆盖完整墙绕行、破坏后路线缩短并到达墙后、`MovementBody`/`MovementObstacle` 同时消失、修复恢复、活动预览清空、默认/大型 Token 体型缓存刷新，以及保存读回的破坏墙保持可通行。
- [x] 交叉回归：P2.5 `P2_5_LOS_RESULT {"assertions":52,"failed":0,"failures":[]}`；Godot 4.7 无扩展隔离工程 `P1_RUNTIME_RESULT {"assertions":296,"failed":0,"failures":[]}`。隔离回归退出仍有既有 9 个 ObjectDB 对象、4 个资源占用提示。
- [x] 主场景运行态探查：临时墙破坏后 `wall_state=DESTROYED`、移动服务实例已更换、该墙 `MovementBody=0`；修复后 `wall_state=INTACT`、服务再次更换、`MovementBody=1`。游戏日志无本轮错误；临时墙未保存并已删除。
- [x] 当前开发场景运行态计时：破坏后的同步全量重建约 `2022 ms`，修复约 `1813 ms`。功能正确但停顿明确可感知；分块导航或异步烘焙列为后续性能任务，不用动态避障替代拓扑更新。
- [ ] GM 可见窗口验证：让 Token 先绕完整墙移动，破坏墙后再次指定墙后目标，应直接穿过缺口；修复墙后同一路径应重新绕行，并确认约 1.8-2.0 秒同步重建停顿在真实带团场景是否可接受。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 破坏后的墙仍阻挡 Token 寻路与胶囊体通行检测。 | 已修复并完成自动/运行态验证；待 GM 可见窗口拖动体感确认。 |
| 2026-07-18 | 墙体破坏/修复触发同步全量导航重建，当前开发场景约停顿 1.8-2.0 秒。 | 已量化；不阻塞最小闭环，分块导航/异步烘焙作为后续性能任务。 |

## 2026-07-18 P2.6 编辑态破坏墙可视恢复

### 四层调研与源码对照
- [x] 项目现状：`WallStateController.sync_wall()` 原先无条件执行 `root.visible = wall_state != DESTROYED`；`main.gd::_on_mode_changed()` 已有 UI、相机、Gizmo、Token、拾取标记的独立模式应用步骤，却缺少墙体步骤，因此切回编辑态没有任何代码恢复模型。
- [x] Godot 源码：精确版本 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`scene/3d/node_3d.cpp` 的 `Node3D::set_visible()` 只修改 `data.visible` 并调用 `_propagate_visibility_changed()`；后者向可见子节点递归发送通知。`is_visible_in_tree()` 沿父 `Node3D` 链检查，不包含应用自定义编辑/运行模式。
- [x] 官方资料：Godot 4.7 `Node3D.visible` / `is_visible_in_tree()` 文档确认父节点隐藏会让整棵 3D 子树不可见；`visibility_changed` 只报告开关变化。编辑态展示必须由 Gvtt 自己协调。
- [x] 英文社区/开源：同类编辑视图讨论和开源实现采用模式边界集中重算可见表现，而不是修改持久业务状态。未引入插件；Gvtt 已有 `ModeGate` 和 `_apply_xxx_for_mode()` 结构，插件无法替代该本地状态边界。

### 实现与验证
- [x] `WallStateController.sync_wall(root, show_destroyed_visual=false)` 分离编辑视图与业务状态：编辑态可显示破坏墙，但 LOS、枪线和移动有效阻挡仍按 `wall_state` 计算。
- [x] `main.gd` 新增 `_apply_wall_state_for_mode()` 递归同步所有墙体；切编辑显示破坏墙，切运行重新按状态隐藏。编辑属性同步和读档迁移传入 `ModeGate.is_edit()`，避免模型显示后再次被藏。
- [x] 失败回归先证实问题：隔离主回归 `P1_RUNTIME_RESULT {"assertions":301,"failed":1}`，唯一失败为 `Destroyed wall visual did not return for edit-mode authoring`。
- [x] 修复后：隔离主回归 `302/302`、P2.6 专项 `64/64`、P2.5 LOS 专项 `52/52` 全通过。隔离主回归退出仍有既有 9 个 ObjectDB 对象、4 个资源占用提示。
- [x] 主场景运行态探查：临时墙破坏后运行态隐藏；切编辑态 `visible=true`、`wall_state=DESTROYED`、CombatBody 层为 0；再切运行态重新隐藏且 `MovementBody=0`。游戏日志无本轮错误，临时墙未保存并已删除。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-18 | 破坏墙切回编辑态后仍保持隐藏，GM 无法看见或编辑原墙。 | 已修复并完成自动/主场景运行态验证；待 GM 可见窗口确认。 |

## 2026-07-19 Codex P2 GM 可见窗口验收接受

### 已完成
- [x] GM（游戏主持人）已在对话中明确回复“我验收了”，确认本轮 Token（棋子）拖动不再误触 combat aim（战斗瞄准）线，并接受当前 P2（第二阶段）可见窗口状态。
- [x] 性能问题按本轮结论保留为已量化债务：历史破墙/修墙约 `2.02 s / 1.81 s`，本轮性能指标双窗口平均约 `89 FPS`（每秒帧数）；不作为阻塞 P3.0（第三阶段第 0 项）的当前失败项。

### 当前状态
- [x] P2（第二阶段）GM（游戏主持人）可见窗口验收闸门已有明确接受记录；后续可进入 P3.0（第三阶段第 0 项）应用框架收口。
- [ ] 性能专项仍应在后续独立批次处理，优先考虑分块导航/异步重建，不混入 P3.0（第三阶段第 0 项）。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | P2（第二阶段）GM（游戏主持人）可见窗口此前缺少明确接受记录。 | 已接受；P3.0（第三阶段第 0 项）前置闸门打开。 |

## 2026-07-19 Codex P2 Token（棋子）拖动/性能收口

### 已完成
- [x] 按用户可见验收反馈回修 P2（第二阶段）：Token（棋子）拖动时不应出现 combat aim（战斗瞄准）线；性能体感偏差先定性，不在本批大改。
- [x] 四层调研回执：项目现状确认 `scripts/main.gd::_input()` 在运行态 Token（棋子）拖动超过 6 像素后仍调用 `_select_entity()`，而 `_select_entity()` 与 `_on_selection_changed()` 会启动 `begin_combat_aim()`；Godot（引擎）4.7-stable 源码 `editor/scene/3d/node_3d_editor_plugin.cpp` 显示 3D 视口在鼠标移动超过 `8 * EDSCALE` 后清掉 `clicked` 并转入框选/变换，不再按普通点击选择；官方离线文档 `gdd_1421_ProjectSettings.md` 与 `gdd_0964_InputEventMouseMotion.md` 支持用拖动阈值区分点击和移动；英文社区方案同样采用“按下位置 + 距离阈值”区分 click（点击）和 drag（拖动），来源 `https://forum.godotengine.org/t/how-to-handle-clicking-click-dragging/100527`。
- [x] 源码行为 -> 本地实现 -> 验证映射：Godot（引擎）按下记候选、超阈值取消点击候选并进入拖动 -> 本项目新增 `_select_entity_for_runtime_token_drag()` 和 `_is_runtime_token_aim_suppressed()`，拖动触发的选中只刷新面板/Gizmo（变换手柄），不启动战斗瞄准 -> `P1_RUNTIME_RESULT {"assertions":305,"failed":0,"failures":[]}` 覆盖拖动状态成立且 `is_combat_aim_active()` 为 false。
- [x] 修改 `scripts/main.gd`：运行态 Token（棋子）拖动开始时走专用选中入口；拖动清理时同步清除本次瞄准抑制目标；普通短点击仍保留原有选中并进入战斗瞄准。
- [x] 修改 `tests/p1_runtime_regressions.gd`：在 Token（棋子）运行态移动用例中新增“超过 6 像素进入拖动后不得启动 combat aim（战斗瞄准）”回归断言。
- [x] 自动测试：P1（第一阶段）主回归通过 `P1_RUNTIME_RESULT {"assertions":305,"failed":0,"failures":[]}`；P2.4（第二阶段第 4 项）战斗遮挡通过 `P2_4_COMBAT_RESULT {"assertions":56,"failed":0,"failures":[]}`；P2.5（第二阶段第 5 项）LOS（视线遮挡）真实窗口通过 `P2_5_LOS_RESULT {"assertions":52,"failed":0,"failures":[]}`；P2.6（第二阶段第 6 项）墙体破坏通过 `P2_6_WALL_RESULT {"assertions":64,"failed":0,"failures":[]}`；P2（第二阶段）性能指标通过 `P2_ACCEPTANCE_METRICS {"assertions":17,"failed":0,...}`。
- [x] 已如实记录运行警告：P2（第二阶段）性能指标场景加载隔离测试模组时出现 3 次 `网行者test` 空模型缺少唯一同名 Token（棋子）素材警告；断言仍全过，判定为测试夹具/素材库隔离警告，不是本次拖动修复失败。
- [x] 静态检查：`rg -n ":=" scripts/main.gd tests/p1_runtime_regressions.gd` 无命中；`git diff --check -- scripts/main.gd tests/p1_runtime_regressions.gd` 通过。
- [x] 性能定性：本轮可见窗口性能复核双窗口 `Engine.get_frames_per_second()` 样本为 `25 / 99 / 143 FPS`，平均约 `89 FPS`；普通切场景可见耗时样本最高约 `1139.842 ms`。历史墙体破坏/修复导航同步重建约 `2.02 s / 1.81 s` 仍是已记录性能债务，不在 Token 拖动修复批次中重构。

### 当前状态
- [ ] 仍需 GM（游戏主持人）在 Godot（引擎）可见窗口手动确认：运行态拖动 Token（棋子）超过 6 像素时只显示移动路线，不出现瞄准线；短点击 Token（棋子）时仍按预期进入选择/战斗瞄准。
- [ ] 性能体感仍需 GM（游戏主持人）接受或明确列为阻塞；若 `1.8-2.0 s` 墙体破坏/修复等待已经影响带团，应另开性能批次做分块导航/异步重建，不塞进 P3.0（第三阶段第 0 项）应用框架收口。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | Token（棋子）拖动和点击判定重合，拖动也触发 combat aim（战斗瞄准）线。 | 已修复并通过 P1/P2（第一阶段/第二阶段）自动回归；待 GM（游戏主持人）可见窗口体感确认。 |
| 2026-07-19 | 性能体感偏差，历史破墙/修墙约 `2.02 s / 1.81 s`。 | 已复核并保留为性能债务；除非 GM（游戏主持人）判定阻塞，否则不挡本轮 Token（棋子）修复。 |

## 2026-07-19 Codex P3.0 应用框架收口与 Godot 原生崩溃修复

### 已完成
- [x] 前置闸门：`devlog/DEVLOG.md` 已有 GM（游戏主持人）明确“我验收了”的 P2（第二阶段）可见窗口接受记录，P3.0（第三阶段第 0 项）允许实施。
- [x] 以 `Main` 为组合根；业务自动加载仍只有 `ModeGate（模式闸门）`、`ModuleGate（模组闸门）`，没有新增万能事件总线或服务定位器。
- [x] 场景名和脏标记只由 `SceneSessionController（场景会话控制器）`持有；Main 的旧字段改为转发入口，不再保存第二份值。
- [x] 相机保存视角、实时轨道和地图状态只由 `CameraViewController（相机视图控制器）`持有；删除 Main 的十个同名转发字段，P1（第一阶段）增加源码防回退断言。
- [x] `SceneSessionController（场景会话控制器）`与 `PlacementController（放置控制器）`不再直接访问 `ModuleGate（模组闸门）`；Main 注入新增场景、保存场景、切换地点、读取清单和读取规则集标识的窄 `Callable（可调用对象）`。
- [x] 删除 `_switch_to_scene()` 提前返回后的不可达旧流程，以及无行为的 `_sync_scene_session_mirror()` 空入口。
- [x] 建立可测试的应用合同日志，覆盖启动、切模式、切场景、关模组和退出清理顺序；三批修改后均重跑 P1/P2（第一阶段/第二阶段）。
- [x] 更新 `docs/roadmap.md` 与 `docs/p3_application_boundary.md`：P3.0 四项完成，P3.1-P3.4 保持未开始。

### Godot 4.7 原生崩溃修复
- [x] 项目现状：`.godot/extension_list.cfg` 唯一登记 `addons/gdstyle/gdstyle.gdextension`；其 Windows（视窗系统）DLL（动态链接库）内嵌 `godot-rust 0.4.5 / API v4.5-stable`。`project.godot` 没有启用 gdstyle（GDScript 格式检查器）插件，但 Godot 仍会因 `.gdextension` 文件存在而让每个测试/应用进程加载该 DLL。
- [x] Godot 源码：精确标签 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`GDExtensionManager::load_extensions()` 读取扩展清单；`OS_Windows::open_dynamic_library()` 复制 `~` 临时 DLL 后调用 `LoadLibraryExW()`；`Main::cleanup()` 按 Editor→Scene→Servers（编辑器→场景→服务器）反向清理扩展。
- [x] 官方资料：离线 4.7 `gdd_0447_What_is_GDExtension.md`、`gdd_0448_The_.gdextension_file.md` 说明扩展登记与最低兼容版本；官方发布策略要求小版本尽量维持 GDExtension（二进制扩展接口）兼容，所以旧日志里的“4.5/4.7 必然不兼容”归因已纠正。
- [x] 英文社区/开源：`godot-rust` 兼容文档承诺 `API version <= runtime version（编译接口版本不高于运行版本）`原则上可运行，但承认 Rust（编程语言）可能遇到细微兼容问题；`gdstyle` 发布说明确认原生扩展缺失时可回退 CLI（命令行工具）。
- [x] 修复：保留 gdstyle 0.2.3 文件和本机 `C:\Users\Admin\.local\bin\gdstyle.exe`，把 `gdstyle.gdextension` 原样改名为 `gdstyle.gdextension.disabled`，并移除生成的旧扩展清单，阻止无关原生 DLL 注入所有 Gvtt 进程。
- [x] 修复验证：全新 Godot 4.7 无窗口“启动→扫描→退出”退出码 `0`，日志不再出现 `Initialize godot-rust`、`signal 11（内存访问崩溃）`或 GDScript（脚本语言）错误；随后 P1/P2 多进程连续退出均未复发应用程序错误。

### 源码行为 → 本地实现 → 验证
- [x] Godot 扩展清单启动加载 → 停用 `addons/gdstyle/gdstyle.gdextension` 扫描入口 → 干净启动退出码 `0`，无 Rust 初始化与崩溃。
- [x] Godot 自动加载先于主场景、节点子级先就绪 → Main 依次创建内容根、控制器、世界服务、UI（界面）、注入依赖、连接信号、应用模式 → P1 启动合同和 Main 可见运行探针通过。
- [x] Godot 节点反向退出 → Main 在退出前按指针、移动、战斗、投屏、窗口状态顺序清理 → P1 退出合同顺序通过。
- [x] Main 作为祖先注入、叶子不查全局 → 两个控制器只保存注入的 `Callable（可调用对象）` → P1 静态合同、`rg` 和隔离控制器测试通过。
- [x] 单一状态所有者 → 场景状态归场景会话控制器，相机状态归相机视图控制器 → P1 行为断言与源码防回退断言通过。

### 自动测试与可见窗口验证
- [x] 最终 P1：`P1_RUNTIME_RESULT {"assertions":320,"failed":0,"failures":[]}`。
- [x] 最终 P2.4：`P2_4_COMBAT_RESULT {"assertions":56,"failed":0,"failures":[]}`。
- [x] 最终 P2.5：Godot 编辑器可见窗口运行，`P2_5_LOS_RESULT {"assertions":52,"failed":0,"failures":[]}`。
- [x] 最终 P2.6：`P2_6_WALL_RESULT {"assertions":64,"failed":0,"failures":[]}`。
- [x] 最终可见性能基线：`P2_ACCEPTANCE_METRICS {"assertions":17,"failed":0}`；Windows（视窗系统）双窗口三轮均有真实绘制，场景可见切换约 `8.2-144.4 ms`。
- [x] Main 可见窗口：`helper_live=true（运行探针在线）`、启动零错误；运行态确认 Main 为组合根、场景/放置控制器已挂树、相机状态只在控制器、模式切换合同完整并恢复原模式；随后正常停止。
- [x] 静态检查：相关 GDScript（脚本）无 `:=`；两个叶子控制器无 `ModuleGate.`；`git diff --check` 通过；Godot 4.7 `find_symbols（解析符号）`成功解析五个相关脚本。

### 未完成与已知边界
- [ ] P1 测试进程退出仍报告 `9 ObjectDB instances（对象实例）`和 `4 resources（资源）`在使用的旧测试夹具警告；断言与退出码均通过，但后续应单独清理夹具生命周期。
- [ ] P2.5 无窗口入口会因窗口生命周期测试长时间不退出；已定点终止该测试进程，并以 Godot 编辑器可见窗口取得 `52/52`。该场景后续应增加明确超时或无窗口跳过合同。
- [ ] 当前用户 Godot 编辑器 PID 6408 在修复前已加载旧 gdstyle DLL；它本次最终关闭时仍可能再弹一次旧崩溃。下次启动开始不再加载该扩展，干净启动已验证。
- [ ] 性能专项仍保留：历史破墙/修墙导航同步重建约 `2.02 s / 1.81 s`；不属于 P3.0。
- [ ] 未实现 P3.1-P3.4；Main 仍约 4100 行、UI（界面）与装配仍有混合，按后续真实工作流分批迁移，不一次重写。
- [ ] `scripts/main.gd` 的 Git（版本管理）文件权限元数据仍显示 `100755 -> 100644`；Windows/Godot 运行不受影响，本机没有可用 `chmod（修改文件权限）`，且未为修元数据擅自改写暂存区。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | 多个 Godot 4.7 测试/应用进程频繁弹出内存不能 read（读取）的应用程序错误。 | 已定位并修复：停用未启用插件的 gdstyle 原生扩展扫描入口；干净启动和连续 P1/P2 进程未复发。当前已打开的旧编辑器可能在最后一次关闭时再弹一次。 |
| 2026-07-19 | 开发日志把崩溃简单归因于 `godot-rust API 4.5 / runtime 4.7` 不兼容。 | 已纠正：官方与 godot-rust 均承诺向后兼容；可实证原因是该具体第三方 DLL 在 Gvtt 多进程加载/清理链中反复崩溃和争用临时 DLL。 |
| 2026-07-19 | P3.0 场景/相机状态镜像、叶子直连全局、生命周期顺序不明确。 | 已收口并通过 P1/P2 与 Main 可见运行验证；P3.1-P3.4 未提前实现。 |

## 2026-07-19 Codex P3.1 模组清单、稳定标识与迁移

### 前置闸门与四层依据
- [x] 前置闸门通过：本日志已有 GM（游戏主持人）明确“我验收了”的 P2（第二阶段）记录，且 P3.0（第三阶段第 0 项）有实现、P1/P2 回归和可见窗口完成证据。
- [x] 项目现状：原 `ModuleGate（模组闸门）` 每次打开都扫描 `_canonical/*.scn` 并重建内存清单，`ModuleIo（模组读写层）` 只保留未接线的 Resource（资源）清单入口，因此重开后没有稳定 ID（标识）、结构版本、备份恢复或失败事务边界。
- [x] Godot 源码：锁定 `4.7-stable` 提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`；对照 `FileAccess（文件访问）`、`JSON（结构化文本）`、`Crypto（密码学随机）`、`DirAccess（目录访问）` 和 `PackedScene（打包场景）` 调用链，并记录 Windows `DirAccessWindows::rename()` 覆盖目标时存在短暂删除窗口，故只声明可恢复写入，不声明断电级原子性。
- [x] 官方资料：离线 4.7 `gdd_1240_Crypto.md`、`gdd_1241_DirAccess.md`、`gdd_1291_FileAccess.md`、`gdd_0972_JSON.md`、`gdd_1006_PackedScene.md` 支持随机字节、目录替换、整文件字节校验、JSON 解析和 `.scn PackedScene（打包场景）` 保存/实例化。
- [x] 英文社区/开源：SaveState Lite 1.2.0（MIT，Godot 4.3-4.6）可借鉴临时写、校验、备份和 schema（结构版本）思路，但其全局键值模型、版本范围和恢复合同与 Gvtt 冲突，因此未安装插件、未复制代码。

### 已实现
- [x] 新增强类型 `ExternalContentRef（外部内容引用）`，扩展 `ModuleManifest（模组清单）` 与 `LocationRef（地点引用）`；运行时 `available（可用状态）`和绝对场景路径不写入 JSON。
- [x] `ModuleIo` 实现 `Crypto.new().generate_random_bytes(16).hex_encode()`，稳定 ID 固定为 32 位小写十六进制；未使用 `ResourceUID（工程资源标识）`。
- [x] `manifest.json` 实现严格字段类型、格式、当前/未来版本、非法/重复 ID、起始地点、场景/外部内容来源和路径校验；绝对底本路径、反斜杠相对路径、`..`、目录逃逸和模组名 `.`/`..` 均拒绝。
- [x] 实现逐版本 `v0 -> v1` 迁移；旧 `canonical_path/start_location` 转为 `canonical_relpath/start_location_id`，迁移后安全写回；未来版本返回 `ERR_UNAVAILABLE（版本不可用）`且不改原文件。
- [x] 实现 `manifest.json.tmp -> 字节/JSON/领域校验 -> manifest.json.bak -> 正式提交`；提交失败时尝试从备份恢复，加载优先级覆盖正式、备份、仅临时首次创建和双损坏拒绝。
- [x] 旧 `user://modules/<name>/_canonical/*.scn` 首次迁移按文件名排序生成清单，原 `.scn` 文件不移动；第二次打开读取同一清单，不重新生成 ID。
- [x] `ModuleGate` 改为局部读取/恢复/迁移成功后一次性提交当前模组；新建地点先保存候选清单，失败不替换当前真值；新地点默认 `_canonical/<location_id>.scn`，场景本体仍走 `ModuleIo.save_scene_tree()`。
- [x] `Main（主应用壳）` 打开模组时显示普通打开、旧清单迁移、备份恢复和失败中文原因；没有实现 P3.2 带团会话、P3.3 播放器、联网、玩家端或规则系统。
- [x] 新增 `tests/p3_1_module_manifest_regressions.gd/.tscn` 失败优先回归：新建/重开、显示名重命名稳定 ID、旧目录迁移、schema（结构版本）逐版迁移、备份恢复、仅临时恢复、双损坏拒绝、未来版本拒绝、非法/重复 ID、绝对/相对/外部路径逃逸、缺失引用保留、打开/新建失败回滚。

### 源码行为 -> 本地实现 -> 验证
- [x] `Crypto.generate_random_bytes(16)` -> `ModuleIo.generate_stable_id()` -> 专项测试检查长度、字符范围、重开和重命名后 ID 不变。
- [x] `FileAccess/JSON/DirAccess` 写读与替换 -> `save_manifest_recoverable()/load_manifest_for_module()` -> 专项测试覆盖 tmp（临时）、bak（备份）、迁移、未来版本、双损坏和路径拒绝。
- [x] `PackedScene.pack()/ResourceSaver.save()/PackedScene.instantiate()` -> 原 `save_scene_tree()/load_scene_tree()` 保持 `.scn` -> P1 场景路径断言改为读取清单引用，不再把显示名当文件名。
- [x] 资源/引用缺失不等于清单损坏 -> `available=false` 且保留条目 -> 专项测试同时覆盖缺失 `.scn` 和缺失模组内图片引用。

### 自动测试与静态验证
- [x] Godot 4.7 `--headless --import --quit`（无窗口导入后退出）退出码 0，新增 `ModuleIo` 完成全局类注册；受限运行环境同时报告 AppData（应用数据）目录不可写和外部缓存 NUL（空字符）警告，项目脚本/场景/配置扫描未发现 NUL 字节。
- [x] 独立 `gdstyle CLI（代码风格命令行工具） check` 成功解析全部 P3.1 脚本，退出码 0；只有复杂校验函数长度/分支和长行告警，没有语法错误。
- [x] `rg` 确认相关 GDScript（脚本）无 `:=`、无漏类型、无 P3.2/P3.3/联网/玩家端越界关键词；`git diff --check` 通过；所有新增 Godot API（接口）签名已由 4.7 离线文档复核。
- [x] Windows 重启后单进程自动验证恢复：P3.1 首次运行暴露 Godot JSON（结构化文本）会把数值解析为浮点类型，严格 `int（整数）`校验错误拒绝自写清单；依据 4.7 `gdd_0972_JSON.md` 改为接受整数/浮点存储但要求有限、非负、无小数部分，随后 `P3_1_MODULE_MANIFEST_RESULT {"assertions":60,"failed":0,"failures":[]}`。
- [x] 重跑 P1/P2：`P1_RUNTIME_RESULT {"assertions":320,"failed":0}`、`P2_4_COMBAT_RESULT {"assertions":56,"failed":0}`、`P2_5_LOS_RESULT {"assertions":52,"failed":0}`、`P2_6_WALL_RESULT {"assertions":64,"failed":0}`、`P2_ACCEPTANCE_METRICS {"assertions":17,"failed":0}`；P2.5 和性能指标均使用真实 D3D12（Direct3D 12）可见窗口并自行关闭。
- [x] 重启后没有复发 `signal 11（原生内存崩溃）`或 Windows 应用程序错误；此前批量崩溃与修复前旧 Godot 进程/原生加载残留相关，停用 gdstyle 原生入口必须配合彻底退出旧进程才生效。
- [x] 启动时 NUL（空字符）警告已定位到 gdUnit4 第三方插件的旧格式配置测试夹具 `addons/gdUnit4/test/core/resources/GdUnitRunner_old_format.cfg` 及 `build` 历史副本；不是 Gvtt 脚本损坏，不修改插件测试数据。

### 可见窗口验证与未完成
- [x] 已彻底退出所有 Godot 进程并重启 Windows，清掉修复前已加载旧 gdstyle DLL（动态链接库）的 PID 6408 和残留原生加载状态。
- [x] 重启后 P3.1、P1、P2.4、P2.5、P2.6 和 P2 性能指标全部通过；`docs/roadmap.md` 的 P3.1 四项已打勾。
- [ ] GM 可见窗口：新建模组应自动进入“场景1”；关闭模组再打开，场景仍在；旧模组首次打开显示迁移提示且旧场景不丢；人工破坏正式清单但保留有效 `.bak` 后应显示“已从备份恢复并打开模组”。
- [ ] P3.2 最小带团会话、P3.3 外部内容播放/玩家输出和播放器均未开始。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | P3.0 日志把停用 gdstyle 原生入口后的一次干净导入和当时回归扩大为“命令行崩溃已彻底修复”。 | 结论已撤回并重开：停用入口是有效的局部修复，但今天 6 个命令行脚本仍在同一原生地址崩溃；需 Windows 重启后的单进程复测，不能归因于 P3.1 脚本。 |
| 2026-07-19 | 连续批量运行 6 个 Godot `--check-only` 导致 Windows 连续弹出 6 次应用程序错误。 | 已停止所有 Godot 命令行调用并清理无窗口残留；这是本轮验证操作失误，后续只允许重启后单进程试跑。 |
| 2026-07-19 | P3.1 功能代码和测试矩阵曾被原生崩溃阻断。 | Windows 重启后专项 60/60、P1/P2 全部通过，路线图 P3.1 已完成；只剩 GM 可见操作体感确认。 |

## 2026-07-19 Codex P3.1 模组入口层级复查

### 调研结论
- [x] 项目现状：`scripts/main.gd` 把 `ModuleHome（模组首页）`同时做成启动入口和编辑态顶栏“模组”按钮打开的覆盖层，`docs/module_workflow.md` 与 P1 回归又把该行为锁为合同；真正问题是启动阶段与模组内工作阶段混层，不只是按钮文案或位置。
- [x] Godot 4.7 源码：标签 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`ProjectManager::_open_selected_projects_check_recovery_mode()` 调 `_open_selected_projects()`，以 `--path/--editor` 创建编辑器实例并退出项目管理器；`EditorNode` 的 `PROJECT_QUIT_TO_PROJECT_MANAGER` 经保存确认后调 `_restart_editor(true)`，用 `--project-manager` 退出当前工作区并返回项目列表。
- [x] 官方资料：离线 `gdd_0057_Using_the_Project_Manager.md` 与 `gdd_0066_Command_line_tutorial.md` 把 Project Manager（项目管理器）和 Editor（编辑器）定义为两个入口状态，不把项目列表作为编辑工具栏常驻面板。
- [x] 英文社区/同类工具：Foundry VTT（虚拟桌面跑团工具）先在 Game Worlds（世界列表）选择并启动世界，进入后专注当前世界；切换使用 `Return to Setup（返回设置）`关闭当前世界，而非临时覆盖选择页后返回。无需插件。

### 待修正合同
- [ ] 正式程序与开发运行均应启动到模组选择页；新建/打开/导入成功后进入场景编辑。
- [ ] 编辑顶栏移除常驻“模组”按钮；当前模组名只作为不可点击状态展示。
- [ ] 如需切换模组，提供应用级“关闭当前模组/返回模组选择”，先保存并退出当前上下文，不保留“临时打开首页再返回编辑器”流程。
- [ ] 同步修正 `docs/module_workflow.md` 和 P1 回归：启动只见模组页、进入后无模组按钮、关闭模组后才返回选择页、保存失败不离开当前模组。
- [ ] 本轮只完成调研与逻辑确认，尚未修改功能代码；P3.2/P3.3 未提前开始。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | 模组选择器既是启动页，又通过编辑顶栏“模组”按钮成为模组内常驻工具。 | 已确认属于导航层级错误；正确结构为“启动选模组 -> 进入模组后专注场景 -> 显式关闭当前模组才返回选择页”，待单独修正代码、文档和测试。 |

## 2026-07-19 Codex P3.1 独立模组入口与窗口故障复查

### 四层调研与源码对照
- [x] 项目现状：入口层级初改只移除了编辑顶栏“模组”按钮，但 `ModuleHome（模组首页）`仍由 `main.gd::_build_ui()` 在完整 3D 编辑器上构建；启动日志证实首帧前会初始化投屏视图、Forward+（前向增强渲染）着色器和模型缓存，属于结构未真正分离。
- [x] Godot 4.7 源码：精确版本 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。导航依据延续 `ProjectManager::_open_selected_projects_check_recovery_mode()` -> `_open_selected_projects()` 与 `EditorNode::_restart_editor(true)` 的列表/工作区边界；资源链补查 `ResourceLoader::load_threaded_request()` -> `_load_start()` -> `WorkerThreadPool::add_native_task()` -> `_run_load_task()` -> `_load()` -> `ResourceCache（资源缓存）`，证明线程请求会立即消耗资源，不应在轻量入口首帧前发起。
- [x] 官方资料：离线 4.7 `gdd_0184_Background_loading.md`、`gdd_1476_ResourceLoader.md` 明确后台请求立即排队，`load_threaded_get()` 未完成时会阻塞；采用先显示入口、进入编辑器后再预热。
- [x] 英文社区/开源：Foundry VTT（虚拟桌面跑团工具）采用世界列表 -> 当前世界 -> 显式返回设置；Maaack's Scene Loader（Maaack 场景加载器，Godot 4.3+）采用先显示加载界面再发线程请求。未引入插件：Gvtt 不切换大型关卡，只需独立首页和现有场景切换接口。

### 已完成
- [x] 新增 `scenes/module_home.tscn` 与强类型 `scripts/module_home.gd`，项目 `run/main_scene` 改为独立模组首页；首页只负责列出、新建、导入、恢复和打开模组，成功后才切换到 `scenes/main.tscn`。
- [x] `scripts/main.gd` 删除全部 `ModuleHome` 遮罩、首页按钮、首页导入框和输入拦截；编辑器只保留不可点击的当前模组名与顶栏直接“关闭模组”命令。
- [x] 关闭当前模组继续执行保存前置：保存失败留在编辑器且不替换当前模组；关闭成功清理场景真值，真实应用延迟切回独立首页。P1/P2 测试直接嵌入编辑器时不会误切测试根场景。
- [x] 模型缓存新增 `_editor_resources_activated: bool` 门禁；启动/无模组时不发 `ResourceLoader` 线程请求，成功进入模组后一次性预热，关闭/重开不重复排队。
- [x] 失败测试优先：资源门禁首轮 `330` 条断言中新增 3 条正常失败；独立入口首轮 `333` 条断言中新增 3 条结构失败。实现后 P1 最终 `334/334`。
- [x] 更新 `docs/module_workflow.md`：明确独立首页场景、编辑器场景、关闭前保存和测试入口差异。

### 源码行为 -> 本地实现 -> 验证
- [x] Godot 项目列表与工作区分离 -> `module_home.tscn` 与 `main.tscn` 分离 -> P1 检查项目入口、场景文件存在、编辑器源码无 `ModuleHome`。
- [x] `load_threaded_request()` 立即排入工作线程 -> `_editor_resources_activated` 延迟预热 -> P1 检查启动队列为空、打开模组后激活。
- [x] `SceneTree.change_scene_to_file()` 切换当前场景 -> 首页成功打开模组后进入编辑器、编辑器关闭成功后返回首页 -> P1 检查编辑器内关闭/重开真值和生命周期顺序，保存失败合同沿用既有回归。

### 自动测试、可见验证与边界
- [x] 独立首页主入口运行检查：Godot 4.7 `--headless --quit-after 2 --path ...` 完整执行两帧并以退出码 `0` 结束，无 GDScript（脚本）错误；NUL（空字符）提示仍来自已记录的 gdUnit4 第三方旧格式夹具。
- [x] 最终自动测试：P1 `334/334`；P3.1 `60/60`；P2.4 `56/56`；P2.5 `52/52`；P2.6 `64/64`；P2 性能指标 `17/17`。P2.5 与性能指标均使用 Windows 显示驱动、RTX 4090、D3D12（Direct3D 12）。
- [x] 性能指标：双窗口平均约 `1012 FPS（每秒帧数）`，四次场景可见切换约 `11.730-178.417 ms`；本轮不改历史墙体导航重建债务。
- [x] 静态检查：新增 GDScript（脚本）变量均有显式类型，无 `:=`；编辑器内旧首页字段/函数无残留。
- [ ] 自动可见主程序验证受系统层阻塞：Gvtt 独立首页日志只加载 `module_home.tscn/module_home.gd`，没有 `main.gd`、模型缓存或脚本错误，但进程持续高 CPU（处理器）且 Windows 原生窗口枚举为 0。OpenGL 3 对照相同；不加载 Gvtt 的纯 Godot 4.7 项目管理器也没有窗口，因此不能归因于 P3.1、D3D12 或项目脚本。
- [ ] GM 仍需从资源管理器手动启动 Godot/Gvtt 做可见确认：应先看到“选择模组”；新建/打开后进入 3D 编辑器且无“模组”按钮；点击顶栏“关闭模组”应返回选择页。若再次弹 `0x...0058`，需保留崩溃模块/转储后另开 Godot 4.7 原生窗口故障任务。
- [ ] P3.2 最小带团会话、P3.3 外部内容播放/玩家输出、联网、玩家端、规则系统均未实现。
- [ ] P1 退出仍报告既有 `10 ObjectDB instances（对象实例）`和 `4 resources（资源）`占用；断言与退出码通过，后续单独清理测试夹具生命周期。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | 模组首页仍是完整 3D 编辑器上的遮罩，启动时提前加载编辑器资源。 | 已修复：项目入口与 3D 编辑器拆成两个场景，模型缓存延迟到进入模组后。 |
| 2026-07-19 | Codex 启动的 Godot 4.7 窗口版持续运行但无任何原生顶层窗口；此前用户见到 `0x...0058` 内存读取错误。 | 未解决，已证明纯 Godot 项目管理器也复现，排除 P3.1、Gvtt 主场景、D3D12 和素材缓存；无 Windows 事件或 WER（错误报告）转储，需独立系统层排障。 |

## 2026-07-19 Codex P3.1 关闭模组命令去除单项父级

### 调研、实现与验证
- [x] 项目现状：顶栏“文件”菜单只有“关闭当前模组”一个条目，没有其他同级命令或已排期扩展；两次点击没有提供分类价值。
- [x] Godot 4.7 源码：精确版本 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`editor/editor_node.cpp` 的项目菜单同时加入返回项目列表、重载、导出、退出等多项命令和快捷键；Gvtt 不具备该菜单成立所需的命令集合。
- [x] 官方与英文桌面规范：Godot `MenuButton（菜单按钮）`用于弹出 `PopupMenu（选项列表）`；普通 `Button（按钮）`直接触发动作。GNOME（桌面环境）建议菜单包含 3-12 项，Microsoft（微软）建议空间足够时直接呈现单个命令。
- [x] 失败测试优先：P1 `336` 条断言中新增 3 条失败，准确覆盖直接按钮缺失、旧“文件”父级残留和直接关闭函数缺失。
- [x] `scripts/main.gd` 删除菜单编号、`MenuButton`、`PopupMenu` 条目和分发函数；新增强类型 `_close_module_btn: Button`，文字“关闭模组”，`pressed（按下信号）`直接连接保存检查与关闭流程。
- [x] 保存失败仍保留当前模组；关闭成功仍清空模组真值并返回独立首页。最终 P1 `336/336`、P3.1 `60/60`，`git diff --check`另行通过。
- [x] 两套测试均已输出最终结果，但各留下一份无窗口、高 CPU（处理器）的 Godot 子进程；已按启动时刻和零窗口句柄确认并只结束 PID `20500/33352`，未关闭 `godot-ai` 辅助服务。该现象归入已记录的 Godot 4.7 原生窗口/进程故障，不归因于按钮逻辑。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | 唯一“关闭当前模组”命令被额外包在“文件”父级菜单下。 | 已修复：改为顶栏直接“关闭模组”按钮，减少一次无意义点击。 |

## 2026-07-19 Codex 文件菜单三命令设计待确认

### 调研结论
- [x] 项目现状：当前只有正在编辑的场景持有未保存状态；其他场景切换前已保存。`manifest.json` 在结构变化时自动安全写入，`manifest.json.bak` 只用于程序恢复，不是用户备份。
- [x] 本节旧 ZIP（压缩包）方案已被用户明确否决；后续以“增量恢复点”实现记录为准。

### 待确认边界
- [x] 用户已确认：备份不是打包模组，而是每次直接新增一个增量备份；“关闭模组”改为“选择模组”，退出程序使用窗口关闭按钮。
- [x] 旧待确认状态由下方实施记录取代。

## 2026-07-19 Codex P3.1 文件菜单与增量恢复点

### 四层调研与源码对照
- [x] 项目现状：当前场景是唯一未保存内存真值；`manifest.json.bak` 只是单层清单恢复文件，不能覆盖或冒充用户主动历史。顶栏直接“关闭模组”与用户最终三命令结构冲突。
- [x] Godot 4.7 源码：精确版本 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。对照 `PackedScene::pack -> SceneState::pack -> ResourceSaver::save`、`FileAccess::get_sha256`、`DirAccess::copy_absolute/rename_absolute`、`MenuButton::show_popup -> PopupMenu::activate_item -> id_pressed`、`SceneTree::change_scene_to_file -> ResourceLoader::load -> PackedScene::instantiate`。
- [x] 官方资料：离线 4.7 `gdd_1006_PackedScene.md`、`gdd_1477_ResourceSaver.md`、`gdd_1291_FileAccess.md`、`gdd_1241_DirAccess.md`、`gdd_1401_MenuButton.md`、`gdd_1431_PopupMenu.md`和`gdd_1469_SceneTree.md`确认场景保存、内容指纹、复制/提交、菜单与场景切换接口。
- [x] 英文社区/开源：BorgBackup 1.4.4 与 restic 0.19.1 都把每次备份呈现为完整快照，底层按内容去重。Gvtt 只复用“完整恢复点清单 + 内容指纹复用”，不引入其分块、压缩、加密、远端仓库或外部程序。

### 已实现
- [x] 失败测试先写入 P1/P3.1：锁定“文件 -> 保存模组/备份模组/选择模组”、恢复点递增、未变内容复用、单文件变化、自递归排除、逃逸拒绝和失败不替换当前模组真值。
- [x] 新增强类型 `ModuleBackupStore（模组备份存储）`：`_backups/objects/<sha256>`按整文件内容去重，`_backups/snapshots/<backup_id>.json`保存每次完整恢复点；备份 ID 复用 32 位小写十六进制稳定标识规则。
- [x] 内容对象执行复制到临时文件、SHA-256（内容指纹）复核、重命名提交；恢复点清单验证格式、结构版本、模组 ID、时间、相对路径、大小、哈希和对象存在性。拒绝绝对/`..`路径、目录逃逸、模组目录链接和内部目录链接。
- [x] `ModuleGate（模组闸门）`新增保存当前清单和备份当前模组入口；失败不替换当前模组真值。
- [x] `main.gd`顶栏改为三项“文件”菜单。“保存模组”保存当前 `.scn`再安全写清单；“备份模组”先保存再新增恢复点；“选择模组”替代关闭文案，脏场景保存失败时留在当前模组。
- [x] 更新 `docs/module_workflow.md`与`docs/p3_persistence_contract.md`，明确不是 ZIP、不是`manifest.json.bak`、不覆盖模组外素材，也不虚报 Windows 断电级原子性。

### 验证与未完成
- [x] `gdstyle CLI（GDScript 代码风格命令行检查器） check`成功解析 `module_backup_store.gd/module_gate.gd/main.gd`，退出码 0；新增代码无 `:=`，`git diff --check`通过。警告为既有大类/复杂度及新备份校验函数复杂度，没有语法错误。
- [x] 原项目入口失败证据：首次单进程 P3.1 测试在输出断言前，于 Godot 4.7 `main+0x3e096d3`发生 `signal 11（原生内存崩溃）`，与用户窗口错误地址 `...3396D4`对应同一偏移。该进程退出后无 Godot/WerFault 残留，不把原生崩溃当测试失败或通过。
- [x] 建立 `build/test_runs/p3_1_incremental_current` 无扩展隔离副本：383 个文件、约 3.46 MB，确认 0 个 `.gdextension`原生扩展清单和 0 个 DLL/so/dylib 原生库；Godot 4.7 `--editor --recovery-mode --import --quit`退出码 0并注册`ModuleBackupStore`。
- [x] 隔离单进程自动回归：P3.1 `P3_1_MODULE_MANIFEST_RESULT {"assertions":75,"failed":0}`；P1 `P1_RUNTIME_RESULT {"assertions":343,"failed":0}`；P2.4 `56/56`；P2.6 `64/64`。P1 退出仍报告既有 `9 ObjectDB instances（对象实例）`和`4 resources（资源）`占用。
- [ ] P2.5 本轮无窗口运行 40 秒没有输出断言，符合已记录的窗口生命周期挂起；已核对同一秒启动、无窗口的 PID `4776/20500`并只结束该进程对。本轮不冒充 `52/52`通过，保留此前可见窗口 `52/52`历史证据。
- [ ] P2 性能指标要求真实 Windows/D3D12（视窗与图形接口）绘制，本轮未重跑，保留此前`17/17`历史证据；没有用无窗口假帧率凑数。原项目命令行入口继续禁用。
- [x] GM（游戏主持人）可见窗口验收通过：用户完成检查后明确反馈“没什么问题了”，接受“文件”菜单三项、保存模组、增量备份模组和选择模组的当前行为。
- [ ] 当前只实现恢复点创建与完整性校验，用户可见的历史列表和一键还原尚未实现，不能宣称主动备份恢复闭环完成。P3.2 带团会话、P3.3 播放器、联网、玩家端和规则系统均未提前实现。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-19 | 旧记录把停用 `addons/gdstyle` 清单扩大为“Godot 命令行崩溃已修复”。 | 再次纠正：只完成局部绕开，原项目命令行仍会在同一原生偏移崩溃；今后只用无扩展隔离工程跑自动回归。 |
| 2026-07-19 | 本轮为取失败测试红灯，直接启动原项目 Godot 命令，导致用户再次看到“内存不能为 read”。 | 已停止并确认无残留 Godot/WerFault 进程；这是测试入口选择错误，不要求用户再次重启或手动修复。 |
| 2026-07-19 | `docs/roadmap.md` 的 P2 可见窗口复选框仍未勾，但日志已有 GM 明确“我验收了”记录。 | 文档状态矛盾已公开；本任务按明确人工接受记录通过前置门槛，路线图旧勾选待统一审计。 |
| 2026-07-19 | P3.1 文件菜单与增量恢复点等待可见窗口确认。 | 已验收：用户明确反馈“没什么问题了”；本轮功能范围完成。 |

## 2026-07-20 Godot 4.7-stable 原生内存读取崩溃根因与修复

### 四层调研回执
- [x] 项目现状：原项目没有 `.godot/extension_list.cfg`；唯一 gdstyle 原生描述文件已停用为 `addons/gdstyle/gdstyle.gdextension.disabled`；`build/.gdignore` 会隔离历史构建扩展；当前只启用 `godot_ai` 编辑器插件。无扩展隔离副本含 0 个 `.gdextension`、DLL/so/dylib，并已连续通过 P3.1、P1、P2.4、P2.6，排除 P3.1 GDScript（脚本）作为崩溃根因。
- [x] Godot 源码：锁定 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`；安装 EXE 内嵌提交一致，SHA-256 为 `B2CA888D5115A6CEDEE564764A2EE494A625F2EC2EDBABD010FE33C9A88A6BF8`。补齐读取 `modules/gltf/gltf_document.cpp`、`modules/gltf/gltf_state.cpp/.h` 和 `core/templates/cowdata.h`。
- [x] 官方资料：Godot 4.7 离线 `gdd_0187_Runtime_file_loading_and_saving.md` 示例保持 `gltf_scene_root_node` 存活，连续调用 `append_from_scene()` 与 `write_to_filesystem()`；`gdd_0929_GLTFDocument.md`、`gdd_0940_GLTFState.md`确认导出与场景节点映射接口。崩溃捕获采用 Microsoft ProcDump（进程转储工具）和 WinDbg（Windows 调试器）；应用级 WER LocalDumps（Windows 错误报告本地转储）因注册表写入被系统拒绝，没有留下半配置状态。
- [x] 英文社区/开源：godot-rust 兼容策略明确旧 API（应用程序接口）原则上可在较新运行时运行，因此继续撤回“API 4.5/runtime 4.7 必然不兼容”的旧结论；未找到能替代精确转储和源码生命周期核对的插件方案，也没有引入新的原生扩展。

### 完整转储与根因分级
- [x] 原项目 P1 在业务结果输出前稳定复现并取得完整转储：`build/crash_matrix/20260719_223947_original_direct/dumps/Godot_v4.7-stable_win64.exe_260719_224001.dmp`，大小 `1,028,677,366` 字节，SHA-256 为 `7F21401FFAD1ED6DE4C3F6B8A1393F3BBE687D17B3A872E1B79F359B4C6629F0`。
- [x] WinDbg 证据：异常为 `msvcrt!memcpy+0x113`，尝试向空目标写 44 字节；Godot 直接帧为 `NoHotPatch+0x3e819e3/+0x3e81ae5`。转储内 GDScript 回溯落在 `tests/p1_runtime_regressions.gd::_write_test_glb()` 的 `append_from_scene()` 后、`write_to_filesystem()` 前清理路径；栈中没有 gdstyle、NVIDIA 或 D3D12（Direct3D 12）直接故障帧。
- [x] 已确认根因：`GLTFState::append_gltf_node()` 把 `Node *` 原始指针保存到 `HashMap<GLTFNodeIndex, Node *> scene_nodes`；`GLTFDocument::write_to_filesystem()` 随后进入 `_serialize()`，第一步 `_convert_mesh_instances()` 再次取出并访问这些指针。测试在两步之间 `root.free()`，制造 use-after-free（释放后使用）和未定义行为。
- [x] 相关诱因：停用 gdstyle 原生扩展是正确的局部风险降低措施，但不是这份 P1 转储的直接根因；旧“已彻底修好全部原生崩溃”结论继续保持撤回。
- [x] 未证实假设：`CowData<char32_t>::ptrw()` 返回空目标后进入 `memcpy` 是最终落点，现有证据只支持它是悬空指针后的结果，不能另行宣称 Godot `CowData` 独立缺陷。显卡驱动、历史 `build` 扩展、普通内存耗尽也没有证据支持。

### 源码行为 -> 本地修复 -> 验证
- [x] Godot `append_from_scene()` 遍历节点并保留原始指针，`write_to_filesystem()` 完成再次访问和序列化，调用者只能在写盘返回后清理源树 -> `tests/p1_runtime_regressions.gd::_write_test_glb()` 改为先保存 `write_error`，再统一 `root.free()` -> 无扩展隔离 P1 `343/343`，原项目 P1 `343/343`，均退出码 0、0 份转储。
- [x] ProcDump 启动链需要稳定继承环境、准确记录退出和隔离用户目录 -> `tools/run_godot_crash_probe.ps1` 规范化当前探针进程中重复的 `PATH/Path`，在 `Get-Process` 无法给出退出码时回读 ProcDump UTF-16 日志，并新增 `-UseCleanUserData` 把自动测试 `user://` 重定向到本次 `build/crash_matrix` 结果目录 -> 避免沙箱 AppData 写入失败，结果文件准确记录退出码 0。
- [x] Windows 可见窗口 -> 原项目 `original_direct/window/none` 使用干净用户目录，观察窗口稳定 5 秒后发送正常关闭 -> `build/crash_matrix/20260720_154618_original_direct/result.json` 记录 `window_observed=true`、`graceful_close_succeeded=true`、退出码 0、无超时、无强制清理、无残留。

### 最小对照矩阵与交付边界
- [x] 纯 Godot 4.7 最小项目窗口可见；普通导入退出码 0。原项目恢复模式导入与无扩展隔离恢复模式导入均退出码 0；这些结果继续排除启动扫描和 `build/.gdignore` 为本次 P1 崩溃根因。
- [x] 修复后无扩展隔离 P1：`P1_RUNTIME_RESULT {"assertions":343,"failed":0,"failures":[]}`；原项目干净用户目录 P1 同为 `343/343`；原项目 P2.4 为 `56/56`；P2.6 为 `64/64`。四个进程均由 ProcDump 单进程监控，0 份新转储、无超时、无强制清理、无残留。
- [x] 本次首次原项目 P1 验证未重定向 `user://`，受沙箱阻止写 AppData 而退出码 1、`214` 项中失败 `25` 项；这是诊断环境失败，不是产品回归。增加显式干净用户目录后同一原项目通过 `343/343`，没有用失败结果冒充通过。
- [x] 本轮没有实现 P3.2 或其他产品功能，没有恢复 gdstyle 原生入口，没有修改注册表、系统目录或默认调试器。WinDbg 仅按当前用户安装；需要撤销时可执行 `Remove-AppxPackage Microsoft.WinDbg`。
- [ ] 本次已根治完整转储证明的 P1 GLTF 测试夹具释放后使用路径，但不能据此保证未来所有不同调用栈的“内存不能为 read”都已消失；若再次出现，必须保留新转储并按新栈重新分类，不能自动归因于 gdstyle 或本次 GLTF 路径。
- [ ] 可见窗口日志仍有一条独立非崩溃错误：`godot_ai` 端口探测尝试调用系统中不存在的 `pwsh.exe`（PowerShell 7）失败；窗口和正常退出不受影响，且它不在崩溃栈中。本轮不扩大范围修改第三方插件。
- [ ] P1 退出仍可见既有 NUL（空字符）解析提示；本轮通过日志、退出码和转储三重证据判断原生修复，不把“没有红字”作为完成标准。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-20 | P1 GLTF 测试夹具在写盘前释放源节点树，触发 Godot 原生释放后使用并最终写入空地址。 | 已修复并完成隔离/原项目 P1、P2.4、P2.6、可见窗口和退出清理验证；本次确定调用栈已根治。 |
| 2026-07-20 | 应用级 WER LocalDumps 注册表配置被系统拒绝访问。 | 未改系统配置；已改用官方 ProcDump 单进程完整转储方案并取得可分析证据。 |
| 2026-07-20 | Codex 环境同时继承 `PATH` 与 `Path`，PowerShell `Start-Process` 拒绝启动探针。 | 已在探针子进程内无损规范化为单一 `Path`；不修改用户或系统环境变量。 |
| 2026-07-20 | 正常窗口中 `godot_ai` 无法启动不存在的 `pwsh.exe` 做端口探测。 | 独立未解决、非本次原生崩溃；窗口显示和退出码 0 已验证，后续按插件依赖单独处理。 |

## 2026-07-20 Codex P3.2 最小带团会话

### 前置与四层调研
- [x] 前置证据：P2 有 GM 可见验收记录；P3.0 有应用边界、生命周期回归和可见窗口证据；P3.1 有 `75/75`、P1 `343/343`、P2.4 `56/56`、P2.6 `64/64`及用户确认。P1 GLTF（场景交换格式）夹具释放后使用导致的“内存不能为 read”已在独立记录修复，P3.1 基线复跑 `75/75`且无新转储。
- [x] 项目现状：`Playthrough/ModuleIo/ModuleGate`只有未接线骨架；`SceneSessionController（场景会话控制器）`只会加载底本；`main.gd`在切换前会先释放移动服务、恢复 Token（标记）编辑位置。真正缺口是版本化会话索引、每地点快照、运行态保存路由和“保存先于清理”的统一编排。
- [x] Godot 4.7 源码：精确标签 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。对照 `scene/resources/packed_scene.cpp` 的 `PackedScene::pack -> SceneState::pack -> _parse_node`、`SceneState::instantiate`，`scene/main/node.cpp` 的 `Node::set_owner`，以及 `core/io/resource_loader.cpp` 的加载与忽略缓存链；保存只包含 owned（有归属）子树，加载后实例化，覆盖文件后必须忽略旧缓存重读。
- [x] 官方资料：离线 Godot 4.7 `PackedScene`、`ResourceSaver`、`ResourceLoader`、`FileAccess`、`DirAccess`、`JSON`、`SceneTree`和 Saving games（保存游戏）文档。官方对象字段方案要求每类对象自己定义稳定身份与字段；当前 Token、墙、光源没有统一对象协议，因此 P3.2 采用每地点完整 `.scn` 快照。
- [x] 英文社区/开源：Tabletop Club（开源桌面跑团工具）的素材/预制与可恢复桌面状态分离可作架构旁证；SaveState Lite（保存状态插件）只借鉴版本、临时文件和备份思路。两者均不直接复用：前者未取得可核实的同版本内部调用链，后者与现有 `ModuleIo/ModuleGate` 边界冲突；未安装插件。

### 已实现
- [x] `Playthrough（带团记录）`升级为 `gvtt_playthrough`、结构版本 1 的强类型数据；`session.json`保存会话 ID、模组 ID、当前地点、地点快照相对路径和备注。未来版本、会话目录 ID 与内部 ID 不符、模组 ID 不匹配均明确拒绝，身份/未来版本错误不得被旧备份掩盖。
- [x] `ModuleIo（模组输入输出）`新增会话 JSON 与 `states/<location_id>.scn`的 `.tmp/.bak`写入、读回实例化校验、提交、恢复和逐版本迁移。固定顺序为“快照成功 -> 会话索引成功 -> 提交内存真值”；不宣称跨文件断电级事务。
- [x] `ModuleGate（模组闸门）`拥有当前会话引用和开始/继续/列出入口。新会话固定从 `start_location_id`起始地点开始；控制器可要求“先落盘但暂不提交”，底本加载成功后才提交会话。
- [x] 新增强类型普通节点 `PlaythroughController（带团会话控制器）`，负责开始、继续、保存、切地点和回编辑态；不做 Autoload（全局自动加载），不拥有场景树。目标地点有快照读快照，无快照读底本；损坏/缺失快照不静默回退底本。
- [x] `SceneSessionController`新增严格接收“已加载并验证场景”的替换入口；失败不清当前内容、不套默认场景。切地点索引写入失败时尝试从刚保存的旧地点快照回滚画面。
- [x] 三层真值已分离：编辑态保存只走 `_canonical`；运行态左栏保存按钮与“文件 -> 保存带团”只写 `sessions/<session_id>`；`gvtt_runtime_only`临时演出/服务节点在打包前摘除，不进入快照。
- [x] `main.gd`文件菜单新增“从底本开始带团 / 继续带团 / 保存带团”；损坏会话在继续列表中禁用并显示错误提示。运行态地点按钮走会话切换，模式按钮回编辑态前先保存并重载底本。
- [x] 每次会话保存前取消未完成手势、清除未提交预览并停止 Token 在当前已到达位置；不恢复编辑位置、不清内容、不释放服务。切地点、回编辑态、选择模组和窗口退出均在快照/索引成功后才允许恢复 Token、清树或释放运行服务；`SceneTree.auto_accept_quit=false`，保存失败时不关闭窗口。
- [x] Token 移动提交、运行态破墙/修墙和开关光源都标记会话变化；切地点后重建墙体显示、Token 编辑快照和移动服务。
- [x] `tools/run_godot_crash_probe.ps1`新增 `runtime_window（运行态可见窗口）`探针模式；真实运行测试等待场景自行退出，继续保留干净 `user://`、ProcDump（崩溃转储监控）、超时和单进程保护。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] `PackedScene::pack -> SceneState::_parse_node`只收 owned（有归属）节点 -> `ModuleIo.save_session_snapshot_recoverable()`复用 owner（归属）补全并摘除 `gvtt_runtime_only` -> P3.2 数据/控制器测试检查 Token、墙、光恢复且临时节点不入快照。
- [x] `ResourceLoader`忽略缓存加载 -> `ModuleIo.load_scene_tree()`以 `CACHE_MODE_IGNORE（忽略缓存模式）`验证临时、正式和备份场景 -> 缺失、正式损坏、正式与备份双损坏均有专项失败断言。
- [x] `SceneState::instantiate`重建场景树 -> `SceneSessionController.replace_with_loaded_scene()`搬入已验证内容 -> 两地点首次读底本、再次读会话快照、回编辑态重读底本均由自动与可见测试覆盖。
- [x] `FileAccess/JSON/DirAccess`读写、解析和替换 -> `session.json.tmp/.bak`与逐版本校验 -> 专项覆盖损坏恢复、未来版本、模组 ID 不匹配、路径越界和新会话不改旧会话。
- [x] `SceneTree`关闭通知可由应用拦截 -> `auto_accept_quit=false`与 `_prepare_application_exit()`显式保存后退出 -> P1 生命周期日志和 P3.2 可见测试证明 `session_save:snapshot`早于移动服务释放。

### 自动测试与可见窗口
- [x] P3.2 数据层：`P3_2_PLAYTHROUGH_RESULT {"assertions":39,"failed":0}`，日志 `build/crash_matrix/20260720_162814_original_direct/godot.log`。
- [x] P3.2 控制器与整树重建：`P3_2_CONTROLLER_RESULT {"assertions":39,"failed":0}`；第一棵测试应用树完整释放后创建第二棵，继续同一会话恢复当前地点、Token、墙和光，日志 `build/crash_matrix/20260720_162657_original_direct/godot.log`。
- [x] P3.2 真实主界面可见窗口：`window_observed=true`、`P3_2_VISIBLE_RESULT {"assertions":33,"failed":0}`，覆盖菜单、开始、保存、两地点切回、编辑态底本、继续会话和退出顺序；退出码 0、0 转储、无残留，日志 `build/crash_matrix/20260720_205230_original_direct/godot.log`。
- [x] 前置回归：P1 `354/354`、P3.1 `75/75`、P2.4 `56/56`、P2.6 `64/64`；全部由原项目、干净用户目录、ProcDump 单进程运行，退出码 0、0 转储、无残留。
- [x] P2.5 必须等待真实 `frame_post_draw（帧绘制完成）`，无窗口探针两次超时后没有冒充通过；改用真实 Windows 可见窗口后 `52/52`，日志 `build/crash_matrix/20260720_204734_original_direct/godot.log`。
- [x] P2 验收指标无窗口首次如实失败 3 条“真实绘制帧大于零”；真实 Windows 可见窗口复跑 `17/17`，实际绘制平均约 `443.8 FPS（每秒帧数）`、双窗口平均约 `391.7 FPS`，日志 `build/crash_matrix/20260720_204814_original_direct/godot.log`。
- [x] 静态检查：新增 GDScript 变量均有显式类型，无 `:=`；相关已跟踪文件 `git diff --check`通过。P3.2 四项已在 `docs/roadmap.md`勾选。

### 未完成与问题状态
- [ ] GM 人工手感确认：自动可见窗口已证明真实界面和流程运行，但当前工具没有 Godot 窗口点击通道，仍需 GM 亲手拖 Token、点破墙/光源和菜单，确认交互手感与文案。
- [ ] P3.3 图片/视频输出、P3.4 统一内容生命周期、联网、玩家端和规则系统均未实现；本轮没有越界加入。
- [ ] P1 整套测试在真实窗口模式下有 5 条既有素材鼠标手势模拟失败；同一代码无窗口 P1 `354/354`，P3.2 聚焦可见测试 `33/33`，失败与会话菜单/持久化无关。后续若要求 P1 全套可见模式也通过，应单独修测试输入注入，不混入 P3.2。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-20 | 正式 `session.json`模组 ID 不匹配时，载入器曾把它当普通损坏并从旧备份恢复，掩盖身份错误。 | 已修复：解析结果显式禁止身份/未来版本走备份；P3.2 数据层 `39/39`。 |
| 2026-07-20 | 新会话最初沿用当前编辑地点并在底本加载前提交当前会话，不符合 `start_location_id`和延迟提交合同。 | 已修复：固定起始地点；控制器先落盘、加载/替换成功后再提交；控制器与可见测试通过。 |
| 2026-07-20 | P2.5 和 P2 验收指标误用无窗口探针，分别超时和得到 0 绘制帧。 | 已纠正测试模式：新增运行态可见窗口探针，P2.5 `52/52`、指标 `17/17`，均 0 转储。 |

## 2026-07-20 Codex P3.2 带团入口与自动保存简化

### 调研回执与结论
- [x] 项目现状：文件菜单同时暴露“从底本开始带团 / 继续带团 / 保存带团”，模式按钮又提供运行入口；底层会话隔离有必要，但界面把底本、会话和恢复等内部数据概念变成 GM 必须理解的重复动作。
- [x] Godot 4.7 源码：继续沿用 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88` 的 `Timer（定时器）`节点生命周期、`PackedScene::pack`、`SceneState::instantiate`与忽略缓存加载链；引擎提供持久化原语，不要求用户手动触发每次保存。
- [x] 官方资料：离线 `Timer`、`PackedScene`、`ResourceSaver`、`ResourceLoader`和运行时文件保存资料支持应用在自己的安全时机延迟保存；保持已有 tmp（临时）/bak（备份）验证链，不改会话格式。
- [x] 英文社区/开源：此前 Tabletop Club 0.1.4 与 SaveState Lite 1.2.0 调研只支持“原始内容与运行状态分离”和可恢复写入，不支持把内部存档术语强加给 GM；本轮联网补查被访问策略拒绝，未伪造新网页证据。
- [x] 结论：保留会话底层，隐藏普通路径中的存档管理。正常工作流收敛为“制作场景 -> 开始带团；下次打开 -> 继续带团”；只有多份记录时才选择，低频新建放入文件菜单。

### 已修改
- [x] 文件菜单删除“从底本开始带团 / 继续带团 / 保存带团”，只保留低频“新开一场带团”；原有“保存模组 / 备份模组 / 选择模组”不变。
- [x] 编辑态模式按钮按有效会话数量动态显示：0 份“开始带团”、1 份“继续带团”、多份“选择带团”。唯一记录直接继续，多份记录才弹现有选择列表；不猜随机会话 ID 的先后。
- [x] 运行态隐藏场景保存按钮。Token、墙和光源变化标记会话后启动 1 秒一次性自动保存；多次变化重置等待时间，合并为一次快照。
- [x] `MovementService（移动服务）`新增只读 `is_movement_active()`；自动保存遇到 Token 仍在沿路径移动时每 0.25 秒重试，移动完成后保存，不为自动保存截停 Token。
- [x] 切地点、回编辑态、选择模组和退出程序的强制保存顺序保持不变；自动保存失败仍显示明确错误，底层 `session.json/.scn`、tmp/bak 和回滚协议未修改。

### 验证与未完成
- [x] P3.2 聚焦主界面无窗口回归 `32/32`，证明不点保存也落盘、唯一记录按钮显示“继续带团”并直接恢复；日志 `build/crash_matrix/20260720_212312_original_direct/godot.log`。
- [x] P1 主界面回归 `352/352`，新增多记录“选择带团”断言；日志 `build/crash_matrix/20260720_212556_original_direct/godot.log`。
- [x] P3.2 控制器 `39/39`、数据层 `39/39`；日志分别为 `build/crash_matrix/20260720_212430_original_direct/godot.log`、`build/crash_matrix/20260720_212458_original_direct/godot.log`。
- [x] P3.2 真实可见窗口 `32/32`，`window_observed=true`、退出码 0、0 转储、无残留；日志 `build/crash_matrix/20260720_212641_original_direct/godot.log`。
- [ ] GM 仍需亲手确认新按钮文案和 1 秒自动保存提示是否自然；本轮工具只能自动驱动真实可见窗口，不能代替鼠标手感评价。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-20 | 内部“模组原始场景/带团会话”分层被直接暴露成三个文件菜单动作，正常带团路径重复。 | 已简化：模式按钮承担开始/继续/选择，运行变化自动保存，文件菜单只保留低频新开记录。 |
| 2026-07-20 | 自动测试开始前发现 PID `52896` 为无窗口 Gvtt Godot 编辑器并持续占用 CPU。 | 未擅自结束；用户在任务管理器结束后继续。后续全部测试单进程完成且无残留。 |

## 2026-07-20 Codex P3.3 外部内容与玩家输出底座

### 前置与四层调研
- [x] 前置证据：P2 有 GM 可见窗口验收记录；P3.0 应用边界完成；P3.1 `75/75`；P3.2 数据 `39/39`、控制器 `39/39`、可见工作流 `32/32`。`docs/roadmap.md` 早期 P2 未勾项与后续验收记录矛盾已公开，本任务按后续明确验收通过前置门槛。
- [x] 项目现状：`ExternalContentRef（外部内容引用）`只有字符串骨架；`ModuleIo（模组输入输出）`已有限制 `..` 的模组相对路径校验；`CastView（投屏视图）`同时拥有原生窗口、地图相机、迷雾和逐帧同步；`main.gd`直接开关窗口。真正缺口是强类型引用、独立解析器、唯一输出状态所有者、三种呈现器、可替换视频后端和统一释放顺序。
- [x] Godot 4.7 源码：锁定 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。对照 `Image::load_from_file -> ImageLoader::load_image -> TextureRect::set_texture`；`VideoStreamPlayer::set_stream -> VideoStreamTheora::instantiate_playback -> VideoStreamPlaybackTheora::set_file -> play/update -> finished -> stop/clear`；`Window::_event_callback -> close_requested`与`Window::_clear_window -> delete_sub_window`。
- [x] 官方离线资料：`gdd_0187_Runtime_file_loading_and_saving.md`、`gdd_0144_Playing_videos.md`、`gdd_0773_VideoStreamPlayer.md`、`gdd_0525_AspectRatioContainer.md`、`gdd_0762_TextureRect.md`、`gdd_0786_Window.md`确认外部图片、原生 OGV（Ogg Theora 视频）、保持比例、视频纹理、音频总线和原生子窗口接口。
- [x] 英文社区/开源：Godot VLC 1.2.0（VLC 媒体播放扩展，2026-05、Godot 4.3+、Windows/Linux、LGPLv2.1）可作为未来常见格式适配候选，但尚未验证 Godot 4.7、双窗口、导出和清理；P3.3 不安装它。采用“项目自有后端接口 + 原生 OGV 适配器”，未采用插件专有类、MP4 承诺或自写解码器。

### 已实现
- [x] `ExternalContentRef`改为强类型 `ContentType/SourceKind（内容类型/来源类型）`，增加只在运行时存在的`resolved_path/available（解析路径/可用状态）`；`manifest.json`仍读写`image/video`和`external_file/module_relative`字符串，不升级结构版本、不写入运行时字段。
- [x] 新增`ExternalContentResolver（外部内容解析器）`：支持本机绝对路径与模组内相对路径，拒绝虚拟资源路径、绝对化相对来源、反斜杠、冒号、NUL（空字符）、`..`和目录逃逸；文件缺失保留引用、返回`ERR_FILE_NOT_FOUND`并标记不可用。
- [x] `CastView`收窄为原生`Window（窗口）`壳、黑色媒体承载面和关闭请求转发；不再保存相机、迷雾、播放状态或失败回退。`MapOutputPresenter（地图输出呈现器）`接管共享`World3D（三维世界）`、玩家相机同步、玩家可见层和迷雾。
- [x] 新增`PlayerOutputController（玩家输出控制器）`作为`NONE/MAP/IMAGE/VIDEO（无/地图/图片/视频）`、生命周期阶段、内容 ID、严格递增请求 ID 和活动呈现器的唯一所有者；这些值没有在`Main（主界面）`或`CastView`中镜像。三种输出与`ModeGate（模式闸门）`正交，不是新`AppMode（应用模式）`。
- [x] `ImageOutputPresenter（图片输出呈现器）`使用`Image.load_from_file()`与`ImageTexture（图片纹理）`，`TextureRect（纹理矩形）`保持比例居中；`VideoOutputPresenter（视频输出呈现器）`使用`AspectRatioContainer（宽高比容器）`和外层黑底，只有取得大于零的真实视频尺寸才就绪。
- [x] 新增项目自有`VideoPlaybackBackend（视频播放后端）`接口、`NativeOgvPlaybackBackend（原生 OGV 播放后端）`和可注入假后端。上层不导入、判断或调用 VLC/原生解码专有类；原生适配器只接受测试`.ogv`，显式播放并使用`Master（主音频）`总线。
- [x] 快速替换先递增请求 ID，旧回调只能释放自己；失败、取消、首帧前结束和自然结束统一回地图。切场景保持投屏窗口但先释放媒体回地图；关投屏和退出固定为“停声/清流/断业务信号/释放媒体 -> 释放地图 -> 最后释放原生窗口”。
- [x] `main.gd`只创建并注入窗口壳与控制器；投屏按钮、玩家窗口关闭、切场景和退出都走控制器命令。P3.3 未新增正式媒体库或 GM 播放控件。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] 图片加载后由纹理控件持有 -> `ImageOutputPresenter.prepare()/release()`加载并在释放前清空`texture` -> P3.3 测试检查`64 x 32`自然尺寸、比例模式和运行时字段不写清单。
- [x] `VideoStreamPlayer::set_stream()`替换旧流前停止，Theora 后端清文件/解码器/音频缓冲 -> `NativeOgvPlaybackBackend.release()`执行`stop -> stream=null -> disconnect -> queue_free`，`VideoOutputPresenter`再断开后端业务信号 -> 假后端逐项记录并断言释放顺序。
- [x] 引擎`finished（自然结束信号）`没有请求 ID，也不负责回地图 -> 呈现器绑定请求 ID，控制器拒绝过期回调并在有效自然结束后分配新地图请求 -> 延迟成功、快速替换、首帧前结束和正常结束专项测试通过。
- [x] OS（操作系统）关闭只发`Window.close_requested（窗口关闭请求）`，原生窗口最终在清理阶段删除 -> `CastView`只转发，控制器先释放媒体/地图再`release_window()` -> 可见测试检查轨迹`release_media -> release_map -> release_window`、旧窗口引用失效和无残留 Godot 进程。

### 自动测试与可见窗口
- [x] P3.3 最终无窗口合同：`P3_3_PLAYER_OUTPUT_RESULT {"assertions":47,"failed":0}`，日志`build/crash_matrix/20260720_221200_original_direct/godot.log`。
- [x] P3.3 最终 Windows 可见窗口：`window_observed=true`、`47/47`、退出码 0、无超时、无强制清理、无残留，日志`build/crash_matrix/20260720_221237_original_direct/godot.log`。
- [x] P3.1 清单兼容`75/75`；P3.2 数据`39/39`、控制器`39/39`、Windows 可见工作流`32/32`；P1 稳定无窗口`352/352`。
- [x] P2.4`56/56`、P2.5 Windows 可见`54/54`、P2.6`64/64`。P2 验收指标首次发现旧`CastView.close()`造成静默中断，修正为控制器命令后 Windows 可见`20/20`，双窗口可见且实际绘制平均约`712.5 FPS（每秒帧数）`。
- [x] 静态检查：导入编译错误 0；本轮 GDScript 变量均有显式类型，无`:=`；最终可见测试均正常退出。

### 未完成与问题状态
- [ ] 仓库没有固定 OGV 测试视频；本轮只以假后端证明状态、失败、并发和清理，并把原生 OGV 适配器接入默认工厂。真实首帧、连续帧变化、音频峰值、自然播完和两种窗口比例的像素证明属于 P3.4，不能宣称已验证。
- [ ] 正式文件选择、登记/删除、缩略图、搜索排序、媒体库、GM 暂停/进度/音量、字幕、播放列表、VLC 和 MP4 均未实现；这符合 P3.3 范围。
- [ ] GM 人工确认仍需在后续有测试媒体入口时完成。目前可见自动测试已证明真实原生窗口创建、图片/假视频承载、切换和最终释放，但没有正式界面可供 GM 选择媒体。
- [ ] 最终测试日志仍有项目既有 NUL（空字符）扫描提示；逐字节扫描确认本轮`scripts/`和`tests/`的`.gd`文件没有零字节，本任务未扩大范围清理其他文件。
- [ ] P1 整套在真实窗口模式仍有 5 条既有合成鼠标素材手势失败，同一最终代码无窗口`352/352`；P3.3、P2.5、P3.2 可见专项均通过。该输入注入波动不混入玩家输出功能修复。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-20 | P2 验收指标仍调用已移除的`CastView.close()`，Godot 静默中断后只跑 8 条却打印`failed=0`。 | 已修复为`PlayerOutputController.close_output()`；Windows 双窗口复跑完整`20/20`。 |
| 2026-07-20 | P3.3 可见测试在原生窗口`queue_free()`后一帧立即退出，探针一度在收尾竞态中看到同一 PID。 | 测试加强为等待两帧并断言旧窗口引用失效；最终`47/47`、无残留进程。 |
| 2026-07-20 | 原生 OGV 后端缺少固定真实视频夹具，无法证明画面、运动和声音。 | 未伪造完成；状态/并发使用假后端通过，真实媒体冒烟明确留到 P3.4。 |

## 2026-07-20 Codex P3.4 生命周期、测试夹具与最小证明

### 前置与四层调研回执
- [x] 前置证据：P2 已有 GM（游戏主持人）明确“我验收了”的可见窗口记录；P3.0 已完成应用边界与关闭顺序；P3.1 `75/75`；P3.2 数据/控制器/可见流程 `39/39 + 39/39 + 32/32`；P3.3 `47/47`。`docs/roadmap.md` 的 P2 GM 旧漏勾已按后续明确验收记录修正。
- [x] 项目现状：P3.3 已有 MAP/IMAGE/VIDEO（地图/图片/视频）状态机、可替换视频后端和固定释放顺序，但缺少统一进度/完成/取消结果、真实 OGV（Ogg Theora 视频）夹具、像素/音频证明、十轮切换基线和关闭重开总验收。
- [x] Godot 4.7 源码：锁定 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。对照 `VideoStreamPlayer::set_stream/play/stop/_notification`、`VideoStreamTheora::instantiate_playback`、`VideoStreamPlaybackTheora::set_file/update/video_write/clear`、`Window::_event_callback/_clear_window`、`Main::iteration` 与 `RenderingServerDefault::_draw` 的完整加载、解码、混音、自然结束、退树和 `frame_post_draw（帧绘制完成）`顺序。
- [x] 官方资料：离线 Godot 4.7 `Image（图片）`、`MovieWriter（影片写出器）`、`Playing videos（播放视频）`、`VideoStreamPlayer（视频流播放器）`、`Viewport（视口）`、`AudioServer（音频服务器）`和命令行文档，支持自产 PNG/OGV、固定帧率含音频写出、可见绘制后取像素和总线峰值。
- [x] 英文社区/开源：Godot 问题 #92050 仍提示播放前/停止后画面可能为空；本地 gdUnit4 6.2.0-rc2 有超时等待但与现有 P1/P2 独立测试框架不一致；官方 demo（演示项目）没有满足短时、含音频、固定哈希的可直接复用 OGV。采用“固定夹具 + 现有结构化测试 + 单调时钟超时”，未引入候选版测试框架、VLC、FFmpeg、自写解码器或外部版权素材。

### 已实现与夹具
- [x] `PlayerOutputController（玩家输出控制器）`新增 `output_progressed/output_completed/output_cancelled（输出进度/完成/取消）`，保留 P3.3 兼容信号；测试可注入临时音频总线，图片纹理、视频播放器、呈现器和原生窗口加入测试分组，只用于计数证明。
- [x] `VideoOutputPresenter（视频输出呈现器）`支持把临时测试音频总线注入后端；`VideoPlaybackBackend（视频播放后端）`、`NativeOgvPlaybackBackend（原生 OGV 后端）`和假后端提供只读清理状态，验证声音停止、`stream=null`、信号断开与幂等释放，不新增正式 GM 媒体控制。
- [x] 新增 `tools/p3_4_fixture_generator/` 独立 Godot 小工程，用 `.gdignore` 隔离正式项目。Godot `Image` API 自产 `640 x 480` 四象限 PNG，2,396 字节，SHA-256 `6cad696fde8ff9f226297d8637a3af20dea4787b4aeee28ea81d17c5c0e1a14b`。
- [x] Godot 4.7 `MovieWriter（影片写出器）`自产 `320 x 180`、30 FPS（每秒帧数）、37 帧、约 1.2333 秒、含测试音 OGV，57,349 字节，SHA-256 `29bd2b2f63f2e3155a093c4bc142eec8c3dfa78d6d2f66b23f368f0856d93119`；生成日志 `build/p3_4_fixture_generation.log`。
- [x] `P3_4FixtureFactory（P3.4 夹具工厂）`在隔离 `user://` 创建两个地点、合法图片/视频、缺失图片/视频、损坏图片、伪 OGV、路径逃逸、未来结构版本和一次 `wall_open` 可恢复带团变化；测试结束清理，不碰真实模组。
- [x] 新增 `tests/p3_4_lifecycle_contracts.gd/.tscn` 和 `tests/p3_4_player_output_smoke.gd/.tscn`；所有等待有截止时间，后者强制 Windows 可见显示，不会在无窗口模式降级为假通过。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] `VideoStreamPlayer::set_stream()`先停旧流并实例化新后端 -> `NativeOgvPlaybackBackend.load_file()/release()`执行播放与 `stop -> stream=null -> disconnect -> queue_free` -> P3.4 检查取消、快速替换、十轮切换和释放后的后端快照。
- [x] Theora `set_file/update/video_write`解析 OGV、更新纹理并混音 -> `VideoOutputPresenter`等待真实尺寸并把音频送入临时总线 -> Windows 测试在 `frame_post_draw` 后检查首帧非空、后续帧变化、两种比例黑边和约 `-8.97 dB` 峰值。
- [x] 引擎 `finished`只表示自然结束 -> `PlayerOutputController._on_video_finished()`分配新的地图请求并统一释放 -> 测试验证约 1.2333 秒自然结束、回地图、声音停止和流为空。
- [x] `Window.close_requested`只发请求，`_clear_window`最终删除子窗口 -> `CastView`转发命令，控制器按“媒体 -> 地图 -> 窗口”清理 -> 切场景、关投屏、退出均验证信号断开、原生窗口最后释放和无残留进程。

### 自动测试与可见窗口
- [x] P3.4 无窗口生命周期合同：`64/64`，退出码 0、0 转储、无超时、无强制清理、无残留；日志 `build/crash_matrix/20260720_224906_original_direct/godot.log`。
- [x] P3.4 Windows 可见媒体冒烟：`133/133`、`window_observed=true`、`display_server=Windows`、`frames_drawn=6275`、音频峰值约 `-8.97 dB`、视频时长约 `1.2333 s`；退出码 0、0 转储、无超时、无强制清理、无残留；日志 `build/crash_matrix/20260720_225401_original_direct/godot.log`。
- [x] P1 `352/352`（`20260720_224936`）；P2.4 `56/56`（`20260720_225006`）；P2.6 `64/64`（`20260720_225026`）；P3.1 `75/75`（`20260720_225050`）；P3.2 数据 `39/39`（`20260720_225106`）、控制器 `39/39`（`20260720_225125`）；P3.3 `47/47`（`20260720_225143`）。对应日志均位于 `build/crash_matrix/<时间>_original_direct/godot.log`，退出码 0、0 转储、无残留。
- [x] Windows 可见回归：P2.5 `54/54`（`20260720_225217`）；P2 指标 `20/20`、双窗口平均约 `967.3 FPS`（`20260720_225250`）；P3.2 主界面 `32/32`（`20260720_225330`）。均观察到真实窗口，退出码 0、0 转储、无超时、无强制清理、无残留。
- [x] 静态检查：本轮相关 GDScript（Godot 脚本）无 `:=`、无漏写变量类型；`git diff --check`通过。一次独立干净导入探针在 60 秒超时并被探针清理，0 转储、无残留，记录 `build/crash_matrix/20260720_224727_original_direct/result.json`；未冒充通过，相关脚本随后均由上述真实场景成功解析并执行。
- [x] 预期错误已分类：损坏 PNG、伪 OGV“没有视频流”、P3.2 主/备份损坏快照是测试主动触发；P2 指标三条空模型警告来自隔离测试存档缺少唯一同名素材。最终日志没有 ObjectDB（对象数据库）或资源泄漏警告。

### 未完成与问题状态
- [x] P3.4 自动证明和路线图四项已经完成；GM 后续明确接受现有证据与手动展示过快的剩余风险，P3 总验收完成。该接受不解释为保证以后没有 bug（程序缺陷）。
- [ ] 正式文件选择、媒体登记/删除、缩略图、搜索排序、暂停/进度/音量、淡入淡出、字幕、播放列表、VLC、MP4 和正式媒体音频总线均未实现；这些属于 P4，不是 P3.4 遗漏。
- [ ] 本轮没有新增联网、玩家端、账号、骰子或规则系统。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-20 | P3.4 隔离模组已有缺失视频引用，但首轮无窗口测试只单独断言了缺失图片。 | 已补缺失视频 `ERR_FILE_NOT_FOUND（文件未找到错误）`断言；最终从 `63/63` 增为 `64/64`。 |
| 2026-07-20 | 独立干净用户目录导入在 60 秒内未结束。 | 未判通过；探针强制清理自己启动的进程，0 转储、无残留。P1/P2/P3 全部相关场景随后成功解析执行，当前视为导入通道超时，不作为功能失败或成功证据。 |
| 2026-07-20 | `docs/roadmap.md` 的 P2 GM 验收仍未勾选，与后续明确“我验收了”的开发日志矛盾。 | 已按后续明确记录修正旧漏勾，并保留 P3.4 本轮 GM 人工接受为独立未完成项。 |

## 2026-07-20 Codex P3 总验收接受

- [x] GM 明确指出可见验收不能保证以后不会出现 bug（程序缺陷）；该判断成立，自动与人工验收都只降低已覆盖路径的风险，不构成无缺陷保证。
- [x] GM 在了解 P3.4 手动展示过快、但 Windows 可见自动测试 `133/133`、无窗口生命周期 `64/64`以及 P1/P2/P3 全量回归证据后，明确表示接受现有证据与剩余风险，并要求将本阶段视为完成。
- [x] `docs/roadmap.md`、`docs/p3_lifecycle_test_contract.md`和`docs/p3_player_output_contract.md`已同步为 P3 完成；本次只更新状态文档，没有修改功能代码、测试或夹具，也没有重复运行测试。
- [x] P3 完成只代表应用装配、模组清单、最小带团会话、外部内容/玩家输出合同和生命周期最小证明完成；正式媒体选择与管理、暂停/进度/音量、常见视频格式和淡入淡出仍属于 P4。

### 剩余风险
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-20 | P3.4 手动验收窗口展示过快，GM 未逐帧观察全部自动流程。 | GM 已知情并明确接受该剩余风险；自动像素、音频、自然结束和清理证据保留，未来真实带团若发现问题按新 bug（程序缺陷）处理。 |
| 2026-07-20 | 独立干净导入探针曾在 60 秒超时。 | 继续保留为导入通道风险；0 转储、无残留，全部相关脚本已被 P1/P2/P3 真实测试场景成功解析执行。 |

## 2026-07-20 Codex 运行入口收敛为“测试 / 开始”

### 四层调研回执与源码对照
- [x] 项目现状：顶栏原来按有效记录数量显示“开始带团 / 继续带团 / 选择带团”，把程序内部的创建、读取和选择分支交给 GM（游戏主持人）判断；文件菜单已经有“新开一场带团”，动态入口文案重复。现有运行操作共用 `ModeGate（模式闸门）`，会话保存由 `PlaythroughController（带团会话控制器）`独立负责。
- [x] Godot 4.7 源码：锁定 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`PackedScene::pack -> SceneState::pack -> _parse_node`可从当前 owned（有归属）子树建立内存快照；`PackedScene::instantiate -> SceneState::instantiate`重建独立节点树；节点替换前仍按现有清理链释放运行服务。
- [x] 官方资料：离线 Godot 4.7 `PackedScene（打包场景）`文档确认 `pack()`打包有归属子树、`instantiate()`重建层级；`Timer（定时器）`只服务正式记录的延迟自动保存，不要求测试运行写磁盘。
- [x] 英文社区/开源：Tabletop Club 0.1.4 继续只作为“原始内容与可恢复桌面状态分离”的产品旁证；SaveState Lite 1.2.0 只支持可恢复写入思路。两者都不要求用户区分“开始/继续”文案，也不能替代 Gvtt 的内存测试恢复。
- [x] 源码行为 -> 本地实现 -> 验证：内存打包/实例化 -> `SceneSessionController.begin_test_run()/end_test_run()`保存并恢复测试前 Token、墙体、光源、场景属性和原编辑脏状态 -> P3.2 可见回归验证等待超过自动保存延迟仍无会话；正式 `PlaythroughController`路线未改 -> 控制器/数据层回归继续通过。
- [x] 无法照搬处：Gvtt 不切换整棵主场景，只替换地点内容根；测试恢复复用 `SceneSessionController.replace_with_loaded_scene()`和既有服务清理，不调用 `SceneTree.change_scene_to_*()`，也不增加第三个 `AppMode（应用模式）`。

### 已修改
- [x] 编辑态顶栏固定显示“测试”和“开始”；运行中统一显示“编辑”，状态标签分别显示“测试中”或“记录中”。不再按记录数量改变“开始”文案。
- [x] “测试”从当前内存内容建立经过实例化验证的 `PackedScene（打包场景）`快照，不要求先保存编辑改动，不创建/读取 `session.json`，不启动会话自动保存；退出测试完整恢复内容和测试前编辑脏状态。
- [x] “开始”继续复用现有安全路线：无记录时内部创建，有一份时内部读取，多份时弹记录选择菜单；文件菜单“新开一场带团”继续负责建立另一份记录。
- [x] 选择模组时若处于测试，先恢复测试前内容再进入原有模组保存/关闭流程，避免测试变化误写模组。
- [x] 更新 `docs/design.md` 与 `docs/p3_playthrough_contract.md`，明确制作、测试和正式记录可以随时往返，不设置“制作完成”门槛。

### 自动测试、可见窗口与未完成
- [x] 通过当前唯一 Godot 编辑器会话运行 P3.2 真实可见回归：`P3_2_VISIBLE_RESULT {"assertions":44,"failed":0}`。新增断言证明“测试”改变 Token、墙和光后，等待 1.5 秒仍不创建会话；返回编辑后三项恢复、模组场景字节不变且测试前未保存标记保留；正式“开始”仍保存并恢复会话。
- [x] P3.2 控制器 `39/39`、数据层 `39/39`；数据层日志中的损坏 `.scn`错误是测试主动制造的主/备份双损坏夹具，最终断言为零失败。
- [x] Godot 精确版本为 `4.7-stable (official)`；各测试场景都通过 Godot AI（Godot 人工智能）编辑器通道真实启动并自行停止，没有解析中断或残留运行实例。本轮没有另启命令行 Godot，也没有 ProcDump（进程转储监控）证据，因为用户的编辑器进程正在使用中。
- [ ] P1 主回归本轮两次分别为 `353` 项中 `2`项和`5`项失败；新增“测试/开始”入口与生命周期断言通过，失败集中在既有合成鼠标素材手势。该测试按下右键后未发送右键松开即继续推送左键，复用编辑器运行时结果不稳定；本轮未修改无关素材拖放代码，也不宣称 P1 全绿。
- [ ] GM 仍需在可见主窗口亲手确认“测试 / 开始 / 编辑”和“测试中 / 记录中”文案及按钮手感。本轮可见自动测试证明功能与窗口生命周期，不代替主观体验。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-20 | “开始/继续/选择”把会话文件是否存在暴露成用户日常判断。 | 已收敛为固定“测试 / 开始”；创建、读取和多记录选择保留为内部/低频管理行为。 |
| 2026-07-20 | 制作时缺少不记录的运行入口，直接运行会污染正式带团记录。 | 已增加只使用内存快照的“测试”，退出完整恢复且不写模组或会话。 |
| 2026-07-20 | P1 合成鼠标素材手势在复用编辑器运行下未全绿。 | 未伪报通过；两次失败证据保留，范围与本轮运行入口无关，待独立处理或在单独探针环境复核。 |

## 2026-07-21 Codex 一个模组下新增多桌记录

### 用户模型纠正与四层调研
- [x] 用户明确纠正：模组是唯一持续迭代的底本；周五团、周六团玩同一模组，只需要各自独立进度。此前把“增量”解释成模组历史恢复点或另存为新模组，偏离了真实带团流程。
- [x] 项目现状：底层已经是一个 `ModuleManifest（模组清单）`对应多个 `Playthrough（带团记录）`，每份记录有独立 `session_id（记录编号）`、名称和地点快照；真正问题是文件菜单同时暴露“备份模组/新开一场带团”，新增记录还固定叫“默认带团”。
- [x] Godot 4.7 源码：锁定 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`PackedScene::pack -> SceneState::pack/_parse_node`保存有归属节点，`SceneState::instantiate`重建独立场景，`ResourceSaver/ResourceLoader`完成写入与忽略缓存重读，`FileAccess/DirAccess`完成会话 JSON（结构化文本）和临时/备用文件提交。
- [x] 官方离线资料：`PackedScene（打包场景）`、`ResourceSaver（资源保存器）`、`ResourceLoader（资源读取器）`和 `Saving games（保存进度）`支持应用自行划分持久状态；`AcceptDialog（接受对话框）`确认 `add_cancel_button（添加取消按钮）`、`register_text_enter（回车确认输入）`和现行属性签名。
- [x] 英文社区/开源：Tabletop Club 0.1.4 只作为“原始内容与桌面状态分离”的产品旁证；SaveState Lite 1.2.0 只借鉴可恢复写入。两者都不替代 Gvtt 的完整地点 `.scn（场景文件）`快照，不安装插件、不改成逐对象差异协议。

### 已修改
- [x] 文件菜单从“保存模组 / 备份模组 / 选择模组 / 新开一场带团”收敛为“保存模组 / 选择模组 / 新增一桌”；移除主应用对手动模组历史的调用。
- [x] “新增一桌”打开命名对话框，默认建议“第 N 桌”，可输入“周五团”“周六团”等名称；确认后仍复用 `PlaythroughController.start_new_session()`，在当前模组下生成独立记录编号并从底本进入。
- [x] 旧 `_backups（历史恢复目录）`不删除，避免破坏已有数据；界面不再创建新历史。兼容校验器补充拒绝任何 `sessions/` 路径，旧恢复点也不能夹带某一桌进度。
- [x] 更新 `docs/design.md`、`docs/roadmap.md`、`docs/module_workflow.md`、`docs/p3_persistence_contract.md`和`docs/p3_playthrough_contract.md`，统一为“一份模组底本，多份独立桌记录”。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] `PackedScene::pack/SceneState::_parse_node`保存完整地点子树 -> `ModuleIo.save_session_snapshot_recoverable()`只写当前 `session_id` 的地点 -> P3.2 可见回归分别保存周五团和周六团状态。
- [x] `ResourceLoader`忽略缓存加载、`SceneState::instantiate`重建 -> `PlaythroughController.open_session()`按记录编号恢复 -> 先玩周六团再重开周五团，周五破墙状态保持且未读取周六状态。
- [x] `FileAccess/DirAccess`临时、备用与提交原语 -> `session.json.tmp/.bak`和地点 `.tmp.scn/.bak.scn`原顺序保持 -> P3.2 数据与控制器回归继续覆盖损坏、未来版本、模组编号不匹配和失败回滚。
- [x] Godot 不提供“模组/桌”业务概念 -> `main.gd`只负责桌名输入，`ModuleGate/PlaythroughController/ModuleIo`继续分别负责记录身份、生命周期和磁盘真值；没有复制模组，也没有新增平行保存系统。

### 自动测试、可见窗口与未完成
- [x] 当前唯一 Godot 编辑器会话 `gvtt@c760`，版本 `4.7-stable (official)`、进程 49460；所有场景通过同一可见编辑器通道启动并自行停止，未启动第二个 Godot 进程。
- [x] P3.2 可见主界面回归：`P3_2_VISIBLE_RESULT {"assertions":58,"failed":0}`。覆盖菜单、命名框、周五/周六两个不同编号、两桌状态隔离、底本字节不变和退出前保存顺序。
- [x] P3.2 控制器 `39/39`、数据层 `39/39`；数据层的损坏场景错误为主动制造的正式/备用双损坏夹具，最终零失败。
- [x] P3.1 `77/77`，新增证明模组恢复点不包含 `sessions/`；P1 整棵主应用回归本轮 `351/351`，此前不稳定的合成鼠标手势本轮未失败。
- [x] 静态检查：相关 GDScript 无 `:=`、变量保持显式类型；无旧菜单常量和现行“新开一场带团”文案；`git diff --check`通过。
- [ ] GM 仍需在真实主窗口亲手确认：文件 -> 新增一桌 -> 输入“周五团”或“周六团” -> 新增；确认对话框尺寸、文字和键盘回车手感。自动可见测试证明功能与隔离，不代替主观操作感。
- [ ] 没有删除旧 `_backups` 数据和底层兼容代码；这是避免破坏用户已有数据，不是仍向用户提供模组历史。没有实现图片/视频输出、联网、玩家端、账号、骰子或规则系统。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-21 | “增量”曾被错误解释成模组历史或另存为，导致“备份模组”和“新开一场带团”重复且难以理解。 | 已纠正为“一个模组下新增多桌独立记录”；文件菜单改为“新增一桌”，手动模组历史入口移除。 |
| 2026-07-21 | 新增记录固定命名“默认带团”，多桌选择时无法分清周五团和周六团。 | 已增加桌名输入与“第 N 桌”默认建议；可见回归验证记录列表同时显示周五团和周六团。 |
| 2026-07-21 | 旧模组恢复点校验可能接受含 `sessions/` 的路径。 | 新建扫描与旧恢复点校验均拒绝 `sessions/`；P3.1 最终 `77/77`。 |
| 2026-07-21 | 首版“新增一桌”对话框在 `ConfirmationDialog（确认对话框）`自带取消按钮外又添加了取消按钮。 | 依据 Godot 4.7 离线文档改为设置内置 `cancel_button_text（取消按钮文字）`；修正后 P3.2 可见回归再次 `58/58`。 |

## 2026-07-21 Codex 同类 VTT 多桌工作流调研

### 四层调研回执
- [x] 项目现状：Gvtt 已采用“一份 `ModuleManifest（模组清单）`、多份 `Playthrough（带团记录）`”，数据隔离方向成立；当前“新增一桌”位于文件菜单，多记录选择藏在“开始”入口，桌记录没有独立可见管理区。
- [x] Godot 4.7 源码与官方离线资料：`PackedScene::pack/SceneState::instantiate`、`ResourceSaver/ResourceLoader`只提供完整场景打包、加载和恢复原语，不规定模组、战役或桌的产品层级；现有完整地点快照足以支持调整界面，不要求改成对象差异协议。
- [x] Foundry VTT 官方：`Game World（游戏世界）`是桌游运行实例；官方推荐用 `Adventure Document（冒险文档）`分发预制内容，再导入各个 World。相同冒险重新导入同一 World 会警告覆盖已有内容。来源：`https://foundryvtt.com/article/game-worlds/`、`https://foundryvtt.com/article/adventure/`。
- [x] Fantasy Grounds 官方：`My Campaigns（我的战役）`首页负责创建、命名、选择 Campaign；进入 Campaign 后再激活同一 Adventure Module（冒险模组）。来源：`https://fantasygroundsunity.atlassian.net/wiki/spaces/FGCP/pages/996639879/Hosting+a+Game+Loading+and+Creating+Campaigns`、`https://fantasygroundsunity.atlassian.net/wiki/spaces/FGCP/pages/996640899/Using+and+Activating+Modules`。
- [x] Roll20 官方：Module（模组）只在创建新 Game（游戏实例）时选择，不能加入已有 Game；不同团各建一个 Game，并以同一 Module 初始化。来源：`https://help.roll20.net/hc/en-us/articles/360049691453-Modules`。
- [x] 英文社区/开源：Reddit JSON（结构化数据）与旧版页面均在 20 秒超时，GitHub 精确工作流关键词无相关议题，未伪造社区共识。Tabletop Club `v0.1.4`只旁证 assets/saves（资产/存档）分目录；作者已停止全职开发、更新稀少，不直接照搬。

### 结论与未决项
- [x] “一份模组底本，多桌独立记录”符合三家主流 VTT 的共同数据原则；不需要为周五团、周六团复制可编辑模组。
- [ ] 当前选桌入口不够清楚：同类软件会在进入运行前直接列出 World/Campaign/Game。建议后续把“带团记录：周五团、周六团、＋新增一桌”做成模组内独立可见区，不再藏在“开始”或文件菜单；本轮未获用户修改授权，不改代码。
- [x] 旧桌与后续模组编辑的关系已由 GM 拍板：未访问地点读取最新底本，让该桌体验后来补充的剧情；已访问地点继续使用桌快照。返回旧剧情同时要求合并新底本属于小众事件，不为它引入模组分支或自动差异合并。
- [x] 本轮仅调研并更新日志，没有修改功能代码、场景或测试，没有运行自动测试和可见窗口验证。

## 2026-07-21 Codex 左侧直接选择带团记录

### 四层依据与源码映射
- [x] 项目现状：底层已经是一个模组清单对应多份独立 `Playthrough（带团记录）`；真正的交互问题是“新增一桌”被放在文件菜单，多桌选择又藏在顶栏“开始”后的 `PopupMenu（弹出菜单）`，GM（游戏主持人）无法直接看见自己有哪些桌。
- [x] Godot 4.7 源码：继续锁定 `4.7-stable`、提交 `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`PackedScene::pack -> SceneState::pack/_parse_node`与`SceneState::instantiate`仍负责地点完整快照和独立重建；本轮界面只把选中的 `session_id（记录编号）`交给既有 `PlaythroughController.open_session()`，没有改动快照、缓存、实例化或清理顺序。
- [x] 官方离线资料：Godot 4.7 `VBoxContainer/HBoxContainer（纵向/横向容器）`负责稳定排列记录行，`Button（按钮）`的 `disabled（禁用）`状态用于阻止运行中切桌或进入损坏记录，`Label（文字标签）`的省略显示与提示用于长桌名；没有引入自绘控件或新窗口。
- [x] 同类软件：Foundry VTT 用 Adventure/World（冒险内容/游戏世界）、Fantasy Grounds 用 Module/Campaign（模组/战役）、Roll20 用 Module/Game（模组/游戏实例）分离可复用内容与每桌进度。采用“模组内直接列出各桌”的共同方向；Tabletop Club 0.1.4 维护较弱，只作开源旁证，未照搬；Reddit（社区论坛）查询超时，未伪造社区共识。

### 已修改
- [x] 编辑器左栏新增“带团记录”区：每份合法记录显示桌名和“进入”，损坏记录明确显示“无法读取”并禁用进入；列表下方固定显示“＋ 新增一桌”。
- [x] 文件菜单收敛为“保存模组 / 选择模组”两个真正的文件命令；“新增一桌”不再伪装成文件操作。
- [x] 移除多桌时由“开始”弹出的隐藏记录菜单。没有记录时“开始”仍打开命名框，只有一桌时仍直接进入；有多桌时停在编辑态并提示从左侧选择。
- [x] 保持已经确定的“测试 / 开始”名称与数据路线不变；新增桌仍从模组底本开始，进入旧桌仍只恢复该桌快照，不复制模组、不读取其他桌变化。
- [x] 更新 `docs/design.md`、`docs/module_workflow.md`、`docs/p3_playthrough_contract.md`和`docs/roadmap.md`；同时纠正路线图开头仍写“清单和带团状态尚未读回”的过期现状。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] 完整地点快照和独立实例化 -> 继续复用 `PlaythroughController/ModuleIo（带团控制器/模组读写）`，左栏只传记录编号 -> P3.2 数据层与控制器各 `39/39`，没有新增按对象差异协议。
- [x] 容器按子控件顺序布局、按钮按禁用状态拒绝操作 -> `_sync_playthrough_list()`重建记录行并按编辑态/损坏状态设置“进入” -> P3.2 可见回归同时找到周五团、周六团并从周五团行恢复破墙状态。
- [x] 删除隐藏弹出选择链 -> 移除 `_session_menu`等旧成员和回调，多桌“开始”只写提示 -> 静态搜索确认旧标识不存在，可见回归确认没有弹出隐藏选择器。

### 自动测试、可见窗口与未完成
- [x] 当前唯一 Godot 编辑器会话 `gvtt@c760`，版本 `4.7-stable (official)`、进程 49460；P3.2 可见主界面 `62/62`、控制器 `39/39`、数据层 `39/39`，P3.1 `77/77`。损坏 `.scn（场景文件）`错误是数据层主动制造的损坏夹具，最终均为零失败。
- [x] 可见回归实际创建周五团与周六团，确认两行同时存在、多桌“开始”只提示左侧、点击周五团“进入”恢复其破墙状态；测试场景均自行停止，最终游戏状态为 `stopped（已停止）`，没有启动第二个 Godot 进程。
- [x] 静态检查：本轮 GDScript（Godot 脚本）无 `:=`，旧隐藏选择器标识不存在；`git diff --check（差异格式检查）`通过。
- [x] 复用编辑器的 P1 运行两次输出磁盘已不存在的 5 条旧素材拖放断言，报错行也与当前文件不符；该结果按无效缓存运行作废，不列为 P1 或 P3.2 未完成项。P1 已完成，最新有效独立证据仍为 `352/352`。
- [ ] GM 仍需在真实主窗口亲手确认左栏宽度、长桌名显示和“进入”按钮手感；自动可见回归证明功能路线，不代替主观体验。
- [x] GM 已接受现有简单策略：未访问地点跟随最新底本，已访问地点保留本桌快照；罕见的旧地点回访不打乱主逻辑，也不把模组备份误称为会话合并。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-21 | 多桌记录选择藏在“开始”后的弹出菜单，GM 看不见当前有哪些桌；“新增一桌”又被误放进文件菜单。 | 已改为左栏常驻“带团记录”，文件菜单只保留两个模组文件命令。 |
| 2026-07-21 | 路线图开头仍把已完成的清单/带团状态读回写成当前缺失。 | 已改为“改版前问题”，并明确 P3.1/P3.2 已完成。 |
| 2026-07-21 | P1 复用编辑器运行命中磁盘已不存在的旧素材拖放断言。 | 已确认是无效缓存运行并作废，不重开 P1 完成状态；旧断言已不在当前测试文件中。 |
| 2026-07-21 | 旧桌是否接收后续底本修改曾未决定。 | 已采用现有读取规则：未访问地点读最新底本，已访问地点读桌快照；不为罕见回访建立模组分支或自动合并系统。 |

## 2026-07-21 Codex P3.2 当前状态文档纠错

- [x] 仅更新状态文档，没有修改功能代码、场景、测试或模组数据。
- [x] `docs/p3_playthrough_contract.md` 页首从“实现前、功能尚未开始”改为 P3.2 已实现，并补当前 `39/39 + 39/39 + 62/62` 专项证据；“当前缺口”改为实现前缺口及现有落地映射。
- [x] `docs/p3_persistence_contract.md` 页首改为 P3.1/P3.2 已实现，明确当前不再提供手动“备份模组”，旧 `_backups/` 只兼容读取与校验。
- [x] `docs/roadmap.md` 和 `docs/README.md` 更新到 2026-07-21；路线图保留 2026-07-20 P3 阶段收口证据，并另列 2026-07-21 多桌入口调整证据。P1 旧脚本资源输出按无效缓存运行作废，不列为未完成。
- [x] 7 月 19 日开发日志中的阻塞/未开始记录保留为历史，不改写当时事实；本条和后续完成记录明确取代其“当前状态”含义。
- [x] 本轮未重跑自动测试或可见窗口，因为没有代码变化；完成后执行差异格式与过期状态搜索。

## 2026-07-21 Codex P1 状态说明纠正

- [x] P1 是已完成的基础功能阶段；P1 回归测试只是后续修改后的旧功能体检，不表示重新实施 P1。
- [x] 当前磁盘测试仍保留文件菜单和运行态实体面板等有效回归；日志中的 5 条旧素材手势断言已不在磁盘测试文件中。
- [x] 两次旧缓存输出直接作废，不作为功能失败、验证阻塞或待办；P1 完成状态保持不变，最新有效独立证据为 `352/352`。
- [x] 本轮只纠正文档表述，没有删除有效 P1 回归、没有修改功能代码，也没有运行测试。
## 2026-07-21 Codex P4.3 视频演出

### 前置与四层调研回执
- [x] P4.2 前置通过：P4.2 Windows 可见专项 `56/56`，P3.4 生命周期 `64/64`，P3.4 Windows 可见媒体冒烟 `133/133`，且已有 GM 手动确认；没有把未完成的 P4.2 当作本轮前置。
- [x] 项目现状：复核 `NativeOgvPlaybackBackend`、`VideoOutputPresenter`、`PlayerOutputController`、`CastView`、`main.gd` 和 P3/P4.2 测试；P3 已有 OGV 播放、首帧、自然结束和释放合同，真正缺口是暂停/恢复/停止/音量公开命令、正式媒体总线和 GM 视频控制行。
- [x] Godot 4.7 源码：精确基线 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`；从 `reference/godot-4.7-stable-full.zip.zip` 对照 `scene/gui/video_stream_player.cpp`、`modules/theora/video_stream_theora.cpp`、`servers/audio/audio_server.cpp`、`scene/main/window.cpp`。当前 `reference/godot_4_7_source/` 是导航/物理子集，不冒充视频源码依据。
- [x] 官方资料：离线 `gdd_0144_Playing_videos.md` 确认核心只支持 Ogg Theora `.ogv`；`gdd_0773_VideoStreamPlayer.md` 确认 `paused`、`finished`、`play()`、`stop()`、`stream_position`、`bus`；`gdd_1224_AudioServer.md` 确认 `add_bus`、`set_bus_volume_linear`、`set_bus_mute`、峰值读取；`gdd_0786_Window.md` 确认 `close_requested` 只是关闭请求。
- [x] 英文社区/开源：复核同日 P4.0 记录的 Godot VLC `v1.2.0`（Godot 4.3+、Windows/Linux、LGPL-2.1）和 EIRTeam.FFmpeg（Godot 4.x、MIT、原生构建链/H.264 专利提示）；它们都没有通过本项目 4.7、双窗口、导出、清理和许可证隔离验证。本轮联网复查被访问控制拒绝，未新增未经核实的社区事实。

### 已实现
- [x] `scripts/player_output_controller.gd` 新增暂停、恢复、停止、线性音量控制和 `Media` 产品媒体总线；播放前确保总线存在，释放媒体时先停止后静音，切媒体、切地点、关投屏和程序退出继续走统一释放链。
- [x] `scripts/video_output_presenter.gd` 将暂停/恢复、播放位置和后端调试状态转为 Presenter 公共行为；`scripts/native_ogv_playback_backend.gd` 补充暂停状态、位置、总线记录和释放后的调试状态。
- [x] `scripts/main.gd` 媒体区新增视频“播放”、暂停/继续、停止、返回地图和音量滑块；视频条目只有登记状态为“可播放”时启用，MP4/MOV/WebM 等仍不写成支持。
- [x] `tests/p4_3_video_presentation_regressions.gd/.tscn` 使用固定 `320 x 180` 带音频 OGV，覆盖首帧、暂停位置不推进、暂停画面不变、恢复继续、帧变化、Media 峰值、停止静音、自然结束回地图、十轮切换、切地点清理、窗口关闭清理。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] `VideoStreamPlayer::set_stream()` 先停旧流、断旧信号、再实例化后端 -> `NativeOgvPlaybackBackend.load_file()/release()` 保持停播、清流、断信号、释放节点 -> P4.3 `144/144`、十轮和窗口关闭均通过。
- [x] `VideoStreamPlayer::_notification()` 退出树先 `stop()` 再移除混音回调；Theora `clear()` 释放文件、Vorbis/Theora 解码器和音频缓冲 -> Controller 释放 Presenter 后静音 `Media` -> 停止、自然结束、切地点、窗口关闭均检查总线静音和节点归零。
- [x] Theora `set_file()` 解析视频流与头部，`update()` 在未播放或暂停时不推进 -> Presenter 首帧非零尺寸门禁、Controller PAUSED 状态和位置调试 -> 暂停位置增量 `0.0`，首帧/帧变化/音频峰值均通过。
- [x] `AudioServer` 按总线名路由并提供线性音量/峰值 -> 产品固定命名 `Media`，不沿用 P3 `P3_4_TEST_MEDIA` -> 自动断言 `Media` 独立于 `Master`，峰值约 `-15.0 dB`。
- [x] `Window.close_requested` 不自动销毁 -> `CastView` 转 Controller，Controller 释放媒体、地图、窗口 -> 窗口关闭专项断言顺序 `release_media -> release_map -> release_window`。
- [x] Godot 不知道 Gvtt 的媒体 ID、GM UI 和地图回退 -> Controller 保持唯一状态，`main.gd` 只消费状态信号 -> MCP 真实主界面看到视频条目“可播放”、视频控制行和自然结束后的“投屏：地图”。

### 自动测试与可见窗口
- [x] P4.3 Windows 可见专项：`P4_3_VIDEO_PRESENTATION_RESULT {"assertions":144,"failed":0,"display_server":"Windows","frames_drawn":166,"max_audio_peak_db":-14.998784,"pause_position_delta":0.0}`；固定 OGV SHA-256 `29bd2b2f63f2e3155a093c4bc142eec8c3dfa78d6d2f66b23f368f0856d93119`。
- [x] P3.3 无窗口 `47/47`、P3.4 生命周期 `64/64`、P3.4 Windows 可见 `133/133`、P4.2 Windows 可见 `56/56` 全部通过；P3.4 可见音频峰值约 `-8.97 dB`，视频时长约 `1.2333 s`。
- [x] 主界面短运行 `180` 帧正常退出；MCP 重新启动主场景后 helper live、无启动错误。运行树实证包含 `MediaVideoPauseButton`、`MediaVideoStopButton`、`MediaVolumeSlider`，视频条目为“可播放”；点击播放后真实 UI 回到“投屏：地图”，符合自然结束回退。
- [x] 直接使用 D3D12/WASAPI 启动测试曾在本机 Godot 4.7 进程层 signal 11，未拿到 GDScript 报错；沿已有隔离 `user_data` 并使用 Windows OpenGL Compatibility + WASAPI 后全部通过。该环境问题不改写为产品代码失败。
- [x] 编辑器最终回到 `ready`，运行态已停止；MCP 最终日志仅有既有脚本警告和测试触发的 Unicode NUL 输出，没有本轮新增脚本错误。

### 未做与问题状态
- [x] 未接入 Godot VLC 或 FFmpeg；未承诺 MP4/MOV/WebM/MKV/AVI。正式支持范围仍为登记后实际可解码的 OGV。
- [x] 未实现进度拖动、字幕、章节、播放列表或投屏窗口内 GM 控件；这些不在 P4.3 交付范围。
- [ ] GM 仍建议在自己的 Godot 可见窗口亲手走一次：打开开发测试模组/实际模组 -> 媒体 -> 播放 OGV -> 暂停 -> 继续 -> 停止 -> 返回地图，并听确认音量滑块只影响视频；自动专项已覆盖同一行为链，MCP 已实证主界面控件和自然结束回地图。

| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-21 | 本机直接使用 D3D12/WASAPI 启动专项触发 Godot 4.7 signal 11。 | 已隔离为启动环境问题；使用项目历史 `user_data` 和 Windows OpenGL Compatibility + WASAPI 后 P4.3 `144/144` 通过。 |
| 2026-07-21 | 编辑器提示 `module_io.gd`、`media_registry.gd`、`module_gate.gd` 的既有静态警告，以及 Presenter/Backend 未使用信号警告。 | 与本轮控制逻辑无关；实际 Windows/无窗口运行均退出码 0，未新增脚本错误。 |
## 2026-07-21 Codex P4.3 验收夹具音乐替换

### 调研回执与决策
- [x] 项目现状：P4.3 播放器、暂停/恢复/停止、`Media` 产品媒体总线和清理链已经通过；用户实际验收反馈旧夹具只有约 `1.2333 s`，且连续 `523.25 Hz` 测试音太刺耳，真正问题在验收素材，不在播放器。
- [x] Godot 源码：沿用本项目已锁定的 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88` 播放链：`VideoStreamPlayer::set_stream()/play()` -> Theora 播放后端逐帧 `update()`/音频混合 -> `finished` -> Controller 释放；本轮没有修改这条引擎行为链。
- [x] 官方资料：离线 `gdd_0145_Creating_movies.md` 和 `gdd_1328_MovieWriter.md` 确认 `.ogv` 是内置 Theora + Vorbis，`--write-movie`、固定 FPS 和 `SceneTree.quit()` 可用于自产含音频夹具；`CanvasItem.draw_string()` 与 `ThemeDB.fallback_font` 用于生成可识别的验收画面。
- [x] 英文社区/开源：沿用 P4.3 调研的 Godot #92050、gdUnit4 和官方 demo 结论；没有找到兼容 Godot 4.7、可固定哈希、可安全纳入本项目的现成短音乐 OGV，因此不引入外部媒体、FFmpeg、VLC 或新插件。
- [x] 采用方案：只改 `tools/p3_4_fixture_generator/` 的自产画面和音频样本，保留 `tests/fixtures/p3_4/motion_audio_320x180.ogv` 路径与 OGV 格式；画面升级为 `640 x 360` 的平滑双图形、标题、状态灯和进度条，音轨改为 18 个半秒音符的原创短旋律、四小节低音伴奏、每音符起落和整体淡入淡出。
- [x] 未采用方案：没有把 MP4/MOV/WebM 写成支持，没有接入 VLC；没有把连续测试正弦波继续伪装成音乐，也没有修改正式媒体播放代码。

### 契约与验证
- [x] 更新生成工程视口为 `640 x 360`，总帧数 `270`，Godot 4.7 OpenGL Compatibility 离线写出 `271` 帧、30 FPS、`9.0333 s`；文件 `693,642` 字节，SHA-256 `3a14a04c0cdf193458fbfe38ccbe2b8add016b197dd6880991b1d0aefcec6142`。
- [x] 更新 P3.4/P4.3 尺寸断言为 `640 x 360`、视频时长断言为 `8.0-10.0 s`、自然结束等待为 `12,000 ms`；生命周期哈希合同同步更新。
- [x] Godot 源码行为 -> 本地实现 -> 验证：固定 FPS 逐帧写出 -> 生成器 `_process()`/`_draw()`/`SceneTree.quit()` -> P3.4 Windows 可见 `133/133`；OGV 播放/音频混合 -> 原有 `NativeOgvPlaybackBackend`/`Media` -> P4.3 `144/144`；资源哈希与模块重开 -> P3.4 生命周期 `64/64`。
- [x] P3.4 Windows 可见结果：`P3_4_VISIBLE_RESULT {"assertions":133,"failed":0,"frames_drawn":1779,"max_audio_peak_db":-33.013042,"video_duration_seconds":9.033333,"video_sha256":"3a14a04c..."}`。
- [x] P4.3 Windows 可见结果：`P4_3_VIDEO_PRESENTATION_RESULT {"assertions":144,"failed":0,"frames_drawn":1248,"max_audio_peak_db":-30.620777,"pause_position_delta":0.0,"video_sha256":"3a14a04c..."}`。
- [x] P3.4 生命周期结果：`P3_4_LIFECYCLE_RESULT {"assertions":64,"failed":0,"video_sha256":"3a14a04c..."}`。
- [x] 运行态中的伪 OGV、损坏 PNG 和 Unicode NUL 是既有测试主动触发的负例日志；三组结构化结果均为 `failed=0`，未新增产品错误。

### 人工验收
- [x] 运行态主界面验证：打开 `开发测试模组` 后，媒体区出现“GVTT 音乐视频验收”，按钮为“播放”、状态为“可播放”；触发播放后状态为“投屏：视频 · GVTT 音乐视频验收”。
- [x] 发现并修正 `scripts/main.gd::_on_media_video_stop_pressed()` 把正数请求编号误当失败的问题；现在停止后状态为“投屏：地图”。
- [x] 发现并修正媒体控制条布局：Godot 4.7 `BoxContainer::_resort()` 按最小宽度分配时，旧版把停止按钮压到 `40 x 31`；现改为暂停/停止各占一半的 `149 x 32`，音量另起一行，运行态截图确认播放时按钮清晰可见。
- [ ] GM 可见验收待本轮人工复核：启动项目后在 GM 主窗口“媒体”区点击视频“播放”，应听到柔和短旋律并看到约 9 秒的 GVTT MEDIA CHECK 画面；中途点击“暂停/继续”、再点“停止”，应立即静音并回到地图。此项自动测试无法替代人耳对音乐听感的最终确认。
## 2026-07-21 Codex GM/玩家同画面媒体输出

### 调研回执与源码对照
- [x] 项目现状：`PlayerOutputController` 是 `MAP/IMAGE/VIDEO` 和播放阶段唯一所有者，`CastView` 只持有玩家原生窗口；此前 GM 只显示“投屏：视频”状态，地图区域没有媒体画面，导致 GM 必须回头看玩家屏幕。
- [x] Godot 4.7 源码：精确基线 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`；`scene/gui/video_stream_player.cpp::set_stream()` 停旧流并实例化后端，`get_video_texture()`返回当前播放纹理，`_notification(NOTIFICATION_EXIT_TREE)`先停播再移除混音回调；同一 `Texture2D`可被多个 `TextureRect`绘制。
- [x] 官方资料：离线 `gdd_0773_VideoStreamPlayer.md`确认 `get_video_texture()`返回当前帧、`.ogv` 原生播放和 `finished`；`gdd_0762_TextureRect.md`确认等比居中；`gdd_0565_Control.md`/`gdd_0622_HBoxContainer.md`确认控制层的最小尺寸和自动重排接口。
- [x] 英文开源：本机 MIT `addons/godot_ai/mcp_dock.gd` 的主要操作区采用独立 `HBoxContainer + SIZE_EXPAND_FILL`，作为控制面与内容面分离的布局参考；不引入外部运行依赖。
- [x] 行为链：`VideoStreamPlayer.get_video_texture()`/`ImageTexture` -> Presenter 只读纹理接口 -> `PlayerOutputController.get_active_media_texture()` -> GM `UI_Layer` 第 2 层的 `GmMediaSurface`；玩家 `CastWindow/MediaRoot`继续使用原呈现器，两个窗口共享同一动态纹理和唯一播放状态。
- [x] 清理映射：`output_requested`先清空 GM 面，`output_changed`按 `IMAGE/VIDEO`重新绑定或在 `MAP/NONE`隐藏；Presenter 释放后 GM `TextureRect.texture=null`，不保留第二播放器、第二音频总线或第二进度真值。

### 实现与验证
- [x] 新增 `PlayerOutputPresenter.get_output_texture()`、`VideoPlaybackBackend.get_video_texture()`、`NativeOgvPlaybackBackend.get_video_texture()`和 `PlayerOutputController.get_active_media_texture()`；图片和视频均复用当前输出纹理。
- [x] `scripts/main.gd` 新增 `GmMediaBackdrop/GmMediaSurface`：媒体时覆盖 GM 地图画面，左侧媒体控制、顶部工具栏和其他 GM 信息仍显示在上层；玩家窗口不显示 GM 控件。
- [x] P4.2 图片共享纹理回归：`58/58`，图片共享纹理非空且为 `640 x 480`，淡入淡出、十轮释放通过。
- [x] P4.3 视频共享纹理回归：`146/146`，共享纹理 `640 x 360`，暂停位置增量 `0.0`，峰值约 `-29.47 dB`，停止静音、自然结束、十轮切换和窗口清理通过。
- [x] 邻接回归：P3.3 `47/47`，P3.4 生命周期 `64/64`，新接口没有改变旧输出合同和释放顺序。
- [x] 主界面双窗口实测：图片和视频播放时 `GmMediaSurface.visible=true`、`GmMediaSurface.texture!=null`、玩家 `MediaRoot.visible=true`；视频 GM 纹理为 `640 x 360`；点击停止后 GM 面和玩家面同时隐藏、纹理清空、状态回到“投屏：地图”。截图产物：`build/gm_media_mirror_video.png`、`build/player_media_mirror_video.png`。
- [x] 首次测试暴露的断言类型错误（`Texture2D.get_size()`为 `Vector2`）已修正，最终回归无脚本解析错误。

### 人工验收
- [ ] 打开“开发测试模组” -> 左侧“媒体” -> 点击“GVTT 音乐视频验收”的“播放”；预期 GM 地图区域和玩家投屏同时显示完整视频，GM 左栏保留“暂停/停止/音量”，玩家窗口无 GM 控件。点击“暂停/继续”和“停止”确认两边同步。

## 2026-07-21 Codex 运行态媒体入口修复

### 调研回执与问题定位
- [x] 项目现状：`scripts/main_ui_controller.gd::apply_panel_for_mode()` 原先在运行态把整个 `_left_panel` 设为不可见；媒体播放按钮本身没有运行态禁用逻辑，登记入口 `_show_media_file_dialog()` 则明确拒绝运行态。真正问题是左栏权限过宽，不是播放器只能在编辑态工作。
- [x] Godot 源码：精确基线 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`；`scene/main/canvas_item.cpp::CanvasItem::is_visible_in_tree()` 返回自身 `visible` 与父树可见性的合取，父节点隐藏会让整棵媒体子树不可见；`scene/gui/base_button.cpp::BaseButton::gui_input()` 在 `status.disabled` 时直接拒绝交互。
- [x] 官方资料：离线 `gdd_0565_Control.md`确认 `Control`继承`CanvasItem`并共享`visible`；`gdd_0532_BaseButton.md`确认`disabled=true`时按钮不能点击或切换。两者是独立机制，不能用“隐藏整个面板”代替“禁用编辑操作”。
- [x] 英文社区/开源：本机 MIT `addons/godot_ai/mcp_dock.gd`采用可见内容容器、独立操作行和单按钮 `visible/disabled` 状态管理；兼容 Godot 4.x，无新增依赖。没有引入插件，复用 Gvtt 现有分区和 `ModeGate`。

### 实现与验证
- [x] `scripts/main_ui_controller.gd`不再在运行态隐藏整个左栏；`scripts/main.gd::_apply_panel_for_mode()`按分区权限保留媒体，隐藏场景、带团记录、模型和地面纹理等编辑区，并保存/恢复分区折叠状态。
- [x] 运行态媒体列表仍显示已登记图片的“投放”和已登记 OGV 的“播放”；改名/删除菜单、登记图片/视频和刷新行只在编辑态创建或显示；回调也增加运行态保护。
- [x] `tests/p1_runtime_regressions.gd`新增模式断言：运行态左栏和媒体分区可见，场景编辑区和媒体登记行不可见；切回编辑态恢复。P1 实际结果：`357` 项断言、`5` 项失败，失败均为既有素材拖放/嵌入窗口夹具，不是本轮新增断言。
- [x] Godot 可见主界面运行态实证：带团会话进入“记录中”后，`ItemPanel.visible=true`、媒体分区可见、场景分区隐藏、登记行隐藏；媒体条目只显示“播放”。
- [x] 运行态媒体控制链实证：播放阶段 `3` 且 `GmMediaSurface.visible=true`、纹理非空；暂停阶段 `4`、按钮变“继续”；恢复回阶段 `3`；停止回阶段 `0`、状态“投屏：地图”、GM 面隐藏。
- [x] P4.3 Windows 可见专项重跑：`P4_3_VIDEO_PRESENTATION_RESULT {"assertions":146,"failed":0,"frames_drawn":13225,"max_audio_peak_db":-49.641056060791,"pause_position_delta":0.0,"video_sha256":"3a14a04c..."}`。

### Godot 源码行为 -> 本地实现 -> 验证
- [x] 父 `CanvasItem` 可见性决定子树是否可见 -> `Main`按媒体/编辑分区分别切换 `visible`，不再隐藏 `_left_panel` -> 主界面运行态节点树实证媒体可见、场景隐藏。
- [x] `BaseButton.disabled`只阻止按钮交互 -> 运行态不创建媒体编辑菜单并隐藏登记行，播放/暂停/停止/音量仍由同一 `PlayerOutputController` -> 运行态播放、暂停、恢复、停止实证；P4.3 `146/146`。

### 未做与问题状态
- [x] 运行态不允许登记、刷新、改名、删除媒体；这属于内容管理权限，保留在编辑态。
- [ ] P1 既有 5 项素材按钮/拖放夹具失败仍待独立处理；本轮没有把它们误报为运行态媒体回归失败。
## 2026-07-21 Codex P4.4 幕式内容管理与 GM 手动投放

### 前置与四层调研回执
- [x] 项目现状：P4.1-P4.3 已有 `ExternalContentRef`、`LocationRef`、`MediaRegistry`、`PlayerOutputController`、图片/视频 Presenter 和独立媒体总线；原 P4.4 仍只是媒体列表加播放按钮。现有 `ModuleManifest`/`ModuleIo`/`ModuleGate` 使用稳定标识、版本化 JSON 和 tmp -> 校验 -> bak -> 提交保存链，因此幕采用逻辑引用集合，不移动原文件。
- [x] Godot 4.7 源码：锁定 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`；对照 `scene/gui/control.cpp` 的 `get_drag_data()`/`can_drop_data()`/`drop_data()`、`scene/gui/tree.cpp` 的 `get_drop_section_at_position()`、`editor/docks/filesystem_dock.cpp` 的 `get_drag_data_fw()`/`can_drop_data_fw()`/`drop_data_fw()`。本地实现复用“取数据 -> 校验落点 -> 提交重排”行为，但只重排幕内稳定引用，不执行 Godot 编辑器的真实文件移动/复制。
- [x] 官方资料：离线 Godot 4.7 `Control`、`Tree`、`TreeItem`、容器、`Button`、`Slider` 和 tooltip（提示）文档确认公开控件接口；未使用编辑器私有类。Godot 4.7 版本与项目 `project.godot` 的 `4.7` 特性配置一致。
- [x] 英文 VTT/开源：Foundry 的 Scenes、Journal Entries、Playlists、Folders；Roll20 的 Page Menu & Folders、Art Library；Tabletop Club 的 Asset Pack Structure。共通做法是内容类型分离、逻辑分组、搜索/排序和 GM 手动展示，不把整理集合强行做成自动时间线。
- [x] 采用方案：新增“幕”作为可排序逻辑资料夹；图片、视频、纯文本和地点/战斗地图作为幕内引用；排序只服务于整理和上一项/下一项选择，不保存剧情完成度、不自动推进。

### 已实现
- [x] 新增 `scripts/act_ref.gd`、`scripts/act_item_ref.gd`：幕和幕内容引用强类型化；媒体/地点引用稳定 ID，文本保存标题、展示内容和 GM 私有备注。
- [x] `ModuleManifest.SCHEMA_VERSION` 从 1 升为 2；`ModuleIo` 增加 v1 -> v2 迁移，旧模组自动得到空 `acts` 数组；清单校验保留缺失媒体/地点引用，不静默删除。
- [x] `ModuleGate` 增加幕增删改、内容增删改、排序、备注和跨幕复用接口；保存继续使用候选清单和可恢复提交，删除幕/移出条目不删除源文件。
- [x] 新增 `scripts/act_item_tree.gd`、`scripts/act_library_panel.gd`：GM 左栏新增“幕”区，支持创建/重命名/删除/备注、搜索、媒体/地图/文本加入、拖动排序、任意选择投放和运行/编辑权限禁用；搜索时暂停拖动排序，避免过滤列表误写真实顺序。
- [x] `PlayerOutputController` 增加 `TEXT` 输出类型和 `TextOutputPresenter`；纯文本与图片/视频共用准备、启用、失败回地图和释放生命周期，玩家窗口只看到文本，不包含幕列表、路径、GM 备注或错误堆栈。
- [x] P4/P6 文档边界重规划：P4.4 交付幕式内容管理与快速手动投放；P6 保留完整媒体库、标签、批量整理和复杂场景增强，不重复实现基础幕引用。

### 自动测试与可见窗口
- [x] P3.1 清单回归：`P3_1_MODULE_MANIFEST_RESULT {"assertions":79,"failed":0}`。
- [x] P3.2 Windows 主界面/带团回归：`P3_2_VISIBLE_RESULT {"assertions":62,"failed":0}`。
- [x] P3.3 玩家输出合同：`P3_3_PLAYER_OUTPUT_RESULT {"assertions":47,"failed":0}`。
- [x] P4.1 Windows 媒体登记：`P4_1_MEDIA_REGISTRATION_RESULT {"assertions":43,"failed":0}`；损坏 PNG/伪 OGV 的引擎错误是测试主动触发的失败路径，产品消息仍不含路径/堆栈。
- [x] P4.2 Windows 图片演出：`P4_2_IMAGE_PRESENTATION_RESULT {"assertions":58,"failed":0,"frames_drawn":1159}`，比例、淡入淡出、失败回地图和释放通过。
- [x] P4.3 Windows 视频演出：`P4_3_VIDEO_PRESENTATION_RESULT {"assertions":146,"failed":0,"frames_drawn":17549,"pause_position_delta":0.0}`，播放、暂停/恢复、停止、自然结束、音频总线和清理通过。
- [x] P4.4 幕管理专项（无窗口）：`51/51`；覆盖迁移、增删改排、跨幕复用、删除边界、缺失引用、编辑/运行禁用、文字输出和玩家树隔离。
- [x] P4.4 Windows 可见专项：`P4_4_ACT_MANAGEMENT_RESULT {"assertions":65,"display_server":"Windows","failed":0,"frames_drawn":5}`；额外覆盖视频播放/暂停/恢复/停止、按钮文案和返回地图后的禁用状态。
- [ ] GM 真人点击验收仍待执行：正常启动模组首页 -> 创建幕 -> 加入图片/视频/文字/地图 -> 拖动排序 -> 任意投放 -> 文字投放 -> 返回地图；确认玩家窗口始终没有 GM 控件、路径或错误。

### 未做与问题状态
- [x] 本阶段没有实现自动播放下一项、计时切换、条件分支、剧情完成度、规则触发器或强制当前步骤；这些不属于当前 Gvtt 内容管理核心。
- [x] 本阶段没有移动、复制或改名外部媒体文件；幕只保存引用，删除幕和移出条目不会删除源文件。
- [x] P4.1 旧测试夹具文件名仍为 `motion_audio_320x180.ogv`，但实际固定视频头部为 `640x360`；P4.1 断言已按实测尺寸修正，文件名暂不改动以避免无必要的引用迁移。

| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-21 | P4.1 固定 OGV 文件名与实际 `640x360` 头部尺寸不一致。 | 已修正登记回归断言；保留文件名，后续若整理测试资产再单独迁移。 |
| 2026-07-21 | Godot 无窗口模式读取 OGV 头部尺寸不可靠。 | Windows 可见 P4.1/P4.3 均已复核；不把无窗口尺寸结果当产品回归证据。 |

## 2026-07-21 Codex P4.4 幕可反复复用与第一入口语义修正

### 四层依据与纠正结论
- [x] 项目现状：`ActRef` 没有顺序、完成、解锁或使用次数字段；`ActLibraryPanel._selected_act_id` 原本也只是面板内存选择，`Playthrough` 只持有 `current_location_id` 和逐地点快照。真正缺口是命名、左栏层级和专项测试没有把“幕可反复使用、幕之间无剧情顺序”锁成合同。
- [x] Godot 4.7 源码：精确基线 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`；`scene/main/scene_tree.cpp` 的 `change_scene_to_file()` 先经 `ResourceLoader::load()` 得到 `PackedScene`，`change_scene_to_packed()` 再调用 `PackedScene::instantiate()` 和 `change_scene_to_node()`；`scene/resources/packed_scene.cpp` 的 `PackedScene::instantiate()` 负责实例化节点树并发送 `NOTIFICATION_SCENE_INSTANTIATED`。这条链只负责地图节点树，不提供叙事幕进度。
- [x] 官方资料：离线 Godot 4.7 Nodes and Scenes、PackedScene、Using SceneTree 文档确认场景是可保存、加载、实例化的节点树；地图场景是幕可引用的空间内容服务，不应被解释成幕本身。
- [x] 英文 VTT/开源：本轮重新读取 Foundry Scenes/Folders 和 Tabletop Club asset pack 文档；Foundry 把 Scene 定义为可探索区域，Folder 负责组织文档，支持手动排序和反复访问。Roll20 页面本轮被 Cloudflare 拦截，只沿用 P4.4 合同中已有调研记录，不伪称重新抓取成功。
- [x] 纠正结论：幕是 GM 可反复查看和使用的第一层内容资料夹；可以没有地图；幕之间没有剧情先后、完成、解锁、历史或自动推进。选择幕只更换 GM 资料视图，只有明确投放条目才改变玩家输出。

### 实现与验证映射
- [x] `scripts/act_library_panel.gd` 把内部 `_selected_act_id` 改为 `_viewed_act_id`，新增只读 `get_viewed_act_id()`；幕选择提示明确不会改变玩家画面。没有新增持久化字段或第三个 `AppMode（应用模式）`。
- [x] `scripts/main.gd` 把“幕”提升为左栏第一工作入口；原“场景”区改名“地图素材”并置于幕后，继续负责编辑态地图创建、保存和尺寸。`SceneSessionController`、`PlaythroughController` 和实际地图切换链未改。
- [x] `scripts/act_ref.gd` 与 P4.4 合同、设计、路线图、推进对话统一写明：同一幕可反复使用，幕可无地图，数组位置不表示剧情顺序，`Playthrough` 不保存幕状态。
- [x] `tests/p4_4_act_management_regressions.gd` 保留一个只有媒体、没有地图的幕；新增“首次投放 -> 查看另一个幕但玩家输出/请求号不变 -> 回到原幕再次投放 -> 清单完全未变”链，并拒绝 `current_act_id`、幕历史、完成/解锁等字段；同时断言幕区位于地图素材区之前。
- [x] Godot P4.4 无窗口专项：`P4_4_ACT_MANAGEMENT_RESULT {"assertions":77,"display_server":"headless","failed":0,"frames_drawn":0}`。
- [x] Godot P4.4 Windows 可见专项：`P4_4_ACT_MANAGEMENT_RESULT {"assertions":91,"display_server":"Windows","failed":0,"frames_drawn":6}`；真实 D3D12/Forward+ 显示后端运行并覆盖视频按钮状态。
- [x] 邻接回归：P3.3 玩家输出合同 `47/47`；P3.2 Windows 主界面/带团入口 `62/62`。
- [ ] GM 真人验收仍待执行：反复切换“废弃矿井/常用线索”等幕，确认切幕本身不改变投屏；回到同一幕重复投放同一内容仍可用；无地图幕正常显示和投放媒体/文字。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-21 | 首次文案修改把 `main.gd` 第 1042 行多缩进一层，Godot 报 `Expected statement, found Indent`。 | 已按错误行修正；随后 P4.4 无窗口 `77/77`、Windows `91/91` 通过。 |
| 2026-07-21 | 直接调用 `Godot_v4.7-stable_win64_console.exe` 在业务结果前触发既有原生 `signal 11`，并遗留两个本轮子进程。 | 已结束明确 PID；改用 Godot 主程序本体、隔离 `APPDATA/LOCALAPPDATA` 和日志文件后稳定完成全部回归；最终无残留 Godot 进程。 |
| 2026-07-21 | 测试启动时仍出现既有二进制夹具 NUL 字符警告。 | P4.4/P3.2/P3.3 均完成断言汇总且退出码 0；未把该既有扫描警告误报为本轮失败。 |

## 2026-07-21 Codex 正式模组与场景数据清理

- [x] 用户要求在不删除资产的前提下清空当前混乱的模组、幕、场景和带团数据；清理目标锁定为 `C:/Users/Admin/AppData/Roaming/Godot/app_userdata/Gvtt/modules`，不修改仓库源码与回归夹具。
- [x] 首次执行因检测到 Godot PID `51996` 正在运行而主动中止，未删除数据；用户关闭 Godot 并回复 `1` 后继续。
- [x] 清空正式 AppData 模组目录全部条目：删除 23 个 manifest/场景/带团快照文件，共 `1,562,683,052` 字节；清理后目录剩余条目为 0。
- [x] 资产复核：桌面 `Gvtt_P4_测试素材` 的 4 个图片/视频文件全部存在；仓库 `assets/`、`tests/fixtures/p3_4/motion_audio_320x180.ogv` 和 `modules/测试模组/_canonical/场景1.scn/场景2.scn` 均保留。
- [x] 清理完成后没有残留 Godot 进程；未启动 Godot，避免空目录被开发运行流程立即重新创建默认模组/地图。

## 2026-07-21 Codex Godot MCP 按需使用决策

- [x] 复核现有规则：`AGENTS.md` 已规定 MCP 断连排障、`game_eval` 缩进和 `batch_execute`，但没有说明哪些任务值得承担连接、端口、日志上下文和编辑器状态成本；因此近期“命令行启动过 Godot”和“用户看见编辑器被操作”被混为一谈。
- [x] 决策：MCP 作为 UI、场景树、输入、投屏、媒体和其他运行态任务的专用开发/验收通道，按需连接；文档、JSON、静态检查、普通文件操作和数据清理不为形式统一强制连接。
- [x] 证据边界：Godot 命令行自动回归不能替代 MCP 的 `game_eval`/场景树实证或 GM 真人体验；MCP 单次探查也不能替代可重复自动测试。MCP 不可用时允许继续文件实现，但相关可见功能不得宣布完整完成。
- [x] 落盘位置：在 `AGENTS.md` 新增“Godot AI 工具规范 -> MCP 按需使用边界”，在 `docs/module_workflow.md` 新增任务矩阵和推荐流程；不写入 `.agents/skills/`，因为这是 Gvtt 项目特定协作规则，不是跨项目 Godot 技能知识。
- [x] 本轮只修改项目流程文档和开发日志，没有修改功能代码、场景、测试或模组数据，也没有启动 Godot。

## 2026-07-21 Codex P4.4 MCP 恢复后自动复核

- [x] 当前对话已实际连接 Godot MCP（Godot 运行态接口）会话 `gvtt@6ddd`；编辑器版本为 `4.7-stable (official)`，当前项目为 `C:/Users/Admin/Desktop/Gvtt/`。这次证据来自运行态通道，不以插件文件存在或命令行测试代替连接状态。
- [x] 通过 `project_run(mode="custom")` 启动 `res://tests/p4_4_act_management_regressions.tscn`；运行态助手在线且启动无错误，测试自行退出并输出 `P4_4_ACT_MANAGEMENT_RESULT {"assertions":91,"display_server":"Windows","failed":0,"failures":[],"frames_drawn":6}`。
- [x] 测试后通过主入口重新启动项目并执行 `game_eval（游戏运行态求值）`：当前场景为 `res://scenes/module_home.tscn`，正式 `user://modules` 的 `module_names=[]`、`module_count=0`。这证明 P4.4 临时测试数据已自行清理，且此前清空的正式模组数据没有被启动流程重建。
- [x] 主入口停止后游戏日志只有运行态助手注册，无运行错误；编辑器日志没有解析错误或运行错误，但仍报告 5 条既有静态警告：`module_io.gd` 的 3 条枚举强制转换警告、`media_registry.gd` 的三元表达式类型警告、`module_gate.gd` 的变量遮蔽警告。本轮不改动这些与 P4.4 自动复核无关的源码。
- [x] 现在可自动确认：玩家窗口树隔离、按钮多状态规则、错误信息不泄漏到玩家侧、幕切换不改变玩家输出、同幕内容重复投放、无地图幕、Windows 实际绘制和测试数据清理。仍不能由自动化替代：布局是否直观、拖拽手感、声音与视频主观质量、真实双屏桌边操作效率；这些保留为 GM 真人体验验收，不再要求用户手工确认可由上述断言和 `game_eval` 客观证明的部分。

## 2026-07-21 Codex P4.4 验收责任边界纠正

- [x] 用户指出此前给出的“真人完整点击清单”包含大量可以由自动测试和 MCP 自动确认的项目；该判断成立。此前开发日志中的 P4.4“完整点击待执行”记录是当时状态，现由本节与最新 MCP 证据取代，不再作为未完成门槛。
- [x] `docs/roadmap.md` 已将 P4.4 客观流程验收标为完成：幕增删改排、搜索、持久化、切幕不改投屏、重复投放、无地图幕、图片/文字/视频控制、权限与玩家窗口隔离均由自动证据负责，不要求 GM 重复验证。
- [x] GM 只需在真实使用中反馈程序无法替代判断的主观体验：布局是否容易理解、拖拽是否顺手、声音与视频观感、真实双屏桌边效率。这些反馈不阻塞 P4.4 程序完成状态；发现问题时按新的体验优化或 bug（程序缺陷）处理。
## 2026-07-21 Codex 带团入口调整与 P4.5 回归验收

### 本轮完成

- [x] 按 GM 的两态模型调整入口：编辑态左栏只保留备团内容；点击顶栏“开始”后打开“开始带团”窗口，在窗口内列出已有记录、进入指定桌或新增一桌。没有修改“一份模组底本、多份独立桌记录”的数据模型。
- [x] 保留 `PlaythroughController`、`ModuleIo` 的加载、每地点快照、自动保存、返回编辑态和退出程序保存顺序；“测试”仍只使用内存快照，不创建带团记录。
- [x] `scripts/main.gd` 使用 `AcceptDialog`、`ScrollContainer` 和 `VBoxContainer` 构建启动窗口；记录行继续显示损坏状态并禁用进入，新增桌继续复用原命名对话框。
- [x] 修复实测的 Godot 独占子窗口问题：关闭启动窗口前先 `hide()`，再 `queue_free()`；首次可见回归暴露该问题后，重跑无窗口独占错误。
- [x] 更新 `docs/design.md`、`docs/module_workflow.md`、`docs/p3_playthrough_contract.md`、`docs/roadmap.md`，统一写成“开始窗口选桌”，移除现行文档中的“左栏直接选桌”表述；历史日志保留原样。

### 四层调研回执与源码对照

- [x] 项目现状：`main.gd` 原先在编辑左栏创建 `_playthrough_section`，多桌时“开始”提示 GM 去左栏；当前数据层已经是一个 `ModuleManifest` 对应多份 `Playthrough`，问题是入口职责而不是版本数据。现改为 `_on_mode_btn_pressed()` -> `_show_playthrough_dialog()`，记录行仍调用 `_continue_playthrough()`，新增桌仍调用 `_start_new_playthrough()`。
- [x] Godot 源码：锁定 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。Godot 的 `EditorRunBar::play_main_scene()` -> `stop_playing()` -> `_run_scene()` -> `EditorRun::run()` 在运行入口决定运行上下文并创建独立实例，`EditorRun::stop()` 负责释放运行实例；Gvtt 是单程序双状态，不能照搬进程创建，只采用“运行入口选择上下文、编辑区不管理存档”的职责边界。
- [x] 官方资料：离线 Godot 4.7 `AcceptDialog` 确认对话框、确认/取消信号和 `popup_centered()`；`ScrollContainer` 确认内容超出时滚动；`File paths in Godot projects` 与 `Saving games` 确认项目资源和运行存档应分开。本轮没有引入旧版 UI 属性或新的存档协议。
- [x] 英文社区/开源：Foundry VTT 的 `Game Worlds` 与 `Adventure Documents` 将可复用内容包和实际游戏世界分开；Tabletop Club `v0.1.4` 只作为 Godot 开源旁证，不照搬其界面。采用的是职责分离思路，不安装插件、不改变 Gvtt 的单 exe 约束。

### 自动测试与 Windows 可见窗口

- [x] Godot 4.7 隔离导入：退出码 0；日志 `build/p45_acceptance/import/godot.log`。
- [x] P1：`P1_RUNTIME_RESULT {"assertions":358,"failed":0}`；日志 `build/p45_acceptance/p1_runtime/godot.log`。
- [x] P2.4：`56/56`；P2.5 Windows：`54/54`；P2.6：`64/64`；日志分别在 `build/p45_acceptance/p2_4/`、`p2_5/`、`p2_6/`。
- [x] P2 指标 Windows：`P2_ACCEPTANCE_METRICS {"assertions":20,"failed":0}`，双窗口平均约 `688.7 FPS`，四次切场景可见耗时约 `11.7–231.3 ms`；该测试历史标记名不是 `_RESULT`，组包装器的“结果缺失”是命名误判，不是业务测试失败。日志 `build/p45_acceptance/p2_metrics/godot.log`。
- [x] P3.1：`79/79`；P3.2 数据层/控制器：`39/39`、`39/39`；P3.2 Windows 可见入口：`66/66`、`WINDOW_OBSERVED=True`；P3.3：`47/47`。日志分别在 `build/p45_acceptance/p3_1/`、`p3_2_data/`、`p3_2_controller/`、`p3_2_visible_retry/`、`p3_3/`。
- [x] P3.4 生命周期：`64/64`；P3.4 Windows 媒体冒烟：`133/133`，真实绘制 `12395` 帧、音频峰值约 `-35.87 dB`、视频时长 `9.0333 s`；日志在 `build/p45_acceptance/p3_4_lifecycle/`、`p3_4_smoke/`。
- [x] P4.1 媒体登记：无窗口 `43/43`；Windows 可见补跑 `43/43`、`WINDOW_OBSERVED=True`。覆盖可播放、缺失、损坏、暂不支持、重命名、删除登记和媒体字节不进入场景/清单。日志在 `build/p45_acceptance/p4_1/`、`p4_1_visible/`。
- [x] P4.2 图片演出 Windows：`58/58`，真实绘制 `493` 帧；覆盖比例/黑边、淡入淡出、缺失/损坏失败回地图、十轮释放。日志 `build/p45_acceptance/p4_2/godot.log`。
- [x] P4.3 视频演出 Windows：`146/146`，真实绘制 `9122` 帧，暂停位置差 `0.0`，音频峰值约 `-37.13 dB`；覆盖播放、暂停/恢复、停止、自然结束、十轮快速切换、切场景、关闭投屏窗口、音频静音和播放器释放。日志 `build/p45_acceptance/p4_3/godot.log`。
- [x] P4.4 UI/投屏隔离：无窗口 `77/77`；Windows 可见 `91/91`；覆盖缺失引用、编辑/运行权限、玩家窗口无 GM 控件/路径/错误泄漏、视频按钮状态和返回地图。日志在 `build/p45_acceptance/p4_4_headless/`、`p4_4/`。
- [x] P4 完整闭环证据由三组互补测试组成：P3.4 媒体冒烟证明“地图 -> 图片 -> 视频 -> 返回地图”；P4.2 证明图片演出失败回地图和释放；P4.3 证明视频暂停/恢复、停止回地图和异常清理。没有新增平行播放器或存档协议。

### 源码行为 -> 本地实现 -> 验证映射

| Godot/官方行为 | Gvtt 本地实现 | 自动/运行验证 |
|---|---|---|
| 运行入口决定运行上下文，运行实例与编辑器职责分离 | `_on_mode_btn_pressed()` 只打开“开始带团”窗口；`PlaythroughController` 进入运行态 | P3.2 可见 `66/66`，编辑态无记录区，开始窗口列出两桌 |
| `AcceptDialog` 通过确认/取消信号关闭 | `_show_playthrough_dialog()`、`_close_playthrough_dialog()`；关闭前隐藏再释放 | 首次窗口独占错误已修复；重跑无错误 |
| 运行状态由应用自行选择持久字段和存档位置 | 模组底本写 `_canonical`，带团写 `sessions/<session_id>`，测试不写盘 | P3.2 数据层/控制器各 `39/39`，P4.1 字节边界 `43/43` |
| 媒体播放器停止后需要释放后端、音频和窗口 | `PlayerOutputController` 统一路由，P4.2/P4.3/P4.4 统一清理 | P4.3 `146/146`、P4.4 `91/91`，暂停位置差 `0.0`、窗口/音频无残留 |

### 未做与原因

- [x] 未做模组版本管理、模组复制或逐对象差异存档；这与 GM 已确认的“一份最佳模组底本、多份桌记录”模型冲突，当前只保留必要的可恢复写入和地点快照。
- [x] 未安装 Godot VLC/FFmpeg，也未扩大 MP4 等格式支持；本轮是回归验收，不改变 P4.1-P4.4 的格式边界。
- [ ] 当前对话没有暴露 Godot MCP 的 `game_eval`、场景树和日志运行态入口；本轮已完成命令行自动回归和 Windows 原生可见窗口，但仍需恢复 MCP 后补一次运行态求值，不能把命令行结果冒充 MCP 证据。

### 问题状态

| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-21 | 首次 P3.2 可见回归在业务 `66/66` 通过后暴露启动窗口与新增桌对话框同时独占。 | 已修复：启动窗口关闭前先 `hide()`；`p3_2_visible_retry` `66/66`，无独占错误。首次日志保留在 `build/p45_acceptance/p3_2_visible/godot.log` 作为排障证据。 |
| 2026-07-21 | P2 指标测试没有使用 `_RESULT` 后缀，自动分组脚本误报 `RESULT_MISSING`。 | 测试本身 `assertions=20, failed=0`；不改历史测试协议，本轮报告实际标记名。 |
| 2026-07-21 | MCP 运行态通道未暴露。 | 待恢复后补 `game_eval`/场景树实证；不影响本轮自动测试和 Windows 可见窗口结果，但阻止宣称 MCP 级完整验收。 |
## 2026-07-22 P4.5 acceptance audit addendum

- [x] The formal P4 core remains complete under the native OGV boundary: map -> image -> video -> pause/resume -> map, media cleanup, window isolation, and the P1/P2/P3 regression evidence all report `failed: 0`.
- [x] Regression evidence checked in `build/p45_acceptance/`: P1 `358/358`; P2.4 `56/56`; P2.5 `54/54`; P2.6 `64/64`; P2 metrics `20/20`; P3.1 `79/79`; P3.2 data/controller/visible `39/39`, `39/39`, `66/66`; P3.3 `47/47`; P3.4 lifecycle/visible `64/64`, `133/133`; P4.1 `43/43`; P4.2 `58/58`; P4.3 `146/146`; P4.4 headless/Windows `77/77`, `91/91`.
- [x] Godot VLC isolation evidence: class probe `P4_5_VLC_CLASS_PROBE failed:0`; direct playback `15/15`; editor Gvtt integration `23/23`; release DLL class probe found both VLC classes under Godot `4.7-stable` commit `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`.
- [ ] VLC is not promoted to formal product support. The Windows exported runtime in `build/p45_acceptance/vlc_export/` failed `14/23`; no `Initialize godot-rust` line appeared, and the runtime did not enter VLC playback. A minimal release-DLL probe also exited with a native access violation during shutdown. Therefore MP4/MOV/WebM/MKV/AVI remain unsupported in the formal boundary and OGV remains the fallback.
- [ ] Windows visible VLC acceptance is not passed. The existing OGV Windows visible evidence is valid; it cannot substitute for the VLC export and cleanup gate. A fresh export attempt was additionally blocked by the local Godot export-template/AppData environment, so no new pass result is claimed.
- [x] Source-to-implementation mapping recorded for this audit: Godot 4.7 `core/extension/gdextension_manager.cpp` (`load_extension`, `load_extensions`), `core/extension/gdextension_library_loader.cpp` (library/dependency resolution), `editor/export/gdextension_export_plugin.h` (forced shared-object export), `platform/windows/os_windows.cpp` (`open_dynamic_library` executable-directory fallback), and offline documentation `gdd_0448_The_.gdextension_file.md` (dependency export layout). Local experimental files are `addons/godot-vlc/`, `scripts/vlc_playback_backend.gd`, `scripts/media_registry.gd`, and `tests/p4_5_vlc_*`.
- [x] This addendum is the current P4.5 status: core acceptance complete, VLC extension gate open. Do not check the roadmap VLC item or announce common-format support until exported Windows initialization, visible playback, cleanup, and license packaging are independently rerun and pass.

### Common-format backend decision

- [x] VLC is not required by the P4 media workflow. It is only one candidate backend for direct MP4/MOV/WebM/MKV/AVI playback; the proven OGV backend already completes the P4 presentation and cleanup contract.
- [x] Godot 4.7 documentation and source confirm that core video support is Ogg Theora and other formats require a GDExtension or conversion. The hard part is not the play command: it is shipping codecs, feeding decoded frames into Godot textures, routing audio, supporting the second native window, and cleaning native threads/resources during switch, close, and exit.
- [x] Current Godot VLC payload contains 403 Windows files and about 231.5 MiB. Upstream Godot VLC supports Godot 4.3+ on Windows/Linux but the Gvtt export and shutdown gate failed. EIRTeam.FFmpeg is another GDExtension but its upstream build and H.264 patent notes make it no simpler for this Windows single-exe target. GoZen proves full FFmpeg playback is possible in Godot, but it is an Alpha GPLv3 video editor rather than a reusable small player plugin.
- [x] Decision: do not make VLC synonymous with P4 completion. Keep common-format playback as a separate backend task; compare a repaired VLC export, a validated FFmpeg backend, and an import-time conversion workflow before changing formal format support.

### Native Windows backend research correction

- [x] Corrected the previous candidate search: limiting the comparison to VLC/FFmpeg missed `claytercek/godot-native-video`, released as v0.2.1 on 2026-07-11. Its release archive is 4.66 MB, MIT licensed, targets Godot 4.4+, and uses Windows Media Foundation / macOS AVFoundation instead of bundling codec libraries.
- [x] The upstream contract matches the Gvtt need more closely than VLC: MP4/MOV/M4V containers, H.264/HEVC video, AAC audio, `VideoStreamPlayer` compatibility, Windows D3D12 support, hardware decoding, and no runtime FFmpeg dependency. Microsoft documentation confirms the Windows Media Foundation H.264 decoder and hardware-acceleration interface.
- [ ] This plugin is very new (4 GitHub stars, three releases at research time) and has not passed Gvtt's Godot 4.7, dual-window, Media bus, export, rapid-switch, close, and shutdown tests. It is now the first candidate for a separate isolation experiment, not formal support yet.
- [x] Process correction: the earlier statement that no lighter alternative was available was unsupported because the search scope was too narrow. Future common-format research must include OS-native decoder bridges before full bundled decoder stacks.

## 2026-07-22 Native Video v0.2.1 隔离实验与 P4.5 收口

### 调研与源码对照
- [x] 项目现状：正式 P4 播放链为 `MediaRegistry -> PlayerOutputController -> VideoOutputPresenter -> VideoPlaybackBackend`；OGV 后端已通过媒体登记、图片/视频演出、暂停/恢复、返回地图、快速切换、切场景、关投屏和音频清理。VLC 只是失败实验，不是 P4 完成依赖。
- [x] Godot 源码：锁定 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`VideoStreamPlayer::set_stream()` 先 `stop()`，再 `instantiate_playback()`；`play()` 启动内部处理，`_notification()` 驱动 playback `update()` 和音频混合；清空 stream 释放 playback。源码快照位于 `build/p45_acceptance/godot_video_source/`。
- [x] 官方资料：离线 Godot 4.7 `Playing videos`、`VideoStreamPlayer`、`VideoStream`、`VideoStreamPlayback`、`ResourceLoader` 说明核心原生格式为 Ogg Theora，GDExtension 可增加格式；绝对运行时路径会经 `ProjectSettings.localize_path()` 处理。
- [x] 社区方案：核对 `claytercek/godot-native-video v0.2.1 / d5491b8484ce36cdb19d01bce79054c96dd52f7d`。发行 ZIP `4,888,596` 字节，SHA-256 `a9f4b4a0327e8e6eb1f1cd494ed54397534b4f082a8bcdba0ff034197c1b3d5d`，MIT；Windows 使用 Media Foundation，支持 MP4/MOV/M4V、H.264/HEVC 和 AAC，不捆绑 VLC/FFmpeg。
- [x] 插件源码链：`NativeVideoResourceFormatLoader` 创建 `NativeVideoStream`；`_instantiate_playback()` 创建并加载 `NativeVideoStreamPlayback`；`PlaybackController::tick()` 驱动解码/音频；`PresentPipeline::present()` 生成 Godot 纹理；析构声明先 `controller_.shutdown()` 等待解码任务，再 `present_.shutdown()` 释放纹理。源码位于 `build/p45_acceptance/godot_native_video_source/`。

### 隔离结果
- [x] 插件发行包指纹匹配；Godot 4.7 成功注册 `NativeVideoStream` 与 `NativeVideoStreamPlayback`。真实 H.264/AAC MP4 成功打开并报告 `466.603 s`，损坏 MP4 安全返回 `0.0 s`；结构化探针 `8/8` 通过。
- [ ] Native Video 未通过退出清理门禁。清除 VLC 扩展与缓存后，官方 `ResourceLoader` 路径和直接类实例化路径均复现：探针打印 `failed:0` 并调用退出后，Godot 进程 30 秒内不结束；连续四次留下 PID `22004/4944/3620/28788`，普通 `Stop-Process`/`taskkill` 无效，最终通过 Win32 CIM `Terminate` 返回值 `0` 清除。
- [x] 失败证据位于 `build/p45_acceptance/native_video_probe3/` 至 `native_video_probe6/`；插件、适配器和探针归档到 `native_video_rejected_addon/`、`native_video_rejected_integration/`。VLC 插件和实验脚本归档到 `vlc_rejected_addon/`、`vlc_rejected_integration/`。
- [x] 正式项目已移除两种候选：`addons/`、`scripts/`、`tests/`、`.godot/extension_list.cfg` 和导出预设均不再加载 VLC/Native Video；`PlayerOutputController` 只为 `.ogv` 创建 `NativeOgvPlaybackBackend`，其他视频登记为“暂不支持”。主界面提示改为“当前正式支持 OGV”。

### 行为映射与阶段结论
| 源码/候选行为 | 本地实验 | 自动/运行验证 |
|---|---|---|
| Godot `set_stream -> instantiate_playback -> update/mix -> stop` | Native Video 适配器复用标准 `VideoStreamPlayer` | 真实 MP4 时长 `466.603 s`、损坏文件 `0.0 s`、8/8 |
| 插件解码调度器与呈现管线声明按序 shutdown | 清空 stream、释放播放器、延迟两帧后退出 | 连续四次 30 秒不退出并残留原生进程，门禁失败 |
| Gvtt 正式后端必须在切换、关窗、退出时无残留 | 候选失败后回退到 OGV-only 路由 | 既有 P4.1 `43/43`、P4.2 `58/58`、P4.3 `146/146`、P4.4 `91/91` 仍为正式证据 |
- [x] P4 核心阶段按 OGV 产品边界完成；地图 -> 图片 -> MV -> 暂停/恢复 -> 返回地图及异常清理均已有 Windows 可见证据。常见格式后端从 P4 完成条件中拆出，MP4 支持未交付、未宣称完成。
- [x] 候选归档后的最终复跑：P4.1 媒体登记 `43/43`；P4.3 Windows 可见视频 `146/146`、`frames_drawn=31046`、`pause_position_delta=0.0`；P4.4 Windows 可见 UI/投屏隔离 `91/91`；测试后 `Win32_Process` 查询无 Godot 进程残留。
- [ ] 当前对话未暴露 Godot MCP 运行态工具；本轮 Native Video 证据来自隔离命令行进程与 Windows 进程审计，未冒充 `game_eval` 或 GM 真人双屏体验。

### 问题状态
| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-22 | Native Video v0.2.1 能打开真实 MP4，但 Godot 4.7 Windows 探针退出后残留原生进程。 | 候选否决并归档；正式产品回到 OGV-only，待上游修复或新后端。 |
| 2026-07-22 | 旧 `.godot` 缓存仍指向已移出的 VLC 扩展。 | 已重建缓存并确认 VLC 引用为 0；最终扩展清单清空。 |
## 2026-07-22 Codex P5 Token、地形移动与射击接口定案前复核

### 四层调研回执
- [x] 项目现状：`TokenProperties` 已有碰撞与显示属性，`CprTokenProperties` 目前只有 `move_stat`；Token 实例保存在当前地点的 `ContentRoot`，幕只是可反复使用的内容资料夹，不能可靠地按幕自动抓取参战者。`TraversalProperties` 已有可走、阻挡、困难、攀爬、跳跃和游泳六种语义；`CombatLinePreview/CombatLineQuery` 已有射线和二元遮挡结果。
- [x] CPR 规则：`docs/cpr_reading/combat_quick_reference.md` 及其原书页码核对确认先攻为 `REF + 1D10`，原版同值重掷；游泳、攀爬、助跑跳每前进 1 米消耗 2 米预算，立定跳距离为助跑跳的一半。用户要求的“同值玩家优先”只能标为 Gvtt/本团简化规则，不能冒充 CPR 原规则。
- [x] Godot 源码：锁定 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。`NavigationLink3D::_link_enter_navigation_map()`登记链接起终点及成本，`GodotNavigationServer3D::query_path()`进入 `NavMeshQueries3D::map_query_path()`；结果用 `path_types/path_rids` 标记链接段。项目当前已给攀爬/跳跃链接设置 `travel_cost`，但困难/游泳区域主要在查询后按中点贴标签并计费，尚不能保证选出移动预算成本最低的路线。
- [x] 官方资料：Godot 4.7 离线 `gdd_0666_NavigationLink3D.md`、`gdd_0670_NavigationRegion3D.md`确认链接和区域的 `travel_cost` 都以距离乘数参与最短路；`gdd_1339_NavigationPathQueryResult3D.md`确认可识别链接段。D&D Beyond 2024 基础规则确认 DND 远程攻击仍对抗 AC（护甲等级），距离通常决定正常、劣势或超距，不能复用 CPR 的“距离直接返回 DV”合同。
- [x] 英文社区：Foundry 现行 Combat Tracker（战斗追踪器）支持 Roll All（一键掷全部先攻）和手动改值，证明二者并存是成熟轻量交互；Godot 社区的区域成本实践提示重叠导航区域和启发式选路存在可靠性风险，实施时必须用“昂贵水域与较远桥梁”的专项路线测试验证，不能只看路径能否生成。

### 本轮设计结论
- [x] 自动参战推荐按当前地点 Token 的持久属性收集，不要求运行时选中：通用 `TokenProperties` 增加 `combat_side` 与 `auto_join_combat`；CPR 数据增加 `ref_stat`，沿用 `move_stat`。不在 P5 建完整角色卡。
- [x] 一键先攻使用 `ref_stat + 1D10`，保留手动填写/修改总值，不提供单 Token 重投。跨阵营同值按用户要求玩家优先；该规则明确标为 Gvtt/本团简化规则，同阵营同值保持预先收集顺序并允许 GM 手改。
- [x] P5 应先补最小 Token 战斗属性，再完善地形加权择路；否则回合移动只能对几何最短路事后收费，无法实现“点击目的地后自动选择走、游、攀、跳”。跳跃/攀爬表现由项目路径跟随器负责，Godot 导航只给路线与链接元数据。
- [x] 射击提示接口现在定，CPR 实现在同一 P5 落地：通用返回距离、射程区间、是否超距、可选目标数值、掷骰状态和说明；CPR 填 DV，DND 以后填正常/劣势/不可攻击及对抗 AC 提示。不重写现有战斗射线，不自动判命中。
- [x] 推荐开发顺序：P5A 最小 Token 战斗属性与自动收集；P5B 地形语义与加权自动择路；P5C 一键/手动先攻和轻量队列；P5D 通用远程提示接口与 CPR DV；P5E 当前角色、下一位和退出战斗模式。
- [x] 本轮未修改 `docs/p5_plan.md`、功能代码、场景或测试；待设计范围确认后再重写正式计划并进入实现。
## 2026-07-22 Codex P5 十属性定案、完整五阶段计划与研究任务创建

### 阶段结论
- [x] 接受用户纠正：既然 P5 已进入 CPR Token（《赛博朋克 RED》标记）属性底座，就一次定义十项主属性稳定变量，避免以后为技能、移动、死亡豁免等用途反复迁移；但只保存基础数值和读取接口，不扩成完整角色卡。
- [x] 十项字段固定为 `int_stat/ref_stat/dex_stat/tech_stat/cool_stat/will_stat/luck_stat/move_stat/body_stat/emp_stat`；沿用现有 `move_stat`，不建立第二套同义真值。
- [x] 通用 Token 参战字段固定为 `combat_side` 与 `auto_join_combat`；开始战斗扫描当前地点 `ContentRoot`，不按幕抓取、不要求逐个选中。
- [x] 批量 `REF + 1D10` 先攻记录为用户批准的窄例外；不建设通用骰子系统，不提供单 Token 重投。玩家优先平手必须标为 Gvtt/本团简化规则，不能冒充 CPR 原版。
- [x] 已重写 `docs/p5_plan.md` 为 P5.1-P5.5 完整计划，并同步 `docs/roadmap.md`、`docs/design.md`和 `docs/README.md`；旧的逐个选中、手动先攻为主、上一位、动作记录、战斗恢复和稳定 ID 前置不再是 P5 真值。

### 四层调研回执与现成资源结论
- [x] 项目现状：唯一 CPR 属性组件是 `CprTokenProperties`，目前只有 `move_stat`；`PlacementController::_attach_ruleset_token_properties()`已负责自动挂载和 owner（归属），`main.gd` 已有 MOVE 属性面板回写，地点保存/加载已有打包、实例化和旧实体迁移。直接扩展现有组件即可，不需要新建第二套角色资源。
- [x] CPR 原文：核心规则书 PDF p.90-97（书内 p.72-79）确认十项主属性和顺序为 INT、REF、DEX、TECH、COOL、WILL、LUCK、MOVE、BODY、EMP；战斗速查及 PDF p.144-145、186-187确认先攻为 `REF + 1D10`且原版同值重掷。
- [x] Godot 源码：锁定 `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`。对照 `scene/main/node.cpp::Node::set_owner()`、`scene/resources/packed_scene.cpp::PackedScene::pack/SceneState::pack/instantiate()`和 `core/io/resource.cpp::Resource::duplicate/resource_local_to_scene`；现有 Node 属性组件随地点场景保存最贴合项目，不引入默认共享的可变 Resource 真值。
- [x] 官方资料：Godot 4.7 自定义 Resource 支持导出字段和 Inspector（检查器）编辑，但共享引用需要唯一化；项目已经有自定义运行时属性面板和 Node 保存链，改用 Resource 不会减少工作，反而增加共享/复制和迁移风险。
- [x] 英文社区/开源：Foundry CPR 仍维护并使用十属性与 `stats.ref`式稳定路径，可借鉴数据分层和迁移；其许可证为 GPL-3.0-only 且依赖 Foundry Actor，不能原样复用。Magnus Laser 为 MIT 的 Tauri/网页工具，只参考离线 GM 工具边界。当前工程插件与 Godot 社区均未发现可直接安装、同时兼容 Godot 4.7/GDScript/单机 GM 边界的 CPR 属性或战斗插件。
- [x] 采用：现有 `CprTokenProperties`、`TokenProperties`、挂载/迁移/属性面板、`MovementService`、`TraversalProperties`、`CombatLinePreview/Query`和社区成熟交互模式。不采用：外部完整规则系统代码、新 Inspector 插件、第二套角色资源和完整角色卡。

### 五个 Codex 研究任务
- [x] `P5.1 十属性与自动参战`：`019f89b6-de6d-7bf0-9808-87d025f1aa07`。
- [x] `P5.2 地形加权自动移动`：`019f89b6-f7db-7480-a732-3eb966e430c3`。
- [x] `P5.3 一键先攻与轻量队列`：`019f89b7-0fe0-7872-bbc1-b4af5be6bea9`。
- [x] `P5.4 远程攻击提示与CPR DV`：`019f89b7-29c1-7c03-9169-d39dfcc4ee15`。
- [x] `P5.5 回合移动整合与退出`：`019f89b7-4251-73b2-8a58-5d7a3bba8df0`。
- [x] 五个任务第一轮均明确只做四层调研、源码对照、现成资源核查、步骤与验收设计，禁止改功能代码；前置未完成时只提交研究。用户之后在对应任务明确继续（包括回复 `1`）才复查依赖并实施。
- [x] 即时状态快照确认五个任务均在读取指令/技能和调研；P5.2、P5.5 已主动识别前置依赖未完成，没有抢跑代码。

### 验证与未做
- [x] `git diff --check` 通过；规划中的字段、阶段、窄例外和研究优先约束已用 `rg` 交叉核对。
- [ ] P5 功能代码、场景、自动测试、Godot MCP（运行态接口）和 Windows 可见验收均未开始；本轮按用户要求只完成调研、规划和任务创建。

| 日期 | 问题 | 状态 |
|---|---|---|
| 2026-07-22 | 项目总边界“不做骰子/规则系统”与用户要求一键先攻存在表面冲突。 | 已收紧为唯一窄例外：只批量执行 CPR `REF + 1D10`，不提供通用骰子、技能检定、命中或伤害。 |
| 2026-07-22 | Foundry CPR 有成熟十属性/战斗数据，但运行时与许可证不允许无风险原样搬入。 | 只借鉴字段路径、分层和迁移，不复制代码或引入 Foundry 运行时。 |

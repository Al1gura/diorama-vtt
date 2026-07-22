# Gvtt → Codex 交接文档（2026-07-15）

> 从 Claude Code 迁移到 Codex。此文档给新的 AI 助手（Codex）在第一次打开项目时读，让新对话能无缝接上。

---

## 一、你在哪

项目路径：`C:\Users\Admin\Desktop\GVTT`（已从 `C:\Users\Admin\Claude\Projects\Gvtt` 迁移）

**当前进度（2026-07-18）：P2.0-P2.6 基础版均已落地；剩余 P2 工作主要是 GM 可见窗口最终体感确认。文档入口和资产清单已收口，真实素材暂不移动。**

### 已完成功能
- [x] P0：正交相机 + 网格地面 + 光源 + 阴影 + 天空照明（main.tscn + main.gd）
- [x] P1：编辑↔运行切换（ModeGate autoload）
- [x] P1：地面纹理替换（子文件夹结构、PBR 多图分类导入）
- [x] P1：地面纹理平铺控制 UI
- [x] P1：物件系统（仓库→拖放，6 分类栏位：场景/Token/地形/地面纹理/墙体/装饰/交互物体/光源）
- [x] P1：物件属性标记 schema（EntityProperties + PickProxy 拾取代理 + GvttRenderLayers）
- [x] P1：Gizmo3D 运行时手柄（选中→移动/旋转/缩放）
- [x] P1：运行态自由视角相机（子模式 MAP/ORBIT + 球坐标四量 + saved 视角权威）
- [x] P1：右键删除素材（自导入素材可删，自带素材只读提示）
- [x] P1：Post-import 中心化（清模型自带位置，解决了保存后模型偏移的顽固 bug）
- [x] P1：场景保存/加载（存→读→切场景换树→纹理随场景存→脏标记→默认空场景 全闭环）
- [x] P1：场景宽×高长方形地面改造（默认 100×100，可改 5-500）
- [x] P1：默认贴图铺满模式（UV 检测图 4096² 一张铺满整个地面，拉伸不重复）
- [x] P1：网格几何体重构（PlaneMesh+shader → SurfaceTool 几何体网格线，三级：辅线/主线/XZ 轴线）
- [x] P1：投屏窗口（CastView，独立 OS 窗口，共享 World3D，embed_subwindows=false）
- [x] P2.0：对象类型系统（EntityProperties + Token/墙体/光源/交互物体专属组件）
- [x] P2.1：运行态选择 + GM 只读操作面板基础版
- [x] P2.2：CPR Token 移动基础版（MOVE 预算、路线预览、绕障、超距截停、体型导航、运行/编辑位置隔离）
- [x] P2.3：光源开关基础版（运行态按钮切换 LightProperties.is_on，编辑态可调颜色/亮度/范围/阴影，状态保存读回）
- [x] P2.4：战斗层 CombatBody + 挡枪线接口基础版（独立第 21 层、单条 3D 挡线查询、GM 主窗口预览，不做命中/骰子/伤害）
- [x] P2.5：LOS 视线遮挡基础版（Token 自动视点、墙体地面遮挡轮廓、主窗口/投屏暗区）
- [x] P2.6：墙体破坏最小闭环（破坏/修复、LOS/挡枪线同步、保存读回重建）

### 正在做的 / 待确认
- [ ] GM 可见窗口最终确认：P2.1 选择面板、P2.3 光源投屏同步、P2.4 瞄准线、P2.5 墙后暗区、P2.6 破坏/保存读回体感。
- [ ] 编辑器脏缓存旧报错 4 条（实跑正常，待重启 Godot 编辑器清）。
- [ ] 非 P2 技术债：shader 网格 `world_line 0.04 → 0.15` 可让近粗远细更明显，尚未改。
- [x] P2 文档与资产清单收口：最新入口见 `docs/README.md`，阶段口径以 `docs/design.md`、`docs/p2_task_schedule.md`、`docs/asset_inventory.md` 和最新 `devlog/DEVLOG.md` 为准。
- [ ] 资产物理整理暂缓：`个人资产/` 被 CPR 资料索引引用，`2K_Gravel01/` 尚未决定是否纳入内置地面纹理。

### 后置 / 增强
- [ ] P2 收口闸门：自动回归、文档统一和性能基线已完成；只剩 GM 可见窗口操作与体感接受。
- [ ] P3：最小可持续底座（应用装配、模组清单真实持久化、稳定标识与迁移、最小带团会话、三层状态、外部内容引用、玩家输出/清理合同和测试夹具）。
- [ ] P4：媒体演出闭环（图片/MV 登记与播放、地图/媒体切换、常见格式后端实验和异常清理）。
- [ ] P5：三维演出闭环（场景气氛、环境预设和一次性法术特效）。
- [ ] P6：备团与内容管理闭环（场景管理、完整媒体库、演出绑定和色块布局）。
- [ ] P7：高级视野闭环（多 Token、阵营、光暗/烟雾、探索记忆、深度遮罩和性能索引）。
- [ ] P8：完整冒险闭环（地图楼层、完整带团状态、长期迷雾和演出引用恢复；基础多场景已接入）。
- [ ] P9：第一版发布闭环（性能、稳定性、数据安全、Windows 单目录便携包和完整用户验收）。
- [x] 详细顺序、依赖和完成标准已迁到 `docs/roadmap.md`，不再用旧阶段大桶判断进度。

---

## 二、项目是什么

**Gvtt** = 用 Godot 4.7 引擎做的跑团 GM（游戏主持人）桌面工具——开源 3D 俯视交互地图引擎。

- **目标用户：** 线下跑团的 GM，使用 Windows 单目录便携应用一人操作，投屏给全桌看
- **许可证：** MIT
- **明确不做：** 联网同步、骰子系统、规则系统、模组市场、玩家端、账号
- **设计理念：** 5 维度（场景呈现① → 场景因果② → 模组管理③ → 交互逻辑④ → 准备成本⑤），见 `docs/design.md`

---

## 三、谁在用这个项目

- **用户（你对话的人）：** 无编程背景的 GM 用户
- **协作风格：** 用口语化表达，英文术语必须加括号写中文翻译
- **忌讳：** 沉默操作、不查询就编造、从零写方案不搜索现成、不问就改
- **核心规矩：** 见项目根目录 `AGENTS.md`；`.claude/CLAUDE.md` 只作为历史迁移资料参考。

---

## 四、关键技术栈

| 组件 | 版本 | 用途 |
|------|------|------|
| **Godot** | 4.7-stable | 引擎，渲染器 Forward Plus |
| **物理引擎** | Jolt Physics | 3D 物理 |
| **Godot AI MCP** | v3.0.3 | AI↔Godot 的桥梁（MCP 协议 HTTP，端口 8000） |
| **Gizmo3D** | v1.0.0 | 运行时手柄插件（已修三角化退化 bug） |
| **GdUnit4** | v6.2.0-rc2 | 测试框架（尚未启用项目测试） |
| **gdstyle** | v0.2.3 | GDScript 代码风格检查编辑器插件；当前未发现 CLI 可执行文件 |
| **离线文档** | Godot 4.7 Dooc | 1593 文件，15MB，在 `reference/Godot 4.7 Dooc/` |

---

## 五、核心架构

### 5.1 编辑态 ↔ 运行态两态系统

**ModeGate** (`scripts/mode_gate.gd`，注册为 autoload)：
- `AppMode.EDIT` / `AppMode.RUN` 两档权限
- `mode_changed` 信号 → 各功能自报归属
- 四个分派函数：`_apply_topbar / _apply_panel / _apply_camera / _apply_gizmo`
- 运行态 Token 移动是临时演示状态：进入运行态时 `main.gd` 记录 Token 编辑态变换，回编辑态或切场景前恢复；运行态拖动不标记场景未保存。编辑态移动并保存仍是底稿持久化入口。

**相机子模式（EditSubMode）**：
- `MAP`（正交俯视） / `ORBIT`（透视自由视角）
- 球坐标四量：`yaw / pitch / dist / focus`
- `_saved_orbit_*` = 游玩视角权威（编辑态才能保存，运行态只能恢复）

### 5.2 投屏窗口（CastView）

- `scripts/cast_view.gd`，旁路于 ModeGate，独立原生 Window
- `world_3d = get_viewport().world_3d` 显式共享同一世界
- `embed_subwindows=false`（全局设置，所有 Window 都变独立 OS 窗）
- `_low_quality` 降画质开关（默认关）

### 5.3 多场景系统（基础版已接入）

多场景的基础编辑闭环已经接入：左栏场景列表、新建、切换、保存/读回、未保存提醒、默认空场景和旧对象迁移由 `SceneSessionController` 协调，`ModuleGate` 继续持有模组/地点真值，`ModuleIo` 继续负责 `PackedScene` 存读盘和 owner 陷阱处理。

当前 `Playthrough（带团记录）` 仍是骨架。P3 先交付可关闭重开的最小会话与版本入口；完整叙事进度、楼层和跨地点状态在 P8 闭环。

见 `docs/multi_scene_draft.md`

### 5.4 地面纹理系统

```
assets/textures/ground/<纹理组名>/
    ├── albedo.png（单文件当作整张颜色贴图）
    └── normal.png / roughness.jpg / ...（多文件按关键词分类）
```

- `_apply_ground_texture()` → 新建材质+贴图+设 uv1_scale+挂 Ground 节点
- 默认贴图铺满模式：uv1_scale=(1,1,1)，整张贴图映射整个 PlaneMesh（拉伸不重复）
- 其他 PBR 纹理按 `ground_tile` 格数重复

### 5.5 物件三套碰撞（架构约定）

| 层 | 组件 | 碰撞体 | 阶段 |
|----|------|--------|------|
| 拾取层 | PickProxy (Area3D+BoxShape3D) | AABB 不跟转 | P1 落地 |
| 战斗层 | CombatBody | 跟物件转的盒/多边形 | P2.4 基础版已落地 |
| 迷雾层 | LOSOccluder | 俯视投影地面遮挡轮廓 | P2.5 基础版已落地，P7 扩展规则与表现 |

---

## 六、项目文件结构（关键）

```
C:\Users\Admin\Desktop\GVTT/
├── project.godot              ← 配置（autoload/input map/渲染/插件）
├── AGENTS.md                  ← 当前项目指令（AI 协作规矩）
├── .claude/CLAUDE.md          ← 历史迁移资料，当前以 AGENTS.md 为准
├── .codex/settings.json       ← Codex MCP 配置 ← **新加的**
├── scripts/
│   ├── main.gd                ← 主场景脚本（4107 行/217 个函数），主协调层目标尚未完成，归 P3 收口
│   ├── pointer_interaction_controller.gd / selection_controller.gd / placement_controller.gd
│   ├── scene_session_controller.gd / camera_view_controller.gd / main_ui_controller.gd
│   ├── token_properties.gd / cpr_token_properties.gd / wall_properties.gd / light_properties.gd
│   ├── combat_body.gd / combat_line_query.gd / combat_line_preview.gd
│   ├── los_occluder.gd / los_service.gd / los_visibility_polygon.gd / cast_fog_overlay.gd / gm_tool_overlay.gd
│   ├── mode_gate.gd           ← autoload 权限闸
│   ├── cast_view.gd           ← 投屏窗口
│   ├── entity_properties.gd   ← 物件属性组件
│   ├── pick_proxy.gd          ← 拾取代理
│   ├── gvtt_render_layers.gd  ← 渲染层常量
│   ├── grid_manager.gd        ← 网格管理器
│   ├── library_manager.gd     ← 素材库管理（导入/删除/扫描）
│   ├── scene_props.gd         ← 场景属性（随场景存的纹理/尺寸等）
│   ├── module_gate.gd         ← 多场景当前模组/场景真值
│   ├── module_io.gd           ← 场景存读盘封装
│   ├── module_manifest.gd / location_ref.gd / playthrough.gd ← 多场景与带团存档骨架
│   ├── post_import_center.gd  ← 导入后置处理器（清模型偏移）
│   └── mode_gate.gd           ← autoload
├── scenes/
│   └── main.tscn              ← 唯一场景（6 节点骨架）
├── shaders/
│   ├── grid_shader.gdshader   ← 网格 shader（三级线）
│   └── grid_line.gdshader     ← 线 shader
├── assets/
│   ├── textures/ground/uv_checker_4096_v2/  ← **唯一自带默认贴图**
│   ├── walls/ terrain/ props/ lights/ interactables/ tokens/ vfx/ environment/
│   └── models/                ← 外部导入素材（不进仓库）
├── addons/
│   ├── godot_ai/              ← Godot MCP 连接器（1.4MB）
│   ├── Gizmo3DScript/         ← 运行时手柄插件（72KB）
│   ├── gdUnit4/               ← 测试框架（3.1MB）
│   └── gdstyle/               ← 代码风格检查（18MB）
├── docs/
│   ├── README.md              ← 文档入口和阅读顺序
│   ├── design.md              ← 策划文档（5 维度+功能优先级）
│   ├── p2_task_schedule.md    ← P2 阶段任务和验收口径
│   ├── asset_inventory.md     ← 资产目录分工和安全整理边界
│   ├── module_workflow.md     ← 模组首页、开发测试模组和正式启动规则
│   ├── architecture.md        ← 架构文档（含术语表）
│   ├── entity_properties_schema.md ← 物件属性 schema
│   └── multi_scene_draft.md   ← 多场景系统草案
├── reference/Godot 4.7 Dooc/  ← Godot 4.7 离线文档（15MB/1593 文件）
└── devlog/DEVLOG.md           ← 实时开发日志
```

---

## 七、Git 状态（历史迁移记录，非当前真值）

> 当前工作区已有大量历史修改和插件升级痕迹。需要判断可提交内容时，以实时 `git status` 为准，不把下列 2026-07-15 迁移记录当成最新状态。

- **远程仓库：** `https://github.com/Al1gura/Gvtt.git`
- **分支：** `master`
- **Git Hub token：** 已配在 remote URL 中（个人 token）
- **已提交到 GitHub：**
  - 核心代码 + 文档（commit `14f5079`）
  - 清理 + 移除残留（commit `fcbd42d`）
  - addons/ 插件（commit `b17e966`）
  - 默认贴图 + 目录骨架（commit `1576b33`，**尚未推送——网络连接失败，须重试 `git push origin master`**）
- **未跟踪（.gitignore 排除，不需要提交）：**
  - `.claude/skills/`（30MB 的 Claude Code 技能，Codex 不用）
  - `.claude/hooks/`（Claude Code 专属 hooks）
  - `assets/models/`（外部导入建筑模型+贴图）
  - `assets/textures/buildings/`（外部导入建筑贴图）
  - `assets/textures/ground/uv_checker/`、`uv_checker_4096/` 和 `stone_floor/`（外部导入地面纹理）
  - `.godot/` 和 shader_cache/（引擎临时文件）

---

## 八、Godot 编辑器配置

| 配置项 | 值 | 位置 |
|--------|-----|------|
| 渲染器 | Forward Plus / D3D12 | `project.godot` |
| 窗口 | 1280×720, embed_subwindows=false | `project.godot` |
| 主场景 | `res://scenes/main.tscn` | `project.godot` |
| Autoloads | ModeGate, ModuleGate, _mcp_game_helper | `project.godot` |
| 插件 | godot_ai 已启用 | `project.godot` |
| Input Map | ui_drag（鼠标左键 deadzone 0.2） | `project.godot` |
| 物理 | Jolt Physics 3D | `project.godot` |

---

## 九、MCP 配置（Godot AI 连接）

### 给 Codex 的配置

`.codex/settings.json` 已创建：
```json
{
  "mcpServers": {
    "godot-ai": {
      "type": "http",
      "url": "http://127.0.0.1:8000/mcp"
    }
  }
}
```

### 给 Cursor/其他工具的配置（备查）

```json
{
  "mcpServers": {
    "godot-ai": {
      "type": "http",
      "url": "http://127.0.0.1:8000/mcp"
    }
  }
}
```

### Godot AI 启动方式

打开 Godot 编辑器后，Godot AI 插件会自动启动服务并连接端口 8000。

如需重新配置 Codex 等客户端，在 Godot AI 面板里选择客户端并点击 `Configure`；当前版本没有 `addons/godot_ai/cli.gd` 命令行入口。

### 调试通道问题

如果 `game_eval` 连不上（helper_live false）：
1. 检查 Godot 启动时有没有报 `port 6006/6005 Already in use` → **僵尸进程**，重启电脑解决
2. 检查 MCP 连接是否断 → 优先**重启 Cowork 客户端**（Codex）而非 Godot
3. 确认跑游戏后 `logs_read(source=game, count=80)` 有数据

### Godot AI 工具规范（来自 CLAUDE.md）
- 场景修改合并为一次 `batch_execute`（用插件命令名 `create_node`/`set_property`/`save_scene`）
- **严禁**调用 `editor_reload_plugin`（会断 MCP 连接）
- `game_eval` 的 code 参数缩进必须用 tab（`\t`），不能用空格
- `project_manage(op=stop)` 也不准用来停僵死游戏（会断链）

---

## 十、已知潜在地雷（读代码前必看）

### 10.1 main.gd 被截断历史（2026-07-15）
main.gd 上一轮写文件两次末尾被截断（疑似 `filesystem_manage(op=reimport)` 重扫时搞的）。验证方法：
```bash
tail -c 20 main.gd | xxd          # 看末尾是否完整
grep "func _reset_all_transforms"  main.gd  # 看关键函数是否存在
```
写大 .gd 文件后务必验证完整性。

### 10.2 Godot AI write_text 偶发写坏
`filesystem_manage(write_text)` 会偶发在 .gd 文件末尾追加 NUL 字节。写 GDScript 文件优先用磁盘 Write 工具。

### 10.3 Godot 3→4 API 改名高危
赋值 `hint_tooltip`（3.x 旧名，4.7 叫 `tooltip_text`）、`flags_unshaded`（4.7 改 `shading_mode`）等会**静默中断**当前函数，不报 parse error。写代码前必须查离线文档 `reference/Godot 4.7 Dooc/` 确认 4.7 现行名称。

### 10.4 编辑器缓存脏
修改 .gd 文件后编辑器可能缓存在脏版本报错（行号对不上、函数找不到）。正确判断：
1. 用 `game_eval` 实跑检查脚本是否正常执行（比编辑器报错靠谱）
2. 确认实跑正常 → 承认"编辑器报错、实跑正常"
3. 不准用 `editor_reload_plugin` 冲缓存（断链）
4. 温和的清缓存办法：`filesystem_manage(op=scan)` → 重启 Godot

### 10.5 新建 class_name 脚本运行态滞后
新加的 `class_name` 脚本在跑游戏前 ClassDB 没注册。用 `load("res://...")` 绕开。

### 10.6 embed_subwindows=false 的副作用
全局设置导致所有 Window 派生类（含弹出对话框）都变独立 OS 窗。弹出菜单位置需要屏幕坐标（`DisplayServer.mouse_get_position()`），不能用窗口内坐标（`get_viewport().get_mouse_position()`）。

### 10.7 PickProxy 拾取盒
- `PickProxy.target_node` 已加 `@export`（修复序列化重连问题）
- 放置物件后需要 `force_update_transform` 才能让拾取盒贴合模型
- `monitoring=true` 是射线命中的必要条件（`monitoring=false` 的 Area3D 不响应射线）

---

## 十一、关键文档清单

阅读优先级：**从上到下**

| 文档 | 内容 | 必读理由 |
|------|------|----------|
| `AGENTS.md` | 当前协作规矩 + 工具规范 + 命名规范 | **每件事前必须读** |
| `docs/README.md` | 文档入口和阅读顺序 | 避免先读到历史档案或旧口径 |
| `docs/design.md` | 产品定位 + 5 维度 + 功能优先级 | 理解"为什么做这个" |
| `docs/architecture.md` | 架构 + 术语表 + 文件结构 | 理解"怎么做的" |
| `devlog/DEVLOG.md` | 实时开发日志 + 问题表 | **最新状态在这里** |
| `docs/entity_properties_schema.md` | 物件属性 schema 2.0 | 做物件相关必须看 |
| `docs/p2_task_schedule.md` | P2 阶段状态与验收口径 | 判断 P2 做完/没做完时必须看 |
| `docs/asset_inventory.md` | 资产目录分工与安全边界 | 整理素材前必须看 |
| `docs/multi_scene_draft.md` | 多场景系统草案 | 做多场景必须看 |
| `devlog/2026-07-07-*` 等 | 历史复盘 | 踩坑总汇 |
| `reference/Godot 4.7 Dooc/` | Godot 4.7 离线文档 | **写代码前查** |

---

## 十二、内存/跨会话持久化

在 Codex 中，跨会话记忆通过 `.claude/ 目录下的文件实现（注意不是 Codex 自己的 memory 系统——Codex 有自己的 `_memory/`，但此项目之前用的是 Claude Code 的 `memory/` 目录）。关键记忆文件存储在：
`C:\Users\Admin\AppData\Local\Claude-3p\local-agent-mode-sessions\064f67ea\00000000\spaces\3c3518e6-ff6b-4f57-9c46-b724c3877573\memory\`

**这些记忆是 Claude Code 格式的，Codex 可能需要重新建立自己的记忆体系。** 核心知识点已浓缩在本文档和以下文件中：
- `devlog/DEVLOG.md` 的"十大未解之谜"🕵️ 部分
- `docs/architecture.md` 的术语表

建议 Codex 第一次对话时让用户决定是否需要重建记忆。

---

## 十三、环境依赖

| 依赖 | 位置 | 说明 |
|------|------|------|
| Godot 4.7-stable | 用户电脑已安装 | 打开项目后 Godot AI 自动启动服务 |
| gdstyle 插件 | `addons/gdstyle/` | 编辑器内 lint/format 辅助；当前未发现 CLI 可执行文件 |
| GdUnit4 | `addons/gdUnit4/` | 测试框架 |
| Gizmo3D | `addons/Gizmo3DScript/` | 运行时手柄 |
| Godot 4.7 离线文档 | `reference/Godot 4.7 Dooc/` | 1593 文件，15MB |
| GitHub remote | `https://github.com/Al1gura/Gvtt.git` | GitHub CLI 2.94.0 已安装；认证凭据只保存在本机，不写入文档或远程 URL |

---

## 十四、给 Codex 的第一句话建议

> 这是一个用 Godot 4.7 做的跑团 GM 桌面工具。我是用户，没有编程背景。你需要知道的所有事都在 `docs/CODEX_HANDOFF.md` 里。先读完这个文件，然后我们再聊。任何时候有不明白的、需要我操作的，直接问。

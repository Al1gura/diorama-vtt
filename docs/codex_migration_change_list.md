# Codex 迁移后变更清单

用途：如果以后从 Codex 切回 Claude Code，先让 Claude Code 读这份清单。它说明哪些文件是 Codex 迁移后明确新增或修改的，哪些只是当前 Git 状态里的迁移噪音。

## 先读结论

- 不要把 `git status` 里所有 `M` 都当成 Codex 改动。当前仓库有大量文件只是 Git 文件模式从 `100755` 变成 `100644`，尤其是 `addons/`、旧文档和若干脚本。这类更像 Windows/迁移造成的权限位变化，不代表内容被 Codex 改写。
- Codex 明确新增的入口文件是 `AGENTS.md`。它不是 `.claude/CLAUDE.md` 的完全平替，而是 Codex 侧项目指令入口；切回 Claude Code 时，应把其中新增的硬规则同步回 `.claude/CLAUDE.md`，否则 CC 可能不会严格执行。
- Codex 明确新增的配置目录是 `.codex/`。切回 CC 时这些文件一般不参与运行，可保留作历史，也可在确认不用 Codex 后清理。
- Codex 明确改过的业务代码主要是 `scripts/main.gd` 和 `scripts/entity_properties.gd`，主题是模型拖放、真实模型预览、模型缓存、分类字段。

## 明确是 Codex 新增的文件

| 文件 | 作用 | 切回 CC 时怎么处理 |
|---|---|---|
| `AGENTS.md` | Codex 读取的项目指令入口。包含沟通规则、调研规则、Godot 源码优先硬门槛、MCP 使用纪律。 | 让 CC 先读。重点把“功能实现”和“Godot 源码优先”段落合并回 `.claude/CLAUDE.md`。 |
| `.codex/config.toml` | Codex 的 MCP 配置，指向 `http://127.0.0.1:8000/mcp`。 | CC 不一定用。保留即可。 |
| `.codex/settings.json` | Codex 兼容格式的 MCP 配置，也指向 `godot-ai`。 | CC 不一定用。保留即可。 |
| `.codex/hooks.json` | Codex hook 配置，调用确认脚本。 | CC 不一定用。保留即可。 |
| `.codex/hooks/require-user-confirmation.sh` | 试图拦截未确认工具调用的 hook 脚本。当前文件显示有中文编码乱码，且内容还残留 “Claude” 字样。 | 不要当成可靠规则源。真正规则以 `AGENTS.md` 为准。 |
| `docs/CODEX_HANDOFF.md` | 从 Claude Code 迁移到 Codex 的交接文档，记录 2026-07-15 当时的项目进度、配置、风险和给 Codex 的第一句话建议。 | 切回 CC 时仍值得读，因为里面有迁移背景和旧状态。 |
| `docs/codex_migration_change_list.md` | 本清单。 | 切回 CC 的第一份识别地图。 |

## 明确是 Codex 修改过的文件

| 文件 | 改动性质 | 依据 |
|---|---|---|
| `devlog/DEVLOG.md` | 追加了 2026-07-15、2026-07-16 多段 Codex 工作记录，包括迁移体检、拖放预览、P1 收口、真实模型拖放预览、Godot 源码优先规则。 | `rg` 能搜到 “2026-07-15 Codex”、“2026-07-16 Codex”、“强化 Godot 源码优先规则”；`git diff --numstat` 显示约 195 行新增。 |
| `scripts/main.gd` | 拖放系统大改：模型栏位拖动、拖放完成、真实模型预览、模型预热缓存、导入模型实例化、缓存清理、墙面吸附、放置后分类写入。 | `rg` 能搜到 `_on_model_drag_started`、`_finish_model_drag`、`_create_drag_preview_model`、`_warm_model_cache_for_path`、`_instantiate_imported_model` 等；`git diff --numstat` 显示约 358 行新增、23 行删除。 |
| `scripts/entity_properties.gd` | 新增 `category: String`，用于记录物件来自哪个素材栏位，如 `token`、`wall`、`interactable`。 | `git diff` 显示新增 `@export var category: String = ""`。 |
| `AGENTS.md` | 新增并继续强化 Codex 侧规则。最近一次加入：“涉 Godot/GD 既有行为时，Godot 源码是硬门槛”。 | `rg` 能搜到 “涉 Godot/GD 既有行为时，Godot 源码是硬门槛”。 |

## 可能是 Codex 期间产生，但需要复核的文件

这些文件在当前 Git 里显示变化，但不能只凭状态断定都是 Codex 写的。切回 CC 时应先看内容差异，再决定要不要保留。

| 文件或目录 | 当前看到的状态 | 判断 |
|---|---|---|
| `assets/textures/ground/uv_checker_4096_v2/uv_checker_4096_v2.png` | 二进制文件有变化。 | 可能和默认 UV 检测贴图、地面贴图测试有关。保留，除非确认要回滚贴图。 |
| `assets/textures/ground/uv_checker_4096_v2/uv_checker_4096_v2.png.import` | Git 显示修改但 `numstat` 为 `0 0`。 | 可能是文件模式或 Godot import 元数据微变。不要轻易当功能改动。 |
| `modules/测试模组/_canonical/场景1.scn` | 二进制场景大小从 3909 变 1775。 | 可能是自动保存或测试场景保存产生。切回 CC 前需确认场景内容是否符合当前测试模组。 |
| `modules/测试模组/_canonical/场景2.scn` | 二进制文件显示修改，大小没变。 | 可能是保存时二进制重写。需要 Godot 里打开或用当前保存逻辑复核。 |
| `.agents/` | 当前是未跟踪目录。 | 里面是 GodotPrompter/技能类资料，Codex 会读到。是否纳入仓库需另行决定。 |
| `reference/` | 当前是未跟踪目录。 | 离线 Godot 文档来源。项目规则要求写 Godot API 前查它。不要随手删。 |
| `2K_Gravel01/`、`个人资产/`、`assets/textures/ground/uv_checker_4096/` | 当前是未跟踪目录。 | 更像素材或本地测试资产，不确定是否应进仓库。切回 CC 时让它先识别来源。 |

## 当前 Git 状态里大量“假修改”

`git diff --summary` 显示大量文件只是：

```text
mode change 100755 => 100644
```

典型范围包括：

- `.claude.json`
- `.claude/CLAUDE.md`
- `.editorconfig`
- `.gitattributes`
- `.gitignore`
- `README.md`
- `addons/Gizmo3DScript/`
- `addons/gdUnit4/`
- `addons/gdstyle/`
- `addons/godot_ai/`
- `project.godot`
- `scenes/main.tscn`
- 多个旧 `docs/`、`scripts/` 文件

这类变化通常只是“这个文件在 Git 里以前被标成可执行，现在变成普通文件”。内容不一定变了。切回 CC 时，不要让它因为这些 `M` 去大规模回滚。

## 切回 Claude Code 时建议顺序

1. 先读 `docs/codex_migration_change_list.md`。
2. 再读 `AGENTS.md`，把 Codex 新增规则同步进 `.claude/CLAUDE.md`，尤其是 Godot 源码优先规则。
3. 再读 `devlog/DEVLOG.md` 从 “2026-07-15 Codex 项目迁移到桌面 GVTT” 往后的段落。
4. 再看 `scripts/main.gd` 与 `scripts/entity_properties.gd` 的差异，重点确认拖放真实模型预览是否符合用户手感。
5. 最后处理 Git 噪音：先区分内容变化和 `mode change`，再决定是否统一修复权限位。

## 仍需提醒 CC 的坑

- 真实模型拖放预览已经按 Godot 编辑器体感和官方 API 改过，但 `devlog/DEVLOG.md` 明确记录：尚未补齐 Godot 引擎源码对照，不能严谨称为“按 Godot 源码实现”。
- P1 已按当前验收口径收口，但真人手动拖放体感仍建议复测。
- `.codex/hooks/require-user-confirmation.sh` 有乱码，不应作为沟通规则依据。
- `git status` 很吵，先看差异类型，不要一上来批量回滚。

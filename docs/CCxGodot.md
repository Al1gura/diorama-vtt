# Codex 与 Godot 工具链核查入口

> 状态：2026-07-18。本文不重复策划和架构，只记录“查状态时别漏哪些入口”。

## 当前真值来源

- 项目定位与阶段状态：`docs/design.md`
- P2 任务和验收：`docs/p2_task_schedule.md`
- 架构和术语：`docs/architecture.md`
- 对象属性边界：`docs/entity_properties_schema.md`
- 模组工作流：`docs/module_workflow.md`
- 资产整理边界：`docs/asset_inventory.md`
- 最新过程记录：`devlog/DEVLOG.md` 顶部最新条目

## 工具与配置入口

- 当前协作规则：项目根目录 `AGENTS.md`
- Codex MCP 配置：`.codex/settings.json`
- Godot 项目配置：`project.godot`
- 主场景：`scenes/main.tscn`
- 主协调脚本：`scripts/main.gd`
- Godot 4.7 离线文档：`reference/Godot 4.7 Dooc/`

## 口径

- 本项目默认使用 Godot 4.7-stable。
- 涉及 Godot API 或编辑器行为时，必须按 `AGENTS.md` 查离线文档和源码依据。
- 本文件只做索引，不作为功能完成状态的最终依据。

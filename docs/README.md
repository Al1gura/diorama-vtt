# Gvtt 文档入口

> 状态：2026-07-22 当前文档入口。本文只说明“先读哪个、哪个是历史档案”，避免多个文档顺序混乱；P1-P4 已完成，P5 CPR 战斗操作闭环已按五个开发阶段完成重新调研和拆分，功能实现尚未开始。

## 最新阅读顺序

1. `AGENTS.md`：当前协作规则、命名规范、调研门禁和 Godot 工具纪律。
2. `docs/design.md`：产品定位、边界和五维度。
3. `docs/roadmap.md`：P2 收口闸门与 P3-P9 第一版剩余阶段、系统依赖和验收真值。
4. `docs/p5_plan.md`：P5 CPR 战斗操作闭环的 GM 操作步骤、四层调研、Godot 4.7 源码对照、架构、批次和验收门槛。
5. `docs/p2_task_schedule.md`：P2.0-P2.6 的最新阶段状态、验收口径和明确后置项。
6. `docs/architecture.md`：当前架构、术语表、控制器拆分、碰撞/移动/战斗/LOS 边界。
7. `docs/p3_application_boundary.md`：P3 应用树、唯一状态所有者、生命周期和迁移门槛。
8. `docs/p3_persistence_contract.md`：P3 模组/会话磁盘格式、稳定标识、迁移、备份恢复与测试矩阵。
9. `docs/p3_playthrough_contract.md`：P3 最小带团会话、地点快照、底本隔离、保存顺序和恢复测试矩阵。
10. `docs/p3_player_output_contract.md`：P3 外部内容引用、MAP/IMAGE/VIDEO 玩家输出、后端隔离和清理测试矩阵。
11. `docs/p3_lifecycle_test_contract.md`：P3 完整生命周期、源码对照、独立测试模组、图片/OGV 夹具和可见验收。
12. `docs/entity_properties_schema.md`：对象类型与专属属性组件边界。
13. `docs/module_workflow.md`：模组首页、开发测试模组、正式 EXE 启动和场景入口规则。
14. `docs/asset_inventory.md`：资产目录分工、重复项和暂不移动的安全边界。
15. `docs/cpr_reading/combat_quick_reference.md`：GM 带团用 CPR 战斗规则速查，保留原书 PDF/书内页码。
16. `devlog/DEVLOG.md`：最新开发日志。只看最顶部最新条目；旧条目是历史，不代表当前状态。

## 辅助与历史文档

| 文档 | 角色 |
|---|---|
| `docs/CODEX_HANDOFF.md` | 给新 Codex 对话快速接手的长交接文档，信息较全但以本入口列出的专题文档为准 |
| `docs/CCxGodot.md` | Codex 与 Godot 工具链核查入口，不放重复策划 |
| `docs/multi_scene_draft.md` | 多场景/带团存档的历史草案；基础场景列表和模组首页已落地，P3/P8 实施前可用于追溯旧决策 |
| `docs/codex_migration_change_list.md` | 迁移到 Codex 期间的改动清单 |
| `docs/drafts/` | 草稿区；内容可能落后，不能作为当前状态真值 |
| `docs/session_*.md`、`docs/前期策划.md` | 历史会议/早期策划归档 |
| `docs/cpr_reading/` | CPR 规则资料索引。涉及 MOVE、行动、伤害、装备等规则时必须查这里 |

## 当前 P2 口径

- P2.0-P2.6 基础版均已落地。
- P2 四套自动回归、文档统一和性能基线已完成；剩余不是新功能，而是 GM 可见窗口最终操作与体感确认。
- P2.6 已在破坏/修复后重建 P2.2 移动服务，Token 能穿过破墙口；当前全量重建约停顿 1.8-2.0 秒，性能优化归 P9。
- 当前双窗口三轮为 `42/54/43 FPS`，两张现有场景切到下一可见帧约 `33-139 ms`；这些数字已记录，但是否满足现场体验仍由 GM 验收。
- P3 先建立最小可持续底座：真实模组清单、稳定标识、最小带团会话、三层状态、外部内容引用、玩家输出与清理合同，并用测试图片/OGV 验证结构。正式图片/MV 归 P4，CPR 战斗操作闭环归 P5，备团与内容管理归 P6，高级 LOS 归 P7，完整多地点/楼层带团恢复归 P8，P9 完成第一版发布；CPR 风格三维演出与场景气氛后置于第一版候选。
- 资产暂不物理搬家；`个人资产/` 作为源素材仓保留，精选素材以后再复制进正式 `assets/` 栏位。

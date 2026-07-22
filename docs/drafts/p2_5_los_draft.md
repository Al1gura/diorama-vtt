# P2.5 LOS（视线遮挡）构思草案

> 状态：历史草案。2026-07-18 已并入 `docs/design.md`、`docs/p2_task_schedule.md` 和 `docs/entity_properties_schema.md`。
> P2.5 已实现；正式范围、接口和验证结果以三份正式文档与 `devlog/DEVLOG.md` 为准。
> 本稿保留早期决策过程，不再作为实现入口。

## 一、当前项目依据

- `docs/design.md` 已把拾取、移动、战斗和迷雾拆成独立职责。
- P2.4 建立 `OcclusionGeometry`，负责从真实模型得到物件根局部边界。
- P2.5 必须复用该局部边界，不重新扫描模型，也不读取 `CombatBody`（战斗碰撞体）作为 LOS 真值。
- `WallProperties.blocks_shot` 与 `WallProperties.blocks_los` 分开保存，分别控制挡枪线和挡视线。
- GM 主窗口与投屏窗口共享同一个 `World3D`（3D 世界），但各有独立相机和视口。
- 当前 Godot 版本为 `4.7-stable official`。

## 二、P2.5 推荐范围

P2.5 只完成“单一视点的当前视野闭环”：

1. GM 在运行态明确指定一个 Token（标记）作为视点。
2. 墙体根据 `blocks_los` 决定是否提供地面遮挡轮廓。
3. 系统从视点和所有墙体轮廓计算当前二维可见区域。
4. 投屏窗口显示不可见区域遮罩；GM 主窗口保留完整地图，可选择显示调试轮廓。
5. 视点移动、墙体增删/变换或 `blocks_los` 改变时重算。

基础版不做：

- 多 Token 视野合并。
- 阵营或玩家专属视野。
- 视野距离、夜视、灯光和黑暗规则。
- 已探索区域记忆和迷雾存档。
- 每帧重算或复杂空间缓存。
- 多楼层和多场景迷雾同步。

## 三、建议职责拆分

### LOSOccluder（视线遮挡体）

- 挂在墙体对象下。
- 读取 `WallProperties.blocks_los`。
- 调用 `OcclusionGeometry` 获取局部边界，并转换为世界 XZ 地面上的遮挡线段。
- 不创建战斗物理体，不执行射线查询，不负责显示迷雾。

### LOSService（视线服务）

- 作为当前场景的运行时服务，不做全局单例。
- 注册和移除 `LOSOccluder`。
- 保存当前唯一视点。
- 在事件发生时计算可见多边形，不使用每帧轮询。

### VisibilityPolygon（可见多边形计算器）

- 输入：视点、地图边界、遮挡线段。
- 早期“墙角正对/左右偏移三射线”方案已撤回：深凹角可能把两个最近交点跨墙直连，造成隔墙漏视。
- 实际采用活动边最小堆旋转扫描；线段先在交点处分割并去重，只在最近活动线段变化时输出边界点。
- 输出：当前可见区域多边形。

基础版仍为事件驱动，不做空间索引或复杂可见区域缓存；旋转扫描解决几何正确性，性能索引留 P3。

### FogRenderer（迷雾显示器）

- 只消费可见多边形，不参与 LOS 计算。
- 遮罩属于投屏窗口自己的视口，不直接放进共享 `World3D`，避免同时遮住 GM 主窗口。
- GM 主窗口只显示可选调试轮廓或半透明预览。

## 四、阶段分界

| 阶段 | 范围 |
|---|---|
| P2.5 | 单一视点、墙体遮挡、当前可见区域、投屏遮罩 |
| P2.6 | 墙体破坏/修复时切换 `blocks_los`，发出变化信号并触发重算 |
| P3 | 多视点合并、阵营、灯光/黑暗、烟雾、探索记忆、性能缓存 |
| P4 | 多楼层、多场景和长期迷雾状态管理 |

## 五、与墙体破坏的联动

- `WallProperties` 已提供统一的 `set_blocks_los()` 基础语义入口，并发出 `los_blocking_changed` 信号。
- P2.6 把墙体设为破坏状态时，不覆盖基础 `blocks_los` / `blocks_shot`；分别从墙状态和基础字段推导两套有效值并关闭对应运行组件，修复时再按各自基础值恢复。
- `LOSService` 收到变化后，只更新对应遮挡体并重算可见区域，不重新扫描整棵模型树。

## 六、验证计划

自动测试至少覆盖：

- 局部边界正确转换为世界地面轮廓。
- 墙体平移、旋转和缩放后轮廓正确。
- 直墙、L 形墙、相邻墙角和前后重叠墙不漏光。
- `blocks_los=false` 后立即不再遮挡。
- LOS 不查询 `PickProxy`（点击代理）和 `CombatBody`。
- 删除墙体或切换场景后不残留旧遮挡体。

运行态验证至少覆盖：

- GM 指定一个 Token 为视点，投屏出现对应可见区域。
- Token 移动后可见区域更新。
- 墙后区域被遮住，墙前区域保持可见。
- GM 主窗口不被投屏迷雾遮挡。
- P2.6 完成后，墙体破坏会立即打开原先被挡住的区域。

## 七、并行开发约束

P2.4 与 P2.5 不应在同一个项目目录中同时写代码，因为两者会共同涉及：

- `scripts/occlusion_geometry.gd`
- `scripts/placement_controller.gd`
- `scripts/main.gd`
- `scripts/gvtt_render_layers.gd`
- `project.godot`
- 正式设计文档和 `devlog/DEVLOG.md`

推荐顺序：P2.4 完成实现和测试，固定共享几何接口；随后 P2.5 基于该接口实现。若必须并行，应使用不同的 Git 独立工作树和分支，并指定唯一的共享文件整合负责人。

## 八、已核查来源

- 项目：`docs/design.md`、`docs/p2_task_schedule.md`、`docs/entity_properties_schema.md`、`scripts/wall_properties.gd`、`scripts/occlusion_geometry.gd`、`scripts/cast_view.gd`、`project.godot`。
- Godot 4.7 源码：`scene/2d/light_occluder_2d.cpp`、`servers/physics_3d/physics_server_3d.h/.cpp`、`modules/jolt_physics/spaces/jolt_physics_direct_space_state_3d.cpp`。
- 官方离线文档：`gdd_0644_LightOccluder2D.md`、`gdd_0989_OccluderPolygon2D.md`、`gdd_1407_PhysicsRayQueryParameters3D.md`、`gdd_1402_PhysicsDirectSpaceState3D.md`、`gdd_1297_Geometry2D.md`。
- 英文社区：`d-bucur/godot-vision-cone`、Godot Asset Library 的 `AreaOfSight2D` 与 `Visibility Polygon`。

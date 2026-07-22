# Entity Properties Schema

> 状态：P2.0 对象类型 schema 已收口，P2.1-P2.6 基础功能已按本文边界落地。本文只定义属性边界，不替代 `docs/p2_task_schedule.md` 的阶段验收口径。

## 一、目标

P2.0 的目标不是先做某个按钮，而是把“地图上的东西”从单一 `EntityProperties` 字段桶，收口为：

- 通用身份组件：`EntityProperties`
- Token 通用组件：`TokenProperties`
- 规则集专属组件：首个为 `CprTokenProperties`
- 跨对象可选通行组件：`TraversalProperties`
- 墙体专属组件：`WallProperties`
- 光源专属组件：`LightProperties`
- 交互物体专属组件：`InteractableProperties`

这样后续运行态选择、操作面板、保存/加载、投屏显示都能按对象类型走清楚路径，而不是继续靠 `category` 字符串散落判断。

明确不做：自动骰子、完整自动规则引擎、自动伤害结算、完整职业技能规则、自动战斗轮次、玩家端联网同步。P2.2 经用户修正为 CPR MOVE（移速）规则辅助；凡涉及 CPR 字段和算法，必须遵守 `docs/design.md` 的 CPR 资料查阅门禁。

## 二、现状依据

- `scripts/entity_properties.gd` 已有 `EntityProperties`，但本文件此前为空，造成“代码说依据 schema、schema 却不存在”的矛盾。
- `scripts/main.gd::_place_model()` 当前给所有放置物件挂 `EntityProperties + PickProxy`，并把素材栏位写入 `props.category`。
- `scripts/main.gd::_select_entity()` 当前属性面板只绑定 `EntityProperties`，所以不同对象类型暂时共用同一套字段。
- `scripts/pick_proxy.gd` 已明确 `PickProxy` 只负责点击选中，不承担挡枪线或视线遮挡。
- `docs/design.md` 和 `docs/p2_task_schedule.md` 均已把 P2.0 定为“对象类型系统 + schema 收口”。

## 三、组件总表

| 对象类型 | 通用组件 | 专属组件 | P2 操作入口 | 后置内容 |
|---|---|---|---|---|
| Token | `EntityProperties` | `TokenProperties` + 当前规则集组件 | CPR MOVE 限制移动范围；绕障碍路线；瞄准线/射击线入口后续排 | 生命值、通用行动点、命中、伤害、职业技能、完整轮次记账 |
| 墙体 | `EntityProperties` | `WallProperties` | 状态查看、破坏/修复入口、挡视线/挡枪线状态 | 材质硬度、抗性、伤害类型、复杂碎裂 |
| 光源 | `EntityProperties` | `LightProperties` | 先做点光源开关，聚光可预留入口 | 方向光/太阳光、场景气氛系统、雾、闪烁曲线、物理光照深调 |
| 交互物体 | `EntityProperties` | `InteractableProperties` | 触发、启用/禁用入口 | 检定难度、钥匙/道具需求、伤害/爆炸/燃烧等具体效果、规则效果 |
| 地形/装饰 | `EntityProperties` | 可选 `TraversalProperties` | 选择、显示/隐藏、通行标签、基础寻路 | 复杂状态减速、覆盖自动判定 |

## 四、EntityProperties

`EntityProperties` 只保留所有对象都共有、且无法可靠从模型自动推导的字段。

建议字段：

| 字段 | 类型 | 阶段 | 说明 |
|---|---|---|---|
| `schema_version` | `int` | P2.0 | 存档迁移用。建议新 schema 从 `2` 开始。 |
| `entity_type` | `EntityType` | P2.0 | 对象语义类型：Token、Wall、Light、Interactable、Terrain、Decor。后续运行态操作按它分派。 |
| `category` | `String` | 兼容保留 | 旧素材栏位名。短期保留读取旧存档，长期不作为主要业务判断。 |
| `display_name` | `String` | 已有 | GM 起的显示名，独立于节点名。 |
| `visibility` | `Visibility` | 已有 | `BOTH` 或 `GM_ONLY`，影响投屏相机能否看到。 |

建议从 `EntityProperties` 迁出的字段：

| 旧字段 | 新归属 | 理由 |
|---|---|---|
| `destructible` | `WallProperties`，必要时也可给 `InteractableProperties` | 是否可破坏不是所有物件共有。 |
| `max_hp` | `WallProperties.durability_max` | 墙的算法可以像生命值，但业务含义是耐久，避免和 Token 生命值混淆。 |
| `cover_level` | `WallProperties.cover_level` 或未来 `CombatBody` 配置 | 掩体是战术/战斗几何语义，不是所有物件共有。 |
| `los_occluder` | `WallProperties.blocks_los` + `LOSOccluder` | 挡视线是 LOS 专用语义，不应挂在所有物件的通用属性里。P2.5 已将基础字段与运行时遮挡组件分离。 |

## 五、TokenProperties

Token 在 P2.2 做 CPR 规则辅助移动：GM 直接拖动，软件根据 MOVE（移速）计算路线预算、绕开阻挡物并限制最后可达点。基础版已落地，完整轮次记账继续后置。

建议字段：

| 字段 | 类型 | 阶段 | 说明 |
|---|---|---|---|
| `can_move` | `bool` | P2.2 | 运行态是否允许 GM 拖动。默认 `true`。 |
| `footprint_cells` | `Vector2i` | P2.2 | 占格大小，默认 `Vector2i(1, 1)`；在 CPR 网格模式下 1 格代表 2 米/码。 |
| `collision_radius` | `float` | P2.2 | 移动防穿模体积半径，默认 `0.45` 米。不是规则 MOVE。 |
| `collision_height` | `float` | P2.2 | 移动防穿模体积高度，默认 `1.8` 米。 |
| `can_show_aim_line` | `bool` | P2.4 | 是否允许显示射击线/瞄准线入口。默认 `true`。 |
| `marker_color` | `Color` | P2 或后置 | Token 标记色，只是视觉辅助，不参与规则。 |

明确后置：

- `hp/current_hp/max_hp`
- `action_points`
- `initiative`
- `skills`
- `attack_bonus`
- `damage`
- `armor`
- `faction/alignment` 若会触发自动规则，也后置

运行期边界：本次移动起点、路线、剩余距离和最终演示位置属于一次跑团操作的临时状态，不混入永久角色属性，也不写回编辑态底稿。进入运行态时会记录 Token 的编辑态 `global_transform`，切回编辑态或切场景前恢复；运行态拖动不标记场景未保存。按下拖动时自动固定起点，松手提交，不增加可见的开始/结束按钮。完整轮次系统后置；P2.2 不自动判断 GM 是否允许同一 Token 再执行一条移动命令。

`snap_to_grid`（吸附网格）不属于 Token 永久 schema。旧字段仅以 `@export_storage` 兼容旧场景反序列化，P2.2 移动逻辑明确忽略它。

### CprTokenProperties

| 字段 | 类型 | 阶段 | 说明 |
|---|---|---|---|
| `move_stat` | `int` | P2.2 | CPR MOVE（移速），由 GM 在编辑属性面板填写。Gvtt 新建/补挂组件的模板默认值为 `5`，一次基础移动命令预算为 `move_stat × 2` 米/码，因此默认可移动 10 米/码。默认 5 是本项目模板选择，不是 CPR 规定所有角色必须相同。 |

`ModuleManifest.ruleset_id` 当前默认 `cpr`。以后换规则集时新增对应规则组件和 `MovementRuleProvider`（移动规则提供器），不修改通用 `TokenProperties`。

路线提交后的播放速度与拖动范围圈属于通用表现层，不进入 CPR schema：短路线保持基础 6 米/秒；只有按基础速度无法在 2 秒内走完时才提高本次速度，保证整条已提交路线最多播放 2 秒。按住 Token 开始拖动时显示以本次起点为圆心、规则预算为半径的基础距离圈；默认 `MOVE=5` 时半径为 10 米/码。超距时只显示并提交预算内路线，不再让圈外完整路线追随鼠标；无障碍直线移动停在线与圆周的交点，绕墙、困难地形和攀爬会因实际耗费更高而提前停在圈内。Token 模型统一约定本地 `+Z` 为正面，移动时只按水平路线方向旋转，坡地不让模型前后倾斜。

规则依据：

- 《赛博朋克 RED 核心规则书》PDF p.144（书内 p.126）：现实化移动每回合获得一次移动动作，移动上限为 MOVE × 2 米/码；网格模式移动 MOVE 格，可斜向移动；每格代表 2 米/码。
- 《赛博朋克 RED 核心规则书》PDF p.145（书内 p.127）：每回合一次移动动作和一次其他动作；“跑”消耗其他动作，再获得一次移动动作。
- 《赛博朋克 RED 核心规则书》PDF p.187（书内 p.169）：游泳、攀爬、助跑跳跃每移动 1 米消耗 2 米移动距离。
- 对应结构化来源：`docs/cpr_reading/agent_index/agent_chunks.jsonl`，相关块均为 `needs_pdf_check=false`。

说明：生命值、通用行动点、命中、伤害和职业技能继续后置；CPR `MOVE` 不再后置，因为没有它就无法实现用户定义的 Token 移动。

## 五-A、TraversalProperties

这是地形、墙、汽车、箱子、交互物体等都可挂的可选几何组件，不属于某个规则集。

| 字段 | 类型 | 阶段 | 说明 |
|---|---|---|---|
| `traversal_mode` | `TraversalMode` | P2.2 | `WALKABLE`、`BLOCKED`、`DIFFICULT`、`CLIMB`、`JUMP`、`SWIM`。 |
| `link_start` | `Vector3` | P2.2 接口 | 攀爬/跳跃连接起点，物件本地坐标。普通属性面板暂不编辑。 |
| `link_end` | `Vector3` | P2.2 接口 | 攀爬/跳跃连接终点，物件本地坐标。 |
| `link_bidirectional` | `bool` | P2.2 接口 | 连接是否双向。 |

默认：地形为 `WALKABLE`；墙、装饰和交互物体为 `BLOCKED`；Token 和光源不参与静态导航烘焙。CPR 提供器把困难、攀爬、跳跃、游泳解释为双倍移动耗费；其他规则集可给同一标签不同解释。

## 六、WallProperties

墙体负责 P2 的“挡不挡、破不破、破了以后状态怎么变”。

建议字段：

| 字段 | 类型 | 阶段 | 说明 |
|---|---|---|---|
| `wall_state` | `WallState` | P2.6 | `INTACT`、`DAMAGED`、`DESTROYED`。 |
| `destructible` | `bool` | P2.6 | 是否可被 GM 触发破坏。 |
| `durability_max` | `int` | P2.6 | 最大耐久。对应旧 `max_hp`，但命名改为耐久。 |
| `durability_current` | `int` | P2.6 | 当前耐久。P2 可手动改，不做自动伤害公式。 |
| `blocks_los` | `bool` | P2.5 | 是否挡视线。对应旧 `los_occluder`。 |
| `blocks_shot` | `bool` | P2.4 | 是否挡枪线/射击线。 |
| `cover_level` | `CoverLevel` | P2.4 | `NONE` 或 `FULL`，先不做半掩体。 |

破坏最小闭环：

1. GM 点击墙体，运行态面板显示“破坏/修复/状态”。
2. 墙体进入 `DESTROYED`。
3. 分别以 `wall_state != DESTROYED && blocks_los` 和 `wall_state != DESTROYED && blocks_shot` 推导运行态有效遮挡；不得覆盖两个基础字段。
4. 墙体状态和基础字段都能保存、加载后仍一致；修复后按原始基础字段恢复有效遮挡。

后置：

- Mesh 碎裂
- 碎块物理
- 材质硬度
- 伤害类型
- 自动扣耐久公式

## 七、LightProperties

光源在 P2.3 只做运行态开关和基础参数入口，不等同于 P3 场景气氛系统。

建议字段：

| 字段 | 类型 | 阶段 | 说明 |
|---|---|---|---|
| `is_on` | `bool` | P2.3 | 运行态开关状态，必须保存/加载。 |
| `light_kind` | `LightKind` | P2.3 | `OMNI` 点光源优先落地；`SPOT` 聚光源可预留。先不把 `DirectionalLight3D` 当普通物件灯，因为它更像全局太阳/环境光。 |
| `color` | `Color` | P2.3 | 光色。 |
| `energy` | `float` | P2.3 | 亮度入口，对应 Godot `Light3D.light_energy`。 |
| `light_range` | `float` | P2.3 | 范围入口，对应 `OmniLight3D.omni_range` 或 `SpotLight3D.spot_range`，避开 GDScript 内置 `range()` 同名警告。 |
| `casts_shadow` | `bool` | P2.3 | 是否投影。 |

可视标记：内置点光源没有模型外观，编辑态用 `PickProxyMarker` 灯泡图标作为 GM 灯位锚点。实现对照 Godot 4.7 `Light3DGizmoPlugin`：使用同源 `GizmoLight.svg`，通过 `Sprite3D.billboard = BILLBOARD_ENABLED` 始终朝向相机，通过 `SpriteBase3D.fixed_size = true` 保持固定屏幕尺寸；图标色相/饱和度跟随 `LightProperties.color`，亮度提满以保证暗色灯仍可辨认。图标走 GM-only 渲染层，只在编辑态主窗口可见，运行态和投屏不显示；真实照明仍由 `RuntimeLight` 里的 Godot `OmniLight3D` 提供。图标节点标记为 `gvtt_runtime_only`，不参与场景保存和拾取盒 AABB 计算。

后置：

- `DirectionalLight3D` 方向光/太阳光，归到全局场景光照或 P3 气氛系统，不作为普通可拖放光源物件。
- 雾和环境光联动
- 场景气氛预设
- 闪烁动画曲线
- 魔法光源规则效果

## 八、InteractableProperties

交互物体在 P2 只做 GM 触发入口，不做自动规则。

建议字段：

| 字段 | 类型 | 阶段 | 说明 |
|---|---|---|---|
| `enabled` | `bool` | P2.1 | 是否可触发。 |
| `interaction_label` | `String` | P2.1 | 按钮显示名，如“打开”“触发”“关闭”。 |
| `interaction_state` | `InteractionState` | P2.1 | `IDLE`、`ACTIVE`、`DISABLED`。 |
| `trigger_mode` | `TriggerMode` | P2 或后置 | `MANUAL` 为 P2 默认；自动触发后置。 |

后置：

- 技能检定
- DC/难度值
- 需要钥匙/道具
- 伤害、爆炸、燃烧、打翻火盆、电箱爆炸等具体效果。后续应以效果载荷/效果 ID 表达伤害，交给所选规则集解释，不能把 CPR 伤害公式写死在 `InteractableProperties`。
- 自动给 Token 加状态
- 脚本化机关链

## 九、组件边界

### PickProxy

只负责点击选中。它可以用更宽容的 AABB 拾取盒，因为点击选中允许容错。

禁止把以下逻辑塞进 `PickProxy`：

- 挡枪线
- LOS/战争迷雾
- 破坏状态
- Token 移动规则
- 光源开关

### CombatBody

负责射击线/子弹线的几何遮挡。它读 `WallProperties.blocks_shot` 和 `cover_level`，但不计算命中率、伤害、武器规则。

它使用 `OcclusionGeometry` 从真实模型得到物件根局部边界，再创建独立战斗物理体。物件旋转时保留局部盒方向；物件缩放会烘进 `BoxShape3D.size`，避免让碰撞形状继承非均匀缩放。`PickProxy` 的 AABB 不参与该流程。每次放置/读回墙体、交互物体、地形、装饰都会生成候选 CombatBody；Token 和光源不创建。候选体按真实视觉高度自动分类：严格高于 `1.0` 米进入第 21 战斗层，低于或等于 `1.0` 米不挡枪。

`local_bounds_position/local_bounds_size` 始终保存真实视觉边界。运行 `BoxShape3D` 也保留真实高度，不再补到 `1.8` 米。`provides_full_cover=true` 表示该对象通过高度阈值，战斗线会额外使用随物件旋转的 XZ 地面占用框做二元挡线判断；因此高于汽车车顶的临时测试线，只要水平投影穿过汽车粗框，也会被判定为被掩体挡住。

复杂静态资产当前采用用户确认的临时保守语义：整车视觉边界盒都算战斗遮挡，破窗、空舱和打开部件不会自动形成洞。以后增加人工低多边形战斗部件时，只替换 CombatBody 的形状来源，不改变第 21 层和 `CombatLineQuery` 查询合同。

挡枪线统一调用：

```gdscript
CombatLineQuery.cast(world, from, to, exclude)
```

- `world`：当前 `World3D`。
- `from` / `to`：射击线三维起点与终点。
- `exclude`：可选的 `Array[RID]`，用于排除调用方指定的战斗体。
- 返回字典固定包含 `blocked`、`position`、`normal`、`collider`、`combat_body`、`entity`、`shape`、`rid`。
- 查询只扫描 `COMBAT_PHYSICS_LAYER`，`collide_with_bodies=true`、`collide_with_areas=false`，因此不会命中 `PickProxy`。
- 调用方应在物理帧安全时机执行；接口只报告几何遮挡，不解释命中、掩体加值、武器穿透或伤害。

### LOSOccluder

负责视线遮挡。P2.5 已落地为墙体子组件；它读 `WallProperties.blocks_los`，破坏后关闭输出但保留组件。它不参与射击命中、伤害或 Token 规则。

当前实现复用 `OcclusionGeometry` 已提供的物件根局部边界，只负责把它投影成世界 XZ 地面遮挡轮廓并交给场景级 `LOSService`；不复用 `CombatBody` 的物理体或战斗射线接口，也没有第二套模型扫描实现。P2.5 只给墙体挂该组件，其他物件类型后续必须有明确 LOS 语义后才能加入。

`LOSService` 保存当前选中或正在移动的 Token 引用，以该 Token 的世界 XZ 坐标作为唯一玩家观察点，再按地图矩形和全部墙段计算活动边可见多边形。启动尚未选择时以场景树第一个 Token 回退；选择非 Token 或空地不清除当前观察源，当前观察 Token 删除后顺延到下一个，没有 Token 时关闭迷雾计算。主窗口与投屏遮罩消费同一最终世界多边形；计算、相机投影和显示三者分离。`WallProperties.set_blocks_los()` 发出基础语义变化信号；P2.6 墙体破坏/修复必须从 `wall_state != DESTROYED && blocks_los` 推导有效值并驱动 `LOSOccluder`，不能覆盖基础字段。

### OcclusionGeometry

无状态共享几何工具。它只扫描真实 `GeometryInstance3D`，跳过标记为 `gvtt_runtime_only` 的运行时节点，把各网格 AABB 折回物件根局部空间后合并。P2.4 消费三维局部盒，P2.5 消费同一局部边界并生成二维地面轮廓；工具本身不决定“挡枪”或“挡视线”。

### MovementService

只负责通用几何：运行态生成独立导航图、查询绕障碍路线、贴合地形高度、绘制路线、按 Token 体积扫掠防穿模、沿路线移动。它不读取 CPR MOVE，也不判断回合或行动是否已经用过。

当前几何边界：

- 墙体、汽车等非地形阻挡物在每次移动服务重建时只计算一次物体根局部 AABB（轴对齐包围盒），并缓存该结果。导航脚印与运行态 `BoxShape3D`（盒形碰撞体）都读这份缓存，同时保留物体旋转和根缩放，不再把旋转后的物体塞进更肥的世界轴对齐方盒。
- 地形、坡面和台阶继续使用三角网格碰撞，不能改成盒形，否则会丢失高度和斜面。
- 橙色选择 Gizmo（操纵框）与移动服务使用等价的“模型边界折回物体根局部坐标”算法，但两边目前各自计算；不能写成直接共用同一个缓存。选择框负责编辑显示，移动缓存负责导航与运行态碰撞。
- Token 体积来自各自 `TokenProperties.collision_radius/collision_height`，不会根据可见模型胖瘦自动猜测。导航源几何每次重建只解析一次，再按量化后的 `(radius, height)` 体型键按需烘焙并缓存导航图。
- 导航精度为水平 `cell_size=0.1` 米、垂直 `cell_height=0.25` 米。默认 `0.45 × 1.8` 米 Token 量化为 `0.5 × 2.0` 米导航档；胶囊扫掠若在墙角否决基础路径，才额外尝试半径增加 `0.2` 米的安全档，不为每次鼠标移动重算所有边界或重烘焙所有体型。
- 每张缓存导航图复制同一组攀爬/跳跃连接；退出运行态、切场景或重建时显式释放地图与区域 RID（资源标识符）。
- `MovementService` 只移动当前运行态节点；编辑态底稿隔离由 `main.gd` 的运行态 Token 快照/恢复入口负责，不塞进移动服务，避免通用几何服务反过来拥有场景保存语义。

### MovementRuleProvider

只负责规则解释：给出本次预算和不同通行标签的耗费。`CprMovementRuleProvider` 当前读取 `CprTokenProperties.move_stat`，以后换模组应新增提供器，不修改 `MovementService`。

### RuntimeActionPanel

运行态操作面板按 `entity_type` 和专属组件显示当前状态，并且只为已经落地的操作生成按钮：

- Token：显示 MOVE、预算和状态；移动继续直接拖动，不增加重复的移动按钮；P2.5 自动使用当前选中/移动 Token 作为 LOS 观察点，不增加 Token 视点按钮
- 墙体：显示状态；P2.6 已加入破坏/修复按钮，状态会同步 LOS（视线遮挡）与挡枪线并保存读回
- 光源：显示状态；P2.3 已加入运行态开关按钮，状态会保存读回并驱动真实 `Light3D`
- 交互物体：只显示当前已有状态；触发/启用按钮随对应功能一起出现
- 地形/装饰：基础查看/可见性

射击线、墙体破坏和光源开关只在对应基础功能已落地时显示真实按钮；技能仍不放空按钮占位。

## 十、Godot 4.7 源码对照卡

本节只作为 P2.0 设计对照。后续真正写运行态选择、组件挂载、CombatBody、LOSOccluder 前，仍需按具体任务补更完整的源码对照卡；用户已经明确功能目标时，对照卡公开后直接继续实现，不重复索要固定确认口令。

### 1. 要复刻的行为链

完整链路：

1. 鼠标点到 3D 视口。
2. 从屏幕点发射 3D 射线。
3. 命中可选对象。
4. 找到对象节点。
5. 更新当前选中对象。
6. 属性面板绑定当前对象。
7. 用户修改字段。
8. 保存场景时，组件随对象一起持久化。

### 2. Godot 源码版本

源码标签：`4.7-stable`

项目版本依据：`project.godot` 中 `config/features=PackedStringArray("4.7", "Forward Plus")`。

### 3. Godot 源码文件、类、函数

| 行为 | Godot 源码 | 关键函数 |
|---|---|---|
| 3D 视口选中 | `editor/scene/3d/node_3d_editor_plugin.cpp` | `Node3DEditorViewport::_select_ray()`、`_find_items_at_pos()`、`_select_clicked()` |
| 当前选中集 | `editor/scene/3d/node_3d_editor_plugin.cpp` | `editor_selection->clear()`、`editor_selection->add_node()`、`EditorNode::edit_node()` |
| 检查器属性面板 | `editor/inspector/editor_inspector.cpp` | `EditorInspector::update_tree()`、`EditorInspectorPlugin::parse_property()` |
| 节点挂载 | `scene/main/node.cpp` | `Node::add_child()`、`Node::set_owner()` |
| 场景打包保存 | `scene/resources/packed_scene.cpp` | `SceneState::_parse_node()`、`PackedScene::pack()` |

### 4. Godot 阶段拆解

| 阶段 | Godot 做法摘要 |
|---|---|
| 选中 | 3D 视口用射线找命中对象，再写入编辑器选中集。 |
| 属性显示 | 检查器遍历对象属性，并允许插件按属性生成编辑器控件。 |
| 挂载 | 子节点必须 `add_child()` 到父节点；`owner` 必须是祖先节点，否则无效。 |
| 保存 | `PackedScene` 只保存 root 与被 root 拥有的子节点。 |
| 清理 | 节点移出树或 owner 不一致时，Godot 会清理或警告 owner 问题。 |

### 5. 本项目对应关系

| Godot 行为 | 本项目文件/函数 | 对应策略 |
|---|---|---|
| 屏幕点转射线 | `scripts/main.gd::_try_select_at_mouse()` | `Camera3D.project_ray_origin/project_ray_normal` 发射射线。 |
| 命中对象 | `scripts/main.gd::_try_select_at_mouse()` | `PhysicsDirectSpaceState3D.intersect_ray()` 查 `PickProxy` 所在物理层。 |
| 找选中根 | `scripts/main.gd::_find_entity_root()` | 从命中的 `Area3D` 往上找挂 `EntityProperties` 的物件根。 |
| 设置选中 | `scripts/main.gd::_select_entity()` | 绑定 gizmo，并让属性面板显示当前对象。 |
| 挂组件 | `scripts/main.gd::_place_model()` | 物件根下挂 `EntityProperties` 与 `PickProxy`，后续再挂专属组件。 |
| 保存组件 | `scripts/main.gd::_place_model()` + `ModuleGate.save_current_scene()` | 组件必须设置 `owner=_content_root` 才会随场景保存。 |

### 6. 无法照搬的差异

Godot 编辑器的选中对象是编辑器节点本身；本项目面向 GM 运行工具，不能暴露 Godot 编辑器检查器。因此只能复刻“射线命中、选中集、属性面板绑定”的行为链，而不是直接使用 Godot 编辑器的 `EditorInspector`。

Godot 的属性系统来自对象反射；本项目为了让 GM 面板更简单，建议手工按 `entity_type` 和组件生成面板。

### 7. 验证方法

| 行为 | 自动测试/运行态验证 |
|---|---|
| 类型分派 | 放置 6 类素材，检查对象根的 `EntityProperties.entity_type` 与专属组件是否匹配。 |
| 旧字段迁移 | 载入旧存档，检查旧 `max_hp/los_occluder/cover_level/destructible` 是否迁入墙体组件。 |
| 选择面板 | 运行态点击 Token/墙/灯/交互物体，检查面板按钮只显示对应操作。 |
| 保存加载 | 保存、重启、加载后检查专属组件字段不丢。 |
| 投屏隔离 | GM-only 字段和 GM 控件不出现在投屏窗口。 |

### 8. P2.2 移动源码映射（已落地）

源码标签：`4.7-stable`，本地来源 `reference/godot-4.7-stable-full.zip.zip`。

| Godot 4.7 行为 | 源码位置 | 本地实现 | 验证 |
|---|---|---|---|
| 地形 Mesh（网格）生成三角碰撞 | `scene/3d/mesh_instance_3d.cpp::create_trimesh_collision_node()`、`scene/resources/mesh.cpp::Mesh::create_trimesh_shape()` | `movement_service.gd::_add_mesh_collisions()` 只为地形保留精确三角面 | 坡面和台阶路线保持真实高度 |
| 模型局部边界生成盒形碰撞 | `editor/scene/3d/mesh_instance_3d_editor_plugin.cpp::MeshInstance3DEditor::create_shape_from_mesh()` 的边界框模式读取 `Mesh.get_aabb()` 并创建 `BoxShape3D`；`scene/3d/mesh_instance_3d.cpp::MeshInstance3D::get_aabb()` 返回模型局部边界 | `_get_cached_local_bounds()` 每次重建只计算一次非地形物体局部边界，`_add_bounds_collision()` 与 `_create_navigation_obstacle()` 共用缓存并保留旋转/缩放 | 4×1 米旋转阻挡物的运行碰撞为同尺寸 `BoxShape3D`，导航轮廓同尺寸同旋转 |
| 解析一次、按体型烘焙多张导航图 | `godot_navigation_server_3d.cpp::parse_source_geometry_data()`、`bake_from_source_geometry_data()`；`nav_mesh_generator_3d.cpp` | `MovementService.rebuild()` 保存一份 `_source_geometry_data`，`_create_navigation_profile()` 按 `(radius, height)` 建图并写入 `_navigation_profiles` | 默认与肥大 Token 产生两张缓存图；默认可过 1.5 米净宽，肥大 Token 不会错误借用该通道 |
| 路径查询与元数据 | `GodotNavigationServer3D::query_path()`、`NavMeshQueries3D::map_query_path()` | `_query_preview_to_target()` | 墙体两侧路线长度大于直线且终点到达目标 |
| 障碍轮廓与挖空 | `navigation_obstacle_3d.cpp::navmesh_parse_source_geometry()` 读取局部 `vertices`，应用节点缩放、Y 轴旋转和世界位置；`modules/navigation_3d/3d/nav_mesh_generator_3d.cpp` 用 `rcErodeWalkableArea()` 按 `agent_radius` 侵蚀可走区 | `_create_navigation_obstacle()` 读取缓存局部边界生成四点轮廓；导航档使用 `0.1` 米水平、`0.25` 米垂直量化，真实胶囊扫掠否决时才查询额外 `0.2` 米安全半径档 | 默认 Token 可过 1.5 米净宽；肥大 Token 走独立图；墙角路径通过真实胶囊扫掠复核 |
| 攀爬/跳跃连接 | `navigation_link_3d.cpp` 的注册、端点、双向和耗费设置 | `_create_navigation_link()` | 标签与双倍耗费自动测试；连接点场景专项测试后续补 |
| 体积扫掠 | `shape_cast_3d.cpp::_update_shapecast_state()`、Jolt `cast_motion()` | `_apply_clearance_limit()` | 路线不会在墙角穿模或提前截停 |
| 区域同步 | `nav_region_3d.cpp::_build_iteration()`；地图和区域各有独立异步开关 | 独立导航图关闭异步迭代后同步提交 | 修复“资源有多边形但服务器边界为零”，当前完整运行回归保持全通过 |
| 模型正面朝向移动方向 | `scene/3d/node_3d.cpp::Node3D::look_at()/look_at_from_position()` → `core/math/basis.cpp::Basis::looking_at()` → `core/math/transform_3d.cpp::Transform3D::looking_at()`；`use_model_front=true` 使本地 `+Z` 指向目标并保留原缩放 | `MovementService._face_movement_direction()` 清除高度分量后调用 `look_at(..., Vector3.UP, true)` | 短程、长坡、零长度路线测试确认 `+Z` 朝向、保持直立且原地不乱转 |
| 路线播放时长封顶 | Godot 每帧移动仍采用距离与 `delta` 推进；2 秒是 Gvtt 表现层要求，不冒充 Godot 或 CPR 原规则 | `commit_preview()` 统计整条路线长度，`_calculate_follow_speed()` 取基础速度与 `路线长度 / 2秒` 的较大值，`_stop_path_following()` 恢复基础速度 | 20 米带高差路线在四次 0.5 秒推进后准确到达；短程仍保持 6 米/秒 |
| 拖动范围圈 | `scene/resources/immediate_mesh.cpp::surface_begin()/surface_add_vertex()/surface_end()` 把简单动态几何提交给 `RenderingServer`；`clear_surfaces()` 清理渲染表面和暂存顶点 | `MovementService._draw_range_ring()` 用独立 `MovementRangePreview` 绘制 64 段闭合线，`begin_preview()` 创建显示，`clear_preview()` 清理；`clear_preview_path()` 不碰范围圈 | 默认 10 米半径、65 个闭合顶点、运行态标记、路线清空仍保留、结束拖动后消失均有运行回归 |
| 超距终点与预览统一 | `core/math/vector3.h::Vector3::distance_to()` 计算路线段长度，`Vector3::lerp()` 按剩余预算比例得到段内边界点 | `MovementRuleProvider.truncate_path()` 生成预算内路线；`MovementService._draw_preview()` 只绘制该路线；`commit_preview()` 提交同一条路线 | 20 米直线目标/10 米预算时，预览终点、圆周交点和 Token 最终位置一致，预览没有圈外顶点 |
| RID 清理 | `scene/main/node.cpp::Node::_propagate_exit_tree()` 在子节点退出后调用脚本 `_exit_tree()`；`NavigationRegion3D/NavigationLink3D` 析构释放节点自有 RID；手动创建 RID 由 `NavigationServer3D.free_rid()` 销毁 | `MovementService._exit_tree()` 兜底调用 `_clear_navigation_runtime()`，断开连接后显式释放独立区域和所有缓存地图 | 129 项运行回归包含销毁后地图列表检查；进程退出无 `NavMap3D/NavRegion3D` 泄漏 |

## 十一、离线 Godot 文档依据

- `gdd_0255_Ray-casting.md`：3D 射线查询、`collide_with_areas`、`collision_mask`。
- `gdd_0540_Camera3D.md`：`project_ray_origin()`、`project_ray_normal()`。
- `gdd_0673_Node3D.md`：3D 节点、transform 更新与 `force_update_transform()`。
- `gdd_1006_PackedScene.md`：`PackedScene.pack()` 只保存 root 和 root 拥有的子节点。
- `gdd_0641_Light3D.md`：光源通用参数。
- `gdd_0675_OmniLight3D.md`：点光源范围。
- `gdd_0742_SpotLight3D.md`：聚光灯范围与角度。
- `gdd_0751_SpriteBase3D.md`：灯位图标的 `billboard`、`fixed_size`、`no_depth_test`、`pixel_size` 与颜色调制。
- `gdd_0864_BaseMaterial3D.md`：`BILLBOARD_ENABLED` 与固定屏幕尺寸材质行为。
- `gdd_0225_Support_different_actor_types.md`：同一份源几何可解析一次，再为不同角色体型烘焙独立导航图。
- `gdd_0216_Using_navigation_meshes.md`、`gdd_0981_NavigationMesh.md`：导航网生成、角色半径和网格精度参数。
- `gdd_0558_CollisionShape3D.md`：运行态碰撞形状节点边界。

## 十二、迁移原则

旧存档兼容必须先于功能扩展。

建议迁移规则：

1. 读取旧对象时，如果只有 `EntityProperties.category`，按旧 `category` 推导 `entity_type`。
2. 如果旧对象是 `wall`，把旧 `destructible/max_hp/cover_level/los_occluder` 迁入 `WallProperties`。
3. 如果旧对象不是 `wall`，先保留旧字段但不在新面板里显示，避免误删用户数据。
4. 新保存的对象使用 `schema_version >= 2`。
5. 迁移必须有自动验证，不能只靠打开场景无红字。

## 十三、风险清单

| 风险 | 说明 | 处理 |
|---|---|---|
| 旧存档迁移 | 旧字段在 `EntityProperties`，新 schema 要拆到专属组件，读回时可能丢语义。 | 先写迁移表，再写功能。 |
| 字段命名误导 | 墙的 `max_hp` 算法像生命值，但业务上是耐久。 | 墙体改用 `durability_max/current`，Token 生命值后置。 |
| 万能字段桶 | 如果继续往 `EntityProperties` 加字段，灯、墙、Token 会互相污染面板。 | 通用字段只保留身份/可见性，类型字段进专属组件。 |
| 规则系统边界混淆 | 把所有规则辅助都禁止，会导致 MOVE 移动无法实现；反过来把 MOVE 扩成整套自动战斗也会让 P2 失控。 | P2.2 只实现经 CPR 查证的 MOVE 范围辅助；技能、命中、伤害与完整轮次自动化继续后置。 |
| 导航生成卡顿 | 运行态进入时同步烘焙，超大或高面数场景可能出现等待。 | 当前优先保证同帧可查询；后续实测大场景后再做分块缓存，不能先牺牲正确性。 |
| 标签边界近似 | 困难/游泳区域当前按路线段中点识别，跨越很小区域时可能低估耗费。 | P2 测试标签可用；精确区域切分作为后续规则移动增强。 |
| 多体型导航缓存 | 当前会按实际出现的 `(collision_radius, collision_height)` 体型按需烘焙并缓存导航图；体型种类过多会增加首次查询时间和内存。 | 同尺寸复用同一张图，源几何只解析一次；后续只在真实模组出现大量不同尺寸时增加缓存上限或预热，不先牺牲正确性。 |
| Token 外形与体积不一致 | 肥大或细长模型不会自动改碰撞体；系统读取该 Token 自己保存的半径和高度。 | 导入或编辑 Token 时由 GM 设置 `collision_radius/collision_height`；未来可做“从模型边界建议体积”，但不能静默覆盖用户配置。 |
| 凹形阻挡物 | 当前导航脚印使用物体根局部 AABB，能正确跟随旋转，但 L 形、U 形等凹模型仍会按保守矩形占用。 | 后续增加可选的手工导航轮廓或多凸形组件；不在运行时对所有模型做昂贵的三维凸分解。 |
| PickProxy 复用诱惑 | 用拾取 AABB 顺手挡枪线/挡视线会误判旋转物件。 | 战斗层和 LOS 层必须独立。 |
| 投屏泄漏 | GM-only 信息或操作按钮可能出现在玩家投屏。 | 验证投屏窗口只显示 3D 结果，不显示 GM 控件。 |

## 十四、P2.0 交付判定

P2.0 完成条件：

- 本 schema 被确认。
- `EntityProperties` 通用字段边界确定。
- 四类专属组件字段确定。
- 旧字段迁移策略确定。
- P2 与后置规则系统边界确定。
- 下一步功能实现前，针对具体行为提交更细的 Godot 4.7 源码对照卡；目标已明确时提交后直接实现，不再重复确认普通文件修改。
### CombatLinePreview（运行时唯一实例，不保存）

旧 `CombatLineProbe`（每个 Token 一条固定 10 米方向线）已撤回并删除。新的 `CombatLinePreview` 只在 `Main` 下创建一个运行时实例，不挂到 Token，不设置场景 owner（归属节点），并固定使用 GM-only 第 20 渲染层。

| 输入/行为 | 类型 | 说明 |
|---|---|---|
| 射手 | `Node3D` | 当前选中的 Token；起点为视觉模型顶部向下 `1/9`，无视觉边界时回退到 `collision_height × 8/9` |
| 测试终点 | `Vector3` | 鼠标只决定水平世界方向，固定为起点外 20 米；不吸附实体、地面或地图边缘 |
| 排除列表 | `Array[RID]` | 排除射手的战斗物理体；不排除真正的环境 CombatBody |
| 无遮挡显示 | 青色整线 | 只表示 20 米测试线内未命中登记的战斗遮挡 |
| 有遮挡显示 | 橙色命中段 + 灰色余段 | 橙色终点是第一个 CombatBody 命中点，灰色继续标出测试余段 |
| 可见性 | `bool` | 继续读取 `TokenProperties.can_show_aim_line`；只影响显示，不改变查询 |
| 输入模式 | 持续瞄准 | 选中 Token 后左键独占锁线，不执行 PickProxy 拾取；`Esc` 依次解锁、退出瞄准并恢复选择 |

查询仍统一调用 `CombatLineQuery.cast(world, from, to, exclude)`。接口只查第 21 战斗物理层的 PhysicsBody3D（物理体），不查 PickProxy 的 Area3D（区域体），返回 `blocked/position/normal/collider/combat_body/entity/shape/rid`。返回值只描述有限线段上的首个几何遮挡，不包含命中率、骰子、伤害、武器射程或穿透规则。

复杂资产当前采用保守粗框，不能宣称为精确材质碰撞；破窗、空舱和打开部件被整盒封住。高度只负责自动分类：`> 1.0` 米是掩体，`<= 1.0` 米不是掩体；真正挡线用旋转后的地面粗框，不再补高运行盒。车门/玻璃/引擎盖这类精细部件与材质识别不属于 P2.4 或 P2.5；未来只有在用户明确需要时，才另开 GM 手工标注低多边形战斗部件任务。P2.5 可以复用同一份源几何生命周期，但不能读取 CombatBody 运行物理体作为 LOS（视线遮挡）真值，也不能照搬战斗掩体的高度阈值。

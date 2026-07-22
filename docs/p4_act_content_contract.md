# P4.4 幕式内容管理合同

状态：2026-07-21 已确认，作为 P4.4 实现与验收依据。

## 一、产品定义

“幕”是 GM 在模组中反复查看和使用的第一层内容资料夹，不是 PPT、自动播放列表、剧情状态机或规则引擎。图片、视频、文本和地图都作为内容服务于幕；地图的加载和保存只是底层服务。

- 一幕可以没有地图，也可以引用一个或多个地点/战斗地图。
- 同一幕可以在一次或多次带团中反复使用；使用不会消耗、完成、锁定或改变幕。
- 幕之间没有剧情先后、解锁关系或自动推进；清单中的显示位置不表示故事顺序。
- 幕内条目可以排序；顺序只服务于整理、上一项/下一项和桌边查找，不表示剧情完成度。
- GM 可以随时选择任意条目投放或切换地点，不需要先完成前一项。
- 选择另一个幕只切换 GM 正在查看的资料夹，不自动改变地图、媒体或玩家输出。
- 幕只保存稳定标识引用，不复制、不移动、不改名原文件。
- 同一内容或地点可以被多幕复用；删除幕只删除这一组引用。

## 二、调研回执

| 层级 | 依据 | 采用结论 |
|---|---|---|
| 项目现状 | `ModuleManifest`、`ExternalContentRef`、`LocationRef`、`ModuleIo`、`ModuleGate`、`PlayerOutputController`、P4.1-P4.3 回归 | 全局内容和地点已有稳定标识；幕应只保存引用。媒体输出继续由 `PlayerOutputController` 唯一持有。 |
| Godot 4.7 源码 | `4.7-stable / 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`；`scene/gui/control.cpp`、`scene/gui/tree.cpp`、`editor/docks/filesystem_dock.cpp` | 采用“取得拖动数据 -> 验证落点 -> 提交重排”的交互顺序；不使用编辑器私有类。 |
| 官方资料 | Godot 4.7 `Control`、`Tree`、`ItemList`、`Button`、容器、tooltip（提示）与禁用状态离线文档 | 使用公开 `Control`/容器控件和明确的禁用、提示状态，不手写文件系统控件。 |
| 英文 VTT / 开源 | Foundry Scenes/Journal/Playlists/Folders、Roll20 Page Menu/Art Library、Tabletop Club asset packs | 内容类型分开管理，场景/页面建立引用；文件夹、搜索、排序和 GM 手动展示是共通模式，不采用强制时间线。 |

来源：

- <https://foundryvtt.com/article/scenes/>
- <https://foundryvtt.com/article/journal/>
- <https://foundryvtt.com/article/playlists/>
- <https://foundryvtt.com/article/folders/>
- <https://help.roll20.net/hc/en-us/articles/360039675413-Page-Menu-Folders>
- <https://help.roll20.net/hc/en-us/articles/360039675113-Art-Library>
- <https://docs.tabletopclub.net/en/stable/custom_assets/asset_packs/asset_pack_structure.html>

## 三、数据与所有权

```text
ModuleManifest
├── external_contents: Array[ExternalContentRef]
├── locations: Array[LocationRef]
└── acts: Array[ActRef]
    ├── act_id
    ├── display_name
    ├── gm_notes
    └── items: Array[ActItemRef]
        ├── item_id
        ├── item_type: media | text | location
        ├── target_id
        ├── display_name_override
        └── gm_notes
```

- `ModuleManifest` 持有幕定义；它属于可复用模组底本。
- `ActRef` 持有条目顺序，不持有文件字节或玩家输出状态。
- `ActItemRef.target_id` 对媒体指向 `ExternalContentRef.content_id`，对地点指向 `LocationRef.location_id`；文本条目使用自身稳定标识和内联纯文本。
- `Playthrough` 不保存当前幕、幕顺序、使用次数、历史、完成或解锁状态；正在查看哪个幕只是 GM 面板的临时状态。
- `PlayerOutputController` 继续唯一持有 MAP/IMAGE/VIDEO、加载阶段、暂停和音量状态。
- GM 面板只在内存中保存正在查看的幕和选中条目，不把它解释成剧情进度，也不因切换幕改变玩家输出。

## 四、权限与失败规则

| 行为 | 编辑态 | 运行态 |
|---|---|---|
| 创建、重命名、删除幕 | 允许 | 禁止 |
| 加入、移除、重排条目 | 允许 | 禁止 |
| 编辑文本和 GM 备注 | 允许 | 禁止 |
| 搜索、筛选、选中、预览 | 允许 | 允许 |
| 投放图片/视频、切换地图、返回地图 | 允许 | 允许 |
| 暂停/恢复、停止、音量 | 仅视频播放时允许 | 仅视频播放时允许 |

- 媒体或地点引用缺失时保留条目并显示“缺失”，不在加载时静默删除。
- 缺失条目禁止投放，但仍可移除或重新绑定。
- 详细路径、解析错误和堆栈只出现在 GM 侧；玩家窗口回到地图或保持安全输出。
- 玩家窗口节点树不得包含幕列表、搜索框、GM 备注、路径或管理按钮。

## 五、P4.4 范围

本阶段交付：

- 幕的创建、重命名、删除和持久化。
- 图片、视频、文本、地点条目的加入、移除、重排和跨幕复用。
- 搜索、类型/可用状态显示、GM 备注和任意条目快速投放。
- 上一项/下一项仅作为当前排序下的快捷选择，不自动投放。
- 同一幕可反复选择和投放；幕可以没有地图，幕之间没有顺序、完成或解锁语义。
- 状态与按钮禁用规则、玩家窗口隔离和 GM 侧错误提示测试。

本阶段不交付：

- 自动播放下一项、计时切换、条件分支或规则触发器。
- 剧情完成度、强制当前步骤或持久化故事状态。
- 当前幕、下一幕、幕历史、幕使用次数、完成/解锁状态或按幕自动切换玩家输出。
- 嵌套幕、复杂标签系统、批量文件搬运、物理目录同步。
- MP4/MOV/WebM 支持承诺；视频格式边界沿用 P4.3。

## 六、源码行为映射与验证

| Godot / 现有行为 | 本地实现 | 自动测试 / 可见验证 |
|---|---|---|
| `Control` 先取得拖动数据，再 `can_drop_data`，最后 `drop_data` | 幕列表只接受自身条目标识，校验幕和索引后提交候选清单 | 非法幕/索引不改清单；合法重排读回顺序一致 |
| `Tree.get_drop_section_at_position()` 区分项前、项上、项后 | 幕条目按目标索引插入，不移动真实文件 | 多次上移/下移、首尾和同索引测试 |
| `FileSystemDock` 搜索、排序、元数据和 tooltip（提示）分离 | 面板使用稳定标识元数据，显示名称/类型/状态，搜索只过滤视图 | 搜索不改变持久顺序；提示不暴露玩家端 |
| `ModuleIo` tmp -> 校验 -> bak -> 提交 | 幕 CRUD 复用候选清单和可恢复保存 | 旧 v1 清单迁移到 v2；保存失败不替换内存真值 |
| `PlayerOutputController` 唯一输出状态 | 幕面板只转发图片/视频/地图命令 | 玩家窗口无 GM 控件；播放状态与 P4.3 一致 |

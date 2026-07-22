# 资产整理清单

> 状态：2026-07-18 收口盘点。本文只整理现状和安全边界，不移动现有素材路径。

## 结论

- 项目运行时导入的 GM 素材不存进 `res://assets/`，而是由 `LibraryManager` 放到 `user://library/`，这样导出 Windows 便携包后仍可写。
- `assets/` 是内置随项目发布的素材区，当前主要包含默认地面贴图、建筑测试模型、建筑贴图和光源图标。
- `个人资产/` 是本地源素材和规则资料区。`docs/cpr_reading/` 的索引直接引用里面两本 PDF；因此不能直接改名、挪目录或批量清理。
- `2K_Gravel01/` 是独立地面纹理源包，目前没有被代码或主场景直接引用；若要纳入内置地面纹理，应复制到 `assets/textures/ground/gravel_01/` 后让 Godot 重新导入，而不是原地移动。

## 目录分工

| 目录 | 当前用途 | 处理口径 |
|---|---|---|
| `assets/textures/ground/uv_checker_4096_v2/` | 默认地面 UV 检测贴图，`scripts/main.gd` 直接引用 | 保留，属于内置发布素材 |
| `assets/lights/` | P2.3 光源图标和 Godot 图标许可 | 保留，属于内置发布素材 |
| `assets/models/` | 早期建筑测试模型与贴图 | 保留但后续可按栏位迁移到 `assets/terrain/`、`assets/props/` 或删除测试模型 |
| `assets/textures/buildings/` | 早期建筑贴图，与 `assets/models/textures/` 内容重复 | 待去重；去重前先确认 FBX 贴图引用是否仍依赖旧路径 |
| `assets/walls/`、`assets/terrain/`、`assets/props/`、`assets/tokens/`、`assets/interactables/`、`assets/vfx/`、`assets/environment/` | 正式栏位目录骨架 | 保留 `.gitkeep`，后续只放要随 exe 发布的精选素材 |
| `个人资产/` | 本地源素材、实验图、CPR 规则 PDF、已按 Token/地形/墙体/装饰/交互初步分类的源文件 | 不移动；后续只从这里复制精选 `.glb` 到运行时素材库或内置素材目录 |
| `2K_Gravel01/` | 未归档地面纹理源包 | 待人工决定是否复制为内置 `gravel_01` 地面纹理 |

## 已知重复

- `个人资产/` 根目录和 `个人资产/模型/...` 下存在同名破车、网行者等素材的重复副本。
- `assets/models/textures/` 与 `assets/textures/buildings/` 存在大量同名建筑贴图重复。
- `.import` 文件已由 Godot 生成，但 `.gitignore` 当前忽略全局 `*.import`；已有被跟踪的导入文件仍会显示变化，新导入文件默认不会进入版本库。

## 后续整理建议

- 先保留 `个人资产/` 作为源素材仓，不把它当正式发布素材目录。
- 需要随 exe 自带的素材，按对象类型复制到 `assets/walls/`、`assets/terrain/`、`assets/props/`、`assets/tokens/`、`assets/interactables/`。
- 需要 GM 临时导入的素材，继续通过软件左栏“导入”进入 `user://library/`。
- 去重 `assets/models/textures/` 和 `assets/textures/buildings/` 前，先用 Godot 打开四个 FBX 确认贴图引用路径，避免建筑变白。

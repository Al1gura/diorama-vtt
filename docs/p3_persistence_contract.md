# P3 模组与会话持久化合同

> 状态：2026-07-21 P3.1/P3.2 已实现并完成验证。当前正常工作流是一份模组底本、多份独立桌记录；界面不再提供手动“备份模组”，旧 `_backups/` 只保留兼容读取与校验。四层调研与 Godot 4.7 源码对照已完成。

## 一、目标与边界

本合同解决：

- 模组清单关闭程序后可真实读回。
- 模组、地点和带团会话拥有与显示名/文件名无关的稳定标识。
- 旧 `_canonical/*.scn` 模组无需用户重建即可迁移。
- 清单损坏、写入中断、未来版本和缺失场景都有明确结果。
- 模组底本与一次带团会话分开保存。

本合同不解决正式媒体库、楼层、长期迷雾或完整带团快照；它们以后向同一版本化结构增加字段。

## 二、磁盘目录

```text
user://modules/<本机目录名>/
├── manifest.json                 # 模组底本清单
├── manifest.json.bak             # 上一份已验证清单
├── manifest.json.tmp             # 写入中间态，正常完成后不存在
├── _canonical/
│   ├── <旧文件名>.scn            # 迁移时保留，不强制重命名
│   └── <location_id>.scn         # 新地点默认使用稳定标识命名
├── _backups/                      # 旧版手动恢复点；保留已有数据，不再由界面创建
│   ├── objects/<sha256>
│   └── snapshots/<backup_id>.json
└── sessions/
    └── <session_id>/
        ├── session.json          # P3.2 最小带团会话
        ├── session.json.bak
        ├── session.json.tmp
        └── states/
            ├── <location_id>.scn
            ├── <location_id>.bak.scn
            └── <location_id>.tmp.scn
```

目录名只是本机入口，不是业务标识。模组复制、重命名或导入后，内部引用只依赖 `module_id/location_id/session_id`。

## 三、稳定标识

- 格式：32 个小写十六进制字符。
- 生成：`Crypto.new().generate_random_bytes(16).hex_encode()`。
- 不使用 `ResourceUID.create_id()`：该 API 用于工程资源 UID 与路径注册，保证范围是当前已加载 UID 列表，不是可复制用户模组的产品身份。
- 加载时必须验证长度和字符范围；空值、重复值或非法值按结构损坏处理。
- 显示名可以修改，不重新生成稳定标识。

## 四、manifest.json

第一版结构：

```json
{
  "format": "gvtt_module_manifest",
  "schema_version": 1,
  "module_id": "0123456789abcdef0123456789abcdef",
  "module_name": "开发测试模组",
  "start_location_id": "11111111111111111111111111111111",
  "ruleset_id": "cpr",
  "notes": "",
  "locations": [
    {
      "location_id": "11111111111111111111111111111111",
      "display_name": "镇广场",
      "canonical_relpath": "_canonical/旧文件名.scn"
    }
  ],
  "external_contents": [
    {
      "content_id": "22222222222222222222222222222222",
      "content_type": "image",
      "display_name": "线索图",
      "source_kind": "external_file",
      "source_path": "C:/Users/GM/Pictures/clue.png",
      "metadata": {}
    }
  ]
}
```

约束：

- `format` 必须精确匹配，防止把其他 JSON 当清单。
- `schema_version` 必须是正整数。
- `module_id`、所有 `location_id` 必须合法且互不重复。
- `start_location_id` 必须为空或引用现有地点。
- `ruleset_id` 第一版允许 `cpr`；未知值保留但运行规则回退必须显式提示。
- `locations` 保持清单顺序。
- `canonical_relpath` 必须是模块目录内相对路径，规范化后仍位于 `_canonical/`，禁止 `..`、绝对路径和目录逃逸。
- 场景文件缺失不等于清单损坏：保留该地点并标记缺失，允许模组其他地点打开。
- `external_contents` 中 `content_id` 必须合法且唯一；类型只允许 `image/video`，路径按 `external_file/module_relative` 分别校验。文件缺失保留引用并标记不可用，不把大文件写进清单。
- 未识别字段读取时保留在原始字典或明确忽略；写回策略由对应版本迁移定义，不能静默改写未来版本。

## 五、内存映射

### ModuleManifest

- `const SCHEMA_VERSION: int = 1`
- `schema_version: int`
- `module_id: String`
- `module_name: String`
- `locations: Array[LocationRef]`
- `start_location_id: String`
- `notes: String`
- `ruleset_id: StringName`
- `external_contents: Array[ExternalContentRef]`

旧 `start_location` 显示名字段只作为迁移输入，完成迁移后不再是真值。

### LocationRef

- `location_id: String`
- `display_name: String`
- `canonical_relpath: String`
- `canonical_path: String` 为运行时计算结果，不直接作为跨机器持久引用。
- `available: bool` 为运行时状态，用于缺失引用提示，不写回清单。

## 六、安全写入

`ModuleIo` 提供一种通用的“可恢复写入”，但不虚称 Windows 上绝对原子：

1. 把完整 JSON 写入同目录 `.tmp`。
2. 关闭文件并重新读取 `.tmp`。
3. 比较字节，并执行 JSON/领域结构校验。
4. 若正式文件存在，复制为 `.bak`；先不移走正式文件。
5. 把 `.tmp` 重命名为正式文件。
6. 若提交失败且正式文件缺失，立即从 `.bak` 复制恢复。
7. 成功后保留一份 `.bak`，删除无用 `.tmp`。

Windows 的 Godot 4.7 `DirAccessWindows::rename()` 在目标存在时先删除目标再移动，因此第 5 步存在极短中间窗口。可靠性来自“正式/备份/临时至少一份可验证 + 下次启动恢复”，不是不存在任何中间状态。

本节步骤用于 JSON 元数据。P3.2 地点快照同样采用“`.tmp.scn` 写入 → 忽略缓存读回并实例化验证 → `.bak.scn` 备份 → 提交/失败恢复”，然后才更新 `session.json`；完整顺序见 `docs/p3_playthrough_contract.md`。

### 内部失败恢复与旧恢复点

`manifest.json.tmp/.bak` 只服务清单写入失败恢复，不是用户历史，也不显示成另一个模组。编辑器不再提供“备份模组”命令；新增周五团、周六团等记录统一写入 `sessions/<session_id>/`，不会创建第二份模组。

旧版本已经产生的 `_backups/` 仓库保持原样，不自动删除。现有读取与校验代码继续拒绝路径逃逸、目录链接和包含 `sessions/` 的恢复点，只用于兼容已有数据；正常工作流不再创建新的手动恢复点。

## 七、加载与恢复优先级

1. 正式文件存在且通过语法、格式、版本和领域校验：使用正式文件，清理陈旧 `.tmp`。
2. 正式文件缺失/损坏且 `.bak` 有效：复制备份恢复正式文件，返回“已从备份恢复”状态。
3. 正式文件和备份都不存在，但 `.tmp` 有效：只用于首次创建中断，提交临时文件。
4. 正式文件损坏且备份/临时文件均无效：拒绝打开，不扫描场景覆盖损坏清单。
5. 清单完全不存在且存在 `_canonical/*.scn`：进入旧模组迁移。
6. 三者都不存在：新建流程可创建空清单；打开流程返回文件不存在。

恢复必须通过公开结果返回给 UI；不能只 `push_error` 后继续。

## 八、旧模组迁移

旧结构：

```text
user://modules/<目录名>/_canonical/*.scn
```

迁移顺序：

1. 按现有文件名排序扫描 `.scn`。
2. 生成一个 `module_id`，每个场景生成一个 `location_id`。
3. 显示名使用旧文件名去扩展名；相对路径保留旧文件名，不移动场景。
4. 第一项成为 `start_location_id`；空目录则为空。
5. 使用安全写入生成 `manifest.json`。
6. 重新从磁盘加载并验证后，才提交为 `ModuleGate` 当前状态。

迁移成功后重复打开必须读同一清单，不能再次扫描或更换 ID。若清单保存失败，旧场景保持原样，模组不进入半打开状态。

当前“导入模组”语义仍是复制外部 `_canonical` 场景形成一个新的本地模组，因此为导入副本生成新 ID；P6 若增加正式模组打包/转移，再单独定义保留身份的导入方式。

## 九、版本迁移

- `schema_version == 当前版本`：直接校验并加载。
- `schema_version < 当前版本`：依次执行 `vN -> vN+1` 迁移，每一步返回明确错误；全部完成后安全写回。
- `schema_version > 当前版本`：返回 `ERR_UNAVAILABLE`，提示由更高版本创建；不覆盖、不降级、不扫描重建。
- 无 `manifest.json` 的旧目录不伪装成 `schema_version=0` JSON；走独立旧目录迁移入口。

第一版迁移器仍需存在，即使暂时只有版本 1；这样版本 2 不会再补架构。

## 十、事务边界

### 新建模组

目录创建、空清单安全写入和读回验证全部成功后，才发 `module_changed`。失败时不改变当前已打开模组。

### 打开模组

在局部变量中完成读取、恢复、迁移和验证，最后一次性替换 `_current_manifest/_current_module_name/_current_location_name`。

### 新建地点

先在清单副本中创建地点引用并保存清单；随后创建默认场景。场景保存失败时地点保留为明确缺失引用，供 GM 重试或删除，不能静默消失。

### 保存已有地点

场景本体继续走 `ModuleIo.save_scene_tree()`；不改变清单字段时无需重复写清单。重命名、排序、删除等 P6 操作再按清单事务执行。

## 十一、错误结果

内部不得只返回 `null` 表示所有失败。最小结果字典：

```text
{
  error: int,
  value: Variant,
  recovered_from_backup: bool,
  migrated: bool,
  message: String
}
```

公开 UI 使用中文消息；自动测试断言 `error` 与状态布尔，不匹配脆弱文案。

## 十二、测试矩阵

### P3.1 专项自动测试

- 新建模组立即产生合法清单。
- 关闭/重开后 `module_id/location_id/start_location_id` 不变。
- 修改显示名不改变 ID 或场景引用。
- 两个地点 ID 唯一，清单顺序稳定。
- 旧 `_canonical` 迁移不移动场景，第二次打开不重复迁移。
- 正式清单损坏时从有效备份恢复并报告。
- 正式/备份均损坏时拒绝打开，不覆盖原文件。
- 只有有效临时文件的首次创建可恢复。
- 未来版本拒绝且文件字节不变。
- 非法 ID、重复 ID、错误起始地点和路径逃逸均拒绝。
- 缺失场景保留地点并标记不可用，其他地点仍可打开。
- 外部内容 ID 唯一；重命名不改 ID；非法类型、非法来源、路径逃逸拒绝；缺失文件保留引用并标记不可用。
- 新建/打开失败不改变此前当前模组。
- 旧 `_backups` 数据仍可校验；不得递归包含自身或 `sessions/`，逃逸路径和目录链接拒绝。
- 新界面不创建模组历史；“新增一桌”只增加独立 `session_id`，不得复制或替换模组真值。

### 回归与可见窗口

- P1、P2.4、P2.5、P2.6 全部保持通过。
- 现有开发测试模组首次打开显示一次迁移结果，场景和顺序不丢。
- 保存、退出程序、重新打开后进入同一模组，清单 ID 和起始地点不变。
- 人工破坏清单副本后能看到明确恢复/错误提示，不出现空白模组覆盖原数据。

## 十三、四层依据与插件取舍

- 项目：复用现有 `ModuleManifest/LocationRef/ModuleIo/ModuleGate` 边界；替换未接线的 `.tres` 清单入口，不新增平行保存系统。
- Godot 4.7 源码：`FileAccess`、`JSON`、`Crypto`、`DirAccess` 完成读写、解析、标识和文件替换；Windows 重命名实现决定必须有恢复链。
- 官方：`Saving games` 使用 Dictionary + JSON + FileAccess；Crypto 文档保证随机字节为密码学安全随机；ResourceUID 文档限定其为工程资源路径 UID。
- 社区：SaveState Lite 1.2.0（MIT，Godot 4.3-4.6）提供临时写、校验、备份和 schema 思路，但其全局键值模型、版本范围和失败恢复不适合直接接入，故不安装、不复制代码。

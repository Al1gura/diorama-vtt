# CCxGodot — Claude Code + Godot 开发参考

> 搜自 GitHub / SkillsMP / 社区，2026年7月整理。
> 此文件为参考索引，不随项目设计演变修改。需要更新时重搜。

---

## 一、Claude Code 官方内置技能和命令

Claude Code 自带，无需安装。在对话中自动触发或通过 `/plugin install` 安装。

| 名称 | 类型 | 用途 | 对 Gvvt 有用吗 |
|------|------|------|---------------|
| `code-reviewer` | 插件 | 代码审查，检查 PR 和变更 | ✅ 开发全程 |
| `security-review` | 插件 | 安全审查，检查漏洞 | ✅ 后期 |
| `frontend-design` | 插件 | UI/UX 设计指导，视觉风格 | ✅ UI 设计时 |
| `deep-research` | 技能 | 多源搜索→查证→写引用报告 | ✅ 策划/调研时 |
| `consolidate-memory` | 技能 | 整理 auto-memory，合并重复，修剪索引 | ✅ 全程（已有） |
| `schedule` | 技能 | 定时任务创建/管理 | ⚠️ 不需要（不是 SaaS） |
| `setup-cowork` | 技能 | Cowork 安装引导 | ❌ |

---

## 二、Godot SKILL.md 技能文件

`SKILL.md` 是 Claude Code 的可安装知识包，教会 Claude 特定领域的编码能力。
所有 Godot 技能的目标引擎版本均为 **Godot 4.3+**，GDScript 2.0。

### 2.1 Godot-Skill（单文件，GDScript 规范必修）

- **来源：** https://github.com/shihabshahrier/Godot-Skill
- **内容：** 1 个主 `SKILL.md`（500 行以内）+ 4 个参考文件
- **核心能力：**
  - 强制静态类型（`var speed: float = 100.0`）
  - 禁止 Godot 3 旧语法（`yield`、`TileMap`、`File` 等）
  - 官方风格指南 + 信号驱动 + 组件化架构
  - **防止 AI 幻觉编造不存在的 API**
- **安装：** `npx add-skill shihabshahrier/Godot-Skill`
- **对 Gvvt：** ✅ **必装。** 写任何 GDScript 之前先把这套规范灌进去。

### 2.2 GodotPrompter（51 个技能，最全面）

- **来源：** https://github.com/jame581/GodotPrompter
- **版本：** v1.10.1（2026年6月）
- **内容：** 51 个技能 + 9 个专用代理
- **安装：** `claude plugins marketplace add jame581/skillsmith` → `claude plugins install godot-prompter@skillsmith`

#### 对 Gvvt 有用的（12 个）

| 技能 | 用途 |
|------|------|
| `godot-project-setup` | 目录结构、autoload（自动加载）、.gitignore、输入映射 |
| `3d-essentials` | 材质、光照、阴影、环境、GI（全局光照）、雾、LOD（细节层次）、遮挡剔除 |
| `state-machine` | 编辑态 ↔ 运行态切换的状态机架构 |
| `event-bus` | 全局 EventBus（事件总线）autoload，类型化信号解耦通信 |
| `component-system` | Hitbox/Hurtbox/Health 组件模式，组合优于继承 |
| `resource-pattern` | 自定义 Resource（资源）用于物件数据、配置、编辑器集成 |
| `camera-system` | 平滑跟随、屏幕震动、相机区域、过渡 |
| `shader-basics` | Godot 着色器语言、常见配方、后处理 |
| `particles-vfx` | GPUParticles2D/3D、过程材质、子发射器、轨迹 |
| `save-load` | ConfigFile/JSON/Resource 序列化、版本迁移 |
| `godot-ui` | Control（控件）节点、Theme（主题）、锚点、容器、布局 |
| `godot-optimization` | Profiler（性能分析器）、Draw Call（绘制调用）、物理调优、对象池 |

#### 不需要的（39 个，不展开）

- 整个 2D 类（`2d-essentials`）— 不是 2D 工具
- 整个 XR 类（`xr-development`）— 不是 VR 应用
- 整个多人联网类（3 个 `multiplayer-*`）— 不做联网
- 整个移动端类（`mobile-development`）— 不是手机应用
- 整个 C# 类（`csharp-*`）— 用 GDScript
- 整个 AI 行为树（`limboai`、`beehave`、`ai-navigation`）— 不是游戏 NPC
- `physics-system` — 不是物理模拟
- `player-controller` — 不是角色控制
- `animation-system` / `tween-animation` — 不是动画游戏
- `inventory-system` / `dialogue-system` / `ability-system` — RPG 系统
- `procedural-generation` — 不是这个阶段
- `export-pipeline` — 不是发布流程
- `addon-development` — 不是做插件
- `localization` — 单语言
- `gdextension` / `multithreading` — 不需要原生扩展

### 2.3 awesome-gamedev-agent-skills（15 个 Godot 技能，跨引擎）

- **来源：** https://github.com/gamedev-skills/awesome-gamedev-agent-skills
- **内容：** 66 个总技能（15 个 Godot），主路由器自动检测引擎
- **安装：** `npx skills add gamedev-skills/awesome-gamedev-agent-skills`

其中 Godot 技能与 GodotPrompter 有大量重叠。如果已装 GodotPrompter 的 12 个，这里的 15 个大部分是重复的。**暂不推荐重复安装。**

### 2.4 Claude-GDSkill（Godot 4.5 完整类参考）

- **来源：** https://github.com/Kothulhu94/Claude-GDSkill
- **内容：** Godot 4.5 全套 **1050+** 个类的 API 参考（压缩 2.5MB，解压 26MB）
- **用途：** 遇到任何 Godot 类不知道方法签名时查询
- **对 Gvvt：** ⚠️ 太大了，26MB 会吃掉 token 预算。**不推荐常驻——只在查具体 API 时临时加载。**

### 2.5 godot-gdscript-patterns（SkillsMP 上的两个版本）

- **来源：**
  - `rmyndharis` 版 — SkillsMP 搜索 `godot-gdscript-patterns`
  - `wshobson` 版 — SkillsMP 搜索同名
- **内容：** GDScript 架构模式、信号、场景、状态机、性能优化
- **对 Gvvt：** 与 Godot-Skill 内容重叠。**如果已经装了 Godot-Skill，不需要额外装。**

### 2.6 godot（SkillsMP 上的通用 Godot 技能）

- **来源：** SkillsMP 搜索 `godot` by `dmaynor`
- **版本：** v1.1.0（2026年3月）
- **内容：** 场景架构、物理、UI、着色器、项目结构、状态机、自动加载、常见踩坑
- **对 Gvvt：** 内容基础，与前面有重叠。**不需要额外装。**

### 2.7 GodoMaster（官方文档技能，18 个模块）

- **来源：** `Aetik-yue/GodoMaster` on GitHub
- **安装：** `npm install -g godomaster-skill`
- **内容：** 18 个模块——项目管理、编辑器、GDScript、节点/场景、2D、3D、物理、动画、UI、音频、输入、导出、性能、文件 I/O、着色器、网络、测试、架构
- **对 Gvvt：** 基于 Godot 官方文档，可能比社区技能更准确。**可以替代 Godot-Skill 作为"权威参考"，但建议先试一个。**

---

## 三、MCP 工具（让 Claude 操控 Godot 编辑器）

**不同于 SKILL.md：** MCP 不会教 Claude 怎么写代码，而是让 Claude 通过 API 操控 Godot 编辑器——创建节点、编辑脚本、运行项目、截屏反馈。

### 3.1 Godot-MCP-Native（推荐——零外部依赖）

- **来源：** https://github.com/yurineko73/Godot-MCP-Native
- **价格：** 免费
- **工具数：** 155 个（30 核心 + 125 补充）
- **依赖：** 无。原生 GDScript + HTTP 实现，不在 Godot 外面装任何东西。
- **功能：** 节点操作、脚本编辑、场景管理、编辑器控制、调试、性能分析、项目设置、输入映射
- **传输：** HTTP（端口 9080）或命令行模式
- **Gvvt 适用性：** ✅ **强烈推荐。** 开发阶段 Claude 能直接操作 Godot，不用来回粘贴代码。

### 3.2 Godot-AI（150+ 操作，支持 19 个 AI 客户端）

- **来源：** https://godotengine.org/asset-library/asset/5050
- **价格：** 免费
- **依赖：** Python + uv
- **功能：** 150+ 操作——场景、节点、脚本、动画、UI、主题、材质、粒子、音频、相机、输入映射、项目设置
- **一键配置 19 个 MCP 客户端**
- **Gvvt 适用性：** ✅ 可选。功能丰富但需要 Python，不如 Native 轻量。

### 3.3 Godot-MCP-Pilot（npm 一键启动）

- **来源：** https://github.com/Pushks18/Godot-MCP-Pilot
- **价格：** 免费
- **安装：** `npx godot-mcp-pilot`
- **功能：** 编辑器启动、场景/节点/脚本编辑、项目设置、资源管理
- **Gvvt 适用性：** ⚠️ 工具少（~35 个），不如 Native 或 Godot-AI。

---

## 四、CLAUDE.md 模板参考（非技能，项目级配置）

以下仓库提供了 `CLAUDE.md` 写得好的参考，可以借鉴他们的写法来改进 Gvvt 自己的 CLAUDE.md：

### 4.1 Godot + Claude Code 完全指南

- **来源：** https://gist.github.com/xbfool/af1cacc74b7e58364aa244770bf85752
- **内容：** 三层工具栈（MCP + Skills + Godogen）、CLAUDE.md 模板、GDScript 编码规则、项目结构、踩坑经验
- **Gvvt 适用性：** ✅ **强烈推荐阅读。** 里面的 CLAUDE.md 模板可以直接参考来改进我们自己的。

### 4.2 Godot-Bevy CLAUDE.md

- **来源：** https://github.com/bytemeadow/godot-bevy/blob/v0.8.4/CLAUDE.md
- **内容：** 构建命令、双调度架构、插件系统、Godot-first 工作流
- **Gvvt 适用性：** ⚠️ 主要是 Rust 桥接，架构借鉴有限。

---

## 五、Godot 项目模板参考

如果需要一个干净的 Godot 目录结构骨架作为 Gvvt 的起点：

| 仓库 | 侧重 |
|------|------|
| [godot-project-template](https://github.com/SamuelAsherRivello/godot-project-template) | Godot 最佳实践 + C# 编码规范 |
| [Godot-Project-Structure-Template](https://github.com/Joshulties/Godot-Project-Structure-Template) | 标准化文件组织 |
| [godot-architecture-organization-advice](https://github.com/abmarnie/godot-architecture-organization-advice) | 架构和文件组织建议 |

**Gvvt 适用性：** P0 阶段搭建目录结构时参考。

---

## 六、推荐安装顺序

按 Gvvt 的 P0→P4 开发阶段，逐步安装：

### 立即安装

| 步骤 | 安装内容 | 理由 |
|------|---------|------|
| 1 | `npx add-skill shihabshahrier/Godot-Skill` | 写 GDScript 的规范基础 |
| 2 | `claude plugins marketplace add jame581/skillsmith` → 再装 `godot-prompter` | 51 个技能中只挑有用的 12 个加载 |
| 3 | Godot Asset Library 搜索 `godot-mcp-native` | 让 Claude 直接操控 Godot |

### 开发中期装

| 步骤 | 安装内容 | 理由 |
|------|---------|------|
| 4 | `/plugin install code-reviewer` | 代码变多后需要审查 |
| 5 | `/plugin install frontend-design` | 做 UI 时参考设计建议 |

### 后期装

| 步骤 | 安装内容 | 理由 |
|------|---------|------|
| 6 | `/plugin install security-review` | 发布前安全审查 |

---

## 七、技能选择逻辑

```
Godot-Skill ──→ 必须 ⭐
    ↓ （规范基础）
GodotPrompter ──→ 只加载对 Gvvt 有用的 12 个
    ↓ （项目骨架 + 3D + 状态管理 + 保存加载 + UI）
Godot-MCP-Native ──→ 让 Claude 控制 Godot 编辑器
    ↓
代码审查 / 前端设计 → 按需加载
```


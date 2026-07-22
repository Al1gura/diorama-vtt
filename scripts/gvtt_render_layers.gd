extends RefCounted
class_name GvttRenderLayers
## GvttRenderLayers —— 渲染层 / 物理查询层归口常量

const RENDER_LAYER_PUBLIC: int = 1
const RENDER_LAYER_GM_ONLY: int = 20
const CULL_MASK_ALL: int = 0xFFFFF
const CULL_MASK_PLAYER: int = 0xFFFFF ^ (1 << (RENDER_LAYER_GM_ONLY - 1))
const PICK_PHYSICS_LAYER: int = 20
const COMBAT_PHYSICS_LAYER: int = 21
const COMBAT_PHYSICS_MASK: int = 1 << (COMBAT_PHYSICS_LAYER - 1)

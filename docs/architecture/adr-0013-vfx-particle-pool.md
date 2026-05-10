# ADR-0013: VFX Particle Pool Architecture

## Status
Accepted

## Date
2026-05-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Rendering |
| **Knowledge Risk** | MEDIUM — GPU particle mode (`RenderingServer.canvas_item_set_use_gpu_particles`) is post-4.0 but well-established; `duplicate_deep()` (4.5+) for pool resource cloning is post-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | `duplicate_deep()` (4.5+) — deep copy of particle resource templates for pool initialization |
| **Verification Required** | Benchmark 8 pools × 500 total particles at 800-peak burst — confirm GPU particle mode avoids CPU stall at pool exhaustion |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 (EventBus signals for all VFX triggers), ADR-0003 (physics 60Hz / render 240fps — particles run in `_process` at render rate) |
| **Enables** | All Presentation layer VFX (shooting trails, hit sparks, dodge afterimages, skill burst, death shatter, environment) |
| **Blocks** | VFX implementation — pool must exist before any particle-emitting system goes live |
| **Ordering Note** | Implement after EventBus (ADR-0005) and before any Core system triggers particle VFX |

## Context

### Problem Statement
《裂隙反应》的 VFX 密度极高——常态战斗 200 粒子同时活跃，技能爆发峰值 800 粒子。Godot 的惯用模式是 `add_child()` 动态创建粒子节点、动画结束后 `queue_free()`。但在 800 粒子峰值下，单帧创建/销毁 100+ 节点会导致 CPU spike（场景树插入/移除触发 `NOTIFICATION_ENTER_TREE`/`EXIT_TREE`），突破 4.17ms 帧预算。

VFX GDD 明确要求"预分配粒子节点池，不动态创建/销毁"。此 ADR 定义池的规模、类型、回收策略和与现有架构的集成点。

### Constraints
- 240fps 渲染（`_process`），帧预算 ≤4.17ms
- 8 种粒子类型（弹道线、命中火花、闪避残影、爆发冲击波、爆发核心、死亡碎裂、环境孢子、化学蒸汽）
- 峰值 800 粒子（技能爆发 0.5s 窗口）
- GPU 粒子模式减少 CPU 负载
- 粒子颜色/形状可被构筑方向切换（C3 原则——火/雷/虚空三套视觉方言）

### Requirements
- 零动态创建/销毁——所有粒子预分配
- 池耗尽时优雅降级（复用最老粒子，不崩溃）
- 粒子回收后状态完全重置
- 时间缩放期间粒子动画速度跟随 `Engine.time_scale`

## Decision

**8 个预分配粒子池，使用 GPU 粒子模式。池耗尽时复用最老的活动粒子（LRU 回收）。所有池在场景加载时初始化，场景切换时释放。**

### Pool Sizing

| Pool | Type | Size | Node Type | Atlas |
|------|------|:---:|-----------|-------|
| bullet_trail | 弹道线 | 16 | `Line2D` / `Sprite2D` | 1×64px white core, tinted dynamically |
| hit_spark | 命中火花 | 128 | `GpuParticles2D` | 64×64, 8×8 grid |
| dodge_afterimage | 闪避残影 | 8 | `Sprite2D` | 128×128, 16 frames |
| skill_shockwave | 爆发冲击波 | 64 | `GpuParticles2D` | 128×128, 8×8 grid |
| skill_core | 爆发核心 | 32 | `GpuParticles2D` | 64×64, 4×4 grid |
| death_shatter | 死亡碎裂 | 64 | `GpuParticles2D` | 64×64, 8×8 grid |
| environment_spore | 环境孢子 | 128 | `GpuParticles2D` | 96×96, 8×6 grid |
| chemical_steam | 化学蒸汽 | 64 | `GpuParticles2D` | 96×96, 8×6 grid |

**Total**: 504 particles pre-allocated.

### Pool Architecture

```gdscript
class_name ParticlePool extends Node2D

var _available: Array[Node2D] = []
var _active: Array[Node2D] = []

func _init(template: PackedScene, size: int) -> void:
    for _i in range(size):
        var instance = template.instantiate()
        instance.visible = false
        instance.process_mode = Node.PROCESS_MODE_DISABLED
        add_child(instance)
        _available.append(instance)

func acquire(position: Vector2, config: Dictionary = {}) -> Node2D:
    var particle: Node2D
    if _available.size() > 0:
        particle = _available.pop_back()
    else:
        # LRU回收 — 复用最老的活动粒子
        particle = _active.pop_front()
        _reset_particle(particle)
    particle.global_position = position
    particle.visible = true
    particle.process_mode = Node.PROCESS_MODE_INHERIT
    _apply_config(particle, config)
    _active.append(particle)
    return particle

func release(particle: Node2D) -> void:
    particle.visible = false
    particle.process_mode = Node.PROCESS_MODE_DISABLED
    _active.erase(particle)
    _available.append(particle)

func _reset_particle(p: Node2D) -> void:
    if p is GpuParticles2D:
        p.emitting = false
        p.amount = 0
    p.scale = Vector2.ONE
    p.modulate = Color.WHITE
    p.rotation = 0.0
```

### VFXManager (Autoload or game.tscn singleton)

```gdscript
class_name VFXManager extends Node2D

var pools: Dictionary = {}  # String → ParticlePool

func _ready() -> void:
    pools["bullet_trail"] = ParticlePool.new(preload("res://vfx/bullet_trail.tscn"), 16)
    pools["hit_spark"] = ParticlePool.new(preload("res://vfx/hit_spark.tscn"), 128)
    # ... etc for all 8 pools

func spawn(pool_name: String, position: Vector2, config: Dictionary = {}) -> void:
    pools[pool_name].acquire(position, config)

# Connected to EventBus in _ready():
func _on_bullet_hit(hit_pos: Vector2, _is_skill2: bool) -> void:
    spawn("hit_spark", hit_pos, {"direction": _last_aim_dir})
    spawn("bullet_trail", hit_pos, {})  # trail endpoint

func _on_skill_1_cast(pos: Vector2) -> void:
    spawn("skill_shockwave", pos, {"radius": 200.0})
    spawn("skill_core", pos, {"color": Color.ORANGE_RED})

func _on_enemy_killed(type: int, pos: Vector2) -> void:
    spawn("death_shatter", pos, {"enemy_type": type})
```

### Per-State Particle Budgets

| State | Budget | Enforcement |
|------|:------:|-------------|
| Normal combat | 200 | Soft cap — acquire rejects if active > 200 |
| Skill burst (0.5s) | 800 | Budget raised; after 0.5s, no new spawns until active < 200 |
| Wave transition | 50 | Tight cap — only card UI particles |
| Death freeze | 100 | Reduced — only death shatter + lingering |

### Time Scale Behavior

Particles in `_process()` read `Engine.time_scale` for their animation speed:
```gdscript
func _process(_delta: float) -> void:
    for p in _active:
        if p is GpuParticles2D:
            p.speed_scale = Engine.time_scale  # Slow down during perfect dodge
```

Screen effects (vignette, cold filter, edge sharpen) are owned by VFXManager but implemented via `ColorRect` + `ShaderMaterial`, not particles. They are excluded from pool budgets.

### Build Direction Visual Dialect

When the build system changes direction (fire → lightning → void), VFXManager receives `EventBus.build_direction_changed` and updates a global dictionary of per-direction colors/shapes:

```gdscript
const DIRECTION_PALETTE = {
    "fire":  {color = Color.ORANGE,      particle_shape = "circle",   trail = "parabolic"},
    "lightning": {color = Color.CYAN,    particle_shape = "hexagon",  trail = "linear"},
    "void":  {color = Color.PURPLE,     particle_shape = "triangle", trail = "slow_penetrate"},
}
```

All subsequent `spawn()` calls read from the current direction palette unless overridden.

## Alternatives Considered

### Alternative 1: Dynamic create/destroy (Godot default)
- **Pros**: Simple code, no pool management, automatic cleanup via `queue_free()`
- **Cons**: 100+ `add_child()`/`queue_free()` per frame at 800 peak → scene tree notifications → CPU spikes >2ms. GC pressure from freed nodes
- **Rejection Reason**: 800 particle peak makes dynamic allocation non-viable at 240fps

### Alternative 2: Single unified pool (all types mixed)
- **Pros**: Simpler manager, one array for everything
- **Cons**: Pool types have different node types (Line2D vs GpuParticles2D vs Sprite2D). Mixed pool requires casting or duck-typing. LRU eviction may kill a long-lasting environment particle to make room for a 1-frame bullet trail — wrong priority
- **Rejection Reason**: Separate pools per type ensure LRU eviction is type-appropriate and prevent type-confusion bugs

### Alternative 3: CPU particles (CPUParticles2D)
- **Pros**: Wider compatibility, no GPU driver edge cases
- **Cons**: 800 CPU particles = 800 × transform update per frame on CPU. GPU particles offload transform + rendering to GPU
- **Rejection Reason**: Godot 4.x `GpuParticles2D` is mature and well-supported. GPU mode is the correct default for 2D pixel art particle systems at this scale

## Consequences

### Positive
- Zero dynamic allocation during gameplay — frame time predictable
- LRU recycling ensures pool exhaustion never crashes; oldest particles gracefully replaced
- Per-type pools prevent cross-type contamination
- Build direction switching is a single dictionary lookup per spawn
- Particle animation speed naturally follows `Engine.time_scale`

### Negative
- 504 pre-allocated particles consume ~2-3MB VRAM at all times (acceptable for PC target)
- Pool initialization at scene load takes ~20-40ms (hidden behind transition fade)
- New particle types require adding a new pool + template resource — not zero-cost extensibility

### Risks
- **Pool sizing wrong**: If a specific pool runs dry more often than expected, LRU recycling causes visible particle pop-in. Mitigation: expose pool sizes as `@export` vars, tune after playtest
- **GPU particle compatibility**: `GpuParticles2D` requires GPU with compute shader support (DX12/Vulkan/Metal). Mitigation: PC Steam target — essentially 100% coverage. No fallback needed
- **Particle state leak**: If a system forgets to `release()`, particles accumulate in _active array and pool drains. Mitigation: add a `_active_timeout` sweep every 5s — any particle active >10s is force-released

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| vfx-particles.md | 预分配粒子池，不动态创建/销毁 | 8 pools × 504 total pre-allocated at scene load |
| vfx-particles.md | 800 粒子峰值 ≤4.17ms | GPU particles + LRU recycling + per-state budgets |
| vfx-particles.md | 构筑方向切换粒子颜色/形状 | `DIRECTION_PALETTE` lookup, EventBus-driven |
| vfx-particles.md | 时间缩放时粒子动画同步 | `speed_scale = Engine.time_scale` in `_process()` |
| vfx-particles.md | 暗角 + 冷色滤镜 + 边缘锐化 | Screen effects owned by VFXManager, not pooled |
| skill-system.md | 技能爆发冲击波 + 核心粒子 | `skill_shockwave` + `skill_core` pools triggered by `EventBus.skill_1_cast` |
| enemy-system.md | 敌人死亡碎裂粒子 | `death_shatter` pool, per-type config (small/medium/large) |
| shooting-system.md | 弹道线 + 命中火花 | `bullet_trail` + `hit_spark` pools, triggered by `EventBus.bullet_hit` |

## Performance Implications
- **CPU**: Pool acquire/release is O(1) array push/pop — <0.01ms/frame. 800 GPU particles transform on GPU — no CPU cost
- **Memory**: 504 particles × ~4-6KB each (texture reference + transform data) ≈ 2-3MB VRAM
- **Load Time**: Pool initialization ~20-40ms (hidden behind scene transition fade)
- **Draw Calls**: GPU particles batch into one draw call per pool (8 draws). Line2D trails add ~16 draws (can be reduced with MultiMesh in future)

## Validation Criteria
- 技能 1 爆发（800 粒子峰值）：帧时间 ≤4.17ms
- 同一帧 `acquire()` 被调用 100 次：无 `add_child()` 调用（全部取自池或 LRU 回收）
- 连续 10 波游戏后退出：无内存泄漏（池大小不变）
- 时间缩放 0.2 时粒子动画减速至 20% 速度
- 构筑方向切换：下一帧起新粒子使用新方向色板
- 粒子回收后重新 `acquire()`：位置/颜色/缩放/旋转全部重置为默认值

# 裂隙反应 — Master Architecture

## Document Status
- **Version**: 1.0
- **Last Updated**: 2026-05-08
- **Engine**: Godot 4.6.2 (2D, GodotPhysics2D)
- **GDDs Covered**: 10 Approved (Foundation 4 + Core 6)
- **ADRs Referenced**: 0 (none yet — see Required ADRs)
- **Technical Director Sign-Off**: Pending
- **Lead Programmer Feasibility**: Pending

## Engine Knowledge Gap Summary

| Domain | Risk | Impact |
|--------|:----:|--------|
| GDScript `@abstract` (4.5) | HIGH | Enemy base class, skill system |
| `duplicate_deep()` (4.5) | HIGH | Resource cloning for VFX pool |
| 2D Navigation server (4.5) | MEDIUM | Fallback for flow-field pathfinding |
| `FileAccess.store_*` return bool (4.4) | MEDIUM | Save system (not yet designed) |
| `AnimationMixer` base (4.3) | LOW | Skill animation manual advance |
| GodotPhysics2D (unchanged) | LOW | Core physics — fully in training data |
| `Time.get_ticks_msec()` | LOW | Real-time timing — in training data |

All HIGH risk areas are language/API additions that improve our design, not breaking changes. Zero deprecated APIs used in the current 10 GDDs.

---

## System Layer Map

```
┌──────────────────────────────────────────────────────┐
│  PRESENTATION LAYER (5 systems — not yet reviewed)   │
│  VFX粒子 | Diegetic UI | HUD | 升级卡片UI | 菜单    │
├──────────────────────────────────────────────────────┤
│  FEATURE LAYER (3 systems — not yet reviewed)        │
│  波次管理 | 构筑系统 | 跨局进度                      │
├──────────────────────────────────────────────────────┤
│  CORE LAYER (6 systems — all Approved)               │
│  玩家移动 | 射击系统 | 闪避系统 | 技能系统           │
│  伤害与血量 | 敌人系统                               │
├──────────────────────────────────────────────────────┤
│  FOUNDATION LAYER (4 systems — all Approved)          │
│  输入系统 | 场景管理 | 摄像机系统 | 音频系统         │
│  + GameManager Autoload | + AudioManager Autoload    │
├──────────────────────────────────────────────────────┤
│  ENGINE LAYER                                        │
│  Godot 4.6.2 | GodotPhysics2D @ 60Hz | 240fps render │
│  CharacterBody2D | Area2D | MultiMeshInstance2D       │
│  PhysicsRayQueryParameters2D | PhysicsShapeQuery2D    │
└──────────────────────────────────────────────────────┘
```

**Layer communication rules:**
- Downward calls only: Core reads Foundation, Feature reads Core, Presentation reads Feature+Core
- Upward via signals: Foundation emits no game signals; Core emits signals upward to Presentation
- Cross-layer shared state: GameManager Autoload (singleton) for run state, AudioManager for audio

---

## Module Ownership

### Foundation Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|--------|------|---------|----------|-------------|
| **InputSystem** | Input Map bindings, debounce state, input buffer | `get_move_axis(): Vector2`, `get_aim_direction(): Vector2`, `is_shoot_pressed(): bool`, `is_dodge_just_pressed(): bool`, `is_skill1_just_pressed(): bool`, `is_pause_just_pressed(): bool` | Nothing (leaf) | `Input.is_action_pressed()`, `Input.is_action_just_pressed()`, `InputEvent` (for debounce only) |
| **SceneManager** | Scene tree (main_menu, game, death_screen), transition state | `switch_to(scene_id: String, data: Dictionary)`, `get_current_scene(): String` | GameManager (read run state on game start) | `SceneTree.change_scene_to_file()`, `ResourceLoader` |
| **CameraSystem** | Camera2D node, follow/offset/zoom state, shake state | `trigger_shake(type: ShakeType)`, `set_zoom_level(zoom: float)` | Player position, aim direction, dodge/skill events | `Camera2D`, `Tween` (set_ignore_time_scale=true) |
| **AudioSystem** | Audio bus hierarchy, BGM playlist, SFX pool | `play_sfx(event: AudioEvent)`, `play_bgm(state: BGMState)`, `set_ducking(config: DuckConfig)` | Game events (shoot/hit/dodge/skill/death) | `AudioStreamPlayer`, `AudioBus`, `Tween` |

### Core Layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|--------|------|---------|----------|-------------|
| **PlayerMovement** | CharacterBody2D, velocity, facing direction | `get_velocity(): Vector2`, `get_last_move_direction(): Vector2`, `get_position(): Vector2` | InputSystem.move_axis | `CharacterBody2D.move_and_slide()`, `CharacterBody2D.velocity` |
| **ShootingSystem** | Fire rate timer, hitscan logic, bullet trail VFX trigger | `get_is_shooting(): bool`, `get_last_hit_position(): Vector2` | InputSystem (shoot+aim), PlayerMovement (position), DamageSystem (deal_damage) | `PhysicsRayQueryParameters2D`, `PhysicsDirectSpaceState2D.intersect_ray()` |
| **DodgeSystem** | Charge count (0-3), charge regen timer, dodge state (300ms), perfect dodge detection (40px radius), time_scale control | `get_charge_count(): int`, `is_invincible(): bool`, `is_dodging(): bool`, `get_dodge_direction(): Vector2` | InputSystem (dodge), PlayerMovement (direction, position), all enemy attack positions | `CharacterBody2D.move_and_collide()`, `Engine.time_scale`, `Time.get_ticks_msec()` |
| **SkillSystem** | Skill_1 cooldown (15s base), cd_speed_multiplier, charge orb state (4 thresholds), skill_2 window (500ms), cancel refund (75%) | `is_skill1_ready(): bool`, `is_skill2_window_open(): bool`, `get_orb_state(): OrbState` | InputSystem (skill_1), DodgeSystem (charge_count, perfect_dodge_signal), ShootingSystem (skill_2 auto-attach) | `PhysicsShapeQueryParameters2D`, `PhysicsDirectSpaceState2D.intersect_shape()`, `CircleShape2D` (cached) |
| **DamageHealthSystem** | Player HP (0-3), invincibility frames (500ms), shield (0-1, 3s duration), death state (500ms freeze) | `get_hp(): int`, `get_shield(): int`, `is_alive(): bool`, `is_invincible(): bool` | ShootingSystem/SkillSystem (damage events), DodgeSystem (is_invincible + charge_count), EnemySystem (contact damage events) | `Time.get_ticks_msec()` (iframes + shield timer) |
| **EnemySystem** | EnemyManager (centralized arrays), 3 state machines (small/medium/large), flow field, spatial hash grid, spawn pool, MultiMeshInstance2D | `get_all_enemy_positions(): Array[Vector2]`, `get_all_enemy_attack_positions(): Array[Vector2]`, `spawn_wave(config: WaveConfig)` | SceneManager (SpawnPoint nodes), PlayerMovement (position), DamageHealthSystem (take_damage signal) | `MultiMeshInstance2D`, `Sprite2D`, `Area2D` (medium bullets), `Time.get_ticks_msec()` |

### Autoloads

| Autoload | Owns | Exposes |
|----------|------|---------|
| **GameManager** | Run state (current wave, build choices, kill count, stats), scene transition data | `start_new_run()`, `get_run_state(): RunState`, `record_kill()`, `end_run()` |
| **AudioManager** | Cross-scene BGM continuity, audio bus references, volume settings | `crossfade_bgm(target: BGMState, duration: float)`, `set_bus_volume(bus: String, db: float)` |

---

## Data Flow

### Frame Update Path (240fps render / 60Hz physics)

```
_physics_process (60Hz):
  1. InputSystem: poll Input.is_action_pressed/just_pressed
  2. PlayerMovement: read move_axis → compute velocity → move_and_slide()
  3. DodgeSystem: check dodge trigger → set invincibility → move_and_collide()
  4. ShootingSystem: check shoot + fire_interval → intersect_ray() → emit hit
  5. SkillSystem: update cooldown (real-time) → check skill_1 trigger
  6. DamageHealthSystem: process incoming damage → update HP/shield/iframes
  7. EnemySystem: update AI arrays → move enemies → check contact damage
  8. CameraSystem: lerp follow + offset → apply shake offset

_process (240fps):
  1. VFX: update particle pools
  2. Diegetic UI: update charge orb visual, health halo, dodge dots
  3. HUD: update wave counter, kill count
  4. Audio: process ducking tweens
```

### Event/Signal Path

```
Shoot pressed → InputSystem → ShootingSystem → intersect_ray()
  → hit: DamageHealthSystem.take_damage(enemy, 1)
  → VFX: spawn hit particles
  → Audio: play hit SFX

Dodge pressed → InputSystem → DodgeSystem:
  → perfect (attack within 40px): time_scale=0.2, heal + shield
    → SkillSystem: open skill_2 window (500ms)
    → Camera: shake (medium-low, 150ms)
    → Audio: perfect dodge SFX + pitch shift
  → normal: invincibility 300ms
    → Audio: whoosh SFX

Skill_1 pressed → SkillSystem → intersect_shape(200px):
  → DamageHealthSystem: deal 1 damage to all in AoE
  → VFX: shockwave particles
  → Audio: burst SFX + ducking
  → Camera: shake (high, 300ms)

HP <= 0 → DamageHealthSystem:
  → GameManager: record stats → end_run()
  → EnemySystem: freeze all AI
  → Camera: shake (heavy, 500ms)
  → SceneManager: switch to death_screen after 500ms
```

### Initialization Order

```
1. Engine boot → Autoloads (GameManager, AudioManager)
2. SceneManager → load main_menu.tscn
3. Player clicks Start:
   a. GameManager.start_new_run()
   b. SceneManager → load game.tscn
   c. InputSystem → register input map
   d. CameraSystem → attach to player
   e. EnemySystem → initialize manager arrays + spawn pool
   f. WaveManager → spawn wave 1
4. Game loop begins
```

---

## API Boundaries

### DodgeSystem ↔ DamageHealthSystem (interface-based decoupling)

```gdscript
# DodgeSystem exposes (read-only interface):
func get_charge_count() -> int      # 0-3, floor-rounded
func is_invincible() -> bool        # true during 300ms dodge displacement

# DamageHealthSystem reads (dependency injection, not direct node access):
var dodge_system: DodgeSystem  # set via @export or autoload

func take_damage(incoming: int, source: Node2D) -> void:
    if dodge_system.is_invincible():
        return  # no damage during dodge
    # ... shield overflow, HP reduction, iframe trigger
```

### ShootingSystem hit detection (hands-off to DamageHealthSystem)

```gdscript
func _fire_bullet() -> void:
    var space_state = get_world_2d().direct_space_state
    var query = PhysicsRayQueryParameters2D.create(
        player_pos, player_pos + aim_dir * weapon_range
    )
    query.collision_mask = ENEMY_LAYER | OBSTACLE_LAYER
    var result = space_state.intersect_ray(query)
    
    if result and result.collider is Enemy:
        # skill_2 modifies damage and enables pierce
        var dmg = _compute_final_damage()
        result.collider.take_damage(dmg)
        if _skill_2_active and _pierce_remaining > 0:
            _pierce_remaining -= 1
            # continue ray from hit point for second target
            _fire_pierce_ray(result.position, aim_dir)
        _skill_2_active = false
```

### SkillSystem AoE query (cached shape, real-time timing)

```gdscript
# Cached once in _ready():
var _aoe_shape = CircleShape2D.new()
_aoe_shape.radius = 200.0
var _aoe_query = PhysicsShapeQueryParameters2D.new()
_aoe_query.shape = _aoe_shape
_aoe_query.collision_mask = ENEMY_LAYER

func _execute_skill_1() -> void:
    _aoe_query.transform = Transform2D(0.0, global_position)
    var hits = get_world_2d().direct_space_state.intersect_shape(_aoe_query, 256)
    for hit in hits:
        if hit.collider.has_method("take_damage"):
            hit.collider.take_damage(_skill_1_damage)
```

### EnemyManager centralized update (data-oriented)

```gdscript
# Struct-of-arrays pattern — cache-friendly
var _positions: Array[Vector2]      # per-enemy position
var _velocities: Array[Vector2]     # per-enemy velocity
var _states: Array[int]             # packed enum
var _timers: Array[float]           # cooldown/windup/death timers
var _hp: Array[int]                 # per-enemy HP

func _process_enemies(delta: float) -> void:
    var now = Time.get_ticks_msec()
    for i in range(_active_count):
        match _states[i]:
            EnemyState.CHASE:
                _update_chase(i, delta, now)
            EnemyState.ATTACK:
                _update_attack(i, delta, now)
            # ... etc
```

---

## Architecture Principles

1. **Real-time is the default time domain.** All gameplay timers (cooldowns, iframes, shield duration, skill windows, death freeze) use `Time.get_ticks_msec()`, not `delta`. `Engine.time_scale` only affects enemy movement, bullet flight, and screen effects. `Tween` instances use `set_ignore_time_scale(true)`.

2. **Array-based, not node-based for performance.** Enemy AI runs in centralized arrays (struct-of-arrays), not individual `_process()` callbacks. MultiMeshInstance2D batches small enemy rendering. Physics at 60Hz, rendering at 240fps.

3. **Interface-based decoupling for circular dependencies.** DodgeSystem ↔ DamageHealthSystem avoid tight coupling via read-only getter interfaces (`is_invincible()`, `get_charge_count()`). Both systems own their internal state; neither depends on the other's implementation.

4. **Signal-up, call-down.** Core systems call Foundation systems directly (downward). Presentation systems listen to Core signals (upward). No Core system calls a Presentation system directly.

5. **Cached physics queries.** `CircleShape2D` and `PhysicsShapeQueryParameters2D` for skill_1 AoE are created once in `_ready()` and reused. No per-frame allocations for gameplay physics queries.

---

## Required ADRs

### Must have before any coding (Foundation + Core):

| # | ADR Topic | Covers TRs | Priority |
|---|-----------|------------|----------|
| ADR-001 | Real-time timing strategy (Time.get_ticks_msec vs delta) | TR-time-001, TR-time-002, TR-skill-001, TR-dodge-002 | BLOCKING |
| ADR-002 | Input processing architecture (_physics_process consolidation) | TR-input-002, TR-input-001 | BLOCKING |
| ADR-003 | Physics tick rate (60Hz) and separation strategy | TR-enemy-005, TR-enemy-004 | BLOCKING |
| ADR-004 | Centralized enemy manager (array-based, MultiMesh scope) | TR-enemy-001, TR-enemy-002, TR-enemy-003 | BLOCKING |
| ADR-005 | Event/signal architecture (call-down signal-up) | TR-dmg-001, TR-dodge-003, TR-skill-002 | HIGH |
| ADR-006 | Scene lifecycle and Autoload design | TR-scene-001, TR-scene-002 | HIGH |
| ADR-007 | Perfect dodge detection (all attack types, 40px radius) | TR-dodge-002 | HIGH |

### Should have before the relevant system is built:

| # | ADR Topic | Covers TRs |
|---|-----------|------------|
| ADR-008 | Ducking specification (attack/hold/release curves, bus scope) | TR-audio-001 |
| ADR-009 | Camera shake system (5 levels, real-time decay) | TR-cam-002 |
| ADR-010 | Skill_2 auto-attach and pierce override in hitscan pipeline | TR-shoot-002, TR-skill-002 |

### Can defer to implementation:

| # | ADR Topic | Covers TRs |
|---|-----------|------------|
| ADR-011 | Flow-field vs direct-chase pathfinding (obstacle-dependent) | TR-enemy-004 |
| ADR-012 | Save system serialization format | TR-build-001 (partial) |

---

## Open Questions

1. **竞技场是否有内部障碍物？** 影响流场寻路是否启用。若 MVP 竞技场仅为边界墙，流场降级为直线追踪。
2. **GameManager 和 AudioManager 的 GDD？** 这两个 Autoload 目前仅在本架构文档中定义——没有独立的 GDD。
3. **Feature/Presentation 层 10 个系统尚未审查** —— 架构骨架基于 Core 接口设计，不影响 Foundation/Core 层决策。

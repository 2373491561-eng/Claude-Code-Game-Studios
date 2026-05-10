# Control Manifest

> **Engine**: Godot 4.6.2
> **Last Updated**: 2026-05-10
> **Manifest Version**: 2026-05-10
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0013, ADR-0014
> **Status**: Active

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine initialisation, input, timing*

### Required Patterns

- **All gameplay timers use `Time.get_ticks_msec()`**, not `delta` parameter. Cooldowns, iframes, shield duration, death freeze, dodge displacement, skill windows — all use real-time millisecond tracking. — ADR-0001
- **Timer pattern**: store `_last_tick_ms`, compute `elapsed = (now - last) / 1000.0` each frame, subtract from remaining. — ADR-0001
- **`Tween.set_ignore_time_scale(true)`** for any Tween that must run in real time (camera shake, audio ducking, UI transitions). — ADR-0001
- **All game input actions executed in `_physics_process()`** via `Input.is_action_just_pressed()` / `Input.is_action_pressed()`. — ADR-0002
- **`_input(event)` only for lightweight state marking** — debounce timestamps, buffer flags. Never trigger action execution from `_input()`. — ADR-0002
- **Same-frame priority order**: dodge → skill_1 → shoot. Dodge cancels skill_1 if in startup phase (0-200ms), refunding 75% CD. — ADR-0002
- **Physics at 60Hz** (`physics/common/physics_ticks_per_second = 60`), **render at 240fps**. Physics interpolation ON. — ADR-0003
- **Spatial hash grid (32px cells)** for enemy separation steering. Rebuild each physics frame. Query 9 adjacent cells per enemy (not O(N²)). — ADR-0003
- **EventBus Autoload** for all cross-system signals. 14 signal definitions: `dodge_perfect`, `dodge_normal`, `skill_1_cast`, `skill_2_triggered`, `player_hit`, `player_death`, `enemy_killed`, `enemy_spawned`, `bullet_hit`, `wave_start`, `wave_clear`, `upgrade_selected`, `game_paused`, `game_resumed`. — ADR-0005
- **Call-down, signal-up**: Core → Foundation (direct call). Core → Presentation (EventBus signal only). Presentation → Core (forbidden). — ADR-0005
- **Two Autoloads**: `GameManager` (run state) + `AudioManager` (cross-scene BGM continuity). Both registered in `project.godot`. — ADR-0006
- **Scene switching**: `SceneTree.change_scene_to_file()`. Three scenes: `main_menu.tscn` → `game.tscn` → `death_screen.tscn`. — ADR-0006
- **New run = full reload** of `game.tscn`. No manual node reset — reload guarantees zero state leakage. — ADR-0006
- **JSON save format** at `user://save_data.json`. Atomic write: write temp file → delete real file → rename temp to real. — ADR-0014
- **Save corruption → default data**. `JSON.parse_string()` returns null → use `_default_data()`. Missing keys → merge from defaults. Never crash on bad save data. — ADR-0014
- **Schema versioning**: `version` field in save JSON. `_migrate()` runs before merge on load. Forward-compatible — unknown keys ignored. — ADR-0014

### Forbidden Approaches

- **Never use `delta` for gameplay timer accumulation.** `Engine.time_scale = 0.2` scales `delta` to 1/5 — a 15s cooldown becomes 75s. Use `Time.get_ticks_msec()`. — ADR-0001
- **Never execute game actions in `_input()`.** Only set debounce timestamps and buffer flags. All action execution belongs in `_physics_process()`. — ADR-0002
- **Never call Presentation systems directly from Core code.** No `$VFXSystem`, no `get_node("AudioSystem")` in Core scripts. Use `EventBus.signal_name.emit()`. — ADR-0005
- **Never skip the 60Hz physics tick.** Do not change `physics_ticks_per_second` from 60. Do not run gameplay logic in `_process()` that depends on physics timing. — ADR-0003
- **Never save mid-run state.** Roguelike design: death = reset. Only meta-progression and settings persist across runs. — ADR-0014
- **Never use string-based signal connections.** `connect("signal_name", obj, "method")` is deprecated since Godot 4.0. Use `signal_name.connect(callable)`. — Global / deprecated-apis.md
- **Never use `yield()`.** Use `await signal` (GDScript 2.0). — Global / deprecated-apis.md
- **Never use `instance()`.** Use `instantiate()`. — Global / deprecated-apis.md
- **Never use `OS.get_ticks_msec()`.** Use `Time.get_ticks_msec()`. — Global / deprecated-apis.md
- **Never hardcode key bindings.** All input through Godot Input Map actions. Actions: `move`, `aim`, `shoot`, `dodge`, `skill_1`, `pause`. — ADR-0002

### Performance Guardrails

- **Physics step CPU**: ≤0.8ms at 60Hz (P95). — ADR-0003
- **Total frame CPU**: ≤4.17ms at 240fps. — Global / technical-preferences.md
- **Spatial hash grid**: ≤2KB memory, ≤0.05ms rebuild per frame. — ADR-0003

---

## Core Layer Rules

*Applies to: core gameplay loop, player systems, enemy AI, physics, collision, damage*

### Required Patterns

- **Struct-of-arrays for enemy data.** `_positions: Array[Vector2]`, `_velocities: Array[Vector2]`, `_states: Array[int]`, `_timers: Array[float]`, `_hp: Array[int]`. Same index = same enemy. — ADR-0004
- **Single AI update loop** in `EnemyManager._physics_process()`. Three type-specific handlers: `_update_small(i, now)`, `_update_medium(i, now)`, `_update_large(i, now)`. — ADR-0004
- **Manual ray-circle intersection** for bullet hit detection. O(N) loop over active enemies. Returns `{index: int, position: Vector2}`. `index = -1` means miss. — ADR-0004
- **Manual distance check** for player contact damage. O(N) loop. Enemy radius + player radius overlap → contact damage. — ADR-0004
- **`MultiMeshInstance2D` for small enemies** (40 instances, 1 draw call). `Sprite2D` for medium (10) and large (3). — ADR-0004
- **Death removal deferred**: 5-10 collisions per frame removed. Avoids physics server overload from mass kills (skill_1 30-kill burst). — ADR-0004
- **Perfect dodge detection**: O(N) `distance_squared_to()` over all enemy positions + in-flight bullet positions. Nearest attack ≤40px → perfect dodge. — ADR-0007
- **Dodge displacement uses `get_physics_process_delta_time()`**, not `delta`. `Engine.time_scale = 0.2` would scale delta to 1/5 speed. — ADR-0007
- **Time scale recovery**: `f(t) = clamp(1.0 - 0.8 × e^(-6t), 0.2, 1.0)`, t ∈ [0,1]. **Hard clamp at t≥1.0** — the curve asymptote (~0.998) never reaches 1.0. Without clamp, time_scale-dependent systems never ungate. — ADR-0007
- **Skill_2 pierce via double manual pass.** Call `enemy_manager.check_bullet_hit()` for first hit, then again from hit position + 2px offset for pierce target. Two passes in one `_physics_process` frame. — ADR-0010

### Forbidden Approaches

- **Never per-enemy `_process()` or `_physics_process()`.** All enemy AI updates go through `EnemyManager` centralized loop. — ADR-0004
- **Never `CharacterBody2D` for enemy collisions.** Enemies are NOT on the physics scene tree. All collision detection is manual distance math. — ADR-0004
- **Never `PhysicsRayQueryParameters2D.intersect_ray()` for hitscan.** Use `enemy_manager.check_bullet_hit()`. Enemies off physics tree → physics ray finds nothing. — ADR-0004, ADR-0010
- **Never leave `Engine.time_scale` without hard clamp back to 1.0.** The ease-out-expo recovery curve asymptotically approaches but never reaches 1.0. Always clamp: `Engine.time_scale = clamp(recovered, 0.2, 1.0)`. — ADR-0007

### Performance Guardrails

- **Enemy AI update**: <0.1ms for 53 enemies. — ADR-0004
- **Hit detection (bullet + contact)**: <0.05ms per check. — ADR-0004
- **Perfect dodge scan**: ~80 `distance_squared_to` calls = <0.001ms. — ADR-0007
- **Enemy draw calls**: 1 (MultiMesh) + 10 (medium Sprite2D) + 3 (large Sprite2D) = 14. — ADR-0004

---

## Feature Layer Rules

*Applies to: wave management, build system, meta-progression, secondary mechanics*

### Required Patterns

- **Wave spawn via `EnemyManager.spawn_wave(config: WaveConfig)`.** WaveManager controls timing and composition; EnemyManager owns the spawn implementation. — ADR-0004
- **Build modifiers read from `GameManager.current_run.build_choices`.** ShootingSystem, SkillSystem, DodgeSystem, DamageHealthSystem each read their relevant modifiers at runtime. — ADR-0005 (EventBus signal for upgrade_selected)
- **Meta-progression unlocks persist via `SaveManager`.** Unlock list stored in `meta_progression.unlocks` array. — ADR-0014

### Forbidden Approaches

- **Never hardcode wave composition.** All wave configs data-driven — enemy counts, types, intervals from external config (not inline constants). — ADR-0004
- **Never save build state mid-run.** Current run build choices live in `GameManager.current_run` (ephemeral, dies with run). Only unlock availability persists. — ADR-0014

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, camera, particle systems*

### Required Patterns

- **Audio ducking: Attack 50ms → Hold 450ms → Release 500ms**, all real-time via `Tween.set_ignore_time_scale(true)`. — ADR-0008
- **Ducking via `AudioServer.set_bus_volume_db()` with `tween_method()`.** Resolve bus index first: `AudioServer.get_bus_index("BGM")`. Do NOT use `get_bus_effect()`. — ADR-0008
- **Kill previous ducking tween before creating new one.** Store tweens in `_duck_tweens: Array[Tween]`. Call `.kill()` on all valid tweens before starting new duck cycle. Prevents overlapping volume fights. — ADR-0008
- **Duck targets**: BGM -12dB, SFX/Weapon -9dB, SFX/Dodge -6dB, SFX/Impact -6dB, SFX/Enemy -9dB, UI -6dB, SFX/Skill 0dB (never ducked). — ADR-0008
- **Camera shake: 5 levels via `Camera2D.offset` + Tween.** SHAKE_CONFIG dict keyed by `ShakeType` enum. All shake tweens use `set_ignore_time_scale(true)`. — ADR-0009
- **8 pre-allocated particle pools**: bullet_trail(16), hit_spark(128), dodge_afterimage(8), skill_shockwave(64), skill_core(32), death_shatter(64), environment_spore(128), chemical_steam(64). Total: 504 particles. — ADR-0013
- **Pool acquire/release pattern**: `pool.acquire(pos, config)` → use → `pool.release(particle)`. Zero `add_child()`/`queue_free()` during gameplay. — ADR-0013
- **LRU recycling on pool exhaustion.** Pop oldest active particle, reset state, reuse. Never crash on pool empty. — ADR-0013
- **Particle `speed_scale` follows `Engine.time_scale`.** In `_process()`: `particle.speed_scale = Engine.time_scale`. — ADR-0013
- **Build direction visual dialect**: `DIRECTION_PALETTE` dict (fire/lightning/void). Read on each spawn. Color + particle shape + trail style + hit effect four-element consistency per direction. — ADR-0013

### Forbidden Approaches

- **Never `AudioServer.get_bus_effect(bus_name_string, 0)`.** API expects `(bus_idx: int, effect_idx: int)`. Use `get_bus_index()` + `set_bus_volume_db()`. — ADR-0008
- **Never dynamic particle create/destroy.** No `add_child()` for new particles, no `queue_free()` for expired ones. All particles pre-allocated in pools. — ADR-0013
- **Never CPU particles (`CPUParticles2D`) for high-count pools.** Use `GpuParticles2D`. GPU mode offloads transform + rendering from CPU. — ADR-0013

### Performance Guardrails

- **Particle pools**: 504 pre-allocated = ~2-3MB VRAM. Acceptable for PC target. — ADR-0013
- **Skill burst peak**: 800 particles at ≤4.17ms. — ADR-0013
- **Audio**: Ducking tween overhead <0.01ms. EventBus signal emission O(1) per connected callback. — ADR-0008, ADR-0005

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController` |
| Variables | snake_case | `move_speed` |
| Functions | snake_case | `take_damage()` |
| Signals/Events | snake_case past tense | `health_changed` |
| Files | snake_case matching class | `player_controller.gd` |
| Scenes/Prefabs | PascalCase matching root node | `PlayerController.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH` |

Source: `.claude/docs/technical-preferences.md`

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 240fps |
| Frame budget | ≤4.17ms |
| Physics tick | 60Hz |
| Physics step budget | ≤0.8ms (P95) |
| Enemy AI (53 enemies) | <0.1ms |
| Draw calls | 500 (suggested for 2D) |
| Memory ceiling | 512MB (suggested for PC) |

Source: `.claude/docs/technical-preferences.md`, ADR-0003, ADR-0004

### Approved Libraries / Addons

- GUT (Godot Unit Testing) — test framework
- No other addons approved yet

### Forbidden APIs (Godot 4.6.2)

These APIs are deprecated. Use the replacement instead:

| Deprecated | Replacement | Since |
|------------|-------------|:----:|
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D` | `VisibleOnScreenNotifier2D` | 4.0 |
| `YSort` node | `Node2D.y_sort_enabled` property | 4.0 |
| `Navigation2D` | `NavigationServer2D` | 4.0 |
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` | `instantiate()` | 4.0 |
| `PackedScene.instance()` | `PackedScene.instantiate()` | 4.0 |
| `get_world()` | `get_world_2d()` or `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 |
| `FileAccess.store_*` return void | Returns `bool` since 4.4 — must check | 4.4 |

Source: `docs/engine-reference/godot/deprecated-apis.md`

### Cross-Cutting Constraints

- **Real-time is the default time domain.** `Time.get_ticks_msec()` for all gameplay timers. `delta` only for visual interpolation (camera follow, VFX animation) and things that SHOULD be affected by time scale (enemy movement, bullet flight). — ADR-0001
- **Array-based, not node-based for performance.** Enemy AI in centralized arrays. MultiMesh for bulk rendering. No per-instance `_process()` callbacks for mass entities. — ADR-0004
- **Interface-based decoupling for circular dependencies.** DodgeSystem ↔ DamageHealthSystem resolved via read-only getter interfaces (`is_invincible()`, `get_charge_count()`). Both own their internal state. — ADR-0005, ADR-0007
- **Signal-up, call-down.** Core calls Foundation directly. Core emits signals upward to Presentation via EventBus. Presentation never calls Core. — ADR-0005
- **Cached physics queries.** `CircleShape2D` and `PhysicsShapeQueryParameters2D` for skill_1 AoE created once in `_ready()`, reused. No per-frame allocations for gameplay physics. — Global / architecture.md
- **Typed GDScript everywhere.** `Array[Type]`, typed variables. No untyped `Array` or `Dictionary` in production code. — `.claude/docs/technical-preferences.md`
- **`@onready var` for node references.** Never `$NodePath` in `_process()` — cache at ready. — Global / current-best-practices.md
- **No hardcoded gameplay values.** All balance values (damage, cooldowns, speeds, ranges) from external config or `@export` vars. — `.claude/docs/coding-standards.md`

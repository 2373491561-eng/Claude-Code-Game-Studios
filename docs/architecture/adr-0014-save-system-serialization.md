# ADR-0014: Save System Serialization Format

## Status
Accepted

## Date
2026-05-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Data |
| **Knowledge Risk** | MEDIUM — `FileAccess` store methods return `bool` since 4.4 (post-cutoff change from `void`); JSON via `JSON.stringify()`/`JSON.parse_string()` is in training data |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | `FileAccess.store_string()` returns `bool` (4.4+) — must check return value |
| **Verification Required** | Confirm `FileAccess.open("user://save_data.json", FileAccess.WRITE)` creates intermediate directories in Godot 4.6.2 — `user://` is platform-mapped; test on Windows target |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0006 (GameManager holds meta-progression state that save system reads on game launch) |
| **Enables** | Meta-progression system persistence, settings system persistence |
| **Blocks** | Meta-progression — unlocks aren't meaningful if lost on restart |
| **Ordering Note** | Implement after GameManager (ADR-0006) Autoload exists; settings system and meta-progression will write through this ADR's interface |

## Context

### Problem Statement
《裂隙反应》的跨局进度（解锁状态、最高波次记录、总点数）和玩家设置（音量）需要在游戏重启后保持。Roguelike Run 本身不持久化（死亡即重置），但跨局进度是玩家"成长感"的物理载体——每次死亡后的解锁记录不能丢失。

存档系统 GDD 指定 JSON 格式 + `user://` 路径。此 ADR 定义序列化格式、保存时机、错误恢复策略，以及哪些数据属于存档 vs 哪些不属于。

### Constraints
- 单机游戏 — 无云存档、无多设备同步需求
- PC (Steam) — `user://` 映射到 `%APPDATA%/Godot/app_userdata/[project_name]/`
- Roguelike Run 本身不保存 — Run 中途退出 = 进度丢失（设计意图，非技术限制）
- 设置系统（音量）需要即时保存，跨局进度在死亡结算后保存

### Requirements
- 存档文件损坏或缺失时游戏正常启动（使用默认值，不崩溃）
- JSON 格式 — 可读、可手动编辑、版本可扩展
- 明确区分"持久数据"和"会话数据"
- 保存操作原子化（先写临时文件，成功后再替换 — 防止写入中途崩溃导致损坏）

## Decision

**使用 JSON 格式保存至 `user://save_data.json`。存档包含三类数据：跨局进度、玩家设置、元信息（版本号）。保存使用原子写入（write-to-temp → rename）。Run 中间状态明确不保存。**

### Save Data Schema

```json
{
  "version": 1,
  "last_updated": 1715332800,
  "meta_progression": {
    "total_points": 0,
    "highest_wave": 0,
    "unlocks": []
  },
  "settings": {
    "master_volume": 1.0,
    "bgm_volume": 0.7,
    "sfx_volume": 0.85
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `version` | int | 1 | Schema version — increment on breaking changes |
| `last_updated` | int | 0 | Unix timestamp of last save |
| `meta_progression.total_points` | int | 0 | Accumulated meta currency |
| `meta_progression.highest_wave` | int | 0 | Best wave reached across all runs |
| `meta_progression.unlocks` | Array[String] | [] | List of unlocked upgrade IDs |
| `settings.master_volume` | float | 1.0 | 0.0–1.0, linear |
| `settings.bgm_volume` | float | 0.7 | 0.0–1.0, linear |
| `settings.sfx_volume` | float | 0.85 | 0.0–1.0, linear |

### SaveManager (Autoload)

```gdscript
# Autoload — registered in project.godot after GameManager
class_name SaveManager extends Node

const SAVE_PATH = "user://save_data.json"
const SAVE_TEMP_PATH = "user://save_data.tmp"

var data: Dictionary = _default_data()

func _default_data() -> Dictionary:
    return {
        version = 1,
        last_updated = 0,
        meta_progression = {
            total_points = 0,
            highest_wave = 0,
            unlocks = [],
        },
        settings = {
            master_volume = 1.0,
            bgm_volume = 0.7,
            sfx_volume = 0.85,
        },
    }

func _ready() -> void:
    _load()

func _load() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return  # Use defaults — first launch
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_warning("SaveManager: Cannot open save file — using defaults")
        return
    var content = file.get_as_text()
    file.close()
    var parsed = JSON.parse_string(content)
    if parsed == null or not parsed is Dictionary:
        push_warning("SaveManager: Save file corrupted — using defaults")
        return
    # Merge: only update known keys, preserve defaults for missing ones
    _merge_loaded(parsed)

func save() -> void:
    data.last_updated = Time.get_unix_time_from_system()
    var json_string = JSON.stringify(data, "\t")  # Pretty-printed for readability
    # Atomic write: temp file first, then rename
    var temp_file = FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)
    if temp_file == null:
        push_error("SaveManager: Cannot write temp save file")
        return
    temp_file.store_string(json_string)
    temp_file.close()
    # Rename temp → real (atomic on most filesystems)
    DirAccess.remove_absolute(SAVE_PATH)
    DirAccess.rename_absolute(SAVE_TEMP_PATH, SAVE_PATH)
```

### What Gets Saved vs What Does Not

| Category | Saved? | Reason |
|----------|:------:|--------|
| Meta progression (points, unlocks) | YES | Core player progression — must persist |
| Settings (volume) | YES | Player preference — must persist |
| Current Run state (wave, HP, build choices) | NO | Roguelike design — death = reset. Run quit = forfeit |
| Run history/stats | NO | Not MVP — future extension candidate |
| Achievements | NO | Not MVP — future extension candidate |
| Keybindings | NO | Not MVP — fixed Input Map in MVP |

### Save Triggers

| Event | Action |
|-------|--------|
| Death screen → "Return to Menu" clicked | `SaveManager.save()` — persists meta progression delta from this run |
| Settings slider released | `SaveManager.save()` — instant persist of volume changes |
| Game launch | `SaveManager._load()` in `_ready()` — loads existing or uses defaults |

### Corruption Recovery

| Scenario | Behavior |
|----------|----------|
| File missing (first launch) | Use `_default_data()` — silent |
| File exists but `JSON.parse_string()` returns null | Use defaults — `push_warning()`, game continues |
| File exists, valid JSON, missing keys | Merge — loaded values overwrite defaults, missing keys keep defaults |
| File exists, valid JSON, unknown keys | Ignored — forward-compatible (future versions may add keys old code ignores) |
| Temp file exists at launch | Delete it — previous save was interrupted |

### Schema Migration

When `version` increments in a future update:

```gdscript
func _migrate(loaded: Dictionary) -> Dictionary:
    match loaded.get("version", 0):
        0:
            # Pre-versioning save — add version field
            loaded["version"] = 1
        1:
            pass  # Current version
    return loaded
```

Migration runs before merge. Old versions are upgraded in-place, then merged with defaults.

## Alternatives Considered

### Alternative 1: Godot Resource (.tres / .res)
- **Pros**: Type-safe via `ResourceSaver`/`ResourceLoader`, native Godot serialization, no manual parsing
- **Cons**: Binary format — not human-readable for debugging. Resource class changes break old saves silently. Version migration requires keeping old resource scripts
- **Rejection Reason**: JSON is readable, debuggable, and version-tolerant. Save data is small (~500 bytes) — JSON parse overhead is negligible

### Alternative 2: ConfigFile (.cfg / .ini)
- **Pros**: Built-in Godot class `ConfigFile`, section-key-value structure, simple API
- **Cons**: Flat key-value only — no nested structures. Meta progression unlock list requires manual serialization (e.g., comma-separated). Schema versioning is ad-hoc
- **Rejection Reason**: JSON handles nested data (arrays, objects) cleanly. `ConfigFile` adds complexity for structured data with no benefit for a single-file save

### Alternative 3: Encrypted save (prevent tampering)
- **Pros**: Players can't manually edit unlock state
- **Cons**: Single-player game — no competitive integrity at stake. Encryption adds complexity (key management, binary format). If a player edits JSON to unlock everything, they only cheat themselves
- **Rejection Reason**: Anti-tamper is unnecessary for a single-player roguelike. JSON readability is more valuable for debugging and player transparency

## Consequences

### Positive
- Human-readable saves — debug with any text editor
- Atomic write prevents corruption from mid-write crashes
- Schema version field enables forward-compatible migration
- SaveManager as Autoload gives any system read/write access via a single interface
- Missing/corrupt file never blocks game launch

### Negative
- JSON not type-safe — runtime errors if a system expects int but JSON stored float
- `user://` path is platform-dependent — testing on Windows doesn't validate Linux/macOS behavior
- No encryption — player can manually edit JSON to unlock everything (accepted risk for single-player)
- Pretty-printed JSON (~500 bytes) is slightly larger than binary — irrelevant for this data size

### Risks
- **JSON float precision**: Godot `float` is 64-bit; JSON number is double-precision. Volume values (0.0–1.0) are safe. Mitigation: keep floats to 2 decimal places for settings
- **Schema drift**: New fields added in later versions must have defaults. Mitigation: `_merge_loaded()` always fills missing keys from `_default_data()` — forward-compatible by design
- **Save triggered during scene transition**: If `save()` is called mid-transition, file I/O may hitch. Mitigation: settings saves are ~200 bytes — write in <1ms. Meta progression save (~500 bytes) fires during death screen (no gameplay in progress)

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| save-system.md | JSON 格式保存至 `user://save_data.json` | JSON schema with atomic write |
| save-system.md | 存档损坏/缺失 → 默认值，不崩溃 | `_load()` fallback chain: file missing → parse failed → merge defaults |
| save-system.md | 死亡结算后自动保存 | `SaveManager.save()` triggered on "Return to Menu" |
| save-system.md | 设置变更即时保存 | `SaveManager.save()` triggered on slider release |
| meta-progression.md | 解锁状态跨 Run 持久化 | `meta_progression.unlocks` array in schema |
| meta-progression.md | 点数累积保留 | `meta_progression.total_points` in schema |
| settings-system.md | 音量设置重启后保留 | `settings.*` fields in schema |

## Performance Implications
- **CPU**: `JSON.stringify()` on ~500-byte Dict — <0.05ms. `FileAccess` write — <1ms for temp file + rename
- **Memory**: In-memory `data` Dictionary — ~300 bytes
- **Load Time**: `JSON.parse_string()` on ~500 bytes — <0.1ms at game launch. No impact on scene transitions
- **I/O**: Save triggered on death screen (no gameplay) and settings changes (rare, user-driven) — zero gameplay impact

## Validation Criteria
- 第一次启动（无存档文件）：游戏正常启动，使用默认音量，0 点数，0 解锁
- 完成一局后回主菜单 → 重启游戏 → 点数和解锁状态保留
- 存档文件手工改成无效 JSON → 游戏启动 → 使用默认值，控制台有 warning
- 存档文件手工删除某个 key → 游戏启动 → 该 key 使用默认值，其余保留
- 存档写入中途强制关闭游戏 → 下次启动 → 使用上次完整存档或默认值（无 JSON 语法错误）
- 调整音量后立即 Alt+F4 → 重启 → 音量设置保留

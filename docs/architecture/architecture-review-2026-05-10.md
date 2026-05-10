# Architecture Review Report

**Date**: 2026-05-10
**Engine**: Godot 4.6.2
**GDDs Reviewed**: 20 system GDDs + game-concept
**ADRs Reviewed**: 12 (ADR-0001 through ADR-0014)

---

## Verdict: CONCERNS

Foundation and Core layers (the MVP-critical layers) are fully covered with 0 gaps. Two ADR bugs were found and fixed during the review. Feature/Presentation/Polish layer gaps are mostly implementation details, not architectural decisions.

---

## Traceability Summary

| Layer | Total TRs | Covered | Partial | Gaps |
|-------|:---------:|:-------:|:-------:|:----:|
| Foundation | 8 | 8 | 0 | 0 |
| Core | 17 | 17 | 0 | 0 |
| Cross-system | 2 | 2 | 0 | 0 |
| Feature | 7 | 1 | 1 | 5 |
| Presentation | 8 | 0 | 3 | 5 |
| Polish | 3 | 0 | 0 | 3 |
| **Total** | **45** | **28** | **4** | **13** |

**Coverage**: 62% (28/45), Foundation+Core 100%.

---

## Bugs Found and Fixed

| ADR | Bug | Fix |
|-----|-----|-----|
| ADR-0008 | `AudioServer.get_bus_effect("BGM", 0)` — param type error (string instead of int) | `AudioServer.get_bus_index()` + `AudioServer.set_bus_volume_db()` via `tween_method()` |
| ADR-0010 | `intersect_ray()` conflicts with ADR-0004 manual collision detection | Switched to ADR-0004 `check_bullet_hit()` manual ray-circle math |
| ADR-0004 | Missing ADR-0010 in "Enables" field | Added ADR-0010 as consumer of `check_bullet_hit()` API |

---

## Cross-ADR Conflicts

**Resolved**: ADR-0004 vs ADR-0010 collision detection approach — unified to manual detection per ADR-0004. ADR-0010 revised to use `check_bullet_hit()`.

---

## ADR Dependency Order

**Foundation (no deps)**:
1. ADR-0001: Real-time timing strategy
2. ADR-0002: Input processing (→ ADR-0001)
3. ADR-0003: Physics 60Hz + spatial hash (→ ADR-0001, ADR-0002)

**Core (depends on Foundation)**:
4. ADR-0004: Enemy manager (→ ADR-0003)
5. ADR-0005: Event/signal architecture (→ ADR-0001, ADR-0002, ADR-0004)
6. ADR-0006: Scene lifecycle (→ ADR-0005)
7. ADR-0007: Perfect dodge detection (→ ADR-0002, ADR-0004)
8. ADR-0008: Audio ducking (→ ADR-0005)
9. ADR-0009: Camera shake (→ ADR-0005)
10. ADR-0010: Skill_2 pierce (→ ADR-0004, ADR-0007)

**Feature/Presentation/Polish**:
11. ADR-0013: VFX particle pool (→ ADR-0005, ADR-0003)
12. ADR-0014: Save system (→ ADR-0006)

No circular dependencies detected.

---

## Engine Compatibility

- All 12 ADRs have Engine Compatibility sections
- No deprecated API usage across all ADRs
- All ADRs agree on Godot 4.6.2
- HIGH RISK engine domains (4.5+/4.6 changes) addressed in architecture.md

---

## New ADRs Created

| ADR | Topic | Covers |
|-----|-------|--------|
| ADR-0013 | VFX particle pool architecture | TR-vfx-001, TR-vfx-002 |
| ADR-0014 | Save system serialization format | TR-save-001, TR-save-002, TR-meta-002 |

**Slots reserved**: ADR-0011 (flow-field pathfinding), ADR-0012 (TBD)

---

## GDD Revision Flags

None — all GDD assumptions are consistent with verified engine behavior.

---

## Remaining Gaps (non-blocking)

Most Feature/Presentation/Polish gaps are implementation details that don't require dedicated ADRs. Only 2 ADRs remain to be written:
- ADR-0011: Flow-field vs direct-chase pathfinding (depends on arena obstacle design)
- ADR-0012: TBD

---

## Review Metadata

- **Chain-of-Verification**: 5 questions checked — verdict unchanged
- **Director panel**: CD READY / TD CONCERNS / PR CONCERNS / AD CONCERNS
- **Bugs fixed during review**: 2
- **New ADRs created**: 2

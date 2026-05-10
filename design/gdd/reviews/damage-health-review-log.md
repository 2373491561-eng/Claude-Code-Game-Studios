# Damage & Health System — Review Log

## Review — 2026-05-08 — Verdict: MAJOR REVISION NEEDED (resolved same session)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, creative-director
Blocking items: 7 (all resolved in revision) | Recommended: 7 | Nice-to-Have: 4

Summary: First review. 8/8 sections present, all 7 dependencies exist. 7 blocking items found: (1) normal dodge healing contradicted dodge GDD v2 — aligned to only perfect dodge (charge≥1) heals; (2) perfect dodge detection expanded from bullet-only to all enemy attack types (contact, projectile, melee) at 40px; (3) damage formula changed from hardcoded `hp-1` to `incoming_damage` variable system; (4) shield overflow formula added for damage>1; (5) shield + invincibility frame stacking order defined (shield first, iframes only on HP damage); (6) death guard added to healing formula (`if hp > 0`); (7) ACs expanded from 8 to 20 covering all enemy HP tiers, shield expiry, time_scale immunity, and build damage. All resolved in same-session revision. Creative-director verdict: APPROVED after revisions.

Prior verdict resolved: First review

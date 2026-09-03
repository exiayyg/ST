---
name: singular-tower-development
description: Develop, review, architect, balance, test, or design Singular Tower / 一炮千径 while preserving its frozen gameplay rules, unresolved design boundaries, and Godot GDExtension–GDScript division of responsibility. Use for any change to this game; do not use for unrelated Godot projects.
---

# Singular Tower Development

Treat this skill as the project design contract, not as optional inspiration. 《Singular Tower / 一炮千径》 is a real-time systems strategy game about weaving the only tower's fixed momentum source into a movable device network under tower-defense pressure. It is not conventional tower defense with one tower, and not a physics sandbox.

## Load the right contract

- Always read [references/design-canon.md](references/design-canon.md) before changing gameplay, data models, content, UI, or player-visible behavior.
- Always read [references/open-decisions-and-guardrails.md](references/open-decisions-and-guardrails.md) before proposing a new rule, choosing a default, or filling in missing behavior.
- Read [references/architecture-and-performance.md](references/architecture-and-performance.md) for any implementation, refactor, profiling, performance, testing, or GDExtension/GDScript decision.
- Read [references/ux-and-content.md](references/ux-and-content.md) for UI/UX, visual feedback, enemy warnings, levels, tutorials, waves, bosses, or mode design.

## Decision workflow

1. Classify each requested behavior as **frozen**, **unfrozen**, or **new**.
   - Preserve frozen behavior exactly.
   - Keep unfrozen behavior data-driven behind a named strategy/interface or an explicit TODO; do not silently choose a permanent rule.
   - Treat new player-visible mechanics as proposals. Do not add them merely because they are conventional or convenient.
2. Test the change against the project's five questions:
   - Does it improve the player's ability to design, understand, route, or optimize momentum paths?
   - Does entropy still mean uncertainty only?
   - Do enemies, devices, the map, and projectiles obey the same world rules?
   - Does it strengthen spatial/system construction instead of conventional stat stacking?
   - Does it preserve high player freedom over device placement, movement, rotation, and routing?
3. Select the language boundary from the measured work shape. The native projectile simulation is an intentional C++ foundation; orchestration and volatile design remain in GDScript. Do not move code to C++ merely because it is mathematical.
4. Keep balance values and unfrozen functions out of compiled rules. Expose typed Resources/configuration and narrow native APIs.
5. Verify invariants at the smallest stable seam, then profile representative load when per-frame or per-entity work changed.

When handing off a change, state which rules were frozen versus left configurable and whether the C++/GDScript boundary changed.

# Open decisions and guardrails

## Explicitly prohibited unless design changes

- Traditional gold/wood/mineral/build costs or a new global resource HUD.
- Device levels, upgrades, or maintenance energy.
- Fixed tower slots, fixed enemy roads, or a second attack tower.
- A fixed device toolbar or per-projectile information panel.
- Entropy as damage, crit, reward multiplier, stun, slow, attack reduction, or another generic debuff.
- Automatic protection for badly placed inactive devices, inactive-device count caps, or automatic activation priority.
- Formal projectile deletion because of lifetime, high entropy, leaving a region/screen, or interaction count.
- Collapsing speed and mass increasers into the same damage multiplier.
- Enemies that are only HP and wait passively to be hit.
- Removing free device movement or rotation to simplify implementation.
- Dense scientific instrumentation that repeats states the world can communicate.
- A permanent device unlock/purchase tree inferred from level teaching.

If technical safety requires a cap or cleanup, label it as an exceptional guard, emit diagnostics, keep it outside ordinary balance, and ensure it does not masquerade as a player-facing rule.

## Not frozen: parameterize or isolate

- Tower fire rate, initial projectile mass, initial speed, and initial momentum.
- Tower muzzle offset along the frozen firing direction. Lateral lane count, lateral spacing, initial firing spread, and free-flight entropy drift are not balance parameters because the unique deterministic initial path is frozen.
- Device activation requirements, HP, lighting radii, and physical multipliers.
- Entropy growth function, onset threshold, saturation point, monotone response curve, interaction multipliers, perturbation distributions, and maximum deviations. The existence of a zero-uncertainty region before the threshold is frozen; its numeric extent is not.
- Enemy entropy transfer ratio, stacking, duration/decay, thresholds, and per-enemy response functions.
- Final enemy roster/AI and all enemy combat/movement numbers.
- Wave duration, target-utilization curve, pressure/spawn-frequency curve, and phase timing.
- Concrete bosses and abilities.
- Whether `TargetReached` immediately ends a wave or it continues to a fixed finish outside the agreed endless-mode clear-then-intermission flow.
- Wave-point count, fan angle, propagation speed, receiver collision radius, and other numeric geometry.
- Map dimensions, camera rules, and whether a minimap exists.
- Exact radial-menu hold threshold and animation.
- Cloud synchronization, expanded run history, permanent power progression, and other metagame content beyond the agreed local level completion/best-utilization record.

Represent these as typed data, curves, strategy objects/interfaces, or explicitly named TODO seams. A provisional test value may live in configuration, but must not be described as final design.

All unfrozen numeric gameplay, UX, presentation, and technical tuning values belong in the project balance profile and its visual tuning surface. Do not leave a second authoritative copy embedded in gameplay scripts or the native algorithm. Mathematical identities, storage layout constants, and validation bounds are implementation details rather than balance values.

## Change classification

Use these labels in specs and reviews:

- **Frozen invariant**: the canon states the behavior. Code and tests must enforce it.
- **Balance parameter**: the behavior is known, but its numeric value/curve is not. Keep it editable without recompiling the native core.
- **Open rule**: competing behaviors are still unresolved. Preserve an interface and avoid choosing one as canon.
- **New proposal**: not present in canon. Explain its value against the five project questions and get design direction before shipping it as player-visible behavior.

Absence is not permission to import a conventional tower-defense mechanic.

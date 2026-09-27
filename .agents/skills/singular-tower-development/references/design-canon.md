# Frozen design canon

## Product identity and player fantasy

The player maintains, migrates, and optimizes a dynamic momentum network under enemy pressure. A single fixed source becomes a map-spanning system of paths, loops, amplifiers, converters, and storage. Complexity creates power and coverage, but also entropy-driven uncertainty that can spread symmetrically to enemies.

The design priority is internal, readable game physics rather than real-world physical accuracy. Space, topology, timing, and system behavior matter more than conventional tower-defense stat progression.

## The only tower and the only initial source

- Exactly one center/unique tower exists at the start of a run.
- Its position, facing, and firing direction are fixed and cannot be changed.
- Every ordinary projectile created directly by the center tower starts at the same fixed muzzle point and follows the same deterministic initial path. There are no parallel firing lanes, lateral offsets, firing-angle randomness, or entropy drift before a device changes that path.
- Once a tower projectile interacts with a device, it follows the ordinary device and entropy rules; tower origin does not grant permanent immunity from uncertainty. Projectiles reconstructed by converters or accumulators begin at their reconstructing device and do not have to align with the tower's initial path.
- It is the only object that actively creates ordinary projectiles and the only source of initial momentum. Devices cannot create ordinary initial momentum from nothing.
- The tower has HP. Destruction at HP `<= 0` causes immediate run failure, independently of wave efficiency.

## Projectiles, momentum, activation, and destruction

- A projectile is both an attack carrier and the sole core resource currently defined.
- Each projectile has independent continuous state, at minimum position, velocity/vector, mass, momentum derived from `p = m × v`, and entropy. There is no global “current projectile state.”
- Devices are free to place. There is no gold, wood, ore, build currency, or global activation-energy pool.
- Every newly placed device starts inactive. An inactive device performs none of its normal function. A projectile that interacts with it transfers all momentum to that device's own activation progress; reaching zero momentum destroys the projectile.
- No device can be activated by one ordinary initial projectile. Activation requires accumulated momentum from multiple projectiles, and device types may require different amounts.
- Activation is a permanent one-time state transition. An activated device functions until destroyed; it has no maintenance drain, recharge cycle, level, or upgrade path.
- Do not limit the number of inactive devices, protect them from bad placement, or automatically choose an activation order. Geometry and the player's routing decisions determine which device receives momentum first. Wasteful placement is allowed to fail naturally.
- A projectile's only formal destruction condition is momentum becoming zero. Lifetime, entropy, leaving the screen, and interaction count are not game-rule deletion conditions. Engineering failsafes must remain exceptional, observable in diagnostics, and invisible as normal rules.
- A projectile reconstructed from stored/transformed energy starts with entropy `0`; it never copies source entropy. This applies to wave–particle reconstruction and accumulator reconstruction.

## Device lifecycle and spatial freedom

- Devices are not attack towers. Their purpose is to change projectile paths or state: direction, position/topology, speed, mass, momentum, charge, particle/wave form, or storage.
- All device types are in principle selectable from the beginning of a run. A level may spotlight or teach one without inventing a permanent unlock/purchase tree.
- Initial placement is allowed only in currently lit space.
- After placement, devices remain freely movable and rotatable during combat, including after activation. Preserve this freedom as a core operation, not an editor-like concession.
- Every device has HP whether inactive or active. Destruction stops all behavior and removes its lighting contribution immediately.
- A player may deliberately dismantle a selected device. Dismantling removes a diode pair atomically, contributes no momentum or damage, and permanently discards activation progress plus any stored mass, particle momentum, or wave momentum without reconstructing a projectile.

## Map, fog, and strategic regions

- The battlefield is open: no fixed roads and no fixed tower slots.
- Initially only the center tower's surrounding area is lit. Most of the map is black fog and hides information.
- Players cannot initially place devices inside unlit fog.
- Only activated devices illuminate a limited radius. Lighting is coverage-dependent, not permanent exploration. Destroying a device removes only that device's lighting contribution; overlapping coverage from every other activated, undestroyed device remains, and only uncovered space returns to fog.
- Expansion is a momentum investment and a strategic layer. Players may build regional loops in different directions and redistribute activated infrastructure according to warnings instead of investing equally everywhere.

## Enemies and warnings

- Enemies have no fixed lane. They usually emerge from fog/map edges in multiple directions and move toward the center area.
- Enemies actively attack devices and the center tower. They are not passive HP targets; damaging the network can break routing and visibility.
- Incoming attacks are warned by direction arrows. Arrow color communicates amount/pressure at a glance.
- Clicking a warning arrow opens information for that direction containing only the precise enemy type names and counts. Do not reduce this to vague “melee/ranged/special” categories or expand it into exact future paths/full omniscience.
- Exact enemy rosters and final AI are not frozen. Any example names in design discussion are illustrative until explicitly promoted to canon.

## Entropy: uncertainty and nothing else

- Entropy is a continuous intrinsic property of each projectile, not a global field, heat model, quality tier, second currency, damage multiplier, crit system, rage, or corruption meter.
- Entropy grows in flight and through device interactions. More prior interactions accelerate later growth. The exact function and coefficients are not frozen.
- Entropy does not cause mechanical uncertainty from its first nonzero increment. A configurable onset threshold exists: at or below that threshold, device transforms and enemy behavior outputs remain mechanically deterministic. Above the threshold, the maximum uncertainty amplitude increases monotonically with entropy until a configurable saturation point. The threshold, saturation value, monotone response curve, and maximum deviations are balance data rather than permanent numeric law.
- Low-entropy results stay close to a device's ideal deterministic transform. As entropy rises, every output property relevant to that interaction may independently deviate slightly around the ideal result. Rules still operate; their outcomes become less predictable.
- Entropy never directly grants damage. Its purpose is to destabilize indefinitely precise, indefinitely amplifying loops without a blunt lifetime deletion rule.
- High-entropy projectiles transfer/inject entropy into enemies. Enemy entropy changes the certainty of their native behavior: for example aim precision, shield position, or target selection. It must not become ordinary bonus damage, stun, slow, attack reduction, or a generic numeric debuff.
- Player and enemy uncertainty must be legible through world behavior and visuals. The same semantic rule applies to both sides.

## Frozen device behaviors

### Diode

A diode is a permanently paired entrance/tail and exit/head. A projectile entering the tail immediately exits the head. The exit angle is player-adjustable; both endpoints can move independently. A world-space link must communicate the pairing. Its main role is spatial topology, not damage.

### Bounce plate

Reflect momentum direction according to clear, stable geometric incidence/reflection. Entropy may perturb relevant output around the ideal reflection.

### Magnetic field

Qualifying charged projectiles undergo circular motion, enabling arcs and loops. A charged projectile entering or leaving the field creates a small shockwave at its current location. Radius, strength, charge conditions, and shockwave numbers remain balance data.

### Electric field

Makes projectiles charged. While a projectile remains inside, it accelerates continuously and slowly rather than receiving a one-time entry boost. Acceleration and region parameters remain configurable.

### Wave–particle converter

Each entering projectile terminates its particle state and distributes all of its momentum into a fan made from `N` discrete moving wave points. Every point carries the equal scalar share `P/N`; the count, fan angle, and propagation speed are balance data. Wave points have no mass, charge, or entropy, and a nonzero point persists regardless of age, range, screen, or map bounds. It retires only after a compatible activated converter absorbs all of its momentum. A point ignores its source converter until it has left the source body, after which ordinary receiver ordering applies.

A compatible activated converter stores all arriving wave-point momentum. For every stored amount equal to one center-tower initial projectile, it automatically reconstructs one ordinary projectile along its facing with the tower's initial mass and speed, neutral charge, and entropy `0`; multiple threshold crossings emit multiple projectiles and leftover momentum remains stored. This is discrete propagation and reception, never an area-damage ability.

### Splitter

One projectile becomes two projectiles emitted from fixed opposite/end emission points. Both outputs travel in the same parallel direction and their shared direction adjusts synchronously. Momentum is conserved as `P → P/2 + P/2`; never duplicate full momentum.

### Speed increaser

Increases speed and therefore momentum at unchanged mass. It modifies physical state, not a direct damage multiplier. The multiplier is balance data.

### Mass increaser

Increases mass and therefore momentum at unchanged speed. It is a distinct physical construction axis from the speed increaser and must not collapse into the same internal “damage multiplier.” The multiplier is balance data.

### Accumulator

Absorbs each entering projectile's full mass and scalar momentum into player-timed storage. Manual release consumes all stored mass and momentum to reconstruct exactly one neutral projectile along the accumulator's facing, with speed `stored momentum / stored mass` and entropy `0`, then clears both stores. The intent is a store-then-burst loop distinct from continuous loops.

## Momentum utilization and wave outcome

- The core per-wave metric is momentum utilization:

  `cumulative projectile damage dealt to enemies this wave / cumulative momentum originally generated by the center tower this wave`

- The denominator counts only original tower-generated momentum. Momentum later added by speed/mass increasers is not added to the denominator.
- Efficiency may exceed `100%`; this is intended and demonstrates repeated/amplified use of the unique source.
- Each wave has its own time window, target threshold, numerator, and denominator.
- Failure occurs if the target is not reached within the time limit. While below target, enemy appearance frequency rises through pressure phases; the curve and timings are data.
- `TargetReached` and `WaveFinished` are distinct states/events. Whether reaching the target ends the wave immediately remains unfrozen.
- Center-tower destruction is an independent immediate failure. Device destruction alone is not, though its systemic consequences may lead to failure.

## Run rhythm, bosses, and modes

- A full run aims for roughly 5–30 minutes.
- Pressure changes in stages, not as an uninterrupted linear escalation. After the player creates a coherent loop, provide a window to watch it operate and enjoy kills/efficiency growth before later pressure exposes weaknesses.
- Boss/high-pressure stages are construction-level tests, not merely high HP. Across the boss system, test both burst/storage builds and long-running stable/cyclic builds; interference resistance and spatial coverage may also be tested. Specific bosses and skills are not frozen.
- At least level mode and endless mode exist.
- Level mode teaches mainly through designed encounters and observable consequences, not large explanatory popups. Spotlighting devices across levels does not imply a permanent unlock tree.
- Player-facing builds enter through a mode menu that exposes level mode and endless mode. Single-wave and construction regression scenes are development-only surfaces.
- Authored campaign levels unlock sequentially from completed prerequisites. This progression gates levels only: every playable level continues to expose all device types through the radial menu.
- The first local campaign record stores each level's completion state and best momentum utilization. Utilization records may exceed `100%`, consistent with the core metric.

### Endless-mode run structure

- The endless mode keeps the current tower, device network, lighting coverage, accumulator stores, and every nonzero-momentum projectile across wave boundaries. Starting a new wave resets only that wave's accounting, never the physical world.
- Its agreed phase order is real-time preparation, active wave, target-reached clearing, real-time intermission, then the next active wave. Phase durations are balance data.
- Reaching the utilization target stops that wave's clock and future spawns. Existing enemies keep acting until cleared; only then is `WaveFinished` emitted and intermission begun. Tower destruction remains an immediate failure during clearing.
- Damage is attributed by when it occurs: every actual enemy damage event during the active wave enters that wave's numerator. Its denominator contains only center-tower momentum generated during that active wave, so momentum prepared or retained across a boundary can improve the next wave's utilization.
- Endless difficulty emphasizes changing direction combinations and enemy composition, with optional slow capped enemy-stat growth. Templates, threat budgets, growth rates, caps, and enemy identities remain balance/content data rather than frozen numbers.

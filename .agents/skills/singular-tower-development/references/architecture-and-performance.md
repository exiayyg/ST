# Godot hybrid architecture and performance contract

## Default boundary

Use GDExtension/C++ for high-volume, per-tick continuous simulation. Use GDScript for volatile gameplay orchestration, content, editor-facing authoring, UI, and scene presentation. The boundary follows data volume and call frequency, not conceptual importance.

The project's native foundation should own an authoritative projectile simulation from the beginning because high projectile counts, continuous independent state, fields, loops, and interactions are defining workloads rather than speculative features.

## Build in C++ from the start

Create a narrow native simulation module responsible for:

- packed/data-oriented projectile state and stable projectile IDs;
- fixed-timestep integration of position, velocity, mass, charge, momentum, and entropy;
- spatial indexing/broad-phase candidate generation for many projectiles against devices, fields, enemies, and map bounds;
- batched electric/magnetic field evaluation and continuous acceleration/circular-motion math;
- ordered interaction transforms, entropy perturbation, momentum-zero retirement, split/reconstruction creation, and buffered gameplay events;
- deterministic seeded random streams for entropy perturbations and reproducible simulations;
- hot conservation/accounting primitives used inside the loop, while reporting aggregate wave damage/source-momentum events to the higher-level wave system.

Avoid a `Node` and GDScript callback per projectile. Store hot state in contiguous arrays/structures, reuse buffers, and batch the boundary. Do not emit per-projectile signals every frame.

## Keep in GDScript

- Run/wave state, pressure phases, victory/failure orchestration, `TargetReached` versus `WaveFinished`, and spawn schedules.
- Typed Resources/configuration for balance values, curves, device definitions, enemies, levels, and unresolved strategies.
- Input, radial menu, selection, dragging/rotation, camera, HUD, warning panels, and accessibility.
- Scene construction, device/enemy presentation, health/charge bars, VFX/audio, animation, and tutorial sequencing.
- High-level enemy state machines and authored behaviors at ordinary counts.
- Save/meta systems if later designed.
- Debug overlays, tooling, and experiment/prototype code.

Mathematical code is not automatically native. A formula run once on a click or wave transition belongs comfortably in GDScript.

## Conditional hotspots: prototype, measure, then migrate

- Fog-of-war coverage recomputation: keep an event-driven grid/mask implementation in GDScript or RenderingServer/shaders until large maps, many moving lights, or destruction churn exceeds budget; then move coverage math to C++ while keeping visuals in Godot.
- Wave–particle propagation/reception: prototype the unfrozen rule in GDScript. Move sampling, geometry queries, or large receiver sets to C++ only after the rule stabilizes and profiles hot.
- Enemy crowd movement, avoidance, and target scoring: keep authored AI in GDScript; move only batched sensing/steering queries when representative enemy counts prove costly.
- Rendering: prefer MultiMesh, RenderingServer, particles, and shaders for bulk projectile/trail visuals. C++ may prepare packed snapshots, but should not replace GPU work with CPU drawing.
- Path previews and prediction: keep interaction/UI policy in GDScript; move repeated many-projectile prediction kernels only if profiling identifies them.

Current measured boundary for the network-lab prototype: the 256×144 mask with 100 lights measured `764.849 ms` p95 in GDScript, far above its `3 ms` migration gate. The coverage raster therefore belongs in the GDExtension adapter, while GDScript still owns event-driven invalidation, light-source selection, overlap semantics, `ImageTexture` updates, and gameplay visibility queries. The native raster measured `2.739 ms` p95 in the Debug integration run on the recorded baseline machine. Projectile and wave rendering likewise uses C++-prepared MultiMesh buffers; Godot owns the meshes, draw order, fog overlay, and device presentation.

## Native/GDScript seam

Expose one deep module with a small API rather than many chatty native objects. A suitable shape is:

- GDScript submits command batches at tick boundaries: tower emissions, device transforms/state, enemy collider/sensor data, manual accumulator release, and configuration changes.
- C++ advances the authoritative projectile state for a fixed step.
- C++ returns aggregate/buffered events: hits/damage, momentum absorbed, activations, shockwaves, reconstructed/split projectiles, projectile retirements, and diagnostic guards.
- Rendering reads a bulk snapshot/interpolation buffer keyed by IDs; views are disposable and are not the authoritative state.

Avoid crossing the extension boundary once per projectile. Prefer packed arrays or native buffer/view objects. Avoid unnecessary `Variant`, dictionary, allocation, string lookup, and signal churn in the inner loop.

Only the main thread may touch the SceneTree, Nodes, Resources, or RenderingServer objects unless the Godot API explicitly documents thread safety. Worker threads operate on native plain data and publish completed buffers at a synchronization point.

Pin `godot-cpp` and extension metadata to the project's exact Godot version/ABI compatibility. Treat an engine upgrade as an explicit dependency update with a clean native rebuild and integration test; do not rely on an unverified prebuilt binary.

## Keep design outside the binary

Native code owns mechanisms and invariants, not unfrozen balance choices. Pass typed/configured values for activation momentum, entropy curves/distributions, field strength, device multipliers, zero-momentum tolerance, wave sampling, and enemy entropy behavior.

The current project uses `res://config/balance/balance.json` as the version-controlled numeric source of truth. Godot loads it into a typed balance profile used by scenes, Resources, orchestration, and the GDExtension configuration boundary. Development tuning surfaces may edit a working copy, but changes enter a running world only through a validated full simulation reset. Native defaults are defensive fallbacks, never a second normal balance source.

Where a rule is unresolved, define a narrow strategy or mode enum at the seam and mark the selection provisional. Do not compile one interpretation of the accumulator or wave converter into the only possible data model.

Use double-precision accumulation for long-running totals such as wave source momentum and cumulative damage where drift can affect thresholds. Projectiles may use the engine's normal vector precision if verified adequate. Define numeric zero handling explicitly for floating-point simulation while preserving the formal rule “destroy only at zero momentum.”

## Correctness and determinism gates

Add invariant tests around the native seam:

- splitter conserves total momentum as `P/2 + P/2`;
- inactive devices absorb all remaining momentum and receive the same activation amount atomically;
- reconstructed projectiles start at entropy `0`;
- speed and mass increasers modify distinct state dimensions;
- entropy changes uncertainty outputs but never damage directly;
- nonzero-momentum projectiles survive age, entropy, screen exit, and interaction count in formal simulation;
- target reached and wave finished remain separate transitions;
- seeded runs reproduce entropy deviations and interaction ordering.

Keep portable pure-C++ math/data tests outside Godot where practical, plus Godot integration tests for binding, scene synchronization, and Resources.

## Profiling gate

Use a representative stress scene and capture the Godot profiler plus native timing. Cover long-lived loops, dense field overlap, repeated splitting, many devices, enemies attacking/repositioning the network, fog coverage changes, and entropy-heavy interactions.

Set the target frame rate and hardware in project performance data. At 60 FPS the total frame is 16.67 ms, but subsystem budgets must be derived from the target profile rather than treated as design constants. Migrate a conditional system to C++ when its sustained/p95 cost or allocation/boundary churn materially consumes the agreed frame budget under representative load. Optimize algorithms and batching before language migration.

Record benchmark seed, configuration, entity counts, build type, engine/native revision, hardware, and p50/p95/max timings so later regressions are comparable.

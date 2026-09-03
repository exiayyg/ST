# UX, feedback, levels, and content contract

## World-first communication

The battlefield is the main interface. Prefer world-space state and motion that reveal causes over duplicated numeric telemetry.

- Inactive devices are visibly gray/inert and show their own activation progress bar.
- All devices show health in both inactive and active states. Low health becomes conspicuously red or flashes red.
- Destroyed devices stop functioning and stop lighting the map immediately.
- Increasing projectile entropy shifts color toward red, softens/blurs the outline, and adds glitchy/irregular trail noise.
- Enemy entropy needs behavior and visual/animation feedback clear enough to distinguish ordinary behavior from uncertainty.
- Pair relationships such as diode endpoints need world-space linkage.

Do not add a per-projectile HUD or inspection panel for mass, speed, momentum, entropy, prediction error, or similar telemetry. The player reads a path/loop as a system, not thousands of individual particles.

## Fixed combat HUD

Keep only globally important information that changes the next decision and cannot be read accurately from the world:

- current wave;
- remaining time;
- live momentum utilization;
- this wave's target utilization.

Give live utilization very high visual priority (the established suggestion is the upper-left or an equivalent location). Crossing the target threshold needs clear animation and color confirmation.

Do not add meaningless visibility percentages, a global device-energy meter, conventional currency/resource counters, or scientific-instrument clutter. Fog and per-device charge already communicate those states.

## Device selection and manipulation

- There is no persistent bottom/side device toolbar.
- Long-press left mouse on an allowed lit map position to open a radial device-selection wheel near that spatial origin.
- Edge and corner placement must not clip the wheel. Preserve spatial pointing while adapting by center offset, partial fan layout, or another suitable responsive treatment.
- Exact hold thresholds and animation timing are not frozen.
- Movement and rotation remain available during combat without arbitrary use limits. The interaction should enable meaningful replanning without turning the game into constant high-APM micromanagement.

## Directional warnings

- Position each warning arrow in the direction from which enemies will arrive.
- Encode quantity/pressure in arrow color.
- On click, show precise enemy type names and the count of each type for that direction.
- Do not default to exact future paths or unrelated omniscient data.

## Levels and enemy teaching

Teach enemy and device behavior by staging battles where the player sees what breaks, what changes a path, and which construction answers the situation. Later, a precise enemy name in the warning panel should recall that learned behavior.

Levels may emphasize one device, enemy, or map rule, but all device types remain generally selectable from the beginning of a run unless canon is explicitly changed. Do not infer a permanent purchase/unlock tree.

Enemy content must possess behavior that interacts with the network. New entropy responses should perturb behavior outputs specific to that enemy while preserving the “uncertainty only” rule.

## Boss coverage

Treat the boss roster as a test matrix across build qualities rather than a sequence of larger health bars:

- burst capacity from stored/reconstructed momentum;
- long-duration stable operation and repeated utilization;
- resistance to disruption;
- spatial coverage and redistribution.

Do not canonize specific bosses, attacks, or numbers until design approves them.

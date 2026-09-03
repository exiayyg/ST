#include "core/momentum_world.hpp"

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <vector>

using namespace singular_tower;

namespace {

constexpr double kPi = 3.14159265358979323846;

void require(bool condition, const char *message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

bool near(double left, double right, double tolerance = 1e-7) {
    return std::abs(left - right) <= tolerance;
}

SimulationConfig deterministic_config() {
    SimulationConfig config;
    config.initial_projectile_momentum = 10.0;
    config.initial_projectile_mass = 1.0;
    config.initial_projectile_speed = 10.0;
    config.projectile_radius = 0.1;
    config.wave_point_radius = 0.1;
    config.entropy_per_second = 0.0;
    config.entropy_per_interaction = 0.0;
    config.max_angle_deviation_radians = 0.0;
    config.max_speed_deviation_ratio = 0.0;
    config.spatial_cell_size = 4.0;
    config.random_seed = 42;
    return config;
}

DeviceSpec basic_spec(DeviceKind kind, Vec2 position = {5.0, 0.0}) {
    DeviceSpec spec;
    spec.kind = kind;
    spec.position = position;
    spec.secondary_position = {20.0, 0.0};
    spec.activation_radius = 0.5;
    spec.activation_required = 25.0;
    spec.half_length = 2.0;
    spec.splitter_half_separation = 1.0;
    spec.field_radius = 5.0;
    spec.wave_point_count = 4;
    spec.wave_fan_radians = 0.0;
    spec.wave_speed = 10.0;
    spec.reconstruction_mass = 1.0;
    spec.reconstruction_speed = 10.0;
    return spec;
}

std::uint64_t activate_device(MomentumWorld &world, const DeviceSpec &spec) {
    const std::uint64_t device_id = world.add_device(spec);
    for (int index = 0; index < 3; ++index) {
        world.emit_projectile(spec.position - Vec2{5.0, 0.0}, {10.0, 0.0}, 1.0, false);
        world.step(1.0);
    }
    for (const auto &device : world.device_snapshot()) {
        if (device.id == device_id) {
            require(device.active, "device should activate after multiple ordinary projectiles");
            require(near(device.activation_progress, spec.activation_required),
                    "activation overflow should be discarded at the threshold");
            return device_id;
        }
    }
    throw std::runtime_error("activated device missing from snapshot");
}

bool has_event(const std::vector<SimulationEvent> &events, EventKind kind) {
    for (const auto &event : events) {
        if (event.kind == kind) {
            return true;
        }
    }
    return false;
}

void test_nonzero_projectiles_are_not_age_or_bounds_deleted() {
    MomentumWorld world(deterministic_config());
    world.emit_projectile({0.0, 0.0}, {1.0, 0.0}, 1.0);
    world.step(100000.0);
    require(world.projectile_count() == 1, "nonzero projectile must survive age and distance");
    require(world.projectile_snapshot().front().position.x > 99999.0,
            "projectile should keep integrating offscreen");
}

void test_activation_absorbs_all_momentum_and_rejects_single_shot_threshold() {
    MomentumWorld world(deterministic_config());
    activate_device(world, basic_spec(DeviceKind::BouncePlate));
    require(world.projectile_count() == 0, "activation projectiles should retire at zero momentum");

    DeviceSpec invalid = basic_spec(DeviceKind::BouncePlate, {15.0, 0.0});
    invalid.activation_required = 10.0;
    bool rejected = false;
    try {
        world.add_device(invalid);
    } catch (const std::invalid_argument &) {
        rejected = true;
    }
    require(rejected, "one initial projectile must never satisfy a device activation threshold");
}

void test_bounce_plate_reflects_geometrically() {
    MomentumWorld world(deterministic_config());
    DeviceSpec spec = basic_spec(DeviceKind::BouncePlate);
    spec.angle_radians = kPi * 0.5;
    activate_device(world, spec);
    world.emit_projectile({0.0, 0.0}, {10.0, 0.0}, 1.0, false);
    world.step(1.0);
    const auto projectile = world.projectile_snapshot().front();
    require(projectile.velocity.x < 0.0, "vertical bounce plate should reflect horizontal velocity");
    require(near(projectile.mass, 1.0), "reflection must preserve mass");
}

void test_speed_and_mass_increasers_change_distinct_dimensions() {
    MomentumWorld speed_world(deterministic_config());
    DeviceSpec speed = basic_spec(DeviceKind::SpeedIncreaser);
    speed.speed_multiplier = 2.0;
    activate_device(speed_world, speed);
    speed_world.emit_projectile({0.0, 0.0}, {10.0, 0.0}, 2.0, false);
    speed_world.step(1.0);
    const auto speed_output = speed_world.projectile_snapshot().front();
    require(near(speed_output.velocity.length(), 20.0), "speed increaser should multiply speed");
    require(near(speed_output.mass, 2.0), "speed increaser must leave mass unchanged");

    MomentumWorld mass_world(deterministic_config());
    DeviceSpec mass = basic_spec(DeviceKind::MassIncreaser);
    mass.mass_multiplier = 2.0;
    activate_device(mass_world, mass);
    mass_world.emit_projectile({0.0, 0.0}, {10.0, 0.0}, 2.0, false);
    mass_world.step(1.0);
    const auto mass_output = mass_world.projectile_snapshot().front();
    require(near(mass_output.velocity.length(), 10.0), "mass increaser must leave speed unchanged");
    require(near(mass_output.mass, 4.0), "mass increaser should multiply mass");
}

void test_splitter_conserves_momentum_into_parallel_outputs() {
    MomentumWorld world(deterministic_config());
    DeviceSpec splitter = basic_spec(DeviceKind::Splitter);
    splitter.angle_radians = 0.0;
    activate_device(world, splitter);
    world.emit_projectile({0.0, 0.0}, {10.0, 0.0}, 2.0, false);
    world.step(1.0);
    const auto outputs = world.projectile_snapshot();
    require(outputs.size() == 2, "splitter should replace one projectile with two");
    const double first_momentum = outputs[0].mass * outputs[0].velocity.length();
    const double second_momentum = outputs[1].mass * outputs[1].velocity.length();
    require(near(first_momentum, 10.0) && near(second_momentum, 10.0),
            "each splitter output should carry P/2");
    require(near(outputs[0].velocity.x, outputs[1].velocity.x) &&
                    near(outputs[0].velocity.y, outputs[1].velocity.y),
            "splitter outputs should be parallel and share one direction");
    require(outputs[0].position.y * outputs[1].position.y < 0.0,
            "splitter outputs should start from opposite endpoints");
}

void test_diode_maps_to_independent_exit_anchor_and_angle() {
    MomentumWorld world(deterministic_config());
    DeviceSpec diode = basic_spec(DeviceKind::Diode);
    diode.secondary_position = {20.0, 3.0};
    diode.secondary_angle_radians = kPi * 0.5;
    const auto diode_id = activate_device(world, diode);
    require(world.set_device_anchor_transform(diode_id, 1, {24.0, 4.0}, kPi * 0.5),
            "diode exit anchor should be independently movable");
    world.emit_projectile({0.0, 0.0}, {10.0, 0.0}, 1.0, false, 0.2, 1.0);
    world.step(1.0);
    const auto output = world.projectile_snapshot().front();
    require(near(output.position.x, 24.0), "diode output should use the moved exit position");
    require(output.position.y > 4.0 && output.velocity.y > 0.0,
            "diode output should travel along the exit angle");
    require(near(output.mass, 1.0) && near(output.charge, 1.0),
            "diode should preserve mass and charge");
}

void test_electric_and_magnetic_fields_apply_continuously_to_qualified_projectiles() {
    MomentumWorld electric_world(deterministic_config());
    DeviceSpec electric = basic_spec(DeviceKind::ElectricField);
    electric.electric_acceleration = 2.0;
    activate_device(electric_world, electric);
    electric_world.emit_projectile({3.0, 0.0}, {1.0, 0.0}, 1.0, false);
    electric_world.step(0.5);
    const auto charged = electric_world.projectile_snapshot().front();
    require(near(charged.charge, 1.0), "electric field should set positive charge");
    require(charged.velocity.x > 1.9, "electric field should accelerate continuously while inside");
    require(has_event(electric_world.consume_events(), EventKind::ProjectileCharged),
            "electric entry should emit a charged event");

    MomentumWorld neutral_magnetic_world(deterministic_config());
    DeviceSpec neutral_magnetic = basic_spec(DeviceKind::MagneticField);
    neutral_magnetic.magnetic_angular_speed = 1.0;
    activate_device(neutral_magnetic_world, neutral_magnetic);
    neutral_magnetic_world.consume_events();
    neutral_magnetic_world.emit_projectile({3.0, 0.0}, {10.0, 0.0}, 1.0, false, 0.0, 0.0);
    neutral_magnetic_world.step(0.5);
    const auto neutral = neutral_magnetic_world.projectile_snapshot().front();
    require(near(neutral.velocity.x, 10.0) && near(neutral.velocity.y, 0.0),
            "magnetic field must not affect neutral projectiles");
    const auto neutral_events = neutral_magnetic_world.consume_events();
    require(!has_event(neutral_events, EventKind::MagneticFieldEntered) &&
                    !has_event(neutral_events, EventKind::Shockwave),
            "neutral projectiles must not emit magnetic entry or shockwave events");

    MomentumWorld magnetic_world(deterministic_config());
    DeviceSpec magnetic = basic_spec(DeviceKind::MagneticField);
    magnetic.magnetic_angular_speed = 1.0;
    activate_device(magnetic_world, magnetic);
    magnetic_world.consume_events();
    magnetic_world.emit_projectile({3.0, 0.0}, {10.0, 0.0}, 1.0, false, 0.0, 1.0);
    magnetic_world.step(0.5);
    const auto curved = magnetic_world.projectile_snapshot().front();
    require(curved.velocity.y > 0.0 && near(curved.velocity.length(), 10.0),
            "magnetic field should curve charged velocity without changing speed");
    const auto events = magnetic_world.consume_events();
    require(has_event(events, EventKind::MagneticFieldEntered) && has_event(events, EventKind::Shockwave),
            "charged magnetic entry should emit entry and shockwave events");
}

void test_wave_points_conserve_momentum_persist_and_reconstruct_automatically() {
    MomentumWorld world(deterministic_config());
    DeviceSpec transmitter = basic_spec(DeviceKind::WaveConverter, {5.0, 0.0});
    transmitter.wave_point_count = 4;
    transmitter.wave_fan_radians = 0.0;
    transmitter.wave_speed = 10.0;
    activate_device(world, transmitter);
    DeviceSpec receiver = transmitter;
    receiver.position = {12.0, 0.0};
    receiver.angle_radians = kPi * 0.5;
    receiver.reconstruction_mass = 0.5;
    receiver.reconstruction_speed = 20.0;
    activate_device(world, receiver);
    world.consume_events();

    world.emit_projectile({0.0, 0.0}, {10.0, 0.0}, 1.0, false, 0.8, 1.0);
    world.step(1.0);
    require(world.wave_point_count() == 4, "converter should emit configured discrete wave points");
    double wave_momentum = 0.0;
    for (const auto &point : world.wave_point_snapshot()) {
        wave_momentum += point.momentum;
    }
    require(near(wave_momentum, 10.0), "wave points must carry equal shares totaling source momentum");

    world.step(0.6);
    require(world.wave_point_count() == 0, "receiver should retire absorbed wave points at zero momentum");
    require(world.projectile_count() == 1, "receiver should automatically reconstruct at one tower threshold");
    const auto reconstructed = world.projectile_snapshot().front();
    require(near(reconstructed.mass, 0.5) && near(reconstructed.velocity.length(), 20.0),
            "wave reconstruction should use configured mass and speed whose product is its threshold");
    require(near(reconstructed.entropy, 0.0) && near(reconstructed.charge, 0.0),
            "wave reconstruction should reset entropy and charge");

    MomentumWorld persistence_world(deterministic_config());
    activate_device(persistence_world, transmitter);
    persistence_world.emit_projectile({0.0, 0.0}, {10.0, 0.0}, 1.0, false);
    persistence_world.step(1.0);
    persistence_world.step(100000.0);
    require(persistence_world.wave_point_count() == 4,
            "nonzero wave points must survive age, range, and map bounds");
}

void test_accumulator_stores_mass_and_momentum_then_releases_one_clean_projectile() {
    MomentumWorld world(deterministic_config());
    DeviceSpec accumulator = basic_spec(DeviceKind::Accumulator);
    accumulator.angle_radians = kPi * 0.5;
    const auto accumulator_id = activate_device(world, accumulator);
    world.emit_projectile({0.0, 0.0}, {5.0, 0.0}, 2.0, false, 0.7, 1.0);
    world.step(1.0);
    const auto stored = world.device_snapshot().front();
    require(near(stored.stored_mass, 2.0) && near(stored.stored_momentum, 10.0),
            "accumulator should preserve full mass and scalar momentum");
    require(world.release_accumulator(accumulator_id), "active nonempty accumulator should release manually");
    require(world.projectile_count() == 1, "accumulator release should create exactly one projectile");
    const auto output = world.projectile_snapshot().front();
    require(near(output.mass, 2.0) && near(output.velocity.length(), 5.0),
            "released speed should equal stored momentum divided by stored mass");
    require(output.velocity.y > 0.0 && near(output.entropy, 0.0) && near(output.charge, 0.0),
            "accumulator output should follow facing and reset entropy and charge");
}

void test_removing_device_prevents_future_interaction() {
    MomentumWorld world(deterministic_config());
    DeviceSpec speed = basic_spec(DeviceKind::SpeedIncreaser);
    speed.speed_multiplier = 2.0;
    const auto id = activate_device(world, speed);
    require(world.remove_device(id), "existing device should be removable");
    world.emit_projectile({0.0, 0.0}, {10.0, 0.0}, 1.0, false);
    world.step(1.0);
    require(near(world.projectile_snapshot().front().velocity.length(), 10.0),
            "removed device must no longer interact");
}

void test_utilization_can_exceed_one_hundred_percent() {
    MomentumWorld world(deterministic_config());
    DeviceSpec speed = basic_spec(DeviceKind::SpeedIncreaser);
    speed.speed_multiplier = 2.0;
    activate_device(world, speed);
    DiagnosticTargetSpec target;
    target.position = {15.0, 0.0};
    target.radius = 0.5;
    world.add_diagnostic_target(target);
    world.reset_wave_stats();
    world.emit_projectile({0.0, 0.0}, {10.0, 0.0}, 1.0, true);
    world.step(1.0);
    require(near(world.wave_stats().tower_source_momentum, 10.0),
            "utilization denominator should count tower source momentum only");
    require(near(world.wave_stats().damage_dealt, 20.0) && near(world.wave_stats().utilization(), 2.0),
            "amplified momentum should allow utilization above one hundred percent");
}

void test_entropy_threshold_curve_has_a_deterministic_dead_zone() {
    SimulationConfig config = deterministic_config();
    config.entropy_start = 50.0;
    config.entropy_full_effect = 100.0;
    config.entropy_curve = {{0.0, 0.0}, {0.5, 0.2}, {1.0, 1.0}};
    MomentumWorld world(config);
    require(near(world.uncertainty_weight(0.0), 0.0), "zero entropy must be deterministic");
    require(near(world.uncertainty_weight(49.999), 0.0), "entropy below threshold must be deterministic");
    require(near(world.uncertainty_weight(50.0), 0.0), "entropy at threshold must be deterministic");
    const double low = world.uncertainty_weight(60.0);
    const double medium = world.uncertainty_weight(75.0);
    const double high = world.uncertainty_weight(90.0);
    require(low > 0.0 && low < medium && medium < high,
            "uncertainty amplitude must increase monotonically above threshold");
    require(near(world.uncertainty_weight(100.0), 1.0) && near(world.uncertainty_weight(1000.0), 1.0),
            "uncertainty must saturate at configured full effect");
}

void test_entropy_specific_diode_and_splitter_limits_preserve_invariants() {
    SimulationConfig config = deterministic_config();
    config.entropy_start = 50.0;
    config.entropy_full_effect = 100.0;
    config.max_diode_exit_offset = 8.0;
    config.max_diode_angle_deviation_radians = 0.1;
    config.max_split_direction_deviation_radians = 0.2;
    config.max_split_share_deviation_ratio = 0.1;

    MomentumWorld split_world(config);
    DeviceSpec splitter = basic_spec(DeviceKind::Splitter);
    activate_device(split_world, splitter);
    split_world.emit_projectile({0.0, 0.0}, {10.0, 0.0}, 2.0, false, 100.0);
    split_world.step(1.0);
    const auto outputs = split_world.projectile_snapshot();
    require(outputs.size() == 2, "high-entropy splitter should still create exactly two outputs");
    const double combined_momentum = outputs[0].mass * outputs[0].velocity.length() +
            outputs[1].mass * outputs[1].velocity.length();
    require(near(combined_momentum, 20.0), "split share uncertainty must conserve total momentum");
    require(near(outputs[0].velocity.x, outputs[1].velocity.x) &&
                    near(outputs[0].velocity.y, outputs[1].velocity.y),
            "entropy-affected splitter outputs must remain parallel");
    require(std::abs(std::atan2(outputs[0].velocity.y, outputs[0].velocity.x)) <= 0.2 + 1e-7,
            "split direction uncertainty must stay within its dedicated maximum");
    require(outputs[0].mass >= 0.8 && outputs[0].mass <= 1.2 &&
                    outputs[1].mass >= 0.8 && outputs[1].mass <= 1.2,
            "split share uncertainty must stay within its configured ratio");

    MomentumWorld diode_world(config);
    DeviceSpec diode = basic_spec(DeviceKind::Diode);
    diode.secondary_position = {20.0, 3.0};
    diode.secondary_angle_radians = kPi * 0.5;
    activate_device(diode_world, diode);
    diode_world.consume_events();
    diode_world.emit_projectile({0.0, 0.0}, {10.0, 0.0}, 1.0, false, 100.0);
    diode_world.step(1.0);
    const auto diode_output = diode_world.projectile_snapshot().front();
    const double diode_angle = std::atan2(diode_output.velocity.y, diode_output.velocity.x);
    Vec2 teleport_position;
    bool found_teleport = false;
    for (const auto &event : diode_world.consume_events()) {
        if (event.kind == EventKind::ProjectileTeleported) {
            teleport_position = event.position;
            found_teleport = true;
        }
    }
    require(found_teleport && std::abs(teleport_position.x - diode.secondary_position.x) <= 8.0 + 1e-7,
            "diode exit position uncertainty must stay within its dedicated maximum");
    require(std::abs(diode_angle - kPi * 0.5) <= 0.1 + 1e-7,
            "diode exit angle uncertainty must stay within its dedicated maximum");
}

void test_enemy_proxy_transfers_momentum_clamps_damage_and_reports_entropy() {
    MomentumWorld world(deterministic_config());
    EnemyProxySpec enemy;
    enemy.id = 77;
    enemy.position = {5.0, 0.0};
    enemy.radius = 0.5;
    enemy.remaining_hp = 3.0;
    enemy.momentum_absorption = 0.5;
    enemy.damage_per_momentum = 1.0;
    enemy.entropy_transfer_ratio = 0.5;
    require(world.sync_enemy_proxies({enemy}), "valid enemy proxy batch should be accepted");
    world.emit_projectile({0.0, 0.0}, {10.0, 0.0}, 1.0, true, 80.0);
    world.step(1.0);
    require(world.projectile_count() == 1, "partially absorbed projectile should retain nonzero momentum");
    require(near(world.projectile_snapshot().front().velocity.length(), 5.0),
            "enemy should remove only its configured momentum fraction");
    require(near(world.wave_stats().damage_dealt, 3.0), "overkill must not count toward utilization");
    const auto events = world.consume_events();
    bool found_hit = false;
    bool found_depleted = false;
    for (const auto &event : events) {
        if (event.kind == EventKind::EnemyHit) {
            found_hit = true;
            require(event.device_id == 77 && near(event.value, 3.0) && near(event.value2, 5.0),
                    "enemy hit must report actual damage and transferred momentum");
            require(near(event.value3, 80.0) && near(event.value4, 40.0),
                    "enemy hit must report source and transferred entropy without changing damage");
        }
        found_depleted = found_depleted || event.kind == EventKind::EnemyDepleted;
    }
    require(found_hit && found_depleted, "depleting hit should emit both hit and depleted events");

    EnemyProxySpec invalid = enemy;
    invalid.id = 0;
    require(!world.sync_enemy_proxies({invalid}), "invalid enemy proxy batch should be rejected atomically");
    require(world.enemy_proxy_count() == 1, "failed proxy sync must preserve prior proxy state");
}

} // namespace

int main() {
    try {
        test_nonzero_projectiles_are_not_age_or_bounds_deleted();
        test_activation_absorbs_all_momentum_and_rejects_single_shot_threshold();
        test_bounce_plate_reflects_geometrically();
        test_speed_and_mass_increasers_change_distinct_dimensions();
        test_splitter_conserves_momentum_into_parallel_outputs();
        test_diode_maps_to_independent_exit_anchor_and_angle();
        test_electric_and_magnetic_fields_apply_continuously_to_qualified_projectiles();
        test_wave_points_conserve_momentum_persist_and_reconstruct_automatically();
        test_accumulator_stores_mass_and_momentum_then_releases_one_clean_projectile();
        test_removing_device_prevents_future_interaction();
        test_utilization_can_exceed_one_hundred_percent();
        test_entropy_threshold_curve_has_a_deterministic_dead_zone();
        test_entropy_specific_diode_and_splitter_limits_preserve_invariants();
        test_enemy_proxy_transfers_momentum_clamps_damage_and_reports_entropy();
    } catch (const std::exception &error) {
        std::cerr << "FAILED: " << error.what() << '\n';
        return EXIT_FAILURE;
    }
    std::cout << "All momentum core tests passed.\n";
    return EXIT_SUCCESS;
}

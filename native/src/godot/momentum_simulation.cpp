#include "godot/momentum_simulation.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <cmath>
#include <exception>
#include <stdexcept>

namespace godot {
namespace {

using singular_tower::DeviceKind;
using singular_tower::DeviceSpec;
using singular_tower::DiagnosticTargetSpec;
using singular_tower::EnemyProxySpec;
using singular_tower::SimulationConfig;
using singular_tower::Vec2;

double number_or(const Dictionary &dictionary, const char *key, double fallback) {
    return dictionary.has(key) ? static_cast<double>(dictionary[key]) : fallback;
}

std::int64_t integer_or(const Dictionary &dictionary, const char *key, std::int64_t fallback) {
    return dictionary.has(key) ? static_cast<std::int64_t>(dictionary[key]) : fallback;
}

bool bool_or(const Dictionary &dictionary, const char *key, bool fallback) {
    return dictionary.has(key) ? static_cast<bool>(dictionary[key]) : fallback;
}

Vector2 vector_or(const Dictionary &dictionary, const char *key, Vector2 fallback = {}) {
    return dictionary.has(key) ? static_cast<Vector2>(dictionary[key]) : fallback;
}

Color color_or(const Dictionary &dictionary, const char *key, Color fallback) {
    return dictionary.has(key) ? static_cast<Color>(dictionary[key]) : fallback;
}

bool valid_color(const Color &color) {
    return std::isfinite(color.r) && std::isfinite(color.g) && std::isfinite(color.b) &&
            std::isfinite(color.a) && color.r >= 0.0f && color.r <= 1.0f &&
            color.g >= 0.0f && color.g <= 1.0f && color.b >= 0.0f && color.b <= 1.0f &&
            color.a >= 0.0f && color.a <= 1.0f;
}

Vec2 to_core(Vector2 value) {
    return {value.x, value.y};
}

Vector2 to_godot(Vec2 value) {
    return {static_cast<real_t>(value.x), static_cast<real_t>(value.y)};
}

DeviceKind parse_device_kind(const String &value) {
    if (value == "bounce_plate") return DeviceKind::BouncePlate;
    if (value == "speed_increaser") return DeviceKind::SpeedIncreaser;
    if (value == "mass_increaser") return DeviceKind::MassIncreaser;
    if (value == "splitter") return DeviceKind::Splitter;
    if (value == "diode") return DeviceKind::Diode;
    if (value == "electric_field") return DeviceKind::ElectricField;
    if (value == "magnetic_field") return DeviceKind::MagneticField;
    if (value == "wave_converter") return DeviceKind::WaveConverter;
    if (value == "accumulator") return DeviceKind::Accumulator;
    throw std::invalid_argument("unknown device type");
}

void report_exception(const char *operation, const std::exception &exception) {
    UtilityFunctions::push_error(String(operation) + ": " + exception.what());
}

} // namespace

MomentumSimulation::MomentumSimulation() = default;

bool MomentumSimulation::configure(const Dictionary &config) {
    SimulationConfig native_config;
    native_config.initial_projectile_momentum =
            number_or(config, "initial_projectile_momentum", native_config.initial_projectile_momentum);
    native_config.initial_projectile_mass =
            number_or(config, "initial_projectile_mass", native_config.initial_projectile_mass);
    native_config.initial_projectile_speed =
            number_or(config, "initial_projectile_speed", native_config.initial_projectile_speed);
    native_config.momentum_zero_epsilon =
            number_or(config, "momentum_zero_epsilon", native_config.momentum_zero_epsilon);
    native_config.projectile_radius = number_or(config, "projectile_radius", native_config.projectile_radius);
    native_config.wave_point_radius = number_or(config, "wave_point_radius", native_config.wave_point_radius);
    native_config.entropy_per_second =
            number_or(config, "entropy_per_second", native_config.entropy_per_second);
    native_config.entropy_per_interaction =
            number_or(config, "entropy_per_interaction", native_config.entropy_per_interaction);
    native_config.entropy_interaction_acceleration = number_or(
            config, "entropy_interaction_acceleration", native_config.entropy_interaction_acceleration);
    native_config.entropy_start = number_or(config, "entropy_start", native_config.entropy_start);
    native_config.entropy_full_effect =
            number_or(config, "entropy_full_effect", native_config.entropy_full_effect);
    if (config.has("entropy_curve")) {
        const Array curve = config["entropy_curve"];
        native_config.entropy_curve.clear();
        for (std::int64_t index = 0; index < curve.size(); ++index) {
            if (curve[index].get_type() != Variant::DICTIONARY) {
                UtilityFunctions::push_error("MomentumSimulation.configure: entropy curve point must be Dictionary");
                return false;
            }
            const Dictionary point = curve[index];
            native_config.entropy_curve.push_back({number_or(point, "x", 0.0), number_or(point, "y", 0.0)});
        }
    }
    native_config.max_angle_deviation_radians =
            number_or(config, "max_angle_deviation_radians", native_config.max_angle_deviation_radians);
    native_config.max_speed_deviation_ratio =
            number_or(config, "max_speed_deviation_ratio", native_config.max_speed_deviation_ratio);
    native_config.max_mass_deviation_ratio =
            number_or(config, "max_mass_deviation_ratio", native_config.max_mass_deviation_ratio);
    native_config.max_diode_exit_offset =
            number_or(config, "max_diode_exit_offset", native_config.max_diode_exit_offset);
    native_config.max_diode_angle_deviation_radians = number_or(config,
            "max_diode_angle_deviation_radians", native_config.max_diode_angle_deviation_radians);
    native_config.max_split_direction_deviation_radians = number_or(config,
            "max_split_direction_deviation_radians", native_config.max_split_direction_deviation_radians);
    native_config.max_split_share_deviation_ratio = number_or(config,
            "max_split_share_deviation_ratio", native_config.max_split_share_deviation_ratio);
    native_config.spatial_cell_size =
            number_or(config, "spatial_cell_size", native_config.spatial_cell_size);
    native_config.enemy_spatial_cell_size =
            number_or(config, "enemy_spatial_cell_size", native_config.enemy_spatial_cell_size);
    native_config.entity_spawn_clearance =
            number_or(config, "entity_spawn_clearance", native_config.entity_spawn_clearance);
    native_config.max_interactions_per_step = static_cast<std::uint32_t>(std::max<std::int64_t>(1,
            integer_or(config, "max_interactions_per_step", native_config.max_interactions_per_step)));
    native_config.random_seed = static_cast<std::uint64_t>(
            std::max<std::int64_t>(0, integer_or(config, "random_seed", native_config.random_seed)));

    const double new_fixed_step = number_or(config, "fixed_step_seconds", fixed_step_seconds_);
    const std::int64_t new_max_substeps = integer_or(config, "max_substeps", max_substeps_);
    const double new_visual_start = number_or(config, "entropy_visual_start", entropy_visual_start_);
    const double new_visual_full = number_or(config, "entropy_visual_full", entropy_visual_full_);
    const double new_projectile_diameter =
            number_or(config, "projectile_base_diameter", projectile_base_diameter_);
    const double new_projectile_entropy_diameter = number_or(
            config, "projectile_entropy_extra_diameter", projectile_entropy_extra_diameter_);
    const double new_wave_diameter = number_or(config, "wave_point_diameter", wave_point_diameter_);
    const Color new_projectile_low_color = color_or(config, "projectile_low_entropy_color",
            Color(projectile_low_entropy_color_.r, projectile_low_entropy_color_.g,
                    projectile_low_entropy_color_.b, projectile_low_entropy_color_.a));
    const Color new_projectile_high_color = color_or(config, "projectile_high_entropy_color",
            Color(projectile_high_entropy_color_.r, projectile_high_entropy_color_.g,
                    projectile_high_entropy_color_.b, projectile_high_entropy_color_.a));
    const Color new_projectile_charged_color = color_or(config, "projectile_charged_color",
            Color(projectile_charged_color_.r, projectile_charged_color_.g,
                    projectile_charged_color_.b, projectile_charged_color_.a));
    const Color new_wave_color = color_or(config, "wave_point_color",
            Color(wave_point_color_.r, wave_point_color_.g, wave_point_color_.b, wave_point_color_.a));
    const double new_charge_blend = number_or(
            config, "projectile_charge_blend_ratio", projectile_charge_blend_ratio_);
    if (!std::isfinite(new_fixed_step) || new_fixed_step <= 0.0 || new_max_substeps <= 0 ||
            !std::isfinite(new_visual_start) || !std::isfinite(new_visual_full) ||
            new_visual_full <= new_visual_start || !std::isfinite(new_projectile_diameter) ||
            new_projectile_diameter <= 0.0 || !std::isfinite(new_projectile_entropy_diameter) ||
            new_projectile_entropy_diameter < 0.0 || !std::isfinite(new_wave_diameter) || new_wave_diameter <= 0.0 ||
            !valid_color(new_projectile_low_color) || !valid_color(new_projectile_high_color) ||
            !valid_color(new_projectile_charged_color) || !valid_color(new_wave_color) ||
            !std::isfinite(new_charge_blend) || new_charge_blend < 0.0 || new_charge_blend > 1.0) {
        UtilityFunctions::push_error("MomentumSimulation.configure: invalid fixed step or max_substeps");
        return false;
    }

    try {
        world_.configure(native_config);
        fixed_step_seconds_ = new_fixed_step;
        max_substeps_ = static_cast<std::int32_t>(std::min<std::int64_t>(new_max_substeps, 1024));
        entropy_visual_start_ = new_visual_start;
        entropy_visual_full_ = new_visual_full;
        projectile_base_diameter_ = new_projectile_diameter;
        projectile_entropy_extra_diameter_ = new_projectile_entropy_diameter;
        wave_point_diameter_ = new_wave_diameter;
        projectile_low_entropy_color_ = {new_projectile_low_color.r, new_projectile_low_color.g,
                new_projectile_low_color.b, new_projectile_low_color.a};
        projectile_high_entropy_color_ = {new_projectile_high_color.r, new_projectile_high_color.g,
                new_projectile_high_color.b, new_projectile_high_color.a};
        projectile_charged_color_ = {new_projectile_charged_color.r, new_projectile_charged_color.g,
                new_projectile_charged_color.b, new_projectile_charged_color.a};
        wave_point_color_ = {new_wave_color.r, new_wave_color.g, new_wave_color.b, new_wave_color.a};
        projectile_charge_blend_ratio_ = new_charge_blend;
        accumulator_seconds_ = 0.0;
        return true;
    } catch (const std::exception &exception) {
        report_exception("MomentumSimulation.configure", exception);
        return false;
    }
}

void MomentumSimulation::clear() {
    world_.clear();
    accumulator_seconds_ = 0.0;
}

void MomentumSimulation::reset_wave_stats() {
    world_.reset_wave_stats();
}

PackedInt64Array MomentumSimulation::emit_projectiles(const Array &commands) {
    PackedInt64Array ids;
    for (std::int64_t index = 0; index < commands.size(); ++index) {
        if (commands[index].get_type() != Variant::DICTIONARY) {
            UtilityFunctions::push_error("MomentumSimulation.emit_projectiles: command must be a Dictionary");
            continue;
        }
        const Dictionary command = commands[index];
        try {
            ids.append(static_cast<std::int64_t>(world_.emit_projectile(
                    to_core(vector_or(command, "position")), to_core(vector_or(command, "velocity")),
                    number_or(command, "mass", 1.0), bool_or(command, "tower_source", true),
                    number_or(command, "entropy", 0.0), number_or(command, "charge", 0.0))));
        } catch (const std::exception &exception) {
            report_exception("MomentumSimulation.emit_projectiles", exception);
        }
    }
    return ids;
}

std::int64_t MomentumSimulation::add_device(const Dictionary &spec) {
    try {
        DeviceSpec native_spec;
        native_spec.kind = parse_device_kind(static_cast<String>(spec.get("type", "")));
        native_spec.position = to_core(vector_or(spec, "position"));
        native_spec.angle_radians = number_or(spec, "angle_radians", native_spec.angle_radians);
        native_spec.secondary_position = to_core(vector_or(spec, "secondary_position"));
        native_spec.secondary_angle_radians =
                number_or(spec, "secondary_angle_radians", native_spec.secondary_angle_radians);
        native_spec.activation_radius = number_or(spec, "activation_radius", native_spec.activation_radius);
        native_spec.activation_required = number_or(spec, "activation_required", native_spec.activation_required);
        native_spec.half_length = number_or(spec, "half_length", native_spec.half_length);
        native_spec.speed_multiplier = number_or(spec, "speed_multiplier", native_spec.speed_multiplier);
        native_spec.mass_multiplier = number_or(spec, "mass_multiplier", native_spec.mass_multiplier);
        native_spec.splitter_half_separation =
                number_or(spec, "splitter_half_separation", native_spec.splitter_half_separation);
        native_spec.field_radius = number_or(spec, "field_radius", native_spec.field_radius);
        native_spec.electric_acceleration =
                number_or(spec, "electric_acceleration", native_spec.electric_acceleration);
        native_spec.magnetic_angular_speed =
                number_or(spec, "magnetic_angular_speed", native_spec.magnetic_angular_speed);
        native_spec.shockwave_radius = number_or(spec, "shockwave_radius", native_spec.shockwave_radius);
        native_spec.wave_point_count = static_cast<std::uint32_t>(std::max<std::int64_t>(1,
                integer_or(spec, "wave_point_count", native_spec.wave_point_count)));
        native_spec.wave_fan_radians = number_or(spec, "wave_fan_radians", native_spec.wave_fan_radians);
        native_spec.wave_speed = number_or(spec, "wave_speed", native_spec.wave_speed);
        native_spec.reconstruction_mass =
                number_or(spec, "reconstruction_mass", native_spec.reconstruction_mass);
        native_spec.reconstruction_speed =
                number_or(spec, "reconstruction_speed", native_spec.reconstruction_speed);
        native_spec.entropy_sensitivity = number_or(spec, "entropy_sensitivity", native_spec.entropy_sensitivity);
        return static_cast<std::int64_t>(world_.add_device(native_spec));
    } catch (const std::exception &exception) {
        report_exception("MomentumSimulation.add_device", exception);
        return 0;
    }
}

bool MomentumSimulation::remove_device(std::int64_t device_id) {
    return device_id > 0 && world_.remove_device(static_cast<std::uint64_t>(device_id));
}

bool MomentumSimulation::set_device_transform(
        std::int64_t device_id, Vector2 position, double angle_radians) {
    return device_id > 0 && world_.set_device_transform(
            static_cast<std::uint64_t>(device_id), to_core(position), angle_radians);
}

bool MomentumSimulation::set_device_anchor_transform(
        std::int64_t device_id, std::int32_t anchor_index, Vector2 position, double angle_radians) {
    return device_id > 0 && anchor_index >= 0 && world_.set_device_anchor_transform(
            static_cast<std::uint64_t>(device_id), static_cast<std::uint32_t>(anchor_index),
            to_core(position), angle_radians);
}

bool MomentumSimulation::release_accumulator(std::int64_t device_id) {
    return device_id > 0 && world_.release_accumulator(static_cast<std::uint64_t>(device_id));
}

std::int64_t MomentumSimulation::add_diagnostic_target(const Dictionary &spec) {
    try {
        DiagnosticTargetSpec native_spec;
        native_spec.position = to_core(vector_or(spec, "position"));
        native_spec.radius = number_or(spec, "radius", native_spec.radius);
        native_spec.damage_per_momentum = number_or(spec, "damage_per_momentum", native_spec.damage_per_momentum);
        native_spec.momentum_absorption_fraction =
                number_or(spec, "momentum_absorption_fraction", native_spec.momentum_absorption_fraction);
        return static_cast<std::int64_t>(world_.add_diagnostic_target(native_spec));
    } catch (const std::exception &exception) {
        report_exception("MomentumSimulation.add_diagnostic_target", exception);
        return 0;
    }
}

bool MomentumSimulation::sync_enemy_proxies(const Dictionary &snapshot) {
    const char *required[] = {"ids", "positions", "radii", "remaining_hp", "momentum_absorption",
            "damage_per_momentum", "entropy_transfer_ratio"};
    for (const char *key : required) {
        if (!snapshot.has(key)) {
            return false;
        }
    }
    if (snapshot["ids"].get_type() != Variant::PACKED_INT64_ARRAY ||
            snapshot["positions"].get_type() != Variant::PACKED_VECTOR2_ARRAY ||
            snapshot["radii"].get_type() != Variant::PACKED_FLOAT32_ARRAY ||
            snapshot["remaining_hp"].get_type() != Variant::PACKED_FLOAT32_ARRAY ||
            snapshot["momentum_absorption"].get_type() != Variant::PACKED_FLOAT32_ARRAY ||
            snapshot["damage_per_momentum"].get_type() != Variant::PACKED_FLOAT32_ARRAY ||
            snapshot["entropy_transfer_ratio"].get_type() != Variant::PACKED_FLOAT32_ARRAY) {
        return false;
    }
    const PackedInt64Array ids = snapshot["ids"];
    const PackedVector2Array positions = snapshot["positions"];
    const PackedFloat32Array radii = snapshot["radii"];
    const PackedFloat32Array hit_points = snapshot["remaining_hp"];
    const PackedFloat32Array absorptions = snapshot["momentum_absorption"];
    const PackedFloat32Array damage_scales = snapshot["damage_per_momentum"];
    const PackedFloat32Array entropy_ratios = snapshot["entropy_transfer_ratio"];
    const std::int64_t size = ids.size();
    if (positions.size() != size || radii.size() != size || hit_points.size() != size ||
            absorptions.size() != size || damage_scales.size() != size || entropy_ratios.size() != size) {
        return false;
    }
    std::vector<EnemyProxySpec> specs;
    specs.reserve(static_cast<std::size_t>(size));
    for (std::int64_t index = 0; index < size; ++index) {
        specs.push_back({static_cast<std::uint64_t>(ids[index]), to_core(positions[index]), radii[index],
                hit_points[index], absorptions[index], damage_scales[index], entropy_ratios[index]});
    }
    return world_.sync_enemy_proxies(specs);
}

void MomentumSimulation::clear_enemy_proxies() {
    world_.clear_enemy_proxies();
}

void MomentumSimulation::step(double frame_delta_seconds) {
    if (!std::isfinite(frame_delta_seconds) || frame_delta_seconds <= 0.0) {
        return;
    }
    accumulator_seconds_ += frame_delta_seconds;
    std::int32_t completed_substeps = 0;
    while (accumulator_seconds_ >= fixed_step_seconds_ && completed_substeps < max_substeps_) {
        world_.step(fixed_step_seconds_);
        accumulator_seconds_ -= fixed_step_seconds_;
        ++completed_substeps;
    }
}

Dictionary MomentumSimulation::get_projectile_snapshot() const {
    PackedInt64Array ids;
    PackedVector2Array positions;
    PackedVector2Array velocities;
    PackedFloat64Array masses;
    PackedFloat64Array charges;
    PackedFloat64Array entropies;
    PackedInt32Array interaction_counts;
    const auto snapshot = world_.projectile_snapshot();
    ids.resize(snapshot.size());
    positions.resize(snapshot.size());
    velocities.resize(snapshot.size());
    masses.resize(snapshot.size());
    charges.resize(snapshot.size());
    entropies.resize(snapshot.size());
    interaction_counts.resize(snapshot.size());
    for (std::size_t index = 0; index < snapshot.size(); ++index) {
        const std::int64_t packed_index = static_cast<std::int64_t>(index);
        ids.set(packed_index, static_cast<std::int64_t>(snapshot[index].id));
        positions.set(packed_index, to_godot(snapshot[index].position));
        velocities.set(packed_index, to_godot(snapshot[index].velocity));
        masses.set(packed_index, snapshot[index].mass);
        charges.set(packed_index, snapshot[index].charge);
        entropies.set(packed_index, snapshot[index].entropy);
        interaction_counts.set(packed_index, static_cast<std::int32_t>(snapshot[index].interaction_count));
    }
    Dictionary result;
    result["ids"] = ids;
    result["positions"] = positions;
    result["velocities"] = velocities;
    result["masses"] = masses;
    result["charges"] = charges;
    result["entropies"] = entropies;
    result["interaction_counts"] = interaction_counts;
    return result;
}

Dictionary MomentumSimulation::get_wave_point_snapshot() const {
    PackedInt64Array ids;
    PackedVector2Array positions;
    PackedVector2Array velocities;
    PackedFloat64Array momenta;
    const auto snapshot = world_.wave_point_snapshot();
    ids.resize(snapshot.size());
    positions.resize(snapshot.size());
    velocities.resize(snapshot.size());
    momenta.resize(snapshot.size());
    for (std::size_t index = 0; index < snapshot.size(); ++index) {
        const std::int64_t packed_index = static_cast<std::int64_t>(index);
        ids.set(packed_index, static_cast<std::int64_t>(snapshot[index].id));
        positions.set(packed_index, to_godot(snapshot[index].position));
        velocities.set(packed_index, to_godot(snapshot[index].velocity));
        momenta.set(packed_index, snapshot[index].momentum);
    }
    Dictionary result;
    result["ids"] = ids;
    result["positions"] = positions;
    result["velocities"] = velocities;
    result["momenta"] = momenta;
    return result;
}

Dictionary MomentumSimulation::get_render_snapshot(Rect2 view_rect, double margin) const {
    const Rect2 visible = view_rect.grow(static_cast<real_t>(std::max(0.0, margin)));
    constexpr std::int64_t multimesh_stride = 12;
    const auto projectiles = world_.projectile_snapshot();
    PackedVector2Array projectile_positions;
    PackedFloat64Array projectile_entropies;
    PackedFloat64Array projectile_charges;
    PackedFloat32Array projectile_multimesh_buffer;
    projectile_positions.resize(static_cast<std::int64_t>(projectiles.size()));
    projectile_entropies.resize(static_cast<std::int64_t>(projectiles.size()));
    projectile_charges.resize(static_cast<std::int64_t>(projectiles.size()));
    projectile_multimesh_buffer.resize(static_cast<std::int64_t>(projectiles.size()) * multimesh_stride);
    Vector2 *projectile_position_write = projectile_positions.ptrw();
    double *projectile_entropy_write = projectile_entropies.ptrw();
    double *projectile_charge_write = projectile_charges.ptrw();
    float *projectile_buffer_write = projectile_multimesh_buffer.ptrw();
    std::int64_t projectile_count = 0;
    for (const auto &projectile : projectiles) {
        const Vector2 position = to_godot(projectile.position);
        if (visible.has_point(position)) {
            projectile_position_write[projectile_count] = position;
            projectile_entropy_write[projectile_count] = projectile.entropy;
            projectile_charge_write[projectile_count] = projectile.charge;

            const float heat = static_cast<float>(std::max(0.0, std::min(1.0,
                    (projectile.entropy - entropy_visual_start_) /
                            (entropy_visual_full_ - entropy_visual_start_))));
            float red = projectile_low_entropy_color_.r +
                    (projectile_high_entropy_color_.r - projectile_low_entropy_color_.r) * heat;
            float green = projectile_low_entropy_color_.g +
                    (projectile_high_entropy_color_.g - projectile_low_entropy_color_.g) * heat;
            float blue = projectile_low_entropy_color_.b +
                    (projectile_high_entropy_color_.b - projectile_low_entropy_color_.b) * heat;
            if (std::abs(projectile.charge) > 0.001) {
                const float blend = static_cast<float>(projectile_charge_blend_ratio_);
                red += (projectile_charged_color_.r - red) * blend;
                green += (projectile_charged_color_.g - green) * blend;
                blue += (projectile_charged_color_.b - blue) * blend;
            }
            const float diameter = static_cast<float>(
                    projectile_base_diameter_ + projectile_entropy_extra_diameter_ * heat);
            const std::int64_t offset = projectile_count * multimesh_stride;
            projectile_buffer_write[offset + 0] = diameter;
            projectile_buffer_write[offset + 1] = 0.0f;
            projectile_buffer_write[offset + 2] = 0.0f;
            projectile_buffer_write[offset + 3] = static_cast<float>(position.x);
            projectile_buffer_write[offset + 4] = 0.0f;
            projectile_buffer_write[offset + 5] = diameter;
            projectile_buffer_write[offset + 6] = 0.0f;
            projectile_buffer_write[offset + 7] = static_cast<float>(position.y);
            projectile_buffer_write[offset + 8] = red;
            projectile_buffer_write[offset + 9] = green;
            projectile_buffer_write[offset + 10] = blue;
            projectile_buffer_write[offset + 11] = 1.0f;
            ++projectile_count;
        }
    }
    projectile_positions.resize(projectile_count);
    projectile_entropies.resize(projectile_count);
    projectile_charges.resize(projectile_count);
    projectile_multimesh_buffer.resize(projectile_count * multimesh_stride);

    const auto wave_points = world_.wave_point_snapshot();
    PackedVector2Array wave_positions;
    PackedFloat64Array wave_momenta;
    PackedFloat32Array wave_multimesh_buffer;
    wave_positions.resize(static_cast<std::int64_t>(wave_points.size()));
    wave_momenta.resize(static_cast<std::int64_t>(wave_points.size()));
    wave_multimesh_buffer.resize(static_cast<std::int64_t>(wave_points.size()) * multimesh_stride);
    Vector2 *wave_position_write = wave_positions.ptrw();
    double *wave_momentum_write = wave_momenta.ptrw();
    float *wave_buffer_write = wave_multimesh_buffer.ptrw();
    std::int64_t wave_count = 0;
    for (const auto &point : wave_points) {
        const Vector2 position = to_godot(point.position);
        if (visible.has_point(position)) {
            wave_position_write[wave_count] = position;
            wave_momentum_write[wave_count] = point.momentum;
            const std::int64_t offset = wave_count * multimesh_stride;
            wave_buffer_write[offset + 0] = static_cast<float>(wave_point_diameter_);
            wave_buffer_write[offset + 1] = 0.0f;
            wave_buffer_write[offset + 2] = 0.0f;
            wave_buffer_write[offset + 3] = static_cast<float>(position.x);
            wave_buffer_write[offset + 4] = 0.0f;
            wave_buffer_write[offset + 5] = static_cast<float>(wave_point_diameter_);
            wave_buffer_write[offset + 6] = 0.0f;
            wave_buffer_write[offset + 7] = static_cast<float>(position.y);
            wave_buffer_write[offset + 8] = wave_point_color_.r;
            wave_buffer_write[offset + 9] = wave_point_color_.g;
            wave_buffer_write[offset + 10] = wave_point_color_.b;
            wave_buffer_write[offset + 11] = wave_point_color_.a;
            ++wave_count;
        }
    }
    wave_positions.resize(wave_count);
    wave_momenta.resize(wave_count);
    wave_multimesh_buffer.resize(wave_count * multimesh_stride);
    Dictionary result;
    result["visible_rect"] = visible;
    result["projectile_positions"] = projectile_positions;
    result["projectile_entropies"] = projectile_entropies;
    result["projectile_charges"] = projectile_charges;
    result["projectile_multimesh_buffer"] = projectile_multimesh_buffer;
    result["wave_positions"] = wave_positions;
    result["wave_momenta"] = wave_momenta;
    result["wave_multimesh_buffer"] = wave_multimesh_buffer;
    return result;
}

PackedByteArray MomentumSimulation::build_visibility_mask(
        const Array &sources, Rect2 map_rect, Vector2i grid_size, double edge_softness) const {
    struct LightSource {
        Vector2 position;
        double radius = 0.0;
    };
    PackedByteArray empty;
    if (grid_size.x <= 0 || grid_size.y <= 0 || grid_size.x > 4096 || grid_size.y > 4096 ||
            !std::isfinite(map_rect.position.x) || !std::isfinite(map_rect.position.y) ||
            !std::isfinite(map_rect.size.x) || !std::isfinite(map_rect.size.y) ||
            map_rect.size.x <= 0.0 || map_rect.size.y <= 0.0 ||
            !std::isfinite(edge_softness) || edge_softness < 0.0) {
        UtilityFunctions::push_error("MomentumSimulation.build_visibility_mask: invalid map, grid, or edge");
        return empty;
    }

    std::vector<LightSource> parsed_sources;
    parsed_sources.reserve(static_cast<std::size_t>(sources.size()));
    for (std::int64_t index = 0; index < sources.size(); ++index) {
        if (sources[index].get_type() != Variant::DICTIONARY) {
            UtilityFunctions::push_error(
                    "MomentumSimulation.build_visibility_mask: every source must be a Dictionary");
            return empty;
        }
        const Dictionary source = sources[index];
        const Vector2 position = vector_or(source, "position");
        const double radius = number_or(source, "radius", 0.0);
        if (!std::isfinite(position.x) || !std::isfinite(position.y) ||
                !std::isfinite(radius) || radius <= 0.0) {
            UtilityFunctions::push_error(
                    "MomentumSimulation.build_visibility_mask: source position and radius must be valid");
            return empty;
        }
        parsed_sources.push_back({position, radius});
    }

    const std::size_t pixel_count = static_cast<std::size_t>(grid_size.x) *
            static_cast<std::size_t>(grid_size.y);
    std::vector<float> visibility(pixel_count, 0.0f);
    const double pixel_width = map_rect.size.x / static_cast<double>(grid_size.x);
    const double pixel_height = map_rect.size.y / static_cast<double>(grid_size.y);
    for (const LightSource &source : parsed_sources) {
        const double radius_squared = source.radius * source.radius;
        const double inner_radius = source.radius - edge_softness;
        const double inner_squared = inner_radius > 0.0 ? inner_radius * inner_radius : -1.0;
        const std::int32_t minimum_x = std::max<std::int32_t>(0, static_cast<std::int32_t>(std::floor(
                (source.position.x - source.radius - map_rect.position.x) / pixel_width)) - 1);
        const std::int32_t maximum_x = std::min<std::int32_t>(grid_size.x - 1,
                static_cast<std::int32_t>(std::ceil(
                        (source.position.x + source.radius - map_rect.position.x) / pixel_width)) + 1);
        const std::int32_t minimum_y = std::max<std::int32_t>(0, static_cast<std::int32_t>(std::floor(
                (source.position.y - source.radius - map_rect.position.y) / pixel_height)) - 1);
        const std::int32_t maximum_y = std::min<std::int32_t>(grid_size.y - 1,
                static_cast<std::int32_t>(std::ceil(
                        (source.position.y + source.radius - map_rect.position.y) / pixel_height)) + 1);
        for (std::int32_t y = minimum_y; y <= maximum_y; ++y) {
            const double world_y = map_rect.position.y + (static_cast<double>(y) + 0.5) * pixel_height;
            for (std::int32_t x = minimum_x; x <= maximum_x; ++x) {
                const double world_x = map_rect.position.x + (static_cast<double>(x) + 0.5) * pixel_width;
                const double delta_x = world_x - source.position.x;
                const double delta_y = world_y - source.position.y;
                const double distance_squared = delta_x * delta_x + delta_y * delta_y;
                if (distance_squared >= radius_squared) {
                    continue;
                }
                float source_visibility = 1.0f;
                if (edge_softness > 0.0 && (inner_squared < 0.0 || distance_squared > inner_squared)) {
                    const double distance = std::sqrt(distance_squared);
                    const double linear = std::max(0.0, std::min(1.0,
                            (source.radius - distance) / edge_softness));
                    source_visibility = static_cast<float>(linear * linear * (3.0 - 2.0 * linear));
                }
                const std::size_t pixel_index = static_cast<std::size_t>(y) *
                        static_cast<std::size_t>(grid_size.x) + static_cast<std::size_t>(x);
                visibility[pixel_index] = std::max(visibility[pixel_index], source_visibility);
            }
        }
    }

    PackedByteArray result;
    result.resize(static_cast<std::int64_t>(pixel_count * 4));
    std::uint8_t *write = result.ptrw();
    for (std::size_t index = 0; index < pixel_count; ++index) {
        const std::size_t offset = index * 4;
        write[offset + 0] = 4;
        write[offset + 1] = 5;
        write[offset + 2] = 9;
        write[offset + 3] = static_cast<std::uint8_t>(std::round(
                std::max(0.0f, std::min(1.0f, 0.96f * (1.0f - visibility[index]))) * 255.0f));
    }
    return result;
}

Array MomentumSimulation::get_device_snapshot() const {
    Array result;
    for (const auto &device : world_.device_snapshot()) {
        Dictionary item;
        item["id"] = static_cast<std::int64_t>(device.id);
        item["type"] = singular_tower::device_kind_name(device.kind);
        item["position"] = to_godot(device.position);
        item["angle_radians"] = device.angle_radians;
        item["secondary_position"] = to_godot(device.secondary_position);
        item["secondary_angle_radians"] = device.secondary_angle_radians;
        item["activation_progress"] = device.activation_progress;
        item["activation_required"] = device.activation_required;
        item["stored_mass"] = device.stored_mass;
        item["stored_momentum"] = device.stored_momentum;
        item["stored_wave_momentum"] = device.stored_wave_momentum;
        item["active"] = device.active;
        result.push_back(item);
    }
    return result;
}

Array MomentumSimulation::consume_events() {
    Array result;
    for (const auto &event : world_.consume_events()) {
        Dictionary item;
        item["type"] = singular_tower::event_kind_name(event.kind);
        item["tick"] = static_cast<std::int64_t>(event.tick);
        item["entity_id"] = static_cast<std::int64_t>(event.entity_id);
        item["device_id"] = static_cast<std::int64_t>(event.device_id);
        item["position"] = to_godot(event.position);
        item["value"] = event.value;
        item["value2"] = event.value2;
        item["value3"] = event.value3;
        item["value4"] = event.value4;
        item["projectile_id"] = static_cast<std::int64_t>(event.entity_id);
        item["subject_id"] = static_cast<std::int64_t>(event.device_id);
        item["amount"] = event.value;
        if (event.kind == singular_tower::EventKind::EnemyHit ||
                event.kind == singular_tower::EventKind::EnemyDepleted) {
            item["damage"] = event.value;
            item["momentum_transferred"] = event.value2;
            item["source_entropy"] = event.value3;
            item["entropy_transferred"] = event.value4;
        }
        result.push_back(item);
    }
    return result;
}

Dictionary MomentumSimulation::get_stats() const {
    const auto &wave = world_.wave_stats();
    const auto &step = world_.step_stats();
    Dictionary result;
    result["projectile_count"] = static_cast<std::int64_t>(world_.projectile_count());
    result["wave_point_count"] = static_cast<std::int64_t>(world_.wave_point_count());
    result["device_count"] = static_cast<std::int64_t>(world_.device_count());
    result["enemy_proxy_count"] = static_cast<std::int64_t>(world_.enemy_proxy_count());
    result["tower_source_momentum"] = wave.tower_source_momentum;
    result["damage_dealt"] = wave.damage_dealt;
    result["utilization"] = wave.utilization();
    result["tick"] = static_cast<std::int64_t>(step.tick);
    result["candidate_checks"] = static_cast<std::int64_t>(step.candidate_checks);
    result["interactions"] = static_cast<std::int64_t>(step.interactions);
    result["enemy_candidate_checks"] = static_cast<std::int64_t>(step.enemy_candidate_checks);
    result["enemy_hits"] = static_cast<std::int64_t>(step.enemy_hits);
    result["last_step_milliseconds"] = step.last_step_milliseconds;
    result["backlog_seconds"] = accumulator_seconds_;
    return result;
}

void MomentumSimulation::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure", "config"), &MomentumSimulation::configure);
    ClassDB::bind_method(D_METHOD("clear"), &MomentumSimulation::clear);
    ClassDB::bind_method(D_METHOD("reset_wave_stats"), &MomentumSimulation::reset_wave_stats);
    ClassDB::bind_method(D_METHOD("emit_projectiles", "commands"), &MomentumSimulation::emit_projectiles);
    ClassDB::bind_method(D_METHOD("add_device", "spec"), &MomentumSimulation::add_device);
    ClassDB::bind_method(D_METHOD("remove_device", "device_id"), &MomentumSimulation::remove_device);
    ClassDB::bind_method(D_METHOD("set_device_transform", "device_id", "position", "angle_radians"),
            &MomentumSimulation::set_device_transform);
    ClassDB::bind_method(D_METHOD("set_device_anchor_transform", "device_id", "anchor_index", "position",
                                 "angle_radians"), &MomentumSimulation::set_device_anchor_transform);
    ClassDB::bind_method(D_METHOD("release_accumulator", "device_id"),
            &MomentumSimulation::release_accumulator);
    ClassDB::bind_method(D_METHOD("add_diagnostic_target", "spec"),
            &MomentumSimulation::add_diagnostic_target);
    ClassDB::bind_method(D_METHOD("sync_enemy_proxies", "snapshot"), &MomentumSimulation::sync_enemy_proxies);
    ClassDB::bind_method(D_METHOD("clear_enemy_proxies"), &MomentumSimulation::clear_enemy_proxies);
    ClassDB::bind_method(D_METHOD("step", "frame_delta_seconds"), &MomentumSimulation::step);
    ClassDB::bind_method(D_METHOD("get_projectile_snapshot"), &MomentumSimulation::get_projectile_snapshot);
    ClassDB::bind_method(D_METHOD("get_wave_point_snapshot"), &MomentumSimulation::get_wave_point_snapshot);
    ClassDB::bind_method(D_METHOD("get_render_snapshot", "view_rect", "margin"),
            &MomentumSimulation::get_render_snapshot, DEFVAL(96.0));
    ClassDB::bind_method(D_METHOD("build_visibility_mask", "sources", "map_rect", "grid_size", "edge_softness"),
            &MomentumSimulation::build_visibility_mask);
    ClassDB::bind_method(D_METHOD("get_device_snapshot"), &MomentumSimulation::get_device_snapshot);
    ClassDB::bind_method(D_METHOD("consume_events"), &MomentumSimulation::consume_events);
    ClassDB::bind_method(D_METHOD("get_stats"), &MomentumSimulation::get_stats);
}

} // namespace godot

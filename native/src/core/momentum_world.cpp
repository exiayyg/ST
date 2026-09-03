#include "core/momentum_world.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <limits>
#include <stdexcept>
#include <unordered_set>

namespace singular_tower {

namespace {

constexpr double kPi = 3.14159265358979323846;
constexpr double kNoHit = std::numeric_limits<double>::infinity();

double dot(Vec2 a, Vec2 b) {
    return a.x * b.x + a.y * b.y;
}

Vec2 rotate(Vec2 value, double radians) {
    const double cosine = std::cos(radians);
    const double sine = std::sin(radians);
    return {value.x * cosine - value.y * sine, value.x * sine + value.y * cosine};
}

double clamp(double value, double minimum, double maximum) {
    return std::max(minimum, std::min(value, maximum));
}

bool finite(Vec2 value) {
    return std::isfinite(value.x) && std::isfinite(value.y);
}

std::int64_t cell_key(std::int64_t x, std::int64_t y) {
    return (x * 73856093LL) ^ (y * 19349663LL);
}

bool contains_id(const std::vector<std::uint64_t> &values, std::uint64_t id) {
    return std::find(values.begin(), values.end(), id) != values.end();
}

} // namespace

Vec2 Vec2::operator+(const Vec2 &other) const {
    return {x + other.x, y + other.y};
}

Vec2 Vec2::operator-(const Vec2 &other) const {
    return {x - other.x, y - other.y};
}

Vec2 Vec2::operator*(double scalar) const {
    return {x * scalar, y * scalar};
}

Vec2 Vec2::operator/(double scalar) const {
    return {x / scalar, y / scalar};
}

Vec2 &Vec2::operator+=(const Vec2 &other) {
    x += other.x;
    y += other.y;
    return *this;
}

Vec2 &Vec2::operator*=(double scalar) {
    x *= scalar;
    y *= scalar;
    return *this;
}

double Vec2::length_squared() const {
    return x * x + y * y;
}

double Vec2::length() const {
    return std::sqrt(length_squared());
}

Vec2 Vec2::normalized() const {
    const double magnitude = length();
    if (magnitude <= std::numeric_limits<double>::epsilon()) {
        return {};
    }
    return *this / magnitude;
}

double WaveStats::utilization() const {
    return tower_source_momentum > 0.0 ? damage_dealt / tower_source_momentum : 0.0;
}

MomentumWorld::MomentumWorld(const SimulationConfig &config) {
    configure(config);
}

void MomentumWorld::configure(const SimulationConfig &config) {
    if (!std::isfinite(config.initial_projectile_momentum) || config.initial_projectile_momentum <= 0.0 ||
            !std::isfinite(config.initial_projectile_mass) || config.initial_projectile_mass <= 0.0 ||
            !std::isfinite(config.initial_projectile_speed) || config.initial_projectile_speed <= 0.0) {
        throw std::invalid_argument("initial projectile values must be finite and positive");
    }
    if (!std::isfinite(config.momentum_zero_epsilon) || config.momentum_zero_epsilon < 0.0 ||
            !std::isfinite(config.projectile_radius) || config.projectile_radius <= 0.0 ||
            !std::isfinite(config.wave_point_radius) || config.wave_point_radius <= 0.0 ||
			!std::isfinite(config.spatial_cell_size) || config.spatial_cell_size <= 0.0 ||
			!std::isfinite(config.enemy_spatial_cell_size) || config.enemy_spatial_cell_size <= 0.0 ||
			!std::isfinite(config.entity_spawn_clearance) || config.entity_spawn_clearance < 0.0 ||
			config.max_interactions_per_step == 0) {
        throw std::invalid_argument("invalid simulation tolerance, radius, spatial cell, or interaction guard");
    }
    if (!std::isfinite(config.entropy_start) || config.entropy_start < 0.0 ||
            !std::isfinite(config.entropy_full_effect) || config.entropy_full_effect <= config.entropy_start ||
            config.entropy_curve.size() < 2) {
        throw std::invalid_argument("invalid entropy threshold or curve");
    }
    double previous_x = -1.0;
    double previous_y = -1.0;
    for (const Vec2 point : config.entropy_curve) {
        if (!finite(point) || point.x < previous_x || point.y < previous_y ||
                point.x < 0.0 || point.x > 1.0 || point.y < 0.0 || point.y > 1.0) {
            throw std::invalid_argument("entropy curve must be finite, normalized, and monotone");
        }
        previous_x = point.x;
        previous_y = point.y;
    }
    if (config.entropy_curve.front().x != 0.0 || config.entropy_curve.front().y != 0.0 ||
            config.entropy_curve.back().x != 1.0 || config.entropy_curve.back().y != 1.0) {
        throw std::invalid_argument("entropy curve endpoints must be (0,0) and (1,1)");
    }
    if (!std::isfinite(config.max_angle_deviation_radians) || config.max_angle_deviation_radians < 0.0 ||
            !std::isfinite(config.max_speed_deviation_ratio) || config.max_speed_deviation_ratio < 0.0 ||
            !std::isfinite(config.max_mass_deviation_ratio) || config.max_mass_deviation_ratio < 0.0 ||
            !std::isfinite(config.max_diode_exit_offset) || config.max_diode_exit_offset < 0.0 ||
            !std::isfinite(config.max_diode_angle_deviation_radians) ||
            config.max_diode_angle_deviation_radians < 0.0 ||
            !std::isfinite(config.max_split_direction_deviation_radians) ||
            config.max_split_direction_deviation_radians < 0.0 ||
            !std::isfinite(config.max_split_share_deviation_ratio) ||
            config.max_split_share_deviation_ratio < 0.0 || config.max_split_share_deviation_ratio > 0.5) {
        throw std::invalid_argument("entropy deviation maxima must be finite and nonnegative");
    }
    config_ = config;
    random_.seed(config_.random_seed);
    rebuild_spatial_index();
    rebuild_enemy_spatial_index();
}

void MomentumWorld::clear() {
    projectiles_.clear();
    wave_points_.clear();
    pending_projectiles_.clear();
    pending_wave_points_.clear();
    devices_.clear();
    targets_.clear();
    enemies_.clear();
    events_.clear();
    device_cells_.clear();
    device_query_marks_.clear();
    device_query_scratch_.clear();
    device_query_generation_ = 0;
    enemy_cells_.clear();
    enemy_query_marks_.clear();
    enemy_query_scratch_.clear();
    enemy_query_generation_ = 0;
    active_wave_converter_count_ = 0;
    wave_stats_ = {};
    step_stats_ = {};
    next_projectile_id_ = 1;
    next_wave_point_id_ = 1;
    next_device_id_ = 1;
    next_target_id_ = 1;
    random_.seed(config_.random_seed);
}

void MomentumWorld::reset_wave_stats() {
    wave_stats_ = {};
}

std::uint64_t MomentumWorld::emit_projectile(
        Vec2 position, Vec2 velocity, double mass, bool tower_source, double entropy, double charge) {
    if (!finite(position) || !finite(velocity) || !std::isfinite(mass) || mass <= 0.0 ||
            !std::isfinite(entropy) || !std::isfinite(charge)) {
        throw std::invalid_argument("projectile values must be finite and mass must be positive");
    }
    Projectile projectile;
    projectile.id = next_projectile_id_++;
    projectile.position = position;
    projectile.previous_position = position;
    projectile.velocity = velocity;
    projectile.mass = mass;
    projectile.charge = charge;
    projectile.entropy = std::max(0.0, entropy);
    projectiles_.push_back(projectile);
    if (tower_source) {
        wave_stats_.tower_source_momentum += momentum_magnitude(projectiles_.back());
    }
    return projectile.id;
}

std::uint64_t MomentumWorld::add_device(const DeviceSpec &spec) {
    if (!finite(spec.position) || !finite(spec.secondary_position) || !std::isfinite(spec.angle_radians) ||
            !std::isfinite(spec.secondary_angle_radians) || !std::isfinite(spec.activation_radius) ||
            spec.activation_radius <= 0.0 || !std::isfinite(spec.activation_required) ||
            spec.activation_required <= config_.initial_projectile_momentum) {
        throw std::invalid_argument("device transforms must be finite and activation must exceed initial momentum");
    }
    if (spec.half_length <= 0.0 || spec.speed_multiplier <= 1.0 || spec.mass_multiplier <= 1.0 ||
            spec.splitter_half_separation <= 0.0 || spec.field_radius <= 0.0 ||
            spec.electric_acceleration < 0.0 || spec.magnetic_angular_speed < 0.0 ||
			spec.shockwave_radius < 0.0 || spec.wave_point_count == 0 || spec.wave_point_count > 4096 ||
			spec.wave_fan_radians < 0.0 || spec.wave_fan_radians > 2.0 * kPi || spec.wave_speed <= 0.0 ||
			!std::isfinite(spec.reconstruction_mass) || spec.reconstruction_mass <= 0.0 ||
			!std::isfinite(spec.reconstruction_speed) || spec.reconstruction_speed <= 0.0 ||
			!std::isfinite(spec.entropy_sensitivity) || spec.entropy_sensitivity < 0.0) {
        throw std::invalid_argument("invalid device balance specification");
    }
    Device device;
    device.id = next_device_id_++;
    device.spec = spec;
    devices_.push_back(device);
    rebuild_spatial_index();
    return device.id;
}

bool MomentumWorld::remove_device(std::uint64_t device_id) {
    const auto found = std::find_if(devices_.begin(), devices_.end(),
            [device_id](const Device &device) { return device.id == device_id; });
    if (found == devices_.end()) {
        return false;
    }
    const Vec2 position = found->spec.position;
    devices_.erase(found);
    rebuild_spatial_index();
    push_event(EventKind::DeviceRemoved, 0, device_id, position);
    return true;
}

bool MomentumWorld::set_device_transform(std::uint64_t device_id, Vec2 position, double angle_radians) {
    if (!finite(position) || !std::isfinite(angle_radians)) {
        return false;
    }
    Device *device = find_device(device_id);
    if (device == nullptr) {
        return false;
    }
    device->spec.position = position;
    device->spec.angle_radians = angle_radians;
    rebuild_spatial_index();
    return true;
}

bool MomentumWorld::set_device_anchor_transform(
        std::uint64_t device_id, std::uint32_t anchor_index, Vec2 position, double angle_radians) {
    if (!finite(position) || !std::isfinite(angle_radians)) {
        return false;
    }
    Device *device = find_device(device_id);
    if (device == nullptr || device->spec.kind != DeviceKind::Diode || anchor_index > 1) {
        return false;
    }
    if (anchor_index == 0) {
        device->spec.position = position;
        device->spec.angle_radians = angle_radians;
    } else {
        device->spec.secondary_position = position;
        device->spec.secondary_angle_radians = angle_radians;
    }
    rebuild_spatial_index();
    return true;
}

bool MomentumWorld::release_accumulator(std::uint64_t device_id) {
    Device *device = find_device(device_id);
    if (device == nullptr || !device->active || device->spec.kind != DeviceKind::Accumulator ||
            device->stored_mass <= config_.momentum_zero_epsilon ||
            device->stored_momentum <= config_.momentum_zero_epsilon) {
        return false;
    }
    const Vec2 direction = {std::cos(device->spec.angle_radians), std::sin(device->spec.angle_radians)};
    const double released_mass = device->stored_mass;
    const double released_momentum = device->stored_momentum;
    const double speed = released_momentum / released_mass;
	const Vec2 position = device->spec.position + direction *
			(device->spec.activation_radius + config_.projectile_radius + config_.entity_spawn_clearance);
    const std::uint64_t projectile_id = emit_projectile(position, direction * speed, released_mass, false, 0.0, 0.0);
    device->stored_mass = 0.0;
    device->stored_momentum = 0.0;
    push_event(EventKind::AccumulatorReleased, projectile_id, device_id, position, released_momentum, released_mass);
    return true;
}

std::uint64_t MomentumWorld::add_diagnostic_target(const DiagnosticTargetSpec &spec) {
    if (!finite(spec.position) || !std::isfinite(spec.radius) || spec.radius <= 0.0 ||
            !std::isfinite(spec.damage_per_momentum) || spec.damage_per_momentum < 0.0 ||
            !std::isfinite(spec.momentum_absorption_fraction) || spec.momentum_absorption_fraction < 0.0 ||
            spec.momentum_absorption_fraction > 1.0) {
        throw std::invalid_argument("invalid diagnostic target specification");
    }
    DiagnosticTarget target;
    target.id = next_target_id_++;
    target.spec = spec;
    targets_.push_back(target);
    return target.id;
}

bool MomentumWorld::sync_enemy_proxies(const std::vector<EnemyProxySpec> &specs) {
    std::vector<EnemyProxy> replacements;
    replacements.reserve(specs.size());
    std::unordered_set<std::uint64_t> ids;
    ids.reserve(specs.size());
    for (const EnemyProxySpec &spec : specs) {
        if (spec.id == 0 || !finite(spec.position) || !std::isfinite(spec.radius) || spec.radius <= 0.0 ||
                !std::isfinite(spec.remaining_hp) || spec.remaining_hp < 0.0 ||
                !std::isfinite(spec.momentum_absorption) || spec.momentum_absorption < 0.0 ||
                spec.momentum_absorption > 1.0 || !std::isfinite(spec.damage_per_momentum) ||
                spec.damage_per_momentum < 0.0 || !std::isfinite(spec.entropy_transfer_ratio) ||
                spec.entropy_transfer_ratio < 0.0 || spec.entropy_transfer_ratio > 1.0 ||
                ids.find(spec.id) != ids.end()) {
            return false;
        }
        ids.insert(spec.id);
        replacements.push_back({spec});
    }
    enemies_.swap(replacements);
    rebuild_enemy_spatial_index();
    return true;
}

void MomentumWorld::clear_enemy_proxies() {
    enemies_.clear();
    rebuild_enemy_spatial_index();
    for (Projectile &projectile : projectiles_) {
        projectile.last_enemy_id = 0;
    }
}

void MomentumWorld::step(double fixed_delta_seconds) {
    if (!std::isfinite(fixed_delta_seconds) || fixed_delta_seconds <= 0.0) {
        return;
    }
    const auto started = std::chrono::steady_clock::now();
    ++step_stats_.tick;
    step_stats_.candidate_checks = 0;
    step_stats_.interactions = 0;
    step_stats_.enemy_candidate_checks = 0;
    step_stats_.enemy_hits = 0;

    const std::size_t projectile_count_at_start = projectiles_.size();
    for (std::size_t index = 0; index < projectile_count_at_start; ++index) {
        if (!is_zero_momentum(projectiles_[index])) {
            process_projectile(projectiles_[index], fixed_delta_seconds);
        }
    }
    const std::size_t wave_count_at_start = wave_points_.size();
    for (std::size_t index = 0; index < wave_count_at_start; ++index) {
        if (!is_zero_momentum(wave_points_[index])) {
            process_wave_point(wave_points_[index], fixed_delta_seconds);
        }
    }

    retire_zero_momentum_entities();
    projectiles_.insert(projectiles_.end(), pending_projectiles_.begin(), pending_projectiles_.end());
    wave_points_.insert(wave_points_.end(), pending_wave_points_.begin(), pending_wave_points_.end());
    pending_projectiles_.clear();
    pending_wave_points_.clear();

    const auto finished = std::chrono::steady_clock::now();
    step_stats_.last_step_milliseconds =
            std::chrono::duration<double, std::milli>(finished - started).count();
}

void MomentumWorld::process_projectile(Projectile &projectile, double fixed_delta_seconds) {
    projectile.previous_position = projectile.position;
    const double entropy_acceleration =
            1.0 + static_cast<double>(projectile.interaction_count) * config_.entropy_interaction_acceleration;
    projectile.entropy += config_.entropy_per_second * entropy_acceleration * fixed_delta_seconds;
    apply_active_fields(projectile, fixed_delta_seconds);

    if (projectile.last_device_id != 0) {
        const Device *last = find_device(projectile.last_device_id);
        if (last == nullptr || (projectile.position - last->spec.position).length() >
                        last->spec.activation_radius + config_.projectile_radius + 0.5) {
            projectile.last_device_id = 0;
        }
    }
    if (projectile.last_target_id != 0) {
        const auto target = std::find_if(targets_.begin(), targets_.end(), [&projectile](const DiagnosticTarget &item) {
            return item.id == projectile.last_target_id;
        });
        if (target == targets_.end() || (projectile.position - target->spec.position).length() >
                        target->spec.radius + config_.projectile_radius + 0.5) {
            projectile.last_target_id = 0;
        }
    }
    if (projectile.last_enemy_id != 0) {
        const EnemyProxy *enemy = find_enemy(projectile.last_enemy_id);
        if (enemy == nullptr || enemy->spec.remaining_hp <= 0.0 ||
                (projectile.position - enemy->spec.position).length() >
                        enemy->spec.radius + config_.projectile_radius + 0.5) {
            projectile.last_enemy_id = 0;
        }
    }

    double remaining = fixed_delta_seconds;
    std::uint32_t interaction_count = 0;
    while (remaining > 1e-12 && !is_zero_momentum(projectile) &&
            interaction_count < config_.max_interactions_per_step) {
        const Vec2 from = projectile.position;
        const Vec2 to = from + projectile.velocity * remaining;
        double best_fraction = kNoHit;
        std::size_t best_device_index = std::numeric_limits<std::size_t>::max();
        std::size_t best_target_index = std::numeric_limits<std::size_t>::max();
        std::size_t best_enemy_index = std::numeric_limits<std::size_t>::max();

        for (const std::size_t device_index : query_device_indices(from, to, config_.projectile_radius)) {
            ++step_stats_.candidate_checks;
            const Device &device = devices_[device_index];
            if (device.id == projectile.last_device_id) {
                continue;
            }
            if (device.active && (device.spec.kind == DeviceKind::ElectricField ||
                                         device.spec.kind == DeviceKind::MagneticField)) {
                continue;
            }
            double fraction = kNoHit;
            if (device.active && device.spec.kind == DeviceKind::BouncePlate) {
                fraction = segment_plate_hit_fraction(projectile, to, device);
            } else {
                fraction = segment_circle_hit_fraction(from, to, device.spec.position,
                        device.spec.activation_radius + config_.projectile_radius);
            }
            if (fraction < best_fraction ||
                    (fraction == best_fraction && best_device_index != std::numeric_limits<std::size_t>::max() &&
                            device.id < devices_[best_device_index].id)) {
                best_fraction = fraction;
                best_device_index = device_index;
                best_target_index = std::numeric_limits<std::size_t>::max();
                best_enemy_index = std::numeric_limits<std::size_t>::max();
            }
        }

        for (const std::size_t enemy_index : query_enemy_indices(from, to, config_.projectile_radius)) {
            ++step_stats_.candidate_checks;
            ++step_stats_.enemy_candidate_checks;
            const EnemyProxy &enemy = enemies_[enemy_index];
            if (enemy.spec.remaining_hp <= 0.0 || enemy.spec.id == projectile.last_enemy_id) {
                continue;
            }
            const double fraction = segment_circle_hit_fraction(from, to, enemy.spec.position,
                    enemy.spec.radius + config_.projectile_radius);
            const bool no_device_at_same_distance = best_device_index == std::numeric_limits<std::size_t>::max();
            if (fraction < best_fraction ||
                    (fraction == best_fraction && no_device_at_same_distance &&
                            (best_enemy_index == std::numeric_limits<std::size_t>::max() ||
                                    enemy.spec.id < enemies_[best_enemy_index].spec.id))) {
                best_fraction = fraction;
                best_enemy_index = enemy_index;
                best_device_index = std::numeric_limits<std::size_t>::max();
                best_target_index = std::numeric_limits<std::size_t>::max();
            }
        }

        for (std::size_t target_index = 0; target_index < targets_.size(); ++target_index) {
            const DiagnosticTarget &target = targets_[target_index];
            if (target.id == projectile.last_target_id) {
                continue;
            }
            const double fraction = segment_circle_hit_fraction(from, to, target.spec.position,
                    target.spec.radius + config_.projectile_radius);
            if (fraction < best_fraction) {
                best_fraction = fraction;
                best_target_index = target_index;
                best_device_index = std::numeric_limits<std::size_t>::max();
                best_enemy_index = std::numeric_limits<std::size_t>::max();
            }
        }

        if (!std::isfinite(best_fraction)) {
            projectile.position = to;
            break;
        }

        projectile.position = from + (to - from) * best_fraction;
        remaining *= std::max(0.0, 1.0 - best_fraction);
        ++interaction_count;
        ++step_stats_.interactions;

        if (best_enemy_index != std::numeric_limits<std::size_t>::max()) {
            EnemyProxy &enemy = enemies_[best_enemy_index];
            const double momentum_before_hit = momentum_magnitude(projectile);
            const double transferred_momentum = momentum_before_hit * enemy.spec.momentum_absorption;
            const double nominal_damage = transferred_momentum * enemy.spec.damage_per_momentum;
            const double actual_damage = std::min(enemy.spec.remaining_hp, nominal_damage);
            const double source_entropy = projectile.entropy;
            const double transferred_entropy = source_entropy * enemy.spec.entropy_transfer_ratio;
            enemy.spec.remaining_hp = std::max(0.0, enemy.spec.remaining_hp - actual_damage);
            wave_stats_.damage_dealt += actual_damage;
            projectile.velocity *= (1.0 - enemy.spec.momentum_absorption);
            projectile.last_enemy_id = enemy.spec.id;
            ++step_stats_.enemy_hits;
            push_event(EventKind::EnemyHit, projectile.id, enemy.spec.id, projectile.position,
                    actual_damage, transferred_momentum, source_entropy, transferred_entropy);
            if (enemy.spec.remaining_hp <= 0.0) {
                push_event(EventKind::EnemyDepleted, projectile.id, enemy.spec.id, projectile.position,
                        actual_damage, transferred_momentum, source_entropy, transferred_entropy);
            }
            if (!is_zero_momentum(projectile)) {
                projectile.position += projectile.velocity.normalized() * 0.01;
            }
            continue;
        }

        if (best_target_index != std::numeric_limits<std::size_t>::max()) {
            const DiagnosticTarget &target = targets_[best_target_index];
            const double momentum_before_hit = momentum_magnitude(projectile);
            const double damage = momentum_before_hit * target.spec.damage_per_momentum;
            wave_stats_.damage_dealt += damage;
            projectile.velocity *= (1.0 - target.spec.momentum_absorption_fraction);
            projectile.last_target_id = target.id;
            push_event(EventKind::TargetHit, projectile.id, target.id, projectile.position, damage, momentum_before_hit);
            if (!is_zero_momentum(projectile)) {
                projectile.position += projectile.velocity.normalized() * 0.01;
            }
            continue;
        }

        Device &device = devices_[best_device_index];
        if (!device.active) {
            const double absorbed = momentum_magnitude(projectile);
            device.activation_progress = std::min(device.spec.activation_required, device.activation_progress + absorbed);
            projectile.velocity = {};
            projectile.last_device_id = device.id;
            push_event(EventKind::MomentumAbsorbed, projectile.id, device.id, projectile.position, absorbed,
                    device.activation_progress);
            if (device.activation_progress >= device.spec.activation_required) {
                device.active = true;
                push_event(EventKind::DeviceActivated, projectile.id, device.id, device.spec.position,
                        device.activation_progress, device.spec.activation_required);
                if (device.spec.kind == DeviceKind::WaveConverter) {
                    rebuild_spatial_index();
                }
            }
            break;
        }

        projectile.last_device_id = device.id;
        if (!apply_device_interaction(projectile, device, projectile.position)) {
            break;
        }
        projectile.position += projectile.velocity.normalized() * 0.01;
    }

    if (interaction_count >= config_.max_interactions_per_step && remaining > 1e-12 &&
            !is_zero_momentum(projectile)) {
        push_event(EventKind::InteractionGuardTriggered, projectile.id, projectile.last_device_id,
                projectile.position, static_cast<double>(interaction_count));
    }
}

void MomentumWorld::apply_active_fields(Projectile &projectile, double fixed_delta_seconds) {
    std::vector<std::uint64_t> current_fields;
    const auto &candidates = query_device_indices(
            projectile.position, projectile.position, config_.projectile_radius);
    for (const std::size_t device_index : candidates) {
        Device &device = devices_[device_index];
        if (!device.active || (device.spec.kind != DeviceKind::ElectricField &&
                                      device.spec.kind != DeviceKind::MagneticField) ||
                (projectile.position - device.spec.position).length_squared() >
                        device.spec.field_radius * device.spec.field_radius) {
            continue;
        }
        if (device.spec.kind == DeviceKind::MagneticField &&
                std::abs(projectile.charge) <= config_.momentum_zero_epsilon) {
            continue;
        }
        current_fields.push_back(device.id);
        const bool entering = !contains_id(projectile.field_memberships, device.id);
        if (entering) {
            apply_entropy_interaction(projectile, device.spec.entropy_sensitivity, true, true, false);
        }
        if (device.spec.kind == DeviceKind::ElectricField) {
            if (entering || projectile.charge != 1.0) {
                push_event(EventKind::ProjectileCharged, projectile.id, device.id, projectile.position, 1.0);
            }
            projectile.charge = 1.0;
            const Vec2 direction = {std::cos(device.spec.angle_radians), std::sin(device.spec.angle_radians)};
            projectile.velocity += direction * (device.spec.electric_acceleration * fixed_delta_seconds);
        } else {
            if (entering) {
                push_event(EventKind::MagneticFieldEntered, projectile.id, device.id, projectile.position,
                        device.spec.shockwave_radius);
                push_event(EventKind::Shockwave, projectile.id, device.id, projectile.position,
                        device.spec.shockwave_radius, 1.0);
            }
            const double sign = projectile.charge >= 0.0 ? 1.0 : -1.0;
            projectile.velocity = rotate(
                    projectile.velocity, sign * device.spec.magnetic_angular_speed * fixed_delta_seconds);
        }
    }

    for (const std::uint64_t old_id : projectile.field_memberships) {
        if (contains_id(current_fields, old_id)) {
            continue;
        }
        const Device *old_device = find_device(old_id);
        if (old_device != nullptr && old_device->spec.kind == DeviceKind::MagneticField &&
                std::abs(projectile.charge) > config_.momentum_zero_epsilon) {
            push_event(EventKind::MagneticFieldExited, projectile.id, old_id, projectile.position,
                    old_device->spec.shockwave_radius);
            push_event(EventKind::Shockwave, projectile.id, old_id, projectile.position,
                    old_device->spec.shockwave_radius, -1.0);
        }
    }
    projectile.field_memberships.swap(current_fields);
}

bool MomentumWorld::apply_device_interaction(Projectile &projectile, Device &device, Vec2 hit_position) {
    switch (device.spec.kind) {
        case DeviceKind::BouncePlate: {
            const Vec2 tangent = {std::cos(device.spec.angle_radians), std::sin(device.spec.angle_radians)};
            const Vec2 normal = {-tangent.y, tangent.x};
            projectile.velocity = projectile.velocity - normal * (2.0 * dot(projectile.velocity, normal));
            apply_entropy_interaction(projectile, device.spec.entropy_sensitivity, true, false, false);
            push_event(EventKind::ProjectileReflected, projectile.id, device.id, hit_position,
                    momentum_magnitude(projectile));
            return true;
        }
        case DeviceKind::SpeedIncreaser:
            projectile.velocity *= device.spec.speed_multiplier;
            apply_entropy_interaction(projectile, device.spec.entropy_sensitivity, false, true, false);
            push_event(EventKind::ProjectileAccelerated, projectile.id, device.id, hit_position,
                    momentum_magnitude(projectile), device.spec.speed_multiplier);
            return true;
        case DeviceKind::MassIncreaser:
            projectile.mass *= device.spec.mass_multiplier;
            apply_entropy_interaction(projectile, device.spec.entropy_sensitivity, false, false, true);
            push_event(EventKind::ProjectileMassIncreased, projectile.id, device.id, hit_position,
                    momentum_magnitude(projectile), device.spec.mass_multiplier);
            return true;
        case DeviceKind::Splitter: {
            const Projectile source = projectile;
            projectile.velocity = {};
            emit_split_projectiles(source, device);
            push_event(EventKind::ProjectileSplit, projectile.id, device.id, hit_position,
                    momentum_magnitude(source), 2.0);
            return false;
        }
        case DeviceKind::Diode: {
            const double speed = projectile.velocity.length();
            const Vec2 direction = {std::cos(device.spec.secondary_angle_radians),
                    std::sin(device.spec.secondary_angle_radians)};
            const Vec2 normal = {-direction.y, direction.x};
			projectile.position = device.spec.secondary_position + direction *
					(device.spec.activation_radius + config_.projectile_radius + config_.entity_spawn_clearance);
            projectile.velocity = direction * speed;
            apply_entropy_interaction(projectile, device.spec.entropy_sensitivity, false, false, false);
            const double weight = uncertainty_weight(projectile.entropy) *
                    std::max(0.0, device.spec.entropy_sensitivity);
            if (weight > 0.0) {
                std::uniform_real_distribution<double> distribution(-1.0, 1.0);
                projectile.position += normal *
                        (distribution(random_) * config_.max_diode_exit_offset * weight);
                projectile.velocity = rotate(projectile.velocity,
                        distribution(random_) * config_.max_diode_angle_deviation_radians * weight);
            }
            push_event(EventKind::ProjectileTeleported, projectile.id, device.id, projectile.position,
                    momentum_magnitude(projectile));
            return true;
        }
        case DeviceKind::WaveConverter: {
            const Projectile source = projectile;
            projectile.velocity = {};
            emit_wave_points(source, device);
            push_event(EventKind::WaveEmitted, source.id, device.id, hit_position,
                    momentum_magnitude(source), static_cast<double>(device.spec.wave_point_count));
            return false;
        }
        case DeviceKind::Accumulator: {
            const double momentum = momentum_magnitude(projectile);
            device.stored_mass += projectile.mass;
            device.stored_momentum += momentum;
            projectile.velocity = {};
            push_event(EventKind::AccumulatorStored, projectile.id, device.id, hit_position,
                    device.stored_momentum, device.stored_mass);
            return false;
        }
        case DeviceKind::ElectricField:
        case DeviceKind::MagneticField:
            return true;
    }
    return true;
}

void MomentumWorld::emit_split_projectiles(const Projectile &source, const Device &device) {
    Projectile transformed = source;
    apply_entropy_interaction(transformed, device.spec.entropy_sensitivity, false, false, false);
    const double weight = uncertainty_weight(transformed.entropy) *
            std::max(0.0, device.spec.entropy_sensitivity);
    std::uniform_real_distribution<double> distribution(-1.0, 1.0);
    const double direction_deviation = weight > 0.0 ? distribution(random_) *
            config_.max_split_direction_deviation_radians * weight : 0.0;
    const double share_deviation = weight > 0.0 ? distribution(random_) *
            config_.max_split_share_deviation_ratio * weight : 0.0;
    const Vec2 ideal_direction = {std::cos(device.spec.angle_radians), std::sin(device.spec.angle_radians)};
    const Vec2 normal = {-ideal_direction.y, ideal_direction.x};
    const Vec2 output_direction = rotate(ideal_direction, direction_deviation);
    const double speed = source.velocity.length();
    for (const double side : {-1.0, 1.0}) {
        Projectile output = transformed;
        output.id = next_projectile_id_++;
        output.mass = source.mass * (0.5 + (side < 0.0 ? share_deviation : -share_deviation));
		output.position = device.spec.position + normal * (device.spec.splitter_half_separation * side) +
				ideal_direction * (device.spec.activation_radius + config_.projectile_radius +
						config_.entity_spawn_clearance);
        output.previous_position = output.position;
        output.velocity = output_direction * speed;
        output.last_device_id = device.id;
        output.last_target_id = 0;
        output.last_enemy_id = 0;
        output.field_memberships.clear();
        pending_projectiles_.push_back(output);
    }
}

void MomentumWorld::emit_wave_points(const Projectile &source, const Device &device) {
    const double total_momentum = momentum_magnitude(source);
    const double point_momentum = total_momentum / static_cast<double>(device.spec.wave_point_count);
    for (std::uint32_t index = 0; index < device.spec.wave_point_count; ++index) {
        const double ratio = device.spec.wave_point_count == 1 ? 0.5 :
                static_cast<double>(index) / static_cast<double>(device.spec.wave_point_count - 1);
        const double angle = device.spec.angle_radians - device.spec.wave_fan_radians * 0.5 +
                device.spec.wave_fan_radians * ratio;
        const Vec2 direction = {std::cos(angle), std::sin(angle)};
        WavePoint point;
        point.id = next_wave_point_id_++;
		point.position = device.spec.position + direction *
				(device.spec.activation_radius + config_.wave_point_radius + config_.entity_spawn_clearance);
        point.previous_position = point.position;
        point.velocity = direction * device.spec.wave_speed;
        point.momentum = point_momentum;
        point.source_device_id = device.id;
        point.ignores_source = true;
        pending_wave_points_.push_back(point);
    }
}

void MomentumWorld::process_wave_point(WavePoint &point, double fixed_delta_seconds) {
    point.previous_position = point.position;
    const Vec2 to = point.position + point.velocity * fixed_delta_seconds;
    if (point.ignores_source) {
        const Device *source = find_device(point.source_device_id);
        if (source == nullptr || (point.position - source->spec.position).length() >
                        source->spec.activation_radius + config_.wave_point_radius + 0.5) {
            point.ignores_source = false;
        }
    }

    if (active_wave_converter_count_ == 0) {
        point.position = to;
        return;
    }

    double best_fraction = kNoHit;
    std::size_t best_device_index = std::numeric_limits<std::size_t>::max();
    for (const std::size_t device_index : query_device_indices(point.position, to, config_.wave_point_radius)) {
        ++step_stats_.candidate_checks;
        const Device &device = devices_[device_index];
        if (!device.active || device.spec.kind != DeviceKind::WaveConverter ||
                (point.ignores_source && device.id == point.source_device_id)) {
            continue;
        }
        const double fraction = segment_circle_hit_fraction(point.position, to, device.spec.position,
                device.spec.activation_radius + config_.wave_point_radius);
        if (fraction < best_fraction ||
                (fraction == best_fraction && best_device_index != std::numeric_limits<std::size_t>::max() &&
                        device.id < devices_[best_device_index].id)) {
            best_fraction = fraction;
            best_device_index = device_index;
        }
    }

    if (best_device_index == std::numeric_limits<std::size_t>::max()) {
        point.position = to;
        return;
    }

    point.position = point.position + (to - point.position) * best_fraction;
    Device &receiver = devices_[best_device_index];
    receiver.stored_wave_momentum += point.momentum;
    push_event(EventKind::WaveAbsorbed, point.id, receiver.id, point.position, point.momentum,
            receiver.stored_wave_momentum);
    point.momentum = 0.0;
    ++step_stats_.interactions;
    reconstruct_wave_projectiles(receiver);
}

void MomentumWorld::reconstruct_wave_projectiles(Device &device) {
	const double reconstruction_momentum =
			device.spec.reconstruction_mass * device.spec.reconstruction_speed;
	while (device.stored_wave_momentum + config_.momentum_zero_epsilon >= reconstruction_momentum) {
		device.stored_wave_momentum -= reconstruction_momentum;
        if (device.stored_wave_momentum < config_.momentum_zero_epsilon) {
            device.stored_wave_momentum = 0.0;
        }
        const Vec2 direction = {std::cos(device.spec.angle_radians), std::sin(device.spec.angle_radians)};
        Projectile projectile;
        projectile.id = next_projectile_id_++;
		projectile.position = device.spec.position + direction *
				(device.spec.activation_radius + config_.projectile_radius + config_.entity_spawn_clearance);
        projectile.previous_position = projectile.position;
		projectile.velocity = direction * device.spec.reconstruction_speed;
		projectile.mass = device.spec.reconstruction_mass;
        projectile.charge = 0.0;
        projectile.entropy = 0.0;
        projectile.last_device_id = device.id;
        pending_projectiles_.push_back(projectile);
		push_event(EventKind::WaveReconstructed, projectile.id, device.id, projectile.position,
				reconstruction_momentum, device.stored_wave_momentum);
    }
}

void MomentumWorld::apply_entropy_interaction(Projectile &projectile, double sensitivity,
        bool perturb_angle, bool perturb_speed, bool perturb_mass) {
    ++projectile.interaction_count;
    projectile.entropy += config_.entropy_per_interaction *
            (1.0 + static_cast<double>(projectile.interaction_count - 1) * config_.entropy_interaction_acceleration);
    const double entropy_weight = uncertainty_weight(projectile.entropy) * std::max(0.0, sensitivity);
    if (entropy_weight <= 0.0) {
        return;
    }
    std::uniform_real_distribution<double> distribution(-1.0, 1.0);
    if (projectile.velocity.length_squared() > std::numeric_limits<double>::epsilon()) {
        const double angle = perturb_angle ?
                distribution(random_) * config_.max_angle_deviation_radians * entropy_weight : 0.0;
        const double speed_ratio = perturb_speed ?
                1.0 + distribution(random_) * config_.max_speed_deviation_ratio * entropy_weight : 1.0;
        projectile.velocity = rotate(projectile.velocity, angle) * std::max(0.0, speed_ratio);
    }
    if (perturb_mass) {
        const double mass_ratio =
                1.0 + distribution(random_) * config_.max_mass_deviation_ratio * entropy_weight;
        projectile.mass *= std::max(config_.momentum_zero_epsilon, mass_ratio);
    }
}

void MomentumWorld::retire_zero_momentum_entities() {
    projectiles_.erase(std::remove_if(projectiles_.begin(), projectiles_.end(), [this](const Projectile &projectile) {
        if (!is_zero_momentum(projectile)) {
            return false;
        }
        push_event(EventKind::ProjectileRetired, projectile.id, projectile.last_device_id, projectile.position);
        return true;
    }), projectiles_.end());
    wave_points_.erase(std::remove_if(wave_points_.begin(), wave_points_.end(), [this](const WavePoint &point) {
        if (!is_zero_momentum(point)) {
            return false;
        }
        push_event(EventKind::WavePointRetired, point.id, 0, point.position);
        return true;
    }), wave_points_.end());
}

std::vector<ProjectileSnapshot> MomentumWorld::projectile_snapshot() const {
    std::vector<ProjectileSnapshot> result;
    result.reserve(projectiles_.size());
    for (const Projectile &projectile : projectiles_) {
        result.push_back({projectile.id, projectile.position, projectile.velocity, projectile.mass, projectile.charge,
                projectile.entropy, projectile.interaction_count});
    }
    return result;
}

std::vector<WavePointSnapshot> MomentumWorld::wave_point_snapshot() const {
    std::vector<WavePointSnapshot> result;
    result.reserve(wave_points_.size());
    for (const WavePoint &point : wave_points_) {
        result.push_back({point.id, point.position, point.velocity, point.momentum});
    }
    return result;
}

std::vector<DeviceSnapshot> MomentumWorld::device_snapshot() const {
    std::vector<DeviceSnapshot> result;
    result.reserve(devices_.size());
    for (const Device &device : devices_) {
        result.push_back({device.id, device.spec.kind, device.spec.position, device.spec.angle_radians,
                device.spec.secondary_position, device.spec.secondary_angle_radians, device.activation_progress,
                device.spec.activation_required, device.stored_mass, device.stored_momentum,
                device.stored_wave_momentum, device.active});
    }
    return result;
}

std::vector<SimulationEvent> MomentumWorld::consume_events() {
    std::vector<SimulationEvent> result;
    result.swap(events_);
    return result;
}

const WaveStats &MomentumWorld::wave_stats() const {
    return wave_stats_;
}

const StepStats &MomentumWorld::step_stats() const {
    return step_stats_;
}

std::size_t MomentumWorld::projectile_count() const {
    return projectiles_.size();
}

std::size_t MomentumWorld::wave_point_count() const {
    return wave_points_.size();
}

std::size_t MomentumWorld::device_count() const {
    return devices_.size();
}

std::size_t MomentumWorld::enemy_proxy_count() const {
    return enemies_.size();
}

double MomentumWorld::uncertainty_weight(double entropy) const {
    if (!std::isfinite(entropy) || entropy <= config_.entropy_start) {
        return 0.0;
    }
    if (entropy >= config_.entropy_full_effect) {
        return 1.0;
    }
    const double normalized = (entropy - config_.entropy_start) /
            (config_.entropy_full_effect - config_.entropy_start);
    Vec2 previous = config_.entropy_curve.front();
    for (std::size_t index = 1; index < config_.entropy_curve.size(); ++index) {
        const Vec2 current = config_.entropy_curve[index];
        if (normalized <= current.x) {
            const double ratio = (normalized - previous.x) / std::max(1e-12, current.x - previous.x);
            return clamp(previous.y + (current.y - previous.y) * ratio, 0.0, 1.0);
        }
        previous = current;
    }
    return 1.0;
}

bool MomentumWorld::is_zero_momentum(const Projectile &projectile) const {
    return momentum_magnitude(projectile) <= config_.momentum_zero_epsilon;
}

bool MomentumWorld::is_zero_momentum(const WavePoint &point) const {
    return point.momentum <= config_.momentum_zero_epsilon;
}

double MomentumWorld::momentum_magnitude(const Projectile &projectile) const {
    return projectile.mass * projectile.velocity.length();
}

double MomentumWorld::segment_circle_hit_fraction(Vec2 from, Vec2 to, Vec2 center, double radius) const {
    const Vec2 offset = from - center;
    if (offset.length_squared() <= radius * radius) {
        return 0.0;
    }
    const Vec2 segment = to - from;
    const double a = segment.length_squared();
    if (a <= std::numeric_limits<double>::epsilon()) {
        return kNoHit;
    }
    const double b = 2.0 * dot(offset, segment);
    const double c = offset.length_squared() - radius * radius;
    const double discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) {
        return kNoHit;
    }
    const double root = std::sqrt(discriminant);
    const double first = (-b - root) / (2.0 * a);
    const double second = (-b + root) / (2.0 * a);
    if (first >= 0.0 && first <= 1.0) {
        return first;
    }
    if (second >= 0.0 && second <= 1.0) {
        return second;
    }
    return kNoHit;
}

double MomentumWorld::segment_plate_hit_fraction(
        const Projectile &projectile, Vec2 to, const Device &device) const {
    const Vec2 tangent = {std::cos(device.spec.angle_radians), std::sin(device.spec.angle_radians)};
    const Vec2 normal = {-tangent.y, tangent.x};
    const double from_distance = dot(projectile.position - device.spec.position, normal);
    const double to_distance = dot(to - device.spec.position, normal);
    const double denominator = from_distance - to_distance;
    if (std::abs(denominator) <= std::numeric_limits<double>::epsilon()) {
        return kNoHit;
    }
    const double fraction = from_distance / denominator;
    if (fraction < 0.0 || fraction > 1.0) {
        return kNoHit;
    }
    const Vec2 hit = projectile.position + (to - projectile.position) * fraction;
    if (std::abs(dot(hit - device.spec.position, tangent)) >
            device.spec.half_length + config_.projectile_radius) {
        return kNoHit;
    }
    return fraction;
}

void MomentumWorld::rebuild_spatial_index() {
    device_cells_.clear();
    device_query_marks_.assign(devices_.size(), 0);
    device_query_scratch_.clear();
    device_query_generation_ = 0;
    active_wave_converter_count_ = 0;
    for (std::size_t index = 0; index < devices_.size(); ++index) {
        const Device &device = devices_[index];
        if (device.active && device.spec.kind == DeviceKind::WaveConverter) {
            ++active_wave_converter_count_;
        }
        const double radius = device_index_radius(device);
        const std::int64_t min_x = static_cast<std::int64_t>(std::floor((device.spec.position.x - radius) /
                config_.spatial_cell_size));
        const std::int64_t max_x = static_cast<std::int64_t>(std::floor((device.spec.position.x + radius) /
                config_.spatial_cell_size));
        const std::int64_t min_y = static_cast<std::int64_t>(std::floor((device.spec.position.y - radius) /
                config_.spatial_cell_size));
        const std::int64_t max_y = static_cast<std::int64_t>(std::floor((device.spec.position.y + radius) /
                config_.spatial_cell_size));
        for (std::int64_t y = min_y; y <= max_y; ++y) {
            for (std::int64_t x = min_x; x <= max_x; ++x) {
                device_cells_[cell_key(x, y)].push_back(index);
            }
        }
    }
}

void MomentumWorld::rebuild_enemy_spatial_index() {
    enemy_cells_.clear();
    enemy_query_marks_.assign(enemies_.size(), 0);
    enemy_query_scratch_.clear();
    enemy_query_generation_ = 0;
    for (std::size_t index = 0; index < enemies_.size(); ++index) {
        const EnemyProxySpec &enemy = enemies_[index].spec;
        if (enemy.remaining_hp <= 0.0) {
            continue;
        }
        const double radius = enemy.radius + config_.projectile_radius;
        const std::int64_t min_x = static_cast<std::int64_t>(std::floor(
                (enemy.position.x - radius) / config_.enemy_spatial_cell_size));
        const std::int64_t max_x = static_cast<std::int64_t>(std::floor(
                (enemy.position.x + radius) / config_.enemy_spatial_cell_size));
        const std::int64_t min_y = static_cast<std::int64_t>(std::floor(
                (enemy.position.y - radius) / config_.enemy_spatial_cell_size));
        const std::int64_t max_y = static_cast<std::int64_t>(std::floor(
                (enemy.position.y + radius) / config_.enemy_spatial_cell_size));
        for (std::int64_t y = min_y; y <= max_y; ++y) {
            for (std::int64_t x = min_x; x <= max_x; ++x) {
                enemy_cells_[cell_key(x, y)].push_back(index);
            }
        }
    }
}

const std::vector<std::size_t> &MomentumWorld::query_device_indices(
        Vec2 from, Vec2 to, double expansion) const {
    const double min_world_x = std::min(from.x, to.x) - expansion;
    const double max_world_x = std::max(from.x, to.x) + expansion;
    const double min_world_y = std::min(from.y, to.y) - expansion;
    const double max_world_y = std::max(from.y, to.y) + expansion;
    const std::int64_t min_x = static_cast<std::int64_t>(std::floor(min_world_x / config_.spatial_cell_size));
    const std::int64_t max_x = static_cast<std::int64_t>(std::floor(max_world_x / config_.spatial_cell_size));
    const std::int64_t min_y = static_cast<std::int64_t>(std::floor(min_world_y / config_.spatial_cell_size));
    const std::int64_t max_y = static_cast<std::int64_t>(std::floor(max_world_y / config_.spatial_cell_size));
    if (device_query_generation_ == std::numeric_limits<std::uint64_t>::max()) {
        std::fill(device_query_marks_.begin(), device_query_marks_.end(), 0);
        device_query_generation_ = 1;
    } else {
        ++device_query_generation_;
    }
    device_query_scratch_.clear();
    for (std::int64_t y = min_y; y <= max_y; ++y) {
        for (std::int64_t x = min_x; x <= max_x; ++x) {
            const auto found = device_cells_.find(cell_key(x, y));
            if (found != device_cells_.end()) {
                for (const std::size_t index : found->second) {
                    if (device_query_marks_[index] == device_query_generation_) {
                        continue;
                    }
                    device_query_marks_[index] = device_query_generation_;
                    device_query_scratch_.push_back(index);
                }
            }
        }
    }
    std::sort(device_query_scratch_.begin(), device_query_scratch_.end(), [this](std::size_t left, std::size_t right) {
        return devices_[left].id < devices_[right].id;
    });
    return device_query_scratch_;
}

const std::vector<std::size_t> &MomentumWorld::query_enemy_indices(
        Vec2 from, Vec2 to, double expansion) const {
    const double min_world_x = std::min(from.x, to.x) - expansion;
    const double max_world_x = std::max(from.x, to.x) + expansion;
    const double min_world_y = std::min(from.y, to.y) - expansion;
    const double max_world_y = std::max(from.y, to.y) + expansion;
    const std::int64_t min_x = static_cast<std::int64_t>(std::floor(min_world_x / config_.enemy_spatial_cell_size));
    const std::int64_t max_x = static_cast<std::int64_t>(std::floor(max_world_x / config_.enemy_spatial_cell_size));
    const std::int64_t min_y = static_cast<std::int64_t>(std::floor(min_world_y / config_.enemy_spatial_cell_size));
    const std::int64_t max_y = static_cast<std::int64_t>(std::floor(max_world_y / config_.enemy_spatial_cell_size));
    if (enemy_query_generation_ == std::numeric_limits<std::uint64_t>::max()) {
        std::fill(enemy_query_marks_.begin(), enemy_query_marks_.end(), 0);
        enemy_query_generation_ = 1;
    } else {
        ++enemy_query_generation_;
    }
    enemy_query_scratch_.clear();
    for (std::int64_t y = min_y; y <= max_y; ++y) {
        for (std::int64_t x = min_x; x <= max_x; ++x) {
            const auto found = enemy_cells_.find(cell_key(x, y));
            if (found == enemy_cells_.end()) {
                continue;
            }
            for (const std::size_t index : found->second) {
                if (enemy_query_marks_[index] == enemy_query_generation_) {
                    continue;
                }
                enemy_query_marks_[index] = enemy_query_generation_;
                enemy_query_scratch_.push_back(index);
            }
        }
    }
    std::sort(enemy_query_scratch_.begin(), enemy_query_scratch_.end(), [this](std::size_t left, std::size_t right) {
        return enemies_[left].spec.id < enemies_[right].spec.id;
    });
    return enemy_query_scratch_;
}

double MomentumWorld::device_index_radius(const Device &device) const {
    double radius = device.spec.activation_radius + config_.projectile_radius;
    if (device.spec.kind == DeviceKind::BouncePlate) {
        radius = std::max(radius, device.spec.half_length + config_.projectile_radius);
    }
    if (device.spec.kind == DeviceKind::ElectricField || device.spec.kind == DeviceKind::MagneticField) {
        radius = std::max(radius, device.spec.field_radius + config_.projectile_radius);
    }
    return radius;
}

MomentumWorld::Device *MomentumWorld::find_device(std::uint64_t device_id) {
    const auto found = std::find_if(devices_.begin(), devices_.end(),
            [device_id](const Device &device) { return device.id == device_id; });
    return found == devices_.end() ? nullptr : &*found;
}

const MomentumWorld::Device *MomentumWorld::find_device(std::uint64_t device_id) const {
    const auto found = std::find_if(devices_.begin(), devices_.end(),
            [device_id](const Device &device) { return device.id == device_id; });
    return found == devices_.end() ? nullptr : &*found;
}

MomentumWorld::EnemyProxy *MomentumWorld::find_enemy(std::uint64_t enemy_id) {
    const auto found = std::find_if(enemies_.begin(), enemies_.end(),
            [enemy_id](const EnemyProxy &enemy) { return enemy.spec.id == enemy_id; });
    return found == enemies_.end() ? nullptr : &*found;
}

const MomentumWorld::EnemyProxy *MomentumWorld::find_enemy(std::uint64_t enemy_id) const {
    const auto found = std::find_if(enemies_.begin(), enemies_.end(),
            [enemy_id](const EnemyProxy &enemy) { return enemy.spec.id == enemy_id; });
    return found == enemies_.end() ? nullptr : &*found;
}

void MomentumWorld::push_event(EventKind kind, std::uint64_t entity_id, std::uint64_t device_id, Vec2 position,
        double value, double value2, double value3, double value4) {
    events_.push_back({kind, step_stats_.tick, entity_id, device_id, position, value, value2, value3, value4});
}

const char *event_kind_name(EventKind kind) {
    switch (kind) {
        case EventKind::MomentumAbsorbed: return "momentum_absorbed";
        case EventKind::DeviceActivated: return "device_activated";
        case EventKind::ProjectileReflected: return "projectile_reflected";
        case EventKind::ProjectileAccelerated: return "projectile_accelerated";
        case EventKind::ProjectileMassIncreased: return "projectile_mass_increased";
        case EventKind::ProjectileSplit: return "projectile_split";
        case EventKind::ProjectileTeleported: return "projectile_teleported";
        case EventKind::ProjectileCharged: return "projectile_charged";
        case EventKind::MagneticFieldEntered: return "magnetic_field_entered";
        case EventKind::MagneticFieldExited: return "magnetic_field_exited";
        case EventKind::Shockwave: return "shockwave";
        case EventKind::WaveEmitted: return "wave_emitted";
        case EventKind::WaveAbsorbed: return "wave_absorbed";
        case EventKind::WaveReconstructed: return "wave_reconstructed";
        case EventKind::AccumulatorStored: return "accumulator_stored";
        case EventKind::AccumulatorReleased: return "accumulator_released";
        case EventKind::DeviceRemoved: return "device_removed";
        case EventKind::TargetHit: return "target_hit";
        case EventKind::ProjectileRetired: return "projectile_retired";
        case EventKind::WavePointRetired: return "wave_point_retired";
        case EventKind::InteractionGuardTriggered: return "interaction_guard_triggered";
        case EventKind::EnemyHit: return "enemy_hit";
        case EventKind::EnemyDepleted: return "enemy_depleted";
    }
    return "unknown";
}

const char *device_kind_name(DeviceKind kind) {
    switch (kind) {
        case DeviceKind::BouncePlate: return "bounce_plate";
        case DeviceKind::SpeedIncreaser: return "speed_increaser";
        case DeviceKind::MassIncreaser: return "mass_increaser";
        case DeviceKind::Splitter: return "splitter";
        case DeviceKind::Diode: return "diode";
        case DeviceKind::ElectricField: return "electric_field";
        case DeviceKind::MagneticField: return "magnetic_field";
        case DeviceKind::WaveConverter: return "wave_converter";
        case DeviceKind::Accumulator: return "accumulator";
    }
    return "unknown";
}

} // namespace singular_tower

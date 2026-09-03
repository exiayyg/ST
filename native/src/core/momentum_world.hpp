#pragma once

#include <cstdint>
#include <random>
#include <unordered_map>
#include <vector>

namespace singular_tower {

struct Vec2 {
    double x = 0.0;
    double y = 0.0;

    Vec2 operator+(const Vec2 &other) const;
    Vec2 operator-(const Vec2 &other) const;
    Vec2 operator*(double scalar) const;
    Vec2 operator/(double scalar) const;
    Vec2 &operator+=(const Vec2 &other);
    Vec2 &operator*=(double scalar);
    double length_squared() const;
    double length() const;
    Vec2 normalized() const;
};

enum class DeviceKind {
    BouncePlate,
    SpeedIncreaser,
    MassIncreaser,
    Splitter,
    Diode,
    ElectricField,
    MagneticField,
    WaveConverter,
    Accumulator,
};

enum class EventKind {
    MomentumAbsorbed,
    DeviceActivated,
    ProjectileReflected,
    ProjectileAccelerated,
    ProjectileMassIncreased,
    ProjectileSplit,
    ProjectileTeleported,
    ProjectileCharged,
    MagneticFieldEntered,
    MagneticFieldExited,
    Shockwave,
    WaveEmitted,
    WaveAbsorbed,
    WaveReconstructed,
    AccumulatorStored,
    AccumulatorReleased,
    DeviceRemoved,
    TargetHit,
    ProjectileRetired,
    WavePointRetired,
    InteractionGuardTriggered,
    EnemyHit,
    EnemyDepleted,
};

struct SimulationConfig {
    double initial_projectile_momentum = 12.0;
    double initial_projectile_mass = 0.05;
    double initial_projectile_speed = 240.0;
    double momentum_zero_epsilon = 1e-9;
    double projectile_radius = 4.0;
    double wave_point_radius = 2.0;
    double entropy_per_second = 0.0;
    double entropy_per_interaction = 0.0;
    double entropy_interaction_acceleration = 0.0;
    double entropy_start = 50.0;
    double entropy_full_effect = 100.0;
    std::vector<Vec2> entropy_curve = {{0.0, 0.0}, {1.0, 1.0}};
    double max_angle_deviation_radians = 0.0;
    double max_speed_deviation_ratio = 0.0;
    double max_mass_deviation_ratio = 0.0;
    double max_diode_exit_offset = 0.0;
    double max_diode_angle_deviation_radians = 0.0;
    double max_split_direction_deviation_radians = 0.0;
    double max_split_share_deviation_ratio = 0.0;
    double spatial_cell_size = 160.0;
    double enemy_spatial_cell_size = 160.0;
    double entity_spawn_clearance = 1.0;
    std::uint32_t max_interactions_per_step = 16;
    std::uint64_t random_seed = 1;
};

struct DeviceSpec {
    DeviceKind kind = DeviceKind::BouncePlate;
    Vec2 position;
    double angle_radians = 0.0;
    Vec2 secondary_position;
    double secondary_angle_radians = 0.0;
    double activation_radius = 28.0;
    double activation_required = 30.0;
    double half_length = 48.0;
    double speed_multiplier = 1.55;
    double mass_multiplier = 1.55;
    double splitter_half_separation = 36.0;
    double field_radius = 120.0;
    double electric_acceleration = 90.0;
    double magnetic_angular_speed = 1.2;
    double shockwave_radius = 36.0;
    std::uint32_t wave_point_count = 48;
    double wave_fan_radians = 1.5707963267948966;
    double wave_speed = 360.0;
    double reconstruction_mass = 0.05;
    double reconstruction_speed = 240.0;
    double entropy_sensitivity = 1.0;
};

struct DiagnosticTargetSpec {
    Vec2 position;
    double radius = 24.0;
    double damage_per_momentum = 1.0;
    double momentum_absorption_fraction = 1.0;
};

struct EnemyProxySpec {
    std::uint64_t id = 0;
    Vec2 position;
    double radius = 16.0;
    double remaining_hp = 1.0;
    double momentum_absorption = 1.0;
    double damage_per_momentum = 1.0;
    double entropy_transfer_ratio = 0.0;
};

struct ProjectileSnapshot {
    std::uint64_t id = 0;
    Vec2 position;
    Vec2 velocity;
    double mass = 0.0;
    double charge = 0.0;
    double entropy = 0.0;
    std::uint32_t interaction_count = 0;
};

struct WavePointSnapshot {
    std::uint64_t id = 0;
    Vec2 position;
    Vec2 velocity;
    double momentum = 0.0;
};

struct DeviceSnapshot {
    std::uint64_t id = 0;
    DeviceKind kind = DeviceKind::BouncePlate;
    Vec2 position;
    double angle_radians = 0.0;
    Vec2 secondary_position;
    double secondary_angle_radians = 0.0;
    double activation_progress = 0.0;
    double activation_required = 0.0;
    double stored_mass = 0.0;
    double stored_momentum = 0.0;
    double stored_wave_momentum = 0.0;
    bool active = false;
};

struct SimulationEvent {
    EventKind kind = EventKind::MomentumAbsorbed;
    std::uint64_t tick = 0;
    std::uint64_t entity_id = 0;
    std::uint64_t device_id = 0;
    Vec2 position;
    double value = 0.0;
    double value2 = 0.0;
    double value3 = 0.0;
    double value4 = 0.0;
};

struct WaveStats {
    double tower_source_momentum = 0.0;
    double damage_dealt = 0.0;

    double utilization() const;
};

struct StepStats {
    std::uint64_t tick = 0;
    std::uint64_t candidate_checks = 0;
    std::uint64_t interactions = 0;
    std::uint64_t enemy_candidate_checks = 0;
    std::uint64_t enemy_hits = 0;
    double last_step_milliseconds = 0.0;
};

class MomentumWorld {
public:
    explicit MomentumWorld(const SimulationConfig &config = {});

    void configure(const SimulationConfig &config);
    void clear();
    void reset_wave_stats();

    std::uint64_t emit_projectile(Vec2 position, Vec2 velocity, double mass, bool tower_source = true,
            double entropy = 0.0, double charge = 0.0);
    std::uint64_t add_device(const DeviceSpec &spec);
    bool remove_device(std::uint64_t device_id);
    bool set_device_transform(std::uint64_t device_id, Vec2 position, double angle_radians);
    bool set_device_anchor_transform(
            std::uint64_t device_id, std::uint32_t anchor_index, Vec2 position, double angle_radians);
    bool release_accumulator(std::uint64_t device_id);
    std::uint64_t add_diagnostic_target(const DiagnosticTargetSpec &spec);
    bool sync_enemy_proxies(const std::vector<EnemyProxySpec> &specs);
    void clear_enemy_proxies();

    void step(double fixed_delta_seconds);

    std::vector<ProjectileSnapshot> projectile_snapshot() const;
    std::vector<WavePointSnapshot> wave_point_snapshot() const;
    std::vector<DeviceSnapshot> device_snapshot() const;
    std::vector<SimulationEvent> consume_events();
    const WaveStats &wave_stats() const;
    const StepStats &step_stats() const;
    std::size_t projectile_count() const;
    std::size_t wave_point_count() const;
    std::size_t device_count() const;
    std::size_t enemy_proxy_count() const;
    double uncertainty_weight(double entropy) const;

private:
    struct Projectile {
        std::uint64_t id = 0;
        Vec2 position;
        Vec2 previous_position;
        Vec2 velocity;
        double mass = 0.0;
        double charge = 0.0;
        double entropy = 0.0;
        std::uint32_t interaction_count = 0;
        std::uint64_t last_device_id = 0;
        std::uint64_t last_target_id = 0;
        std::uint64_t last_enemy_id = 0;
        std::vector<std::uint64_t> field_memberships;
    };

    struct WavePoint {
        std::uint64_t id = 0;
        Vec2 position;
        Vec2 previous_position;
        Vec2 velocity;
        double momentum = 0.0;
        std::uint64_t source_device_id = 0;
        bool ignores_source = true;
    };

    struct Device {
        std::uint64_t id = 0;
        DeviceSpec spec;
        double activation_progress = 0.0;
        double stored_mass = 0.0;
        double stored_momentum = 0.0;
        double stored_wave_momentum = 0.0;
        bool active = false;
    };

    struct DiagnosticTarget {
        std::uint64_t id = 0;
        DiagnosticTargetSpec spec;
    };

    struct EnemyProxy {
        EnemyProxySpec spec;
    };

    SimulationConfig config_;
    WaveStats wave_stats_;
    StepStats step_stats_;
    std::vector<Projectile> projectiles_;
    std::vector<WavePoint> wave_points_;
    std::vector<Projectile> pending_projectiles_;
    std::vector<WavePoint> pending_wave_points_;
    std::vector<Device> devices_;
    std::vector<DiagnosticTarget> targets_;
    std::vector<EnemyProxy> enemies_;
    std::vector<SimulationEvent> events_;
    std::unordered_map<std::int64_t, std::vector<std::size_t>> device_cells_;
    mutable std::vector<std::uint64_t> device_query_marks_;
    mutable std::vector<std::size_t> device_query_scratch_;
    mutable std::uint64_t device_query_generation_ = 0;
    std::unordered_map<std::int64_t, std::vector<std::size_t>> enemy_cells_;
    mutable std::vector<std::uint64_t> enemy_query_marks_;
    mutable std::vector<std::size_t> enemy_query_scratch_;
    mutable std::uint64_t enemy_query_generation_ = 0;
    std::mt19937_64 random_;
    std::size_t active_wave_converter_count_ = 0;
    std::uint64_t next_projectile_id_ = 1;
    std::uint64_t next_wave_point_id_ = 1;
    std::uint64_t next_device_id_ = 1;
    std::uint64_t next_target_id_ = 1;

    bool is_zero_momentum(const Projectile &projectile) const;
    bool is_zero_momentum(const WavePoint &point) const;
    double momentum_magnitude(const Projectile &projectile) const;
    double segment_circle_hit_fraction(Vec2 from, Vec2 to, Vec2 center, double radius) const;
    double segment_plate_hit_fraction(const Projectile &projectile, Vec2 to, const Device &device) const;
    void apply_entropy_interaction(Projectile &projectile, double sensitivity = 1.0,
            bool perturb_angle = true, bool perturb_speed = true, bool perturb_mass = false);
    void apply_active_fields(Projectile &projectile, double fixed_delta_seconds);
    bool apply_device_interaction(Projectile &projectile, Device &device, Vec2 hit_position);
    void emit_split_projectiles(const Projectile &source, const Device &device);
    void emit_wave_points(const Projectile &source, const Device &device);
    void reconstruct_wave_projectiles(Device &device);
    void process_projectile(Projectile &projectile, double fixed_delta_seconds);
    void process_wave_point(WavePoint &point, double fixed_delta_seconds);
    void retire_zero_momentum_entities();
    void rebuild_spatial_index();
    void rebuild_enemy_spatial_index();
    const std::vector<std::size_t> &query_device_indices(Vec2 from, Vec2 to, double expansion) const;
    double device_index_radius(const Device &device) const;
    const std::vector<std::size_t> &query_enemy_indices(Vec2 from, Vec2 to, double expansion) const;
    Device *find_device(std::uint64_t device_id);
    const Device *find_device(std::uint64_t device_id) const;
    EnemyProxy *find_enemy(std::uint64_t enemy_id);
    const EnemyProxy *find_enemy(std::uint64_t enemy_id) const;
    void push_event(EventKind kind, std::uint64_t entity_id, std::uint64_t device_id, Vec2 position,
            double value = 0.0, double value2 = 0.0, double value3 = 0.0, double value4 = 0.0);
};

const char *event_kind_name(EventKind kind);
const char *device_kind_name(DeviceKind kind);

} // namespace singular_tower

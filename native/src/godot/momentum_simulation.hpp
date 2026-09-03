#pragma once

#include "core/momentum_world.hpp"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2i.hpp>

namespace godot {

class MomentumSimulation : public RefCounted {
    GDCLASS(MomentumSimulation, RefCounted)

public:
    MomentumSimulation();

    bool configure(const Dictionary &config);
    void clear();
    void reset_wave_stats();

    PackedInt64Array emit_projectiles(const Array &commands);
    std::int64_t add_device(const Dictionary &spec);
    bool remove_device(std::int64_t device_id);
    bool set_device_transform(std::int64_t device_id, Vector2 position, double angle_radians);
    bool set_device_anchor_transform(
            std::int64_t device_id, std::int32_t anchor_index, Vector2 position, double angle_radians);
    bool release_accumulator(std::int64_t device_id);
    std::int64_t add_diagnostic_target(const Dictionary &spec);
    bool sync_enemy_proxies(const Dictionary &snapshot);
    void clear_enemy_proxies();

    void step(double frame_delta_seconds);

    Dictionary get_projectile_snapshot() const;
    Dictionary get_wave_point_snapshot() const;
    Dictionary get_render_snapshot(Rect2 view_rect, double margin = 96.0) const;
    PackedByteArray build_visibility_mask(
            const Array &sources, Rect2 map_rect, Vector2i grid_size, double edge_softness) const;
    Array get_device_snapshot() const;
    Array consume_events();
    Dictionary get_stats() const;

protected:
    static void _bind_methods();

private:
    struct RenderColor {
        float r;
        float g;
        float b;
        float a;
    };

    singular_tower::MomentumWorld world_;
    double fixed_step_seconds_ = 1.0 / 120.0;
    double accumulator_seconds_ = 0.0;
    std::int32_t max_substeps_ = 16;
    double entropy_visual_start_ = 0.0;
    double entropy_visual_full_ = 100.0;
    double projectile_base_diameter_ = 8.0;
    double projectile_entropy_extra_diameter_ = 8.0;
    double wave_point_diameter_ = 5.0;
    RenderColor projectile_low_entropy_color_{0.47451f, 0.84314f, 1.0f, 1.0f};
    RenderColor projectile_high_entropy_color_{1.0f, 0.46275f, 0.37255f, 1.0f};
    RenderColor projectile_charged_color_{1.0f, 0.89020f, 0.41961f, 1.0f};
    RenderColor wave_point_color_{0.39608f, 0.95686f, 1.0f, 1.0f};
    double projectile_charge_blend_ratio_ = 0.45;
};

} // namespace godot

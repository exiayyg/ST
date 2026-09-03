#include "core/momentum_world.hpp"

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <random>
#include <vector>

using namespace singular_tower;

namespace {

void activate_converter(MomentumWorld &world, const DeviceSpec &spec) {
    for (int shot = 0; shot < 2; ++shot) {
        world.emit_projectile(spec.position, {240.0, 0.0}, 0.05, false);
        world.step(1.0 / 120.0);
    }
}

double percentile(std::vector<double> values, double ratio) {
    std::sort(values.begin(), values.end());
    const std::size_t index = static_cast<std::size_t>(ratio * static_cast<double>(values.size() - 1));
    return values[index];
}

} // namespace

int main(int argc, char **argv) {
    const int projectile_target = argc > 1 ? std::max(0, std::atoi(argv[1])) : 10000;
    const int wave_target = argc > 2 ? std::max(0, std::atoi(argv[2])) : 50000;
    const int device_target = argc > 3 ? std::max(0, std::atoi(argv[3])) : 100;
    const int enemy_target = argc > 4 ? std::max(0, std::atoi(argv[4])) : 300;
    const int sample_count = argc > 5 ? std::max(1, std::atoi(argv[5])) : 120;
    SimulationConfig config;
    config.initial_projectile_momentum = 12.0;
    config.initial_projectile_mass = 0.05;
    config.initial_projectile_speed = 240.0;
    config.entropy_per_second = 0.018;
    config.entropy_per_interaction = 0.12;
    config.spatial_cell_size = 160.0;
    config.random_seed = 20260901;
    MomentumWorld world(config);

    DeviceSpec converter;
    converter.kind = DeviceKind::WaveConverter;
    converter.position = {0.0, 0.0};
    converter.activation_required = 24.0;
    converter.wave_point_count = 48;
    converter.wave_fan_radians = 1.5707963267948966;
    converter.wave_speed = 360.0;
    const auto converter_id = world.add_device(converter);
    activate_converter(world, converter);
    const int converter_projectiles = (wave_target + static_cast<int>(converter.wave_point_count) - 1) /
            static_cast<int>(converter.wave_point_count);
    for (int index = 0; index < converter_projectiles; ++index) {
        world.emit_projectile({0.0, 0.0}, {240.0, 0.0}, 0.05, false);
    }
    world.step(1.0 / 120.0);
    world.remove_device(converter_id);

    const int column_count = 20;
    const int row_count = std::max(1, (device_target + column_count - 1) / column_count);
    for (int index = 0; index < device_target; ++index) {
        DeviceSpec device;
        device.kind = static_cast<DeviceKind>(index % 9);
        device.position = {-2100.0 + static_cast<double>(index % 20) * 220.0,
                -static_cast<double>(row_count - 1) * 115.0 +
                        static_cast<double>(index / column_count) * 230.0};
        device.secondary_position = device.position + Vec2{80.0, 80.0};
        device.activation_required = 30.0 + static_cast<double>(index % 5) * 12.0;
        world.add_device(device);
    }

    std::mt19937_64 random(20260901);
    std::uniform_real_distribution<double> x_distribution(-2200.0, 2200.0);
    std::uniform_real_distribution<double> y_distribution(-1200.0, 1200.0);
    std::uniform_real_distribution<double> angle_distribution(0.0, 6.283185307179586);
    for (int index = 0; index < projectile_target; ++index) {
        const double angle = angle_distribution(random);
        world.emit_projectile({x_distribution(random), y_distribution(random)},
                {std::cos(angle) * 240.0, std::sin(angle) * 240.0}, 0.05, false);
    }

    std::vector<EnemyProxySpec> enemies;
    enemies.reserve(static_cast<std::size_t>(enemy_target));
    for (int index = 0; index < enemy_target; ++index) {
        enemies.push_back({static_cast<std::uint64_t>(index + 1),
                {x_distribution(random), y_distribution(random)}, 18.0, 1000000.0,
                0.25, 1.0, 0.5});
    }
    if (!world.sync_enemy_proxies(enemies)) {
        std::cerr << "failed to install enemy benchmark proxies\n";
        return 2;
    }

    std::vector<double> samples;
    samples.reserve(static_cast<std::size_t>(sample_count));
    for (int step = 0; step < sample_count; ++step) {
        const auto started = std::chrono::steady_clock::now();
        world.step(1.0 / 120.0);
        const auto finished = std::chrono::steady_clock::now();
        samples.push_back(std::chrono::duration<double, std::milli>(finished - started).count());
    }

    const double maximum = *std::max_element(samples.begin(), samples.end());
    std::cout << std::fixed << std::setprecision(3)
              << "seed=20260901 projectiles=" << world.projectile_count()
              << " wave_points=" << world.wave_point_count()
              << " devices=" << device_target
              << " enemies=" << world.enemy_proxy_count()
              << " samples=" << sample_count
              << " p50_ms=" << percentile(samples, 0.50)
              << " p95_ms=" << percentile(samples, 0.95)
              << " max_ms=" << maximum
              << " candidate_checks=" << world.step_stats().candidate_checks
              << " enemy_candidate_checks=" << world.step_stats().enemy_candidate_checks
              << " enemy_hits=" << world.step_stats().enemy_hits << '\n';
    return 0;
}

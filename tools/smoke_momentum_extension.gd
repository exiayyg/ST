extends SceneTree


func _init() -> void:
	if not ClassDB.class_exists(&"MomentumSimulation"):
		push_error("MomentumSimulation was not registered by the GDExtension")
		quit(1)
		return

	var simulation := MomentumSimulation.new()
	if not simulation.configure({
		"fixed_step_seconds": 1.0 / 120.0,
		"initial_projectile_momentum": 10.0,
		"initial_projectile_mass": 1.0,
		"initial_projectile_speed": 10.0,
		"random_seed": 42,
	}):
		quit(2)
		return

	var ids: PackedInt64Array = simulation.emit_projectiles([{
		"position": Vector2.ZERO,
		"velocity": Vector2(100.0, 0.0),
		"mass": 0.1,
		"tower_source": true,
	}])
	simulation.step(1.0 / 60.0)
	var kinds := [
		"bounce_plate", "speed_increaser", "mass_increaser", "splitter", "diode",
		"electric_field", "magnetic_field", "wave_converter", "accumulator",
	]
	var device_ids: Array[int] = []
	for index in kinds.size():
		var device_id := simulation.add_device({
			"type": kinds[index],
			"position": Vector2(100.0 + index * 20.0, 0.0),
			"secondary_position": Vector2(100.0 + index * 20.0, 40.0),
			"activation_required": 20.0,
		})
		if device_id <= 0:
			push_error("Could not add device kind: %s" % kinds[index])
			quit(4)
			return
		device_ids.append(device_id)

	var snapshot: Dictionary = simulation.get_projectile_snapshot()
	var positions: PackedVector2Array = snapshot["positions"]
	if ids.size() != 1 or positions.size() != 1 or positions[0].x <= 0.0:
		push_error("MomentumSimulation failed its Godot smoke test")
		quit(3)
		return
	if simulation.get_device_snapshot().size() != 9:
		push_error("MomentumSimulation did not expose all nine device kinds")
		quit(5)
		return
	if not simulation.set_device_anchor_transform(device_ids[4], 1, Vector2(200.0, 50.0), 0.5):
		push_error("Diode anchor API failed")
		quit(6)
		return
	var render_snapshot: Dictionary = simulation.get_render_snapshot(
		Rect2(-100.0, -100.0, 400.0, 200.0), 0.0
	)
	var projectile_buffer: PackedFloat32Array = render_snapshot.get(
		"projectile_multimesh_buffer", PackedFloat32Array()
	)
	var visibility: PackedByteArray = simulation.build_visibility_mask(
		[{"position": Vector2.ZERO, "radius": 40.0}],
		Rect2(-80.0, -45.0, 160.0, 90.0), Vector2i(16, 9), 10.0
	)
	if not render_snapshot.has("wave_multimesh_buffer") or projectile_buffer.size() != 12 or \
			visibility.size() != 16 * 9 * 4 or not simulation.remove_device(device_ids[0]):
		push_error("Render snapshot or remove_device API failed")
		quit(7)
		return

	var enemy_simulation := MomentumSimulation.new()
	if not enemy_simulation.configure({
		"fixed_step_seconds": 1.0 / 120.0,
		"initial_projectile_momentum": 20.0,
		"initial_projectile_mass": 0.02,
		"initial_projectile_speed": 1000.0,
		"projectile_radius": 0.5,
		"entropy_start": 50.0,
		"entropy_full_effect": 100.0,
		"entropy_curve": [{"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 1.0}],
	}):
		quit(8)
		return
	var proxy_batch := {
		"ids": PackedInt64Array([7]),
		"positions": PackedVector2Array([Vector2(5.0, 0.0)]),
		"radii": PackedFloat32Array([1.0]),
		"remaining_hp": PackedFloat32Array([10.0]),
		"momentum_absorption": PackedFloat32Array([0.5]),
		"damage_per_momentum": PackedFloat32Array([1.0]),
		"entropy_transfer_ratio": PackedFloat32Array([0.25]),
	}
	if not enemy_simulation.sync_enemy_proxies(proxy_batch):
		quit(9)
		return
	enemy_simulation.emit_projectiles([{
		"position": Vector2.ZERO, "velocity": Vector2(1000.0, 0.0),
		"mass": 0.02, "entropy": 60.0,
	}])
	enemy_simulation.step(1.0 / 120.0)
	var enemy_events: Array = enemy_simulation.consume_events()
	var hit := enemy_events.filter(func(event: Dictionary): return event.get("type") == "enemy_hit")
	var enemy_stats: Dictionary = enemy_simulation.get_stats()
	var invalid_proxy_batch := proxy_batch.duplicate(true)
	invalid_proxy_batch.positions = PackedVector2Array()
	if hit.size() != 1 or not is_equal_approx(float(hit[0].damage), 10.0) or \
			not is_equal_approx(float(hit[0].momentum_transferred), 10.0) or \
			not is_equal_approx(float(hit[0].source_entropy), 60.0) or \
			not is_equal_approx(float(hit[0].entropy_transferred), 15.0) or \
			enemy_simulation.sync_enemy_proxies(invalid_proxy_batch) or int(enemy_stats.enemy_proxy_count) != 1:
		push_error("Enemy proxy GDExtension boundary failed")
		quit(10)
		return

	print("MomentumSimulation smoke test passed: nine devices, MultiMesh buffers, native fog, mutable anchors, atomic enemy proxies")
	quit()

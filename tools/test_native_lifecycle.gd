extends SceneTree

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")
const SimulationControllerType := preload("res://scripts/prototype/simulation_controller.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var native := MomentumSimulation.new()
	if OS.get_cmdline_user_args().has("instantiate-only"):
		native = null
		await process_frame
		print("Native instantiate-only lifecycle passed")
		quit()
		return
	var profile := BalanceRepositoryType.load_profile()
	if profile == null:
		quit(2)
		return
	var simulation := SimulationControllerType.new(profile) as SimulationController
	simulation.native = native
	if not simulation.initialize():
		push_error("Native lifecycle regression: configure failed")
		quit(3)
		return
	simulation.native = null
	simulation = null
	await process_frame
	print("Native lifecycle regression passed")
	quit()

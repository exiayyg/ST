extends Node

const BalanceRepositoryType := preload("res://scripts/config/balance_repository.gd")
const SimulationControllerType := preload("res://scripts/prototype/simulation_controller.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var native := MomentumSimulation.new()
	if OS.get_cmdline_user_args().has("instantiate-only"):
		native = null
		await get_tree().process_frame
		print("Native instantiate-only lifecycle passed")
		get_tree().quit()
		return
	var profile := BalanceRepositoryType.load_profile()
	if profile == null:
		get_tree().quit(2)
		return
	var simulation := SimulationControllerType.new(profile) as SimulationController
	simulation.native = native
	if not simulation.initialize():
		push_error("Native lifecycle regression: configure failed")
		get_tree().quit(3)
		return
	simulation.native = null
	simulation = null
	await get_tree().process_frame
	print("Native lifecycle regression passed")
	get_tree().quit()

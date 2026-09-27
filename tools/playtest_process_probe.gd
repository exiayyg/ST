extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var campaign := root.get_node("_campaign_service") as CampaignService
	if "--recover-only" in OS.get_cmdline_user_args():
		print("PLAYTEST_RECOVERY_COMPLETE")
		quit()
		return
	if campaign.launch_playtest(&"diode_tutorial", true) != OK:
		quit(1)
		return
	await scene_changed
	await create_timer(0.1).timeout
	print("PLAYTEST_DIRECTORY=", ProjectSettings.globalize_path("user://playtests"))
	print("PLAYTEST_PROCESS_READY")
	if "--abrupt" not in OS.get_cmdline_user_args():
		quit()

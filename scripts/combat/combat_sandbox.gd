extends "res://scripts/runtime/world_screen.gd"

@export_enum("single_wave", "endless", "tutorial_diode") var session_mode := "single_wave"

func session_kind() -> StringName:
	return StringName(session_mode)

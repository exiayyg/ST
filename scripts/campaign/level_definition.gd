class_name LevelDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export_file("*.tscn") var scene_path := ""
@export_enum("tutorial_diode", "single_wave", "endless") var session_kind := "tutorial_diode"
@export var balance_key := ""
@export var sort_order := 0
@export var prerequisites: Array[StringName] = []
@export var release_visible := true


func snapshot() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"scene_path": scene_path,
		"session_kind": StringName(session_kind),
		"balance_key": balance_key,
		"sort_order": sort_order,
		"prerequisites": prerequisites.duplicate(),
		"release_visible": release_visible,
	}

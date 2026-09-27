class_name PlaytestRecorder
extends RefCounted

## Read-only observer. Never retains a world reference or raw input/entity trajectories.
signal recording_failed(message: String)

const RECORD_VERSION := 1
const BUILD_ID := "v0.5.1-worktree-80c90e2"
const ACTION_TYPES := ["device_placed", "device_dismantled", "device_moved", "device_rotated", "interaction_cancelled", "invalid_placement"]
const FIRST_TYPES := ["device_placed", "device_activated", "projectile_teleported", "enemy_hit"]
static var _live_runs: Dictionary = {}
var _enabled := false
var _finished := false
var _failed := false
var _journal: FileAccess
var _directory := ""
var _summary: Dictionary = {}
var _sample_interval: float
var _flush_interval: float
var _sample_elapsed := 0.0
var _flush_elapsed := 0.0
var _elapsed := 0.0
var _paused := 0.0
var _stage := ""
var _last_frame: Dictionary = {}

func begin(authorized: bool, metadata: Dictionary, config: RuntimeBalance.Playtest,
		base_directory := "user://playtests") -> bool:
	if _enabled or _finished:
		return false
	if not authorized:
		return true
	_enabled = true
	_sample_interval = config.sample_interval_seconds
	_flush_interval = config.flush_interval_seconds
	recover_interrupted(base_directory)
	var run_id := "%s-%s" % [str(Time.get_unix_time_from_system()).replace(".", "-"), Time.get_ticks_usec()]
	_directory = base_directory.path_join(run_id)
	_summary = {"record_version": RECORD_VERSION, "build_id": BUILD_ID, "run_id": run_id,
		"process_id": OS.get_process_id(),
		"metadata": metadata.duplicate(true), "finished": false, "reason": "", "elapsed_seconds": 0.0,
		"paused_seconds": 0.0, "first_events": {}, "actions": {}, "waves": {}, "feedback": {}}
	var ancestor := _directory
	while not ancestor.is_empty() and not ancestor.ends_with("://"):
		if FileAccess.file_exists(ancestor):
			return _fail()
		var parent := ancestor.get_base_dir()
		if parent == ancestor:
			break
		ancestor = parent
	if DirAccess.make_dir_recursive_absolute(_directory) != OK:
		return _fail()
	_journal = FileAccess.open(_directory.path_join("events.jsonl"), FileAccess.WRITE)
	if _journal == null:
		return _fail()
	_append({"type": "begin", "metadata": metadata})
	_live_runs[_directory] = weakref(self)
	_checkpoint()
	return not _failed

func ingest_event(event: Dictionary) -> void:
	if not is_recording():
		return
	var type := String(event.get("type", ""))
	if type == "enemy_hit" and float(event.get("damage", 0.0)) <= 0.0:
		return
	if FIRST_TYPES.has(type) and not _summary.first_events.has(type):
		_summary.first_events[type] = _elapsed
		_append({"type": "first_" + type})
	if ACTION_TYPES.has(type):
		_summary.actions[type] = int(_summary.actions.get(type, 0)) + 1
		# Stable device IDs are semantic objects, not raw input or projectile IDs.
		_append({"type": type, "device_id": int(event.get("device_id", 0)),
			"anchor_index": int(event.get("anchor_index", 0))})
	if type == "device_destroyed":
		_summary["device_losses"] = int(_summary.get("device_losses", 0)) + 1
		_append({"type": type, "device_id": int(event.get("device_id", 0))})

func observe_frame(delta: float, frame: Dictionary, paused := false) -> void:
	if not is_recording() or not is_finite(delta) or delta < 0.0:
		return
	if paused:
		_paused += delta
	else:
		_elapsed += delta
		_last_frame = frame.duplicate(true)
		var stage := String(frame.get("tutorial_phase", ""))
		if stage != _stage:
			_stage = stage
			_append({"type": "stage", "stage": stage})
		var wave := str(frame.get("wave_index", 0))
		if int(frame.get("wave_index", 0)) > 0 and String(frame.get("phase", "active")) != "intermission":
			var previous: Dictionary = _summary.waves.get(wave, {})
			var wave_frame := frame.duplicate(true)
			var initial_losses := int(previous.get("initial_device_losses", frame.get("device_losses", 0)))
			wave_frame["initial_device_losses"] = initial_losses
			wave_frame["wave_device_losses"] = int(frame.get("device_losses", 0)) - initial_losses
			wave_frame["peak_enemy_count"] = maxi(int(previous.get("peak_enemy_count", 0)), int(frame.get("enemy_count", 0)))
			wave_frame["wave_maximum_no_damage_seconds"] = maxf(float(previous.get("wave_maximum_no_damage_seconds", 0.0)), float(frame.get("no_damage_seconds", 0.0)))
			_summary.waves[wave] = wave_frame
		_sample_elapsed += delta
		if _sample_elapsed >= _sample_interval:
			_sample_elapsed = fmod(_sample_elapsed, _sample_interval)
			_append({"type": "sample", "frame": frame})
	_flush_elapsed += delta
	if _flush_elapsed >= _flush_interval:
		_flush_elapsed = fmod(_flush_elapsed, _flush_interval)
		_checkpoint()

func finish(reason: String, completion: Dictionary = {}) -> void:
	if not _enabled or _finished:
		return
	_finished = true
	_live_runs.erase(_directory)
	_summary["finished"] = true
	_summary["reason"] = reason
	_summary["completion"] = completion.duplicate(true)
	_append({"type": "finish", "reason": reason, "completion": completion})
	_checkpoint()
	if _journal != null:
		_journal.close()
		_journal = null

func submit_feedback(feedback: Dictionary) -> bool:
	if not _enabled or not _finished or _failed:
		return false
	var accepted := {}
	for field in ["stuck", "unclear", "other"]:
		if feedback.get(field, "") is not String:
			return false
		accepted[field] = feedback.get(field, "")
	_summary["feedback"] = accepted
	return _checkpoint()

func is_recording() -> bool:
	return _enabled and not _finished and not _failed

func report_directory() -> String:
	return _directory if _enabled and not _failed else ""

func snapshot() -> Dictionary:
	return _summary.duplicate(true)

func _append(event: Dictionary) -> void:
	if _failed or _journal == null:
		return
	var safe := event.duplicate(true)
	safe["elapsed_seconds"] = _elapsed
	_journal.store_line(JSON.stringify(safe, "", true))
	if _journal.get_error() != OK:
		_fail()

func _checkpoint() -> bool:
	if _failed:
		return false
	_summary["elapsed_seconds"] = _elapsed
	_summary["paused_seconds"] = _paused
	_summary["last_frame"] = _last_frame.duplicate(true)
	if _journal != null:
		_journal.flush()
		if _journal.get_error() != OK:
			return _fail()
	if not _save_summary(_directory, _summary):
		return _fail()
	return true

func _fail() -> bool:
	if not _failed:
		_failed = true
		recording_failed.emit("试玩记录失败；游戏仍可继续，正式成绩不受影响。")
	return false

static func _save_summary(directory: String, summary: Dictionary) -> bool:
	var path := directory.path_join("summary.json")
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(summary, "\t", true, true) + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	var verification = JSON.parse_string(FileAccess.get_file_as_string(temporary))
	if verification is not Dictionary or verification != JSON.parse_string(JSON.stringify(summary, "", true, true)):
		return false
	return DirAccess.rename_absolute(temporary, path) == OK

static func recover_interrupted(base_directory: String) -> void:
	if not DirAccess.dir_exists_absolute(base_directory):
		return
	for name in DirAccess.get_directories_at(base_directory):
		var directory := base_directory.path_join(name)
		var path := directory.path_join("summary.json")
		if not FileAccess.file_exists(path):
			continue
		var summary = JSON.parse_string(FileAccess.get_file_as_string(path))
		if summary is not Dictionary or summary.get("record_version") != RECORD_VERSION or summary.get("finished", true):
			continue
		var process_id := int(summary.get("process_id", 0))
		if process_id != OS.get_process_id() and process_id > 0 and OS.is_process_running(process_id):
			continue
		if _live_runs.has(directory) and (_live_runs[directory] as WeakRef).get_ref() != null:
			continue
		_live_runs.erase(directory)
		# Preserve the journal verbatim, including a possibly truncated final line.
		summary["finished"] = true
		summary["reason"] = "interrupted"
		_save_summary(directory, summary)

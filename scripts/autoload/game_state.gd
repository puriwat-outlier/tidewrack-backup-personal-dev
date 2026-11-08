extends Node
## GameState — global save/load and story flags.
##
## Autoloaded as `GameState`. Holds the narrative flags set by dialogue
## choices and journal discoveries, and persists them to user://save.json so "Continue" works.

signal state_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const DEFAULT_SCENE := "res://scenes/game.tscn"

## Story flags set during play, e.g. {"trusted_edith": true}.
var flags: Dictionary = {}
## Path of the scene the player should resume into.
var current_scene: String = DEFAULT_SCENE


func set_flag(name: String, value: Variant) -> void:
	flags[name] = value
	state_changed.emit()


func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


func new_game() -> void:
	flags.clear()
	current_scene = DEFAULT_SCENE
	Journal.clear()
	state_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags,
		"journal_entries": Journal.entries(),
	}
	var temporary_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return false
	var replace_error := DirAccess.rename_absolute(temporary_path, SAVE_PATH)
	if replace_error != OK:
		push_error("GameState: could not replace save file.")
		DirAccess.remove_absolute(temporary_path)
		return false
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: could not open save file for reading.")
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameState: save file is corrupt.")
		return false

	var data: Dictionary = parsed
	# Validate everything before committing any live state. Unversioned saves
	# use the v1 shape. Future versions must not be silently downgraded.
	var version: Variant = data.get("version", 1)
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or (version != 1 and version != SAVE_VERSION):
		return false
	var loaded_scene: Variant = data.get("scene", DEFAULT_SCENE)
	if typeof(loaded_scene) != TYPE_STRING or loaded_scene not in [DEFAULT_SCENE, "res://scenes/lamp_room.tscn"]:
		return false
	var loaded_flags: Variant = data.get("flags", {})
	if typeof(loaded_flags) != TYPE_DICTIONARY:
		return false
	var loaded_entries: Variant = data.get("journal_entries", []) if version == SAVE_VERSION else []
	if typeof(loaded_entries) != TYPE_ARRAY:
		return false
	for id in loaded_entries:
		if typeof(id) != TYPE_STRING or id.strip_edges().is_empty():
			return false

	current_scene = loaded_scene
	flags = loaded_flags.duplicate(true)
	# Replacement clears stale entries; restoration never emits discovery events.
	Journal.restore(loaded_entries)
	state_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

extends Node

var failures := 0
var discoveries := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func write_payload(payload: Variant) -> void:
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()

func _ready() -> void:
	# Separate engine processes prove this is disk state, not retained autoloads.
	if "--write-cycle" in OS.get_cmdline_user_args():
		GameState.new_game()
		Journal.discover("keeper_log")
		GameState.set_flag("trusted_edith", false)
		check(GameState.save_game(), "cold-cycle save")
		get_tree().quit(failures)
		return
	if "--read-cycle" in OS.get_cmdline_user_args():
		check(GameState.load_game(), "cold-cycle load")
		check(Journal.entries() == ["keeper_log"] and GameState.flags.has("trusted_edith") and GameState.get_flag("trusted_edith") == false, "cold-cycle restored journal and false flag")
		GameState.delete_save()
		print("Cold-process cycle: ", failures, " failures")
		get_tree().quit(failures)
		return
	Journal.entry_added.connect(func(_id): discoveries += 1)
	GameState.delete_save()
	check(not GameState.load_game(), "missing save")
	GameState.new_game()
	Journal.discover("")
	Journal.discover("  ")
	Journal.discover("keeper_log")
	Journal.discover("keeper_log")
	Journal.discover("future_content")
	check(discoveries == 2, "only new nonblank IDs emit discoveries")
	var copy := Journal.entries()
	copy.clear()
	check(Journal.entries().size() == 2, "entries snapshot cannot mutate journal")
	var story := {"skeptic": true, "believer": false, "trusted_edith": false, "radioed_tom": true, "unknown_flag": {"value": "retained"}}
	for key in story:
		GameState.set_flag(key, story[key])
	check(GameState.save_game(), "save v2")
	GameState.new_game()
	check(GameState.flags.is_empty() and Journal.entries().is_empty(), "new game resets both stores")
	check(GameState.has_save(), "new game preserves disk save until explicit save")
	check(GameState.load_game(), "load v2")
	check(GameState.flags == story, "all story flag values round-trip including false and unknown")
	check(Journal.entries() == ["keeper_log", "future_content"], "journal order and unknown IDs round-trip")
	check(discoveries == 2, "restore emits no discovery notifications")
	check(GameState.load_game() and Journal.entries().size() == 2, "repeated Continue replaces rather than appends")

	for version in [null, 1]:
		var legacy := {"scene": "res://scenes/game.tscn", "flags": story}
		if version != null:
			legacy["version"] = version
		write_payload(legacy)
		Journal.discover("stale")
		check(GameState.load_game(), "legacy version loads")
		check(GameState.flags == story and Journal.entries().is_empty(), "legacy clears journal and preserves flags")
		check(GameState.save_game(), "legacy can be saved as v2")

	var good := {"version": 2, "scene": "res://scenes/lamp_room.tscn", "flags": story, "journal_entries": ["a", "b", "a", "future"]}
	write_payload(good)
	check(GameState.load_game(), "valid lamp scene loads")
	check(Journal.entries() == ["a", "b", "future"], "deduplicate preserving first-seen order")
	for invalid in [null, [], {"version": 3}, {"version": true}, {"version": 1.5}, {"scene": 7}, {"scene": "res://missing.tscn"}, {"flags": []}, {"version": 2, "journal_entries": null}, {"version": 2, "journal_entries": ["good", 7]}, {"version": 2, "journal_entries": [" "]}]:
		write_payload(invalid)
		check(not GameState.load_game(), "invalid save rejected: " + str(invalid))
		check(GameState.flags == story and Journal.entries() == ["a", "b", "future"] and GameState.current_scene == "res://scenes/lamp_room.tscn", "failed load leaves all state untouched")
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string('{"version":')
	file.close()
	check(not GameState.load_game(), "truncated JSON rejected")

	# A directory at the temporary path forces open failure, preserving the old slot.
	write_payload(good)
	var before := FileAccess.get_file_as_string(GameState.SAVE_PATH)
	DirAccess.make_dir_absolute(GameState.SAVE_PATH + ".tmp")
	check(not GameState.save_game(), "write failure reported")
	check(FileAccess.get_file_as_string(GameState.SAVE_PATH) == before, "failed save preserves existing file")
	DirAccess.remove_absolute(GameState.SAVE_PATH + ".tmp")

	GameState.new_game()
	check(DialogueManager.start("res://data/dialogue/keeper_intro.json", "logbook"), "real dialogue starts")
	check(Journal.has("keeper_log"), "reading logbook discovers entry")
	DialogueManager.advance()
	DialogueManager.advance()
	DialogueManager.choose(0)
	DialogueManager.advance()
	DialogueManager.advance()
	DialogueManager.choose(1)
	DialogueManager.advance()
	check(GameState.get_flag("skeptic") == true and GameState.flags.has("trusted_edith") and GameState.get_flag("trusted_edith") == false, "real dialogue choices retain story behavior")
	check(GameState.save_game(), "save actual discovered log and choices")
	GameState.new_game()
	check(GameState.load_game() and Journal.has("keeper_log") and GameState.get_flag("skeptic") == true and GameState.flags.has("trusted_edith") and GameState.get_flag("trusted_edith") == false, "actual story plus journal round-trip")
	GameState.new_game()
	DialogueManager.start("res://data/dialogue/keeper_intro.json", "logbook")
	DialogueManager.advance()
	DialogueManager.advance()
	DialogueManager.choose(1)
	DialogueManager.advance()
	DialogueManager.advance()
	DialogueManager.choose(0)
	DialogueManager.advance()
	DialogueManager.start("res://data/dialogue/keeper_intro.json", "radio")
	DialogueManager.advance()
	DialogueManager.choose(0)
	DialogueManager.advance()
	check(GameState.save_game(), "save alternate story branch")
	GameState.new_game()
	check(GameState.load_game() and GameState.get_flag("believer") == true and GameState.get_flag("trusted_edith") == true and GameState.get_flag("radioed_tom") == true, "alternate branch and radio flags survive")
	GameState.delete_save()
	print("Save/journal integration: ", failures, " failures")
	get_tree().quit(1 if failures else 0)

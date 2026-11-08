# Save / Continue audit and Sprint 29 acceptance

Baseline audited: `8c9b1e4` (public-demo candidate).

| State | Baseline save / Continue | With this change |
|---|---|---|
| Story flags | Entire dictionary serialized; false values retained | Same names and values, including unknown keys; malformed dictionaries rejected |
| Scene | Pause Save records scene path; Continue reconstructs scene | Same, restricted to the two shipped gameplay scene paths |
| Journal | Unregistered scaffold, no callers, no persistence | Registered autoload; ordered unique IDs saved and replaced on load |
| Player position | Not saved; default scene spawn | Unchanged |
| Dialogue cursor | Not saved; dialogue restarts on interaction | Unchanged; no mid-dialogue Save through pause menu |
| Settings | Runtime volume/fullscreen only; not serialized | Unchanged |

## Concrete flow

`game.gd` Pause → Save sets `GameState.current_scene`, then writes the slot.
`main_menu.gd` Continue → `load_game()` validates and restores state before
changing scene. File existence enables Continue; unreadable/invalid saves now
show failure text and remain on the menu.

A dialogue node or choice may declare `"journal_entry": "stable_id"`.
The keeper log entry node now declares `keeper_log`. Discovery happens when
that node is entered; revisits do not append or notify again. Existing
`set_flag` behavior is independent: skeptic, believer, trusted_edith (including
false), and radioed_tom are unchanged. No guessed journal recovery from flags:
old saves never recorded discovery, so they start with an empty journal.
Re-reading the log discovers it normally.

## Save contract

Version 2 keeps `scene` and `flags` and adds `journal_entries` (array of IDs).
Unversioned and version 1 files load using the legacy shape and an empty journal.
Missing scene/flags/journal fields use the existing default scene, empty flags,
and empty journal respectively. A subsequent explicit save writes v2.
New Game clears in-memory flags and journal, but retains the on-disk slot until
Save is selected, matching existing behavior. Main Menu is not an autosave.

Unknown journal IDs survive; duplicate IDs collapse in first-seen order.
Blank IDs, non-string IDs, wrong container types, invalid scene paths,
non-object/truncated JSON, and unsupported versions fail before any live state
is changed. JSON numeric flags retain the existing JSON conversion semantics.
Restore emits `entries_changed`, never `entry_added`; callers receive copies.

Writes go to a sibling temporary file, flush and check the write result, then
rename over the slot. Open/write/rename failures return false. The implementation
does not claim full power-loss durability, backup recovery, concurrent-process
coordination, or Steam Cloud conflict handling. Those need platform testing.

## Automated checks

Use Godot 4.3+ and an isolated user-data directory: tests intentionally create
and delete `user://save.json`. On Linux, from the repository root:

```sh
export XDG_DATA_HOME="$(mktemp -d)"
godot --headless --path . --editor --import --quit
godot --headless --path . tests/save_journal.tscn
godot --headless --path . tests/save_journal.tscn -- --write-cycle
godot --headless --path . tests/save_journal.tscn -- --read-cycle
python3 tests/validate_dialogue.py
```

On Windows/macOS run in a disposable test user/project data directory.
Corruption and forced-write-failure cases deliberately print engine errors;
the integration runner's exit code and failure count determine success.

Coverage: deduplication, blank discovery, copy isolation, ordering, unknown IDs,
flag false values and unknown keys, new-game reset, repeated load, legacy and
unversioned migration, unsupported versions, malformed fields, missing/truncated
files, failure without live-state mutation, write-open failure preserving the
old slot, real logbook dialogue choices, and a separate-process disk cycle.

## Before calling the launch path done

- [ ] Run the actual menu: read log → choose both story branches in separate
  runs → Save → quit application → Continue → revisit log; one entry remains.
- [ ] Verify controller and keyboard Continue failure text fits and stays usable.
- [ ] Exercise scene reconstruction from both supported scene paths in exported
  builds. The lamp room is still a scaffold, and the stair currently only plays
  dialogue; this change does not make that chapter playable.
- [ ] Test disk full, denied permissions, rename failure/locked file, and process
  interruption before/after replacement on every shipping OS/filesystem.
- [ ] Decide backup/recovery and Steam Cloud conflict policy, including two
  running instances and downgrading to an older binary (which would discard
  journal entries when it saves).
- [ ] Ship the journal reader/content catalog; unknown IDs must render a safe
  fallback. There is still no reader UI in this change.
- [ ] Decide whether launch needs position or mid-dialogue resume; current
  semantics are scene checkpoints with explicit manual saves.

Passing persistence checks completes this state-hardening slice, not the above
launch acceptance work or the playtest feedback loop as a whole.

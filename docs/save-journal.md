# Save / Continue behavior contract

Baseline audited: `8c9b1e4` (public-demo candidate). Persistence implementation: `cb4c363`.

For test steps, evidence, and outstanding acceptance work, see the
[regression checklist](journal-save-regression.md).

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
Supported scene paths are `res://scenes/game.tscn` and
`res://scenes/lamp_room.tscn`. Saves naming other or renamed scenes are rejected
until an explicit migration exists.

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


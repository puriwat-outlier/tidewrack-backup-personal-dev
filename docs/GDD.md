# Tidewrack — Game Design Document

Concise and living. For story canon see [`narrative-bible.md`](narrative-bible.md);
for schedule see [`milestones.md`](milestones.md).

## Pillars

1. **The fog keeps its secrets.** Discovery is slow, earned, and atmospheric.
2. **Words over combat.** The game is exploration + reading + choices. No fail
   states, no timers, no death.
3. **A place you tend.** The lighthouse is a home and a job; verbs are keeper's
   verbs — light the lamp, log the night, work the radio.

## Core loop

Explore a location → find a document, recording, or object → read/hear it in a
branching conversation → make a choice that sets a flag → the world (and later,
who answers you) responds. Repeat across locations toward the water.

## Systems

| System | State | Notes |
|--------|-------|-------|
| Branching dialogue | ✅ vertical slice | JSON graphs, choices set flags. |
| Save / load        | Implemented; launch checks pending | Manual single slot, `user://save.json`; scene, story flags, and journal discoveries. |
| Menus + settings   | ✅ vertical slice | Title, pause, volume, fullscreen. |
| Player movement    | ✅ vertical slice | Top-down; wall collision pending. |
| Journal            | Persistence implemented; reader pending | Reading the keeper log records a unique entry; a re-readable journal UI remains planned. |
| Second location    | ⏳ demo           | The lamp room. |
| Controller + remap  | ⏳ demo          | Currently keyboard-only, built-in actions. |
| Localization        | ⏳ press build    | String extraction + translation tables. |
| Accessibility       | ⏳ press build    | Text scale, dyslexia-friendly font, no-flash. |
| Steam integration   | ⏳ launch         | Achievements, cloud saves. |

## Save, Continue, and journal

Save is an explicit pause-menu action. Continue restores story flags and ordered
journal discoveries, then reconstructs the saved scene at its default spawn.
Player position and dialogue progress are not saved. Existing story-choice
flags retain their names and values, including false values.

Valid version 1 and unversioned saves retain their flags and supported scene,
with an empty journal because discovery was not recorded in those formats.
The supported scene paths are `res://scenes/game.tscn` and
`res://scenes/lamp_room.tscn`; other paths require an explicit migration.
The lamp room remains a gameplay scaffold.

New Game clears flags and journal in memory; the previous disk slot remains
until the player explicitly saves again. Returning to the main menu does not
autosave. Invalid or unsupported saves report a Continue failure without
replacing live state. Journal discovery/persistence is implemented; the reader
UI and Steam Cloud integration remain pending.

See the [save/Continue behavior contract](save-journal.md) for implementation
details and the [regression checklist](journal-save-regression.md) for verified
coverage and outstanding launch checks. Feature implementation is not launch
sign-off.

## Interaction design

Proximity-based: walk near an object, a prompt appears, press Enter. Dialogue
uses a typewriter reveal with press-to-skip; choices are keyboard-navigable and
focus the first option automatically. Movement is locked during conversation.

## Art & audio direction

Placeholder primitives today. Target: muted, desaturated palette (slate, kelp,
lamp-gold as the one warm accent — `#ffd466`); hand-painted 2D; a sound bed of
foghorn, surf, and radio static carrying most of the mood. Concept art and
final assets are produced per-milestone (see the tracker's `art` label).

## Out of scope (YAGNI)

No inventory economy, no crafting, no procedural generation, no multiplayer.

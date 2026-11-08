# Journal and save regression checklist

Behavior is defined in [save-journal.md](save-journal.md); the design summary is
in [GDD.md](GDD.md). This file owns test procedures, evidence, and acceptance
status. Do not mark a case passed from code inspection alone.

## Evidence and status

Recorded on 2026-11-08. The existing automated runs used Godot 4.3 on Linux
against local commit `03aad14`. Published commit `cb4c363` has the identical
file tree (`6b48eae780655535a2bc3be68d3576626f1e104b`).
These are prior execution results, not a new run for this documentation update.

- **Automated pass:** assertions executed successfully in that environment.
- **Manual pass:** requires a recorded build, platform, date, and observed result.
- **Not tested:** no execution evidence yet; expected behavior is a requirement,
  not a claim that it works.

Evidence comes from [save_journal.gd](../tests/save_journal.gd) and its
[runner scene](../tests/save_journal.tscn). The integration runner reported
`0 failures`; the separate-process cycle reported `0 failures`.
The dialogue validator also passed with zero warnings. No manual passes are
claimed. “Load” below means a function call, not clicking the Continue button.

## Running automated checks

Tests create and delete `user://save.json`. Use an isolated user-data directory.
On Linux, from the repository root, run in a subshell so the test environment
does not affect later game launches:

```sh
(
  set -e
  export XDG_DATA_HOME="$(mktemp -d)"
  godot --headless --path . --editor --import --quit
  godot --headless --path . tests/save_journal.tscn
  godot --headless --path . tests/save_journal.tscn -- --write-cycle
  godot --headless --path . tests/save_journal.tscn -- --read-cycle
  python3 tests/validate_dialogue.py
)
```

Use Godot 4.3+; only 4.3/Linux is covered by the recorded evidence.
On Windows/macOS use a disposable test user/project data directory.
Corruption and forced-open-failure cases deliberately print engine errors;
check each command's exit code and the runner's failure count.

## Journal and story state

All rows in this section are **Automated pass** on the recorded build/platform.

| ID | Scenario / steps | Expected result | Assertion evidence |
|---|---|---|---|
| J01 | Discover empty, whitespace-only, duplicate, and two distinct IDs | Only two entries; two discovery events | `only new nonblank IDs emit discoveries`, later entry-list comparison |
| J02 | Clear the array returned by `entries()` | Internal journal still holds two entries | `entries snapshot cannot mutate journal` |
| J03 | Save ordered IDs including an unknown ID; reset and load | Same order and IDs, no new-discovery events | `journal order and unknown IDs round-trip`; `restore emits no discovery notifications` |
| J04 | Load the same save twice; separately load duplicate IDs | No appended duplicates; first-seen order retained | `repeated Continue replaces rather than appends`; `deduplicate preserving first-seen order` |
| J05 | Call New Game after saving | Flags and journal empty in memory; disk save still exists | `new game resets both stores`; `new game preserves disk save until explicit save` |
| S01 | Round-trip canonical flags, false values, and an unknown nested string-valued flag | Flag dictionary equals the fixture | `all story flag values round-trip including false and unknown` |
| S02 | Drive actual logbook dialogue through skeptic/quiet, then save, reset, load | Journal entry, skeptic=true, trusted_edith=false retained | `actual story plus journal round-trip` |
| S03 | Drive believer/share and radio's Edith branch, then save, reset, load | believer, trusted_edith, radioed_tom are true | `alternate branch and radio flags survive` |
| S04 | Save in one engine process; load in another | keeper_log and explicitly stored trusted_edith=false restored from disk | `--write-cycle` and `--read-cycle` assertions |

S02/S03 exercise both options at each logbook choice, not all four combinations.
Only one radio choice is exercised. Numeric flag conversion and every possible
flag value type are not covered by S01.

## Legacy saves and invalid data

| ID | Scenario / steps | Expected result | Status / evidence |
|---|---|---|---|
| L01 | Generate v1 and unversioned fixtures; seed a stale journal; load | Flags preserved; stale journal cleared; subsequent save succeeds | Automated pass: `legacy clears journal and preserves flags`, `legacy can be saved as v2` |
| L02 | Load actual archived player saves from supported releases | Supported scenes and flags retained; empty journal for legacy format | Not tested: fixtures in L01 are synthetic |
| L03 | Load fixture naming lamp_room.tscn | Loader accepts the scene path | Automated pass: `valid lamp scene loads`; does not instantiate the scene |
| L04 | Load a valid v2 object with optional fields absent | Defaults follow the behavior contract | Not tested as a dedicated valid-case assertion |
| V01 | Load null/array roots, version 3/true/1.5, numeric or nonexistent scene path, array flags, null journal, non-string or blank entry | Load fails; existing scene, flags, and journal remain unchanged | Automated pass: invalid-fixture loop and state comparisons; nonexistent path fixture is `res://missing.tscn` |
| V02 | Remove save; attempt load | Returns false | Automated pass: `missing save` |
| V03 | Write truncated JSON; attempt load | Returns false | Automated pass: `truncated JSON rejected`; this case does not separately assert unchanged live state |
| V04 | Load legacy save with a formerly valid renamed/other scene | Reject without mutation under current allowlist; migration needed if such a release existed | Not tested against historical releases |

L01 checks that re-saving returns success; it does not separately inspect the
upgraded file's version field or reload that upgraded fixture.

## Write failures and recovery

| ID | Scenario / steps | Expected result / acceptance target | Status / evidence |
|---|---|---|---|
| W01 | Put a directory at save.json.tmp, then save | Open fails, save returns false, old slot remains byte-for-byte unchanged | Automated pass: `write failure reported`; `failed save preserves existing file` |
| W02 | Deny filesystem access to the temporary file | Failure is reported; old slot remains usable | Not tested; W01 is an open-failure simulation, not a permissions test |
| W03 | Exhaust disk space or inject a write/flush failure | No false success; previous slot remains usable | Not tested |
| W04 | Lock destination or inject rename failure | Failure is reported; previous slot remains usable | Not tested |
| W05 | Interrupt process before/after replacement; test power loss separately | Characterize recoverable state and define recovery guarantees | Not tested; full power-loss durability is not claimed |
| W06 | Run two instances or create conflicting Steam Cloud saves | Apply an agreed conflict/recovery policy without silent loss | Not tested; policy and cloud integration pending |
| W07 | Open a v2 save with the older binary and save again | Confirm and document downgrade behavior | Not tested; code review indicates older writer drops journal data |

Do not generalize W01 into “disk-full, interrupted-write, or rename safety
passed.” Run W02–W05 on each shipping OS/filesystem before making those claims.

## Menu, exported builds, and remaining acceptance

| ID | Scenario / steps | Expected result / acceptance target | Status |
|---|---|---|---|
| M01 | In actual game UI, read log, make choices, Save, quit, relaunch, Continue, revisit log | Saved flags and one journal entry retained; scene starts at default spawn | Not tested through menus |
| M02 | Use keyboard/controller Continue with invalid/unreadable save | Failure text fits; menu remains usable; no scene change | Not tested |
| M03 | Continue each supported scene in exported builds | Scene reconstruction succeeds with restored state | Not tested; lamp room remains a scaffold and stair only plays dialogue |
| M04 | Leave without saving; Continue; separately start New Game without saving and relaunch | Last explicit disk save remains authoritative | Not tested as a complete UI/process flow |
| M05 | Exercise future journal reader with known and unknown IDs | Entries readable; unknown IDs show a safe fallback | Blocked by missing reader/content catalog |

Before launch sign-off:

- [ ] Complete L02 and menu/exported-build checks with recorded evidence.
- [ ] Complete relevant failure tests on shipping platforms.
- [ ] Decide backup/recovery, downgrade, concurrency, and cloud conflict policy.
- [ ] Ship and verify the journal reader.
- [ ] Decide whether launch requires position or mid-dialogue resume. Current
  behavior is manual saving of scene, flags, and journal discoveries.

For each new result, record case ID, commit/build, engine version, OS/filesystem,
date, steps or fixture provenance, observed result, and evidence location.
Keep pending checks pending until exercised; persistence test passes alone are
not full launch sign-off.

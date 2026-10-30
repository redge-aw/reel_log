# Proposal

## Why

The "Log a film" button is a no-op, so the list can only show the demo seed. The next handoff screen is the sheet that turns a watched film into a persisted entry.

## What Changes

- Tapping "Log a film" opens a bottom sheet for a new entry: title, optional release year, date watched, rating, and notes.
- Save is disabled until the title has non-whitespace text. A blank year and an unrated film (no stars) are valid.
- Save appends the film and writes the full list to the existing local store. The list keeps sorting by date watched, so a backdated entry does not jump to the top.
- Cancel and the close icon discard the draft.
- A short confirmation names the saved title.
- **BREAKING** for new saves only: release year may be absent. Existing saved films still have a year. There is no director field.

## Capabilities

### New Capabilities

- `log-film`: Create a watched-film entry from the log sheet and keep it in the persisted, date-sorted list.

### Modified Capabilities

- None. The repo has no existing specs.

## Impact

- `lib/main.dart`: the log button, the sheet, `Film.year` (optional on new entries), and the save path that rewrites `reel_log_films`.
- `test/widget_test.dart`: the sheet's save gate, rating, persistence, and date ordering.
- No new dependencies. The exploratory worktrees are not the implementation.

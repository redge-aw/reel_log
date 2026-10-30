# Proposal

## Why

The "Log a film" button is a no-op, so the list can only show the demo seed. The next handoff screen is the sheet that turns a watched film into a persisted entry.

## What Changes

- Tapping "Log a film" opens a bottom sheet for a new entry: title, optional release year, watched year, rating, and optional notes.
- Save is disabled until the title has non-whitespace text. A blank year and an unrated film (no stars) are valid.
- Save appends the film with a generated unique identifier and writes the full list to the existing local store. The list keeps sorting by watched year, so an entry from an earlier year does not jump to the top.
- Cancel and the close icon discard the draft.
- A short confirmation names the saved title.
- **BREAKING** for new saves only: release year may be absent, and watched is stored as a year instead of a full date. Existing saved films still load; a stored watched date is read as its year. There is no director field.

## Capabilities

### New Capabilities

- `log-film`: Create a watched-film entry from the log sheet and keep it in the persisted list, sorted by watched year.

### Modified Capabilities

- None. The repo has no existing specs.

## Impact

- `lib/main.dart`: the log button, the sheet, `Film.year` (optional on new entries), `Film.watched` becoming a watched year, blank notes stored as absent, generated unique ids, and the save path that rewrites `reel_log_films`.
- `test/widget_test.dart`: the sheet's save gate, rating, persistence, and date ordering.
- No new dependencies. The exploratory worktrees are not the implementation.

# Proposal

## Why

Tapping a row in the Watched list does nothing today, so a film's rating and notes can only be set at log time and cannot be revisited. This change implements [issue #2](https://github.com/redge-aw/reel_log/issues/2) for the `02 Film detail` handoff screen.

## What Changes

- Tapping a Watched list row opens the film detail screen showing the poster tile, inline editable title and release year, a `Your rating` card (`Not rated` when unrated, `<rating> of 5` when rated) with five 44x44 star targets that save on tap (sticky, no toggle-off) and an inline editable watched year, a `Notes` field that autosaves with `Saved automatically`, and back navigation to the Watched list with search and filter preserved.
- Title, release year, and watched year validate on commit (focus loss, submit, or back navigation) using the same rules and messages as the log sheet (`Enter a title.`, `Enter a 4-digit year.`); a blank release year stays valid and stored as absent.
- Detail saves wait for the initial load, serialize writes to the existing local store, flush pending notes before navigating back, and roll back on write failure while keeping the user's draft text and showing `Couldn't save. Try again.`.
- Share and Remove controls are out of scope and omitted. No `director`, `runtime`, or `genre` fields are added.

## Capabilities

### New Capabilities

- `film-detail`: View and update a logged film's title, release year, watched year, rating, and notes from the detail screen with tap-to-save rating and autosave notes.

### Modified Capabilities

- None.

## Impact

- `lib/main.dart`: tappable list rows, the detail screen widget, and the serialized update path that rewrites `reel_log_films`.
- `test/widget_test.dart`: detail navigation, sticky rating persistence, notes debounce and back-flush, inline field validation, write-failure rollback, and out-of-scope guards.
- No new dependencies.

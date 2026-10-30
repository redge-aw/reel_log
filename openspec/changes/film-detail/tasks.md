# Tasks

## 1. Detail route and header

- [ ] 1.1 Make `_row` in `lib/main.dart` tappable to push the detail screen by film `id` (waiting for `_loadDone`, showing `Film not found.` and popping if missing, and preserving search and filter state on back), and serialize full-list writes in `_ReelLogHomeState`. Verify a widget test taps a row, sees the detail screen, navigates back via `Key('detailBack')`, and finds the Watched list with the same search and filter applied.
- [ ] 1.2 Build the detail header with the `< Watched` back control (`Key('detailBack')`), the 112x168 `_tones` poster tile, and editable `Key('detailTitle')` and `Key('detailReleaseYear')` fields. Verify widget tests open detail for a film with a release year and a film without one (confirming `detailReleaseYear` is empty and editable when `year == null`).

## 2. Sticky rating card

- [ ] 2.1 Build the `Your rating` card with `Not rated` when `0` or `'<rating> of 5'` when `1..5`, five 44x44 star buttons (`'1 of 5'`…`'5 of 5'` tooltips) that save immediately on tap and stay sticky when re-tapped, and the watched-year field (`Key('detailWatchedYear')`). Verify widget tests for `Not rated` display when `0`, tapping a star persisting to `reel_log_films` and showing `'4 of 5'`, re-tapping the selected star keeping the rating, and navigating back updating the row and average rating.
- [ ] 2.2 Roll back the rating in memory and revert the displayed stars and label on write failure while showing `Couldn't save. Try again.` inline. Verify a widget test with a failing store shows the revert and error message and leaves the list unchanged.

## 3. Notes autosave and inline field validation

- [ ] 3.1 Build the `Notes` section (`Key('detailNotes')`, placeholder `'What stayed with you?'`) with 500ms debounced autosave (trimmed, blank stored as absent), `Saved automatically` / `Saving...` caption, and back-navigation flush (`PopScope` / `detailBack`) that cancels the timer and awaits pending writes before popping. Verify widget tests for 500ms autosave, blank notes omitting the `notes` key in JSON, and typing notes then immediately navigating back persisting the notes.
- [ ] 3.2 Validate and save `detailTitle`, `detailReleaseYear`, and `detailWatchedYear` on blur, submit, or back navigation (`Enter a title.` for empty/whitespace title; `Enter a 4-digit year.` for non-blank release year != 4 digits or watched year != 4 digits; valid title updating poster initials; blank release year stored as absent; invalid fields keeping draft text without writing). Verify widget tests for each validation case, valid title updating initials and the list row, and clearing release year to absent.
- [ ] 3.3 On write failure for notes, title, or years, keep the typed draft text in the field, restore the prior `Film` in memory, show `Couldn't save. Try again.` inline, and keep the route open if a back-flush fails. Verify widget tests with a failing store for notes and watched year.

## 4. Validate the spec

- [ ] 4.1 Verify the detail screen renders zero `Share`, `Share film`, or `Remove` controls and stores no `director`, `runtime`, or `genre` keys after detail saves.
- [ ] 4.2 Run `flutter analyze`, `flutter test`, and `openspec validate film-detail --strict`; all pass.

## Workflow follow-up

- Archive the change after review.

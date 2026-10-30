# Tasks

## 1. Film model

- [ ] 1.1 Make `Film.year` nullable, omit it from JSON when null, and accept a missing year in `fromJson`. Show the release year on a row only when it is present. Verify the existing JSON round-trip test still passes and a new case round-trips a film with no year plus a film that still has one.
- [ ] 1.2 Replace `Film.watched` (`DateTime`) with `watchedYear` (`int`): store it as an int in JSON, and in `fromJson` accept an int or an old ISO date string (taking its year). Sort `_visible` by `watchedYear` descending, compare the `2026` filter against `watchedYear`, and show the watched year on the row instead of a formatted date. Verify a round-trip of the new shape and a legacy entry whose watched date loads as its year.
- [ ] 1.3 Make `Film.notes` nullable (`String?`): blank notes save as null and are omitted from JSON, and `fromJson` treats missing notes as null. The With-notes filter treats null as no notes. Verify a round-trip with no notes and one with notes.

## 2. Log sheet

- [ ] 2.1 Add a private sheet widget in `lib/main.dart` and open it from the log button with a 28px top radius and a 300ms ease-out. Include title, release year (digits, max 4), watched year (digits, max 4, defaulting to the current calendar year), five stars that clear when the current rating is tapped again, notes, Cancel, Save, and a close control. Verify a widget test opens the sheet and that Save stays disabled for an empty title and a whitespace title, then enables once the title has text. Verify typing a title and clearing it shows `Enter a title.` under the title field, and entering text again clears that message.

## 3. Save

- [ ] 3.1 On Save, wait for the initial prefs load if it is still running, generate a unique id from the current time (`microsecondsSinceEpoch`, bumped while it matches an existing id), append the film, await a full-list write to `reel_log_films`, then close the sheet and show `Added "{title}"`. If the write throws, remove the film, do not show that confirmation, keep the sheet open with the draft as entered, and show `Couldn't save "{title}". Try again.` Leave `_visible`'s watched-year sort as it is. Verify widget tests for: a blank year stored as absent with no year on the row; a five-digit year kept as four digits; an unrated save that leaves the average unchanged; toggling the selected star back to unrated; a saved non-zero rating; Cancel leaving the store unchanged; the close control leaving the store unchanged; tapping outside the sheet or dragging it down leaving the store unchanged; an earlier watched year appearing below a later one; notes stored trimmed, and blank notes stored as no notes; a generated id that no existing film uses, and two saves receiving distinct ids; no `director` key; the film still present when the app is pumped again against the same prefs; a two-digit release year that shows `Enter a 4-digit year.` and does not save; a cleared watched year that shows the same message and does not save; a two-digit watched year that shows the same message and does not save; the sheet closing with the exact confirmation `Added "Aftersun"` on a successful save; and a write failure that leaves the film out of the list with no `Added` confirmation, shows `Couldn't save "Aftersun". Try again.`, and keeps the sheet open with the entered draft still in place.

## 4. Validate the spec

- [ ] 4.1 Confirm every requirement in `specs/log-film/spec.md` has a passing test in `test/widget_test.dart` (or the `Film` JSON unit test where the requirement is about storage shape). Check each one off only when its named test exists and passes:
  - Log sheet opens from the list — widget test taps "Log a film" and finds the sheet fields
  - Save requires a title — empty and whitespace titles keep Save disabled; a real title enables it; typing then clearing the title shows `Enter a title.`, and entering text again clears it
  - Release year is optional and numeric — blank year stored absent with no year on the row; more than four digits kept as four; a two-digit year on Save shows `Enter a 4-digit year.` and does not save
  - Watched year defaults to the current year — sheet opens on the current year; a changed watched year is what gets saved; a cleared watched year on Save shows `Enter a 4-digit year.` and does not save; a two-digit watched year on Save shows the same message and does not save
  - Rating may be unset — tapping a star saves that rating; tapping it again clears to unrated; an unrated save leaves the average unchanged
  - Notes are optional — blank notes stored as no notes; padded notes stored trimmed
  - Dismissing the sheet discards the draft — Cancel, the close control, and tapping outside the sheet or dragging it down each leave the list and store unchanged
  - Save persists a unique entry in watched-year order — sheet closes on success, trimmed title stored, exact confirmation `Added "Aftersun"` shown, generated id unused by any other film, two saves receive distinct ids, earlier watched year below a later one (same-year order not asserted), film present after re-pumping against the same prefs
  - Save failure leaves the list unchanged — a failing write keeps the film out, shows no `Added "Aftersun"` confirmation, shows `Couldn't save "Aftersun". Try again.`, and keeps the sheet open with the entered draft still in place
  - Existing saved films still load — a prior save with a release year shows its year, and a prior save with a full watched date loads showing that date's year
- [ ] 4.2 Run `flutter analyze` and `flutter test`; both pass. Run `openspec validate log-a-film --strict`; it passes.

## Workflow follow-up

- Apply this change only from these artifacts. Do not copy either exploratory worktree.
- Archive the change after review.

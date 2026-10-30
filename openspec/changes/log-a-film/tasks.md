# Tasks

## 1. Optional release year

- [ ] 1.1 Make `Film.year` nullable, omit it from JSON when null, and accept a missing year in `fromJson`. Show the year on a row only when it is present. Verify the existing JSON round-trip test still passes and a new case round-trips a film with no year plus a film that still has one.

## 2. Log sheet

- [ ] 2.1 Add a private sheet widget in `lib/main.dart` and open it from the log button with a 28px top radius and a 300ms ease-out. Include title, release year (digits, max 4), date watched defaulting to today, five stars that clear when the current rating is tapped again, notes, Cancel, Save, and a close control. Verify a widget test opens the sheet and that Save stays disabled for an empty title and a whitespace title, then enables once the title has text.

## 3. Save

- [ ] 3.1 On Save, wait for the initial prefs load if it is still running, assign an id above the current max, append the film, await a full-list write to `reel_log_films`, then show "Added {title}". If the write throws, remove the film and do not show that confirmation. Leave `_visible`'s date sort as it is. Verify widget tests for: a blank year stored as absent with no year on the row; a five-digit year kept as four digits; an unrated save that leaves the average unchanged; toggling the selected star back to unrated; a saved non-zero rating; Cancel leaving the store unchanged; a backdated film appearing below a later one; no `director` key; and the film still present when prefs are read back. `flutter analyze` is clean and `flutter test` passes.

## Workflow follow-up

- Apply this change only from these artifacts. Do not copy either exploratory worktree.
- Archive the change after review.

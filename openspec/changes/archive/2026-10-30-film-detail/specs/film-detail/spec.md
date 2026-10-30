# Spec Delta

<!-- Implements https://github.com/redge-aw/reel_log/issues/2 (film details screen). -->

## Purpose

Lets a person open a logged film to view and update its title, release year, watched year, rating, and notes from a dedicated details screen, with tap-to-save rating and autosaving notes.

## ADDED Requirements

### Requirement: Detail opens from the list

The system SHALL open a detail screen when the person taps a Watched list row. The screen SHALL show the 112x168 initials tile, editable title field, editable release-year field (empty when the film has no release year), editable watched-year field, rating stars, notes field, and a `< Watched` back control.

#### Scenario: Row opens detail

- **WHEN** the person taps a list row for a saved film
- **THEN** the detail screen shows that film's poster initials, title, release year when present, watched year, rating, and notes

#### Scenario: Film with no release year has empty release-year field

- **WHEN** the person opens detail for a film with no release year
- **THEN** the release-year field on detail is empty and editable so a release year can be added

#### Scenario: Back preserves list state

- **WHEN** the person navigates back from detail
- **THEN** the app returns to the Watched list with the same search query and filter chip applied

### Requirement: Sticky tap-to-save rating

The system SHALL render five 44x44 star targets (`1 of 5` to `5 of 5` tooltips) inside the `Your rating` card. Tapping any star SHALL set the rating to that count and persist immediately with no Save step. Tapping the current rating SHALL keep it (sticky, never clears). When unrated (`0`), all five stars SHALL appear unselected with label `Not rated`; when rated `1..5`, the label SHALL show `<rating> of 5`.

#### Scenario: Star tap persists

- **WHEN** the detail screen is open and the person taps the fourth star
- **THEN** the rating is stored as 4 in `reel_log_films` and the rating card shows `4 of 5`

#### Scenario: Re-tap keeps rating

- **WHEN** the rating is 5 and the person taps the fifth star again
- **THEN** the rating stays 5 and the rating card still shows `5 of 5`

#### Scenario: Unrated display

- **WHEN** the film is unrated (`rating == 0`)
- **THEN** all five stars appear unselected and the rating card shows `Not rated`

#### Scenario: List reflects after back

- **WHEN** the person changes the rating then navigates back
- **THEN** the list row shows the new rating and the header average updates

### Requirement: Notes debounce autosave and back flush

The system SHALL autosave notes (trimmed, with blank stored as absent) 500ms after typing stops. The screen SHALL show `Saved automatically` under notes and `Saving...` while a write is in flight. Navigating back SHALL cancel any pending 500ms timer, commit pending notes and any dirty valid text fields, and await the write before popping.

#### Scenario: Notes autosave

- **WHEN** the person edits notes on detail and pauses for 500ms
- **THEN** the trimmed notes are stored in `reel_log_films` and `Saved automatically` is shown

#### Scenario: Blank notes stored as absent

- **WHEN** the person clears notes to empty or whitespace and the edit commits
- **THEN** the film is stored in `reel_log_films` with no `notes` key

#### Scenario: Flush on back

- **WHEN** the person types notes and immediately navigates back before 500ms elapses
- **THEN** the pending write is awaited before pop completes and the typed notes are stored and reflected on the list

#### Scenario: Missing film

- **WHEN** the film id is missing after the initial load finishes
- **THEN** detail shows `Film not found.` and returns to the list

### Requirement: Inline title and year validation on commit

The system SHALL validate and save title, release year, and watched year on focus loss (blur), keyboard submit, or back navigation — not per keystroke. Blank release year SHALL stay valid and stored absent. Non-blank release year and watched year SHALL require 4 digits. Whitespace-only title SHALL be blocked. Invalid input SHALL show inline copy (`Enter a title.` or `Enter a 4-digit year.`), keep the draft text, and skip writing that field.

#### Scenario: Valid title edit updates initials and persists

- **WHEN** the person changes the title to `" Past Lives "` and blurs or submits the title field
- **THEN** the film is stored with trimmed title `"Past Lives"`, the header tile initials update to `PL`, and the list row shows `"Past Lives"` after navigating back

#### Scenario: Blank release year stays absent

- **WHEN** the person clears the release year on detail and commits the field
- **THEN** no error is shown and the film is stored with no `year` key

#### Scenario: Short release year blocked

- **WHEN** the person enters a two-digit release year and blurs or submits the field
- **THEN** `Enter a 4-digit year.` is shown under the release-year field, the draft text stays, and the stored release year is unchanged

#### Scenario: Short watched year blocked

- **WHEN** the person enters a two-digit watched year and blurs or submits the field
- **THEN** `Enter a 4-digit year.` is shown under the watched-year field, the draft text stays, and the stored watched year is unchanged

#### Scenario: Cleared watched year blocked

- **WHEN** the person clears the watched year and blurs or submits the field
- **THEN** `Enter a 4-digit year.` is shown under the watched-year field and the stored watched year is unchanged

#### Scenario: Whitespace title blocked

- **WHEN** the person clears the title to empty or whitespace and blurs or submits the field
- **THEN** `Enter a title.` is shown under the title field, the draft text stays, and the stored title is unchanged

### Requirement: Load gate and serialized writes

The system SHALL wait for the initial prefs load before any detail read or write. Detail writes and log-sheet saves SHALL serialize through a single write queue so concurrent edits never interleave or overwrite one another. Each save SHALL resolve a fresh `SharedPreferences.getInstance()` and rewrite the full list.

#### Scenario: Edit before load waits

- **WHEN** detail opens before the initial load finishes and the person taps a star
- **THEN** the write applies after the load completes without dropping the film

### Requirement: Failures revert persisted state and keep draft text

If a detail write throws, the system SHALL revert the persisted `Film` in memory to its pre-write value, show `Couldn't save. Try again.` inline, and leave the list unchanged for that field. For a star tap, the displayed stars and rating label SHALL revert to the prior rating; for a text field, the typed draft text SHALL remain in the input controller. If a write fails during back navigation, the detail screen SHALL remain open.

#### Scenario: Rating write fails

- **WHEN** a star-tap write throws
- **THEN** the stars and rating label revert to the prior rating, `Couldn't save. Try again.` is shown inline, and the stored rating is unchanged

#### Scenario: Notes or field write fails

- **WHEN** a notes, title, or year write throws
- **THEN** the typed text stays in the field, `Couldn't save. Try again.` is shown inline, and the stored film in `reel_log_films` is unchanged

### Requirement: Share and metadata stay out

The system SHALL render zero Share or Remove widgets on detail. The system SHALL NOT read or write `director`, `runtime`, or `genre` keys.

#### Scenario: No share or remove

- **WHEN** the detail screen is open
- **THEN** no `Share`, `Share film`, or `Remove` control is present

#### Scenario: No invented metadata

- **WHEN** a film is saved from detail
- **THEN** the stored JSON has no `director`, `runtime`, or `genre` key

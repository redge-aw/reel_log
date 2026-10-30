# log-film Specification

## Purpose

Lets a person add a film they watched to the persisted list, including a blank release year and an unrated entry.

## Requirements

### Requirement: Log sheet opens from the list

The system SHALL open a log sheet when the person taps "Log a film". The sheet SHALL show a title field, a release-year field, a watched-year field, five rating stars, a notes field, Cancel, Save, and a close control.

#### Scenario: Sheet opens

- **WHEN** the person taps "Log a film"
- **THEN** the log sheet is shown over the list

### Requirement: Save requires a title

The system SHALL keep Save disabled until the title contains non-whitespace text. Once the person has interacted with the title field, if the title is empty or whitespace the system SHALL show "Enter a title." under the title field. That message SHALL clear when the title contains non-whitespace text.

#### Scenario: Empty title

- **WHEN** the title is empty
- **THEN** Save is disabled

#### Scenario: Whitespace title

- **WHEN** the title is only whitespace
- **THEN** Save is disabled

#### Scenario: Title entered

- **WHEN** the title contains non-whitespace text
- **THEN** Save is enabled

#### Scenario: Title cleared after typing

- **WHEN** the person types a title and then clears it
- **THEN** "Enter a title." is shown under the title field and Save is disabled

#### Scenario: Title message clears

- **WHEN** "Enter a title." is shown and the person enters non-whitespace text
- **THEN** the message is no longer shown and Save is enabled

### Requirement: Release year is optional and numeric

The system SHALL accept a blank release year. A non-blank year SHALL be digits only and at most four digits. A blank year SHALL be stored as absent, and the list row SHALL NOT show a year for that film. If a non-blank release year has fewer than four digits when Save is tapped, the system SHALL show "Enter a 4-digit year." under the release-year field and SHALL NOT save the film.

#### Scenario: Blank year

- **WHEN** the person saves a titled film with the release year left blank
- **THEN** the saved film has no release year and its row does not show one

#### Scenario: Year longer than four digits

- **WHEN** the person types more than four digits in the release year
- **THEN** only the first four digits are kept

#### Scenario: Short release year

- **WHEN** the person enters a titled film with a two-digit release year and taps Save
- **THEN** "Enter a 4-digit year." is shown under the release-year field and the film is not saved

### Requirement: Watched year defaults to the current year

The system SHALL set the watched year to the current calendar year when the sheet opens. The person SHALL be able to change that year before saving. A non-blank watched year SHALL be digits only and at most four digits. If the watched year does not have exactly four digits when Save is tapped, the system SHALL show "Enter a 4-digit year." under the watched-year field and SHALL NOT save the film.

#### Scenario: Default year

- **WHEN** the sheet opens
- **THEN** the watched year is the current calendar year

#### Scenario: Watched year changed

- **WHEN** the person changes the watched year to a different year and saves
- **THEN** the saved film's watched year is the changed year

#### Scenario: Watched year cleared

- **WHEN** the person clears the watched year and taps Save
- **THEN** "Enter a 4-digit year." is shown under the watched-year field and the film is not saved

#### Scenario: Short watched year

- **WHEN** the person enters a two-digit watched year and taps Save
- **THEN** "Enter a 4-digit year." is shown under the watched-year field and the film is not saved

### Requirement: Rating may be unset

The system SHALL start with no stars selected. Tapping a star SHALL set the rating to that star's count from 1 to 5. Tapping the currently selected rating SHALL clear it to unrated. An unrated film SHALL be savable and SHALL NOT change the average rating.

#### Scenario: Rating set

- **WHEN** the person taps the third star and saves
- **THEN** the saved film's rating is 3

#### Scenario: Unrated save

- **WHEN** the person saves a titled film without tapping a star
- **THEN** the film is stored as unrated and the average rating is unchanged

#### Scenario: Clear a rating

- **WHEN** the rating is 4 and the person taps the fourth star again
- **THEN** the rating returns to unrated

### Requirement: Notes are optional

The system SHALL allow Save with notes empty. Empty notes SHALL be stored as no notes. Non-empty notes SHALL be stored with surrounding whitespace removed.

#### Scenario: Empty notes

- **WHEN** the person saves a titled film with empty notes
- **THEN** the film is stored with no notes

#### Scenario: Notes trimmed

- **WHEN** the person saves a film with notes "  Great sound.  "
- **THEN** the film is stored with notes "Great sound."

### Requirement: Dismissing the sheet discards the draft

The system SHALL discard the draft when the person taps Cancel or the close control, or dismisses the sheet by tapping outside it or dragging it down. The list and the saved store SHALL stay unchanged.

#### Scenario: Cancel

- **WHEN** the person has typed a title and taps Cancel
- **THEN** the sheet closes and the film is not in the list or the saved store

#### Scenario: Close control

- **WHEN** the person has typed a title and taps the close control
- **THEN** the sheet closes and the film is not in the list or the saved store

#### Scenario: Dismiss outside the sheet

- **WHEN** the person has typed a title and taps outside the sheet or drags it down
- **THEN** the sheet closes and the film is not in the list or the saved store

### Requirement: Save persists a unique entry in watched-year order

The system SHALL append the film with a generated unique identifier no other film uses, persist the full list, close the sheet, then show `Added "{title}"` over the list, using the trimmed title. The stored title SHALL be the entered title trimmed of surrounding whitespace. The list SHALL order by watched year, later first; order within the same watched year is unspecified.

#### Scenario: Successful save

- **WHEN** the person saves a film titled " Aftersun "
- **THEN** the sheet closes, the list shows "Aftersun", and the confirmation `Added "Aftersun"` is shown
- **THEN** the saved store contains that film with the title "Aftersun" and no director field

#### Scenario: Two saves get distinct identifiers

- **WHEN** the person saves two films
- **THEN** the two saved films have different identifiers, and neither identifier matches a film already in the list

#### Scenario: Earlier watched year

- **WHEN** the person saves a film whose watched year is earlier than a film already in the list
- **THEN** the new film appears below that later film

#### Scenario: Restart

- **WHEN** the person saves a film and opens the app again
- **THEN** the film is still in the list

### Requirement: Save failure leaves the list unchanged

If persisting the full list fails, the system SHALL NOT keep the film in the list, SHALL NOT show the saved confirmation, and SHALL show `Couldn't save "{title}". Try again.` using the film's trimmed title. The sheet SHALL stay open with the draft as entered, so the person can tap Save again to retry.

#### Scenario: Write fails

- **WHEN** the person saves a film titled "Aftersun" and writing the saved store fails
- **THEN** the film is not in the list and no `Added "Aftersun"` confirmation is shown
- **THEN** the message `Couldn't save "Aftersun". Try again.` is shown
- **THEN** the sheet stays open with the entered title, year, rating, and notes still in place

### Requirement: Existing saved films still load

The system SHALL keep loading films that were saved before this change, including films saved with a release year and films whose watched value is a full date.

#### Scenario: Prior save has a year

- **WHEN** the saved store contains a film with a release year
- **THEN** that film loads and its row shows the year

#### Scenario: Prior save has a watched date

- **WHEN** the saved store contains a film whose watched value is a full date from before this change
- **THEN** that film loads and its row shows that date's year as the watched year

# Spec Delta

## Purpose

Lets a person add a film they watched to the persisted list, including a blank release year and an unrated entry.

## ADDED Requirements

### Requirement: Log sheet opens from the list

The system SHALL open a log sheet when the person taps "Log a film". The sheet SHALL show a title field, a release-year field, a date-watched field, five rating stars, a notes field, Cancel, Save, and a close control.

#### Scenario: Sheet opens

- **WHEN** the person taps "Log a film"
- **THEN** the log sheet is shown over the list

### Requirement: Save requires a title

The system SHALL keep Save disabled until the title contains non-whitespace text.

#### Scenario: Empty title

- **WHEN** the title is empty
- **THEN** Save is disabled

#### Scenario: Whitespace title

- **WHEN** the title is only whitespace
- **THEN** Save is disabled

#### Scenario: Title entered

- **WHEN** the title contains non-whitespace text
- **THEN** Save is enabled

### Requirement: Release year is optional and numeric

The system SHALL accept a blank release year. A non-blank year SHALL be digits only and at most four digits. A blank year SHALL be stored as absent, and the list row SHALL NOT show a year for that film.

#### Scenario: Blank year

- **WHEN** the person saves a titled film with the release year left blank
- **THEN** the saved film has no release year and its row does not show one

#### Scenario: Year longer than four digits

- **WHEN** the person types more than four digits in the release year
- **THEN** only the first four digits are kept

### Requirement: Date watched defaults to today

The system SHALL set date watched to the current local date when the sheet opens. The person SHALL be able to change that date before saving.

#### Scenario: Default date

- **WHEN** the sheet opens
- **THEN** date watched is today

#### Scenario: Date changed

- **WHEN** the person changes date watched to a different date and saves
- **THEN** the saved film's date watched is the changed date

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

The system SHALL allow Save with notes empty. Non-empty notes SHALL be stored with surrounding whitespace removed.

#### Scenario: Empty notes

- **WHEN** the person saves a titled film with empty notes
- **THEN** the film is stored with empty notes

#### Scenario: Notes trimmed

- **WHEN** the person saves a film with notes "  Great sound.  "
- **THEN** the film is stored with notes "Great sound."

### Requirement: Dismissing the sheet discards the draft

The system SHALL discard the draft when the person taps Cancel or the close control. The list and the saved store SHALL stay unchanged.

#### Scenario: Cancel

- **WHEN** the person has typed a title and taps Cancel
- **THEN** the sheet closes and the film is not in the list or the saved store

#### Scenario: Close control

- **WHEN** the person has typed a title and taps the close control
- **THEN** the sheet closes and the film is not in the list or the saved store

### Requirement: Save persists a unique entry in date order

The system SHALL append the film with a new id that is not already used, persist the full list, and then confirm with the film's trimmed title. The saved film's title SHALL be the entered title with surrounding whitespace removed. The visible list SHALL order films by date watched, newest first. A film with an earlier date watched SHALL NOT appear above a film watched later.

#### Scenario: Successful save

- **WHEN** the person saves a film titled " Aftersun "
- **THEN** the list shows "Aftersun" and a confirmation names "Aftersun"
- **THEN** the saved store contains that film with the title "Aftersun" and no director field

#### Scenario: Backdated entry

- **WHEN** the person saves a film whose date watched is earlier than a film already in the list
- **THEN** the new film appears below that later film

#### Scenario: Restart

- **WHEN** the person saves a film and opens the app again
- **THEN** the film is still in the list

### Requirement: Save failure leaves the list unchanged

If persisting the full list fails, the system SHALL NOT keep the film in the list, SHALL NOT show the saved confirmation, and SHALL tell the person the film was not saved.

#### Scenario: Write fails

- **WHEN** the person saves a titled film and writing the saved store fails
- **THEN** the film is not in the list and no "Added" confirmation is shown
- **THEN** a message says the film was not saved

### Requirement: Existing saved films still load

The system SHALL keep loading films that were saved with a release year before this change.

#### Scenario: Prior save has a year

- **WHEN** the saved store contains a film with a release year
- **THEN** that film loads and its row shows the year

## ADDED Requirements

### Requirement: Playlist selection UI

When a playlist URL is detected and video metadata is fetched, the system SHALL present a selection view allowing the user to choose which videos to download before adding them to the queue.

#### Scenario: Playlist selection view is shown after metadata fetch

- **WHEN** the user pastes or drops a playlist URL and metadata fetch completes
- **THEN** the system SHALL display a PlaylistSelectionView as a sheet containing the playlist title, total video count, and a scrollable list of all videos with checkboxes

#### Scenario: All videos are selected by default

- **WHEN** the PlaylistSelectionView is presented
- **THEN** all videos SHALL be checked (selected) by default

### Requirement: Select all and deselect all

The system SHALL provide buttons to select all or deselect all videos in the playlist selection view.

#### Scenario: User deselects all videos

- **WHEN** the user clicks the "deselect all" button
- **THEN** all video checkboxes SHALL be unchecked

#### Scenario: User selects all videos

- **WHEN** the user clicks the "select all" button
- **THEN** all video checkboxes SHALL be checked

### Requirement: Download button reflects selection count

The download confirmation button SHALL display the number of currently selected videos.

#### Scenario: Download button shows selected count

- **WHEN** 3 out of 10 videos are selected
- **THEN** the download button SHALL display text indicating 3 videos will be downloaded (e.g., "下載 (3)")

#### Scenario: Download button is disabled when none selected

- **WHEN** no videos are selected
- **THEN** the download button SHALL be disabled

### Requirement: Confirm selection triggers media selection flow

After the user confirms the playlist selection, the system SHALL proceed to the existing media selection flow (subtitle/audio track selection) for the selected videos.

#### Scenario: User confirms selection and proceeds to media selection

- **WHEN** the user clicks the download button with N videos selected
- **THEN** the PlaylistSelectionView SHALL dismiss
- **AND** the MediaSelectionView SHALL be presented for the N selected videos
- **AND** subtitle/audio settings SHALL apply uniformly to all selected videos

#### Scenario: Media selection fallback for unsupported tracks

- **WHEN** a selected video does not support the chosen subtitle or audio track
- **THEN** the system SHALL fall back to default settings for that video (skip the unsupported track)

### Requirement: Cancel removes placeholder task

When the user cancels the playlist selection, the system SHALL remove the placeholder task and not add any videos to the download queue.

#### Scenario: User cancels playlist selection

- **WHEN** the user clicks the cancel button in PlaylistSelectionView
- **THEN** the placeholder task SHALL be removed from the task list
- **AND** no videos SHALL be added to the download queue

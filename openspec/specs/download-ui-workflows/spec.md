# download-ui-workflows Specification

## Purpose

TBD - created by archiving change 'improve-download-ui-workflows'. Update Purpose after archive.

## Requirements

### Requirement: Context-aware paste handling

The application SHALL add HTTP(S) URLs from the clipboard when Command-V is pressed in the main download interface, SHALL preserve standard paste behavior while a text input control is active, and MUST NOT accumulate duplicate key event monitors across view appearances.

#### Scenario: Paste URLs from the main interface

- **WHEN** the main interface is active, no text input control is the first responder, and the clipboard contains two HTTP(S) URLs on separate lines
- **THEN** the application adds each URL exactly once to the download queue

#### Scenario: Paste text into settings

- **WHEN** the download command editor is the first responder and the user presses Command-V
- **THEN** the text input control receives the paste event and the application does not add a download task

#### Scenario: Main view reappears

- **WHEN** the main view disappears and appears again
- **THEN** exactly one paste event monitor handles the next Command-V event

#### Scenario: Paste while Settings has a non-text focus

- **WHEN** the Settings window is active, a non-text control is the first responder, and the user presses Command-V
- **THEN** the application preserves the event and does not add a download task


<!-- @trace
source: improve-download-ui-workflows
updated: 2026-07-13
code:
  - TubifyTests/MediaSelectionLogicTests.swift
  - TubifyTests/NotificationServiceTests.swift
  - .agents/skills/spectra-verify/SKILL.md
  - Tubify/Views/ContentView.swift
  - Tubify/Views/EmptyStateView.swift
  - Tubify/Views/SettingsView.swift
  - Tubify.xcodeproj/project.pbxproj
  - Tubify/Views/PlaylistSelectionView.swift
  - Tubify/ViewModels/DownloadManager.swift
  - Tubify/Services/PersistenceService.swift
  - Tubify/TubifyApp.swift
  - Tubify/Views/MediaSelectionView.swift
  - TubifyTests/ContentViewTests.swift
  - Tubify/Services/NotificationService.swift
  - Tubify/Views/DownloadItemView.swift
  - TubifyTests/DownloadItemViewTests.swift
  - Tubify/Models/AppSettings.swift
  - .agents/skills/spectra-analyze/SKILL.md
  - TubifyTests/SettingsViewTests.swift
  - TubifyTests/DownloadManagerTests.swift
-->

---
### Requirement: Persisted task recovery after UI activation

The application SHALL recover interrupted persisted tasks only after media-selection callbacks are available, and the recovery operation MUST be idempotent.

#### Scenario: Recover interrupted downloads

- **WHEN** persisted tasks with `downloading` and `pending` status are loaded and the main UI activates
- **THEN** the interrupted download returns to `pending` and the queue starts each pending task without duplicating work

#### Scenario: Recover metadata lookup

- **WHEN** a persisted task with `fetchingInfo` status is loaded and the main UI activates
- **THEN** the application restarts metadata lookup after callbacks are registered

#### Scenario: Recover playlist placeholder lookup

- **WHEN** a persisted `fetchingInfo` task has the playlist placeholder marker and a playlist URL
- **THEN** the application restarts playlist expansion and does not route the placeholder through single-video metadata lookup

#### Scenario: Recover expanded playlist child lookup

- **WHEN** a persisted `fetchingInfo` task represents an expanded playlist child whose group membership is not persisted
- **THEN** the application safely restarts metadata lookup for that individual task without recreating a playlist group

#### Scenario: Recover media selection with persisted options

- **WHEN** a persisted task has `waitingForMediaSelection` status and stored subtitle or audio options
- **THEN** the application presents exactly one media-selection request for that task

#### Scenario: Recover media selection without persisted options

- **WHEN** a persisted task has `waitingForMediaSelection` status without stored options
- **THEN** the application returns it to metadata lookup and does not leave it in an inert waiting state

#### Scenario: Activate recovery more than once

- **WHEN** the UI activation recovery operation is called twice with the same UI session identifier
- **THEN** only the first call starts recovery work or presents selection requests

#### Scenario: Reconnect a new UI session

- **WHEN** the first UI session disappears with an unresolved selection request and a new UI session activates
- **THEN** the application presents that unresolved request exactly once to the new session without restarting metadata lookup or queue work

#### Scenario: Selection work completes without an active UI

- **WHEN** asynchronous recovery produces a media, playlist, or video-or-playlist selection request while no UI session is active
- **THEN** the application retains the request and presents it exactly once when the next UI session activates

#### Scenario: Playlist selection view disappears with its parent

- **WHEN** a playlist selection sheet is visible and its parent UI session deactivates without an explicit confirm or cancel action
- **THEN** the application preserves the playlist placeholder and unresolved request for the next UI session

#### Scenario: Preserve non-interrupted states

- **WHEN** persisted tasks have `completed`, `failed`, `cancelled`, `paused`, `scheduled`, `livestreaming`, or `postLive` status and the main UI activates
- **THEN** the application preserves each status and starts no metadata lookup, media-selection request, or queue work for those tasks


<!-- @trace
source: improve-download-ui-workflows
updated: 2026-07-13
code:
  - TubifyTests/MediaSelectionLogicTests.swift
  - TubifyTests/NotificationServiceTests.swift
  - .agents/skills/spectra-verify/SKILL.md
  - Tubify/Views/ContentView.swift
  - Tubify/Views/EmptyStateView.swift
  - Tubify/Views/SettingsView.swift
  - Tubify.xcodeproj/project.pbxproj
  - Tubify/Views/PlaylistSelectionView.swift
  - Tubify/ViewModels/DownloadManager.swift
  - Tubify/Services/PersistenceService.swift
  - Tubify/TubifyApp.swift
  - Tubify/Views/MediaSelectionView.swift
  - TubifyTests/ContentViewTests.swift
  - Tubify/Services/NotificationService.swift
  - Tubify/Views/DownloadItemView.swift
  - TubifyTests/DownloadItemViewTests.swift
  - Tubify/Models/AppSettings.swift
  - .agents/skills/spectra-analyze/SKILL.md
  - TubifyTests/SettingsViewTests.swift
  - TubifyTests/DownloadManagerTests.swift
-->

---
### Requirement: Actionable download errors

A failed download item SHALL display a concise, non-empty error summary and SHALL provide controls to view and copy the complete stored error message.

#### Scenario: Failed task with a multiline error

- **WHEN** a failed task contains a multiline yt-dlp error message
- **THEN** the row displays the first non-empty line as a bounded summary and the details control displays the complete message

#### Scenario: Failed task without an error message

- **WHEN** a failed task has no stored error message
- **THEN** the row displays a stable localized fallback summary

#### Scenario: Copy error details

- **WHEN** the user chooses the copy action from the error details
- **THEN** the complete stored error message is written to the pasteboard

#### Scenario: Failed task with an overlong error line

- **WHEN** the first non-empty error line contains more than 160 Swift `Character` values
- **THEN** the row displays the first 159 `Character` values followed by one `…`, for a total summary length of 160


<!-- @trace
source: improve-download-ui-workflows
updated: 2026-07-13
code:
  - TubifyTests/MediaSelectionLogicTests.swift
  - TubifyTests/NotificationServiceTests.swift
  - .agents/skills/spectra-verify/SKILL.md
  - Tubify/Views/ContentView.swift
  - Tubify/Views/EmptyStateView.swift
  - Tubify/Views/SettingsView.swift
  - Tubify.xcodeproj/project.pbxproj
  - Tubify/Views/PlaylistSelectionView.swift
  - Tubify/ViewModels/DownloadManager.swift
  - Tubify/Services/PersistenceService.swift
  - Tubify/TubifyApp.swift
  - Tubify/Views/MediaSelectionView.swift
  - TubifyTests/ContentViewTests.swift
  - Tubify/Services/NotificationService.swift
  - Tubify/Views/DownloadItemView.swift
  - TubifyTests/DownloadItemViewTests.swift
  - Tubify/Models/AppSettings.swift
  - .agents/skills/spectra-analyze/SKILL.md
  - TubifyTests/SettingsViewTests.swift
  - TubifyTests/DownloadManagerTests.swift
-->

---
### Requirement: Persistent completion navigation

The application SHALL retain completed tasks by default for users without an existing auto-remove preference and SHALL open the output location when a valid completion notification is activated.

#### Scenario: New installation completes a download

- **WHEN** no auto-remove preference exists and a download completes
- **THEN** the completed task remains visible with an action that reveals the file in Finder

#### Scenario: Existing auto-remove preference

- **WHEN** a user has explicitly enabled automatic removal and a download completes
- **THEN** the application continues to remove the completed task automatically

#### Scenario: Activate completion notification

- **WHEN** the user activates a completion notification containing a valid `outputPath`
- **THEN** Finder opens and selects the downloaded file

#### Scenario: Activate notification without a valid path

- **WHEN** a notification lacks `outputPath` or references an invalid path
- **THEN** the application completes notification handling without opening an unrelated location or crashing


<!-- @trace
source: improve-download-ui-workflows
updated: 2026-07-13
code:
  - TubifyTests/MediaSelectionLogicTests.swift
  - TubifyTests/NotificationServiceTests.swift
  - .agents/skills/spectra-verify/SKILL.md
  - Tubify/Views/ContentView.swift
  - Tubify/Views/EmptyStateView.swift
  - Tubify/Views/SettingsView.swift
  - Tubify.xcodeproj/project.pbxproj
  - Tubify/Views/PlaylistSelectionView.swift
  - Tubify/ViewModels/DownloadManager.swift
  - Tubify/Services/PersistenceService.swift
  - Tubify/TubifyApp.swift
  - Tubify/Views/MediaSelectionView.swift
  - TubifyTests/ContentViewTests.swift
  - Tubify/Services/NotificationService.swift
  - Tubify/Views/DownloadItemView.swift
  - TubifyTests/DownloadItemViewTests.swift
  - Tubify/Models/AppSettings.swift
  - .agents/skills/spectra-analyze/SKILL.md
  - TubifyTests/SettingsViewTests.swift
  - TubifyTests/DownloadManagerTests.swift
-->

---
### Requirement: Single native settings experience

The application SHALL expose one macOS Settings scene and SHALL route both the main-window settings control and the standard Command-, shortcut to that scene.

#### Scenario: Open settings from the toolbar

- **WHEN** the user activates the settings control in the main window
- **THEN** the native Settings scene opens without presenting a settings sheet

#### Scenario: Open settings with the standard shortcut

- **WHEN** the user presses Command-,
- **THEN** the same Settings scene opens and no duplicate settings command is present


<!-- @trace
source: improve-download-ui-workflows
updated: 2026-07-13
code:
  - TubifyTests/MediaSelectionLogicTests.swift
  - TubifyTests/NotificationServiceTests.swift
  - .agents/skills/spectra-verify/SKILL.md
  - Tubify/Views/ContentView.swift
  - Tubify/Views/EmptyStateView.swift
  - Tubify/Views/SettingsView.swift
  - Tubify.xcodeproj/project.pbxproj
  - Tubify/Views/PlaylistSelectionView.swift
  - Tubify/ViewModels/DownloadManager.swift
  - Tubify/Services/PersistenceService.swift
  - Tubify/TubifyApp.swift
  - Tubify/Views/MediaSelectionView.swift
  - TubifyTests/ContentViewTests.swift
  - Tubify/Services/NotificationService.swift
  - Tubify/Views/DownloadItemView.swift
  - TubifyTests/DownloadItemViewTests.swift
  - Tubify/Models/AppSettings.swift
  - .agents/skills/spectra-analyze/SKILL.md
  - TubifyTests/SettingsViewTests.swift
  - TubifyTests/DownloadManagerTests.swift
-->

---
### Requirement: Accessible and consistent controls

Interactive icon controls SHALL participate in keyboard focus, SHALL expose localized accessibility labels, and primary views SHALL use semantic typography with a consistent hierarchy.

#### Scenario: Navigate controls by keyboard

- **WHEN** keyboard focus navigation is enabled and the user advances through toolbar and row actions
- **THEN** each available action can receive focus and exposes a descriptive accessibility label

#### Scenario: Present primary and secondary text

- **WHEN** the main list, settings form, playlist selector, or media selector is displayed
- **THEN** headings, body text, and captions use semantic font roles instead of unrelated fixed point sizes


<!-- @trace
source: improve-download-ui-workflows
updated: 2026-07-13
code:
  - TubifyTests/MediaSelectionLogicTests.swift
  - TubifyTests/NotificationServiceTests.swift
  - .agents/skills/spectra-verify/SKILL.md
  - Tubify/Views/ContentView.swift
  - Tubify/Views/EmptyStateView.swift
  - Tubify/Views/SettingsView.swift
  - Tubify.xcodeproj/project.pbxproj
  - Tubify/Views/PlaylistSelectionView.swift
  - Tubify/ViewModels/DownloadManager.swift
  - Tubify/Services/PersistenceService.swift
  - Tubify/TubifyApp.swift
  - Tubify/Views/MediaSelectionView.swift
  - TubifyTests/ContentViewTests.swift
  - Tubify/Services/NotificationService.swift
  - Tubify/Views/DownloadItemView.swift
  - TubifyTests/DownloadItemViewTests.swift
  - Tubify/Models/AppSettings.swift
  - .agents/skills/spectra-analyze/SKILL.md
  - TubifyTests/SettingsViewTests.swift
  - TubifyTests/DownloadManagerTests.swift
-->

---
### Requirement: Settings input feedback

The settings interface SHALL visibly identify an empty download command or a command that lacks the `$youtubeUrl` placeholder, and the folder picker SHALL use the configured local filesystem path as its starting directory.

#### Scenario: Command lacks the URL placeholder

- **WHEN** the download command does not contain `$youtubeUrl`
- **THEN** the settings interface displays a localized validation error and a reset action remains available

#### Scenario: Command contains only whitespace

- **WHEN** the download command contains only whitespace
- **THEN** the settings interface displays a localized validation error

#### Scenario: Download folder contains spaces

- **WHEN** the configured download folder is a valid local path containing spaces and the user opens the folder picker
- **THEN** the picker starts at that local directory

<!-- @trace
source: improve-download-ui-workflows
updated: 2026-07-13
code:
  - TubifyTests/MediaSelectionLogicTests.swift
  - TubifyTests/NotificationServiceTests.swift
  - .agents/skills/spectra-verify/SKILL.md
  - Tubify/Views/ContentView.swift
  - Tubify/Views/EmptyStateView.swift
  - Tubify/Views/SettingsView.swift
  - Tubify.xcodeproj/project.pbxproj
  - Tubify/Views/PlaylistSelectionView.swift
  - Tubify/ViewModels/DownloadManager.swift
  - Tubify/Services/PersistenceService.swift
  - Tubify/TubifyApp.swift
  - Tubify/Views/MediaSelectionView.swift
  - TubifyTests/ContentViewTests.swift
  - Tubify/Services/NotificationService.swift
  - Tubify/Views/DownloadItemView.swift
  - TubifyTests/DownloadItemViewTests.swift
  - Tubify/Models/AppSettings.swift
  - .agents/skills/spectra-analyze/SKILL.md
  - TubifyTests/SettingsViewTests.swift
  - TubifyTests/DownloadManagerTests.swift
-->
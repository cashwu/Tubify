# 下載介面工作流程（`download-ui-workflows`）

## Purpose

貼上、任務恢復、錯誤診斷、完成後導向、設定入口、鍵盤可存取性、設定輸入回饋，以及下載項目改名。

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

---

### Requirement: Single native settings experience

The application SHALL expose one macOS Settings scene and SHALL route both the main-window settings control and the standard Command-, shortcut to that scene.

#### Scenario: Open settings from the toolbar

- **WHEN** the user activates the settings control in the main window
- **THEN** the native Settings scene opens without presenting a settings sheet

#### Scenario: Open settings with the standard shortcut

- **WHEN** the user presses Command-,
- **THEN** the same Settings scene opens and no duplicate settings command is present

---

### Requirement: Accessible and consistent controls

Interactive icon controls SHALL participate in keyboard focus, SHALL expose localized accessibility labels, and primary views SHALL use semantic typography with a consistent hierarchy.

#### Scenario: Navigate controls by keyboard

- **WHEN** keyboard focus navigation is enabled and the user advances through toolbar and row actions
- **THEN** each available action can receive focus and exposes a descriptive accessibility label

#### Scenario: Present primary and secondary text

- **WHEN** the main list, settings form, playlist selector, or media selector is displayed
- **THEN** headings, body text, and captions use semantic font roles instead of unrelated fixed point sizes

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

---

### Requirement: Media selection window sizing

The media selection window height SHALL be 75% of the main window height, and MUST NOT be less than 250 points, so that the list of subtitle and audio options scales with the main window instead of a content-based estimate.

#### Scenario: Window scales with the main window

- **WHEN** the media selection window is presented while the main window is 600 points high
- **THEN** the media selection window height SHALL be 450 points

#### Scenario: Main window is very short

- **WHEN** 75% of the main window height is less than 250 points
- **THEN** the media selection window height SHALL be 250 points

---

### Requirement: Rename download tasks

The application SHALL let the user rename any download task except an unexpanded playlist placeholder. Double-clicking the task title, choosing 「重新命名…」 from the context menu, or pressing Return while the title has keyboard focus SHALL open the same rename window. The title SHALL be reachable with Tab, show a focus ring, and expose an accessibility label and a rename action. The window SHALL show 「輸入新的檔案名稱：」, a text field prefilled with the name currently shown in the list, and the buttons 「取消」 and 「重新命名」; Return SHALL confirm and Escape SHALL cancel. The custom name SHALL be stored separately from the metadata title and persisted with the task, the list SHALL show the custom name (trimmed of surrounding whitespace) whenever one exists, and metadata lookup, reload, webpage-title fallback, and filename-based title fallback MUST NOT replace it. Recovery logic that recognizes placeholder titles (`載入中...`, `載入播放清單中...`) MUST keep working after a rename. Renaming a task that has not completed MUST NOT interrupt, restart, or reset the progress of its download. (E1, E2, E6, E8, E9, E12, E13, E18)

#### Scenario: Rename a pending task (E1)

- **WHEN** a pending task titled 「觸控屏 Macbook，最大的優點竟然是... | 大耳朵 TV」 is renamed to 「Macbook 觸控屏」 by double-clicking its title and choosing 「重新命名」
- **THEN** the list immediately shows 「Macbook 觸控屏」 and the downloaded file is later named `Macbook 觸控屏.mp4`

#### Scenario: Rename while downloading (E2)

- **WHEN** a task at 37% download progress is renamed to 「新名稱」
- **THEN** the yt-dlp process keeps running with its progress intact, and after completion the file, the completion notification, 「在 Finder 中顯示」, and the Whispify callback use `新名稱.mp4`, and the callback `title` parameter is 「新名稱」

#### Scenario: Cancel or submit no change (E6)

- **WHEN** the user cancels the rename window, presses Escape, enters only whitespace, or enters the current name
- **THEN** nothing changes, and 「重新命名」 is disabled while the input is only whitespace

#### Scenario: Metadata arrives after a rename and the app restarts (E8)

- **WHEN** a task still showing 「載入中...」 is renamed to 「自訂」, its metadata lookup later succeeds, and the app is restarted
- **THEN** the list keeps showing 「自訂」 both before and after the restart, persisted-task recovery still restarts the metadata lookup, and the downloaded file is named `自訂.mp4`

#### Scenario: Rename a failed or cancelled task and retry (E9)

- **WHEN** a failed or cancelled task is renamed to 「新」 and retried successfully
- **THEN** the downloaded file is named `新.mp4`

#### Scenario: Rename from the context menu (E12)

- **WHEN** the user chooses 「重新命名…」 from a renamable task's context menu
- **THEN** the same rename window opens as for a double-click and can be operated with VoiceOver

#### Scenario: Playlist placeholder (E13)

- **WHEN** the user double-clicks the title of a 「載入播放清單中...」 placeholder or opens its context menu
- **THEN** no rename window opens and the context menu has no 「重新命名…」 item

#### Scenario: Rename by keyboard (E18)

- **WHEN** the user moves focus to a task title with Tab and presses Return, then types a new name and presses Return, and in another attempt presses Escape
- **THEN** Return opens the window and applies the name, Escape changes nothing, and no mouse input is needed

---

### Requirement: Apply custom names to downloaded files

When a task with a custom name finishes downloading and passes the premiere length check, the application SHALL rename the final video file and the subtitle files that belong to the task before setting `outputPath`, sending the completion notification, and triggering the callback. The callback `title` parameter SHALL be the name shown in the list (the custom name when one exists), so that it matches the callback `file`. Renaming a completed task SHALL immediately apply the same rules to the files on disk and update `outputPath` without sending the notification or callback again. File names SHALL replace `/` with `⧸` and `:` with `：`, matching yt-dlp's default sanitization, while the list shows the name as entered. Only subtitle files named `<video base name>.<language>.srt` in the video's folder, for languages in the task's `subtitleSelection` (uploaded and automatic), SHALL be renamed or copied; files are only handled inside their current folder, and `.part` intermediates are never touched. The video and its subtitles SHALL share one base name; if any target is taken by another file, the application SHALL try `名 (1)`, `名 (2)`, … until all targets are free, and MUST NOT overwrite an existing file. The task SHALL persist whether the file at `outputPath` belongs to it: files that yt-dlp actually downloaded or that the application copied belong to it, files yt-dlp reused (`__real_download` is False) do not, and tasks without a record (completed before this feature) are treated as owning their file. Owned files SHALL be renamed in place; reused files SHALL be copied to the new name with the original left untouched, after which the copy belongs to the task. A case-only rename of an owned file MUST succeed without numbering; a case-only rename of a reused file SHALL be numbered because the original is kept. A rename whose target is the current file name changes no files. (E1–E5, E7, E10, E11, E14–E17, E19)

#### Scenario: Rename a completed task with subtitles (E3)

- **WHEN** a completed task owns `舊.mp4` and `舊.zh-Hant.srt` (with `zh-Hant` selected) and is renamed to 「新」
- **THEN** the files become `新.mp4` and `新.zh-Hant.srt`, and 「在 Finder 中顯示」 reveals `新.mp4`

#### Scenario: Target video name is taken (E4)

- **WHEN** an unrelated `新.mp4` already exists and a task is renamed to 「新」 before completion or after completion
- **THEN** the files are saved as `新 (1).mp4` and `新 (1).<language>.srt`, the existing `新.mp4` is unchanged, and the list shows 「新」

#### Scenario: yt-dlp reuses an existing file (E5)

- **WHEN** `A.mp4` already exists, a new task whose yt-dlp title is also A is renamed to 「B」 before downloading, and yt-dlp reuses `A.mp4`
- **THEN** `B.mp4` is created, `A.mp4` is kept, and `outputPath` points to `B.mp4`

#### Scenario: Name contains slash and colon (E7)

- **WHEN** a waiting task is renamed to 「評測 / 重量: 心得」 and the download completes
- **THEN** the list shows 「評測 / 重量: 心得」 and the file is named `評測 ⧸ 重量： 心得.mp4`

#### Scenario: Completed task file is missing (E10)

- **WHEN** the file of a completed task has been moved or deleted by the user and the task is renamed to 「新」
- **THEN** an error alert explains that the file cannot be found, and the list name and `outputPath` stay unchanged

#### Scenario: Rename fails when the download completes (E11)

- **WHEN** a task's custom name cannot be applied at completion (for example, it exceeds the file system name length limit)
- **THEN** the task is still marked completed, `outputPath`, the completion notification, and the callback use the original yt-dlp file, the list shows the original file's base name, and the failure reason is logged

#### Scenario: Case-only rename of an owned file (E14)

- **WHEN** a completed task owns `abc.mp4` and is renamed to 「ABC」
- **THEN** the file becomes `ABC.mp4`, not `ABC (1).mp4`

#### Scenario: Rename a reused file after restart (E15)

- **WHEN** a task without a custom name completed by reusing an existing `A.mp4`, the app restarts, and the task is renamed to 「B」 and later to 「C」
- **THEN** the first rename creates `B.mp4` and keeps `A.mp4` with `outputPath` pointing to `B.mp4`, and the second rename renames `B.mp4` to `C.mp4`

#### Scenario: Only a subtitle target is taken (E16)

- **WHEN** a task with English subtitles selected is renamed to 「新」, no `新.mp4` exists, but an unrelated `新.en.srt` does, and the download completes
- **THEN** the video and subtitle are saved as `新 (1).mp4` and `新 (1).en.srt`, and the existing `新.en.srt` is unchanged

#### Scenario: Subtitles that do not belong to the task (E17)

- **WHEN** a completed task without selected subtitles owns `A.mp4`, a `A.en.srt` from another source sits next to it, and the task is renamed to 「B」
- **THEN** only the video becomes `B.mp4` and `A.en.srt` is unchanged

#### Scenario: Case-only rename of a reused file (E19)

- **WHEN** a completed task's `abc.mp4` was reused by yt-dlp and the task is renamed to 「ABC」
- **THEN** `ABC (1).mp4` is created and `abc.mp4` is kept

## 來源 change

- 2026-07-13-improve-download-ui-workflows（詳見 [completed-tasks.md](../completed-tasks.md)）
- 媒體選擇視窗高度（commit `63d9f63`，未經 OpenSpec 流程，需求由實作反推整理）
- 2026-11-07-rename-download-title（[設計](../design/2026-11-07-rename-download-title.md)、[任務](../task/2026-11-07-rename-download-title.md)）

## 對應程式碼

- `Tubify/Models/AppSettings.swift`
- `Tubify/Models/DownloadTask.swift`
- `Tubify/Services/CallbackService.swift`
- `Tubify/Services/NotificationService.swift`
- `Tubify/Services/PersistenceService.swift`
- `Tubify/TubifyApp.swift`
- `Tubify/Utilities/OutputFileRenamer.swift`
- `Tubify/ViewModels/DownloadManager.swift`
- `Tubify/Views/ContentView.swift`
- `Tubify/Views/DownloadItemView.swift`
- `Tubify/Views/EmptyStateView.swift`
- `Tubify/Views/MediaSelectionView.swift`
- `Tubify/Views/PlaylistSelectionView.swift`
- `Tubify/Views/RenameTitleView.swift`
- `Tubify/Views/SettingsView.swift`
- `TubifyTests/CallbackServiceTests.swift`
- `TubifyTests/ContentViewTests.swift`
- `TubifyTests/DownloadItemViewTests.swift`
- `TubifyTests/DownloadManagerRenameTests.swift`
- `TubifyTests/DownloadManagerTests.swift`
- `TubifyTests/DownloadTaskTests.swift`
- `TubifyTests/MediaSelectionLogicTests.swift`
- `TubifyTests/NotificationServiceTests.swift`
- `TubifyTests/OutputFileRenamerTests.swift`
- `TubifyTests/SettingsViewTests.swift`

# YouTube 直播結束回放（`youtube-post-live-replay`）

## Purpose

定義 `live_status = post_live` 的回放在「可下載」「暫態處理中」「失敗」之間的任務狀態、手動重試行為，以及首播倒數錯誤的排程判定。

## Requirements

### Requirement: Downloadable post-live replay detection

The system SHALL treat a YouTube video with `live_status = post_live` as downloadable when yt-dlp metadata includes at least one usable media format for the replay. Usable media formats MUST be yt-dlp media formats that the existing download flow can turn into a complete downloadable audio/video option, including combined video/audio formats, pairable separate video and audio formats, DASH media formats, or HLS media formats. A single unpaired video-only entry, a single unpaired audio-only entry, thumbnails, storyboards, metadata-only entries, and entries without audio or video codecs MUST NOT count as usable media formats.

#### Scenario: post_live metadata has downloadable formats

- **WHEN** metadata for a YouTube URL reports `live_status = post_live` and includes usable media formats
- **THEN** the system SHALL continue the normal media option and download queue flow for that task

##### Example: post_live replay manifest is available

- **GIVEN** metadata for `https://www.youtube.com/watch?v=TR_NgGeXWGc` reports `live_status = post_live` and raw formats include video-only `format_id = "137"` plus audio-only `format_id = "140"` that the existing flow can pair as download option `137+140`
- **WHEN** the task metadata is processed
- **THEN** the task SHALL be eligible for download instead of remaining in `postLive`

#### Scenario: post_live follow-up format lookup has downloadable formats

- **WHEN** initial metadata for a YouTube URL reports `live_status = post_live` and the follow-up format lookup returns usable media formats
- **THEN** the system SHALL continue the normal media option and download queue flow for that task

#### Scenario: post_live metadata has no downloadable formats

- **WHEN** metadata for a YouTube URL reports `live_status = post_live` and no usable media formats are available
- **THEN** the system SHALL mark the task as `postLive` and SHALL NOT start the download process

#### Scenario: post_live metadata has only excluded format entries

- **WHEN** metadata for a YouTube URL reports `live_status = post_live` and formats contain only unpaired video-only entries, unpaired audio-only entries, thumbnails, storyboards, metadata-only entries, entries without audio or video codecs, manifest-only entries, or stream entries that cannot form a complete download option
- **THEN** the system SHALL treat the metadata as having no usable media formats
- **THEN** the system SHALL mark the task as `postLive` and SHALL NOT start the download process

#### Scenario: post_live format lookup returns ended-live error

- **WHEN** metadata for a YouTube URL reports `live_status = post_live` and the follow-up format lookup returns an ended-live extractor error
- **THEN** the system SHALL mark the task as `postLive`
- **THEN** the system SHALL NOT start the download process

#### Scenario: post_live format lookup returns non-ended-live error

- **WHEN** metadata for a YouTube URL reports `live_status = post_live` and the follow-up format lookup returns an error that is not an ended-live extractor error
- **THEN** the system SHALL mark the task as `failed`
- **THEN** the system SHALL preserve the non-ended-live error message
- **THEN** the system SHALL send the generic failed download notification used by the existing failed download flow

---

### Requirement: Ended-live extractor errors are transient post-live states

The system SHALL classify yt-dlp ended-live extractor errors as transient post-live processing states instead of permanent download failures.

#### Scenario: download receives ended-live extractor error

- **WHEN** yt-dlp returns an error containing `This live event has ended.` for a downloading task
- **THEN** the system SHALL mark the task as `postLive`
- **THEN** the system SHALL preserve a user-readable message explaining that the replay is still processing or not yet available
- **THEN** the system SHALL NOT send a generic failed download notification for that transient state

##### Example: ended-live error classification

| yt-dlp error | Expected task status | Generic failure notification |
| ----- | ----- | ----- |
| `ERROR: [youtube] TR_NgGeXWGc: This live event has ended.` | `postLive` | not sent |
| `ERROR: [youtube] abc123: Video unavailable` | `failed` | sent |

---

### Requirement: Manual retry rechecks post-live replay availability

The system SHALL allow a user to retry a `postLive` task and SHALL re-run metadata and download checks instead of reusing the previous post-live result.

#### Scenario: retrying a postLive task

- **WHEN** the user retries a task with status `postLive`
- **THEN** the system SHALL clear the transient error message
- **THEN** the system SHALL reset task progress to zero
- **THEN** the system SHALL enqueue the task for the normal metadata and download flow

##### Example: replay becomes available after retry

- **GIVEN** a task was marked `postLive` because yt-dlp returned `This live event has ended.`
- **WHEN** the user retries after yt-dlp metadata includes format `137+140`
- **THEN** the task SHALL proceed as a normal downloadable video

---

### Requirement: Upcoming premiere extractor errors keep the task scheduled

The system SHALL treat YouTube upcoming-premiere extractor errors as a scheduled premiere, both when fetching metadata and when downloading, instead of queueing the task or failing it. YouTube shows `Premieres in X minutes` during the countdown and switches to `Premiere will begin shortly` in the last minutes; both are upcoming-premiere errors.

#### Scenario: metadata or download receives an upcoming-premiere error

- **WHEN** yt-dlp returns an error containing `Premieres in` or `Premiere will begin` for a YouTube task, including per-video media option lookups after playlist selection
- **THEN** the system SHALL mark the task as `scheduled` and SHALL NOT enqueue it for download
- **THEN** the system SHALL set `premiereDate` from the countdown when present, and leave it empty otherwise (UI shows「尚未首播」)
- **THEN** the system SHALL NOT send a generic failed download notification

##### Example: upcoming-premiere error classification

| yt-dlp error | Expected task status | `premiereDate` |
| ----- | ----- | ----- |
| `ERROR: [youtube] sV7cOFFZsPk: Premieres in 81 minutes` | `scheduled` | now + 81 minutes |
| `ERROR: [youtube] nGxDfmaRlB0: Premiere will begin shortly` | `scheduled` | empty |

若「Premiere will begin shortly」未被辨識，任務會被當成一般影片排入下載；首播開始後 yt-dlp 改錄即時串流，ffmpeg 不輸出進度，任務停在 0%。

## 來源 change

- 2026-06-11-fix-post-live-replay-downloads（詳見 [completed-tasks.md](../completed-tasks.md)）

## 對應程式碼

- `Tubify/Services/NotificationService.swift`
- `Tubify/Services/YTDLPService.swift`
- `Tubify/Services/YouTubeMetadataService.swift`
- `Tubify/Utilities/PremiereErrorParser.swift`
- `Tubify/ViewModels/DownloadManager.swift`
- `Tubify/Views/DownloadItemView.swift`
- `TubifyTests/ContentViewTests.swift`
- `TubifyTests/DownloadManagerTests.swift`
- `TubifyTests/PremiereErrorParserTests.swift`
- `TubifyTests/YTDLPServiceTests.swift`
- `TubifyTests/YouTubeMetadataServiceTests.swift`

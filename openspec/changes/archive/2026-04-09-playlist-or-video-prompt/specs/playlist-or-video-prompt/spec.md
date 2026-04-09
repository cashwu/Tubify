## ADDED Requirements

### Requirement: Detect ambiguous playlist-video URL

The system SHALL detect when a pasted or dropped YouTube URL contains both a video ID (`v=` parameter) and a playlist ID (`list=` parameter).

#### Scenario: URL contains both v= and list=

- **WHEN** user pastes or drops a URL like `https://www.youtube.com/watch?v=abc123&list=PLxyz`
- **THEN** the system SHALL present a choice dialog before proceeding with any download flow

#### Scenario: URL contains only list= without v=

- **WHEN** user pastes or drops a pure playlist URL (contains `list=` but no `v=`)
- **THEN** the system SHALL proceed directly to the existing playlist selection flow without showing the choice dialog

#### Scenario: URL contains only v= without list=

- **WHEN** user pastes or drops a single video URL (contains `v=` but no `list=`)
- **THEN** the system SHALL proceed directly to the existing single video download flow

### Requirement: Video-or-playlist choice dialog

The system SHALL present a dialog with three options when an ambiguous URL is detected.

#### Scenario: User chooses video

- **WHEN** user selects the "影片" (Video) option
- **THEN** the system SHALL strip playlist-related parameters (`list`, `index`) from the URL and proceed with the single video download flow

#### Scenario: User chooses playlist

- **WHEN** user selects the "播放清單" (Playlist) option
- **THEN** the system SHALL proceed with the existing playlist selection flow using the original URL

#### Scenario: User chooses cancel

- **WHEN** user selects the "取消" (Cancel) option
- **THEN** the system SHALL discard the URL and take no further action

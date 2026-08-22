## Summary

修正「影片有多個配音音軌時，媒體選擇視窗不顯示音軌區塊」的缺陷：媒體選項查詢與實際下載都改為明確要求 yt-dlp 額外納入會列出配音音軌的 player client，並讓使用者明確選定的音軌語言在無法取得時明確失敗，而不是靜默改用原聲。

## Motivation

這是一個 Bug Fix。使用者回報某些明明有多國配音的影片，媒體選擇視窗只出現字幕區塊、沒有音軌區塊。

實測（yt-dlp 2026.07.04，影片 `https://www.youtube.com/watch?v=Af6i6ChAVTw`）確認根因：

- app 目前的媒體選項查詢引數為 `-J --skip-download --no-playlist`，未指定任何 `--extractor-args`，yt-dlp 自行選用 android vr client，回傳的 `formats` 只有 4 筆純音訊格式且語言全為 `en`。
- 同一支影片加上 `--extractor-args "youtube:player_client=default,web_embedded"` 後，`formats` 增為 116 筆、純音訊 93 筆、涵蓋 22 種語言，`subtitles` 維持 24 筆，stderr 沒有任何 WARNING 或 ERROR。
- 因此 `DownloadManager` 取得的 `filteredAudioTracks` 只有 `en` 一筆，卡在 `filteredAudioTracks.count > 1` 的門檻，音軌區塊不會出現。解析程式本身正確，是輸入的 JSON 就缺配音音軌。

第二個獨立缺陷在下載路徑。使用者若選了配音語言，`YTDLPService` 會把 format 字串改寫成帶 `[language=xx]` 並附上原字串作為 fallback。實測在缺少 JavaScript runtime 的環境下，yt-dlp 印出 `n challenge solving failed`、配音格式從清單中消失，選擇器因而落到 fallback，最終下載的是英文原聲格式 `251` 而非日文的 `251-0`，且整個流程以成功結束、不留任何錯誤。使用者選了日文卻拿到英文，沒有任何訊號。

這兩點合在一起才是完整缺陷：只修偵測，使用者選得到配音卻可能拿到原聲；只修下載，選單根本不會出現。

## Proposed Solution

1. **媒體選項偵測納入 web_embedded client**：`fetchMediaOptions` 的兩次 invocation 都加上 `--extractor-args "youtube:player_client=default,web_embedded"`。採 `default,web_embedded` 而非單獨 `web_embedded`，因為 yt-dlp 會合併兩組 client 的 format 清單，既取得配音音軌，也保留現有 default client 既有的 format 覆蓋率與下載可靠性。
2. **下載路徑套用同一組 client**：只有在使用者明確選定音軌語言時，把同一組 `--extractor-args` 注入下載指令範本；範本已含 `--extractor-args` 時不重複注入。若下載 invocation 仍走 default client，`[language=xx]` 匹配不到任何 format。
3. **明確選定的語言不得靜默改用其他語言**：改寫 format 字串時，語言限制套用到每一個 alternative，並移除「原始 format 字串」這個未帶語言限制的 fallback。取不到該語言時 yt-dlp 以既有的 format 不可用錯誤失敗，由現有的錯誤呈現機制回報，而不是靜默交付原聲。

## Non-Goals

- 不擴大 `LanguageFilter` 的支援語言清單，維持 `en`／`ja`／`zh`。
- 不調整 `MediaSelectionView` 與 `DownloadManager` 現有的 `filteredAudioTracks.count > 1` 顯示門檻。
- 不處理 JavaScript runtime（deno／node）或 PO Token 的安裝與偵測；本變更只確保缺少它們時失敗是可見的。
- 不變更字幕偵測與 cookies 兩階段策略的既有行為。
- 不改動使用者可編輯的預設下載指令範本內容。
- 不改動 `fetchVideoInfo` 的引數，因此 post_live 的兩段可下載性判定會使用不同的 player client 集合；此不對稱與其後果記於 design 的 D10 與 Risks。
- 不為非 YouTube 網址另立分支：媒體選項查詢與選定語言時的下載注入都不分站台，`youtube:` 前綴的 extractor args 對其他 extractor 惰性（已實測）。
- 不為「format 不可得」新增帶 cookies 的重試訊號。

## Alternatives Considered

- **單獨使用 `player_client=web_embedded`**：同樣能取得 22 種語言，但會完全取代 default client 的 format 清單。default client 目前支撐既有下載路徑，取代它會把一個尚未量測的迴歸風險引入所有下載，包括不含配音的一般影片。改用合併寫法沒有這個代價。
- **維持偵測不變，僅在下載時處理語言**：選單不會出現，使用者沒有入口，等於沒修。
- **保留現有 fallback，改以下載後檢查實際音軌語言**：需要新增輸出檔的探測步驟與新的失敗狀態，成本高於直接讓 format 選擇器失敗，且無法在下載開始前就阻止。
- **只對 YouTube URL 注入 `--extractor-args`**：`youtube:` 前綴的 extractor args 對其他 extractor 是惰性的（實測 `https://archive.org/details/BigBuckBunny_124` 帶與不帶該引數，回傳的 title 與 3 筆 formats 完全相同），額外的 URL 判斷會讓 `YTDLPService` 依賴 `DownloadManager` 的 `isValidYouTubeURL`，跨層依賴的成本高於收益。

## Capabilities

### New Capabilities

- `audio-track-selection`：配音音軌的偵測來源、下載時的 client 一致性，以及明確選定語言時的失敗行為。

### Modified Capabilities

- `subtitle-selection`：媒體選項查詢的 invocation 引數集合需納入新增的 `--extractor-args`，現行 requirement 明文限定「不含其他引數」。

## Impact

- Affected specs:
  - openspec/specs/subtitle-selection/spec.md
  - openspec/specs/audio-track-selection/spec.md
- Affected code:
  - New:
    - (none)
  - Modified:
    - Tubify/Services/YouTubeMetadataService.swift
    - Tubify/Services/YTDLPService.swift
    - TubifyTests/YouTubeMetadataServiceTests.swift
    - TubifyTests/YTDLPServiceTests.swift
  - Removed:
    - (none)

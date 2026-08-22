<!-- cash-apply implementation notes | change: dubbed-audio-track-selection | initialized: 2026-08-21 00:00 | no entries below means no deviations or open questions were recorded -->

## 2026-08-21 18:22 — 5.6 以既有 post_live 迴歸測試取代新增測試
- 類別：deviation
- 任務：5.6
- 內容：`tasks.md` 5.6 要求在 `TubifyTests/YouTubeMetadataServiceTests.swift` 新增 post_live 解析層迴歸測試。實作時發現既有測試 `testPostLiveMediaOptionsStillParseLiveStatusAndFormats`（由 change `cookieless-subtitle-detection` 引入，commit 59597ef）已逐項涵蓋該 task 指名的全部斷言：以 `MetadataFixture` 佈置 `live_status` 為 `post_live` 且含 `release_timestamp` 與一組 formats 的 JSON、呼叫 `fetchMediaOptions`、斷言 `liveStatus`、`releaseTimestamp`、`formats` 與 `YTDLPFormat.hasUsableMediaFormats` 的判定。改以執行該既有測試作為 5.6 的 verification evidence，未新增內容重複的第二個測試。
- 原因：交付的觀察行為與驗收標準不變——design D10 指派給 5.6 的驗證責任（1.4 的引數改動未波及 `fetchMediaOptions` 的解析路徑）已由該既有測試在新引數下通過而成立。新增一個斷言完全相同的測試違反 Focused Implementation Discipline 的 Reuse 判準，且會讓同一條迴歸有兩處需同步維護。

## 2026-08-21 22:32 — DownloadManagerTests 出現間歇性 test host crash
- 類別：open-question
- 任務：n/a
- 內容：執行 `./Scripts/package-app.sh` 的測試階段時，`DownloadManagerTests.testRecoveryStartsInterruptedAndPendingDownloadsOnlyOnce()` 使 test host 崩潰（日誌可見 `Tubify 已關閉` 後 xcodebuild 以新 PID 重啟，該次只跑完 261/338 個測試並以 `** TEST FAILED **` 結束），非斷言失敗。其後以 `-only-testing` 單獨執行該測試 3 次、以及帶本變更執行完整套件 2 次（各 338/338）皆通過，將本變更 stash 後執行 baseline 完整套件（325/325）亦通過，無法穩定重現。該測試透過 `mockYTDLPService` 執行，不經過本變更改動的 `YTDLPService.download`／`injectExtractorArgs`／`injectLanguageIntoFormat` 與 `YouTubeMetadataService.fetchMediaOptions`，因此判定與本變更無因果關係。假設：屬既有的 recovery 路徑併發競態或 test host teardown 問題。
- 原因：依 Focused Implementation Discipline，不相關的既有缺陷不在本次 diff 內修，但它會讓 `package-app.sh` 的測試關卡間歇性擋下打包，使用者需知道其存在並決定是否另立 change 追查。

## 2026-08-21 22:52 — 5.9 驗收點三改以 format id 解析作為 oracle
- 類別：deviation
- 任務：5.9
- 內容：`tasks.md` 5.9 驗收點三指定「以 `ffprobe -show_streams` 檢查輸出檔的音訊串流語言標籤為 `ja`」。實際驗證（使用者選定 `zh-Hant`，TaskID `A2F01543-2A5A-4618-B3AC-317BFC98159A`）中，輸出檔 `/Users/cash/Downloads/tubify/Last To Leave Mansion, Keeps It.mp4` 的 `ffprobe` 音訊串流標籤為 `TAG:language=und`。改以下列等效證據判定驗收點三成立：把該次 `執行命令` 中的 `-f` 值原樣交給 yt-dlp 解析（`--simulate --print "%(format_id)s"`，同一組 `--extractor-args`），結果為 `399+140-12`，而 `140-12` 的 metadata 為 `language=zh-Hant`、`format_note=Chinese (Traditional), medium`、`abr=129.473`；輸出檔實測為 `aac / 128000 bps / 2ch`、視訊高度 `1080`，與 `399`+`140-12` 吻合。
- 原因：交付的觀察行為與驗收標準不變——delta spec 要求的是「MUST NOT 以其他語言的音軌完成下載」，而非容器需帶語言標籤。`und` 來自 yt-dlp 合併 mp4 時未寫入語言 metadata（app 未傳 `--embed-metadata`），與音軌選擇正確與否無關，因此原 oracle 在此路徑上不具鑑別力；format id 的語言屬性是對同一條 requirement 更直接的觀察。

## 2026-08-21 22:52 — 輸出檔未帶音訊語言 metadata
- 類別：open-question
- 任務：n/a
- 內容：選定配音語言並下載成功後，輸出檔的音訊串流語言標籤為 `und` 而非所選語言，因為下載指令未帶 `--embed-metadata`（或等效的 `-metadata:s:a:0 language=`）。後果是使用者在播放器或後續工具中看不出該檔案是哪個語言的配音，多檔管理時無法從檔案本身分辨。假設：本變更範圍只涵蓋「選對音軌」，不涵蓋「把語言寫進容器」，因此不在本次 diff 內處理。
- 原因：proposal 的 Non-Goals 未提及容器 metadata，delta spec 也未要求，逕自加上 `--embed-metadata` 會改動使用者可編輯的下載指令範本行為（proposal 明列不改動範本內容），屬範圍外決定，需使用者判斷是否另立 change。

## 2026-08-21 22:58 — 輸出檔未帶音訊語言 metadata：使用者決定不處理
- 類別：open-question
- 任務：n/a
- 內容：本條為 2026-08-21 22:52「輸出檔未帶音訊語言 metadata」的 resolution。使用者在本次 session 明確決定不處理該問題，理由是實際使用情境中不太會對同一支影片下載多種語言的音訊，因此檔案本身無法分辨配音語言不構成困擾。不新增 `--embed-metadata`，不另立 change。
- 原因：該問題的成本效益由使用者的實際使用型態決定，而非由 spec 推導；使用者已在知情下（知道標籤為 `und`、知道修法是加 `--embed-metadata`、知道那會動到指令範本）作出取捨。原 open-question 條目保留為歷史記錄，不再阻塞本 change。

## 2026-08-21 23:05 — DownloadManagerTests 間歇性 crash：使用者決定接受現況
- 類別：open-question
- 任務：n/a
- 內容：本條為 2026-08-21 22:32「DownloadManagerTests 出現間歇性 test host crash」的 resolution。使用者在本次 session 明確決定接受現況，不就該 flake 另立 change 追查。已知影響為 `./Scripts/package-app.sh` 的測試關卡會偶發性擋下打包，屆時可確認失敗項目確為該測試後以 `--skip-tests` 重跑。
- 原因：該 flake 與本 change 無因果關係（測試走 `mockYTDLPService`，不經過本次改動的 `YTDLPService.download`／`injectExtractorArgs`／`injectLanguageIntoFormat` 與 `YouTubeMetadataService.fetchMediaOptions`），且在 3 次單獨執行、3 次完整套件執行與 1 次 baseline 執行中皆無法重現；使用者已在知情下作出取捨。原 open-question 條目保留為歷史記錄，不再阻塞本 change。

## 2026-08-21 23:20 — 5.9 驗收點二以 zh-Hant 取代 ja 執行
- 類別：deviation
- 任務：5.9
- 內容：`tasks.md` 5.9 驗收點二指定「選定日文音軌並確認送出」，驗收點一指定確認音軌清單「依 `LanguageFilter` 過濾後預期至少含英文與日文」。實際執行的那一次（TaskID `A2F01543-2A5A-4618-B3AC-317BFC98159A`）選定的是 `zh-Hant` 而非 `ja`。驗收點二的兩項斷言在該次執行下成立：`執行命令` 的 `-f` 值為 `bv*[ext=mp4]+ba[ext=m4a][language=zh-Hant]/bv*+ba[language=zh-Hant]/b[language=zh-Hant]`，依 delta spec 的 alternative 定義切開後每一段都含 `[language=zh-Hant]`；該指令含 `--extractor-args` 與 `youtube:player_client=default,web_embedded`。驗收點一改以可稽核的解析層 oracle 承接：對同一支影片以本變更的引數集合實際查詢 yt-dlp（2026.07.04）取得的 metadata，其純音訊軌語言共 22 種，套用 `LanguageFilter.isSupportedLanguage`（前綴 `en`／`ja`／`zh`，`Tubify/Models/SubtitleInfo.swift:6`）過濾後為 `["en", "ja", "zh-Hans", "zh-Hant"]`，數量 4 滿足 `filteredAudioTracks.count > 1`，且同時包含 `en` 與 `ja`，即 delta spec `##### Example: 多配音影片出現音軌區塊` 的「音軌清單 SHALL 同時包含 `en` 與 `ja`」。使用者另已確認媒體選擇視窗的音軌區塊確實出現且可選取。未直接觀察 UI 清單的逐項渲染結果。
- 原因：交付的觀察行為與驗收標準不變。`ja` 與 `zh-Hant` 在本變更涉及的每一段程式路徑上都是同一條路徑的同一種輸入——兩者都通過 `LanguageFilter.isSupportedLanguage`、都不是該影片的原聲語言（原聲為 `en`）、都經由同一個 `injectAudioLanguage`／`injectLanguageIntoFormat` 改寫、都由同一組 `--extractor-args` 供給 format，因此對 C3、C4、C5 的鑑別力相同；spec 的 requirement 本身也以語言代碼為參數而非限定 `ja`。以 metadata 解析結果作為驗收點一的 oracle，比「使用者回報看到幾個選項」更可稽核，且能直接對應 spec Example 指名的 `en` 與 `ja`。

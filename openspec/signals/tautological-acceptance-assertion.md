---
id: tautological-acceptance-assertion
type: recurring-finding
status: open
occurrences: 2
first_seen: 2026-08-21
last_seen: 2026-08-21
links:
  - openspec/changes/cookieless-subtitle-detection/reviews/propose-r1.md
  - openspec/changes/dubbed-audio-track-selection/reviews/propose-r1.md
---

# 驗收斷言恆真，實作寫錯也不會失敗

Contract 或 tasks 指定的驗收方式若比較的是兩個依定義相等的東西，或斷言的對象在受測型別上根本沒有可觀察的成員，該驗收就沒有鑑別力：實作正確會通過，實作忽略該條款也會通過，甚至在依賴缺失的機器上兩邊同為 `nil` 而一起通過。這與「觸發路徑不可達」（見 [[unreachable-guard-or-dead-test]]）不同——測試確實有執行，問題出在斷言本身無法區分正確與錯誤的實作。

指定驗收方式時 SHALL 先回答「若實作違反這一條，哪一個斷言會失敗」；答不出來就代表該驗收不成立。為新注入點寫驗收時，SHALL 斷言注入確實取代了預設來源（例如指向 fixture 後該 fixture 必須留下可觀察的痕跡），而非拿注入後的結果與預設結果互比。

## Occurrences

- 2026-08-21 — `cookieless-subtitle-detection` — cash-propose round 1（Reviewer A 與 Reviewer B 獨立提出，confidence 85，Warning）：為了讓兩階段 cookies 策略可測，design 決定為 `YouTubeMetadataService` 新增 `init(ytdlpPathProvider:)`，Contract 指定的驗收卻是「以預設方式建立的實例，其 yt-dlp 路徑解析行為與 `shared` 相同」。該 actor 沒有任何暴露路徑解析結果的成員，且預設實例與 `shared` 本來就呼叫同一個 `YTDLPService.shared.findYTDLPPath()`，兩者相等是定義上的恆等式；在未安裝 yt-dlp 的機器上兩者同為 `nil`，測試照樣全綠。改為行為式驗收後（provider 指向 fixture 執行檔時，fixture 必須留下 invocation 記錄——實作若忽略 provider 而沿用預設解析，該斷言必定失敗），round 2 的 Reviewer V 判定 resolved。同一輪 reviewer 也指出附帶的第二個斷言「provider 指向不存在路徑時拋出 `MetadataError`」鑑別力較弱：忽略 provider 的實作在裝有 yt-dlp 的機器上多半也會以其他原因拋出同型錯誤而矇混通過。
- 2026-08-21 — `dubbed-audio-track-selection` — cash-propose round 1（Reviewer A，confidence 88，Warning）：為驗證 format 切分是否 bracket-aware 而寫的 task，驗收方式是「結果的 alternative 數量與原字串一致」。對 `ba[format_note*=A/B]+bv` 而言，bracket-aware 實作與 naive 實作在各自的計數慣例下都會與原字串相等，無論實作對錯、無論用哪一種計數，斷言都通過。已改為完整字串相等斷言（預期 `ba[format_note*=A/B]+bv[language=ja]`），該字串對 naive `/` 切分具鑑別力，round 2 的 Reviewer V 判定 resolved。

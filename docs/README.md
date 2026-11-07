# Tubify 文件

## 專案規格與開發紀錄

| 文件 | 內容 |
| ---- | ---- |
| [specs/](specs/README.md) | 目前生效的 8 份功能規格（要什麼、行為契約） |
| [tdd.md](tdd.md) | TDD 開發規範：Red／Green／Refactor、離線測試隔離、驗證指令與完成條件 |
| [completed-tasks.md](completed-tasks.md) | 10 個已完成 change、共 143 項 task 的紀錄（為什麼做、做了什麼、怎麼驗證） |
| [design/](design/README.md) | 各 change 的設計文件（脈絡、決策與替代方案、風險、Implementation Contract） |
| [task/](task/) | 進行中 change 的任務文件（範圍、依賴、狀態與驗收引用），與 `design/` 同名對應 |
| [implementation-notes.md](implementation-notes.md) | 實作期間的偏離、待決問題與其解決 |
| [review-signals.md](review-signals.md) | review 中反覆出現的 35 類缺陷，依主題分組，可當撰寫規格與測試時的檢查清單 |

建議閱讀順序：先看 `specs/` 了解行為，再依興趣讀 `completed-tasks.md` 找到對應 change，最後深入該 change 的 `design/`。

## 整合與修改指南

| 文件 | 內容 |
| ---- | ---- |
| [tubify-integration-spec.md](tubify-integration-spec.md) | Tubify 與 Whispify 的 URL Scheme 整合規格 |
| [whispify-tubify-integration-plan.md](whispify-tubify-integration-plan.md) | Whispify 端的整合實作計畫 |
| [tubify-modification-guide.md](tubify-modification-guide.md) | Tubify 端的修改指南 |

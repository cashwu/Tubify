<!-- cash-apply implementation notes | change: cleanup-orphaned-part-files | initialized: 2026-08-21 10:07 | no entries below means no deviations or open questions were recorded -->

## 2026-08-21 10:12 — seam 測試順序調整至 2.1 之後

- 類別：deviation
- 任務：1.10–1.13、1.15–1.18
- 內容：`tasks.md` 的文件順序是第 1 節全部測試先於第 2 節實作，但 seam 測試（1.10–1.13、1.15–1.17）需要斷言 `CleanupOutcome` 與傳入 `cleanupObserver`，這兩者由 task 2.1 建立；1.18 需要 `Darwin.unlink` 但不依賴新型別，為與其餘 seam 測試同批撰寫也一併後移。依 tasks.md 字面順序撰寫會因型別不存在而編譯失敗，無法取得任何 red 訊號。因此先執行 2.1 建立型別與參數（不含清理邏輯），再撰寫 1.10–1.13、1.15–1.18，最後執行 2.2、2.3。
- 原因：要交付的觀察行為、interface／資料形狀、失敗模式與驗收標準完全不變，改變的只是同一批工作的執行順序；替代做法不需要 a synchronization primitive, identity/generation type, or state machine not defined in design.md。每個 task 的驗收證據仍逐一取得，最終 2.3 會執行 1.2 至 1.18 全部測試。

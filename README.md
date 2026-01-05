# Tubify

一款簡潔的 macOS YouTube 影片下載器，使用 yt-dlp 作為後端。

## 系統需求

- macOS 14 (Sonoma) 或更新版本
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) 已安裝
- [ffmpeg](https://ffmpeg.org/)（選用，用於合併高畫質影音串流）
- 完整磁碟存取權限（選用，用於讀取 Safari cookies 下載需要登入的影片）

> **注意**：由於 App 使用 ad-hoc 簽署，每次透過 DMG 更新後需要重新授權完整磁碟存取權限。這是 macOS 安全機制的限制。

## 安裝 yt-dlp

使用 Homebrew 安裝：

```bash
brew install yt-dlp
```

或使用 pip：

```bash
pip install yt-dlp
```

## 安裝 ffmpeg（選用）

```bash
brew install ffmpeg
```

## 建置與執行

直接開啟 `Tubify.xcodeproj` 即可建置與執行。

如需重新產生專案檔，可使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```bash
xcodegen generate
```

### 打包發佈

使用打包腳本建立 DMG 發佈檔：

```bash
./Scripts/package-app.sh
```

腳本會執行測試、建置 Release 版本並打包成 DMG 檔案。可用選項：

- `--skip-tests`：跳過測試
- `--no-clean`：跳過清理，加速建置
- `--no-dmg`：只建置 .app，不建立 DMG

## 功能

- **拖放下載**：直接拖 YouTube 連結到視窗即可加入下載佇列
- **播放清單支援**：自動展開播放清單為多個獨立下載任務
- **並行下載**：支援同時下載 1-5 個影片
- **高畫質支援**：預設格式支援最高 4K 畫質（需要 ffmpeg）
- **自訂下載指令**：在設定中自訂 yt-dlp 指令
- **Safari Cookies 整合**：自動使用 Safari cookies 下載需要登入的影片
- **首播影片支援**：自動偵測並排程首播影片（顯示的首播時間為近似值，可能與 YouTube 顯示的時間有幾分鐘差異）
- **任務持久化**：App 重啟後自動恢復未完成的下載
- **系統通知**：下載完成或失敗時發送通知
- **縮圖預覽**：顯示影片縮圖

## 設定選項

- **下載指令**：預設為 `yt-dlp -f "bv[ext=mp4][vcodec^=avc]+ba[ext=m4a]/b[ext=mp4][vcodec^=avc]" --cookies-from-browser safari "$youtubeUrl"`
  - 使用 `$youtubeUrl` 作為 URL 佔位符
  - 預設格式使用 H.264 編碼，確保 macOS 原生支援預覽與播放
  - 支援高畫質下載（最高可達 4K，需要 ffmpeg 合併影音串流）
- **下載資料夾**：預設為 `~/Downloads`
- **同時下載數量**：可設定 1-5 個並行下載，預設為 2

> **更新注意**：更新 App 後，原有的下載指令設定不會自動更新。如果下載的影片無法預覽，請到設定頁面點擊「重設為預設值」以套用新的下載指令。

## 授權

本專案採用 MIT 授權條款 - 詳情請參閱 [LICENSE](LICENSE) 檔案。

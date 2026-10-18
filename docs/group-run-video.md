# 揪團運動：真實多人視訊

揪團頁改用 LiveKit 的相機／麥克風串流。房內名單由實際連線決定，不再建立假成員、假里程、假分數或示意骨架。這頁目前是多人視訊，不同時運行單人頁的 ML Kit，避免兩個相機套件搶用鏡頭；尚未接入視訊影格的姿態分析。

## 同一台電腦啟動 Django 與視訊（同 Wi-Fi 測試）

不必另外申請 LiveKit Cloud。電腦先安裝並啟動 Docker Desktop，接著在專案根目錄執行：

```sh
python3 backend/scripts/setup_group_video.py --host 192.168.50.58
```

把 IP 換成**執行 Django 的電腦**目前的區網 IPv4；這個 IP 必須能從手機連到。腳本會生成隨機金鑰、啟動固定版本的 LiveKit 容器，並將相同憑證寫入 Django 可自動讀取的 `backend/.env.livekit`。不覆蓋原本的 `.env`。憑證與伺服器設定已加入 Git 忽略規則；重跑時保留金鑰，只更新 IP。

再用原本的虛擬環境重啟 Django：

```sh
cd backend
python manage.py runserver 0.0.0.0:8000
```

另開一個終端機，在專案根目錄重新安裝 App（將 IP 換成相同的電腦 IP）：

```sh
flutter run --dart-define=API_BASE_URL=http://192.168.50.58:8000/api/
```

這個參數讓 iPhone／Android 真機都連到你的 Mac，不必直接修改程式中的 IP。需要重建安裝原生視訊外掛，不能僅用 hot reload。

手機與電腦需在相同 Wi-Fi，防火牆允許 TCP 8000、7880、7881 與 UDP 7882。現有 App API IP 也必須指向這台電腦。視訊容量設定為最多 30 人，但仍需做實際設備與頻寬負載測試。

這個腳本是區網測試設定（WS），不會替你建立公開網域、TLS 或跨網路 TURN。若已在公開伺服器部署，請使用下面的 WSS／LiveKit Cloud 設定；既有環境變數或 `.env` 的設定優先於 `.env.livekit`。

停止服務（不會停止 Django）：

```sh
docker compose -f deploy/video/compose.yaml down
```

## 公開伺服器部署

1. 建立 LiveKit Cloud 專案或部署自己的 LiveKit SFU（需符合人數、頻寬與 TURN 的配置）。不使用公開 demo room 或把伺服器 secret 放在 App。
2. 在 Django 的部署環境設定以下三項，然後重啟後端：

   ```dotenv
   LIVEKIT_URL=wss://your-project.livekit.cloud
   LIVEKIT_API_KEY=your-server-api-key
   LIVEKIT_API_SECRET=your-server-api-secret
   ```

   URL 必須是手機可連線的 WebSocket 位址。正式部署使用 WSS。未設定時 API 回 503，畫面顯示尚未開放，不假裝連線成功。不需要資料庫 migration。
3. 在 Flutter 專案執行 `flutter pub get`。iOS 在 Mac 執行 `cd ios && pod install`，重新編譯安裝，不能僅用 hot reload 安裝原生 WebRTC 外掛。iOS 沿用既有相機與麥克風權限說明；Android 新增錄音及音訊設定權限。
4. 視訊人數上限取決於 LiveKit 服務設定與實測，不再宣稱已支援 30 人。

## 房間與權限

`POST /api/group-runs/token/` 必須攜帶既有登入 JWT，只接受 `group_id` 或 `activity_id` 其中一項。伺服器核對群組成員（含擁有者）；活動房另核對報名、建立者或群主資格。成員身分及顯示名稱來自登入帳號，不能由客戶端冒用。

群組房為 `group-{id}`；活動房為 `group-{group_id}-activity-{activity_id}`。兩個入口是不同房間，請雙方從相同入口加入。簽發的 JWT 僅能進入指定房間，有效期 10 分鐘；無管理權限，secret 不回傳。不記錄 token。LiveKit 會處理已連線工作階段的憑證更新；重新加入會向 Django 索取新 token。

注意：群組權限在簽發 token 時核對。移除成員不會即時踢除既有視訊連線；若需即時撤銷，須再接 LiveKit 管理 API。相同會員在同一房間只使用一個 identity，第二個裝置登入可能取代第一個。

## 使用與驗收

- 按「開啟相機並加入」才連線與分享影像，麥克風預設關閉。
- 兩個不同會員、兩台實機，加入同一群組房：互相看得到實際相機畫面，人數為 2。點縮圖可切換焦點。
- 分別測試拒絕相機權限、開關相機、開關麥克風、離開、斷網與恢復。
- 相機關閉時顯示「相機已關閉」；串流尚未訂閱顯示「影像連線中」，不以頭貼替代直播。
- 切到背景會關閉本機相機與麥克風；回到前景需手動重新開啟。離開頁面會斷線並釋放相機。
- 同活動的報名會員可加入同房；未報名者與非群組成員被拒絕。不同房間不能互相看到。
- 尚未配置 LiveKit 時只能驗證錯誤狀態，不能聲稱完成雙機視訊或 30 人負載驗證。

後端自動測試：`python manage.py test api.test_group_run_video`。

## 工作區驗證結果

- LiveKit v1.8.4 由上述 Compose 與設定腳本實際啟動，健康檢查通過。
- 使用兩個暫時 Django 帳號與真正登入 JWT 呼叫房間 API，取得同房間的視訊憑證；驗證資料庫交易已回滾，不留下示範帳號或群組。
- 兩個 SDK 用戶端用後端憑證加入服務，雙向發布與接收 160×120 測試影格，兩端各收到至少 3 幀並看到 2 人。
- 這是本工作區 Linux 的自動產生影格測試；尚未替代 Mac Docker Desktop、iPhone 相機、Wi-Fi／防火牆與 30 人負載的實機驗收。

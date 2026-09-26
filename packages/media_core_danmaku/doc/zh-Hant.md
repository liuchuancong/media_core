# danmaku 模組

> 彈幕工作階段：平台無關的傳輸契約、訊息正規化、去重/積壓閘門、內容過濾與工作階段圍欄。

## 模組職責

- 為一個房間擁有唯一彈幕工作階段：安裝/替換傳輸、連線、停止與恢復。
- 序列化每一次連線/斷線轉換，並用工作階段權杖保護回呼，使舊 socket 無法寫入新房間。
- 執行訊息管道：閘門(去重/積壓) → 封鎖策略 → 重複文字過濾 → 相似度過濾。
- 曝露工作階段狀態與失敗串流，供宿主演算。

## 核心 API

| API | 說明 |
| --- | --- |
| `DanmakuController` | 工作階段編排根：`installTransport` / `replaceTransport` / `connect` / `stop` / `recover`，以及狀態與失敗串流 |
| `DanmakuTransport` | 平台合約：`start(request, listener)` / `stop()` / `heartbeat()` / `isConnected` / `heartbeatInterval`；單房間、單次使用 |
| `DanmakuTransportListener` | 傳輸 → 工作階段的回呼契約：訊息、就緒、重連、終止 |
| `DanmakuTransportRequest` / `DanmakuRoomRef` / `DanmakuAuth` | 連線入參：房間、憑證與平台專用 `extras` |
| `DanmakuSink` | 輸出埠：訊息、人數、付費留言、通知、房間號、清屏；由宿主實作 |
| `DanmakuMessage` / `DanmakuMessageType` / `DanmakuColor` / `DanmakuStyle` | 正規化訊息模型 |
| `DanmakuSuperChat` / `DanmakuAudienceUpdate` / `DanmakuAudienceKind` | 付費留言與人數酬載 |
| `DanmakuMessageGate` | 去重與積壓閘門：穩定 ID 長窗、無 ID 短指紋窗、年齡上限與有界淘汰 |
| `DanmakuRepeatedFilter` | 折疊短時間內的相同文字(不同帳號也算)，本地訊息豁免 |
| `DanmakuSimilarityFilter` | 相似度抑制，保留快取與比較預算分離 |
| `DanmakuFilterPolicy` | 觀眾級封鎖：使用者與關鍵字，建構時正規化 |
| `DanmakuConfig` | 全部可調參數；預設值為參考實作長期調校的結果 |
| `DanmakuSessionState` / `DanmakuSessionPhase` | 工作階段快照與生命週期階段 |
| `DanmakuFailure` / `DanmakuFailureKind` | 失敗模型(與播放失敗分離) |

## 設計說明

- **分層紀律**：模組只做解碼、去重、過濾與生命週期。協定由適配套件實作 `DanmakuTransport`,渲染、佇列與文案由宿主實作 `DanmakuSink`,模組不認識任何平台。
- **工作階段圍欄**：每個被接受的工作階段遞增權杖，交給傳輸的監聽器捕獲(傳輸身分、房間鍵、權杖)三元組，任一不匹配即丟棄回呼。這取代了可變回呼欄位，傳輸無法半途替換監聽器。
- **轉換序列化**：切房、設定變更、播放器重載與浮窗銷毀可能落在同一事件迴圈輪次。所有轉換追加到單一操作尾鏈，並在執行前重新校驗請求世代，避免兩個握手競爭同一房間。
- **本地工作階段**：沒有彈幕能力的平台由「不上 socket 直接報就緒」的傳輸表達，工作階段即視為已建立並停止重試，無需為「不支援」單獨設狀態。
- **管道順序**：閘門 → 封鎖 → 重複 → 相似度。閘門與封鎖最便宜且最決定性，先拒絕掉大部分流量；相似度是最貴的一步，因此放在最後並帶比較預算。觀眾自己的回聲繞過相似度(必須看到自己發的內容),但不豁免閘門與封鎖。
- **視窗錨定首次到達**：被拒絕的重複不會延長視窗。一個反覆斷線的 socket 不能讓某個訊息 ID 被抑制一小時——重複視窗只需壓過重連重放。
- **通知是代碼不是句子**：模組沒有本地化能力，`DanmakuNotice` 只報事件，文案與是否展示由宿主決定。
- **心跳歸屬**：工作階段依 `heartbeatInterval` 排程保活，傳輸不必自帶計時器(自帶者上報 `Duration.zero` 即可，工作階段不重複呼叫)。

## 依賴

- 內部：`diagnostics`(結構化日誌，分類 `LogCategory.danmaku`)
- 外部：`rxdart`(狀態/失敗串流)、`fuzzywuzzy`(相似度評分)

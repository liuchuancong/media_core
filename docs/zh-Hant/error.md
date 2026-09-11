# error 模塊

> 錯誤體系:穩定的錯誤碼/分類、分類器、格式化器,以及重試/降級策略決策與失敗對象表示。

## 模塊職責

- 定義機器可讀的 `PlayerErrorCode` 與寬泛失敗域 `PlayerErrorCategory`。
- 回答三個分離的問題:分類器「是哪類錯?」、策略「該怎麼辦?」、格式化器「如何呈現?」。
- 提供不可變失敗對象、異常類型與結構化診斷上下文。

## 核心 API

| API | 說明 |
| --- | --- |
| `PlayerErrorCode` | 穩定錯誤碼值對象(`PLAYER_UNKNOWN`、網絡/源/後端等);支持自定義碼 |
| `PlayerErrorCategory` | 失敗域值對象(unknown/invalidArgument/state/network/…);支持自定義 |
| `ErrorClassifier` | 靜態 code → category 映射 |
| `ErrorPolicy` | 決策:可重試/不可重試碼集合、maxRetries、retryDelay、是否啟用重試/降級/恢復;`defaults()` 將網絡/超時/源/後端碼視為可重試 |
| `PlayerFailure` | 不可變失敗對象(code、message、cause、stackTrace、context、category);命名構造器與 `fromError` |
| `PlayerException` | 攜帶 code/message/cause/context 的基礎異常;`PlayerException.from` |
| `ErrorContext` | 結構化診斷上下文(player/session/source/request/operation id、uri、backend、adapter、state、metadata) |
| `ErrorFormatter` | 面向用戶與面向診斷的字符串格式化 |
| `ErrorUtils` | 無狀態輔助:`toFailure`、`tryToFailure` |

## 設計說明

- 錯誤碼/分類刻意用值對象而非 enum,以便應用與適配器擴展。
- 本模塊不執行重試/恢復,只產生決策數據。

## 依賴

- 內部:`identity`(上下文 id)
- 外部:`equatable`

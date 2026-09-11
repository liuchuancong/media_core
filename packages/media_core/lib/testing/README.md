# testing 模塊

> 內部測試替身(test doubles)與測試基礎設施。

## 規劃內容

按 barrel 文件的規劃,本模塊將提供:

- **Fake 基礎設施**:`fake_clock`、`fake_timer`、`fake_network`、`fake_platform`、`fake_lifecycle`、`fake_visibility`、`fake_player`、`fake_player_adapter`
- **測試工廠**:`test_player_factory`、`test_session_factory`、`test_source_factory`
- **場景與斷言**:`test_scenarios`、`test_assertions`

## 當前狀態

⚠️ **尚未實現**:目前除 `library.dart`(barrel)外,所有 13 個文件均為 0 字節佔位。使用前請先確認各文件是否已有實現。

## 依賴

- 規劃上將被各模塊測試使用(見各模塊 `test/` 目錄)

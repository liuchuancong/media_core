# error 模块

> 错误体系：稳定的错误码/分类、分类器、格式化器，以及重试/降级策略决策与失败对象表示。

## 模块职责

- 定义机器可读的 `PlayerErrorCode` 与宽泛失败域 `PlayerErrorCategory`。
- 回答三个分离的问题：分类器「是哪类错？」、策略「该怎么办？」、格式化器「如何呈现？」。
- 提供不可变失败对象、异常类型与结构化诊断上下文。

## 核心 API

| API | 说明 |
| --- | --- |
| `PlayerErrorCode` | 稳定错误码值对象（`PLAYER_UNKNOWN`、网络/源/后端等）；支持自定义码 |
| `PlayerErrorCategory` | 失败域值对象（unknown/invalidArgument/state/network/…）；支持自定义 |
| `ErrorClassifier` | 静态 code → category 映射 |
| `ErrorPolicy` | 决策：可重试/不可重试码集合、maxRetries、retryDelay、是否启用重试/降级/恢复；`defaults()` 将网络/超时/源/后端码视为可重试 |
| `PlayerFailure` | 不可变失败对象（code、message、cause、stackTrace、context、category）；命名构造器与 `fromError` |
| `PlayerException` | 携带 code/message/cause/context 的基础异常；`PlayerException.from` |
| `ErrorContext` | 结构化诊断上下文（player/session/source/request/operation id、uri、backend、adapter、state、metadata） |
| `ErrorFormatter` | 面向用户与面向诊断的字符串格式化 |
| `ErrorUtils` | 无状态辅助：`toFailure`、`tryToFailure` |

## 设计说明

- 错误码/分类刻意用值对象而非 enum，以便应用与适配器扩展。
- 本模块不执行重试/恢复，只产生决策数据。

## 依赖

- 内部：`identity`（上下文 id）
- 外部：`equatable`

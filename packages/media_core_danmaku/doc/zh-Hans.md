# danmaku 模块

> 弹幕会话：平台无关的传输契约、消息归一化、去重/积压闸门、内容过滤与会话围栏。

## 模块职责

- 为一个房间拥有唯一弹幕会话：安装/替换传输、连接、停止与恢复。
- 串行化每一次连接/断开转换，并用会话令牌保护回调，使旧 socket 无法写入新房间。
- 执行消息管道：闸门(去重/积压) → 屏蔽策略 → 重复文本过滤 → 相似度过滤。
- 暴露会话状态与失败流，供宿主观测。

## 核心 API

| API | 说明 |
| --- | --- |
| `DanmakuController` | 会话编排根：`installTransport` / `replaceTransport` / `connect` / `stop` / `recover`，以及状态与失败流 |
| `DanmakuTransport` | 平台合约：`start(request, listener)` / `stop()` / `heartbeat()` / `isConnected` / `heartbeatInterval`；单房间、单次使用 |
| `DanmakuTransportListener` | 传输 → 会话的回调契约：消息、就绪、重连、终止 |
| `DanmakuTransportRequest` / `DanmakuRoomRef` / `DanmakuAuth` | 连接入参：房间、凭据与平台专用 `extras` |
| `DanmakuSink` | 输出端口：消息、人数、付费留言、通知、房间号、清屏；由宿主实现 |
| `DanmakuMessage` / `DanmakuMessageType` / `DanmakuColor` / `DanmakuStyle` | 归一化消息模型 |
| `DanmakuSuperChat` / `DanmakuAudienceUpdate` / `DanmakuAudienceKind` | 付费留言与人数载荷 |
| `DanmakuMessageGate` | 去重与积压闸门：稳定 ID 长窗、无 ID 短指纹窗、年龄上限与有界淘汰 |
| `DanmakuRepeatedFilter` | 折叠短时间内的相同文本(不同账号也算)，本地消息豁免 |
| `DanmakuSimilarityFilter` | 相似度抑制，保留缓存与比较预算分离 |
| `DanmakuFilterPolicy` | 观众级屏蔽：用户与关键词，构造时归一化 |
| `DanmakuConfig` | 全部可调参数；默认值为参考实现长期调优的结果 |
| `DanmakuSessionState` / `DanmakuSessionPhase` | 会话快照与生命周期阶段 |
| `DanmakuFailure` / `DanmakuFailureKind` | 失败模型(与播放失败分离) |

## 设计说明

- **分层纪律**：模块只做解码、去重、过滤与生命周期。协议由适配包实现 `DanmakuTransport`,渲染、队列与文案由宿主实现 `DanmakuSink`,模块不认识任何平台。
- **会话围栏**：每个被接受的会话递增令牌，交给传输的监听器捕获(传输身份、房间键、令牌)三元组，任一不匹配即丢弃回调。这取代了可变回调字段，传输无法半途替换监听器。
- **转换串行化**：切房、设置变化、播放器重载与浮窗销毁可能落在同一事件循环轮次。所有转换追加到单一操作尾链，并在执行前重新校验请求世代，避免两个握手竞争同一房间。
- **本地会话**：没有弹幕能力的平台由"不上 socket 直接报就绪"的传输表达，会话即视为已建立并停止重试，无需为"不支持"单独设状态。
- **管道顺序**：闸门 → 屏蔽 → 重复 → 相似度。闸门与屏蔽最便宜且最决定性，先拒绝掉大部分流量；相似度是最贵的一步，因此放在最后并带比较预算。观众自己的回声绕过相似度(必须看到自己发的内容),但不豁免闸门与屏蔽。
- **窗口锚定首次到达**：被拒绝的重复不会延长窗口。一个反复掉线的 socket 不能让某个消息 ID 被抑制一小时——重复窗口只需压过重连重放。
- **通知是代码不是句子**：模块没有本地化能力，`DanmakuNotice` 只报事件，文案与是否展示由宿主决定。
- **心跳归属**：会话按 `heartbeatInterval` 调度保活，传输不必自带定时器(自带者上报 `Duration.zero` 即可，会话不重复调用)。

## 小窗弹幕

小窗(画中画/应用内浮窗)的弹幕由独立会话承载,不与主画面共用队列:

| API | 说明 |
| --- | --- |
| `DanmakuOverlaySession` | 浮层会话:独立队列、独立样式、有界容量、隐藏即清 |
| `DanmakuOverlayConfig` | 用户可配置项:开关、上限、FPS、速度系数、字号、透明度、显示区域、随窗口缩放与缩放上下限、描边、隐藏时是否清空 |
| `DanmakuFanOutSink` | 分流:把同一条已接受的消息同时交给主画面 sink 与浮层,主画面仍独占人数/付费留言/通知/房间号 |

要点:

- **独立队列的理由**:主画面保留长队列是刻意的(观众在读热闹的聊天),小窗不是——12 条已是 320 像素宽的窗口能显示的上限,而隐藏期间继续堆积的队列会在窗口回来时重放旧弹幕。
- **绑定而不是依赖**:`overlay.bindVisibility(pipDriver.onPipChanged)` 接任意"表面可见性"流,因此弹幕包不认识画中画或浮窗,`media_core_pip`/`media_core_floating` 也不需要依赖弹幕包。
- **随窗口缩放**:`fontSizeFor(surfaceWidth)` 按参考宽度缩放并夹在 `minScale`/`maxScale` 之间;字号缩小时按比例延长停留时间,保持可读时长大致不变。
- **满队列丢最旧**:小窗上最新的消息才是还能反应的那条,丢最旧而不是丢新。

## 依赖

- 内部：`diagnostics`(结构化日志，分类 `LogCategory.danmaku`)
- 外部：`rxdart`(状态/失败流)、`fuzzywuzzy`(相似度打分)

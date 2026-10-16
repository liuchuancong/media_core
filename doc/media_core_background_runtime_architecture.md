# media_core 后台运行时架构重构方案

> 状态：架构提案  
> 适用范围：`media_core_native`、`media_core_notify`、`media_core_mediasession`、`media_core_download` 及录制相关模块  
> 目标：统一后台执行协调、明确 Android 前台服务所有权、消除重复通知，并为跨平台能力提供清晰契约。

## 1. 背景与现状

当前后台运行能力分散在多个包中：

- `media_core_native`：通过 `BackgroundExecutionService` 启动 Android 前台服务，持有 `PARTIAL_WAKE_LOCK`，并将多个会话聚合为一条作业通知。
- `media_core_notify`：负责完成、失败等事件通知；`ForegroundJobs` 还会通过 Flutter Local Notifications（FLN）启动独立前台服务。
- `media_core_mediasession`：通过 `audio_service` 管理媒体播放服务和媒体控制条。
- 录制目前会申请保活；下载、直播、多画面和音乐后台播放没有统一的后台执行声明。
- `ForegroundJobs.start` 和 `MediaCoreNotify.enable` 没有形成一致的统一调用路径。
- 示例宿主清单没有完整体现后台媒体播放所需的权限和服务声明。

这些实现导致服务生命周期、通知展示和后台能力申请彼此脱节，容易产生重复通知、权限申请重复、后台任务没有申请执行能力，以及播放和作业服务互相影响等问题。

## 2. 架构目标与原则

### 2.1 核心目标

1. 所有业务模块通过统一的后台运行契约声明需求，不直接启动 Android 前台服务。
2. Android 作业服务与媒体播放服务保持独立所有权和独立生命周期。
3. 作业通知只由一个作业通知后端维护；媒体控制条由媒体会话后端维护。
4. 事件通知与前台服务生命周期分离。
5. 显式表达权限缺失、平台不支持、系统拒绝、超时和能力降级。
6. 对跨平台能力如实建模，不承诺所有平台都能提供 Android 式保活。
7. 保留现有 Java 侧多任务聚合和 WakeLock 引用计数能力，避免不必要的全面重写。

### 2.2 必须遵守的原则

- **统一协调，不强制统一 Service。**
- **前台服务类型属于具体 Service，不属于整个进程。**
- **请求后台能力不等于系统保证后台执行。**
- **媒体播放资格不能只依赖 UI surface ready 或播放器 playing 的副作用。**
- **通知内容由唯一的投影层生成，业务模块不得自行创建重复的常驻作业通知。**
- **所有 Lease 都有明确所有者，释放操作必须幂等。**

## 3. 目标架构

```text
业务功能层
录制 / 下载 / 直播 / 多画面 / 音乐播放
        |
        | 声明需求、更新状态、释放会话
        v
Background Runtime
  ├── Lease Registry
  │     会话登记、更新、释放、重复请求处理
  ├── Policy Engine
  │     后台能力判定、服务类型策略、WakeLock 需求
  ├── Notification Projector
  │     作业聚合、标题/文本/进度生成
  └── Permission & Capability Coordinator
        权限状态、平台能力、拒绝和降级结果
        |
        +---------------------------+
        |                           |
        v                           v
Android Job Backend          Media Session Adapter
media_core_native            media_core_mediasession
  ├── 作业前台服务             ├── audio_service 适配
  ├── WakeLock                ├── 媒体会话
  ├── 作业通知                 └── 锁屏/通知媒体控制条
        |
        v
media_core_notify
普通通知、完成/失败通知、权限状态
```

`Background Runtime` 是统一协调概念，不要求第一阶段就新增独立 pub package。可以先在现有包中建立清晰的内部模块，待 API 稳定后再决定是否拆包。

## 4. 包职责

### 4.1 `media_core_background`

建议作为逻辑模块，后续再决定是否独立成包。

负责：

- Lease Registry 和会话状态机。
- 后台需求模型及能力结果。
- 后台执行策略接口。
- 统一错误与降级语义。
- 不直接调用 Android Service、WakeLock 或通知 API。

### 4.2 `media_core_native`

负责 Android 作业执行后端：

- 作业前台服务启动、更新和停止。
- `PARTIAL_WAKE_LOCK` 生命周期。
- 作业通知的唯一 ID 与原生更新。
- Android 前台服务类型和超时回调。
- 系统启动失败、权限问题、超时及异常退出上报。

它是 Android 执行者，不应成为录制、下载、媒体播放、权限和通知所有逻辑的巨型容器。

### 4.3 `media_core_mediasession`

负责媒体播放后台会话：

- 媒体会话的建立、更新和释放。
- 媒体元数据、播放状态及控制操作同步。
- 与 `audio_service` 的适配。
- 媒体服务后台资格和生命周期协调。
- 多播放器切换时的所有权和竞态处理。

### 4.4 `media_core_notify`

只负责：

- 普通通知。
- 任务完成、失败、中断等事件通知。
- 通知权限状态及通知能力接口。
- 跨平台通知适配。

Android 上不再通过 `ForegroundJobs` 启动第三条独立前台服务。FLN 可以继续用于普通事件通知及适用平台上的通知展示，但不能和 native 作业服务重复承担 Android 常驻作业通知。

### 4.5 下载与录制模块

业务模块只负责自身工作：

- 创建和持有 Lease。
- 更新标题、说明、进度及任务状态。
- 在完成、取消、失败时释放 Lease。
- 通过事件接口报告结果。

业务模块不直接依赖 Android 通知 API，也不自行启动前台服务。

## 5. 后台执行与媒体播放分开建模

不建议将 `mediaPlayback` 直接作为普通作业服务的 `BackgroundExecutionKind`。媒体播放有独立的 Android 服务所有权，应由 `media_core_mediasession` 管理。

### 5.1 作业执行模型

以下是目标 API 形状，实施时需要根据仓库现有 Dart 版本、错误模型和 API 风格调整。

```dart
enum BackgroundExecutionKind {
  recording,
  download,
  generic,
}

enum BackgroundCapability {
  cpuWakeLock,
  foregroundExecution,
  persistentNotification,
  backgroundAudio,
}

enum BackgroundSessionStatus {
  starting,
  running,
  degraded,
  stopping,
  stopped,
  failed,
}

final class BackgroundRequest {
  const BackgroundRequest({
    required this.id,
    required this.kind,
    required this.title,
    this.description,
    this.requiresCpuWakeLock = true,
    this.priority = 0,
  });

  final String id;
  final BackgroundExecutionKind kind;
  final String title;
  final String? description;
  final bool requiresCpuWakeLock;
  final int priority;
}

abstract interface class BackgroundLease {
  String get id;

  Stream<BackgroundSessionStatus> get status;

  Future<void> update(BackgroundRequest request);

  Future<void> release();
}

abstract interface class BackgroundRuntime {
  Future<BackgroundAcquireResult> acquire(
    BackgroundRequest request,
  );
}
```

`BackgroundAcquireResult` 应明确区分成功、权限缺失、平台不支持、系统拒绝启动和能力降级等结果，不要用 `null` 代表所有失败原因。

建议进一步定义：

```dart
enum BackgroundAcquireFailure {
  permissionDenied,
  unsupportedPlatform,
  foregroundStartRejected,
  capabilityUnavailable,
  invalidRequest,
}

sealed class BackgroundAcquireResult {
  const BackgroundAcquireResult();
}

final class BackgroundAcquireSuccess
    extends BackgroundAcquireResult {
  const BackgroundAcquireSuccess({
    required this.lease,
    required this.grantedCapabilities,
  });

  final BackgroundLease lease;
  final Set<BackgroundCapability> grantedCapabilities;
}

final class BackgroundAcquireRejected
    extends BackgroundAcquireResult {
  const BackgroundAcquireRejected({
    required this.reason,
    this.message,
  });

  final BackgroundAcquireFailure reason;
  final String? message;
}
```

注意：如果成功后可能丢失某些能力，还需要通过 Lease 的状态流报告运行时降级或失败。

### 5.2 媒体会话模型

```dart
abstract interface class MediaBackgroundSession {
  Future<void> activate({
    required String sessionId,
    required String title,
  });

  Future<void> updateMetadata({
    required String title,
  });

  Future<void> deactivate(String sessionId);
}
```

是否激活媒体后台会话，应综合真实播放状态、后台播放意图、音频焦点和平台能力判断，不能仅以播放器创建完成或 UI surface 已准备作为依据。

## 6. Android 前台服务设计

### 6.1 作业服务

作业服务只承载它实际负责的后台工作。

检查和落实：

- 服务声明适用的 `android:foregroundServiceType`。
- 声明 `FOREGROUND_SERVICE` 及目标 Android 版本和任务类型要求的权限。
- Android 14+ 使用正确的前台服务类型参数。
- Android 15+ 正确处理 `dataSync` 后台运行时限及超时回调。
- 为作业通知使用稳定且唯一的通知 ID。
- 服务启动失败、超时或异常退出时更新会话状态并清理资源。

不要为了简化代码，直接把 `dataSync|mediaPlayback` 同时声明到作业服务中。只有同一个 Service 确实承担两种合法职责时，才应使用对应的类型组合。

### 6.2 媒体服务

检查并落实：

- 媒体服务声明 `mediaPlayback` 类型。
- 声明适用版本要求的 `FOREGROUND_SERVICE_MEDIA_PLAYBACK` 等权限。
- 保留 `audio_service` 的媒体会话、媒体通知和控制操作职责。
- 媒体会话结束、播放停止和资源释放时正确退出或更新媒体服务。
- 实际服务名称、清单和版本行为以项目使用的 `audio_service` 版本为准。

### 6.3 权限协调

推荐流程：

1. 业务声明需要的能力。
2. Runtime 检查平台能力和权限状态。
3. 如需用户授权，在合适的前台 UI 中发起请求。
4. 授权后重新执行能力申请。
5. 如果用户拒绝，返回明确结果，由业务选择暂停、降级或提示用户。

不要在每次 `acquire()` 时无条件弹出权限请求。`POST_NOTIFICATIONS` 被拒绝也不能简单等同于所有前台执行能力不可用；需要按 Android 版本和实际场景分别判断。

## 7. 通知设计

通知分成三个语义类别：

| 类别 | 负责人 | 用途 |
|---|---|---|
| 作业通知 | native 作业后端 | 录制、下载和聚合进度 |
| 媒体控制条 | mediasession / `audio_service` | 正在播放的媒体、状态和控制 |
| 事件通知 | `media_core_notify` | 完成、失败、中断等结果 |

### 7.1 作业通知聚合

- native 维护唯一的作业通知 ID。
- 所有活动作业进入统一的聚合器。
- 聚合规则统一生成标题、文本、进度和活动任务数量。
- 例如：`正在录制 · 主播8891 · 12:03 (+1)`。
- 单个作业更新不得覆盖其他作业的数据。
- 最后一个作业释放后，停止对应的作业服务并清理通知。

### 7.2 通知渠道

建议使用明确分工的渠道：

| 渠道 ID（建议） | 用途 |
|---|---|
| `media_core_jobs` | 进行中的作业 |
| `media_core_results` | 完成、失败等事件 |
| 媒体渠道 | 媒体播放通知和控制 |

统一导出渠道 ID 常量，避免多个包重复定义。不要将不同语义的通知全部合并成一个渠道，因为用户可能希望关闭完成提醒，同时保留作业状态或媒体控制。

Android 通知渠道创建后，其重要性等设置通常由系统和用户管理。修改常量不会自动迁移旧渠道，升级时需要考虑兼容、旧渠道清理和用户设置保留。

## 8. 三个维度与场景矩阵

三个维度：

- **A — Execution：** 后台执行需求、能力申请和实际运行结果。
- **B — Surface：** 用户看到的常驻作业通知或媒体控制条。
- **C — Notice：** 任务完成、失败或中断等事件通知。

| 场景 | A：执行策略 | B：常驻界面 | C：事件通知 |
|---|---|---|---|
| 前台录制 | 按需求申请作业执行能力 | 作业通知 | 完成、失败、中断 |
| 后台录制 | `dataSync` 作业服务，受系统限制 | 聚合作业通知 | 完成、失败、中断 |
| 前台下载 | 默认不强制申请 FGS；按产品策略 | 可无常驻通知 | 完成、失败 |
| 后台下载 | 按任务策略和系统限制申请后台执行 | 同一条聚合作业通知 | 完成、失败 |
| 前台视频 | 不额外申请后台能力 | 无 | 无 |
| 后台音频 | 媒体服务按播放状态运行 | 媒体控制条 | 通常无 |
| 后台有声直播 | 按媒体播放策略运行 | 媒体控制条 | 仅同时录制等情况产生 |
| 多画面全部暂停 | 释放不再需要的后台会话 | 无 | 无 |
| 多画面某一路获准后台播放 | 该路拥有独立媒体会话 | 对应媒体控制条 | 无 |
| 录制 + 音乐播放 | 作业服务与媒体服务独立运行 | 作业通知 + 媒体控制条 | 录制结果通知 |

前台下载默认不申请 FGS 是产品策略，不是 Android 强制要求。如果任务必须切后台后持续执行，应按目标 Android 版本、任务时长和系统限制选择合适的执行后端。

多画面也不应默认假设只有一路可以有声播放。若产品支持多路有声播放，需要另行定义媒体会话选择、切换和控制规则。

## 9. Lease 生命周期与竞态规则

### 9.1 会话登记

- 每个 Lease 使用稳定的会话 ID。
- 相同 ID 重复申请必须明确选择拒绝、复用或更新，不得无意增加引用计数。
- 重复释放应幂等。
- 单个会话更新只影响自身记录。
- 一个会话结束时，其他活动会话仍存在就不得停止整个作业服务。
- 最后一个会话释放后，才停止其所属执行后端。

### 9.2 WakeLock

- 只要至少一个有效会话明确要求 CPU 唤醒，才保持对应 WakeLock。
- 每个会话只能释放自己持有的引用。
- 不能由某个任务无条件释放整个进程的锁。
- 启动失败、超时、异常退出时必须清理并同步状态。
- WakeLock 只表达 CPU 唤醒请求，不保证网络可用、任务永不被杀或系统持续调度。

### 9.3 媒体会话

重点覆盖：

- 旧会话释放时误删新会话的媒体通知。
- 多画面切换时，旧播放器停止导致新播放器的服务提前释放。
- 音频暂停后媒体控制条与真实播放状态不一致。
- 录制结束时误停止仍在运行的媒体服务。
- 媒体服务启动失败或权限不满足时，Dart 层仍错误地显示为后台播放成功。

## 10. 分阶段迁移计划

### 阶段 1：建立统一契约

- 定义 Runtime、Lease Registry、会话状态机和明确的结果类型。
- 定义服务所有权与后台能力策略。
- 先将现有录制接入新接口，保持旧 API 兼容。
- 不改变现有通知表现，优先验证生命周期正确性。

### 阶段 2：统一作业前台服务

- 将下载接入作业 Lease。
- 移除 FLN 独立前台服务路径。
- 将 `ForegroundJobs` 改为聚合数据提供者。
- 验证多任务、进度更新、异常退出和最后一个 Lease 释放。

### 阶段 3：明确媒体服务所有权

- 由 mediasession 显式管理媒体会话。
- 处理多画面切换、暂停、释放和录制与播放并存。
- 消除依赖 UI surface 副作用的隐式保活链。
- 验证锁屏控制条和真实播放状态一致。

### 阶段 4：统一权限与渠道

- 收敛权限申请入口。
- 统一渠道 ID 和通知语义。
- 完成示例宿主清单及渠道升级兼容。
- 核对 Android Manifest 合并后的最终配置。

### 阶段 5：系统与跨平台验证

- Android 13、14、15+ 的权限、前台服务类型和运行时限。
- 息屏、切后台、任务超时、进程重建和异常退出。
- iOS 后台音频与后台任务的独立能力验证。
- Android TV 的通知和遥控器操作验证。
- Windows、macOS、Linux 按各平台真实能力实现，不伪装成相同的保活保证。

## 11. 测试策略

### 单元测试

- Lease 重复申请与重复释放。
- 多会话引用计数。
- WakeLock 获取与释放策略。
- 通知聚合和活动任务数量。
- 服务类型策略与状态转换。
- 权限缺失、能力降级和启动失败结果。
- 媒体会话切换及旧会话释放。

### 集成与真机测试

- Android 13+ 通知权限拒绝场景。
- Android 14+ 前台服务类型与权限校验。
- Android 15+ `dataSync` 超时处理。
- 息屏录制、后台下载和任务取消。
- 录制与媒体播放同时运行。
- 作业通知与媒体控制条不重复、不互相覆盖。
- 服务异常退出后状态恢复和资源清理。
- iOS、Android TV、桌面平台的实际能力边界。

Dart 单元测试不能代替真机验证 Android 系统服务、WakeLock、运行时限和媒体控制条行为。

## 12. 实施前的代码审查清单

以下清单已在阶段 1 前逐项对着源码核过，结论写在第 14 节。

- [x] `BackgroundExecutionService` 的完整启动、更新、停止和超时路径。
- [x] `BackgroundExecution.acquire` 当前的引用计数和 WakeLock 所有权。
- [x] `ForegroundJobs` 所有启动入口与实际调用位置。
- [x] `MediaCoreNotify.enable()` 是否触发权限申请或服务启动。
- [x] `audio_service` 的实际版本、服务声明和通知渠道行为。
- [x] `media_core_download` 与录制模块的开始、取消、失败和释放路径。
- [x] 示例 App 最终合并后的 Android Manifest。
- [x] Android 目标 SDK、最低 SDK 和各平台能力约束。
- [x] 旧 API 的兼容窗口与迁移完成条件。

## 13. 最终决策

1. 保留 Java 侧已经有效的作业通知聚合和 WakeLock 机制。
2. 引入统一的 Background Runtime 与显式 Lease 契约。
3. 删除 FLN 独立的 Android 前台作业服务路径。
4. 下载和录制统一接入作业执行后端。
5. 媒体播放由 mediasession 独立管理，不混入作业服务的类型计算。
6. 将事件通知与前台服务生命周期彻底分离。
7. 统一权限和通知渠道，但保留不同通知语义。
8. 把权限拒绝、系统限制、超时、降级和异常退出纳入正式 API。
9. 先完成代码审查和契约，再分阶段迁移，不一次性重写所有模块。

**最终原则：一个统一协调器、多个职责明确的执行后端、每个服务独立的生命周期、每类通知唯一的展示责任。**

> 本文是架构目标与迁移方案，不代表当前仓库代码已经完成审查。实际实现前，必须结合仓库源码、依赖版本、目标 SDK 和最终合并清单逐项确认。

## 14. 阶段 1 落地情况（2026-10-14）

### 14.1 §12 审查结论

| 审查项 | 结论 |
|---|---|
| `BackgroundExecutionService` | 启动路径把类型硬编码成 `ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC`（`BackgroundExecutionService.java:402-414`），`onTimeout` 已有回调（`:321-324`），非超时 `PARTIAL_WAKE_LOCK`（`:574-576`）与释放（`:344-363`）按会话计数；通知固定 id `0x4D4C`（`:76`），渠道 `media_core.background`、`IMPORTANCE_LOW`（`:55`），启动失败返回 `START_NOT_STICKY`（`:275/:292`）。聚合与引用计数保留不动。 |
| `BackgroundExecution.acquire` | Dart 侧 `acquire` 返回 null 覆盖四种原因（平台不支持、服务被拒、插件没接、没有 platform binding），引用计数在 Java 侧，Dart 侧只有一个 `id`。 |
| `ForegroundJobs` | 仓库内**零调用点**；它经 `flutter_local_notifications_client.dart:159` 的 `startForegroundService` 起第三条前台服务，宿主清单还得自己声明 FLN 的 `ForegroundService`。阶段 2 处理。 |
| `MediaCoreNotify.enable()` | 只做两件事：配置 FLN 客户端、把 `JobNotifications` 装进 `MediaJobReporting`。不申请权限、不起服务。权限申请是独立的 `requestPermission()`。 |
| `audio_service` | 锁定 `^0.18.19`（Linux 走 `audio_service_mpris`，Windows 走 `audio_service_win`）。它自己的 `AudioService.java:727` 用不带类型的 `startForeground` 起服务，库清单里没有 `FOREGROUND_SERVICE_MEDIA_PLAYBACK` 权限，渠道也由它自己命名。 |
| 下载与录制的释放路径 | 录制：`_acquireKeepAlive` 只在 `media_core_recording_ffmpeg` 一处（阶段 1 已改成走契约），释放覆盖 stop/cancel/自行退出/dispose；下载：只上报结果，从来没申请过任何后台能力。 |
| 示例 App 清单 | `example/android/app/src/main/AndroidManifest.xml` 里**没有任何**后台权限或服务声明，全部依赖插件清单合并。阶段 4 补齐并核对合并结果。 |
| SDK | `media_core_native/android/build.gradle`：`compileSdkVersion 36`、`minSdkVersion 21`；示例应用未显式声明 target。 |
| 旧 API 兼容窗口 | `BackgroundExecution.acquire` 与 `BackgroundExecutionLease` 原样保留、行为不变；新的 `acquireDetailed` 只是把原因带出来。破坏性改动只在 `FfmpegRecordingBackend` 的注入缝（`keepAliveStarter` → `backgroundRuntime`），该包尚未发布。 |

### 14.2 已落地

- `packages/media_core/lib/src/background/`：`BackgroundRequest`、`BackgroundExecutionKind {recording, download, generic}`、`BackgroundCapability`、`BackgroundSessionStatus`、`BackgroundAcquireFailure`、`BackgroundDuplicatePolicy`、`BackgroundLease`、`BackgroundAcquireResult`（sealed）、`BackgroundExecutionBackend` / `BackgroundBackendOutcome`、`BackgroundLeaseRegistry`、`BackgroundRuntimes` 安装槽、`MediaBackgroundSession`。没有新增包，按 §4.1 先做逻辑模块。
- `packages/media_core_native/lib/src/background/native_background_backend.dart`：Android/iOS/macOS/Windows 的执行后端，把请求翻译成既有通道形状；`NativeBackgroundRuntime.shared` 是全进程共用的登记表。
- 录制接入：`FfmpegRecordingBackend` 以 `recording/<前缀>` 申请会话，更新只写自己那条，释放路径不变。通知表现与阶段 1 之前一致。
- 测试：`media_core/test/background`（31 例，覆盖 §9 的 id、重复、幂等、逐会话唤醒锁、平台无能力、被拒原因、聚合排序）；`media_core_native/test/background_runtime_test.dart`（11 例，覆盖通道形状与拒绝原因映射）。

### 14.3 与文档字样的差异

- `BackgroundRequest` 多了 `icon` 和 `progress`，少了 §5.1 里那版的隐含字段。理由：图标和进度条本来就是通知内容的一部分，写在请求里才有唯一的生成处；否则每个后端只能自己猜一个。
- 没有 `wantsNotification`。Android 的前台服务**必须**带通知，"不要通知"在这条路上做不到，所以不提供一个会撒谎的开关：`persistentNotification` 是否授予由平台决定，与请求无关。
- `duplicatePolicy` 是 §9.1 "相同 ID 重复申请必须明确选择拒绝、复用或更新"的字面实现：`reject` / `share` / `update`。默认 `reject`。
- `MediaBackgroundSession.updateMetadata`/`deactivate` 都带 `sessionId`。多画面切换时旧播放器的迟到回调必须能被判为过期，只给标题做不到。
- §9.2 的唤醒锁规则落成了"能力在有人持有期间一直在 `activeCapabilities` 里，释放只退自己那条"，没有引入新的全局锁 API —— Java 侧的计数继续做它的工作。

### 14.4 阶段 2 已落地（2026-10-14）

- **契约补两件投影层写字面所需的事**：`BackgroundRuntime.changes`（聚合变更广播，**先改记录再发信号**，
  所以听到就重读 `activeRequests` 的投影看到的已经是新列表）与 `BackgroundRuntime.platformCapabilities`
  （平台能给什么，与当前有没有人持有无关）。`BackgroundLeaseRegistry.dispose()` 交回所有会话并停止广播。
- **下载接进作业会话**：`DownloadConfig.keepAlive`（默认关，这是 §8「前台下载默认不申请 FGS」的产品决定）。
  每个正在传输的任务持有一条 `download/<任务 id>` 会话，取在第一个字节之前，还于完成 / 预算用完 / 暂停 /
  取消 / 移除 / `dispose()`；重试按 `update` 策略刷新同一条而不是叠一条。正文 `文件名 · 45% · 1.2 MB/s`，
  服务器没给长度时不写百分比、进度用 `indeterminate`；重写最多每秒一次。本包仍不依赖 `media_core_native`。
- **删掉 FLN 的独立前台服务路径**：`LocalNotificationClient` 的 `startForeground` / `updateForeground` /
  `stopForeground` 变成 `showRunningLine` / `clearRunningLine`，`NotifySetup.foregroundServiceTypes` 随之下线。
  Android 的常驻作业通知自此只有 native 作业服务一个主人，宿主也不需要再在清单里声明 FLN 的 `ForegroundService`。
- **`ForegroundJobs` 改成投影**：不再自己维护会话列表，而是订阅运行时 `changes`、从 `activeRequests` 组那一行。
  平台的 `platformCapabilities` 含 `persistentNotification` 时只组合不绘制；开线收线不节流，
  只有移动的文字节流——最后一条作业结束后还留着的那条线是在说假话。
- 测试：`media_core/test/background` 31 例，`media_core_download` 45 例（其中 14 例是后台执行），
  `media_core_notify` 30 例（线由真登记表驱动，含「Android 不画第二条」「暂停不留线」）。

### 14.5 阶段 3 已落地（2026-10-14）

- `MediaSessionDriver` 实现 `MediaBackgroundSession`：媒体面只有**一个命名主人**。内核的活动播放器以 `player/<handle id>` 持有它，宿主可以用
  `activate(sessionId:, title:)` 接走（结果会说出上一任是谁），`updateMetadata` 与 `deactivate` 只对当前主人有效——旧播放器停止时的迟到回调
  从此不能再改写或清掉新接手那一格的控制条。`activeSessionId` 是"现在谁在上面"的唯一答案。
- `activate` 现在会**报告**平台到底接了没有：`MediaSessionActivation.held/refused` + 三个各有生产者的 `MediaSessionRefusal`
  （`notInitialized`＝握手还没跑，等；`surfaceUnavailable`＝跑了而平台没给，别等；`disposed`＝驱动已经扔掉还在被调用）。
  这是 §9.3 最后一条（"媒体服务启动失败或权限不满足时，Dart 层仍显示为后台播放成功"）的字面修复。
- 相位说出口了：`MediaSessionState.phase`（idle / loading / buffering / ready / completed）由播放器的真实 transport 状态推出来，
  `publishState` 不再一律报 `AudioProcessingState.ready`；相位变化不受一秒位置窗口的节流。
- `dispose()` 交还整个面（`releaseSurface`），不是把它停在 idle ——一个没有主人的媒体项留在锁屏上就是还在播放的假象。
- 顺带修掉一个属于同一族的真 bug：`PlaybackSnapshot.isPlaying` 用 `runtimeType.toString().contains('Play')` 判断，而这一族每个类都叫
  `PlaybackCommand…`，所以 idle / pause / stop / seek 全都算"在播放"（`PlayerHandleSnapshot.isPlaying` 就是它的下游）。
  命令改成有类型的 `PlaybackCommand` 并问它自己文档里的谓词；`isBuffering` 以前读命令，而缓冲只更新 transport 的标志位，
  所以快照永远答"不在缓冲"——现在它带着那个标志位。
- "依赖 UI surface 副作用的隐式保活链"复核结果：链子已经在阶段 1 之前的生命周期修复里断掉了（`didChangeAppLifecycleState` 只看
  `playbackStream.value.isPlaying` 与每个玩家的 `pauseWhenBackgrounded`，不看渲染面），本阶段把剩下的隐式部分（谁都能写同一块控制条）改成显式所有权。
- 测试：`media_core_mediasession` 30 例（新增 13 例：相位、所有权、迟到回调、dispose 交还、三种拒绝各有其位）。

### 14.6 修复轮（2026-10-14）

阶段 1–3 落地后自查出的两处"契约写全了、接线没接上"，本轮补完：

- **运行中那一行以前没有任何调用点**。`ForegroundJobs` 的投影每次被问都答得对，但除了 Android（作业服务自己带通知）之外
  没有任何平台真的画过它——iOS / macOS / Windows / Linux 上录制与下载全然是无声的。现在 `MediaCoreNotify.enable()`
  顺手 `watch()`，`disable()` 顺手 `hide()`（因此返回 `Future<void>`）；宿主不再需要第二步。`watch()` 也不再"看一眼就走"：
  后端通常在第一条作业出现时才装进槽位，所以它等 `BackgroundRuntimes.changes`，装上即接。为此 `BackgroundRuntimes`
  的 setter 会把新运行时报到 `changes` 上。
- **`surfaceUnavailable` 当时没有生产者**，`notInitialized` 于是被拿来回答三种不同的问题。`MediaSessionDriver.initialize()`
  现在记住"握手跑了但平台没给 handler"（`AudioService.init` 抛出来的那种），之后每次 `activate` 答 `surfaceUnavailable`；
  `dispose()` 之后答 `disposed`。这条分支在单元测试里跑不出真平台失败（`audio_service` 会在 zone 里留下自己的
  `MissingPluginException`），所以 `surfaceUnavailable` 由代码路径证明、由 `notInitialized` / `disposed` 两例守住判断表。

顺带一条测试脚手架的坑，值得写下来免得再踩：登记表、它的广播流和投影由此开出的节流定时器**属于创建它的那个 zone**。
在 `setUp`（`fakeAsync` 之外）构造它们，`async.elapse` 就永远叫不响那条线的截止时间——看起来像投影逻辑坏了，其实是 harness。

### 14.7 还没做

- 阶段 4/5：权限与渠道统一（`media_core_jobs` / `media_core_results`）、示例清单、Android 13/14/15 与 iOS 真机验证。超时与服务被系统杀掉上报成 `degraded` / `failed` 需要 Java 侧先事件化——`BackgroundBackendLease.statusChanges` 已经给它留了口。

# lx-music 功能对齐台账

参考源码：`E:\study\lx-music-desktop-master`、`E:\study\lx-music-mobile-master`（2026-10-28 审阅）。
本文只记录 `media_core_audio` 这一层的迁移状态；播放器 UI、主题、设置页、同步服务属于宿主 App，不在本包范围。

图例：✅ 已完成并测试；🟡 部分完成/有明确边界；⛔ 不在本包职责；⏳ 待后续。

## 1. 播放

| lx-music 能力 | 本包对应 | 状态 |
| --- | --- | --- |
| 队列、顺序/列表循环/单曲循环/随机 | `PlayQueue`、`PlayMode` | ✅ |
| “下一首播放”、插入/删除/移动 | `playTrack(insertNext)`、`PlayQueue` | ✅ |
| 音质档位与按档解析 | `MusicQuality`、`MusicSource.qualities` | ✅ |
| 播放失败换源/刷新签名 URL | `AudioPlaybackConfig.refreshSourceOnError` | ✅ |
| 预加载下一首 URL 与歌词 | `prefetchNext` + `LyricLoader.prefetch` | ✅ |
| 倍速、音量、静音 | `setRate` / `setVolume` / `setMute` | ✅ |
| 定时停止（睡眠定时） | `setSleepTimer`、`state.sleepTimerEndsAt` | ✅ 本次补齐 |
| 定时停止「播完当前歌曲」 | `setPauseAfterCurrentTrack`、`state.pauseAfterCurrentTrack` | ✅ 本次补齐 |
| 播放历史 | `PlayQueue` 目前只有当前游标 | ⏳ 宿主可自行记录，必要时再加 `history` |
| 均衡器/音效 | 依赖播放后端，非本包 | ⛔ |
| 系统媒体面（通知/锁屏/SMTC/MPRIS） | `MusicBackgroundBinding`、`MediaSessionBootstrap` | ✅ |
| 后台继续播放（移动端/桌面） | `PlayerConfig(pauseWhenBackgrounded: false)` 豁免共享内核的默认暂停 | ✅ 本次补齐 |

## 2. 歌词

| lx-music 能力 | 本包对应 | 状态 |
| --- | --- | --- |
| LRC 解析（多时间戳、`[offset:]`、1–3 位毫秒） | `LrcParser` | ✅ |
| `[hh:mm:ss.xx]` 等不规范时间戳 | `LrcParser` 兼容 | ✅ 本次补齐 |
| 翻译、罗马音并轨 | `LyricDocument.rawTranslation/rawRomanization` | ✅ |
| 逐字歌词 `<mm:ss.xx>` | `LrcParser` | ✅ |
| lx 扩展逐字 `<起始毫秒,时长>` | `LrcParser` | ✅ 本次补齐 |
| QRC/KRC/YRC 解码后的毫秒文本 | `LyricParser` + `MillisecondLyricParser` | ✅ 本次补齐 |
| QRC/KRC/YRC 解密（DES/XOR/zlib） | 属于音源插件，随 token/签名留在宿主 | ⛔ 源职责 |
| 运行时歌词延迟（滑杆） | `setLyricOffset`、`LyricDocument.offset`、`LyricTimeline.setOffset` | ✅ 本次补齐 |
| 翻译/罗马音开关与交换顺序 | `LyricDisplayOptions`、`LyricLine.secondaryTexts` | ✅ 本次补齐 |
| 播放页歌词字号/对齐/当前行放大/进度条 | 宿主 `MusicSettings.lyricFontScale/lyricAlignment/lyricZoomActive/lyricProgress` | ✅ 本次补齐 |
| 歌词缓存、并发合并、预取 | `LyricLoader` | ✅ |
| 歌词来源回退链（缓存→在线→文件） | `LyricLoader(providers: [...])` | ✅ 本次补齐 |
| 手动关联歌词（本地 `.lrc`/`.txt`，可取消） | `setLyricOverride`、`state.lyricRevision`；宿主 `MusicLyricOverridesController` 持久化 | ✅ 本次补齐 |
| 侧栏/桌面歌词 | `DesktopLyricController`（Win/Android/macOS/Linux） | ✅ |
| 桌面歌词样式（字号/透明度/颜色/对齐） | `DesktopLyricStyle` + `setStyle` | ✅ |
| 桌面歌词锁定鼠标穿透 | `setLocked` / `state.locked` | ✅ |
| 桌面歌词自有关闭/锁定按钮回传宿主 | `visibleChanges` / `lockedChanges` | ✅ 本次补齐 |
| 桌面歌词翻译/罗马音 | `DesktopLyricController.display`、`setDisplayOptions` | ✅ 本次补齐 |
| 导出 `.lrc`（翻译/罗马音/逐字/`[awlrc:…]`） | `LyricExporter` | ✅ 本次补齐 |
| UTF-8 BOM / GBK 写盘 | `LyricFileWriter`；GBK 通过自定义编码器注入 | 🟡 Dart 无内置 GBK |
| 状态栏歌词 / 蓝牙歌词 | 平台 UI 能力 | ⏳ 宿主实现 |
| 按歌名搜索歌词 | 宿主用 `MusicSource.search` 找候选、`resolveLyric` 取歌词并写入覆盖表（`MusicPlayerController.searchLyricCandidates/useLyricFrom`） | ✅ 本次补齐（走宿主 Kuwo 通道，未用脚本的 `lyric` 动作） |

## 3. 下载

| lx-music 能力 | 本包对应 | 状态 |
| --- | --- | --- |
| 有界并发队列、运行中调整并发数 | `MusicDownloadQueue.maxConcurrent` + `setMaxConcurrent` | ✅ 本次补齐 |
| 失败重试、重试前换 URL | `maxAttempts` + `resolve` 回调 | ✅ |
| 状态：等待/运行/暂停/错误/完成 | `MusicDownloadStatus`（另有 `processing` / `skipped`） | ✅ |
| 暂停/继续 | `pause` / `resume` / `pauseAll` / `resumeAll` | ✅ 本次补齐 |
| 断点续传（HTTP Range） | 复用 `media_core_download` 的传输与文件抽象 | ✅ 本次补齐 |
| 续传前尾部字节校验 | `DownloadResumePlanner.tailMatches` | ✅ |
| HLS/分段流下载 | 先按分段缓存（`hls_playlist.dart`：清单解析/主清单选码率/本地清单重写/已缓存分段探测），再让 ffmpeg 读本地清单；重试与续传只补缺失分段 | ✅ 本次补齐 |
| 跳过已存在文件 | `skipExisting` → `skipped` | ✅ 本次补齐 |
| 重复任务过滤 | `dedupeKey`（源+曲目+音质+容器） | ✅ 本次补齐 |
| 按音质回退/选择容器 | `planFor(source, quality)` | ✅ 本次补齐 |
| 文件名模板与非法字符清理 | `{title}/{artist}/{album}/{quality}/{source}/{list}/{index}` | ✅ |
| 按列表分目录 | `subdirectory` | ✅ 本次补齐 |
| 标签写入（标题/歌手/专辑） | ffmpeg `-metadata` | ✅ |
| 封面内嵌 | `embedCover` + attached_pic | ✅ 本次补齐 |
| 歌词内嵌 | `embedLyric` → `lyrics` 标签；先按导出选项合成（翻译/音译/逐字/`[awlrc:…]`）再写入 | ✅ 本次补齐 |
| 旁车歌词包含翻译/音译 | `writeLyricFile` 与内嵌共用同一份合成文本 | ✅ 本次补齐 |
| 同名 `.lrc` 旁车 | `writeLyricFile` + `LyricExporter` | ✅ 本次补齐 |
| 任务持久化 | `toJson/fromJson`、`restore`（未完成恢复为暂停） | ✅ 本次补齐 |
| 移除时删除半成品 | `remove(deleteFile: true)` | ✅ |
| 试听列表自动下载/watch list | 宿主策略 | ⏳ |
| 代理 | 随 App 启动安装的 `AppProxyHttpOverrides` 生效（搜索/歌词/脚本/下载都走 `dart:io` 客户端）；播放流由播放内核直连 | ✅ 宿主全局 |

## 4. 本地音乐

| lx-music 能力 | 本包对应 | 状态 |
| --- | --- | --- |
| 扫描目录、按文件名成曲目 | `LocalMusicSource` | ✅ |
| ID3v1/ID3v2 标签（标题/歌手/专辑/音轨/年份） | `AudioTagReader` | ✅ 本次补齐 |
| FLAC / MP4 / Ogg / WAV 标签 | `AudioTagReader` | ✅ 本次补齐 |
| 标签时长（MP3 帧与 Xing、FLAC STREAMINFO、MP4 mvhd、WAV byteRate） | `AudioTagReader` | ✅ 本次补齐 |
| 内嵌歌词（ID3 USLT/SYLT、Vorbis LYRICS、MP4 ©lyr） | `LocalMusicSource.resolveLyric` 回退链 | ✅ 本次补齐 |
| 内嵌封面 | `AudioTag.picture`、`LocalMusicSource.coverOf`；宿主 `MusicArtwork` 直接绘制 | ✅ 本次补齐 |
| 同名 `.lrc` | `LocalMusicSource.resolveLyric`（BOM/编码回退，优先于内嵌） | ✅ 本次补齐 |
| 歌曲元数据编辑 | 宿主 UI | ⛔ |

## 5. 验证

```bash
cd packages/media_core_audio
dart analyze
flutter test
```

当前覆盖：歌词解析/偏移/导出/写盘 17 项，下载请求/持久化/标签参数/合成歌词/本地清单输入/续传/暂停/并发调整/去重/旁车 15 项，HLS 清单解析/主清单选码率/本地清单重写/分段缓存探测 9 项，播放器偏移/睡眠定时/播完当前歌曲/歌词覆盖 4 项，桌面歌词自有关闭/锁定回传 1 项，本地标签/内嵌歌词/封面 8 项，另有既有的后台绑定与来源契约测试（包内共 64 项通过）。

## 6. 宿主 App 接入（`D:\flutter\pure_live\apps\pure_live`）

2026-10-28 在音乐模块补齐的宿主侧能力：

| lx-music 能力 | 宿主实现 |
| --- | --- |
| 菜单：搜索 / 歌单 / 排行榜 / 我的列表 | `NavigationItem.music*` + `MusicView` |
| 本地音乐入口与目录扫描 | `MusicLocalController` + `LocalMusicSource`；标题/歌手/专辑/时长取自标签，内嵌歌词在无 `.lrc` 时生效 |
| 记住播放进度 | `MusicProgressStore`：按 `sourceId:id` 保存位置，首次播放时恢复，播完清除 |
| 歌曲详情 / 复制歌名 | `MusicSongRow` 菜单：详情弹窗列出歌名/歌手/专辑/时长/来源/文件，复制为「歌手 - 歌名」 |
| 下载管理入口、进度、暂停/继续/重试/移除/清空 | `MusicDownloadsController` + `MusicView.downloads` |
| 自建歌单 CRUD、加歌/移除/清空/播放 | `MusicPlaylistsController` + `MusicView.songlists` |
| 歌单导入/导出（JSON） | `MusicPlaylistsController.importFromFile/exportToDirectory` + 歌单页按钮与菜单 |
| 歌单排序（歌名/歌手/专辑/时长/随机） | `MusicPlaylistsController.sortTracks` + 歌单菜单「排序」 |
| 列表多选与批量操作（全选/批量加入歌单/批量下载/批量移除） | 歌单详情与本地音乐列表的「选择」模式 + `MusicSongRow(selecting:)`；本地列表支持全选/播放所选/批量加入歌单 |
| 应用内歌词显示 | 设置页歌词分区：字号缩放（100%–200%）、对齐（左/中/右）、放大当前行、显示播放进度；作用于播放页歌词面板 |
| 不喜欢规则与自动跳过 | `MusicDislikesController` 持久化规则，`MusicPlayerController` 遇到即跳过（以队列长度兜底），列表设置可查看数量并清除 |
| 歌曲行更多菜单（下一首播放/加入歌单/下载/歌曲详情/复制歌名） | `MusicSongRow` 的 `DsMenuAnchor` |
| 播放器更多菜单：倍速、睡眠定时（含播完当前歌曲）、歌词延迟（预设与 ±10/±100ms）、歌词字号、对齐、翻译/音译顺序、桌面歌词、清空队列 | `MusicPlayerController` + `_PlayerMenu` |
| 自定义源管理：导入/重新加载/启用禁用/移除 | `MusicSourcesPane` + `MusicCustomSource.enabled`；运行时只加载启用的脚本 |
| 搜索历史 | `MusicSearchHistoryController` |
| 下载设置：目录、格式、命名模板、封面/标签/旁车/跳过/按歌单分组/并发数、歌词包含翻译/音译 | `MusicSettings` + `MusicDownloadPane` |
| 歌词设置：翻译/音译开关、延迟 | `MusicSettings` + `MusicLyricPane` |
| 关联本地歌词（`.lrc`/`.txt`，可取消） | 播放器菜单 + `MusicLyricOverridesController`；歌词页与桌面歌词按 `lyricRevision` 刷新 |
| 在线搜索歌词 | 播放器菜单「在线搜索歌词」：默认以「歌手 歌名」搜索，候选来自 `LxMusicSource.search`，选中后取 `resolveLyric` 并写入覆盖表（含翻译） |
| 歌词翻译/音译顺序 | 设置页歌词分区「翻译/音译顺序」；播放页歌词与桌面歌词同步交换 |
| 下载并发数 | 设置页下载分区 1–5；`MusicDownloadQueue.setMaxConcurrent` 即时调整，不打断已运行任务 |
| 播放失败自动跳过 | `skipOnError` 接通：引擎重试一次仍失败时自动下一首，跳过次数以队列长度兜底，全部失败后停止 |
| 后台播放 | `AudioPlaybackController` 传 `PlayerConfig(pauseWhenBackgrounded: false)`，离开前后台不被内核暂停 |
| 系统媒体面（通知/锁屏/SMTC/MPRIS） | `MusicBackgroundBinding` 接 `MediaSessionBootstrap.current`；启动未就绪时在控制器内重试 `MediaSessionBootstrap.enable()` |
| Android 媒体通知接入 | `MainActivity` 继承 `AudioServiceActivity`；补 `drawable/ic_media_{play,pause,stop,previous,next,rewind,forward}`；首次播放时申请 `POST_NOTIFICATIONS` |
| 桌面歌词 | 设置页 `MusicDesktopLyricPane` + 播放器菜单：开关、锁定、字号、透明度、文字色、描边色/宽度、对齐；偏好持久化并在启动时恢复 |
| 自定义源脚本执行 | `fjs`（QuickJS）运行时：`lx.on/send/request/utils`，HTTP 桥接；MD5/随机数用运行时全局 crypto，AES/RSA 以纯 JS 实现（fjs 的 crypto 是 WebCrypto，没有 Node 的 `createCipheriv`/`publicEncrypt`），zlib 动态 import |
| 音源 | 搜索/榜单/歌词走 lx 的 Kuwo 通道；播放地址优先由最新导入的脚本解析，Kuwo 直链兜底 |
| 搜索/榜单/歌词 | 已移除 Bilibili 音源，不再依赖视频站客户端与登录 |
| 热门搜索 | `LxMusicSource.hotSearches`（Kuwo 热搜接口）+ `musicHotSearchesProvider`；搜索空状态以 chip 展示，设置页可关闭；拉取失败只隐藏该区 |
| 歌曲评论 | `LxMusicSource.getJson` + `musicCommentsProvider`：Kuwo 评论接口，播放器菜单「评论」弹窗，热门/最新切换与分页加载；本地歌曲不显示入口 |
| 备份与恢复 | 应用级备份文档已覆盖音乐模块：音源/音质/播放与列表设置、歌词显示与桌面歌词样式、下载设置、歌单/收藏/试听/不喜欢/歌词覆盖/搜索历史/本地目录/队列；恢复后刷新对应 provider |

仍有明确边界的部分：

- **脚本覆盖范围**：lx 自定义源契约只提供 `musicUrl`（以及 local 的 lyric/pic），搜索与榜单仍由宿主提供；当前宿主实现的是 Kuwo 通道。
- **均衡器/音效**：属于播放后端，未接入。
- **本地封面显示**：内嵌封面已由 `LocalMusicSource.coverOf` 读出并在歌曲行绘制；封面按会话缓存，文件变化后需重开窗口才重读。
- **标签编码**：ID3v2 按规范支持 Latin-1/UTF-8/UTF-16；GBK 编码的旧标签没有内置解码器，宿主可注入自己的读取器。
- **评论通道**：评论走宿主的 Kuwo 通道，只对在线歌曲开放；接口字段缺失时按空列表处理。
- **备份恢复的生效时机**：设置与列表恢复后立即刷新；播放队列与“记住播放进度”在下次启动读取，避免恢复操作打断正在播放的歌曲。
- **代理**：音乐模块的搜索/歌词/脚本/下载继承 App 启动时安装的全局代理（`AppProxyHttpOverrides`）；播放内核的媒体流不经过 Dart HTTP 客户端，不受该代理影响。
- **在线歌词搜索的通道**：候选与歌词都走宿主的 Kuwo 通道，不会调用自定义源的 `lyric` 动作；脚本只声明 `lyric` 的 local 源不参与搜索。
- **HLS 续传边界**：分段缓存只用于有 `#EXT-X-ENDLIST` 的点播清单；直播清单窗口会移动，仍由 ffmpeg 直连。`#EXT-X-KEY` 的密钥仍从远端取（本地清单保留绝对 URI），密钥请求依赖源站与已传请求头；DASH/`mpd` 没有分段缓存，暂停后重启该文件。分段缓存目录为 `<输出文件>.parts`，完成后删除，移除任务时也删除。
- **歌单推荐/分类**：仍由自建歌单承担，未接平台歌单接口。
- **桌面歌词位置与字体**：`DesktopLyricController` 已支持拖拽与样式，但宿主只持久化字号/透明度/颜色/对齐/锁定，未保存窗口坐标与字体族。
- **桌面歌词权限**：Android 需要 `SYSTEM_ALERT_WINDOW`，宿主在开启时经 `AudioPermissionService` 申请；被拒绝时开关回弹。
- **系统媒体面**：依赖平台实现（Android 13+ 通知权限、iOS 后台音频模式已在 Info.plist），无桌面环境时 `MediaSessionBootstrap.enable()` 失败只影响通知。

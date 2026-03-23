# Typeless iOS 项目分层与上下文

## 1. 当前项目定位

这个仓库当前不是完整产品仓，而是 `P0 / MVP 前技术验证仓`。

当前目标不是一次性做完 Typeless 风格语音键盘，而是先验证这条主链路是否可跑通：

`主 App 录音 -> 直连阿里云实时 ASR -> 实时/最终结果落地 -> Keyboard Extension 读取共享结果 -> 将结果插入当前输入框`

当前已经完成：

- 主 App 标准 iOS 工程
- 麦克风权限申请
- `16kHz` 单声道 `PCM` 音频采集
- 阿里云 `fun-asr-realtime` WebSocket 客户端
- 主 App 内实时预览与最终结果展示
- Keyboard Extension 基础目标
- App Group 共享状态同步
- 键盘侧插入最近结果与撤销最近插入

当前还没有完成：

- 键盘扩展内直接录音
- 主 App 后台常驻策略验证
- Live Activity / 灵动岛协同
- 用户词典、热词管理 UI
- 服务端代理与安全鉴权链路

## 2. 分层原则

当前工程按“职责分层”而不是按页面堆文件。

核心规则：

- `App / Feature` 层负责 UI、用户交互、状态编排。
- `Services` 层负责外部能力接入，例如音频采集、ASR 网络连接。
- `Shared` 层负责主 App 和 Keyboard Extension 共用的数据模型与共享存储。
- `Support` 层负责配置、环境变量、基础上下文对象。
- `KeyboardExtension` 层只关心键盘目标自己的 UI 和输入代理动作。

依赖方向保持单向：

`Feature -> Services / Shared / Support`

`KeyboardExtension -> Shared`

`Services` 不反向依赖 `Feature`

这样做的目的很明确：

- 避免 UI 状态和底层能力耦死
- 方便把主 App 验证逻辑迁移到后续正式架构
- 让键盘扩展只消费共享结果，不直接绑住主 App 页面代码

## 3. 当前目录职责

### 根目录

- [README.md](/Users/codefriday/workspace/project/typeless/README.md)
  当前项目的运行说明和环境变量入口。
- [PRD.md](/Users/codefriday/workspace/project/typeless/PRD.md)
  产品目标、P0 范围和验证边界。
- [FUN_ASR_REALTIME.md](/Users/codefriday/workspace/project/typeless/FUN_ASR_REALTIME.md)
  阿里云实时 ASR 最小接入说明。
- [ARCHITECTURE.md](/Users/codefriday/workspace/project/typeless/ARCHITECTURE.md)
  当前这份工程分层与上下文说明。
- [scripts/generate_xcodeproj.rb](/Users/codefriday/workspace/project/typeless/scripts/generate_xcodeproj.rb)
  标准 Xcode 工程生成脚本。

### App 层

- [TypelessApp.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/App/TypelessApp.swift)
  应用入口，组装 `SettingsStore` 和 `RecorderViewModel`。
- [TypelessApp.entitlements](/Users/codefriday/workspace/project/typeless/TypelessApp/App/TypelessApp.entitlements)
  主 App 的 App Group 能力声明。

职责：

- 启动应用
- 注入全局依赖
- 承载后续主 App 级能力，例如后台录音、Live Activity、系统路由控制

### Feature 层

- [HomeView.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/Features/Home/HomeView.swift)
  当前主页面，用来验证录音、实时识别和结果展示。
- [RecorderViewModel.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/Features/Home/RecorderViewModel.swift)
  主录音链路的核心编排层。
- [SettingsView.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/Features/Home/SettingsView.swift)
  本地调试配置入口。

职责：

- 接收用户动作
- 切换录音状态
- 组合音频采集与 ASR 客户端
- 将状态同步到共享容器

`RecorderViewModel` 是当前 P0 的核心 orchestrator，不是底层服务。

它负责：

- 权限判断
- 启停录音
- 驱动 ASR 任务生命周期
- 处理 partial / final 结果
- 向键盘共享“最近一次可插入结果”

### Services 层

- [PCM16MonoAudioCaptureService.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/Services/Audio/PCM16MonoAudioCaptureService.swift)
  麦克风采集、格式转换和音频分片输出。
- [DashScopeRealtimeASRClient.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/Services/ASR/DashScopeRealtimeASRClient.swift)
  阿里云 WebSocket 客户端，负责 `run-task / audio / finish-task` 协议。

职责：

- `Audio Service` 只关心把设备输入变成 `16kHz mono pcm`
- `ASR Service` 只关心把音频发到云端并解析服务端事件

这里刻意不让 `Services` 了解 SwiftUI 页面或键盘 UI。

### Shared 层

- [AppGroup.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/Shared/AppGroup.swift)
  App Group 标识常量。
- [SharedRecorderSnapshot.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/Shared/SharedRecorderSnapshot.swift)
  主 App 与键盘扩展共享的数据快照模型。
- [SharedRecorderStore.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/Shared/SharedRecorderStore.swift)
  基于 App Group `UserDefaults` 的共享读写封装。

职责：

- 定义跨 target 的最小共享数据面
- 隔离共享存储细节
- 保证主 App 与键盘扩展的数据契约一致

当前共享的字段只保留“键盘真正需要知道的内容”：

- 当前状态
- 实时转写
- 当前轮最终文本
- 最近一次结果 ID
- 最近一次错误
- 更新时间

这个层很关键，因为后续如果把共享介质从 `UserDefaults` 换成文件、SQLite 或更稳定的 IPC，这里可以保持调用面不变。

### Support 层

- [DashScopeConfiguration.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/Support/DashScopeConfiguration.swift)
  阿里云 endpoint、区域和模型配置。
- [SettingsStore.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/Support/SettingsStore.swift)
  本地设置与环境变量读取。

职责：

- 提供运行时配置
- 屏蔽环境变量和 `UserDefaults` 读取细节
- 为上层提供可直接使用的配置对象

### KeyboardExtension 层

- [Info.plist](/Users/codefriday/workspace/project/typeless/TypelessApp/KeyboardExtension/Info.plist)
  键盘扩展声明，当前已启用 `RequestsOpenAccess`。
- [TypelessKeyboard.entitlements](/Users/codefriday/workspace/project/typeless/TypelessApp/KeyboardExtension/TypelessKeyboard.entitlements)
  键盘扩展的 App Group 能力声明。
- [KeyboardViewController.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/KeyboardExtension/KeyboardViewController.swift)
  `UIInputViewController` 容器，负责把 SwiftUI 视图挂到键盘扩展中，并调用 `textDocumentProxy`。
- [KeyboardRootView.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/KeyboardExtension/KeyboardRootView.swift)
  键盘扩展 UI。
- [KeyboardViewModel.swift](/Users/codefriday/workspace/project/typeless/TypelessApp/KeyboardExtension/KeyboardViewModel.swift)
  键盘端状态读取、结果可用性判断和最近一次插入状态管理。

职责：

- 展示主 App 同步过来的实时/最终结果
- 把最近一次最终结果插入当前输入框
- 撤销刚刚由键盘插入的结果
- 提供换行、删除、切换键盘等基础动作

当前键盘扩展不负责录音，只负责消费共享结果和执行输入动作。

## 4. 当前主链路数据流

### 主 App 侧

1. 用户在主 App 点击开始录音
2. `RecorderViewModel` 申请权限并切换状态
3. `PCM16MonoAudioCaptureService` 开始输出音频 chunk
4. `DashScopeRealtimeASRClient` 建立 WebSocket 并发送 `run-task`
5. partial 结果更新 `liveTranscript`
6. final 结果累积到 `committedTranscript`
7. 每次状态或文本变化，`RecorderViewModel` 都把快照写入 `SharedRecorderStore`

### 键盘侧

1. `KeyboardViewModel` 周期性读取 `SharedRecorderStore`
2. 键盘 UI 展示当前状态、实时预览和最近最终结果
3. 用户点击“插入最近结果”
4. `KeyboardViewController` 通过 `textDocumentProxy.insertText` 插入文本
5. 键盘记录本次插入的 `resultID` 和文本内容
6. 用户点击“撤销插入”
7. 键盘按插入文本长度调用 `deleteBackward`

## 5. 为什么当前先用 App Group + 轮询

这是一个刻意的 P0 取舍，不是最终方案。

原因：

- 最快落地
- 主 App 和键盘扩展都能直接用
- 不需要先引入更重的进程间通信设计
- 足够验证“主 App 产出结果，键盘消费结果”这件事

当前缺点也明确：

- 轮询不是最优的实时同步方式
- `UserDefaults(suiteName:)` 更适合小数据快照，不适合高频大文本
- 插入/撤销仍是轻量方案，不是完整编辑事务

如果后续进入 MVP，可以考虑升级为：

- 文件快照 + 时间戳
- 更明确的结果队列模型
- 多轮结果历史
- 更稳定的同步触发机制

## 6. 当前状态机语义

项目内部统一使用这组状态：

- `idle`
- `connecting`
- `recording`
- `processing`
- `completed`
- `error`

语义边界：

- `idle`：没有进行中的识别会话
- `connecting`：已准备录音，正在建立 ASR 链路
- `recording`：正在采音并持续发送音频
- `processing`：录音结束，等待最终结果
- `completed`：本轮已有可插入最终结果
- `error`：本轮失败，等待用户重试

这组状态会同时服务于：

- 主 App 自己的 UI
- 键盘扩展的状态展示
- 后续日志和调试输出

## 7. 当前边界与约束

### 当前允许的临时方案

- iOS 客户端直连阿里云
- API Key 从环境变量或本地设置注入
- 键盘通过 App Group 读取主 App 结果

### 当前明确不是正式方案的部分

- 客户端长期持有 API Key
- 键盘扩展自己直接连云做正式方案
- 用轮询作为长期同步机制

### 当前最重要的真实风险

- 真机上主 App 到阿里云的 WebSocket 链路是否完全稳定
- App Group / Full Access / 键盘启用流程在真机上是否一致
- iOS 对主 App 常驻、后台音频和键盘协同的限制是否影响最终体验

## 8. 后续推荐演进顺序

建议按这个顺序推进，而不是并行发散：

1. 真机验证当前主 App 录音到键盘插入链路
2. 验证键盘扩展启用、Full Access 和 App Group 的实际行为
3. 补最近一次结果撤销的真实边界测试
4. 评估主 App 常驻、后台音频和状态可见性
5. 再决定是否把 ASR 从客户端迁到服务端代理

## 9. 开发时的边界约束

后续继续开发时，建议保持以下规则：

- 不要让 `KeyboardExtension` 直接依赖 `Features/Home`
- 不要让 `Services` 知道 `SwiftUI` 状态
- 共享给键盘的数据只放到 `Shared` 层
- 新增业务能力时，优先先问“它属于 Feature、Service、Shared 还是 Support”
- 如果一个类型同时承担“页面状态”和“底层协议处理”，应拆分

一句话总结当前架构：

`主 App 负责采音和识别，Shared 层负责同步结果，Keyboard Extension 负责消费结果并执行输入动作。`

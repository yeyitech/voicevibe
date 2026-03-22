# Typeless 风格 iOS 语音键盘 P0 / MVP 一页 PRD

版本：v0.4  
日期：2026-03-23

## 1. 一句话目标

做一个 iPhone 端 Typeless 风格语音键盘，用阿里云 `fun-asr-realtime` 替代 Typeless 的识别能力，在尽量不跳页面的前提下实现：

- 键盘内实时转写
- 说完后自动纠错
- 一键插入当前输入框
- 支持至少一种外接麦克风方案

## 2. 当前结论

- `fun-asr-realtime` 可作为实时 ASR 底座，热词能力适合做专业词订正
- `DJI Mic` 这类外接麦克风在 iPhone 普通 App 内具备可行性
- 根据现象观察，Typeless 很可能不是“纯键盘扩展直采音”，而是 `主 App 常驻 + 键盘扩展协同`
- 最大不确定性已经从“键盘扩展能不能独立采麦”升级为 `主 App 常驻方案能否稳定、合规、可审核`

所以当前阶段不是直接开发 MVP，而是先做 `P0 技术验证`。

## 3. 当前优先技术假设

优先验证这条路线：

- 主 App 负责常驻、音频会话、ASR 链路、Live Activity 状态
- 键盘扩展负责 UI、状态显示、最终文本插入
- 两者通过共享容器或其他桥接方式同步转写结果

这只是当前最合理假设，不是已确认事实。

## 4. P0 只验证 5 件事

### P0-1 主 App 常驻与状态可见性

问题：

- 主 App 首次唤起后，能不能维持可观察状态，例如 Live Activity / 灵动岛状态

### P0-2 主 App 后台音频与 ASR

问题：

- 主 App 能不能在目标使用链路里维持音频会话、实时识别和网络连接

### P0-3 键盘与主 App 协同

问题：

- 键盘扩展能不能近实时拿到主 App 产生的转写结果并展示出来

### P0-4 文本插入

问题：

- 键盘内产出的最终文本能不能稳定插入当前输入框

### P0-5 外接麦克风路由

问题：

- 接上 `DJI Mic 接收器 + 手机` 后，主 App 能不能把它作为有效输入源稳定接入

## 5. 成功标准

只有同时满足以下条件，才进入 MVP 开发：

- 主 App 常驻方案可稳定工作
- 主 App 可稳定跑音频会话和 ASR
- 键盘扩展可稳定显示并插入结果
- 最终文本可稳定插入输入框
- 至少一种外接麦克风方案可用

## 6. MVP 最小范围

如果 P0 通过，MVP 只做：

- iPhone 第三方键盘形态
- 一个主麦克风按钮
- 实时转写预览
- 最终文本纠错
- 一键插入
- 热词词表
- 用户纠错词典

不做：

- 桌面端
- 声纹识别
- 团队能力
- 复杂 AI 改写模板
- 蓝牙直连麦克风作为主承诺

## 7. 纠错方案

MVP 的“好用感”不依赖单一 ASR，而依赖这三层：

- Fun-ASR 热词
- 用户词典替换
- 句末规则清洗

句末规则清洗只做：

- 口头禅删除
- 常见错词替换
- 标点补全
- 数字和日期规范化

## 8. No-Go 后的兜底方案

如果 P0 失败，立即转向：

- 自有 App 内的键盘式语音输入面板

保留：

- 实时转写
- 最终纠错
- 外接麦克风

放弃：

- 跨 App 系统键盘体验

## 9. 参考资料

- Typeless 官网：https://www.typeless.com/
- Typeless App Store：https://apps.apple.com/us/app/typeless-ai-voice-keyboard/id6749257650
- Apple ActivityKit：https://developer.apple.com/documentation/ActivityKit/
- Apple Live Activities：https://developer.apple.com/documentation/ActivityKit/displaying-live-data-with-live-activities
- Apple Custom Keyboard 文档：https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html
- Apple App Extension Keys：https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/AppExtensionKeys.html
- Apple Audio Session Basics：https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioSessionBasics/AudioSessionBasics.html
- Apple 音频输入选择 QA1799：https://developer.apple.com/library/archive/qa/qa1799/_index.html
- Apple iPhone 外接麦克风文档：https://support.apple.com/en-tj/guide/iphone/iph4d2a39a3b/ios
- 阿里云实时语音识别：https://www.alibabacloud.com/help/en/model-studio/real-time-speech-recognition
- 阿里云 Fun-ASR Realtime WebSocket API：https://www.alibabacloud.com/help/en/model-studio/fun-asr-realtime-websocket-api
- 阿里云自定义热词：https://www.alibabacloud.com/help/en/model-studio/custom-hot-words
- 阿里云模型列表：https://www.alibabacloud.com/help/en/model-studio/models
- DJI Mic FAQ：https://www.dji.com/tw/support/product/mic
- DJI Mic 2 FAQ：https://www.dji.com/sg/mic-2/faq
- DJI Mic Mini FAQ：https://www.dji.com/ca/mic-mini/faq

# Typeless

Typeless 是一个双端验证仓：

- `TypelessApp/`
  iOS P0 工程，验证主 App 录音、阿里云实时 ASR、键盘扩展协同
- `macOS端/`
  macOS 独立工程，验证全局按键唤起、录音结束后整段转写、自动插字与剪贴板回退

当前推荐直接使用 macOS 端。

## 仓库结构

- `TypelessApp.xcodeproj`
  iOS 工程
- `macOS端/TypelessMac.xcodeproj`
  macOS 工程
- `scripts/build_macos_release.sh`
  一键构建并打包最新 macOS 版本
- `ARCHITECTURE.md`
  iOS P0 架构说明
- `PRD.md`
  当前产品和验证范围
- `FUN_ASR_REALTIME.md`
  阿里云 Fun-ASR Realtime 协议要点

## macOS 安装

### 1. 直接使用已经打好的本地开发版

固定路径：

```bash
~/Applications/Typeless\ Mac\ Dev.app
```

打开：

```bash
open "$HOME/Applications/Typeless Mac Dev.app"
```

### 2. 重新构建最新版本

执行：

```bash
./scripts/build_macos_release.sh
```

脚本会做三件事：

- 用 `Release` 配置构建最新 macOS app
- 产出本地安装包到 `dist/`
- 同步一份固定开发版到 `~/Applications/Typeless Mac Dev.app`

构建完成后，主要产物在：

```bash
dist/Typeless Mac Dev.app
dist/Typeless-Mac-Dev.zip
```

## macOS 首次使用

启动前或启动后，需要给 `Typeless Mac Dev.app` 打开权限：

- `隐私与安全性 -> 麦克风`
- `隐私与安全性 -> 输入监控`
- `隐私与安全性 -> 辅助功能`

权限含义：

- `麦克风`
  决定能不能录音
- `输入监控`
  决定能不能在其他 App 里通过全局按键唤起录音
- `辅助功能`
  决定能不能把转写结果直接插到当前输入框

如果没有可插入位置，macOS 端会自动把结果回退到剪贴板。

## macOS 配置

当前桌面端会从两处读取 DashScope 配置：

- 环境变量
- app 自己的本地配置

必须项：

```bash
DASHSCOPE_API_KEY=你的阿里云 API Key
```

可选：

```bash
DASHSCOPE_REGION=beijing
DASHSCOPE_MODEL=fun-asr-realtime
DASHSCOPE_LANGUAGE_HINTS=zh,en
DASHSCOPE_VOCABULARY_ID=你的热词表ID
TYPELESS_TRIGGER_MODE=fn_hold
```

注意：

- `API Key` 不是写死的，仍然可以在 macOS app 里修改
- 当前默认触发键为 `Fn`
- 如果 `Fn` 和其他工具冲突，可以切回 `右 Command` 或 `右 Option`

## iOS 本地运行

1. 打开 `TypelessApp.xcodeproj`
2. 在 Xcode 里选择 `TypelessApp` Scheme
3. 在 `Run > Arguments` 里配置：

```bash
DASHSCOPE_API_KEY=你的阿里云 API Key
```

优先真机运行。键盘扩展需要同时启用：

- App Group
- Full Access

## 当前状态

### macOS

- 全局按键唤起录音
- 录音结束后整段转写
- 自动插字与剪贴板回退
- 累计历史统计
- 固定开发版路径与本地安装包产物

### iOS

- 主 App 实时录音与 ASR
- 键盘扩展消费共享结果
- App Group 状态同步

## 补充文档

- [ARCHITECTURE.md](/Users/codefriday/workspace/project/typeless/ARCHITECTURE.md)
- [PRD.md](/Users/codefriday/workspace/project/typeless/PRD.md)
- [FUN_ASR_REALTIME.md](/Users/codefriday/workspace/project/typeless/FUN_ASR_REALTIME.md)
- [macOS端/README.md](/Users/codefriday/workspace/project/typeless/macOS端/README.md)

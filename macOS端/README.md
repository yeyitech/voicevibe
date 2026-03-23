# Typeless macOS

这是和 iOS 端完全解耦的 macOS 独立工程。

当前桌面端主链路：

- 全局按键唤起录音
- 录音结束后整段转写
- 有可插入目标时直接插字
- 没有可插入目标时自动复制到剪贴板
- 保留累计历史统计

## 目录

- `TypelessMac/`
  macOS 独立源码
- `TypelessMac.xcodeproj`
  macOS 工程
- `scripts/generate_xcodeproj.rb`
  从源码重新生成 Xcode 工程

## 构建

在仓库根目录执行：

```bash
./scripts/build_macos_release.sh
```

或者手动：

```bash
cd macOS端
xcodebuild -project TypelessMac.xcodeproj -scheme TypelessMac -configuration Release CODE_SIGNING_ALLOWED=NO build
```

## 构建产物

脚本构建后会生成：

```bash
dist/Typeless Mac Dev.app
dist/Typeless-Mac-Dev.zip
```

同时会同步一份固定开发版到：

```bash
~/Applications/Typeless Mac Dev.app
```

## 首次安装 / 使用

1. 打开：

```bash
open "$HOME/Applications/Typeless Mac Dev.app"
```

2. 授权：

- 麦克风
- 输入监控
- 辅助功能

3. 如果没有可插入位置，结果会自动复制到剪贴板

## 配置

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

说明：

- `API Key` 仍然可在 app 内修改
- 当前默认触发键为 `Fn`
- 如果和其他工具冲突，可以切回 `右 Command` 或 `右 Option`

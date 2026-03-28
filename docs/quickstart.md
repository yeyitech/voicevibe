# VoiceVibe Quick Start

这份文档只讲第一次把 VoiceVibe 跑起来需要做什么。

## 1. 安装

如果你是普通用户:

1. 去 GitHub Releases 下载对应架构的安装包:
   - `VoiceVibe-<version>-mac-arm64.dmg`
   - `VoiceVibe-<version>-mac-x64.dmg`
2. 拖进 `/Applications`
3. 首次打开时，如果 macOS 提示来源校验，按系统提示放行

如果你是开发者:

```bash
npm install
npm run dev
```

## 2. 第一次启动先做什么

先别急着按住说话，先在设置页做三件事:

1. 选 provider
2. 申请权限
3. 先跑一次“手动开始 / 停止并转写”

需要的权限:

- 麦克风
- 辅助功能

说明:

- `麦克风` 用来录音
- `辅助功能` 用来监听全局按键和把结果插入当前输入框

如果你只想测试“录音 + 转写 + 复制到剪贴板”，可以先把结果处理改成“只复制到剪贴板”。

## 3. 选哪种 provider

### 阿里云百炼 / DashScope

适合:

- 已经有阿里云账号
- 希望用官方云端 ASR
- 需要 `vocabulary_id` 或 `phrase_id`

你要准备:

- API Key

开通路径:

1. 打开阿里云百炼控制台 API Key 页面
2. 创建或查看 API Key
3. 复制到 VoiceVibe

官方资料:

- <https://help.aliyun.com/zh/model-studio/get-api-key>
- <https://help.aliyun.com/zh/isi/product-overview/billing-10>

注意:

- DashScope 更适合配合云端词表 ID 使用
- VoiceVibe 会帮你导出阿里云词表 JSON
- 仓库里的 `scripts/manage_hotwords.py` 可以把 JSON 同步到官方 vocabulary

### 火山引擎

适合:

- 希望直接传热词
- 希望应用级词条库自动参与增强
- 想通过控制台管理应用和试用额度

你要准备:

- App Key
- Access Token
- Resource ID

开通路径:

1. 打开豆包语音控制台
2. 创建应用
3. 在应用详情中取回凭证
4. 把值填进 VoiceVibe

官方资料:

- <https://console.volcengine.com/speech/app>
- <https://www.volcengine.com/docs/6561/163043?lang=zh>
- <https://www.volcengine.com/docs/6561/1354869?lang=zh>

注意:

- 官方快速入门写明，首次创建应用后默认为试用版本，并提供一定免费额度用于测试
- 商用接入时再升级正式版

### 本地 OpenWhisper

适合:

- 最重视隐私
- 不希望敏感输入发往第三方云端
- 希望自己掌控模型和词条

你要准备:

- `whisper.cpp`
- 一个本地模型

最快路径:

1. 在应用里点“通过 Homebrew 安装 Runtime”
2. 选择模型
3. 点“下载当前模型”

也可以自己手动安装:

- <https://github.com/ggml-org/whisper.cpp>
- <https://github.com/ggml-org/whisper.cpp/releases>

建议:

- 首次建议 `base`
- 对识别更稳有要求、机器也够强时再上 `small` 或 `medium`

### VibeVoice Server

适合:

- 你已经有 GPU 机器或云上推理服务
- 想试 VibeVoice-ASR 的长上下文、结构化能力和 hotwords
- 不想把 9B 模型直接塞进桌面应用

你要准备:

- 一套你自己部署的 VibeVoice-ASR 服务
- 最方便的方式是官方 vLLM 插件暴露的 OpenAI-compatible 接口

推荐路径:

1. 按官方文档在 GPU 机器上部署 VibeVoice-ASR
2. 确认 `/v1/chat/completions` 可访问
3. 把服务地址填进 VoiceVibe 的 `Base URL`
4. 录入 personal terms 和 provider hotwords

官方资料:

- <https://github.com/microsoft/VibeVoice>
- <https://github.com/microsoft/VibeVoice/blob/main/docs/vibevoice-asr.md>
- <https://github.com/microsoft/VibeVoice/blob/main/docs/vibevoice-vllm-asr.md>
- <https://huggingface.co/microsoft/VibeVoice-ASR>

注意:

- 官方文档主推的是 NVIDIA Docker / vLLM / GPU 部署
- 这条 provider 更适合作为实验性、自托管后端，不适合当成轻量本地默认方案
- 官方 README 明确写了 `research and development only`

## 4. 配置个人词条库

把这些内容优先录进去:

- 你的名字
- 公司的常用称呼
- 产品名
- 项目代号
- 英文缩写
- 常写错的专有名词

为什么先做这一步:

- 火山引擎会直接吃到这些词条
- OpenWhisper 会把它们变成 prompt hints
- VibeVoice Server 会把这些词条和 provider hotwords 合并后作为上下文提示发给服务端
- 这通常比盲目换大模型更直接地改善“专有词识别错误”

## 5. 测试最短闭环

推荐测试顺序:

1. 先把结果处理切成“只复制到剪贴板”
2. 点击“手动开始”
3. 说一句包含专有词的句子
4. 点击“停止并转写”
5. 检查历史记录和剪贴板结果
6. 再切回“自动插入当前输入框”
7. 最后再测试 `Fn` 或 `右 Command` 按住说话

这样能把问题快速定位到:

- 权限
- provider 凭证
- 模型
- 词条
- 自动插入

## 6. 常见问题

### 按住快捷键没有反应

先看这三项:

- 是否已经启用 VoiceVibe
- `辅助功能` 是否授权
- 当前 provider 是否已配置完成

### 录到声音但没有插入输入框

通常是:

- 没有辅助功能权限
- 当前应用阻止模拟粘贴

这时 VoiceVibe 会退回到剪贴板。

### OpenWhisper 点安装没反应

检查:

- 本机是否安装 Homebrew
- 网络是否能访问 `whisper.cpp` 和模型下载源

### 阿里云词条为什么没有直接生效

因为 DashScope 这条链路更偏向引用云端 `vocabulary_id` / `phrase_id`。

做法:

1. 在 VoiceVibe 维护个人词条
2. 复制应用导出的 JSON
3. 用仓库脚本同步到阿里云 vocabulary
4. 把返回的 `vocabulary_id` 填回应用

### VibeVoice 配好了但请求失败

先看这几项:

- `Base URL` 是否真的能访问到 `/v1/chat/completions`
- 反向代理如果做了鉴权，`API Key` 是否正确
- 服务端是否真的把 VibeVoice 插件加载起来
- GPU / vLLM 服务是否已经把模型拉取完成

## 7. 本地构建与打包

开发构建:

```bash
npm run build
```

本地打包 macOS arm64:

```bash
npm run dist:mac:arm64
```

本地打包 macOS x64:

```bash
npm run dist:mac:x64
```

GitHub Release:

- 推送 `v*` tag 即可触发 `.github/workflows/release.yml`

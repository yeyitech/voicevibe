# Fun-ASR Realtime 最小接入说明

版本：v0.1  
日期：2026-03-23

## 1. 这份文档的用途

只保留后续开发会直接用到的最小上下文：

- 选哪个模型
- 连哪个 WebSocket
- 最小请求怎么发
- 结果怎么读
- 热词怎么挂
- 最容易踩的坑是什么

## 2. 推荐选择

对当前项目，默认选择：

- 区域：`Beijing`
- 模型：`fun-asr-realtime`
- 音频：`16 kHz`、单声道、`pcm`

原因：

- 对中文场景合适
- 成本低于国际区
- 官方稳定模型名就是 `fun-asr-realtime`

当前公开价格：

- 北京区：`$0.000047/second`
- 国际区：`$0.00009/second`

## 3. 基本前提

需要先准备：

- 阿里云 Model Studio / 百炼 API Key
- 目标区域对应的 endpoint
- 麦克风音频流

环境变量建议统一使用：

```bash
export DASHSCOPE_API_KEY="your-api-key"
```

## 4. Endpoint

按区域区分：

- 北京区：`wss://dashscope.aliyuncs.com/api-ws/v1/inference`
- 国际区：`wss://dashscope-intl.aliyuncs.com/api-ws/v1/inference`

当前项目优先北京区。

## 5. 最小接入流程

最小流程只有 5 步：

1. 建立 WebSocket 连接
2. 发送 `run-task`
3. 持续发送音频帧
4. 监听 `result-generated`
5. 停止时结束当前任务

实现上要注意：

- 一个连接可以复用多个任务
- 每个任务必须使用新的 `task_id`
- 如果任务失败，服务端会关闭连接，下一次必须重连

## 6. 最小请求体

接入时最核心的是 `run-task` 消息。最小参数可以先只保留这些：

```json
{
  "header": {
    "action": "run-task",
    "task_id": "uuid",
    "streaming": "duplex"
  },
  "payload": {
    "task_group": "audio",
    "task": "asr",
    "function": "recognition",
    "model": "fun-asr-realtime",
    "parameters": {
      "format": "pcm",
      "sample_rate": 16000
    },
    "input": {}
  }
}
```

如果接热词，在 `parameters` 里加：

```json
{
  "vocabulary_id": "vocab-xxx"
}
```

如果要提示语言，在 `parameters` 里加：

```json
{
  "language_hints": ["zh"]
}
```

## 7. 音频要求

当前项目建议统一按这套走：

- 编码：`pcm`
- 采样率：`16000`
- 声道：单声道

虽然官方支持 `wav/mp3/opus/speex/aac/amr`，但对实时键盘输入场景，`pcm + 16kHz` 最省事。

## 8. 结果解析

核心只看 `result-generated` 事件。

关键字段在：

```json
payload.output.sentence
```

最重要的字段：

- `text`：当前识别文本
- `sentence_end`：是否已成为最终结果
- `heartbeat`：是否只是保活事件

处理规则：

- `sentence_end = false`：当作实时预览
- `sentence_end = true`：当作最终文本
- `heartbeat = true`：忽略，不渲染给用户

推荐策略：

- 键盘实时预览区展示所有非 heartbeat 的 `text`
- 只有 `sentence_end = true` 的结果进入最终纠错链路

## 9. 结束一个任务

实际代码里要支持“当前句子结束”或“用户手动停止”。

可以按这个思路实现：

- 用户点停止
- 停止继续发送音频
- 等最后一个 final result
- 结束当前任务

文档层面，这里最重要的是：

- 一个会话结束后，连接可以继续复用
- 如果 60 秒内不启动新任务，连接会自动超时关闭

## 10. 热词最小用法

热词是这次产品里最重要的能力之一，因为它直接影响“专业词纠错感”。

最小链路：

1. 先创建热词表
2. 拿到 `vocabulary_id`
3. 在识别请求里带上 `vocabulary_id`

热词规则里最关键的字段：

- `text`
- `weight`
- 可选 `lang`

建议默认：

- `weight = 4`
- 中文词条带 `lang: "zh"` 也可以，不确定时可留空

当前官方限制：

- 每个账号最多 `10` 个热词表
- 每个热词表最多 `500` 个词

建议做法：

- 不要每个用户建很多热词表
- MVP 阶段只维护 1 个主热词表
- 用户新增专业词时，批量合并进主热词表

## 11. 推荐接入参数

对当前语音键盘场景，建议先用这组思路：

- `model = fun-asr-realtime`
- `format = pcm`
- `sample_rate = 16000`
- `language_hints = ["zh"]`
- 有热词时带 `vocabulary_id`

如果用户是中英混说，可以再评估：

- `language_hints = ["zh", "en"]`

## 12. 键盘场景下的处理建议

这个项目不是会议转录，而是语音输入键盘，所以建议这样分层：

- ASR 层：只负责尽快给出 partial / final
- 键盘层：负责 UI 状态和插入动作
- 后处理层：负责纠错和清洗

不要指望 ASR 一层直接做完 Typeless 那种体验。

对当前项目，更合理的链路是：

- 实时识别
- final result 出来后做一次轻量规则清洗
- 再进入文本插入

## 13. 最容易踩的坑

### 13.1 音频参数不匹配

最常见问题就是：

- 实际音频不是 `16kHz pcm`
- 但请求里写成了 `pcm + 16000`

这会直接导致识别异常或结果很差。

### 13.2 把 partial 当 final 用

`sentence_end = false` 的文本会变化，不要直接插入输入框。

### 13.3 忽略 heartbeat 机制

长停顿时如果要保连接：

- 需要开启 `heartbeat`
- 还要继续发送静音音频

否则连接会在长静默后超时。

但对语音键盘这种短会话场景，第一版通常不需要为了停顿去复杂保活。

### 13.4 热词表和模型不一致

创建热词表时要绑定目标模型。后续识别时，模型和热词表要保持一致。

### 13.5 过度依赖热词

热词能拉正专有名词，但不能替代句级纠错。

想接近 Typeless 的“它会帮我修”，仍然需要：

- 用户词典
- 规则清洗
- 必要时再加语义后处理

## 14. 最小伪代码

```text
connect websocket
send run-task(model=fun-asr-realtime, format=pcm, sample_rate=16000, vocabulary_id?)

while recording:
  read audio frame
  send frame

on message:
  if event != result-generated:
    ignore
  if sentence.heartbeat == true:
    ignore
  if sentence.sentence_end == false:
    update live preview
  else:
    finalText = sentence.text
    correctedText = postProcess(finalText)
    show correctedText

on stop:
  stop audio
  wait final result
  end task
```

## 15. 当前项目的最小接入建议

如果开始做 P0，Fun-ASR 这部分建议只做这些：

- 只接北京区
- 只接 `fun-asr-realtime`
- 只接 `pcm 16kHz mono`
- 只处理 `result-generated`
- 只用一个 `vocabulary_id`
- 只做中文优先

先把链路跑通，再扩参数。

## 16. 参考资料

- 实时语音识别总览：https://www.alibabacloud.com/help/en/model-studio/real-time-speech-recognition
- Fun-ASR Realtime WebSocket API：https://www.alibabacloud.com/help/en/model-studio/fun-asr-realtime-websocket-api
- 自定义热词：https://www.alibabacloud.com/help/en/model-studio/custom-hot-words
- 模型列表与价格：https://www.alibabacloud.com/help/en/model-studio/models

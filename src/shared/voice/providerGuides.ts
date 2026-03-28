import type { VoiceInputProviderId } from '@shared/voice/types';

export type ProviderGuide = {
  title: string;
  summary: string;
  updatedAt: string;
  trialNote: string;
  pricingNote: string;
  setupSteps: string[];
  links: Array<{
    label: string;
    url: string;
  }>;
  tips: string[];
};

export const PROVIDER_GUIDES: Record<VoiceInputProviderId, ProviderGuide> = {
  dashscope: {
    title: '阿里云百炼 / DashScope',
    summary: '适合想快速接入中文语音识别、且已经在用阿里云账号体系的桌面用户。',
    updatedAt: '2026-03-28',
    trialNote:
      '根据 2026-03-28 官方页面，百炼模型服务提供新用户试用路径和价格页，具体免费额度与活动会随账号和活动变化，请以控制台与官方价格页为准。',
    pricingNote:
      'VoiceVibe 本身不收取订阅费。使用 DashScope 时，你直接向阿里云支付实际语音识别费用。',
    setupSteps: [
      '先在阿里云百炼控制台开通模型服务，并进入 API Key 页面创建或查看 API Key。',
      '如果你要做词表增强，可以先在阿里云语音识别定制页创建 vocabulary 或 phrase，再把对应 ID 填回 VoiceVibe。',
      '推荐先用默认模型跑通，再逐步补充 language hints、vocabulary_id 和 phrase_id。',
    ],
    links: [
      { label: '百炼 API Key', url: 'https://help.aliyun.com/zh/model-studio/get-api-key' },
      { label: '实时语音识别定制', url: 'https://help.aliyun.com/zh/isi/developer-reference/realtime-speech-recognition' },
      { label: '语音识别定制价格', url: 'https://help.aliyun.com/zh/isi/product-overview/pricing' },
    ],
    tips: [
      'DashScope 当前更适合通过 vocabulary_id 或 phrase_id 使用云端词表，不是直接把本地词条列表随请求上传。',
      '你可以先在 VoiceVibe 维护个人词条，再把它导出为阿里云词表 JSON，配合仓库脚本同步。',
    ],
  },
  volcengine: {
    title: '火山引擎语音技术',
    summary: '适合希望直接传热词、做领域增强，并且想用火山引擎控制台管理应用和资源的用户。',
    updatedAt: '2026-03-28',
    trialNote:
      '根据 2026-03-28 官方页面，火山引擎语音技术提供控制台试用和价格说明，新账号常见有试用资源或活动额度，但具体以你的账号控制台为准。',
    pricingNote:
      'VoiceVibe 只负责桌面输入体验，不代收任何火山引擎费用。实际 ASR 成本由你的火山引擎账户承担。',
    setupSteps: [
      '先在火山引擎语音技术控制台创建应用，进入应用详情页获取 App Key、Access Token 和 Resource ID。',
      '如果你需要更强的领域识别，可在控制台中创建热词表、纠错表，然后把 boosting_table_id 或 correct_table_id 回填到 VoiceVibe。',
      '应用级个人词条会自动和 provider 专属 hotwords 合并，一起发送给火山引擎识别接口。',
    ],
    links: [
      { label: '语音技术控制台', url: 'https://console.volcengine.com/speech/app' },
      { label: '接入概览', url: 'https://www.volcengine.com/docs/6561/111524' },
      { label: '流式语音识别 WebSocket', url: 'https://www.volcengine.com/docs/6561/1354869?lang=zh' },
      { label: '计费与资源', url: 'https://www.volcengine.com/docs/6561/163043' },
    ],
    tips: [
      '最常见的接入错误是 Access Token、Resource ID 或应用权限不匹配，先用控制台示例参数确认一遍。',
      '如果你已经有固定行业词表，优先把它们放进 personal terms，再按需要补 provider 专属 hotwords。',
    ],
  },
  openWhisper: {
    title: '本地 OpenWhisper / whisper.cpp',
    summary: '适合最重视隐私、希望完全本地转写、不希望敏感文本进入第三方云端的用户。',
    updatedAt: '2026-03-28',
    trialNote: '本地运行没有云厂商试用额度概念，成本主要是你本机的 CPU、内存和模型下载时间。',
    pricingNote: 'VoiceVibe 免费，whisper.cpp 开源。只要机器能跑模型，你就可以持续本地使用。',
    setupSteps: [
      '先通过 Homebrew 安装 whisper.cpp，或者手动下载可执行文件并在 VoiceVibe 里指定 CLI 路径。',
      '首次使用时下载一个模型。`base` 和 `small` 是桌面场景里更平衡的选择。',
      '应用级个人词条会自动变成 prompt hints，帮助本地模型更稳地识别人名、项目名和术语。',
    ],
    links: [
      { label: 'whisper.cpp GitHub', url: 'https://github.com/ggml-org/whisper.cpp' },
      { label: 'whisper.cpp Releases', url: 'https://github.com/ggml-org/whisper.cpp/releases' },
      { label: 'Homebrew whisper-cpp', url: 'https://formulae.brew.sh/formula/whisper-cpp' },
    ],
    tips: [
      '完全本地模式最适合内部文档、客户信息、代码注释、产品代号等敏感内容。',
      '模型越大，识别效果通常越稳，但内存占用和等待时间也会更高。',
    ],
  },
  vibevoice: {
    title: 'VibeVoice-ASR Server',
    summary: '适合已经有 GPU 服务器，想把 VibeVoice-ASR 作为长音频、强上下文、可带热词的实验性转写后端接入 VoiceVibe 的用户。',
    updatedAt: '2026-03-28',
    trialNote:
      '根据 2026-03-28 Microsoft 官方仓库，VibeVoice-ASR 已进入 Transformers 生态，并提供 vLLM OpenAI-compatible API 部署方案；官方文档主推 NVIDIA Docker / GPU 服务，不是轻量桌面本地模型。',
    pricingNote:
      'VibeVoice 本身是研究模型。VoiceVibe 这里只接你自己部署的服务地址，不代管推理资源。GPU、云主机或私有集群成本由你自己承担。',
    setupSteps: [
      '先按官方仓库文档，在 GPU 机器上部署 VibeVoice-ASR。最实用的接法是官方 vLLM 插件，它暴露 OpenAI-compatible `/v1/chat/completions` 接口。',
      '在 VoiceVibe 里把 Base URL 填成你的服务地址，例如 `http://localhost:8000` 或内网网关地址。',
      '应用级个人词条会自动和 provider 专属 hotwords 合并，并作为上下文提示发给 VibeVoice 服务。',
    ],
    links: [
      { label: 'GitHub 仓库', url: 'https://github.com/microsoft/VibeVoice' },
      { label: 'VibeVoice-ASR 文档', url: 'https://github.com/microsoft/VibeVoice/blob/main/docs/vibevoice-asr.md' },
      { label: 'vLLM ASR 部署', url: 'https://github.com/microsoft/VibeVoice/blob/main/docs/vibevoice-vllm-asr.md' },
      { label: 'Hugging Face 模型', url: 'https://huggingface.co/microsoft/VibeVoice-ASR' },
    ],
    tips: [
      '这条接法更适合“你自己有 GPU 服务”的场景，不适合当成默认轻量本地 provider。',
      '官方 README 明确把 VibeVoice 标成 research and development only，正式业务接入前需要你自己做稳定性和成本验证。',
    ],
  },
};

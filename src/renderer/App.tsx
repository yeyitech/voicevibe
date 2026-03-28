import { useEffect, useMemo, useState } from 'react';
import { DEFAULT_VOICE_INPUT_CONFIG, EMPTY_VOICE_INPUT_STATS } from '@shared/voice/defaults';
import { PROVIDER_GUIDES } from '@shared/voice/providerGuides';
import type {
  VoiceInputConfig,
  VoiceInputHistoryRecord,
  VoiceInputOpenWhisperModelId,
  VoiceInputOpenWhisperState,
  VoiceInputProviderId,
  VoiceInputState,
  VoiceInputStats,
} from '@shared/voice/types';

const OPEN_WHISPER_MODELS: Array<{
  id: VoiceInputOpenWhisperModelId;
  sizeBytes: number;
  recommendedMemoryGb: number;
}> = [
  { id: 'tiny', sizeBytes: 77_691_713, recommendedMemoryGb: 4 },
  { id: 'base', sizeBytes: 147_951_465, recommendedMemoryGb: 8 },
  { id: 'small', sizeBytes: 487_601_967, recommendedMemoryGb: 8 },
  { id: 'medium', sizeBytes: 1_533_763_059, recommendedMemoryGb: 16 },
  { id: 'large-v3-turbo', sizeBytes: 1_624_555_275, recommendedMemoryGb: 16 },
];

const splitListInput = (value: string): string[] =>
  value
    .split(/[\n,]/u)
    .map((item) => item.trim())
    .filter((item, index, list) => item.length > 0 && list.indexOf(item) === index);

const formatFileSize = (value: number): string => {
  if (value >= 1024 * 1024 * 1024) {
    return `${(value / (1024 * 1024 * 1024)).toFixed(1)} GB`;
  }

  return `${Math.round(value / (1024 * 1024))} MB`;
};

const formatDuration = (value: number): string => {
  const totalSeconds = Math.floor(value / 1000);
  if (totalSeconds <= 0) {
    return '< 1s';
  }

  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  const parts: string[] = [];

  if (hours > 0) {
    parts.push(`${hours}h`);
  }

  if (minutes > 0) {
    parts.push(`${minutes}m`);
  }

  if (seconds > 0 || parts.length === 0) {
    parts.push(`${seconds}s`);
  }

  return parts.join(' ');
};

const formatDateTime = (value: number): string =>
  new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(value);

const statusLabelMap: Record<string, string> = {
  idle: '空闲',
  recording: '录音中',
  transcribing: '转写中',
  inserted: '已插入',
  copied: '已复制',
  error: '出错',
  unsupported: '暂不支持',
  granted: '已授权',
  denied: '未授权',
  restricted: '受限',
  'not-determined': '未决定',
};

const providerLabelMap: Record<VoiceInputProviderId, string> = {
  dashscope: '阿里云百炼',
  volcengine: '火山引擎',
  openWhisper: '本地 OpenWhisper',
  vibevoice: 'VibeVoice Server',
};

const createDashScopeVocabularyPreview = (terms: string[], region: VoiceInputConfig['providers']['dashscope']['region']): string => {
  const entries = terms.map((text) => ({
    text,
    weight: 5,
    lang: /[\u4e00-\u9fff]/u.test(text) ? 'zh' : 'en',
  }));

  return JSON.stringify(
    {
      prefix: 'voicevibe',
      target_model: 'fun-asr',
      region,
      entries,
    },
    null,
    2
  );
};

export function App() {
  const voiceInputApi = window.voiceVibe.voiceInput;
  const [draft, setDraft] = useState<VoiceInputConfig>(DEFAULT_VOICE_INPUT_CONFIG);
  const [state, setState] = useState<VoiceInputState | null>(null);
  const [stats, setStats] = useState<VoiceInputStats>(EMPTY_VOICE_INPUT_STATS);
  const [history, setHistory] = useState<VoiceInputHistoryRecord[]>([]);
  const [openWhisperState, setOpenWhisperState] = useState<VoiceInputOpenWhisperState | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [busyAction, setBusyAction] = useState<string | null>(null);

  const currentGuide = PROVIDER_GUIDES[draft.providerId];
  const dashScopeVocabularyPreview = useMemo(
    () => createDashScopeVocabularyPreview(draft.personalTerms, draft.providers.dashscope.region),
    [draft.personalTerms, draft.providers.dashscope.region]
  );

  const refreshRuntimeData = async (): Promise<void> => {
    const [nextState, nextStats, nextHistory] = await Promise.all([
      voiceInputApi.getState(),
      voiceInputApi.getStats(),
      voiceInputApi.listHistory(),
    ]);

    setState(nextState);
    setStats(nextStats);
    setHistory(nextHistory);
  };

  const refreshOpenWhisper = async (): Promise<void> => {
    const nextState = await voiceInputApi.getOpenWhisperState();
    setOpenWhisperState(nextState);
  };

  const refresh = async (): Promise<void> => {
    const [config] = await Promise.all([voiceInputApi.getConfig()]);
    setDraft(config);
    await Promise.all([refreshRuntimeData(), refreshOpenWhisper()]);
  };

  useEffect(() => {
    let disposed = false;

    void refresh()
      .catch((error) => {
        console.error('[VoiceVibe] Failed to refresh UI state', error);
      })
      .finally(() => {
        if (!disposed) {
          setLoading(false);
        }
      });

    const unsubscribe = voiceInputApi.onStateChanged((nextState) => {
      if (disposed) {
        return;
      }

      setState(nextState);
      void Promise.all([voiceInputApi.getStats(), voiceInputApi.listHistory()])
        .then(([nextStats, nextHistory]) => {
          if (!disposed) {
            setStats(nextStats);
            setHistory(nextHistory);
          }
        })
        .catch(() => {});
    });

    return () => {
      disposed = true;
      unsubscribe();
    };
  }, []);

  const updateDraft = (updater: (current: VoiceInputConfig) => VoiceInputConfig): void => {
    setDraft((current) => updater(current));
  };

  const saveConfig = async (): Promise<void> => {
    setSaving(true);
    try {
      const nextConfig = await voiceInputApi.setConfig(draft);
      setDraft(nextConfig);
      await Promise.all([refreshRuntimeData(), refreshOpenWhisper()]);
    } finally {
      setSaving(false);
    }
  };

  const handleRequestPermissions = async (): Promise<void> => {
    setBusyAction('permissions');
    try {
      await voiceInputApi.requestPermissions();
      await refreshRuntimeData();
    } finally {
      setBusyAction(null);
    }
  };

  const handleStart = async (): Promise<void> => {
    setBusyAction('start');
    try {
      await saveConfig();
      await voiceInputApi.startManualCapture();
      await refreshRuntimeData();
    } finally {
      setBusyAction(null);
    }
  };

  const handleStop = async (): Promise<void> => {
    setBusyAction('stop');
    try {
      await voiceInputApi.stopManualCapture();
      await refreshRuntimeData();
    } finally {
      setBusyAction(null);
    }
  };

  const handleInstallRuntime = async (): Promise<void> => {
    setBusyAction('install-runtime');
    try {
      await saveConfig();
      const nextState = await voiceInputApi.installOpenWhisperRuntime();
      setOpenWhisperState(nextState);
    } finally {
      setBusyAction(null);
    }
  };

  const handleInstallModel = async (): Promise<void> => {
    setBusyAction('install-model');
    try {
      await saveConfig();
      const nextState = await voiceInputApi.installOpenWhisperModel(draft.providers.openWhisper.modelId);
      setOpenWhisperState(nextState);
    } finally {
      setBusyAction(null);
    }
  };

  const handleOpenLink = async (url: string): Promise<void> => {
    await voiceInputApi.openExternal(url);
  };

  const copyDashScopePreview = async (): Promise<void> => {
    await navigator.clipboard.writeText(dashScopeVocabularyPreview);
  };

  const openWhisperSelectedModel = openWhisperState?.models.find((item) => item.id === draft.providers.openWhisper.modelId);

  return (
    <div className="app-shell">
      <div className="ambient ambient-left" />
      <div className="ambient ambient-right" />

      <header className="hero-card">
        <div className="hero-copy">
          <p className="eyebrow">VOICEVIBE / DESKTOP VOICE INPUT</p>
          <h1>按住说话，松开落字。</h1>
          <p className="hero-summary">
            一个桌面优先、开源、可私有化的语音输入工具。它保留 Typeless 这类产品最顺手的交互，
            但把 provider 选择权、词条库和本地运行能力交还给你。
          </p>
        </div>

        <div className="hero-status">
          <div className="stat-pill">
            <span>运行状态</span>
            <strong>{statusLabelMap[state?.status ?? 'idle'] ?? '空闲'}</strong>
          </div>
          <div className="stat-pill">
            <span>当前 provider</span>
            <strong>{providerLabelMap[draft.providerId]}</strong>
          </div>
          <div className="stat-pill">
            <span>个人词条</span>
            <strong>{draft.personalTerms.length}</strong>
          </div>
          <div className="hero-actions">
            <button className="button button-secondary" onClick={() => void handleRequestPermissions()} disabled={busyAction === 'permissions'}>
              {busyAction === 'permissions' ? '请求中…' : '检查权限'}
            </button>
            <button className="button button-secondary" onClick={() => void handleStart()} disabled={busyAction === 'start' || state?.status === 'recording'}>
              {busyAction === 'start' ? '启动中…' : '手动开始'}
            </button>
            <button className="button button-primary" onClick={() => void handleStop()} disabled={busyAction === 'stop' || state?.status !== 'recording'}>
              {busyAction === 'stop' ? '停止中…' : '停止并转写'}
            </button>
          </div>
        </div>
      </header>

      <main className="dashboard-grid">
        <section className="card">
          <div className="card-head">
            <div>
              <p className="card-kicker">桌面主链路</p>
              <h2>基础设置</h2>
            </div>
            <button className="button button-primary" onClick={() => void saveConfig()} disabled={saving || loading}>
              {saving ? '保存中…' : '保存设置'}
            </button>
          </div>

          <div className="field-grid">
            <label className="field">
              <span>启用全局语音输入</span>
              <select
                value={draft.enabled ? 'true' : 'false'}
                onChange={(event) =>
                  updateDraft((current) => ({
                    ...current,
                    enabled: event.target.value === 'true',
                  }))
                }
              >
                <option value="true">启用</option>
                <option value="false">关闭</option>
              </select>
            </label>

            <label className="field">
              <span>Provider</span>
              <select
                value={draft.providerId}
                onChange={(event) =>
                  updateDraft((current) => ({
                    ...current,
                    providerId: event.target.value as VoiceInputProviderId,
                  }))
                }
              >
                <option value="dashscope">阿里云百炼</option>
                <option value="volcengine">火山引擎</option>
                <option value="openWhisper">本地 OpenWhisper</option>
                <option value="vibevoice">VibeVoice Server</option>
              </select>
            </label>

            <label className="field">
              <span>触发键</span>
              <select
                value={draft.triggerMode}
                onChange={(event) =>
                  updateDraft((current) => ({
                    ...current,
                    triggerMode: event.target.value as VoiceInputConfig['triggerMode'],
                  }))
                }
              >
                <option value="right_command_hold">右 Command 按住说话</option>
                <option value="fn_hold">Fn 按住说话</option>
              </select>
            </label>

            <label className="field">
              <span>结果处理</span>
              <select
                value={draft.autoInsert ? 'insert' : 'copy'}
                onChange={(event) =>
                  updateDraft((current) => ({
                    ...current,
                    autoInsert: event.target.value === 'insert',
                  }))
                }
              >
                <option value="insert">自动插入当前输入框</option>
                <option value="copy">只复制到剪贴板</option>
              </select>
            </label>
          </div>

          <div className="status-row">
            <div className="status-chip">
              麦克风
              <strong>{statusLabelMap[state?.permissions.microphone ?? 'not-determined']}</strong>
            </div>
            <div className="status-chip">
              辅助功能
              <strong>{statusLabelMap[state?.permissions.accessibility ?? 'not-determined']}</strong>
            </div>
            <div className="status-chip">
              最新来源
              <strong>{state?.sourceAppName ?? '尚未捕获'}</strong>
            </div>
          </div>

          {state?.lastError ? <div className="notice notice-error">{state.lastError}</div> : null}
          {state?.lastTranscript ? <div className="notice notice-soft">最近一次结果：{state.lastTranscript}</div> : null}
        </section>

        <section className="card">
          <div className="card-head">
            <div>
              <p className="card-kicker">官方接入说明</p>
              <h2>{currentGuide.title}</h2>
            </div>
            <span className="muted-text">资料更新时间：{currentGuide.updatedAt}</span>
          </div>

          <p className="lead-copy">{currentGuide.summary}</p>
          <div className="notice notice-soft">{currentGuide.trialNote}</div>
          <div className="notice notice-soft">{currentGuide.pricingNote}</div>

          <div className="bullet-block">
            <h3>怎么开通</h3>
            <ul>
              {currentGuide.setupSteps.map((step) => (
                <li key={step}>{step}</li>
              ))}
            </ul>
          </div>

          <div className="link-grid">
            {currentGuide.links.map((link) => (
              <button key={link.url} className="link-card" onClick={() => void handleOpenLink(link.url)}>
                <span>{link.label}</span>
                <strong>打开官方页面</strong>
              </button>
            ))}
          </div>

          <div className="bullet-block">
            <h3>使用建议</h3>
            <ul>
              {currentGuide.tips.map((tip) => (
                <li key={tip}>{tip}</li>
              ))}
            </ul>
          </div>
        </section>

        <section className="card card-wide">
          <div className="card-head">
            <div>
              <p className="card-kicker">Provider Config</p>
              <h2>识别参数</h2>
            </div>
          </div>

          {draft.providerId === 'dashscope' ? (
            <div className="stack">
              <div className="field-grid">
                <label className="field">
                  <span>API Key</span>
                  <input
                    type="password"
                    value={draft.providers.dashscope.apiKey}
                    placeholder="sk-..."
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          dashscope: {
                            ...current.providers.dashscope,
                            apiKey: event.target.value,
                          },
                        },
                      }))
                    }
                  />
                </label>

                <label className="field">
                  <span>Region</span>
                  <select
                    value={draft.providers.dashscope.region}
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          dashscope: {
                            ...current.providers.dashscope,
                            region: event.target.value as VoiceInputConfig['providers']['dashscope']['region'],
                          },
                        },
                      }))
                    }
                  >
                    <option value="beijing">中国大陆</option>
                    <option value="singapore">新加坡</option>
                  </select>
                </label>

                <label className="field">
                  <span>Model</span>
                  <input
                    value={draft.providers.dashscope.model}
                    placeholder="paraformer-realtime-v2"
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          dashscope: {
                            ...current.providers.dashscope,
                            model: event.target.value,
                          },
                        },
                      }))
                    }
                  />
                </label>

                <label className="field">
                  <span>Language Hints</span>
                  <input
                    value={draft.providers.dashscope.languageHints.join(', ')}
                    placeholder="zh, en"
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          dashscope: {
                            ...current.providers.dashscope,
                            languageHints: splitListInput(event.target.value),
                          },
                        },
                      }))
                    }
                  />
                </label>

                <label className="field">
                  <span>Vocabulary ID</span>
                  <input
                    value={draft.providers.dashscope.vocabularyId}
                    placeholder="可选，绑定阿里云词表"
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          dashscope: {
                            ...current.providers.dashscope,
                            vocabularyId: event.target.value,
                          },
                        },
                      }))
                    }
                  />
                </label>

                <label className="field">
                  <span>Phrase ID</span>
                  <input
                    value={draft.providers.dashscope.phraseId}
                    placeholder="可选，绑定阿里云短语热词"
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          dashscope: {
                            ...current.providers.dashscope,
                            phraseId: event.target.value,
                          },
                        },
                      }))
                    }
                  />
                </label>
              </div>

              <div className="notice notice-soft">
                阿里云这一路线最适合把词条同步到云端词表后再引用。VoiceVibe 会帮你在下方生成可复制的词表 JSON。
              </div>
            </div>
          ) : null}

          {draft.providerId === 'volcengine' ? (
            <div className="field-grid">
              <label className="field">
                <span>App Key</span>
                <input
                  value={draft.providers.volcengine.appKey}
                  placeholder="火山控制台应用标识"
                  onChange={(event) =>
                    updateDraft((current) => ({
                      ...current,
                      providers: {
                        ...current.providers,
                        volcengine: {
                          ...current.providers.volcengine,
                          appKey: event.target.value,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>Access Token</span>
                <input
                  type="password"
                  value={draft.providers.volcengine.accessKey}
                  placeholder="Access Token"
                  onChange={(event) =>
                    updateDraft((current) => ({
                      ...current,
                      providers: {
                        ...current.providers,
                        volcengine: {
                          ...current.providers.volcengine,
                          accessKey: event.target.value,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>Resource ID</span>
                <input
                  value={draft.providers.volcengine.resourceId}
                  placeholder="volc.bigasr.sauc.duration"
                  onChange={(event) =>
                    updateDraft((current) => ({
                      ...current,
                      providers: {
                        ...current.providers,
                        volcengine: {
                          ...current.providers.volcengine,
                          resourceId: event.target.value,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>Model</span>
                <input
                  value={draft.providers.volcengine.model}
                  placeholder="bigmodel"
                  onChange={(event) =>
                    updateDraft((current) => ({
                      ...current,
                      providers: {
                        ...current.providers,
                        volcengine: {
                          ...current.providers.volcengine,
                          model: event.target.value,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>Boosting Table ID</span>
                <input
                  value={draft.providers.volcengine.boostingTableId}
                  placeholder="可选"
                  onChange={(event) =>
                    updateDraft((current) => ({
                      ...current,
                      providers: {
                        ...current.providers,
                        volcengine: {
                          ...current.providers.volcengine,
                          boostingTableId: event.target.value,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field">
                <span>Correct Table ID</span>
                <input
                  value={draft.providers.volcengine.correctTableId}
                  placeholder="可选"
                  onChange={(event) =>
                    updateDraft((current) => ({
                      ...current,
                      providers: {
                        ...current.providers,
                        volcengine: {
                          ...current.providers.volcengine,
                          correctTableId: event.target.value,
                        },
                      },
                    }))
                  }
                />
              </label>

              <label className="field field-full">
                <span>Provider 专属 Hotwords</span>
                <textarea
                  rows={5}
                  value={draft.providers.volcengine.hotwords.join('\n')}
                  placeholder="一行一个热词，和应用级 personal terms 自动合并"
                  onChange={(event) =>
                    updateDraft((current) => ({
                      ...current,
                      providers: {
                        ...current.providers,
                        volcengine: {
                          ...current.providers.volcengine,
                          hotwords: splitListInput(event.target.value),
                        },
                      },
                    }))
                  }
                />
              </label>
            </div>
          ) : null}

          {draft.providerId === 'openWhisper' ? (
            <div className="stack">
              <div className="field-grid">
                <label className="field">
                  <span>CLI Path</span>
                  <input
                    value={draft.providers.openWhisper.cliPath}
                    placeholder="可留空，默认自动探测 whisper-cli"
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          openWhisper: {
                            ...current.providers.openWhisper,
                            cliPath: event.target.value,
                          },
                        },
                      }))
                    }
                  />
                </label>

                <label className="field">
                  <span>Model</span>
                  <select
                    value={draft.providers.openWhisper.modelId}
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          openWhisper: {
                            ...current.providers.openWhisper,
                            modelId: event.target.value as VoiceInputOpenWhisperModelId,
                          },
                        },
                      }))
                    }
                  >
                    {OPEN_WHISPER_MODELS.map((model) => (
                      <option key={model.id} value={model.id}>
                        {model.id} · {formatFileSize(model.sizeBytes)} · 推荐 {model.recommendedMemoryGb}GB
                      </option>
                    ))}
                  </select>
                </label>

                <label className="field">
                  <span>Language Hints</span>
                  <input
                    value={draft.providers.openWhisper.languageHints.join(', ')}
                    placeholder="zh, en"
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          openWhisper: {
                            ...current.providers.openWhisper,
                            languageHints: splitListInput(event.target.value),
                          },
                        },
                      }))
                    }
                  />
                </label>

                <label className="field field-full">
                  <span>Provider 专属 Hotwords</span>
                  <textarea
                    rows={5}
                    value={draft.providers.openWhisper.hotwords.join('\n')}
                    placeholder="一行一个热词，和应用级 personal terms 自动合并进 prompt hints"
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          openWhisper: {
                            ...current.providers.openWhisper,
                            hotwords: splitListInput(event.target.value),
                          },
                        },
                      }))
                    }
                  />
                </label>
              </div>

              <div className="status-row">
                <div className="status-chip">
                  Runtime
                  <strong>{openWhisperState?.runtimeInstalled ? '已安装' : '未安装'}</strong>
                </div>
                <div className="status-chip">
                  Model
                  <strong>{openWhisperSelectedModel?.installed ? '已下载' : '未下载'}</strong>
                </div>
                <div className="status-chip">
                  Model 目录
                  <strong>{openWhisperState?.modelDirectory ?? '等待检测'}</strong>
                </div>
              </div>

              <div className="hero-actions">
                <button className="button button-secondary" onClick={() => void handleInstallRuntime()} disabled={busyAction === 'install-runtime'}>
                  {busyAction === 'install-runtime' ? '安装中…' : '通过 Homebrew 安装 Runtime'}
                </button>
                <button className="button button-primary" onClick={() => void handleInstallModel()} disabled={busyAction === 'install-model'}>
                  {busyAction === 'install-model' ? '下载中…' : '下载当前模型'}
                </button>
                {openWhisperSelectedModel?.filePath ? (
                  <button className="button button-secondary" onClick={() => void voiceInputApi.revealPath(openWhisperSelectedModel.filePath)}>
                    打开模型目录
                  </button>
                ) : null}
              </div>
            </div>
          ) : null}

          {draft.providerId === 'vibevoice' ? (
            <div className="stack">
              <div className="notice notice-soft">
                这是实验性 provider。VoiceVibe 连接的是你自己部署的 VibeVoice-ASR 服务，不会把 9B 模型直接打进桌面包。
              </div>

              <div className="field-grid">
                <label className="field">
                  <span>Base URL</span>
                  <input
                    value={draft.providers.vibevoice.baseUrl}
                    placeholder="http://localhost:8000"
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          vibevoice: {
                            ...current.providers.vibevoice,
                            baseUrl: event.target.value,
                          },
                        },
                      }))
                    }
                  />
                </label>

                <label className="field">
                  <span>Model</span>
                  <input
                    value={draft.providers.vibevoice.model}
                    placeholder="vibevoice"
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          vibevoice: {
                            ...current.providers.vibevoice,
                            model: event.target.value,
                          },
                        },
                      }))
                    }
                  />
                </label>

                <label className="field">
                  <span>API Key</span>
                  <input
                    type="password"
                    value={draft.providers.vibevoice.apiKey}
                    placeholder="可选，反向代理做鉴权时再填"
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          vibevoice: {
                            ...current.providers.vibevoice,
                            apiKey: event.target.value,
                          },
                        },
                      }))
                    }
                  />
                </label>

                <label className="field field-full">
                  <span>Provider 专属 Hotwords</span>
                  <textarea
                    rows={5}
                    value={draft.providers.vibevoice.hotwords.join('\n')}
                    placeholder="一行一个热词，和应用级 personal terms 合并后发给 VibeVoice"
                    onChange={(event) =>
                      updateDraft((current) => ({
                        ...current,
                        providers: {
                          ...current.providers,
                          vibevoice: {
                            ...current.providers.vibevoice,
                            hotwords: splitListInput(event.target.value),
                          },
                        },
                      }))
                    }
                  />
                </label>
              </div>
            </div>
          ) : null}
        </section>

        <section className="card">
          <div className="card-head">
            <div>
              <p className="card-kicker">Personal Dictionary</p>
              <h2>个人词条库</h2>
            </div>
            <span className="muted-text">{draft.personalTerms.length} 项</span>
          </div>

          <p className="lead-copy">
            把项目名、人名、产品名、专有名词维护在这里。火山引擎和 OpenWhisper 会自动使用它们，
            阿里云可以通过下方导出的 JSON 同步到云端词表。
          </p>

          <label className="field field-full">
            <span>一行一个词条</span>
            <textarea
              rows={10}
              value={draft.personalTerms.join('\n')}
              placeholder="例如：VoiceVibe&#10;Typeless&#10;王小明&#10;产品增长飞轮"
              onChange={(event) =>
                updateDraft((current) => ({
                  ...current,
                  personalTerms: splitListInput(event.target.value),
                }))
              }
            />
          </label>

          <div className="notice notice-soft">
            {'同步规则：Volcengine = personal terms + provider hotwords；OpenWhisper = personal terms + provider hotwords -> prompt hints。'}
          </div>

          <div className="card-head compact-head">
            <div>
              <h3>阿里云词表 JSON 预览</h3>
              <p className="muted-text">可复制后配合仓库脚本同步到 DashScope vocabulary。</p>
            </div>
            <button className="button button-secondary" onClick={() => void copyDashScopePreview()}>
              复制 JSON
            </button>
          </div>
          <pre className="code-preview">{dashScopeVocabularyPreview}</pre>
        </section>

        <section className="card">
          <div className="card-head">
            <div>
              <p className="card-kicker">Usage</p>
              <h2>最近转写</h2>
            </div>
          </div>

          <div className="stats-grid">
            <div className="metric-card">
              <span>累计转写次数</span>
              <strong>{stats.totalTranscriptionCount}</strong>
            </div>
            <div className="metric-card">
              <span>累计录音时长</span>
              <strong>{formatDuration(stats.totalRecordingDurationMs)}</strong>
            </div>
            <div className="metric-card">
              <span>累计转写字符</span>
              <strong>{stats.totalTranscribedCharacterCount}</strong>
            </div>
          </div>

          <div className="history-list">
            {history.slice(0, 8).map((record) => (
              <article key={record.id} className="history-item">
                <div className="history-meta">
                  <span>{formatDateTime(record.createdAt)}</span>
                  <span>{providerLabelMap[record.providerId]}</span>
                  <span>{record.status === 'failed' ? '失败' : record.status === 'inserted' ? '已插入' : '已复制'}</span>
                  <span>{formatDuration(record.durationMs)}</span>
                </div>
                <p className="history-text">{record.transcript || record.errorMessage || '没有文本输出'}</p>
              </article>
            ))}

            {!history.length ? <div className="empty-state">还没有历史记录。先用“手动开始”跑一段语音试试。</div> : null}
          </div>
        </section>
      </main>
    </div>
  );
}

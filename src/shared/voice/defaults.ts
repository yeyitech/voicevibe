import type { VoiceInputConfig, VoiceInputPermissions, VoiceInputState, VoiceInputStats } from '@shared/voice/types';

export const EMPTY_VOICE_INPUT_STATS: VoiceInputStats = {
  totalTranscriptionCount: 0,
  totalRecordingDurationMs: 0,
  totalTranscribedCharacterCount: 0,
};

export const DEFAULT_VOICE_INPUT_CONFIG: VoiceInputConfig = {
  enabled: false,
  providerId: 'dashscope',
  triggerMode: 'right_command_hold',
  autoInsert: true,
  personalTerms: [],
  providers: {
    dashscope: {
      apiKey: '',
      region: 'beijing',
      model: 'paraformer-realtime-v2',
      languageHints: ['zh', 'en'],
      vocabularyId: '',
      phraseId: '',
    },
    volcengine: {
      appKey: '',
      accessKey: '',
      resourceId: 'volc.bigasr.sauc.duration',
      model: 'bigmodel',
      boostingTableId: '',
      correctTableId: '',
      hotwords: [],
    },
    openWhisper: {
      cliPath: '',
      modelId: 'base',
      languageHints: ['zh', 'en'],
      hotwords: [],
    },
    vibevoice: {
      baseUrl: 'http://localhost:8000',
      apiKey: '',
      model: 'vibevoice',
      hotwords: [],
    },
  },
};

export const DEFAULT_VOICE_INPUT_PERMISSIONS: VoiceInputPermissions = {
  microphone: 'not-determined',
  accessibility: 'not-determined',
};

export const createDefaultVoiceInputState = (): VoiceInputState => ({
  supported: process.platform === 'darwin',
  enabled: DEFAULT_VOICE_INPUT_CONFIG.enabled,
  providerId: DEFAULT_VOICE_INPUT_CONFIG.providerId,
  triggerMode: DEFAULT_VOICE_INPUT_CONFIG.triggerMode,
  status: process.platform === 'darwin' ? 'idle' : 'unsupported',
  permissions:
    process.platform === 'darwin'
      ? DEFAULT_VOICE_INPUT_PERMISSIONS
      : {
          microphone: 'unsupported',
          accessibility: 'unsupported',
        },
  updatedAt: Date.now(),
});

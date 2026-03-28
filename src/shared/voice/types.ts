export const VOICE_INPUT_PROVIDER_IDS = ['dashscope', 'volcengine', 'openWhisper', 'vibevoice'] as const;
export type VoiceInputProviderId = (typeof VOICE_INPUT_PROVIDER_IDS)[number];

export const VOICE_INPUT_TRIGGER_MODES = ['fn_hold', 'right_command_hold'] as const;
export type VoiceInputTriggerMode = (typeof VOICE_INPUT_TRIGGER_MODES)[number];

export const VOICE_INPUT_REGIONS = ['beijing', 'singapore'] as const;
export type VoiceInputRegion = (typeof VOICE_INPUT_REGIONS)[number];

export const VOICE_INPUT_OPEN_WHISPER_MODEL_IDS = ['tiny', 'base', 'small', 'medium', 'large-v3-turbo'] as const;
export type VoiceInputOpenWhisperModelId = (typeof VOICE_INPUT_OPEN_WHISPER_MODEL_IDS)[number];

export type VoiceInputDashScopeConfig = {
  apiKey: string;
  region: VoiceInputRegion;
  model: string;
  languageHints: string[];
  vocabularyId: string;
  phraseId: string;
};

export type VoiceInputVolcengineConfig = {
  appKey: string;
  accessKey: string;
  resourceId: string;
  model: string;
  boostingTableId: string;
  correctTableId: string;
  hotwords: string[];
};

export type VoiceInputOpenWhisperConfig = {
  cliPath: string;
  modelId: VoiceInputOpenWhisperModelId;
  languageHints: string[];
  hotwords: string[];
};

export type VoiceInputVibeVoiceConfig = {
  baseUrl: string;
  apiKey: string;
  model: string;
  hotwords: string[];
};

export type VoiceInputConfig = {
  enabled: boolean;
  providerId: VoiceInputProviderId;
  triggerMode: VoiceInputTriggerMode;
  autoInsert: boolean;
  personalTerms: string[];
  providers: {
    dashscope: VoiceInputDashScopeConfig;
    volcengine: VoiceInputVolcengineConfig;
    openWhisper: VoiceInputOpenWhisperConfig;
    vibevoice: VoiceInputVibeVoiceConfig;
  };
};

export type VoiceInputPermissionState = 'granted' | 'denied' | 'restricted' | 'not-determined' | 'unsupported';

export type VoiceInputPermissions = {
  microphone: VoiceInputPermissionState;
  accessibility: VoiceInputPermissionState;
};

export type VoiceInputRuntimeStatus =
  | 'idle'
  | 'recording'
  | 'transcribing'
  | 'inserted'
  | 'copied'
  | 'error'
  | 'unsupported';

export type VoiceInputState = {
  supported: boolean;
  enabled: boolean;
  providerId: VoiceInputProviderId;
  triggerMode: VoiceInputTriggerMode;
  status: VoiceInputRuntimeStatus;
  permissions: VoiceInputPermissions;
  lastTranscript?: string;
  lastError?: string;
  sourceAppName?: string;
  updatedAt: number;
};

export type VoiceInputHistoryStatus = 'inserted' | 'copied' | 'failed';

export type VoiceInputHistoryRecord = {
  id: string;
  createdAt: number;
  providerId: VoiceInputProviderId;
  triggerMode: VoiceInputTriggerMode;
  status: VoiceInputHistoryStatus;
  transcript: string;
  sourceAppName?: string;
  sourceBundleId?: string;
  durationMs: number;
  errorMessage?: string;
  model?: string;
  termCount: number;
};

export type VoiceInputStats = {
  totalTranscriptionCount: number;
  totalRecordingDurationMs: number;
  totalTranscribedCharacterCount: number;
};

export type VoiceInputOpenWhisperModelStatus = {
  id: VoiceInputOpenWhisperModelId;
  sizeBytes: number;
  installed: boolean;
  filePath: string;
};

export type VoiceInputOpenWhisperState = {
  supported: boolean;
  brewAvailable: boolean;
  runtimeInstalled: boolean;
  cliPath?: string;
  brewPath?: string;
  modelDirectory: string;
  selectedModelId: VoiceInputOpenWhisperModelId;
  selectedModelInstalled: boolean;
  models: VoiceInputOpenWhisperModelStatus[];
  lastError?: string;
};

export type VoiceInputOverlayCapture = {
  pcmBase64: string;
  durationMs: number;
  chunkCount: number;
};

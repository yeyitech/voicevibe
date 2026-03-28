import { JsonStore } from '@main/store/jsonStore';
import { DEFAULT_VOICE_INPUT_CONFIG } from '@shared/voice/defaults';
import { normalizeVoiceInputConfig } from '@shared/voice/config';
import type { VoiceInputConfig } from '@shared/voice/types';

const store = new JsonStore<VoiceInputConfig>('voice-input.config.json', () => DEFAULT_VOICE_INPUT_CONFIG);

export const configStore = {
  async read(): Promise<VoiceInputConfig> {
    return normalizeVoiceInputConfig(await store.read());
  },

  async write(value: VoiceInputConfig): Promise<VoiceInputConfig> {
    const normalized = normalizeVoiceInputConfig(value);
    await store.write(normalized);
    return normalized;
  },
};

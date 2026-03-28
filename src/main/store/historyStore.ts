import { JsonStore } from '@main/store/jsonStore';
import { EMPTY_VOICE_INPUT_STATS } from '@shared/voice/defaults';
import type { VoiceInputHistoryRecord, VoiceInputStats } from '@shared/voice/types';

const HISTORY_LIMIT = 200;
const store = new JsonStore<VoiceInputHistoryRecord[]>('voice-input.history.json', () => []);

const sortDescending = (records: VoiceInputHistoryRecord[]): VoiceInputHistoryRecord[] =>
  [...records].sort((left, right) => right.createdAt - left.createdAt);

export const historyStore = {
  async list(): Promise<VoiceInputHistoryRecord[]> {
    return sortDescending(await store.read());
  },

  async append(record: VoiceInputHistoryRecord): Promise<void> {
    const current = sortDescending(await store.read());
    current.unshift(record);
    await store.write(current.slice(0, HISTORY_LIMIT));
  },

  async getStats(): Promise<VoiceInputStats> {
    const records = await store.read();

    return records.reduce<VoiceInputStats>((accumulator, record) => {
      if (record.status !== 'failed' && record.transcript.trim().length > 0) {
        accumulator.totalTranscriptionCount += 1;
        accumulator.totalTranscribedCharacterCount += record.transcript.length;
      }
      accumulator.totalRecordingDurationMs += record.durationMs;
      return accumulator;
    }, { ...EMPTY_VOICE_INPUT_STATS });
  },
};

import { createPcm16WavBuffer } from '@main/services/voice/wavAudio';
import type { VoiceInputConfig } from '@shared/voice/types';

type VibeVoiceChatCompletionResponse = {
  choices?: Array<{
    message?: {
      content?: string | Array<{ type?: string; text?: string }>;
    };
  }>;
  error?: {
    message?: string;
  };
};

const REQUEST_TIMEOUT_MS = 5 * 60 * 1000;

const stripCodeFence = (value: string): string => {
  const trimmed = value.trim();
  const match = trimmed.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/u);
  return match ? match[1].trim() : trimmed;
};

const flattenStructuredTranscript = (value: unknown): string | null => {
  if (typeof value === 'string') {
    const normalized = value.trim();
    return normalized.length > 0 ? normalized : null;
  }

  if (Array.isArray(value)) {
    const parts = value
      .map((item) => flattenStructuredTranscript(item))
      .filter((item): item is string => Boolean(item));
    return parts.length > 0 ? parts.join('\n') : null;
  }

  if (value && typeof value === 'object') {
    const record = value as Record<string, unknown>;
    if (typeof record.Content === 'string') {
      return record.Content.trim();
    }
    if (typeof record.content === 'string') {
      return record.content.trim();
    }
    if (typeof record.text === 'string') {
      return record.text.trim();
    }
    if (Array.isArray(record.segments)) {
      return flattenStructuredTranscript(record.segments);
    }
    if (Array.isArray(record.items)) {
      return flattenStructuredTranscript(record.items);
    }
  }

  return null;
};

const parseTranscript = (content: string): string => {
  const stripped = stripCodeFence(content);

  try {
    const parsed = JSON.parse(stripped) as unknown;
    const flattened = flattenStructuredTranscript(parsed);
    if (flattened) {
      return flattened;
    }
  } catch {
    // plain text response
  }

  return stripped;
};

const getDurationSeconds = (pcmBuffer: Buffer): number => pcmBuffer.length / 32000;

export class VibeVoiceProvider {
  constructor(private readonly config: VoiceInputConfig['providers']['vibevoice']) {}

  async transcribe(pcmBuffer: Buffer): Promise<string> {
    const baseUrl = this.config.baseUrl.trim().replace(/\/+$/u, '');
    if (!baseUrl) {
      throw new Error('VibeVoice base URL is required');
    }

    if (pcmBuffer.length === 0) {
      return '';
    }

    const hotwords = this.config.hotwords.filter((item) => item.trim().length > 0);
    const wavBuffer = createPcm16WavBuffer(pcmBuffer);
    const dataUrl = `data:audio/wav;base64,${wavBuffer.toString('base64')}`;
    const duration = getDurationSeconds(pcmBuffer);

    const promptText =
      hotwords.length > 0
        ? `This is a ${duration.toFixed(2)} seconds desktop dictation audio, with extra info: ${hotwords.join(', ')}.

Please transcribe the spoken content into plain text only. Do not return JSON, timestamps, or speaker labels.`
        : `This is a ${duration.toFixed(2)} seconds desktop dictation audio.

Please transcribe the spoken content into plain text only. Do not return JSON, timestamps, or speaker labels.`;

    const payload = {
      model: this.config.model.trim() || 'vibevoice',
      messages: [
        {
          role: 'system',
          content:
            'You are a helpful assistant that transcribes audio input into plain text output. Return only the transcript itself.',
        },
        {
          role: 'user',
          content: [
            { type: 'audio_url', audio_url: { url: dataUrl } },
            { type: 'text', text: promptText },
          ],
        },
      ],
      max_tokens: 8192,
      temperature: 0,
      top_p: 1,
      stream: false,
    };

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

    try {
      const response = await fetch(`${baseUrl}/v1/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(this.config.apiKey.trim()
            ? {
                Authorization: `Bearer ${this.config.apiKey.trim()}`,
              }
            : {}),
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });

      const json = (await response.json().catch(() => ({}))) as VibeVoiceChatCompletionResponse;
      if (!response.ok) {
        throw new Error(json.error?.message || `VibeVoice request failed with status ${response.status}`);
      }

      const content = json.choices?.[0]?.message?.content;
      const text =
        typeof content === 'string'
          ? content
          : Array.isArray(content)
            ? content.map((item) => item.text ?? '').join('\n')
            : '';

      const transcript = parseTranscript(text).trim();
      if (!transcript) {
        throw new Error('VibeVoice returned an empty transcript.');
      }

      return transcript;
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }

      throw new Error(String(error));
    } finally {
      clearTimeout(timeoutId);
    }
  }
}

import { contextBridge, ipcRenderer } from 'electron';
import type {
  VoiceInputConfig,
  VoiceInputHistoryRecord,
  VoiceInputOpenWhisperModelId,
  VoiceInputOpenWhisperState,
  VoiceInputState,
  VoiceInputStats,
} from '@shared/voice/types';

const voiceInputApi = {
  getConfig: () => ipcRenderer.invoke('voice-input:get-config') as Promise<VoiceInputConfig>,
  setConfig: (config: VoiceInputConfig) => ipcRenderer.invoke('voice-input:set-config', config) as Promise<VoiceInputConfig>,
  getState: () => ipcRenderer.invoke('voice-input:get-state') as Promise<VoiceInputState>,
  requestPermissions: () => ipcRenderer.invoke('voice-input:request-permissions') as Promise<VoiceInputState['permissions']>,
  startManualCapture: () => ipcRenderer.invoke('voice-input:start-manual-capture') as Promise<void>,
  stopManualCapture: () => ipcRenderer.invoke('voice-input:stop-manual-capture') as Promise<void>,
  getStats: () => ipcRenderer.invoke('voice-input:get-stats') as Promise<VoiceInputStats>,
  listHistory: () => ipcRenderer.invoke('voice-input:list-history') as Promise<VoiceInputHistoryRecord[]>,
  getOpenWhisperState: () => ipcRenderer.invoke('voice-input:get-open-whisper-state') as Promise<VoiceInputOpenWhisperState>,
  installOpenWhisperRuntime: () => ipcRenderer.invoke('voice-input:install-open-whisper-runtime') as Promise<VoiceInputOpenWhisperState>,
  installOpenWhisperModel: (modelId: VoiceInputOpenWhisperModelId) =>
    ipcRenderer.invoke('voice-input:install-open-whisper-model', modelId) as Promise<VoiceInputOpenWhisperState>,
  openExternal: (url: string) => ipcRenderer.invoke('app:open-external', url) as Promise<void>,
  revealPath: (targetPath: string) => ipcRenderer.invoke('app:reveal-path', targetPath) as Promise<void>,
  onStateChanged: (listener: (state: VoiceInputState) => void) => {
    const channel = 'voice-input:state-changed';
    const wrapped = (_event: Electron.IpcRendererEvent, state: VoiceInputState) => listener(state);
    ipcRenderer.on(channel, wrapped);
    return () => ipcRenderer.removeListener(channel, wrapped);
  },
};

contextBridge.exposeInMainWorld('voiceVibe', {
  voiceInput: voiceInputApi,
});

declare global {
  interface Window {
    voiceVibe: {
      voiceInput: typeof voiceInputApi;
    };
  }
}

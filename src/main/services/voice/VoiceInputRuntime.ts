import { BrowserWindow, clipboard, screen, systemPreferences } from 'electron';
import type { EventEmitter } from 'node:events';
import { configStore } from '@main/store/configStore';
import { historyStore } from '@main/store/historyStore';
import { VOICE_OVERLAY_HTML } from '@main/services/voice/overlayHtml';
import { getFrontmostAppInfo, pasteTextToActiveApp, type FrontmostAppInfo } from '@main/services/voice/macosActions';
import { DashScopeVoiceProvider } from '@main/services/voice/providers/DashScopeVoiceProvider';
import {
  getOpenWhisperState,
  installOpenWhisperModel,
  installOpenWhisperRuntime,
  OpenWhisperVoiceProvider,
} from '@main/services/voice/providers/OpenWhisperVoiceProvider';
import { VibeVoiceProvider } from '@main/services/voice/providers/VibeVoiceProvider';
import { VolcengineVoiceProvider } from '@main/services/voice/providers/VolcengineVoiceProvider';
import {
  createVoiceInputPermissions,
  createVoiceInputState,
  getTriggerPressedState,
  isVoiceInputConfigured,
  mergeTerms,
  normalizeVoiceInputConfig,
  toPermissionState,
} from '@shared/voice/config';
import { DEFAULT_VOICE_INPUT_CONFIG } from '@shared/voice/defaults';
import type {
  VoiceInputConfig,
  VoiceInputHistoryRecord,
  VoiceInputOpenWhisperModelId,
  VoiceInputOpenWhisperState,
  VoiceInputOverlayCapture,
  VoiceInputPermissions,
  VoiceInputState,
  VoiceInputStats,
} from '@shared/voice/types';

type IoHookModule = (typeof import('iohook-macos'))['default'];

type VoiceInputTranscriptionProvider = {
  transcribe: (pcmBuffer: Buffer) => Promise<string>;
};

type RuntimeOptions = {
  emitState: (state: VoiceInputState) => void;
};

type CaptureReason = 'shortcut' | 'manual';

export class VoiceInputRuntime {
  private config: VoiceInputConfig = DEFAULT_VOICE_INPUT_CONFIG;
  private state: VoiceInputState = createVoiceInputState({});
  private overlayWindow: BrowserWindow | null = null;
  private overlayReadyPromise: Promise<void> | null = null;
  private hookListenerRegistered = false;
  private monitoringActive = false;
  private triggerHeld = false;
  private captureActive = false;
  private captureStartPromise: Promise<void> | null = null;
  private iohookModulePromise: Promise<IoHookModule> | null = null;

  constructor(private readonly options: RuntimeOptions) {}

  async initialize(): Promise<void> {
    this.config = normalizeVoiceInputConfig(await configStore.read());
    await this.refreshPermissions();
    await this.syncMonitoring();
    this.emitState();
  }

  async dispose(): Promise<void> {
    try {
      if (this.monitoringActive) {
        const iohook = await this.getIoHookModule().catch(() => null);
        iohook?.stopMonitoring();
      }
    } finally {
      this.monitoringActive = false;
      this.captureActive = false;
      await this.cancelOverlayRecording().catch(() => {});
      this.overlayWindow?.destroy();
      this.overlayWindow = null;
      this.overlayReadyPromise = null;
    }
  }

  getConfig(): VoiceInputConfig {
    return this.config;
  }

  getState(): VoiceInputState {
    return this.state;
  }

  async getOpenWhisperState(): Promise<VoiceInputOpenWhisperState> {
    return getOpenWhisperState(this.getMergedOpenWhisperConfig());
  }

  async setConfig(config: VoiceInputConfig): Promise<VoiceInputConfig> {
    this.config = await configStore.write(config);
    await this.refreshPermissions();
    await this.syncMonitoring();
    this.updateState({
      enabled: this.config.enabled,
      providerId: this.config.providerId,
      triggerMode: this.config.triggerMode,
    });
    return this.config;
  }

  async installOpenWhisperRuntime(): Promise<VoiceInputOpenWhisperState> {
    return installOpenWhisperRuntime(this.getMergedOpenWhisperConfig());
  }

  async installOpenWhisperModel(modelId = this.config.providers.openWhisper.modelId): Promise<VoiceInputOpenWhisperState> {
    return installOpenWhisperModel(modelId, this.getMergedOpenWhisperConfig());
  }

  async requestPermissions(): Promise<VoiceInputPermissions> {
    if (process.platform !== 'darwin') {
      const permissions = createVoiceInputPermissions('unsupported', 'unsupported');
      this.updateState({ permissions, status: 'unsupported' });
      return permissions;
    }

    try {
      await systemPreferences.askForMediaAccess('microphone');
    } catch {
      // ignore permission prompt failures
    }

    try {
      const iohook = await this.getIoHookModule();
      const status = iohook.checkAccessibilityPermissions();
      if (!status.hasPermissions) {
        iohook.requestAccessibilityPermissions();
      }
    } catch {
      // ignore accessibility prompt failures
    }

    return this.refreshPermissions();
  }

  async startManualCapture(): Promise<void> {
    await this.beginCapture('manual');
  }

  async stopManualCapture(): Promise<void> {
    await this.finishCapture('manual');
  }

  async listHistory(): Promise<VoiceInputHistoryRecord[]> {
    return historyStore.list();
  }

  async getStats(): Promise<VoiceInputStats> {
    return historyStore.getStats();
  }

  private async getIoHookModule(): Promise<IoHookModule> {
    if (!this.iohookModulePromise) {
      this.iohookModulePromise = import('iohook-macos').then((module) => module.default);
    }
    return this.iohookModulePromise;
  }

  private async refreshPermissions(): Promise<VoiceInputPermissions> {
    if (process.platform !== 'darwin') {
      const permissions = createVoiceInputPermissions('unsupported', 'unsupported');
      this.updateState({ supported: false, permissions, status: 'unsupported' });
      return permissions;
    }

    const microphone = toPermissionState(systemPreferences.getMediaAccessStatus('microphone'));
    let accessibility = toPermissionState('not-determined');

    try {
      const iohook = await this.getIoHookModule();
      accessibility = iohook.checkAccessibilityPermissions().hasPermissions ? 'granted' : 'denied';
    } catch {
      accessibility = 'denied';
    }

    const permissions = createVoiceInputPermissions(microphone, accessibility);
    this.updateState({
      supported: true,
      permissions,
      status: this.state.status === 'unsupported' ? 'idle' : this.state.status,
    });
    return permissions;
  }

  private async syncMonitoring(): Promise<void> {
    if (process.platform !== 'darwin') {
      return;
    }

    const shouldMonitor =
      this.config.enabled && this.state.permissions.accessibility === 'granted' && isVoiceInputConfigured(this.config);

    const iohook = await this.getIoHookModule().catch(() => null);
    if (!iohook) {
      return;
    }

    if (!this.hookListenerRegistered) {
      const handleKeyboardLikeEvent = (event: {
        keyCode?: number;
        flags?: number;
        modifiers: { command: boolean; option: boolean; fn: boolean };
      }) => {
        void this.handleHookEvent(event);
      };
      iohook.on('flagsChanged', handleKeyboardLikeEvent);
      iohook.on('keyDown', handleKeyboardLikeEvent);
      iohook.on('keyUp', handleKeyboardLikeEvent);
      this.hookListenerRegistered = true;
    }

    if (shouldMonitor && !this.monitoringActive) {
      iohook.startMonitoring();
      this.monitoringActive = true;
      return;
    }

    if (!shouldMonitor && this.monitoringActive) {
      iohook.stopMonitoring();
      this.monitoringActive = false;
      this.triggerHeld = false;
    }
  }

  private async handleHookEvent(event: {
    keyCode?: number;
    flags?: number;
    modifiers: { command: boolean; option: boolean; fn: boolean };
  }): Promise<void> {
    const nextPressed = getTriggerPressedState(this.config.triggerMode, event);
    if (nextPressed === null || nextPressed === this.triggerHeld) {
      return;
    }

    this.triggerHeld = nextPressed;

    if (nextPressed) {
      await this.beginCapture('shortcut');
      return;
    }

    await this.finishCapture('shortcut');
  }

  private async ensureActiveProviderReady(): Promise<void> {
    if (this.config.providerId !== 'openWhisper') {
      return;
    }

    const localState = await getOpenWhisperState(this.getMergedOpenWhisperConfig());
    if (!localState.runtimeInstalled) {
      throw new Error('OpenWhisper runtime is not installed. Install whisper.cpp first.');
    }

    if (!localState.selectedModelInstalled) {
      throw new Error('Selected OpenWhisper model is not installed.');
    }
  }

  private async beginCapture(reason: CaptureReason): Promise<void> {
    if (this.captureActive) {
      return;
    }

    if (process.platform !== 'darwin') {
      this.updateState({ status: 'unsupported', lastError: 'VoiceVibe desktop capture currently ships as a macOS-first workflow.' });
      return;
    }

    if (!isVoiceInputConfigured(this.config)) {
      this.updateState({ status: 'error', lastError: 'The current provider is not configured yet.' });
      return;
    }

    try {
      await this.ensureActiveProviderReady();
    } catch (error) {
      this.updateState({
        status: 'error',
        lastError: error instanceof Error ? error.message : String(error),
      });
      return;
    }

    const permissions = await this.refreshPermissions();
    if (permissions.microphone !== 'granted') {
      this.updateState({ status: 'error', lastError: 'Microphone permission is required.' });
      return;
    }

    const requiresAccessibility = reason === 'shortcut' || this.config.autoInsert;
    if (requiresAccessibility && permissions.accessibility !== 'granted') {
      this.updateState({
        status: 'error',
        lastError: 'Accessibility permission is required for global hotkey monitoring and auto insert.',
      });
      return;
    }

    this.captureActive = true;
    const sourceAppPromise: Promise<FrontmostAppInfo> = requiresAccessibility ? getFrontmostAppInfo() : Promise.resolve({});

    try {
      await this.showRecordingOverlay();
      const startPromise = this.startOverlayRecording();
      this.captureStartPromise = startPromise;
      await startPromise;
      const sourceApp = await sourceAppPromise;
      this.updateState({
        status: 'recording',
        lastError: undefined,
        sourceAppName: sourceApp.appName,
      });
    } catch (error) {
      this.captureActive = false;
      this.updateState({
        status: 'error',
        lastError: error instanceof Error ? error.message : String(error),
      });
      await this.flashOverlayState('error');
    } finally {
      this.captureStartPromise = null;
    }
  }

  private async finishCapture(_reason: CaptureReason): Promise<void> {
    if (!this.captureActive) {
      return;
    }

    this.captureActive = false;

    let payload: VoiceInputOverlayCapture;
    try {
      if (this.captureStartPromise) {
        await this.captureStartPromise;
      }
      await this.setOverlayState('transcribing');
      payload = await this.stopOverlayRecording();
    } catch (error) {
      this.updateState({ status: 'error', lastError: error instanceof Error ? error.message : String(error) });
      await this.flashOverlayState('error');
      return;
    }

    if (!payload.pcmBase64) {
      const message = 'No audio was captured. Check the microphone permission and selected input device.';
      await this.persistRecord({
        id: crypto.randomUUID(),
        providerId: this.config.providerId,
        triggerMode: this.config.triggerMode,
        status: 'failed',
        transcript: '',
        sourceAppName: this.state.sourceAppName,
        durationMs: payload.durationMs,
        errorMessage: message,
        model: this.getActiveModelLabel(),
        termCount: this.getMergedTermCount(),
        createdAt: Date.now(),
      });
      this.updateState({ status: 'error', lastError: message });
      await this.flashOverlayState('error');
      return;
    }

    try {
      const transcript = (await this.createTranscriptionProvider().transcribe(Buffer.from(payload.pcmBase64, 'base64'))).trim();

      if (!transcript) {
        throw new Error('The provider returned an empty transcript.');
      }

      let outcome: 'inserted' | 'copied' = 'copied';
      if (this.config.autoInsert) {
        outcome = await pasteTextToActiveApp(transcript);
      } else {
        clipboard.writeText(transcript);
      }

      const appInfo = await getFrontmostAppInfo();
      const record: VoiceInputHistoryRecord = {
        id: crypto.randomUUID(),
        providerId: this.config.providerId,
        triggerMode: this.config.triggerMode,
        status: outcome,
        transcript,
        sourceAppName: this.state.sourceAppName ?? appInfo.appName,
        sourceBundleId: appInfo.bundleId,
        durationMs: payload.durationMs,
        model: this.getActiveModelLabel(),
        termCount: this.getMergedTermCount(),
        createdAt: Date.now(),
      };
      await this.persistRecord(record);

      this.updateState({
        status: outcome === 'inserted' ? 'inserted' : 'copied',
        lastTranscript: transcript,
        lastError: undefined,
        sourceAppName: record.sourceAppName,
      });
      await this.flashOverlayState('success');
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      await this.persistRecord({
        id: crypto.randomUUID(),
        providerId: this.config.providerId,
        triggerMode: this.config.triggerMode,
        status: 'failed',
        transcript: '',
        sourceAppName: this.state.sourceAppName,
        durationMs: payload.durationMs,
        errorMessage: message,
        model: this.getActiveModelLabel(),
        termCount: this.getMergedTermCount(),
        createdAt: Date.now(),
      });
      this.updateState({ status: 'error', lastError: message });
      await this.flashOverlayState('error');
    }
  }

  private async persistRecord(record: VoiceInputHistoryRecord): Promise<void> {
    await historyStore.append(record);
  }

  private createTranscriptionProvider(): VoiceInputTranscriptionProvider {
    switch (this.config.providerId) {
      case 'openWhisper':
        return new OpenWhisperVoiceProvider(this.getMergedOpenWhisperConfig());
      case 'vibevoice':
        return new VibeVoiceProvider({
          ...this.config.providers.vibevoice,
          hotwords: mergeTerms(this.config.personalTerms, this.config.providers.vibevoice.hotwords),
        });
      case 'volcengine':
        return new VolcengineVoiceProvider({
          ...this.config.providers.volcengine,
          hotwords: mergeTerms(this.config.personalTerms, this.config.providers.volcengine.hotwords),
        });
      case 'dashscope':
      default:
        return new DashScopeVoiceProvider(this.config.providers.dashscope);
    }
  }

  private getMergedOpenWhisperConfig(): VoiceInputConfig['providers']['openWhisper'] {
    return {
      ...this.config.providers.openWhisper,
      hotwords: mergeTerms(this.config.personalTerms, this.config.providers.openWhisper.hotwords),
    };
  }

  private getMergedTermCount(): number {
    switch (this.config.providerId) {
      case 'openWhisper':
        return mergeTerms(this.config.personalTerms, this.config.providers.openWhisper.hotwords).length;
      case 'volcengine':
        return mergeTerms(this.config.personalTerms, this.config.providers.volcengine.hotwords).length;
      case 'vibevoice':
        return mergeTerms(this.config.personalTerms, this.config.providers.vibevoice.hotwords).length;
      case 'dashscope':
      default:
        return this.config.personalTerms.length;
    }
  }

  private getActiveModelLabel(): string | undefined {
    switch (this.config.providerId) {
      case 'openWhisper':
        return this.config.providers.openWhisper.modelId;
      case 'volcengine':
        return this.config.providers.volcengine.model;
      case 'vibevoice':
        return this.config.providers.vibevoice.model;
      case 'dashscope':
      default:
        return this.config.providers.dashscope.model;
    }
  }

  private async showRecordingOverlay(): Promise<void> {
    await this.ensureOverlayWindow();
    await this.positionOverlayWindow();
    await this.setOverlayState('recording');
    await this.overlayWindow?.showInactive();
  }

  private async ensureOverlayWindow(): Promise<void> {
    if (this.overlayWindow && !this.overlayWindow.isDestroyed()) {
      return;
    }

    this.overlayWindow = new BrowserWindow({
      width: 84,
      height: 42,
      show: false,
      paintWhenInitiallyHidden: true,
      frame: false,
      resizable: false,
      movable: false,
      minimizable: false,
      maximizable: false,
      closable: false,
      focusable: false,
      skipTaskbar: true,
      transparent: true,
      roundedCorners: true,
      alwaysOnTop: true,
      hasShadow: false,
      backgroundColor: '#00000000',
      webPreferences: {
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: false,
        backgroundThrottling: false,
      },
    });

    this.overlayWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
    this.overlayWindow.setAlwaysOnTop(true, 'screen-saver');
    this.overlayWindow.setIgnoreMouseEvents(true);
    this.overlayWindow.on('closed', () => {
      this.overlayWindow = null;
      this.overlayReadyPromise = null;
    });

    this.overlayWindow.webContents.session.setPermissionRequestHandler((_webContents, permission, callback) => {
      callback(permission === 'media');
    });
    this.overlayReadyPromise = this.overlayWindow.loadURL(
      `data:text/html;charset=utf-8,${encodeURIComponent(VOICE_OVERLAY_HTML)}`
    );
    await this.overlayReadyPromise;
  }

  private async positionOverlayWindow(): Promise<void> {
    if (!this.overlayWindow) {
      return;
    }

    const display = screen.getPrimaryDisplay();
    const { x, y, width, height } = display.workArea;
    const overlayBounds = this.overlayWindow.getBounds();
    this.overlayWindow.setBounds({
      x: Math.round(x + width / 2 - overlayBounds.width / 2),
      y: Math.round(y + height - overlayBounds.height - 26),
      width: overlayBounds.width,
      height: overlayBounds.height,
    });
  }

  private async executeOverlay<T>(script: string): Promise<T> {
    await this.ensureOverlayWindow();
    if (!this.overlayWindow) {
      throw new Error('Voice overlay window is unavailable.');
    }

    return this.overlayWindow.webContents.executeJavaScript(script, true) as Promise<T>;
  }

  private async startOverlayRecording(): Promise<void> {
    await this.executeOverlay<boolean>('window.voiceVibeOverlayStartRecording()');
  }

  private async stopOverlayRecording(): Promise<VoiceInputOverlayCapture> {
    return this.executeOverlay<VoiceInputOverlayCapture>('window.voiceVibeOverlayStopRecording()');
  }

  private async cancelOverlayRecording(): Promise<void> {
    await this.executeOverlay<boolean>('window.voiceVibeOverlayCancelRecording()');
  }

  private async setOverlayState(state: 'idle' | 'recording' | 'transcribing' | 'success' | 'error'): Promise<void> {
    await this.executeOverlay(`window.voiceVibeOverlaySetState(${JSON.stringify(state)})`);
  }

  private async flashOverlayState(state: 'success' | 'error'): Promise<void> {
    try {
      await this.setOverlayState(state);
      await new Promise((resolve) => setTimeout(resolve, 900));
    } finally {
      await this.hideOverlay();
    }
  }

  private async hideOverlay(): Promise<void> {
    if (!this.overlayWindow || this.overlayWindow.isDestroyed()) {
      return;
    }

    await this.setOverlayState('idle').catch(() => {});
    this.overlayWindow.hide();
  }

  private updateState(patch: Partial<VoiceInputState>): void {
    this.state = createVoiceInputState(
      {
        ...this.state,
        ...patch,
        updatedAt: Date.now(),
      },
      this.config
    );
    this.emitState();
  }

  private emitState(): void {
    this.options.emitState(this.state);
  }
}

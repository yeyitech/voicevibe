import { app, BrowserWindow, ipcMain, shell } from 'electron';
import { fileURLToPath } from 'node:url';
import { VoiceInputRuntime } from '@main/services/voice/VoiceInputRuntime';
import type { VoiceInputConfig, VoiceInputOpenWhisperModelId, VoiceInputState } from '@shared/voice/types';

let mainWindow: BrowserWindow | null = null;
let voiceInputRuntime: VoiceInputRuntime | null = null;

const isDev = !app.isPackaged;

const createWindow = async (): Promise<void> => {
  mainWindow = new BrowserWindow({
    width: 1320,
    height: 920,
    minWidth: 1080,
    minHeight: 760,
    title: 'VoiceVibe',
    backgroundColor: '#0d111d',
    titleBarStyle: 'hiddenInset',
    webPreferences: {
      preload: fileURLToPath(new URL('../preload/index.mjs', import.meta.url)),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });

  if (isDev) {
    await mainWindow.loadURL(process.env.ELECTRON_RENDERER_URL ?? 'http://localhost:5173');
    mainWindow.webContents.openDevTools({ mode: 'detach' });
  } else {
    await mainWindow.loadFile(fileURLToPath(new URL('../renderer/index.html', import.meta.url)));
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
};

const emitState = (state: VoiceInputState): void => {
  for (const window of BrowserWindow.getAllWindows()) {
    window.webContents.send('voice-input:state-changed', state);
  }
};

app.whenReady().then(async () => {
  voiceInputRuntime = new VoiceInputRuntime({ emitState });
  await voiceInputRuntime.initialize();

  ipcMain.handle('app:open-external', async (_event, url: string) => {
    await shell.openExternal(url);
  });

  ipcMain.handle('app:reveal-path', async (_event, targetPath: string) => {
    shell.showItemInFolder(targetPath);
  });

  ipcMain.handle('voice-input:get-config', () => voiceInputRuntime?.getConfig());
  ipcMain.handle('voice-input:set-config', async (_event, config: VoiceInputConfig) => {
    return voiceInputRuntime?.setConfig(config);
  });
  ipcMain.handle('voice-input:get-state', () => voiceInputRuntime?.getState());
  ipcMain.handle('voice-input:request-permissions', async () => voiceInputRuntime?.requestPermissions());
  ipcMain.handle('voice-input:start-manual-capture', async () => voiceInputRuntime?.startManualCapture());
  ipcMain.handle('voice-input:stop-manual-capture', async () => voiceInputRuntime?.stopManualCapture());
  ipcMain.handle('voice-input:get-stats', async () => voiceInputRuntime?.getStats());
  ipcMain.handle('voice-input:list-history', async () => voiceInputRuntime?.listHistory());
  ipcMain.handle('voice-input:get-open-whisper-state', async () => voiceInputRuntime?.getOpenWhisperState());
  ipcMain.handle('voice-input:install-open-whisper-runtime', async () => voiceInputRuntime?.installOpenWhisperRuntime());
  ipcMain.handle('voice-input:install-open-whisper-model', async (_event, modelId: VoiceInputOpenWhisperModelId) => {
    return voiceInputRuntime?.installOpenWhisperModel(modelId);
  });

  await createWindow();

  app.on('activate', async () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      await createWindow();
      return;
    }

    mainWindow?.show();
    mainWindow?.focus();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('before-quit', async () => {
  await voiceInputRuntime?.dispose();
});

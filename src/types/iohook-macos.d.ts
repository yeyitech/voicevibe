declare module 'iohook-macos' {
  type HookEvent = {
    keyCode?: number;
    flags?: number;
    modifiers: {
      command: boolean;
      option: boolean;
      fn: boolean;
    };
  };

  type AccessibilityStatus = {
    hasPermissions: boolean;
  };

  type Listener = (event: HookEvent) => void;

  type IoHookMacos = {
    startMonitoring(): void;
    stopMonitoring(): void;
    checkAccessibilityPermissions(): AccessibilityStatus;
    requestAccessibilityPermissions(): void;
    on(eventName: 'flagsChanged' | 'keyDown' | 'keyUp', listener: Listener): void;
  };

  const iohookMacos: IoHookMacos;
  export default iohookMacos;
}

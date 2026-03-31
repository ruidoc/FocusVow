export interface SettingsState {
  hasAuthorized: boolean;
  selectedTokens: string[];
  selectedAppCount: number;
  statusMessage: string;
}

export function createDefaultSettingsState(): SettingsState {
  return {
    hasAuthorized: false,
    selectedTokens: [],
    selectedAppCount: 0,
    statusMessage: '先申请系统授权，再选择需要限制的应用'
  };
}

export type CycleGuardPhase =
  'idle'
  | 'quota_running'
  | 'locked';

export interface CycleGuardState {
  enabled: boolean;
  configured: boolean;
  quotaMinutes: number;
  lockMinutes: number;
  selectedTokens: string[];
  selectedAppCount: number;
  phase: CycleGuardPhase;
  statusMessage: string;
}

export function normalizeCycleGuardState(state?: Partial<CycleGuardState> | null): CycleGuardState {
  const defaultState = createDefaultCycleGuardState();
  return {
    enabled: state?.enabled ?? defaultState.enabled,
    configured: state?.configured === true,
    quotaMinutes: state?.quotaMinutes ?? defaultState.quotaMinutes,
    lockMinutes: state?.lockMinutes ?? defaultState.lockMinutes,
    selectedTokens: state?.selectedTokens ? [...state.selectedTokens] : [...defaultState.selectedTokens],
    selectedAppCount: state?.selectedAppCount ?? defaultState.selectedAppCount,
    phase: state?.phase ?? defaultState.phase,
    statusMessage: state?.statusMessage ?? defaultState.statusMessage
  };
}

export function createDefaultCycleGuardState(): CycleGuardState {
  return {
    enabled: false,
    configured: false,
    quotaMinutes: 60,
    lockMinutes: 25,
    selectedTokens: [],
    selectedAppCount: 0,
    phase: 'idle',
    statusMessage: '配置总可用时长和目标应用后，即可启动娱乐限额'
  };
}

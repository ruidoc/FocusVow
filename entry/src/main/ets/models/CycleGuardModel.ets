export type CycleGuardPhase =
  'idle'
  | 'quota_running'
  | 'locked';

export interface CycleGuardState {
  enabled: boolean;
  quotaMinutes: number;
  selectedTokens: string[];
  selectedAppCount: number;
  phase: CycleGuardPhase;
  statusMessage: string;
}

export function normalizeCycleGuardState(state?: Partial<CycleGuardState> | null): CycleGuardState {
  const defaultState = createDefaultCycleGuardState();
  return {
    enabled: state?.enabled ?? defaultState.enabled,
    quotaMinutes: state?.quotaMinutes ?? defaultState.quotaMinutes,
    selectedTokens: state?.selectedTokens ? [...state.selectedTokens] : [...defaultState.selectedTokens],
    selectedAppCount: state?.selectedAppCount ?? defaultState.selectedAppCount,
    phase: state?.phase ?? defaultState.phase,
    statusMessage: state?.statusMessage ?? defaultState.statusMessage
  };
}

export function createDefaultCycleGuardState(): CycleGuardState {
  return {
    enabled: false,
    quotaMinutes: 60,
    selectedTokens: [],
    selectedAppCount: 0,
    phase: 'idle',
    statusMessage: '配置总可用时长和目标应用后，即可启动娱乐限额'
  };
}

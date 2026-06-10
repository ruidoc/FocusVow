export type CycleGuardPhase =
  'idle'
  | 'quota_running'
  | 'switching_to_lock'
  | 'lock_running'
  | 'switching_to_quota';

export interface CycleGuardState {
  enabled: boolean;
  quotaMinutes: number;
  lockMinutes: number;
  selectedTokens: string[];
  selectedAppCount: number;
  phase: CycleGuardPhase;
  statusMessage: string;
}

export function createDefaultCycleGuardState(): CycleGuardState {
  return {
    enabled: false,
    quotaMinutes: 60,
    lockMinutes: 20,
    selectedTokens: [],
    selectedAppCount: 0,
    phase: 'idle',
    statusMessage: '配置共享时长和锁定时长后，即可启动循环守护'
  };
}

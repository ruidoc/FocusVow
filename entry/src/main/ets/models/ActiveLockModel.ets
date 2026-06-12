export type RestrictionMode = 'shield' | 'allow';

export type LockKind = 'none' | 'covenant' | 'cycle_guard' | 'quick_focus';

export const CYCLE_GUARD_STRATEGY_NAME: string = 'cycle_quota_strategy';

export interface ActiveLockState {
  kind: LockKind;
  strategyName: string;
  title: string;
  planId: string;
  selectedTokens: string[];
  selectedCount: number;
  mode: RestrictionMode;
  startedAt: number;
  endAt: number;
  updatedAt: number;
}

export function createIdleLockState(): ActiveLockState {
  return {
    kind: 'none',
    strategyName: '',
    title: '',
    planId: '',
    selectedTokens: [],
    selectedCount: 0,
    mode: 'shield',
    startedAt: 0,
    endAt: 0,
    updatedAt: Date.now()
  };
}

export function normalizeActiveLockState(state?: Partial<ActiveLockState> | null): ActiveLockState {
  const idle = createIdleLockState();
  if (!state) {
    return idle;
  }

  return {
    kind: state.kind ?? idle.kind,
    strategyName: state.strategyName ?? idle.strategyName,
    title: state.title ?? idle.title,
    planId: state.planId ?? idle.planId,
    selectedTokens: state.selectedTokens ? [...state.selectedTokens] : [...idle.selectedTokens],
    selectedCount: state.selectedCount ?? idle.selectedCount,
    mode: state.mode ?? idle.mode,
    startedAt: state.startedAt ?? idle.startedAt,
    endAt: state.endAt ?? idle.endAt,
    updatedAt: state.updatedAt ?? idle.updatedAt
  };
}

export function isLocked(state: ActiveLockState): boolean {
  return state.kind !== 'none';
}

export function getRemainingSeconds(state: ActiveLockState, nowAt: number): number {
  if (!isLocked(state) || state.endAt <= 0) {
    return 0;
  }

  const remainMs = state.endAt - nowAt;
  if (remainMs <= 0) {
    return 0;
  }

  return Math.ceil(remainMs / 1000);
}

export function isTimedLockFinished(state: ActiveLockState, nowAt: number): boolean {
  if (state.kind !== 'covenant' && state.kind !== 'quick_focus') {
    return false;
  }

  return state.endAt > 0 && getRemainingSeconds(state, nowAt) === 0;
}

export function formatRemainingSeconds(totalSeconds: number): string {
  const safeSeconds = Math.max(0, totalSeconds);
  const minutes = Math.floor(safeSeconds / 60);
  const seconds = safeSeconds % 60;

  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

export function createQuickFocusLockState(
  selectedTokens: string[],
  durationMinutes: number,
  mode: RestrictionMode,
  nowAt: number = Date.now()
): ActiveLockState {
  const safeDuration = durationMinutes > 0 ? durationMinutes : 25;

  return {
    kind: 'quick_focus',
    strategyName: '',
    title: '快速专注',
    planId: '',
    selectedTokens: [...selectedTokens],
    selectedCount: selectedTokens.length,
    mode,
    startedAt: nowAt,
    endAt: nowAt + safeDuration * 60 * 1000,
    updatedAt: nowAt
  };
}

export function createCovenantLockState(
  planId: string,
  planName: string,
  selectedTokens: string[],
  mode: RestrictionMode,
  windowStartAt: number,
  windowEndAt: number,
  nowAt: number = Date.now()
): ActiveLockState {
  return {
    kind: 'covenant',
    strategyName: planId,
    title: planName,
    planId,
    selectedTokens: [...selectedTokens],
    selectedCount: selectedTokens.length,
    mode,
    startedAt: windowStartAt,
    endAt: windowEndAt,
    updatedAt: nowAt
  };
}

export function createCycleGuardLockState(
  selectedTokens: string[],
  selectedCount: number,
  nowAt: number = Date.now()
): ActiveLockState {
  return {
    kind: 'cycle_guard',
    strategyName: CYCLE_GUARD_STRATEGY_NAME,
    title: '循环守护',
    planId: '',
    selectedTokens: [...selectedTokens],
    selectedCount,
    mode: 'allow',
    startedAt: nowAt,
    endAt: 0,
    updatedAt: nowAt
  };
}

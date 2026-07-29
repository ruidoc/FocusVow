import { isCountupMode, resolveInstantLockMinutes } from '../utils/TimerMode';

export type RestrictionMode = 'shield' | 'allow';

export type LockKind = 'none' | 'covenant' | 'cycle_guard' | 'quick_focus';

export type QuickFocusParticipationMode = 'solo' | 'duo' | '';

export interface QuickFocusOptions {
  title?: string;
  duoSessionId?: string;
  recordId?: string;
  participationMode?: QuickFocusParticipationMode;
  partnerNickname?: string;
  /** 服务端权威开始时刻（ms）；搭子互督应对齐 active_at */
  startedAtMs?: number;
  /** 服务端权威结束时刻（ms）；搭子互督应对齐 end_at */
  endAtMs?: number;
  /** countdown | countup；默认 countdown */
  timerMode?: string;
  /** 正计时最短时长（分钟）；倒计时为 0 */
  minDurationMin?: number;
}

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
  duoSessionId: string;
  recordId: string;
  participationMode: 'solo' | 'duo' | '';
  partnerNickname: string;
  /** countdown | countup；默认 countdown */
  timerMode: string;
  /** 正计时最短时长（分钟）；倒计时为 0 */
  minDurationMin: number;
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
    updatedAt: Date.now(),
    duoSessionId: '',
    recordId: '',
    participationMode: '',
    partnerNickname: '',
    timerMode: 'countdown',
    minDurationMin: 0
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
    updatedAt: state.updatedAt ?? idle.updatedAt,
    duoSessionId: state.duoSessionId ?? idle.duoSessionId,
    recordId: state.recordId ?? idle.recordId,
    participationMode: state.participationMode ?? idle.participationMode,
    partnerNickname: state.partnerNickname ?? idle.partnerNickname,
    timerMode: state.timerMode === 'countup' ? 'countup' : 'countdown',
    minDurationMin: state.minDurationMin ?? idle.minDurationMin
  };
}

export function withLockPartnerNickname(state: ActiveLockState, partnerNickname: string): ActiveLockState {
  if (state.partnerNickname.trim().length > 0) {
    return state;
  }
  return normalizeActiveLockState({
    kind: state.kind,
    strategyName: state.strategyName,
    title: state.title,
    planId: state.planId,
    selectedTokens: state.selectedTokens,
    selectedCount: state.selectedCount,
    mode: state.mode,
    startedAt: state.startedAt,
    endAt: state.endAt,
    updatedAt: state.updatedAt,
    duoSessionId: state.duoSessionId,
    recordId: state.recordId,
    participationMode: state.participationMode,
    partnerNickname: partnerNickname.trim().length > 0 ? partnerNickname.trim() : '搭子',
    timerMode: state.timerMode,
    minDurationMin: state.minDurationMin
  });
}

export function isLocked(state: ActiveLockState): boolean {
  return state.kind !== 'none';
}

export function isCountupLock(state: ActiveLockState): boolean {
  return isCountupMode(state.timerMode);
}

export function resolveDuoSessionIdFromLock(lock: ActiveLockState): string {
  if (lock.duoSessionId.length > 0) {
    return lock.duoSessionId;
  }
  if (lock.planId.startsWith('session_')) {
    return lock.planId.replace('session_', '');
  }
  return '';
}

export function isDuoCovenantLock(lock: ActiveLockState): boolean {
  return lock.kind === 'covenant' &&
    lock.participationMode === 'duo' &&
    resolveDuoSessionIdFromLock(lock).length > 0;
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

export function getElapsedSeconds(state: ActiveLockState, nowAt: number): number {
  if (!isLocked(state) || state.startedAt <= 0) {
    return 0;
  }
  return Math.max(0, Math.floor((nowAt - state.startedAt) / 1000));
}

export function isTimedLockFinished(state: ActiveLockState, nowAt: number): boolean {
  if (state.kind !== 'covenant' && state.kind !== 'quick_focus') {
    return false;
  }
  // 正计时不因到点自动完成
  if (state.kind === 'quick_focus' && isCountupLock(state)) {
    return false;
  }

  return state.endAt > 0 && getRemainingSeconds(state, nowAt) === 0;
}

export function minutesToHours(minutes: number): string {
  const safeMinutes = Math.max(0, Math.floor(minutes));
  const hours = Math.floor(safeMinutes / 60);
  const remainingMinutes = safeMinutes % 60;

  if (hours === 0) {
    return `${remainingMinutes} 分钟`;
  }
  if (remainingMinutes === 0) {
    return `${hours} 小时`;
  }
  return `${hours} 小时 ${remainingMinutes} 分`;
}

export function formatRemainingSeconds(totalSeconds: number): string {
  const safeSeconds = Math.max(0, Math.floor(totalSeconds));
  const hours = Math.floor(safeSeconds / 3600);
  const minutes = Math.floor((safeSeconds % 3600) / 60);
  const seconds = safeSeconds % 60;

  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

export function createQuickFocusLockState(
  selectedTokens: string[],
  durationMinutes: number,
  mode: RestrictionMode,
  nowAt: number = Date.now(),
  title: string = '单人专注',
  duoSessionId: string = '',
  recordId: string = '',
  participationMode: 'solo' | 'duo' | '' = '',
  partnerNickname: string = '',
  startedAtMs?: number,
  endAtMs?: number,
  timerMode: string = 'countdown',
  minDurationMin: number = 0
): ActiveLockState {
  const normalizedMode = timerMode === 'countup' ? 'countup' : 'countdown';
  const lockMinutes = resolveInstantLockMinutes(durationMinutes, normalizedMode);
  const resolvedMin = normalizedMode === 'countup'
    ? (minDurationMin > 0 ? minDurationMin : durationMinutes)
    : 0;
  const hasServerEnd = endAtMs !== undefined && endAtMs > 0;
  const endAt = hasServerEnd ? endAtMs : nowAt + lockMinutes * 60 * 1000;
  const startedAt = startedAtMs !== undefined && startedAtMs > 0
    ? startedAtMs
    : (hasServerEnd ? endAt - lockMinutes * 60 * 1000 : nowAt);

  return {
    kind: 'quick_focus',
    strategyName: '',
    title,
    planId: '',
    selectedTokens: [...selectedTokens],
    selectedCount: selectedTokens.length,
    mode,
    startedAt,
    endAt,
    updatedAt: nowAt,
    duoSessionId,
    recordId,
    participationMode,
    partnerNickname,
    timerMode: normalizedMode,
    minDurationMin: resolvedMin
  };
}

export function createCovenantLockState(
  planId: string,
  planName: string,
  selectedTokens: string[],
  mode: RestrictionMode,
  windowStartAt: number,
  windowEndAt: number,
  nowAt: number = Date.now(),
  duoSessionId: string = '',
  recordId: string = '',
  participationMode: QuickFocusParticipationMode = '',
  partnerNickname: string = ''
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
    updatedAt: nowAt,
    duoSessionId,
    recordId,
    participationMode,
    partnerNickname,
    timerMode: 'countdown',
    minDurationMin: 0
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
    title: '娱乐限额',
    planId: '',
    selectedTokens: [...selectedTokens],
    selectedCount,
    mode: 'allow',
    startedAt: nowAt,
    endAt: 0,
    updatedAt: nowAt,
    duoSessionId: '',
    recordId: '',
    participationMode: '',
    partnerNickname: '',
    timerMode: 'countdown',
    minDurationMin: 0
  };
}

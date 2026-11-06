import { ActiveLockState } from '../models/ActiveLockModel';
import { isCountupMode } from './TimerMode';
import { resolveCountedActualMin } from './FocusValidity';

export interface ContractPointDeltaParams {
  lock: ActiveLockState;
  endedAt: number;
  outcome: 'success' | 'failed';
  failReason?: string;
  breachRole?: string;
}

const SKIP_FAIL: Set<string> = new Set(['too_short', 'cancelled']);

function totalMinutesFromLock(lock: ActiveLockState): number {
  if (isCountupMode(lock.timerMode) && (lock.minDurationMin || 0) > 0) {
    return Math.max(1, lock.minDurationMin || 1);
  }
  if (lock.endAt > lock.startedAt) {
    return Math.max(1, Math.round((lock.endAt - lock.startedAt) / 60000));
  }
  return 25;
}

function pointBandMin(lock: ActiveLockState, endedAt: number): number {
  const total = totalMinutesFromLock(lock);
  if (isCountupMode(lock.timerMode)) {
    const actual =
      lock.startedAt > 0 ? resolveCountedActualMin(lock.startedAt, endedAt) : 0;
    return actual > 0 ? actual : 0;
  }
  return total > 0 ? total : 0;
}

function isDuo(lock: ActiveLockState): boolean {
  return lock.participationMode === 'duo' || lock.duoSessionId.trim().length > 0;
}

/** 与 focus-api scorePointRecord 一致；无加减分时返回 null */
export function estimateContractPointDelta(params: ContractPointDeltaParams): number | null {
  const reason = String(params.failReason || '');
  if (SKIP_FAIL.has(reason)) {
    return null;
  }

  const minutes = pointBandMin(params.lock, params.endedAt);
  const duo = isDuo(params.lock);
  const success = params.outcome === 'success';
  const role = String(params.breachRole || '');
  const cohort = !success && (role === 'cohort' || role === 'victim');

  const duoTear = minutes >= 60 ? -30 : -20;
  if (cohort) {
    return Math.trunc(duoTear / 2);
  }

  let delta = 0;
  if (!duo) {
    if (minutes >= 60) {
      delta = success ? 20 : -15;
    } else if (minutes >= 30) {
      delta = success ? 10 : -10;
    } else {
      delta = success ? 5 : -5;
    }
  } else if (success) {
    delta = minutes >= 60 ? 30 : 15;
  } else {
    delta = duoTear;
  }

  return delta;
}

export function formatContractPointDelta(delta: number): string {
  if (delta > 0) {
    return `+${delta}`;
  }
  return String(delta);
}

export function formatContractPoints(value: number): string {
  return Math.max(0, Math.round(value)).toLocaleString('en-US');
}

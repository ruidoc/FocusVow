/**
 * 正计时无产品硬上限；锁机仍需结束点。
 * 对齐 rn-expo：用 23h 作开放锁机窗（不展示给用户）。
 */
export const COUNTUP_OPEN_LOCK_MIN: number = 23 * 60;

export type TimerMode = 'countdown' | 'countup';

export function normalizeTimerMode(raw?: string | null): TimerMode {
  return raw === 'countup' ? 'countup' : 'countdown';
}

export function isCountupMode(raw?: string | null): boolean {
  return normalizeTimerMode(raw) === 'countup';
}

/** 即时锁机窗口：倒计时=设定时长；正计时=开放安全窗口 */
export function resolveInstantLockMinutes(
  durationMin: number,
  timerMode?: string | null
): number {
  if (isCountupMode(timerMode)) {
    return COUNTUP_OPEN_LOCK_MIN;
  }
  return Math.max(1, durationMin > 0 ? durationMin : 25);
}

/** 是否已过正计时最短时间（可正常结束） */
export function isPastCountupMinimum(
  startedAtMs: number,
  minDurationMin: number,
  nowMs: number = Date.now()
): boolean {
  if (!startedAtMs || minDurationMin <= 0) {
    return false;
  }
  return nowMs - startedAtMs >= minDurationMin * 60_000;
}

/** 不足此时长的专注视为无效：不计时、不生成证书 */
export const MIN_VALID_FOCUS_MS = 30_000;

export const FOCUS_TOO_SHORT_TIP = '专注不足 30 秒，本次不计时';

export function isFocusTooShort(startedAt: number, endedAt: number): boolean {
  if (!startedAt || !endedAt || endedAt <= startedAt) {
    return true;
  }
  return endedAt - startedAt < MIN_VALID_FOCUS_MS;
}

/**
 * 有效专注的已用分钟：≥30 秒至少记 1 分钟。
 * 无效场次返回 0。
 */
export function resolveCountedActualMin(
  startedAt: number,
  endedAt: number,
): number {
  if (isFocusTooShort(startedAt, endedAt)) {
    return 0;
  }
  return Math.max(1, Math.round((endedAt - startedAt) / 60000));
}

import { DuoSessionView, getScheduleRepeatDays } from '../models/DuoModel';

export const SLEEP_MAX_MIN: number = 12 * 60;
export const SLEEP_MIN_DURATION_MIN: number = 5 * 60;
export const SLEEP_START_MIN_BOUND: number = 21 * 60;
export const SLEEP_START_MAX_BOUND: number = 23 * 60 + 30;
export const SLEEP_END_MIN_BOUND: number = 5 * 60;
export const SLEEP_END_MAX_BOUND: number = 8 * 60 + 30;
export const SLEEP_DEFAULT_START_CLOCK: string = '22:30';
export const SLEEP_DEFAULT_END_CLOCK: string = '06:30';
export const SLEEP_WEEKLY_REPEAT: number[] = [1, 2, 3, 4, 5, 6, 7];

export type SleepClockValidationReason = 'sleep_start_range' | 'sleep_end_range' | 'sleep_too_short';

export function isSleepSchedule(schedule?: Record<string, string | number> | null): boolean {
  if (!schedule) {
    return false;
  }
  return String(schedule['kind'] ?? '') === 'sleep';
}

export function clockDurationMinutes(startMin: number, endMin: number): number {
  if (endMin > startMin) {
    return endMin - startMin;
  }
  if (endMin < startMin) {
    return 24 * 60 - startMin + endMin;
  }
  return 0;
}

export function validateSleepClockWindow(startMin: number, endMin: number): string {
  if (startMin < SLEEP_START_MIN_BOUND || startMin > SLEEP_START_MAX_BOUND) {
    return '入睡时间需在 21:00–23:30';
  }
  if (endMin < SLEEP_END_MIN_BOUND || endMin > SLEEP_END_MAX_BOUND) {
    return '起床时间需在 05:00–08:30';
  }
  if (clockDurationMinutes(startMin, endMin) < SLEEP_MIN_DURATION_MIN) {
    return '早睡时长至少 5 小时';
  }
  if (clockDurationMinutes(startMin, endMin) > SLEEP_MAX_MIN) {
    return '早睡时长不能超过 12 小时';
  }
  return '';
}

/** JS getDay(): 0=周日 … 6=周六；repeat 1=周一 … 7=周日 */
export function jsWeekdayToRepeatDay(jsDay: number): number {
  return jsDay === 0 ? 7 : jsDay;
}

function prevRepeatDay(day: number): number {
  return day === 1 ? 7 : day - 1;
}

export function inScheduledClockWindow(
  startMin: number,
  endMin: number,
  repeatDays: number[],
  nowMin: number,
  jsToday: number,
): boolean {
  if (repeatDays.length === 0) {
    return false;
  }
  const today = jsWeekdayToRepeatDay(jsToday);
  if (endMin > startMin) {
    return repeatDays.includes(today) && nowMin >= startMin && nowMin < endMin;
  }
  if (endMin < startMin) {
    if (nowMin >= startMin) {
      return repeatDays.includes(today);
    }
    return repeatDays.includes(prevRepeatDay(today)) && nowMin < endMin;
  }
  return false;
}

export function resolveSleepSession(sessions: DuoSessionView[]): DuoSessionView | null {
  let fallback: DuoSessionView | null = null;
  for (let i = 0; i < sessions.length; i++) {
    const session = sessions[i];
    if (!isSleepSchedule(session.schedule_json)) {
      continue;
    }
    if (session.viewer_role === 'initiator') {
      return session;
    }
    if (fallback === null) {
      fallback = session;
    }
  }
  return fallback;
}

export function parseMinutesFromClock(clock: string, fallbackMin: number = 0): number {
  const parts = clock.trim().split(':');
  if (parts.length < 2) {
    return fallbackMin;
  }
  const hour = Math.floor(Number(parts[0]) || 0);
  const minute = Math.floor(Number(parts[1]) || 0);
  return hour * 60 + minute;
}

export function repeatDaysOfSession(session: DuoSessionView): number[] {
  if (session.schedule_repeat === 'once') {
    return getScheduleRepeatDays(session.schedule_repeat);
  }
  return getScheduleRepeatDays(session.schedule_repeat ?? '');
}

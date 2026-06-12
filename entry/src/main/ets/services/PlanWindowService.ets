import { FocusPlan } from '../models/PlanModel';

export interface PlanWindow {
  startAt: number;
  endAt: number;
}

function getTimeParts(timeText: string): number[] | null {
  const parts = timeText.split(':');
  if (parts.length !== 2) {
    return null;
  }

  return [Number(parts[0]), Number(parts[1])];
}

function createDateFromPlanTime(baseDate: Date, timeText: string): Date {
  const result = new Date(baseDate.getTime());
  const parts = getTimeParts(timeText);
  const hour = parts ? parts[0] : 0;
  const minute = parts ? parts[1] : 0;
  result.setHours(hour, minute, 0, 0);
  return result;
}

export function getPlanWindow(plan: FocusPlan, now: Date): PlanWindow {
  const todayStart = createDateFromPlanTime(now, plan.startTime);
  const todayEnd = createDateFromPlanTime(now, plan.endTime);

  if (todayStart.getTime() === todayEnd.getTime()) {
    return {
      startAt: now.getTime(),
      endAt: now.getTime() + 24 * 60 * 60 * 1000
    };
  }

  if (todayStart.getTime() < todayEnd.getTime()) {
    return {
      startAt: todayStart.getTime(),
      endAt: todayEnd.getTime()
    };
  }

  if (now.getTime() >= todayStart.getTime()) {
    const nextDayEnd = new Date(todayEnd.getTime());
    nextDayEnd.setDate(nextDayEnd.getDate() + 1);
    return {
      startAt: todayStart.getTime(),
      endAt: nextDayEnd.getTime()
    };
  }

  const previousDayStart = new Date(todayStart.getTime());
  previousDayStart.setDate(previousDayStart.getDate() - 1);
  return {
    startAt: previousDayStart.getTime(),
    endAt: todayEnd.getTime()
  };
}

export function isWithinPlanWindow(plan: FocusPlan, now: Date = new Date()): boolean {
  const window = getPlanWindow(plan, now);
  const nowMs = now.getTime();
  return nowMs >= window.startAt && nowMs < window.endAt;
}

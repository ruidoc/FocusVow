import { showToast } from '../common/Toast';
import { DuoSessionView, getScheduleRepeatDays, getScheduledSessionEndMin, getScheduledSessionStartMin, isInactiveScheduledSession } from '../models/DuoModel';
import { FocusPlan, getTodayRepeatDay, normalizePlanRepeatDays, normalizeTimeText } from '../models/PlanModel';
import { PlanStore } from '../stores/PlanStore';
import { ScheduledListStore } from '../stores/ScheduledListStore';
import { isSleepSchedule } from '../utils/ScheduledClockUtil';

interface ScheduledSessionTimeRange {
  startMin: number;
  endMin: number;
  repeatDays: number[];
}

function timeToMinutes(time: string): number {
  const normalized = normalizeTimeText(time, '09:00');
  const parts = normalized.split(':');
  return Math.floor(Number(parts[0]) || 0) * 60 + Math.floor(Number(parts[1]) || 0);
}

export const MIN_SCHEDULED_PLAN_MINUTES: number = 10;
export const DEFAULT_SCHEDULED_PLAN_MINUTES: number = 20;

export function getScheduledDurationMinutes(startMin: number, endMin: number): number {
  if (endMin > startMin) {
    return endMin - startMin;
  }
  if (endMin < startMin) {
    return 24 * 60 - startMin + endMin;
  }
  return 0;
}

function nextScheduledRepeatDay(day: number): number {
  return day === 7 ? 1 : day + 1;
}

interface OccupiedSlot {
  day: number;
  startMin: number;
  endMin: number;
}

function occupiedSlots(startMin: number, endMin: number, repeatDays: number[]): OccupiedSlot[] {
  const days = normalizePlanRepeatDays(repeatDays);
  const slots: OccupiedSlot[] = [];
  for (let i = 0; i < days.length; i++) {
    const day = days[i];
    if (endMin > startMin) {
      slots.push({ day, startMin, endMin });
    } else if (endMin < startMin) {
      slots.push({ day, startMin, endMin: 24 * 60 });
      slots.push({ day: nextScheduledRepeatDay(day), startMin: 0, endMin });
    }
  }
  return slots;
}

function isTimeRangeOverlap(startA: number, endA: number, startB: number, endB: number): boolean {
  return startA < endB && endA > startB;
}

function isScheduledRangeOverlap(
  startA: number,
  endA: number,
  daysA: number[],
  startB: number,
  endB: number,
  daysB: number[]
): boolean {
  const left = occupiedSlots(startA, endA, daysA);
  const right = occupiedSlots(startB, endB, daysB);
  for (let i = 0; i < left.length; i++) {
    for (let j = 0; j < right.length; j++) {
      if (left[i].day === right[j].day &&
        isTimeRangeOverlap(left[i].startMin, left[i].endMin, right[j].startMin, right[j].endMin)) {
        return true;
      }
    }
  }
  return false;
}

function isActiveScheduledSession(session: DuoSessionView): boolean {
  if (session.type !== 'scheduled') {
    return false;
  }
  if (session.enabled === false) {
    return false;
  }
  return !isInactiveScheduledSession(session);
}

function getSessionTimeRange(session: DuoSessionView): ScheduledSessionTimeRange {
  const scheduleJson = session.schedule_json;
  const repeatRaw = session.schedule_repeat && session.schedule_repeat.length > 0
    ? session.schedule_repeat
    : String(scheduleJson?.['repeat'] ?? '1,2,3,4,5');
  const range: ScheduledSessionTimeRange = {
    startMin: getScheduledSessionStartMin(session),
    endMin: getScheduledSessionEndMin(session),
    repeatDays: getScheduleRepeatDays(repeatRaw)
  };
  return range;
}

/** 与 RN scheduleOverlapMessageKey 文案一致 */
export function scheduledOverlapToastMessage(selfIsSleep: boolean, otherIsSleep: boolean): string {
  if (otherIsSleep) {
    return '与早睡重叠';
  }
  if (selfIsSleep) {
    return '与定时任务重叠';
  }
  return '与其他契约时间重叠';
}

export function findOverlappingScheduledSession(
  startMin: number,
  endMin: number,
  repeatDays: number[],
  sessions: DuoSessionView[],
  excludeSessionId: string = ''
): DuoSessionView | undefined {
  const normalizedRepeat = normalizePlanRepeatDays(repeatDays);
  for (let i = 0; i < sessions.length; i++) {
    const session = sessions[i];
    if (!isActiveScheduledSession(session)) {
      continue;
    }
    if (excludeSessionId.length > 0 && session.session_id === excludeSessionId) {
      continue;
    }
    const range = getSessionTimeRange(session);
    if (isScheduledRangeOverlap(startMin, endMin, normalizedRepeat, range.startMin, range.endMin, range.repeatDays)) {
      return session;
    }
  }
  return undefined;
}

function nextRepeatDay(day: number): number {
  return day === 7 ? 1 : day + 1;
}

function windowOverlapsPlan(
  startMin: number,
  windowMin: number,
  planStart: number,
  planEnd: number,
  planDays: number[],
  today: number,
): boolean {
  const endMin = startMin + Math.max(1, windowMin);
  if (endMin <= 24 * 60) {
    return isScheduledRangeOverlap(startMin, endMin, [today], planStart, planEnd, planDays);
  }
  if (isScheduledRangeOverlap(startMin, 24 * 60, [today], planStart, planEnd, planDays)) {
    return true;
  }
  return isScheduledRangeOverlap(0, endMin - 24 * 60, [nextRepeatDay(today)], planStart, planEnd, planDays);
}

/** 正计时只用最短时长，避免误挡几小时后的定时契约。 */
export function conflictWindowMinutes(timerMode: string, durationMin: number): number {
  const minutes = durationMin > 0 ? durationMin : 25;
  if (timerMode === 'countup') {
    return Math.max(1, minutes);
  }
  return Math.max(1, minutes);
}

/**
 * 本次锁机窗口是否盖住已启用的定时契约。
 * 命中则提示并返回 true。
 */
export function blockIfOverlapsScheduledPlan(windowMin: number): boolean {
  const now = new Date();
  const startMinute = now.getHours() * 60 + now.getMinutes();
  const today = getTodayRepeatDay();
  const plans: FocusPlan[] = PlanStore.getPlans();
  let conflictPlan: FocusPlan | undefined = undefined;
  for (let i = 0; i < plans.length; i++) {
    const plan = plans[i];
    if (!plan.enabled || plan.repeatDays.length === 0) {
      continue;
    }
    const planStart = timeToMinutes(plan.startTime);
    const planEnd = timeToMinutes(plan.endTime);
    if (windowOverlapsPlan(startMinute, windowMin, planStart, planEnd, plan.repeatDays, today)) {
      conflictPlan = plan;
      break;
    }
  }
  if (!conflictPlan) {
    return false;
  }
  const conflictStart = timeToMinutes(conflictPlan.startTime);
  const sleepConflict = isSleepPlanId(conflictPlan.duoSessionId);
  const minutesUntil = conflictStart - startMinute;
  if (minutesUntil > 0) {
    showToast(
      sleepConflict
        ? `${minutesUntil}分钟后早睡开始，不可超时`
        : `${minutesUntil}分钟后契约开始，不可超时`,
    );
  } else {
    showToast(sleepConflict ? '与早睡时间冲突，请调整时长' : '与契约时间冲突，请调整时长');
  }
  return true;
}

function isSleepPlanId(duoSessionId: string): boolean {
  if (duoSessionId.length === 0) {
    return false;
  }
  const sessions = ScheduledListStore.getAllSessions();
  for (let i = 0; i < sessions.length; i++) {
    if (sessions[i].session_id === duoSessionId) {
      return isSleepSchedule(sessions[i].schedule_json);
    }
  }
  return false;
}

export function validateScheduledPlanTime(
  startTime: string,
  endTime: string,
  repeatDays: number[],
  sessions: DuoSessionView[],
  excludeSessionId: string = '',
  selfIsSleep: boolean = false,
): string {
  const startMin = timeToMinutes(startTime);
  const endMin = timeToMinutes(endTime);
  if (startMin === endMin) {
    return '开始时间和结束时间不能相同';
  }
  if (getScheduledDurationMinutes(startMin, endMin) < MIN_SCHEDULED_PLAN_MINUTES) {
    return `时间间隔最少${MIN_SCHEDULED_PLAN_MINUTES}分钟`;
  }
  const hit = findOverlappingScheduledSession(startMin, endMin, repeatDays, sessions, excludeSessionId);
  if (hit) {
    return scheduledOverlapToastMessage(selfIsSleep, isSleepSchedule(hit.schedule_json));
  }
  return '';
}

export function toastIfScheduleOverlapsEnabled(session: DuoSessionView): boolean {
  if (session.enabled === false) {
    return false;
  }
  const repeatRaw = session.schedule_repeat && session.schedule_repeat.length > 0
    ? session.schedule_repeat
    : String(session.schedule_json?.['repeat'] ?? '1,2,3,4,5');
  const repeatDays = getScheduleRepeatDays(repeatRaw);
  const startMin = getScheduledSessionStartMin(session);
  const endMin = getScheduledSessionEndMin(session);
  const hit = findOverlappingScheduledSession(
    startMin,
    endMin,
    repeatDays,
    ScheduledListStore.getAllSessions(),
    session.session_id,
  );
  if (!hit) {
    return false;
  }
  const selfSleep = isSleepSchedule(session.schedule_json);
  const otherSleep = isSleepSchedule(hit.schedule_json);
  showToast(scheduledOverlapToastMessage(selfSleep, otherSleep));
  return true;
}

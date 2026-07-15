import { DuoSessionView, getScheduleRepeatDays, getScheduledSessionEndMin, getScheduledSessionStartMin, isInactiveScheduledSession } from '../models/DuoModel';
import { normalizePlanRepeatDays, normalizeTimeText } from '../models/PlanModel';

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

export function getScheduledDurationMinutes(startMin: number, endMin: number): number {
  if (endMin > startMin) {
    return endMin - startMin;
  }
  if (endMin < startMin) {
    return 24 * 60 - startMin + endMin;
  }
  return 0;
}

function hasSharedRepeatDay(left: number[], right: number[]): boolean {
  const normalizedLeft = normalizePlanRepeatDays(left);
  const normalizedRight = normalizePlanRepeatDays(right);
  for (let i = 0; i < normalizedLeft.length; i++) {
    if (normalizedRight.includes(normalizedLeft[i])) {
      return true;
    }
  }
  return false;
}

function isTimeRangeOverlap(startA: number, endA: number, startB: number, endB: number): boolean {
  return startA < endB && endA > startB;
}

function isActiveScheduledSession(session: DuoSessionView): boolean {
  if (session.type !== 'scheduled') {
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
    if (!hasSharedRepeatDay(normalizedRepeat, range.repeatDays)) {
      continue;
    }
    if (isTimeRangeOverlap(startMin, endMin, range.startMin, range.endMin)) {
      return session;
    }
  }
  return undefined;
}

export function validateScheduledPlanTime(
  startTime: string,
  endTime: string,
  repeatDays: number[],
  sessions: DuoSessionView[],
  excludeSessionId: string = ''
): string {
  const startMin = timeToMinutes(startTime);
  const endMin = timeToMinutes(endTime);
  if (startMin === endMin) {
    return '开始时间和结束时间不能相同';
  }
  if (getScheduledDurationMinutes(startMin, endMin) < 20) {
    return '时间间隔最少20分钟';
  }
  if (findOverlappingScheduledSession(startMin, endMin, repeatDays, sessions, excludeSessionId)) {
    return '与其他契约时间重叠';
  }
  return '';
}

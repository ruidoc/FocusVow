import { RestrictionMode } from './ActiveLockModel';

export type PlanFilterScope = 'today' | 'all';

export interface PlanDraft {
  name: string;
  startTime: string;
  endTime: string;
  repeatDays: number[];
  selectedTokens: string[];
  mode: RestrictionMode;
}

export interface FocusPlan {
  id: string;
  name: string;
  startTime: string;
  endTime: string;
  repeatDays: number[];
  selectedTokens: string[];
  selectedCount: number;
  mode: RestrictionMode;
  enabled: boolean;
  duoSessionId: string;
  createdAt: number;
  updatedAt: number;
}

export type PlanPresentationState = 'running' | 'upcoming' | 'enabled' | 'paused';

/** HarmonyOS repeat 标准：1=周一 … 7=周日 */
export const PLAN_REPEAT_DAY_OPTIONS: number[] = [1, 2, 3, 4, 5, 6, 7];

/** 新建定时契约默认全周，对齐 RN plans/add */
export const DEFAULT_PLAN_REPEAT_DAYS: number[] = [1, 2, 3, 4, 5, 6, 7];

const REPEAT_DAY_FULL_LABELS: string[] = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

export function getTodayRepeatDay(): number {
  const jsWeekday = new Date().getDay();
  return jsWeekday === 0 ? 7 : jsWeekday;
}

export function getRepeatDayShortLabel(day: number): string {
  switch (day) {
    case 1:
      return '一';
    case 2:
      return '二';
    case 3:
      return '三';
    case 4:
      return '四';
    case 5:
      return '五';
    case 6:
      return '六';
    case 7:
      return '日';
    default:
      return '?';
  }
}

function padTimeValue(value: number): string {
  return value.toString().padStart(2, '0');
}

function normalizeTimePart(rawPart: string, fallback: number, minValue: number, maxValue: number): number {
  const parsed = Number(rawPart);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(Math.max(Math.floor(parsed), minValue), maxValue);
}

export function normalizeTimeText(value: string, fallback: string): string {
  const safeValue = value.trim();
  if (safeValue.length === 0 || !safeValue.includes(':')) {
    return fallback;
  }

  const parts = safeValue.split(':');
  if (parts.length !== 2) {
    return fallback;
  }

  const hour = normalizeTimePart(parts[0], Number(fallback.split(':')[0]), 0, 23);
  const minute = normalizeTimePart(parts[1], Number(fallback.split(':')[1]), 0, 59);
  return `${padTimeValue(hour)}:${padTimeValue(minute)}`;
}

function normalizeRepeatDays(repeatDays: number[]): number[] {
  if (repeatDays.length === 0) {
    return [1, 2, 3, 4, 5];
  }

  const uniqueDays: number[] = [];
  repeatDays.forEach((day: number) => {
    const normalizedDay = day === 0 ? 7 : day;
    if (normalizedDay >= 1 && normalizedDay <= 7 && !uniqueDays.includes(normalizedDay)) {
      uniqueDays.push(normalizedDay);
    }
  });

  return uniqueDays.length > 0 ? uniqueDays.sort((left, right) => left - right) : [1, 2, 3, 4, 5];
}

export function normalizePlanRepeatDays(repeatDays: number[]): number[] {
  return normalizeRepeatDays(repeatDays);
}

export function createPlanFromDraft(draft: PlanDraft, nowAt: number): FocusPlan {
  return {
    id: `plan_${nowAt}`,
    name: draft.name.trim().length > 0 ? draft.name.trim() : '新的契约',
    startTime: normalizeTimeText(draft.startTime, '09:00'),
    endTime: normalizeTimeText(draft.endTime, '18:00'),
    repeatDays: normalizeRepeatDays(draft.repeatDays),
    selectedTokens: [...draft.selectedTokens],
    selectedCount: draft.selectedTokens.length,
    mode: draft.mode,
    enabled: true,
    duoSessionId: '',
    createdAt: nowAt,
    updatedAt: nowAt
  };
}

export function getPlanDurationMinutes(plan: FocusPlan): number {
  const startParts = plan.startTime.split(':');
  const endParts = plan.endTime.split(':');
  const startMinutes = Number(startParts[0]) * 60 + Number(startParts[1]);
  const endMinutes = Number(endParts[0]) * 60 + Number(endParts[1]);
  const directDuration = endMinutes - startMinutes;

  if (directDuration > 0) {
    return directDuration;
  }

  return 24 * 60 + directDuration;
}

function getTimeMinutes(timeText: string): number {
  const parts = timeText.split(':');
  return Number(parts[0]) * 60 + Number(parts[1]);
}

/** 若今天在重复日内，开始时间必须晚于当前时刻（跨日窗口凌晨/白天编辑除外） */
export function validateScheduledStartTime(
  startTime: string,
  repeatDays: number[],
  endTime?: string,
  nowAt: number = Date.now()
): string {
  const normalizedDays = normalizeRepeatDays(repeatDays);
  if (normalizedDays.length === 0) {
    return '请至少选择一天重复';
  }

  const todayWeekday = getTodayRepeatDay();
  if (!normalizedDays.includes(todayWeekday)) {
    return '';
  }

  const nowDate = new Date(nowAt);
  const nowMinutes = nowDate.getHours() * 60 + nowDate.getMinutes();
  const startMinutes = getTimeMinutes(normalizeTimeText(startTime, '09:00'));
  const endMinutes = endTime && endTime.length > 0
    ? getTimeMinutes(normalizeTimeText(endTime, '09:00'))
    : startMinutes;

  if (endMinutes < startMinutes) {
    if (nowMinutes < endMinutes || nowMinutes < startMinutes) {
      return '';
    }
  }

  if (startMinutes <= nowMinutes) {
    return '开始时间必须晚于当前时间';
  }

  return '';
}

function getPreviousWeekday(day: number): number {
  return day === 1 ? 7 : day - 1;
}

function getRelativeWeekday(todayWeekday: number, dayOffset: number): number {
  return ((todayWeekday - 1 + dayOffset) % 7) + 1;
}

interface PlanNextOccurrence {
  dayOffset: number;
  weekday: number;
  sortValue: number;
}

function getNextPlanOccurrence(plan: FocusPlan, nowAt: number): PlanNextOccurrence | undefined {
  if (!plan.enabled || plan.repeatDays.length === 0) {
    return undefined;
  }

  const nowDate = new Date(nowAt);
  const todayWeekday = getTodayRepeatDay();
  const nowMinutes = nowDate.getHours() * 60 + nowDate.getMinutes();
  const startMinutes = getTimeMinutes(plan.startTime);

  for (let offset = 0; offset < 7; offset += 1) {
    const weekday = getRelativeWeekday(todayWeekday, offset);
    if (!plan.repeatDays.includes(weekday)) {
      continue;
    }

    if (offset === 0 && startMinutes <= nowMinutes) {
      continue;
    }

    return {
      dayOffset: offset,
      weekday,
      sortValue: offset * 24 * 60 + startMinutes
    };
  }

  return undefined;
}

export function isPlanRunning(plan: FocusPlan, nowAt: number = Date.now()): boolean {
  if (!plan.enabled || plan.repeatDays.length === 0) {
    return false;
  }

  const nowDate = new Date(nowAt);
  const currentWeekday = getTodayRepeatDay();
  const currentMinutes = nowDate.getHours() * 60 + nowDate.getMinutes();
  const startMinutes = getTimeMinutes(plan.startTime);
  const endMinutes = getTimeMinutes(plan.endTime);

  if (endMinutes > startMinutes) {
    return plan.repeatDays.includes(currentWeekday) &&
      currentMinutes >= startMinutes &&
      currentMinutes < endMinutes;
  }

  if (currentMinutes >= startMinutes) {
    return plan.repeatDays.includes(currentWeekday);
  }

  return plan.repeatDays.includes(getPreviousWeekday(currentWeekday)) && currentMinutes < endMinutes;
}

export function getPlanPresentationState(plan: FocusPlan, nowAt: number = Date.now()): PlanPresentationState {
  if (!plan.enabled) {
    return 'paused';
  }
  if (isPlanRunning(plan, nowAt)) {
    return 'running';
  }
  if (getNextPlanOccurrence(plan, nowAt) !== undefined) {
    return 'upcoming';
  }
  return 'enabled';
}

export function getPlanPresentationLabel(plan: FocusPlan, nowAt: number = Date.now()): string {
  const state = getPlanPresentationState(plan, nowAt);
  if (state === 'running') {
    return '进行中';
  }
  if (state === 'upcoming') {
    return '即将开始';
  }
  if (state === 'paused') {
    return '已停用';
  }
  return '已启用';
}

export function getPlanNextStartText(plan: FocusPlan, nowAt: number = Date.now()): string {
  if (!plan.enabled) {
    return '当前不会自动生效';
  }
  if (isPlanRunning(plan, nowAt)) {
    return '当前契约正在生效';
  }

  const nextOccurrence = getNextPlanOccurrence(plan, nowAt);
  if (!nextOccurrence) {
    return '等待下一轮排期';
  }

  if (nextOccurrence.dayOffset === 0) {
    return `今天 ${plan.startTime} 开始`;
  }
  if (nextOccurrence.dayOffset === 1) {
    return `明天 ${plan.startTime} 开始`;
  }

  return `${REPEAT_DAY_FULL_LABELS[nextOccurrence.weekday]} ${plan.startTime} 开始`;
}

export function comparePlansForDisplay(left: FocusPlan, right: FocusPlan, nowAt: number = Date.now()): number {
  const statePriority = (plan: FocusPlan): number => {
    const state = getPlanPresentationState(plan, nowAt);
    if (state === 'running') {
      return 0;
    }
    if (state === 'upcoming') {
      return 1;
    }
    if (state === 'enabled') {
      return 2;
    }
    return 3;
  };

  const leftPriority = statePriority(left);
  const rightPriority = statePriority(right);
  if (leftPriority !== rightPriority) {
    return leftPriority - rightPriority;
  }

  const leftOccurrence = getNextPlanOccurrence(left, nowAt);
  const rightOccurrence = getNextPlanOccurrence(right, nowAt);
  if (leftOccurrence && rightOccurrence && leftOccurrence.sortValue !== rightOccurrence.sortValue) {
    return leftOccurrence.sortValue - rightOccurrence.sortValue;
  }

  return right.updatedAt - left.updatedAt;
}

export function updatePlanFromDraft(plan: FocusPlan, draft: PlanDraft, nowAt: number): FocusPlan {
  return {
    id: plan.id,
    name: draft.name.trim().length > 0 ? draft.name.trim() : plan.name,
    startTime: normalizeTimeText(draft.startTime, plan.startTime),
    endTime: normalizeTimeText(draft.endTime, plan.endTime),
    repeatDays: normalizeRepeatDays(draft.repeatDays),
    selectedTokens: [...draft.selectedTokens],
    selectedCount: draft.selectedTokens.length,
    mode: draft.mode,
    enabled: plan.enabled,
    duoSessionId: plan.duoSessionId,
    createdAt: plan.createdAt,
    updatedAt: nowAt
  };
}

export function upsertPlan(plans: FocusPlan[], targetPlan: FocusPlan): FocusPlan[] {
  const targetIndex = plans.findIndex((plan: FocusPlan) => plan.id === targetPlan.id);
  if (targetIndex < 0) {
    return [targetPlan, ...plans];
  }

  return plans.map((plan: FocusPlan) => plan.id === targetPlan.id ? targetPlan : plan);
}

export function removePlanById(plans: FocusPlan[], planId: string): FocusPlan[] {
  return plans.filter((plan: FocusPlan) => plan.id !== planId);
}

export function getPlanById(plans: FocusPlan[], planId: string): FocusPlan | undefined {
  return plans.find((plan: FocusPlan) => plan.id === planId);
}

export function filterPlansByScope(plans: FocusPlan[], scope: PlanFilterScope, todayWeekday: number): FocusPlan[] {
  if (scope === 'all') {
    return [...plans];
  }

  return plans.filter((plan: FocusPlan) => plan.repeatDays.includes(todayWeekday));
}

export function summarizeRepeatDays(repeatDays: number[]): string {
  const safeDays = normalizeRepeatDays(repeatDays);
  const weekdaySignature = '1,2,3,4,5';
  const weekendSignature = '6,7';
  const allSignature = '1,2,3,4,5,6,7';
  const currentSignature = safeDays.join(',');

  if (currentSignature === allSignature) {
    return '每天';
  }
  if (currentSignature === weekdaySignature) {
    return '工作日';
  }
  if (currentSignature === weekendSignature) {
    return '周末';
  }

  return safeDays.map((day: number) => REPEAT_DAY_FULL_LABELS[day]).join('、');
}

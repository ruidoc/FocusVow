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
  createdAt: number;
  updatedAt: number;
}

/** HarmonyOS repeat 标准：1=周一 … 7=周日 */
export const PLAN_REPEAT_DAY_OPTIONS: number[] = [1, 2, 3, 4, 5, 6, 7];

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

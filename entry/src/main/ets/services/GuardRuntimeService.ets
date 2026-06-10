import { common } from '@kit.AbilityKit';
import { FocusPlan } from '../models/PlanModel';
import { FocusRunStatus, FocusSource } from '../models/FocusSession';
import { FocusStore } from '../stores/FocusStore';
import { SettingsStore } from '../stores/SettingsStore';

interface PlanWindow {
  startAt: number;
  endAt: number;
}

function getPreviousWeekday(weekday: number): number {
  return weekday === 0 ? 6 : weekday - 1;
}

function getTimeParts(timeText: string): number[] | null {
  const parts = timeText.split(':');
  if (parts.length !== 2) {
    return null;
  }

  return [Number(parts[0]), Number(parts[1])];
}

function getMinutesOfDay(timeText: string): number {
  const parts = getTimeParts(timeText);
  if (!parts) {
    return -1;
  }

  return parts[0] * 60 + parts[1];
}

function isPlanActiveAt(plan: FocusPlan, now: Date): boolean {
  if (!plan.enabled || plan.selectedTokens.length === 0) {
    return false;
  }

  const currentWeekday = now.getDay();
  const previousWeekday = getPreviousWeekday(currentWeekday);
  const startMinutes = getMinutesOfDay(plan.startTime);
  const endMinutes = getMinutesOfDay(plan.endTime);
  if (startMinutes < 0 || endMinutes < 0) {
    return false;
  }

  const currentMinutes = now.getHours() * 60 + now.getMinutes();
  const repeatsToday = plan.repeatDays.includes(currentWeekday);
  const repeatsYesterday = plan.repeatDays.includes(previousWeekday);

  if (startMinutes === endMinutes) {
    return repeatsToday;
  }
  if (startMinutes < endMinutes) {
    return repeatsToday && currentMinutes >= startMinutes && currentMinutes < endMinutes;
  }
  if (repeatsToday && currentMinutes >= startMinutes) {
    return true;
  }

  return repeatsYesterday && currentMinutes < endMinutes;
}

function createDateFromPlanTime(baseDate: Date, timeText: string): Date {
  const result = new Date(baseDate.getTime());
  const parts = getTimeParts(timeText);
  const hour = parts ? parts[0] : 0;
  const minute = parts ? parts[1] : 0;
  result.setHours(hour, minute, 0, 0);
  return result;
}

function getPlanWindow(plan: FocusPlan, now: Date): PlanWindow {
  const todayStart = createDateFromPlanTime(now, plan.startTime);
  const todayEnd = createDateFromPlanTime(now, plan.endTime);

  if (todayStart.getTime() === todayEnd.getTime()) {
    const fullDayWindow: PlanWindow = {
      startAt: now.getTime(),
      endAt: now.getTime() + 24 * 60 * 60 * 1000
    };
    return fullDayWindow;
  }

  if (todayStart.getTime() < todayEnd.getTime()) {
    const sameDayWindow: PlanWindow = {
      startAt: todayStart.getTime(),
      endAt: todayEnd.getTime()
    };
    return sameDayWindow;
  }

  if (now.getTime() >= todayStart.getTime()) {
    const nextDayEnd = new Date(todayEnd.getTime());
    nextDayEnd.setDate(nextDayEnd.getDate() + 1);
    const crossDayWindow: PlanWindow = {
      startAt: todayStart.getTime(),
      endAt: nextDayEnd.getTime()
    };
    return crossDayWindow;
  }

  const previousDayStart = new Date(todayStart.getTime());
  previousDayStart.setDate(previousDayStart.getDate() - 1);
  const overnightWindow: PlanWindow = {
    startAt: previousDayStart.getTime(),
    endAt: todayEnd.getTime()
  };
  return overnightWindow;
}

function findActivePlan(plans: FocusPlan[], now: Date): FocusPlan | undefined {
  for (const plan of plans) {
    if (isPlanActiveAt(plan, now)) {
      return plan;
    }
  }

  return undefined;
}

export function syncGuardRuntimeToAppState(
  context: common.UIAbilityContext,
  plans: FocusPlan[]
): void {
  const currentSession = FocusStore.getCurrentSession();
  const settingsState = SettingsStore.getState();
  const hasRunningManualSession = currentSession.status === FocusRunStatus.Running &&
    (currentSession.source === FocusSource.Plan || currentSession.source === FocusSource.QuickStart);
  if (hasRunningManualSession) {
    return;
  }

  const now = new Date();
  const activePlan = findActivePlan(plans, now);
  if (!activePlan) {
    if (currentSession.source === FocusSource.GuardStrategy) {
      FocusStore.resetToIdle(context);
      if (settingsState.statusMessage !== '当前没有进行中的系统锁定') {
        SettingsStore.updateStatusMessage(context, '当前没有进行中的系统锁定');
      }
    }
    return;
  }

  const planWindow = getPlanWindow(activePlan, now);
  if (
    currentSession.source === FocusSource.GuardStrategy &&
    currentSession.planId === activePlan.id &&
    currentSession.startAt === planWindow.startAt &&
    currentSession.endAt === planWindow.endAt
  ) {
    if (settingsState.statusMessage !== `契约「${activePlan.name}」正在系统锁定中`) {
      SettingsStore.updateStatusMessage(context, `契约「${activePlan.name}」正在系统锁定中`);
    }
    return;
  }

  FocusStore.startSystemGuardSession(
    context,
    activePlan.selectedTokens,
    activePlan.id,
    activePlan.name,
    activePlan.mode,
    planWindow.startAt,
    planWindow.endAt
  );
  if (settingsState.statusMessage !== `契约「${activePlan.name}」正在系统锁定中`) {
    SettingsStore.updateStatusMessage(context, `契约「${activePlan.name}」正在系统锁定中`);
  }
}

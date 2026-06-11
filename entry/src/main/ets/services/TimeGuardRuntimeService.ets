import { common } from '@kit.AbilityKit';
import {
  FocusRunStatus,
  FocusSession,
  FocusSource,
  RestrictionMode
} from '../models/FocusSession';
import { FocusPlan } from '../models/PlanModel';
import { createDefaultSettingsState, SettingsState } from '../models/PermissionModel';
import {
  clearPersistedFocusSession,
  loadPersistedFocusSession,
  savePersistedFocusSession
} from './FocusPersistenceService';
import { loadPersistedPlans } from './PlanPersistenceService';
import { loadPersistedSettings, savePersistedSettings } from './SettingsPersistenceService';

interface PlanWindow {
  startAt: number;
  endAt: number;
}

function isPlanStrategyName(strategyName: string): boolean {
  return strategyName.startsWith('plan_');
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

function getPlanWindow(plan: FocusPlan, now: Date): PlanWindow {
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

function updateSettingsStatusMessage(context: common.Context, statusMessage: string): void {
  const currentSettings = loadPersistedSettings(context) ?? createDefaultSettingsState();
  const nextSettings: SettingsState = {
    hasAuthorized: currentSettings.hasAuthorized,
    selectedTokens: [...currentSettings.selectedTokens],
    selectedAppCount: currentSettings.selectedAppCount,
    statusMessage
  };
  savePersistedSettings(context, nextSettings);
}

function findPlanByStrategyName(context: common.Context, strategyName: string): FocusPlan | null {
  if (!isPlanStrategyName(strategyName)) {
    return null;
  }

  const plans = loadPersistedPlans(context);
  for (const plan of plans) {
    if (plan.id === strategyName) {
      return plan;
    }
  }

  return null;
}

function createPlanFocusSession(plan: FocusPlan, planWindow: PlanWindow): FocusSession {
  const durationMinutes = Math.max(1, Math.ceil((planWindow.endAt - planWindow.startAt) / (60 * 1000)));
  return {
    selectedTokens: [...plan.selectedTokens],
    selectedCount: plan.selectedTokens.length,
    durationMinutes,
    startAt: planWindow.startAt,
    endAt: planWindow.endAt,
    status: FocusRunStatus.Running,
    source: FocusSource.GuardStrategy,
    planId: plan.id,
    planName: plan.name,
    mode: plan.mode as RestrictionMode
  };
}

export function handlePlanStrategyStart(context: common.Context, strategyName: string): void {
  const plan = findPlanByStrategyName(context, strategyName);
  if (!plan || !plan.enabled || plan.selectedTokens.length === 0) {
    return;
  }

  const currentSession = loadPersistedFocusSession(context);
  if (currentSession && currentSession.status === FocusRunStatus.Running && currentSession.source !== FocusSource.GuardStrategy) {
    updateSettingsStatusMessage(context, `契约「${plan.name}」正在系统锁定中`);
    return;
  }

  savePersistedFocusSession(context, createPlanFocusSession(plan, getPlanWindow(plan, new Date())));
  updateSettingsStatusMessage(context, `契约「${plan.name}」正在系统锁定中`);
}

export function handlePlanStrategyStop(context: common.Context, strategyName: string): void {
  const currentSession = loadPersistedFocusSession(context);
  if (
    currentSession &&
    currentSession.status === FocusRunStatus.Running &&
    currentSession.source === FocusSource.GuardStrategy &&
    currentSession.planId === strategyName
  ) {
    clearPersistedFocusSession(context);
  }

  updateSettingsStatusMessage(context, '当前没有进行中的系统锁定');
}

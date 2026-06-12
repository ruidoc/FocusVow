import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  ActiveLockState,
  createCovenantLockState,
  createIdleLockState,
  RestrictionMode
} from '../models/ActiveLockModel';
import { FocusPlan } from '../models/PlanModel';
import { createDefaultSettingsState, SettingsState } from '../models/PermissionModel';
import {
  loadPersistedActiveLockState,
  savePersistedActiveLockState
} from './ActiveLockPersistenceService';
import { restartCycleGuardIfEnabled } from './CycleGuardService';
import { getPlanWindow } from './PlanWindowService';
import { loadPersistedPlans } from './PlanPersistenceService';
import { loadPersistedSettings, savePersistedSettings } from './SettingsPersistenceService';

const DOMAIN: number = 0x0000;
const TAG: string = 'PlanGuardRuntime';

function isPlanStrategyName(strategyName: string): boolean {
  return strategyName.startsWith('plan_');
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

function buildCovenantLockFromPlan(plan: FocusPlan): ActiveLockState {
  const planWindow = getPlanWindow(plan, new Date());
  return createCovenantLockState(
    plan.id,
    plan.name,
    plan.selectedTokens,
    plan.mode as RestrictionMode,
    planWindow.startAt,
    planWindow.endAt
  );
}

function buildFallbackCovenantLock(strategyName: string): ActiveLockState {
  const now = Date.now();
  return createCovenantLockState(
    strategyName,
    '契约',
    [],
    'shield',
    now,
    now + 60 * 60 * 1000
  );
}

function isCovenantLockStillActive(lock: ActiveLockState, strategyName: string, nowMs: number): boolean {
  return lock.kind === 'covenant' &&
    lock.planId === strategyName &&
    lock.endAt > nowMs;
}

function saveCovenantLockState(
  context: common.Context,
  nextState: ActiveLockState,
  statusMessage: string
): boolean {
  const saved = savePersistedActiveLockState(context, nextState);
  hilog.info(
    DOMAIN,
    TAG,
    'onStart lock saved=%{public}s planId=%{public}s kind=%{public}s',
    String(saved),
    nextState.planId,
    nextState.kind
  );
  updateSettingsStatusMessage(context, statusMessage);
  return saved;
}

export function handlePlanStrategyStart(context: common.Context, strategyName: string): void {
  if (!isPlanStrategyName(strategyName)) {
    return;
  }

  const plans = loadPersistedPlans(context);
  hilog.info(DOMAIN, TAG, 'onStart %{public}s persistedPlans=%{public}d', strategyName, plans.length);

  const plan = findPlanByStrategyName(context, strategyName);
  if (plan) {
    const nextState = buildCovenantLockFromPlan(plan);
    saveCovenantLockState(
      context,
      nextState,
      `契约「${plan.name}」正在系统锁定中`
    );
    return;
  }

  const fallbackState = buildFallbackCovenantLock(strategyName);
  saveCovenantLockState(
    context,
    fallbackState,
    '契约正在系统锁定中'
  );
  hilog.warn(DOMAIN, TAG, 'onStart plan not found, wrote fallback lock %{public}s', strategyName);
}

export async function handlePlanStrategyStop(context: common.Context, strategyName: string): Promise<void> {
  const nowMs = Date.now();
  const currentLock = loadPersistedActiveLockState(context) ?? createIdleLockState();

  if (isCovenantLockStillActive(currentLock, strategyName, nowMs)) {
    hilog.warn(
      DOMAIN,
      TAG,
      'onStop ignored: covenant lock still active until %{public}d now=%{public}d',
      currentLock.endAt,
      nowMs
    );
    return;
  }

  if (currentLock.kind === 'covenant' && currentLock.planId === strategyName) {
    savePersistedActiveLockState(context, createIdleLockState());
    hilog.info(DOMAIN, TAG, 'onStop cleared covenant lock %{public}s', strategyName);
  }

  await restartCycleGuardIfEnabled(context);
  updateSettingsStatusMessage(context, '当前没有进行中的系统锁定');
}

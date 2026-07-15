import { common } from '@kit.AbilityKit';
import {
  ActiveLockState,
  isTimedLockFinished,
  resolveDuoSessionIdFromLock
} from '../models/ActiveLockModel';
import { syncScheduledCovenantTerminal } from './ActiveLockLifecycleService';
import { stopPlanGuardStrategyForWindow } from './ScreenTimeService';
import {
  clearScheduledActivationTracking,
  markScheduledListStale,
  reconcileScheduledCovenantActivation,
  reconcileStaleScheduledWindows
} from './ScheduledCovenantService';
import { restartCycleGuardIfEnabled } from './CycleGuardService';
import { queueHonorCertificate } from './CertificatePendingService';
import { FocusSyncService } from './FocusSyncService';
import { LockStore } from '../stores/LockStore';
import { ScheduledListStore } from '../stores/ScheduledListStore';
import { refreshStats } from '../stores/StatsStore';
import { SettingsStore } from '../stores/SettingsStore';
import { UserStore } from '../stores/UserStore';

let covenantCompletionInFlight: boolean = false;

async function releaseCovenantGuard(state: ActiveLockState): Promise<boolean> {
  const stopResult = await stopPlanGuardStrategyForWindow(state.planId);
  return stopResult.ok;
}

export async function reconcileCovenantNaturalCompletion(
  context: common.UIAbilityContext
): Promise<boolean> {
  const lock = LockStore.getState();
  if (lock.kind !== 'covenant' || lock.endAt <= 0) {
    return false;
  }
  if (!isTimedLockFinished(lock, Date.now())) {
    return false;
  }
  if (covenantCompletionInFlight) {
    return false;
  }

  covenantCompletionInFlight = true;
  try {
    const endedAt = Date.now();
    await syncScheduledCovenantTerminal(context, lock, 'SUCCESS');
    await releaseCovenantGuard(lock);
    const sessionId = resolveDuoSessionIdFromLock(lock);
    queueHonorCertificate(lock, endedAt);
    LockStore.clear(context);
    markScheduledListStale(context);
    clearScheduledActivationTracking(sessionId);
    await restartCycleGuardIfEnabled(context);
    SettingsStore.updateStatusMessage(context, '契约窗口已结束，履约完成');
    if (UserStore.isLoggedIn()) {
      await FocusSyncService.flushPending(context);
    }
    refreshStats();
    return true;
  } finally {
    covenantCompletionInFlight = false;
  }
}

export async function reconcileLockLifecycle(context: common.UIAbilityContext): Promise<void> {
  await reconcileScheduledCovenantActivation(context);
  await reconcileCovenantNaturalCompletion(context);
  if (UserStore.isLoggedIn()) {
    await FocusSyncService.flushPending(context);
    const cached = ScheduledListStore.getAllSessions();
    if (cached.length > 0) {
      const reconciled = await reconcileStaleScheduledWindows(cached, context);
      ScheduledListStore.setAllSessions(reconciled);
    }
  }
}

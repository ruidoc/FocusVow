import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  ActiveLockState,
  createCovenantLockState,
  createIdleLockState,
  QuickFocusParticipationMode,
  RestrictionMode,
  resolveDuoSessionIdFromLock
} from '../models/ActiveLockModel';
import { createDefaultSettingsState, SettingsState } from '../models/PermissionModel';
import {
  loadPersistedActiveLockState,
  savePersistedActiveLockState
} from './ActiveLockPersistenceService';
import { DuoApiService } from './DuoApiService';
import { restartCycleGuardIfEnabled } from './CycleGuardService';
import { ScheduledListStore } from '../stores/ScheduledListStore';
import { getPlanWindow } from './PlanWindowService';
import { FocusPlan } from '../models/PlanModel';
import { DuoSessionView, isScheduledTornToday, resolveDuoCounterpartName } from '../models/DuoModel';
import { loadPersistedPlans } from './PlanPersistenceService';
import { loadPersistedSettings, savePersistedSettings } from './SettingsPersistenceService';
import {
  loadScheduledGuardSnapshot,
  ScheduledGuardSnapshot
} from './ScheduledSessionPersistenceService';
import { activateDelayedOnceIfNeeded } from './PendingQuickStartService';
import { completeOnceQuickFocusFromGuardStop } from './ActiveLockLifecycleService';
import { isOnceStrategyName, sessionIdFromGuardName } from './ScreenTimeService';
import { loadExitPlanIds } from './ExitPlanIdsService';

const DOMAIN: number = 0x0000;
const TAG: string = 'PlanGuardRuntime';

interface ScheduledActivationMeta {
  duoSessionId: string;
  recordId: string;
  participationMode: QuickFocusParticipationMode;
  partnerNickname: string;
}

function createEmptyActivationMeta(): ScheduledActivationMeta {
  const empty: ScheduledActivationMeta = {
    duoSessionId: '',
    recordId: '',
    participationMode: '',
    partnerNickname: ''
  };
  return empty;
}

function buildActivationMetaFromSession(session: DuoSessionView): ScheduledActivationMeta {
  const participationMode: QuickFocusParticipationMode =
    session.participation_mode === 'duo' ? 'duo' : 'solo';
  const meta: ScheduledActivationMeta = {
    duoSessionId: session.session_id,
    recordId: session.my_record_id || session.record_id || '',
    participationMode,
    partnerNickname: participationMode === 'duo' ? resolveDuoCounterpartName(session) : ''
  };
  return meta;
}

async function resolveScheduledActivationMeta(
  context: common.Context,
  sessionId: string
): Promise<ScheduledActivationMeta> {
  if (sessionId.length === 0) {
    return createEmptyActivationMeta();
  }

  const response = await DuoApiService.activateScheduledSession(sessionId, context);
  const session = DuoApiService.parseSession(response);
  if (!session) {
    hilog.warn(
      DOMAIN,
      TAG,
      'activate scheduled failed session=%{public}s message=%{public}s',
      sessionId,
      response.message ?? 'unknown'
    );
    return createEmptyActivationMeta();
  }

  return buildActivationMetaFromSession(session);
}

function isPlanStrategyName(strategyName: string): boolean {
  return strategyName.startsWith('plan_');
}

function isSessionStrategyName(strategyName: string): boolean {
  return strategyName.startsWith('session_');
}

function sessionIdFromStrategy(strategyName: string): string {
  return sessionIdFromGuardName(strategyName);
}

function lockMatchesStrategy(lock: ActiveLockState, strategyName: string): boolean {
  if (lock.kind !== 'covenant') {
    return false;
  }
  if (lock.planId === strategyName || lock.strategyName === strategyName) {
    return true;
  }
  if (isSessionStrategyName(strategyName)) {
    const sessionId = sessionIdFromStrategy(strategyName);
    return lock.duoSessionId === sessionId ||
      lock.planId === `session_${sessionId}` ||
      resolveDuoSessionIdFromLock(lock) === sessionId;
  }
  return false;
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

function buildCovenantLockFromSnapshot(
  snapshot: ScheduledGuardSnapshot,
  activationMeta: ScheduledActivationMeta
): ActiveLockState {
  const pseudoPlan: FocusPlan = {
    id: `session_${snapshot.sessionId}`,
    name: snapshot.title,
    startTime: snapshot.startTime,
    endTime: snapshot.endTime,
    repeatDays: snapshot.repeatDays,
    selectedTokens: snapshot.selectedTokens,
    selectedCount: snapshot.selectedTokens.length,
    mode: snapshot.mode,
    enabled: true,
    duoSessionId: snapshot.sessionId,
    createdAt: 0,
    updatedAt: 0
  };
  const planWindow = getPlanWindow(pseudoPlan, new Date());
  return createCovenantLockState(
    pseudoPlan.id,
    pseudoPlan.name,
    pseudoPlan.selectedTokens,
    pseudoPlan.mode as RestrictionMode,
    planWindow.startAt,
    planWindow.endAt,
    Date.now(),
    activationMeta.duoSessionId || snapshot.sessionId,
    activationMeta.recordId,
    activationMeta.participationMode,
    activationMeta.partnerNickname
  );
}

function buildCovenantLockFromPlan(
  plan: FocusPlan,
  activationMeta: ScheduledActivationMeta
): ActiveLockState {
  const planWindow = getPlanWindow(plan, new Date());
  return createCovenantLockState(
    plan.id,
    plan.name,
    plan.selectedTokens,
    plan.mode as RestrictionMode,
    planWindow.startAt,
    planWindow.endAt,
    Date.now(),
    activationMeta.duoSessionId || plan.duoSessionId,
    activationMeta.recordId,
    activationMeta.participationMode,
    activationMeta.partnerNickname
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
  return lockMatchesStrategy(lock, strategyName) && lock.endAt > nowMs;
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
    'onStart lock saved=%{public}s planId=%{public}s kind=%{public}s duo=%{public}s',
    String(saved),
    nextState.planId,
    nextState.kind,
    nextState.participationMode
  );
  updateSettingsStatusMessage(context, statusMessage);
  return saved;
}

function buildScheduledLockStatusMessage(
  title: string,
  participationMode: QuickFocusParticipationMode
): string {
  const duoHint = participationMode === 'duo' ? '（搭子互督）' : '';
  return `契约「${title}」正在系统锁定中${duoHint}`;
}

async function finalizeScheduledCovenantStart(
  context: common.Context,
  sessionId: string,
  snapshot: ScheduledGuardSnapshot,
  initialState: ActiveLockState
): Promise<void> {
  ScheduledListStore.markNeedsRefreshPersisted(context);
  const activationMeta = await resolveScheduledActivationMeta(context, sessionId);
  if (activationMeta.duoSessionId.length === 0) {
    hilog.warn(DOMAIN, TAG, 'activate scheduled failed session=%{public}s', sessionId);
    return;
  }

  const enrichedState = buildCovenantLockFromSnapshot(snapshot, activationMeta);
  saveCovenantLockState(
    context,
    enrichedState,
    buildScheduledLockStatusMessage(snapshot.title, activationMeta.participationMode)
  );
  if (initialState.recordId.length === 0 && enrichedState.recordId.length > 0) {
    hilog.info(DOMAIN, TAG, 'scheduled activate enriched recordId=%{public}s', enrichedState.recordId);
  }
}

export async function handlePlanStrategyStart(context: common.Context, strategyName: string): Promise<void> {
  if (await activateDelayedOnceIfNeeded(context, strategyName)) {
    hilog.info(DOMAIN, TAG, 'onStart delayed once %{public}s', strategyName);
    return;
  }

  if (isSessionStrategyName(strategyName)) {
    const sessionId = sessionIdFromStrategy(strategyName);
    const currentLock = loadPersistedActiveLockState(context) ?? createIdleLockState();
    if (isCovenantLockStillActive(currentLock, strategyName, Date.now())) {
      hilog.info(DOMAIN, TAG, 'onStart skipped already locking %{public}s', strategyName);
      return;
    }
    if (isScheduledTornToday(sessionId, loadExitPlanIds(context))) {
      hilog.info(DOMAIN, TAG, 'onStart skipped torn today %{public}s', strategyName);
      return;
    }
    if (strategyName.endsWith('_P2')) {
      const yesterday = Date.now() - 24 * 60 * 60 * 1000;
      if (isScheduledTornToday(sessionId, loadExitPlanIds(context), yesterday)) {
        hilog.info(DOMAIN, TAG, 'onStart skipped torn yesterday %{public}s', strategyName);
        return;
      }
    }
    const snapshot = loadScheduledGuardSnapshot(context, sessionId);
    if (!snapshot) {
      hilog.warn(DOMAIN, TAG, 'onStart missing snapshot %{public}s', strategyName);
      return;
    }

    const initialState = buildCovenantLockFromSnapshot(snapshot, createEmptyActivationMeta());
    saveCovenantLockState(
      context,
      initialState,
      buildScheduledLockStatusMessage(snapshot.title, '')
    );
    await finalizeScheduledCovenantStart(context, sessionId, snapshot, initialState);
    return;
  }

  if (!isPlanStrategyName(strategyName)) {
    return;
  }

  const plans = loadPersistedPlans(context);
  hilog.info(DOMAIN, TAG, 'onStart %{public}s persistedPlans=%{public}d', strategyName, plans.length);

  const plan = findPlanByStrategyName(context, strategyName);
  if (plan) {
    const initialState = buildCovenantLockFromPlan(plan, createEmptyActivationMeta());
    saveCovenantLockState(
      context,
      initialState,
      `契约「${plan.name}」正在系统锁定中`
    );
    if (plan.duoSessionId.length > 0) {
      const snapshot = loadScheduledGuardSnapshot(context, plan.duoSessionId);
      if (snapshot) {
        await finalizeScheduledCovenantStart(context, plan.duoSessionId, snapshot, initialState);
      } else {
        ScheduledListStore.markNeedsRefreshPersisted(context);
        const activationMeta = await resolveScheduledActivationMeta(context, plan.duoSessionId);
        if (activationMeta.duoSessionId.length > 0) {
          const enrichedState = buildCovenantLockFromPlan(plan, activationMeta);
          saveCovenantLockState(context, enrichedState, `契约「${plan.name}」正在系统锁定中`);
        }
      }
    }
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

  if (isOnceStrategyName(strategyName)) {
    if (currentLock.kind === 'quick_focus' && currentLock.planId === strategyName) {
      // 对齐 RN：原生到点停锁，不依赖 App 打开
      await completeOnceQuickFocusFromGuardStop(context, currentLock);
      updateSettingsStatusMessage(context, '当前没有进行中的系统锁定');
      hilog.info(DOMAIN, TAG, 'onStop completed once quick focus %{public}s', strategyName);
    } else {
      savePersistedActiveLockState(context, createIdleLockState());
      updateSettingsStatusMessage(context, '当前没有进行中的系统锁定');
    }
    return;
  }

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

  // 跨日 P1 在 23:59 结束只是分段，整段窗口由 P2/lock.endAt 收尾
  if (isSessionStrategyName(strategyName) && strategyName.endsWith('_P1')) {
    hilog.info(DOMAIN, TAG, 'onStop ignored cross-day P1 segment %{public}s', strategyName);
    return;
  }

  if (isSessionStrategyName(strategyName)) {
    const sessionId = sessionIdFromStrategy(strategyName);
    await DuoApiService.completeScheduledWindow(sessionId, context);
  } else {
    const plan = findPlanByStrategyName(context, strategyName);
    if (plan?.duoSessionId && plan.duoSessionId.length > 0) {
      await DuoApiService.completeScheduledWindow(plan.duoSessionId, context);
    }
  }

  if (lockMatchesStrategy(currentLock, strategyName)) {
    savePersistedActiveLockState(context, createIdleLockState());
    ScheduledListStore.markNeedsRefreshPersisted(context);
    hilog.info(DOMAIN, TAG, 'onStop cleared covenant lock %{public}s', strategyName);
  }

  await restartCycleGuardIfEnabled(context);
  updateSettingsStatusMessage(context, '当前没有进行中的系统锁定');
}

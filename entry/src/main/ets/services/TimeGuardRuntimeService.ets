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
import { publishFocusBoundaryNotice } from './DuoBgSyncService';
import { completeOnceQuickFocusFromGuardStop } from './ActiveLockLifecycleService';
import { loadExitPlanIds } from './ExitPlanIdsService';
import {
  GuardWindowEvent,
  removeGuardWindowOccurrence,
  removeGuardWindowStart,
  scheduledOccurrenceId,
  upsertGuardWindowEvent,
} from './GuardWindowEventService';
import { isOnceStrategyName, sessionIdFromGuardName } from './ScreenTimeService';

function noticeMinutes(startedAt: number, endAt: number): number {
  if (endAt > startedAt) {
    return Math.max(1, Math.round((endAt - startedAt) / 60000));
  }
  return 1;
}

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

function rememberScheduledStart(
  context: common.Context,
  sessionId: string,
  state: ActiveLockState
): void {
  const durationMin = Math.max(1, Math.round((state.endAt - state.startedAt) / 60000));
  const event: GuardWindowEvent = {
    occurrence_id: scheduledOccurrenceId(sessionId, state.startedAt),
    session_id: sessionId,
    plan_id: state.planId,
    kind: 'start',
    result: '',
    fail_reason: '',
    started_at: state.startedAt,
    ended_at: 0,
    title: state.title,
    duration_min: durationMin,
    timer_mode: state.timerMode.length > 0 ? state.timerMode : 'countdown',
    mode: state.mode,
  };
  upsertGuardWindowEvent(context, event);
}

function rememberScheduledStop(
  context: common.Context,
  sessionId: string,
  state: ActiveLockState,
  endedAt: number,
  result: string
): void {
  const durationMin = Math.max(1, Math.round((state.endAt - state.startedAt) / 60000));
  const event: GuardWindowEvent = {
    occurrence_id: scheduledOccurrenceId(sessionId, state.startedAt),
    session_id: sessionId,
    plan_id: state.planId,
    kind: 'stop',
    result: result,
    fail_reason: result === 'VIOLATION' ? 'tear' : '',
    started_at: state.startedAt,
    ended_at: endedAt,
    title: state.title,
    duration_min: durationMin,
    timer_mode: state.timerMode.length > 0 ? state.timerMode : 'countdown',
    mode: state.mode,
  };
  upsertGuardWindowEvent(context, event);
}

async function finalizeScheduledCovenantStart(
  context: common.Context,
  sessionId: string,
  snapshot: ScheduledGuardSnapshot,
  initialState: ActiveLockState
): Promise<void> {
  ScheduledListStore.markNeedsRefreshPersisted(context);
  rememberScheduledStart(context, sessionId, initialState);
  const activationMeta = await resolveScheduledActivationMeta(context, sessionId);
  if (activationMeta.duoSessionId.length === 0) {
    hilog.warn(DOMAIN, TAG, 'activate scheduled failed session=%{public}s', sessionId);
    return;
  }
  removeGuardWindowStart(
    context,
    scheduledOccurrenceId(sessionId, initialState.startedAt)
  );

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
    void publishFocusBoundaryNotice(
      context,
      'start',
      snapshot.title,
      noticeMinutes(initialState.startedAt, initialState.endAt),
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
    void publishFocusBoundaryNotice(
      context,
      'start',
      plan.name,
      noticeMinutes(initialState.startedAt, initialState.endAt),
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

async function settleScheduledStop(
  context: common.Context,
  sessionId: string,
  lock: ActiveLockState,
  result: string
): Promise<void> {
  let state = lock;
  const lockSession = resolveDuoSessionIdFromLock(lock);
  if (lock.kind !== 'covenant' || lockSession !== sessionId || lock.startedAt <= 0) {
    const snapshot = loadScheduledGuardSnapshot(context, sessionId);
    if (!snapshot) {
      return;
    }
    state = buildCovenantLockFromSnapshot(snapshot, createEmptyActivationMeta());
  }
  const endedAt = Date.now();
  rememberScheduledStop(context, sessionId, state, endedAt, result);
  const occurrenceId = scheduledOccurrenceId(sessionId, state.startedAt);
  const response = await DuoApiService.completeScheduledWindow(
    sessionId,
    context,
    occurrenceId,
    state.startedAt,
    endedAt,
    result,
    result === 'VIOLATION' ? 'tear' : ''
  );
  if (response.statusCode === 200) {
    removeGuardWindowOccurrence(context, occurrenceId);
  }
  if (result === 'SUCCESS') {
    void publishFocusBoundaryNotice(
      context,
      'end',
      state.title,
      noticeMinutes(state.startedAt, state.endAt > 0 ? state.endAt : endedAt),
    );
  }
}

function isPlanTornToday(context: common.Context, planId: string): boolean {
  if (planId.length === 0) {
    return false;
  }
  const exits = loadExitPlanIds(context);
  const date = new Date();
  const year = date.getFullYear();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  const entry = `${year}-${month}-${day}:${planId}`;
  return exits.includes(entry);
}

export async function handlePlanStrategyStop(context: common.Context, strategyName: string): Promise<void> {
  const nowMs = Date.now();
  const currentLock = loadPersistedActiveLockState(context) ?? createIdleLockState();
  const exitPlanIds = loadExitPlanIds(context);

  if (isOnceStrategyName(strategyName)) {
    if (isPlanTornToday(context, strategyName)) {
      savePersistedActiveLockState(context, createIdleLockState());
      updateSettingsStatusMessage(context, '当前没有进行中的系统锁定');
      hilog.info(DOMAIN, TAG, 'onStop skipped once tear %{public}s', strategyName);
      return;
    }
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
    if (!isScheduledTornToday(sessionId, exitPlanIds, nowMs)) {
      await settleScheduledStop(context, sessionId, currentLock, 'SUCCESS');
    } else {
      hilog.info(DOMAIN, TAG, 'onStop skipped scheduled tear %{public}s', strategyName);
    }
  } else {
    const plan = findPlanByStrategyName(context, strategyName);
    if (plan?.duoSessionId && plan.duoSessionId.length > 0) {
      if (!isScheduledTornToday(plan.duoSessionId, exitPlanIds, nowMs)) {
        await settleScheduledStop(context, plan.duoSessionId, currentLock, 'SUCCESS');
      } else {
        hilog.info(DOMAIN, TAG, 'onStop skipped plan scheduled tear %{public}s', strategyName);
      }
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

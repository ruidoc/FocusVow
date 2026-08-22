import { common } from '@kit.AbilityKit';
import { ActiveLockState, resolveDuoSessionIdFromLock } from '../models/ActiveLockModel';
import {
  DuoSessionView,
  applyTornTodayToRepeatDays,
  getScheduleRepeatDays,
  resolveDuoCounterpartName,
  getSessionApps,
  shouldCompleteStaleScheduledWindow
} from '../models/DuoModel';
import { ScheduledListStore } from '../stores/ScheduledListStore';
import { LockStore } from '../stores/LockStore';
import { DuoApiService } from './DuoApiService';
import { deactivateCycleGuard } from './CycleGuardService';
import {
  GuardResult,
  pruneSessionGuardStrategies,
  releaseScreenRestriction,
  removeAllGuardStrategies,
  removeScheduledSessionGuardStrategy,
  stopPlanGuardStrategyForWindow,
  syncScheduledSessionGuardStrategy
} from './ScreenTimeService';
import {
  clearAllScheduledGuardPersistence,
  loadScheduledGuardIssueIndex,
  loadScheduledGuardSnapshot,
  loadScheduledGuardSyncIssue,
  removeScheduledGuardSyncIssue,
  removeScheduledGuardSnapshot,
  saveScheduledGuardSnapshot,
  saveScheduledGuardSyncIssue,
  ScheduledGuardSnapshot,
  ScheduledGuardSyncIssue
} from './ScheduledSessionPersistenceService';
import { loadExitPlanIds } from './ExitPlanIdsService';
import { readStoredString, writeStoredString } from './PreferencesService';
import { StoreKeys } from '../stores/StoreKeys';

const NEEDS_SCHEDULED_GUARD_SYNC_KEY: string = 'needs_scheduled_guard_sync';
const AWAITING_SCHEDULED_GUARD_SYNC_CHECK_KEY: string = 'awaiting_scheduled_guard_sync_check';

function readBoolPref(context: common.Context, key: string): boolean {
  return readStoredString(context, key, '') === 'true';
}

function writeBoolPref(context: common.Context, key: string, value: boolean): void {
  writeStoredString(context, key, value ? 'true' : 'false');
}

/** 登录后标记：下次拉取定时列表时决定是否提示同步本机策略 */
export function markAwaitingScheduledGuardSyncCheck(context: common.Context): void {
  writeBoolPref(context, AWAITING_SCHEDULED_GUARD_SYNC_CHECK_KEY, true);
  AppStorage.setOrCreate(StoreKeys.AwaitingScheduledGuardSyncCheck, true);
}

export function needsScheduledGuardSync(context: common.Context): boolean {
  return readBoolPref(context, NEEDS_SCHEDULED_GUARD_SYNC_KEY);
}

export function clearScheduledGuardSyncFlags(context: common.Context): void {
  writeBoolPref(context, NEEDS_SCHEDULED_GUARD_SYNC_KEY, false);
  writeBoolPref(context, AWAITING_SCHEDULED_GUARD_SYNC_CHECK_KEY, false);
  AppStorage.setOrCreate(StoreKeys.NeedsScheduledGuardSync, false);
  AppStorage.setOrCreate(StoreKeys.AwaitingScheduledGuardSyncCheck, false);
}

/** 对齐 RN scheduled-list.loadAll：有待同步定时契约时任务 Tab 默认切到「定时任务」 */
export function applyScheduledGuardSyncCheckAfterListLoad(
  context: common.Context,
  itemCount: number
): void {
  if (!readBoolPref(context, AWAITING_SCHEDULED_GUARD_SYNC_CHECK_KEY)) {
    return;
  }
  writeBoolPref(context, AWAITING_SCHEDULED_GUARD_SYNC_CHECK_KEY, false);
  writeBoolPref(context, NEEDS_SCHEDULED_GUARD_SYNC_KEY, itemCount > 0);
  AppStorage.setOrCreate(StoreKeys.AwaitingScheduledGuardSyncCheck, false);
  AppStorage.setOrCreate(StoreKeys.NeedsScheduledGuardSync, itemCount > 0);
}

export function consumeOpenQuickTaskTabOnce(): boolean {
  if (AppStorage.get<boolean>(StoreKeys.OpenQuickTaskTabOnce) !== true) {
    return false;
  }
  AppStorage.setOrCreate(StoreKeys.OpenQuickTaskTabOnce, false);
  return true;
}

export function scheduledSessionStrategyName(sessionId: string): string {
  return `session_${sessionId}`;
}

export const LOCAL_GUARD_SYNC_WARNING_PREFIX: string = '本机屏时策略未同步';

const TERMINAL_SCHEDULED_STATUSES: Set<string> = new Set([
  'cancelled',
  'completed',
  'failed',
  'breached',
  'expired'
]);

export function isScheduledGuardEligible(session: DuoSessionView): boolean {
  if (session.type !== 'scheduled') {
    return false;
  }
  if (TERMINAL_SCHEDULED_STATUSES.has(session.status)) {
    return false;
  }
  return session.status === 'scheduled' || session.status === 'active';
}

function normalizeGuardIssueMessage(message: string): string {
  return message.length > 0 ? message : `${LOCAL_GUARD_SYNC_WARNING_PREFIX}，请稍后重试`;
}

export function buildGuardSnapshotFromSession(
  session: DuoSessionView,
  context?: common.Context
): ScheduledGuardSnapshot | null {
  if (session.session_id.length === 0) {
    return null;
  }
  const apps = getSessionApps(session);
  const startTime = session.schedule_start && session.schedule_start.length > 0
    ? session.schedule_start
    : String(session.schedule_json?.['start'] ?? '09:00');
  const endTime = session.schedule_end && session.schedule_end.length > 0
    ? session.schedule_end
    : String(session.schedule_json?.['end'] ?? '18:00');
  const repeatRaw = session.schedule_repeat && session.schedule_repeat.length > 0
    ? session.schedule_repeat
    : String(session.schedule_json?.['repeat'] ?? '1,2,3,4,5');
  let repeatDays = getScheduleRepeatDays(repeatRaw);
  if (context) {
    repeatDays = applyTornTodayToRepeatDays(
      session.session_id,
      repeatDays,
      loadExitPlanIds(context)
    );
  }
  // 空 apps（换机未重选）仍挂策略；强制 allow = 全锁，不可跳过不执行
  const modeValue = apps.length === 0
    ? 'allow'
    : (session.mode === 'shield' ? 'shield' : 'allow');

  return {
    sessionId: session.session_id,
    title: session.title,
    startTime,
    endTime,
    repeatDays,
    selectedTokens: apps,
    mode: modeValue
  };
}

export async function syncGuardForSession(
  context: common.Context,
  session: DuoSessionView
): Promise<GuardResult<boolean>> {
  const snapshot = buildGuardSnapshotFromSession(session, context);
  if (!snapshot) {
    await removeGuardForSession(context, session.session_id);
    return { ok: false, data: false, message: '契约无效，无法同步屏时策略' };
  }

  saveScheduledGuardSnapshot(context, snapshot);
  const result = await syncScheduledSessionGuardStrategy(snapshot);
  if (result.ok) {
    removeScheduledGuardSyncIssue(context, session.session_id);
    return result;
  }

  saveScheduledGuardSyncIssue(context, {
    sessionId: session.session_id,
    title: session.title,
    message: normalizeGuardIssueMessage(result.message),
    updatedAt: Date.now()
  });
  return result;
}

export async function removeGuardForSession(
  context: common.Context,
  sessionId: string
): Promise<GuardResult<boolean>> {
  removeScheduledGuardSnapshot(context, sessionId);
  removeScheduledGuardSyncIssue(context, sessionId);
  return removeScheduledSessionGuardStrategy(sessionId);
}

export function markGuardSyncIssue(
  context: common.Context,
  session: DuoSessionView,
  message: string
): void {
  const snapshot = buildGuardSnapshotFromSession(session, context);
  if (snapshot) {
    saveScheduledGuardSnapshot(context, snapshot);
  }
  saveScheduledGuardSyncIssue(context, {
    sessionId: session.session_id,
    title: session.title,
    message: normalizeGuardIssueMessage(message),
    updatedAt: Date.now()
  });
}

export function getGuardSyncIssue(context: common.Context, sessionId: string): ScheduledGuardSyncIssue | null {
  return loadScheduledGuardSyncIssue(context, sessionId);
}

export function getGuardSyncIssueCount(context: common.Context): number {
  return loadScheduledGuardIssueIndex(context).length;
}

const activatedSessionIds: Set<string> = new Set();
let activationInFlight: boolean = false;

export function markScheduledListStale(context: common.Context): void {
  ScheduledListStore.markNeedsRefreshPersisted(context);
  ScheduledListStore.markDirty();
}

export function clearScheduledActivationTracking(sessionId: string): void {
  if (sessionId.length > 0) {
    activatedSessionIds.delete(sessionId);
  }
}

export function clearAllScheduledActivationTracking(): void {
  activatedSessionIds.clear();
}

async function releaseActiveLockOnLogout(context: common.Context): Promise<void> {
  const lock = LockStore.getState();
  if (lock.kind === 'quick_focus') {
    await releaseScreenRestriction(lock.selectedTokens, lock.mode);
    LockStore.clear(context);
    return;
  }
  if (lock.kind === 'covenant') {
    await stopPlanGuardStrategyForWindow(lock.planId);
    const activeSessionId = resolveDuoSessionId(lock);
    LockStore.clear(context);
    clearScheduledActivationTracking(activeSessionId);
    return;
  }
  if (lock.kind === 'cycle_guard') {
    LockStore.clear(context);
  }
}

export async function clearAllScheduledGuardOnLogout(context: common.Context): Promise<GuardResult<boolean>> {
  LockStore.hydrate(context);
  await releaseActiveLockOnLogout(context);
  await deactivateCycleGuard(context);
  clearAllScheduledGuardPersistence(context);
  const osResult = await removeAllGuardStrategies();
  ScheduledListStore.setAllSessions([]);
  ScheduledListStore.markDirty();
  clearAllScheduledActivationTracking();
  return osResult;
}

export async function syncAllScheduledGuardStrategies(
  context: common.Context,
  sessions: DuoSessionView[]
): Promise<GuardResult<boolean>> {
  const activeSessionIds = new Set<string>();

  for (const session of sessions) {
    if (session.session_id.length === 0) {
      continue;
    }
    if (isScheduledGuardEligible(session)) {
      activeSessionIds.add(session.session_id);
      await syncGuardForSession(context, session);
      continue;
    }
    await removeGuardForSession(context, session.session_id);
  }

  const pruneResult = await pruneSessionGuardStrategies(activeSessionIds);
  if (!pruneResult.ok) {
    return pruneResult;
  }
  return { ok: true, data: true, message: '定时契约屏时策略已同步' };
}

/**
 * 补报窗口外仍滞留为 active 的定时契约（对齐 RN flushPendingScheduledCompletion 的目标）。
 * 返回纠正后的列表；调用方负责写回 ScheduledListStore。
 */
export async function reconcileStaleScheduledWindows(
  sessions: DuoSessionView[],
  context?: common.Context
): Promise<DuoSessionView[]> {
  if (sessions.length === 0) {
    return sessions;
  }

  const nextSessions: DuoSessionView[] = [];
  for (let i = 0; i < sessions.length; i++) {
    const session = sessions[i];
    if (!shouldCompleteStaleScheduledWindow(session)) {
      nextSessions.push(session);
      continue;
    }
    const response = await DuoApiService.completeScheduledWindow(session.session_id, context);
    const completed = DuoApiService.parseSession(response);
    if (completed) {
      nextSessions.push(completed);
      clearScheduledActivationTracking(session.session_id);
      continue;
    }
    nextSessions.push(session);
  }
  return nextSessions;
}

export async function syncAllScheduledGuardOnLogin(context: common.Context): Promise<GuardResult<boolean>> {
  const response = await DuoApiService.getScheduledList();
  if (response.statusCode !== 200) {
    return {
      ok: false,
      data: false,
      message: response.message ?? '获取契约列表失败，暂未同步本机屏时策略'
    };
  }

  const list = DuoApiService.parseScheduledList(response);
  const reconciled = await reconcileStaleScheduledWindows(list.items, context);
  ScheduledListStore.setAllSessions(reconciled);
  ScheduledListStore.clearDirty();
  return syncAllScheduledGuardStrategies(context, reconciled);
}

/** 对齐 RN scheduled-list.loadAll：登录后只拉列表并标记待同步，不自动挂本机策略 */
export async function loadScheduledListOnLogin(context: common.Context): Promise<void> {
  const response = await DuoApiService.getScheduledList();
  if (response.statusCode !== 200) {
    return;
  }
  const list = DuoApiService.parseScheduledList(response);
  const reconciled = await reconcileStaleScheduledWindows(list.items, context);
  ScheduledListStore.setAllSessions(reconciled);
  ScheduledListStore.clearDirty();
  applyScheduledGuardSyncCheckAfterListLoad(context, reconciled.length);
}

/** 对齐 RN syncScheduledGuardsManually：用户点击「同步定时任务」 */
export async function syncScheduledGuardsManually(context: common.Context): Promise<GuardResult<boolean>> {
  const result = await syncAllScheduledGuardOnLogin(context);
  if (result.ok) {
    writeBoolPref(context, NEEDS_SCHEDULED_GUARD_SYNC_KEY, false);
    AppStorage.setOrCreate(StoreKeys.NeedsScheduledGuardSync, false);
  }
  return result;
}

export function hydrateScheduledGuardSyncFlags(context: common.Context): void {
  AppStorage.setOrCreate(StoreKeys.NeedsScheduledGuardSync, needsScheduledGuardSync(context));
}

function resolveDuoSessionId(lock: ActiveLockState): string {
  return resolveDuoSessionIdFromLock(lock);
}

function enrichLockFromSession(lock: ActiveLockState, session: DuoSessionView): ActiveLockState {
  const recordId = session.my_record_id || session.record_id || '';
  if (recordId.length === 0 && lock.recordId.length > 0) {
    return lock;
  }
  return {
    kind: lock.kind,
    strategyName: lock.strategyName,
    title: lock.title,
    planId: lock.planId,
    selectedTokens: [...lock.selectedTokens],
    selectedCount: lock.selectedCount,
    mode: lock.mode,
    startedAt: lock.startedAt,
    endAt: lock.endAt,
    updatedAt: Date.now(),
    duoSessionId: lock.duoSessionId.length > 0 ? lock.duoSessionId : session.session_id,
    recordId: recordId.length > 0 ? recordId : lock.recordId,
    participationMode: session.participation_mode === 'duo' ? 'duo' : lock.participationMode,
    partnerNickname: session.participation_mode === 'duo'
      ? resolveDuoCounterpartName(session)
      : lock.partnerNickname,
    timerMode: lock.timerMode,
    minDurationMin: lock.minDurationMin,
    isDelayedSolo: lock.isDelayedSolo
  };
}

/**
 * 主进程补偿：扩展 onStart 可能因网络/进程限制未能完成 activate，或列表未刷新。
 */
export async function reconcileScheduledCovenantActivation(context: common.Context): Promise<void> {
  if (ScheduledListStore.consumePersistedNeedsRefresh(context)) {
    ScheduledListStore.markDirty();
  }

  const lock = LockStore.getState();
  const sessionId = resolveDuoSessionId(lock);
  if (lock.kind !== 'covenant' || sessionId.length === 0) {
    return;
  }
  if (activationInFlight || activatedSessionIds.has(sessionId)) {
    return;
  }

  activationInFlight = true;
  try {
    const response = await DuoApiService.activateScheduledSession(sessionId, context);
    const session = DuoApiService.parseSession(response);
    if (!session) {
      return;
    }

    activatedSessionIds.add(sessionId);
    ScheduledListStore.markDirty();
    ScheduledListStore.patchSession(session);

    const enriched = enrichLockFromSession(lock, session);
    if (enriched.recordId !== lock.recordId || enriched.participationMode !== lock.participationMode) {
      LockStore.setState(context, enriched);
    }
  } finally {
    activationInFlight = false;
  }
}

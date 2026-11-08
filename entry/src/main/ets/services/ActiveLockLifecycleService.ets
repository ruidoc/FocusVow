import { common } from '@kit.AbilityKit';
import {
  ActiveLockState,
  createIdleLockState,
  resolveDuoSessionIdFromLock,
} from '../models/ActiveLockModel';
import { FocusSyncResult } from '../models/FocusSyncModel';
import { endCurrentCycleGuardLockAndRestart, restartCycleGuardIfEnabled } from './CycleGuardService';
import { DuoApiService } from './DuoApiService';
import { DuoBgSyncService, publishFocusBoundaryNotice } from './DuoBgSyncService';
import { FocusSyncService } from './FocusSyncService';
import { AnalyticsService } from './AnalyticsService';
import { FIRST_FOCUS_TITLE } from './FirstFocusPromptService';
import { GuardResult, releaseScreenRestriction, removePlanGuardStrategy, stopAllRunningGuardStrategies, stopPlanGuardStrategyForWindow } from './ScreenTimeService';
import { LockStore } from '../stores/LockStore';
import { refreshStats } from '../stores/StatsStore';
import { UserStore } from '../stores/UserStore';
import { buildOnboardingAnalyticsProps } from '../utils/OnboardingMetaUtil';
import {
  clearScheduledActivationTracking,
  markScheduledListStale,
  syncGuardForSession
} from './ScheduledCovenantService';
import { ScheduledListStore } from '../stores/ScheduledListStore';
import { SettingsStore } from '../stores/SettingsStore';
import { clearPendingQuickStart } from './PendingQuickStartService';
import { saveOrgClassroomMeta } from './OrgClassroomService';
import { isFocusTooShort } from '../utils/FocusValidity';
import { queueHonorCertificate } from './CertificatePendingService';
import { savePersistedActiveLockState } from './ActiveLockPersistenceService';
import { addExitPlanId } from './ExitPlanIdsService';
import { GuardWindowEvent, upsertGuardWindowEvent } from './GuardWindowEventService';

let endingLock: boolean = false;

export interface FocusLifecycleResult {
  ok: boolean;
  tooShort: boolean;
}

function notifyDuoBgSync(): void {
  DuoBgSyncService.ensure();
}

function rememberOnceWindow(
  context: common.Context,
  state: ActiveLockState,
  kind: 'start' | 'stop',
  endedAt: number,
  result: string
): void {
  if (!state.planId.startsWith('once_')) {
    return;
  }
  // 即时互督也用 once_ 策略名，补记只留给单人，避免再写一条同名单人记录
  if (resolveDuoSessionIdFromLock(state).length > 0 || state.participationMode === 'duo') {
    return;
  }
  const durationMin = state.minDurationMin > 0
    ? state.minDurationMin
    : Math.max(1, Math.round((state.endAt - state.startedAt) / 60000));
  const event: GuardWindowEvent = {
    occurrence_id: state.planId,
    session_id: '',
    plan_id: state.planId,
    kind: kind,
    result: result,
    fail_reason: result === 'VIOLATION' ? 'tear' : '',
    started_at: state.startedAt,
    ended_at: kind === 'stop' ? endedAt : 0,
    title: state.title,
    duration_min: durationMin,
    timer_mode: state.timerMode.length > 0 ? state.timerMode : 'countdown',
    mode: state.mode,
  };
  upsertGuardWindowEvent(context, event);
}

function trackSessionFinished(
  state: ActiveLockState,
  endedAt: number,
  result: string,
  reason: string = ''
): void {
  const elapsedMs = Math.max(0, endedAt - state.startedAt);
  const props: Record<string, Object> = {
    'plan_id': state.planId,
    'focus_type': 'once',
    'result': result,
    'is_first_focus': state.title === FIRST_FOCUS_TITLE,
    'entry_source': 'quick_start',
    'participation_mode': state.participationMode.length > 0 ? state.participationMode : 'solo',
    'elapsed_minutes': Math.floor(elapsedMs / 60000)
  };
  if (reason.length > 0) {
    props['reason'] = reason;
    props['unlock_path'] = reason;
  }
  AnalyticsService.trackEvent('session_finished', props);
}

function saveQuickFocusPending(
  context: common.Context,
  state: ActiveLockState,
  result: FocusSyncResult,
  endedAt: number = Date.now(),
  failReason: string = ''
): void {
  if (state.planId.startsWith('org_cls_')) {
    return;
  }
  const sessionId = resolveDuoSessionIdFromLock(state);
  console.info(
    `[FocusSync] save pending kind=${sessionId.length > 0 ? 'session_terminal' : 'solo_instant'} result=${result}`
  );
  if (sessionId.length > 0) {
    const enriched: ActiveLockState = {
      kind: state.kind,
      strategyName: state.strategyName,
      title: state.title,
      planId: state.planId,
      selectedTokens: [...state.selectedTokens],
      selectedCount: state.selectedCount,
      mode: state.mode,
      startedAt: state.startedAt,
      endAt: state.endAt,
      updatedAt: state.updatedAt,
      duoSessionId: sessionId,
      recordId: state.recordId,
      participationMode: state.participationMode,
      partnerNickname: state.partnerNickname,
      timerMode: state.timerMode,
      minDurationMin: state.minDurationMin,
      isDelayedSolo: state.isDelayedSolo
    };
    FocusSyncService.saveSessionTerminalPending(context, enriched, result, endedAt, failReason);
    return;
  }
  FocusSyncService.saveSoloInstantPending(context, state, result, endedAt, failReason);
  if (!UserStore.isLoggedIn()) {
    const durationMin = Math.max(1, Math.round((state.endAt - state.startedAt) / 60000));
    const actualMin = Math.max(0, Math.floor((endedAt - state.startedAt) / 60000));
    if (result === 'SUCCESS') {
      AnalyticsService.trackEvent('guest_focus_pending_saved', buildOnboardingAnalyticsProps({
        'plan_id': state.planId,
        'duration_min': durationMin,
        'actual_min': actualMin,
        'pending_saved': true,
      }));
    } else if (result === 'VIOLATION') {
      AnalyticsService.trackEvent('guest_focus_failed', buildOnboardingAnalyticsProps({
        'reason': failReason.length > 0 ? failReason : 'tear',
        'plan_id': state.planId,
        'pending_saved': false,
      }));
    }
  }
}

/**
 * TimeGuard onStop：对齐 RN 原生到点停锁。
 * 扩展进程即可跑：落 sync pending、清锁、重启循环守护。系统停策略即解锁，不依赖 App 打开。
 */
export async function completeOnceQuickFocusFromGuardStop(
  context: common.Context,
  state: ActiveLockState,
): Promise<void> {
  if (state.kind !== 'quick_focus') {
    return;
  }
  const endedAt = Date.now();
  const tooShort = isFocusTooShort(state.startedAt, endedAt);
  if (tooShort) {
    trackSessionFinished(state, endedAt, 'failed', 'too_short');
  } else {
    trackSessionFinished(state, endedAt, 'completed');
    rememberOnceWindow(context, state, 'stop', endedAt, 'SUCCESS');
    saveQuickFocusPending(context, state, 'SUCCESS', endedAt);
    if (UserStore.isLoggedIn()) {
      queueHonorCertificate(state, endedAt);
    }
  }
  clearPendingQuickStart(context);
  // 扩展进程可能无 AppStorage；持久化 idle + 尝试 LockStore.clear
  savePersistedActiveLockState(context, createIdleLockState());
  try {
    LockStore.clear(context);
  } catch (_e) {
    // extension 无 UI store 时忽略
  }
  await releaseScreenRestriction(state.selectedTokens, state.mode);
  await restartCycleGuardIfEnabled(context);
  if (!tooShort) {
    void publishFocusBoundaryNotice(
      context,
      'end',
      state.title.length > 0 ? state.title : '快速专注',
      Math.max(1, Math.round((endedAt - state.startedAt) / 60000)),
    );
  }
}

export async function endQuickFocus(
  context: common.UIAbilityContext,
  state: ActiveLockState,
  successMessage: string,
  failurePrefix: string,
  markCompleted: boolean = true
): Promise<FocusLifecycleResult> {
  if (endingLock || state.kind !== 'quick_focus') {
    return { ok: false, tooShort: false };
  }

  endingLock = true;
  try {
    const endedAt = Date.now();
    const tooShort = isFocusTooShort(state.startedAt, endedAt);

    if (markCompleted) {
      if (tooShort) {
        trackSessionFinished(state, endedAt, 'failed', 'too_short');
        const sessionId = resolveDuoSessionIdFromLock(state);
        if (sessionId.length > 0) {
          saveQuickFocusPending(context, state, 'VIOLATION', endedAt, 'too_short');
        } else if (!UserStore.isLoggedIn()) {
          AnalyticsService.trackEvent('guest_focus_failed', buildOnboardingAnalyticsProps({
            'reason': 'too_short',
            'plan_id': state.planId,
            'pending_saved': false,
          }));
        }
      } else {
        trackSessionFinished(state, endedAt, 'completed');
        saveQuickFocusPending(context, state, 'SUCCESS', endedAt);
      }
    }

    // once_ 可能是 TimeGuard 策略，也可能是 reconcile 兜底的 setAppsRestriction，两边都解
    let unlockOk = false;
    if (state.planId.startsWith('once_')) {
      const removeResult = await removePlanGuardStrategy(state.planId);
      const releaseResult = await releaseScreenRestriction(
        state.selectedTokens,
        state.mode,
      );
      unlockOk = removeResult.ok || releaseResult.ok;
    } else {
      const releaseResult = await releaseScreenRestriction(
        state.selectedTokens,
        state.mode,
      );
      unlockOk = releaseResult.ok;
    }
    await FocusSyncService.flushPending(context);
    if (unlockOk) {
      if (state.planId.startsWith('once_') || state.isDelayedSolo) {
        clearPendingQuickStart(context);
      }
      if (state.planId.startsWith('org_cls_')) {
        saveOrgClassroomMeta(context, null);
      }
      LockStore.clear(context);
      notifyDuoBgSync();
    }
    SettingsStore.updateStatusMessage(
      context,
      unlockOk
        ? (tooShort ? '专注不足 30 秒，本次不计时' : successMessage)
        : `${failurePrefix}：解除限制失败`
    );
    if (unlockOk && markCompleted && !tooShort) {
      refreshStats();
    }
    return { ok: unlockOk, tooShort };
  } finally {
    endingLock = false;
  }
}

export async function tearQuickFocus(
  context: common.UIAbilityContext,
  state: ActiveLockState
): Promise<FocusLifecycleResult> {
  if (endingLock || state.kind !== 'quick_focus') {
    return { ok: false, tooShort: false };
  }

  endingLock = true;
  try {
    const endedAt = Date.now();
    const tooShort = isFocusTooShort(state.startedAt, endedAt);
    const sessionId = resolveDuoSessionIdFromLock(state);

    trackSessionFinished(
      state,
      endedAt,
      'failed',
      tooShort ? 'too_short' : 'user_exit'
    );

    if (tooShort) {
      if (sessionId.length > 0) {
        saveQuickFocusPending(context, state, 'VIOLATION', endedAt, 'too_short');
      }
    } else if (UserStore.isLoggedIn() || sessionId.length > 0) {
      // 未登录第一次单人失败：不落 pending，登录后也不补推耻辱记录
      rememberOnceWindow(context, state, 'stop', endedAt, 'VIOLATION');
      saveQuickFocusPending(context, state, 'VIOLATION', endedAt);
    }

    // 先于停策略写入，避免 TimeGuard onStop 把撕毁当成自然结束记 success
    if (state.planId.length > 0 && !tooShort) {
      addExitPlanId(context, state.planId);
    }

    let unlockOk = false;
    if (state.planId.startsWith('once_')) {
      const removeResult = await removePlanGuardStrategy(state.planId);
      const releaseResult = await releaseScreenRestriction(
        state.selectedTokens,
        state.mode,
      );
      unlockOk = removeResult.ok || releaseResult.ok;
    } else {
      const releaseResult = await releaseScreenRestriction(
        state.selectedTokens,
        state.mode,
      );
      unlockOk = releaseResult.ok;
    }
    await FocusSyncService.flushPending(context);
    if (unlockOk) {
      if (state.planId.startsWith('once_') || state.isDelayedSolo) {
        clearPendingQuickStart(context);
      }
      if (state.planId.startsWith('org_cls_')) {
        saveOrgClassroomMeta(context, null);
      }
      LockStore.clear(context);
      notifyDuoBgSync();
    }
    SettingsStore.updateStatusMessage(
      context,
      unlockOk
        ? (tooShort ? '专注不足 30 秒，本次不计时' : '契约已撕毁')
        : '撕毁失败：解除限制失败'
    );
    if (unlockOk && !tooShort) {
      refreshStats();
    }
    return { ok: unlockOk, tooShort };
  } finally {
    endingLock = false;
  }
}

export async function syncScheduledCovenantTerminal(
  context: common.Context,
  state: ActiveLockState,
  result: FocusSyncResult
): Promise<boolean> {
  const sessionId = resolveDuoSessionIdFromLock(state);
  if (sessionId.length === 0) {
    return false;
  }

  const endedAt = Date.now();
  const tooShort = isFocusTooShort(state.startedAt, endedAt);

  if (result === 'VIOLATION' || tooShort) {
    saveQuickFocusPending(
      context,
      state,
      'VIOLATION',
      endedAt,
      tooShort ? 'too_short' : ''
    );
    await FocusSyncService.flushPending(context);
    return tooShort;
  }

  await DuoApiService.completeScheduledWindow(sessionId, context);
  if (UserStore.isLoggedIn()) {
    await FocusSyncService.flushPending(context);
  }
  return false;
}

export async function tearCovenantWindow(
  context: common.UIAbilityContext,
  state: ActiveLockState
): Promise<FocusLifecycleResult> {
  if (endingLock || state.kind !== 'covenant') {
    return { ok: false, tooShort: false };
  }

  endingLock = true;
  try {
    const tooShort = await syncScheduledCovenantTerminal(context, state, 'VIOLATION');
    const sessionId = resolveDuoSessionIdFromLock(state);
    if (state.planId.length > 0 && !tooShort) {
      addExitPlanId(context, state.planId);
    }
    const stopResult = await stopPlanGuardStrategyForWindow(state.planId);
    await releaseScreenRestriction(state.selectedTokens, state.mode);
    if (stopResult.ok && state.planId.length > 0) {
      const sessions = ScheduledListStore.getAllSessions();
      for (let i = 0; i < sessions.length; i++) {
        if (sessions[i].session_id === sessionId) {
          await syncGuardForSession(context, sessions[i]);
          break;
        }
      }
    }
    LockStore.clear(context);
    notifyDuoBgSync();
    markScheduledListStale(context);
    clearScheduledActivationTracking(sessionId);
    await restartCycleGuardIfEnabled(context);
    SettingsStore.updateStatusMessage(
      context,
      stopResult.ok
        ? (tooShort ? '专注不足 30 秒，本次不计时' : '契约已撕毁')
        : `撕毁失败：${stopResult.message}`
    );
    if (stopResult.ok && !tooShort) {
      refreshStats();
    }
    return { ok: stopResult.ok, tooShort };
  } finally {
    endingLock = false;
  }
}

export async function skipCovenantWindow(
  context: common.UIAbilityContext,
  state: ActiveLockState
): Promise<GuardResult<boolean>> {
  if (endingLock || state.kind !== 'covenant') {
    return { ok: false, data: false, message: '当前不在契约锁定中' };
  }

  endingLock = true;
  try {
    await syncScheduledCovenantTerminal(context, state, 'SUCCESS');
    const sessionId = resolveDuoSessionIdFromLock(state);
    const stopResult = await stopPlanGuardStrategyForWindow(state.planId);
    await releaseScreenRestriction(state.selectedTokens, state.mode);
    LockStore.clear(context);
    notifyDuoBgSync();
    markScheduledListStale(context);
    clearScheduledActivationTracking(sessionId);
    await restartCycleGuardIfEnabled(context);
    const message = stopResult.ok ? '已跳过本次契约窗口' : `已跳过本次契约窗口，但停止策略失败：${stopResult.message}`;
    SettingsStore.updateStatusMessage(context, message);
    if (stopResult.ok) {
      refreshStats();
    }
    return { ok: stopResult.ok, data: stopResult.ok, message };
  } finally {
    endingLock = false;
  }
}

export async function endCycleGuardLock(context: common.Context): Promise<GuardResult<boolean>> {
  if (endingLock) {
    return { ok: false, data: false, message: '正在处理中' };
  }

  endingLock = true;
  try {
    const result = await endCurrentCycleGuardLockAndRestart(context);
    LockStore.clear(context);
    return result;
  } finally {
    endingLock = false;
  }
}

/** 设置页强制解锁：停定时策略，并解开补发留下的立即限制 */
export async function forceReleaseStaleScreenLock(
  context: common.UIAbilityContext
): Promise<GuardResult<boolean>> {
  const lock = LockStore.getState();
  if (lock.kind !== 'none') {
    await releaseScreenRestriction(lock.selectedTokens, lock.mode);
  }
  await releaseScreenRestriction([], 'allow');
  const result = await stopAllRunningGuardStrategies();
  if (result.ok) {
    LockStore.clear(context);
  }
  return result;
}

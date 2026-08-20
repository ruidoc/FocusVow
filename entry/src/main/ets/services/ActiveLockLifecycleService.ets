import { common } from '@kit.AbilityKit';
import {
  ActiveLockState,
  createIdleLockState,
  resolveDuoSessionIdFromLock,
} from '../models/ActiveLockModel';
import { FocusSyncResult } from '../models/FocusSyncModel';
import { endCurrentCycleGuardLockAndRestart, restartCycleGuardIfEnabled } from './CycleGuardService';
import { DuoApiService } from './DuoApiService';
import { DuoBgSyncService } from './DuoBgSyncService';
import { FocusSyncService } from './FocusSyncService';
import { AnalyticsService } from './AnalyticsService';
import { FIRST_FOCUS_TITLE } from './FirstFocusPromptService';
import { GuardResult, releaseScreenRestriction, removePlanGuardStrategy, stopPlanGuardStrategyForWindow } from './ScreenTimeService';
import { LockStore } from '../stores/LockStore';
import { refreshStats } from '../stores/StatsStore';
import { UserStore } from '../stores/UserStore';
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

let endingLock: boolean = false;

export interface FocusLifecycleResult {
  ok: boolean;
  tooShort: boolean;
}

function notifyDuoBgSync(): void {
  DuoBgSyncService.ensure();
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
      saveQuickFocusPending(context, state, 'VIOLATION', endedAt);
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
    const stopResult = await stopPlanGuardStrategyForWindow(state.planId);
    if (stopResult.ok && state.planId.length > 0) {
      addExitPlanId(context, state.planId);
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

import { common } from '@kit.AbilityKit';
import { ActiveLockState, resolveDuoSessionIdFromLock } from '../models/ActiveLockModel';
import { FocusSyncResult } from '../models/FocusSyncModel';
import { endCurrentCycleGuardLockAndRestart, restartCycleGuardIfEnabled } from './CycleGuardService';
import { DuoApiService } from './DuoApiService';
import { DuoBgSyncService } from './DuoBgSyncService';
import { FocusSyncService } from './FocusSyncService';
import { GuardResult, releaseScreenRestriction, stopPlanGuardStrategyForWindow } from './ScreenTimeService';
import { LockStore } from '../stores/LockStore';
import { refreshStats } from '../stores/StatsStore';
import { UserStore } from '../stores/UserStore';
import {
  clearScheduledActivationTracking,
  markScheduledListStale
} from './ScheduledCovenantService';
import { SettingsStore } from '../stores/SettingsStore';
import { isFocusTooShort } from '../utils/FocusValidity';

let endingLock: boolean = false;

export interface FocusLifecycleResult {
  ok: boolean;
  tooShort: boolean;
}

function notifyDuoBgSync(): void {
  DuoBgSyncService.ensure();
}

function saveQuickFocusPending(
  context: common.Context,
  state: ActiveLockState,
  result: FocusSyncResult,
  endedAt: number = Date.now(),
  failReason: string = ''
): void {
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
      minDurationMin: state.minDurationMin
    };
    FocusSyncService.saveSessionTerminalPending(context, enriched, result, endedAt, failReason);
    return;
  }
  if (!UserStore.isLoggedIn()) {
    return;
  }
  FocusSyncService.saveSoloInstantPending(context, state, result, endedAt, failReason);
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
        const sessionId = resolveDuoSessionIdFromLock(state);
        if (sessionId.length > 0) {
          saveQuickFocusPending(context, state, 'VIOLATION', endedAt, 'too_short');
        }
      } else {
        saveQuickFocusPending(context, state, 'SUCCESS', endedAt);
      }
    }

    const result = await releaseScreenRestriction(state.selectedTokens, state.mode);
    await FocusSyncService.flushPending(context);
    if (result.ok) {
      LockStore.clear(context);
      notifyDuoBgSync();
    }
    SettingsStore.updateStatusMessage(
      context,
      result.ok
        ? (tooShort ? '专注不足 30 秒，本次不计时' : successMessage)
        : `${failurePrefix}：${result.message}`
    );
    if (result.ok && markCompleted && !tooShort) {
      refreshStats();
    }
    return { ok: result.ok, tooShort };
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

    if (tooShort) {
      if (sessionId.length > 0) {
        saveQuickFocusPending(context, state, 'VIOLATION', endedAt, 'too_short');
      }
    } else {
      saveQuickFocusPending(context, state, 'VIOLATION', endedAt);
    }

    const result = await releaseScreenRestriction(state.selectedTokens, state.mode);
    await FocusSyncService.flushPending(context);
    if (result.ok) {
      LockStore.clear(context);
      notifyDuoBgSync();
    }
    SettingsStore.updateStatusMessage(
      context,
      result.ok
        ? (tooShort ? '专注不足 30 秒，本次不计时' : '契约已撕毁')
        : `撕毁失败：${result.message}`
    );
    if (result.ok && !tooShort) {
      refreshStats();
    }
    return { ok: result.ok, tooShort };
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

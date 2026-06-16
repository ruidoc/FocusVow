import { common } from '@kit.AbilityKit';
import { ActiveLockState } from '../models/ActiveLockModel';
import { FocusSyncResult } from '../models/FocusSyncModel';
import { endCurrentCycleGuardLockAndRestart, restartCycleGuardIfEnabled } from './CycleGuardService';
import { FocusSyncService } from './FocusSyncService';
import { GuardResult, releaseScreenRestriction, stopPlanGuardStrategyForWindow } from './ScreenTimeService';
import { LockStore } from '../stores/LockStore';
import { SettingsStore } from '../stores/SettingsStore';

let endingLock: boolean = false;

function saveQuickFocusPending(
  context: common.Context,
  state: ActiveLockState,
  result: FocusSyncResult,
  endedAt: number = Date.now()
): void {
  console.info(`[FocusSync] save pending kind=${state.duoSessionId.length > 0 ? 'session_terminal' : 'solo_instant'} result=${result}`);
  if (state.duoSessionId.length > 0) {
    FocusSyncService.saveSessionTerminalPending(context, state, result, endedAt);
  } else {
    FocusSyncService.saveSoloInstantPending(context, state, result, endedAt);
  }
}

export async function endQuickFocus(
  context: common.UIAbilityContext,
  state: ActiveLockState,
  successMessage: string,
  failurePrefix: string,
  markCompleted: boolean = true
): Promise<boolean> {
  if (endingLock || state.kind !== 'quick_focus') {
    return false;
  }

  endingLock = true;
  try {
    if (markCompleted) {
      saveQuickFocusPending(context, state, 'SUCCESS');
    }

    const result = await releaseScreenRestriction(state.selectedTokens, state.mode);
    if (result.ok) {
      LockStore.clear(context);
      void FocusSyncService.flushPending(context);
    }
    SettingsStore.updateStatusMessage(
      context,
      result.ok ? successMessage : `${failurePrefix}：${result.message}`
    );
    return result.ok;
  } finally {
    endingLock = false;
  }
}

export async function tearQuickFocus(
  context: common.UIAbilityContext,
  state: ActiveLockState
): Promise<boolean> {
  if (endingLock || state.kind !== 'quick_focus') {
    return false;
  }

  endingLock = true;
  try {
    saveQuickFocusPending(context, state, 'VIOLATION');

    const result = await releaseScreenRestriction(state.selectedTokens, state.mode);
    if (result.ok) {
      LockStore.clear(context);
      void FocusSyncService.flushPending(context);
    }
    SettingsStore.updateStatusMessage(
      context,
      result.ok ? '契约已撕毁' : `撕毁失败：${result.message}`
    );
    return result.ok;
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
    const stopResult = await stopPlanGuardStrategyForWindow(state.planId);
    LockStore.clear(context);
    await restartCycleGuardIfEnabled(context);
    const message = stopResult.ok ? '已跳过本次契约窗口' : `已跳过本次契约窗口，但停止策略失败：${stopResult.message}`;
    SettingsStore.updateStatusMessage(context, message);
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

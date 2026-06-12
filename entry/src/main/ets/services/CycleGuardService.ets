import { common } from '@kit.AbilityKit';
import { guardService } from '@kit.ScreenTimeGuardKit';
import {
  CycleGuardPhase,
  CycleGuardState,
  createDefaultCycleGuardState
} from '../models/CycleGuardModel';
import {
  createCycleGuardLockState,
  createIdleLockState
} from '../models/ActiveLockModel';
import {
  loadPersistedActiveLockState,
  savePersistedActiveLockState
} from './ActiveLockPersistenceService';
import { loadPersistedCycleGuardState, savePersistedCycleGuardState } from './CycleGuardPersistenceService';
import { GuardResult } from './ScreenTimeService';

interface GuardErrorLike {
  code?: number;
}

const QUOTA_STRATEGY_NAME: string = 'cycle_quota_strategy';

export function isCycleGuardStrategyName(strategyName: string): boolean {
  return strategyName === QUOTA_STRATEGY_NAME;
}

function toError(message: string): Error {
  return new Error(message);
}

function getCurrentState(context: common.Context): CycleGuardState {
  return loadPersistedCycleGuardState(context) ?? createDefaultCycleGuardState();
}

function saveState(
  context: common.Context,
  patch: Partial<CycleGuardState>
): CycleGuardState {
  const currentState = getCurrentState(context);
  const nextState: CycleGuardState = {
    enabled: patch.enabled ?? currentState.enabled,
    quotaMinutes: patch.quotaMinutes ?? currentState.quotaMinutes,
    selectedTokens: patch.selectedTokens ?? currentState.selectedTokens,
    selectedAppCount: patch.selectedAppCount ?? currentState.selectedAppCount,
    phase: patch.phase ?? currentState.phase,
    statusMessage: patch.statusMessage ?? currentState.statusMessage
  };
  savePersistedCycleGuardState(context, nextState);
  return nextState;
}

function createQuotaStrategy(state: CycleGuardState): guardService.GuardStrategy {
  return {
    name: QUOTA_STRATEGY_NAME,
    timeStrategy: {
      type: guardService.TimeStrategyType.INCLUSIVE_DURATION_TYPE,
      totalDuration: state.quotaMinutes
    },
    appInfo: {
      appTokens: [...state.selectedTokens]
    },
    appRestrictionType: guardService.RestrictionType.TRUSTLIST_TYPE
  };
}

function isGuardErrorCode(error: GuardErrorLike, code: guardService.GuardServiceErrorCode): boolean {
  return error.code === code;
}

async function addOrUpdateGuardStrategy(strategy: guardService.GuardStrategy): Promise<void> {
  try {
    await guardService.addGuardStrategy(strategy);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (isGuardErrorCode(guardError, guardService.GuardServiceErrorCode.STRATEGY_NAME_ALREADY_EXIST)) {
      await guardService.updateGuardStrategy(strategy.name, strategy);
      return;
    }
    throw toError(`Failed to add or update guard strategy: ${strategy.name}`);
  }
}

async function stopGuardStrategyIfStarted(strategyName: string): Promise<void> {
  try {
    await guardService.stopGuardStrategy(strategyName);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (!isGuardErrorCode(guardError, guardService.GuardServiceErrorCode.STRATEGY_NOT_STARTED) &&
      !isGuardErrorCode(guardError, guardService.GuardServiceErrorCode.NONEXISTENT_STRATEGY)) {
      throw toError(`Failed to stop guard strategy: ${strategyName}`);
    }
  }
}

async function removeGuardStrategyIfExists(strategyName: string): Promise<void> {
  try {
    await guardService.removeGuardStrategy(strategyName);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (!isGuardErrorCode(guardError, guardService.GuardServiceErrorCode.NONEXISTENT_STRATEGY)) {
      throw toError(`Failed to remove guard strategy: ${strategyName}`);
    }
  }
}

async function startGuardStrategySafely(strategyName: string): Promise<void> {
  try {
    await guardService.startGuardStrategy(strategyName);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (!isGuardErrorCode(guardError, guardService.GuardServiceErrorCode.STRATEGY_ALREADY_EXECUTED)) {
      throw toError(`Failed to start guard strategy: ${strategyName}`);
    }
  }
}

async function hasAuthorization(): Promise<boolean> {
  try {
    const authStatus = await guardService.getUserAuthStatus();
    return authStatus === guardService.AuthStatus.AUTH_GRANTED;
  } catch {
    return false;
  }
}

function validateState(state: CycleGuardState): GuardResult<boolean> | null {
  if (state.selectedTokens.length === 0) {
    return { ok: false, data: false, message: '请先选择需要纳入娱乐限额的应用' };
  }
  if (state.quotaMinutes <= 0) {
    return { ok: false, data: false, message: '总可用时长需要大于 0 分钟' };
  }
  return null;
}

function clearActiveLockIfCycleGuard(context: common.Context): void {
  const currentLock = loadPersistedActiveLockState(context) ?? createIdleLockState();
  if (currentLock.kind === 'cycle_guard') {
    savePersistedActiveLockState(context, createIdleLockState());
  }
}

/** 重启额度计时时仅清理守护锁，避免误清契约 / 快速专注锁态 */
function clearActiveLockBeforeCycleGuardRestart(context: common.Context): void {
  const currentLock = loadPersistedActiveLockState(context) ?? createIdleLockState();
  if (currentLock.kind === 'cycle_guard' || currentLock.kind === 'none') {
    savePersistedActiveLockState(context, createIdleLockState());
  }
}

async function restartQuotaStrategy(
  context: common.Context,
  preparingMessage: string,
  successMessage: string
): Promise<GuardResult<boolean>> {
  const state = getCurrentState(context);
  const validation = validateState(state);
  if (validation) {
    saveState(context, { enabled: false, phase: 'idle', statusMessage: validation.message });
    clearActiveLockIfCycleGuard(context);
    return validation;
  }

  try {
    clearActiveLockBeforeCycleGuardRestart(context);
    saveState(context, {
      enabled: true,
      phase: 'quota_running',
      statusMessage: preparingMessage
    });
    await stopGuardStrategyIfStarted(QUOTA_STRATEGY_NAME);
    await removeGuardStrategyIfExists(QUOTA_STRATEGY_NAME);
    await addOrUpdateGuardStrategy(createQuotaStrategy(state));
    await startGuardStrategySafely(QUOTA_STRATEGY_NAME);
    saveState(context, {
      enabled: true,
      phase: 'quota_running',
      statusMessage: successMessage
    });
    return { ok: true, data: true, message: successMessage };
  } catch {
    saveState(context, {
      enabled: false,
      phase: 'idle',
      statusMessage: '启动娱乐限额失败'
    });
    clearActiveLockIfCycleGuard(context);
    return { ok: false, data: false, message: '启动娱乐限额失败' };
  }
}

export async function restartCycleGuardIfEnabled(context: common.Context): Promise<void> {
  const state = getCurrentState(context);
  if (!state.enabled) {
    return;
  }

  await restartQuotaStrategy(
    context,
    '正在重新开始娱乐限额计时',
    `娱乐限额已重新开始：${state.quotaMinutes} 分钟`
  );
}

export async function activateCycleGuard(context: common.Context): Promise<GuardResult<boolean>> {
  if (!(await hasAuthorization())) {
    saveState(context, {
      enabled: false,
      phase: 'idle',
      statusMessage: '请先完成系统授权'
    });
    return { ok: false, data: false, message: '请先完成系统授权' };
  }

  const state = getCurrentState(context);
  return restartQuotaStrategy(
    context,
    '正在开始娱乐限额计时',
    `娱乐限额已开始：${state.quotaMinutes} 分钟`
  );
}

export async function deactivateCycleGuard(context: common.Context): Promise<GuardResult<boolean>> {
  saveState(context, {
    enabled: false,
    phase: 'idle',
    statusMessage: '娱乐限额已停止'
  });
  clearActiveLockIfCycleGuard(context);

  try {
    await stopGuardStrategyIfStarted(QUOTA_STRATEGY_NAME);
    await removeGuardStrategyIfExists(QUOTA_STRATEGY_NAME);
    return { ok: true, data: true, message: '娱乐限额已停止' };
  } catch {
    return { ok: false, data: false, message: '停止娱乐限额失败' };
  }
}

function isPhase(state: CycleGuardState, phase: CycleGuardPhase): boolean {
  return state.phase === phase;
}

export async function handleCycleStrategyStart(
  context: common.Context,
  strategyName: string
): Promise<void> {
  const state = getCurrentState(context);
  if (!state.enabled || !isCycleGuardStrategyName(strategyName) || !isPhase(state, 'quota_running')) {
    return;
  }

  saveState(context, {
    enabled: true,
    phase: 'locked',
    statusMessage: `总可用时长已用完，已自动锁定 ${state.selectedAppCount} 个应用`
  });
  savePersistedActiveLockState(
    context,
    createCycleGuardLockState(state.selectedTokens, state.selectedAppCount)
  );
}

export async function handleCycleStrategyStop(
  context: common.Context,
  strategyName: string
): Promise<void> {
  const state = getCurrentState(context);
  if (!state.enabled || !isCycleGuardStrategyName(strategyName) || !isPhase(state, 'locked')) {
    return;
  }

  saveState(context, {
    enabled: true,
    phase: 'quota_running',
    statusMessage: `娱乐限额已恢复：${state.quotaMinutes} 分钟`
  });
  clearActiveLockIfCycleGuard(context);
}

export async function endCurrentCycleGuardLockAndRestart(
  context: common.Context
): Promise<GuardResult<boolean>> {
  const state = getCurrentState(context);
  if (!state.enabled) {
    return { ok: false, data: false, message: '娱乐限额未启动' };
  }
  if (!isPhase(state, 'locked')) {
    return { ok: false, data: false, message: '当前不在锁定状态' };
  }

  saveState(context, {
    enabled: true,
    phase: 'locked',
    statusMessage: '正在结束当前锁定并重新开始娱乐限额计时'
  });

  const nextState = getCurrentState(context);
  return restartQuotaStrategy(
    context,
    '正在重新开始娱乐限额计时',
    `娱乐限额已重新开始：${nextState.quotaMinutes} 分钟`
  );
}

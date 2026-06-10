import { common } from '@kit.AbilityKit';
import { guardService } from '@kit.ScreenTimeGuardKit';
import { CycleGuardPhase, CycleGuardState, createDefaultCycleGuardState } from '../models/CycleGuardModel';
import { loadPersistedCycleGuardState, savePersistedCycleGuardState } from './CycleGuardPersistenceService';
import { GuardResult } from './ScreenTimeService';

interface GuardErrorLike {
  code?: number;
}

interface LockTimeWindow {
  startTime: string;
  endTime: string;
}

const QUOTA_STRATEGY_NAME: string = 'cycle_quota_strategy';
const LOCK_STRATEGY_NAME: string = 'cycle_lock_strategy';

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
    lockMinutes: patch.lockMinutes ?? currentState.lockMinutes,
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

function createLockStrategy(state: CycleGuardState): guardService.GuardStrategy {
  const lockTimeWindow: LockTimeWindow = createLockTimeWindow(state.lockMinutes);
  return {
    name: LOCK_STRATEGY_NAME,
    timeStrategy: {
      type: guardService.TimeStrategyType.START_END_TIME_TYPE,
      startTime: lockTimeWindow.startTime,
      endTime: lockTimeWindow.endTime
    },
    appInfo: {
      appTokens: [...state.selectedTokens]
    },
    appRestrictionType: guardService.RestrictionType.BLOCKLIST_TYPE
  };
}

function padTime(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

function toTimeString(date: Date): string {
  return `${padTime(date.getHours())}:${padTime(date.getMinutes())}`;
}

function createLockTimeWindow(lockMinutes: number): LockTimeWindow {
  const now = new Date();
  const endAt = new Date(now.getTime() + lockMinutes * 60 * 1000);
  const lockTimeWindow: LockTimeWindow = {
    startTime: toTimeString(now),
    endTime: toTimeString(endAt)
  };
  return lockTimeWindow;
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
    return { ok: false, data: false, message: '请先选择需要循环守护的应用' };
  }
  if (state.quotaMinutes <= 0) {
    return { ok: false, data: false, message: '共享时长需要大于 0 分钟' };
  }
  if (state.lockMinutes <= 0) {
    return { ok: false, data: false, message: '锁定时长需要大于 0 分钟' };
  }
  return null;
}

async function startQuotaPhaseInternal(context: common.Context): Promise<GuardResult<boolean>> {
  const state = getCurrentState(context);
  const validation = validateState(state);
  if (validation) {
    saveState(context, { enabled: false, phase: 'idle', statusMessage: validation.message });
    return validation;
  }

  try {
    saveState(context, {
      enabled: true,
      phase: 'switching_to_quota',
      statusMessage: '正在重建共享额度阶段'
    });
    await addOrUpdateGuardStrategy(createQuotaStrategy(state));
    await startGuardStrategySafely(QUOTA_STRATEGY_NAME);
    await stopGuardStrategyIfStarted(LOCK_STRATEGY_NAME);
    await removeGuardStrategyIfExists(LOCK_STRATEGY_NAME);
    saveState(context, {
      enabled: true,
      phase: 'quota_running',
      statusMessage: `共享额度计时已启动：${state.quotaMinutes} 分钟`
    });
    return { ok: true, data: true, message: '共享额度计时已启动' };
  } catch {
    saveState(context, {
      enabled: true,
      phase: 'idle',
      statusMessage: '启动共享额度阶段失败'
    });
    return { ok: false, data: false, message: '启动共享额度阶段失败' };
  }
}

async function startLockPhaseInternal(context: common.Context): Promise<GuardResult<boolean>> {
  const state = getCurrentState(context);
  const validation = validateState(state);
  if (validation) {
    saveState(context, { enabled: false, phase: 'idle', statusMessage: validation.message });
    return validation;
  }

  try {
    saveState(context, {
      enabled: true,
      phase: 'switching_to_lock',
      statusMessage: '共享额度已耗尽，正在切换到锁定阶段'
    });
    await addOrUpdateGuardStrategy(createLockStrategy(state));
    await startGuardStrategySafely(LOCK_STRATEGY_NAME);
    await stopGuardStrategyIfStarted(QUOTA_STRATEGY_NAME);
    await removeGuardStrategyIfExists(QUOTA_STRATEGY_NAME);
    saveState(context, {
      enabled: true,
      phase: 'lock_running',
      statusMessage: `锁定窗口已建立：${state.lockMinutes} 分钟`
    });
    return { ok: true, data: true, message: '锁定窗口已建立' };
  } catch {
    saveState(context, {
      enabled: true,
      phase: 'idle',
      statusMessage: '启动锁定阶段失败'
    });
    return { ok: false, data: false, message: '启动锁定阶段失败' };
  }
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

  return startQuotaPhaseInternal(context);
}

export async function deactivateCycleGuard(context: common.Context): Promise<GuardResult<boolean>> {
  saveState(context, {
    enabled: false,
    phase: 'idle',
    statusMessage: '循环守护已停止'
  });

  try {
    await stopGuardStrategyIfStarted(QUOTA_STRATEGY_NAME);
    await stopGuardStrategyIfStarted(LOCK_STRATEGY_NAME);
    await removeGuardStrategyIfExists(QUOTA_STRATEGY_NAME);
    await removeGuardStrategyIfExists(LOCK_STRATEGY_NAME);
    return { ok: true, data: true, message: '循环守护已停止' };
  } catch {
    return { ok: false, data: false, message: '停止循环守护失败' };
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
  if (!state.enabled) {
    return;
  }

  if (strategyName === QUOTA_STRATEGY_NAME) {
    if (!isPhase(state, 'quota_running')) {
      return;
    }
    await startLockPhaseInternal(context);
    return;
  }

  if (strategyName === LOCK_STRATEGY_NAME) {
    if (isPhase(state, 'switching_to_quota')) {
      return;
    }
    saveState(context, {
      enabled: true,
      phase: 'lock_running',
      statusMessage: `锁定阶段运行中：${state.lockMinutes} 分钟`
    });
  }
}

export async function handleCycleStrategyStop(
  context: common.Context,
  strategyName: string
): Promise<void> {
  const state = getCurrentState(context);
  if (!state.enabled) {
    return;
  }

  if (strategyName === QUOTA_STRATEGY_NAME) {
    return;
  }

  if (strategyName === LOCK_STRATEGY_NAME) {
    if (!isPhase(state, 'lock_running')) {
      return;
    }
    await startQuotaPhaseInternal(context);
  }
}

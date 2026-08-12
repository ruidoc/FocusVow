import { common } from '@kit.AbilityKit';
import { appPicker, guardService } from '@kit.ScreenTimeGuardKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FocusPlan } from '../models/PlanModel';
import { ScheduledGuardSnapshot } from './ScheduledSessionPersistenceService';

export interface GuardResult<T> {
  ok: boolean;
  data?: T;
  message: string;
}

interface GuardErrorLike {
  code?: number;
  message?: string;
}

const DOMAIN: number = 0x0000;
const TAG: string = 'ScreenTimeGuard';

function toBusinessMessage(fallback: string): string {
  return fallback;
}

function formatGuardError(action: string, error: Object): string {
  if (error instanceof Error && error.message.length > 0) {
    return error.message;
  }

  const guardError = error as GuardErrorLike;
  const codeText = guardError.code !== undefined ? `code=${guardError.code}` : 'code=unknown';
  const messageText =
    guardError.message !== undefined && guardError.message.length > 0 ? guardError.message : String(error);
  return `${action}: ${codeText}, ${messageText}`;
}

function logGuardError(action: string, error: Object): void {
  hilog.error(DOMAIN, TAG, '%{public}s', formatGuardError(action, error));
}

function guardOperationError(action: string, error: Object): Error {
  return new Error(formatGuardError(action, error));
}

function getRestrictionType(mode: 'shield' | 'allow'): guardService.RestrictionType {
  if (mode === 'allow') {
    return guardService.RestrictionType.TRUSTLIST_TYPE;
  }

  return guardService.RestrictionType.BLOCKLIST_TYPE;
}

function isGuardErrorCode(error: GuardErrorLike, code: guardService.GuardServiceErrorCode): boolean {
  return error.code === code;
}

function shouldIgnoreStartError(error: GuardErrorLike): boolean {
  return isGuardErrorCode(error, guardService.GuardServiceErrorCode.STRATEGY_ALREADY_EXECUTED);
}

function shouldIgnoreStopError(error: GuardErrorLike): boolean {
  return isGuardErrorCode(error, guardService.GuardServiceErrorCode.STRATEGY_NOT_STARTED);
}

function shouldIgnoreRemoveError(error: GuardErrorLike): boolean {
  return isGuardErrorCode(error, guardService.GuardServiceErrorCode.NONEXISTENT_STRATEGY);
}

function createPlanGuardStrategy(plan: FocusPlan): guardService.GuardStrategy {
  return {
    name: plan.id,
    timeStrategy: {
      type: guardService.TimeStrategyType.START_END_TIME_TYPE,
      startTime: plan.startTime,
      endTime: plan.endTime,
      repeat: [...plan.repeatDays]
    },
    appInfo: {
      appTokens: [...plan.selectedTokens]
    },
    appRestrictionType: getRestrictionType(plan.mode)
  };
}

function createScheduledGuardStrategy(snapshot: ScheduledGuardSnapshot): guardService.GuardStrategy {
  return {
    name: `session_${snapshot.sessionId}`,
    timeStrategy: {
      type: guardService.TimeStrategyType.START_END_TIME_TYPE,
      startTime: snapshot.startTime,
      endTime: snapshot.endTime,
      repeat: [...snapshot.repeatDays]
    },
    appInfo: {
      appTokens: [...snapshot.selectedTokens]
    },
    appRestrictionType: getRestrictionType(snapshot.mode)
  };
}

async function addOrUpdateScheduledGuardStrategy(
  snapshot: ScheduledGuardSnapshot,
  existingNames?: Set<string>
): Promise<void> {
  const strategyName = `session_${snapshot.sessionId}`;
  const strategy = createScheduledGuardStrategy(snapshot);
  const hasExistingStrategy = existingNames?.has(strategyName) ?? false;

  if (hasExistingStrategy) {
    try {
      await guardService.updateGuardStrategy(strategyName, strategy);
    } catch (error) {
      throw guardOperationError(`updateGuardStrategy(${strategyName})`, error as Object);
    }
    return;
  }

  try {
    await guardService.addGuardStrategy(strategy);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (isGuardErrorCode(guardError, guardService.GuardServiceErrorCode.STRATEGY_NAME_ALREADY_EXIST)) {
      try {
        await guardService.updateGuardStrategy(strategyName, strategy);
      } catch (updateError) {
        throw guardOperationError(`updateGuardStrategy(${strategyName})`, updateError as Object);
      }
      return;
    }
    throw guardOperationError(`addGuardStrategy(${strategyName})`, error as Object);
  }
}

async function addOrUpdatePlanGuardStrategy(
  plan: FocusPlan,
  existingNames?: Set<string>
): Promise<void> {
  const strategy = createPlanGuardStrategy(plan);
  const hasExistingStrategy = existingNames?.has(plan.id) ?? false;

  if (hasExistingStrategy) {
    try {
      await guardService.updateGuardStrategy(plan.id, strategy);
    } catch (error) {
      throw guardOperationError(`updateGuardStrategy(${plan.id})`, error as Object);
    }
    return;
  }

  try {
    await guardService.addGuardStrategy(strategy);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (isGuardErrorCode(guardError, guardService.GuardServiceErrorCode.STRATEGY_NAME_ALREADY_EXIST)) {
      try {
        await guardService.updateGuardStrategy(plan.id, strategy);
      } catch (updateError) {
        throw guardOperationError(`updateGuardStrategy(${plan.id})`, updateError as Object);
      }
      return;
    }
    throw guardOperationError(`addGuardStrategy(${plan.id})`, error as Object);
  }
}

async function startPlanGuardStrategy(planId: string): Promise<void> {
  try {
    await guardService.startGuardStrategy(planId);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (!shouldIgnoreStartError(guardError)) {
      throw guardOperationError(`startGuardStrategy(${planId})`, error as Object);
    }
  }
}

async function stopPlanGuardStrategy(planId: string): Promise<void> {
  try {
    await guardService.stopGuardStrategy(planId);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (!shouldIgnoreStopError(guardError)) {
      throw guardOperationError(`stopGuardStrategy(${planId})`, error as Object);
    }
  }
}

async function removePlanGuardStrategyInternal(planId: string): Promise<void> {
  try {
    await guardService.removeGuardStrategy(planId);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (!shouldIgnoreRemoveError(guardError)) {
      throw guardOperationError(`removeGuardStrategy(${planId})`, error as Object);
    }
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function getUserAuthGranted(): Promise<boolean> {
  try {
    const authStatus = await guardService.getUserAuthStatus();
    return authStatus === guardService.AuthStatus.AUTH_GRANTED;
  } catch {
    return false;
  }
}

/** 弹框关闭后系统状态可能滞后，短轮询直到授权成功或超时 */
async function pollUserAuthGranted(maxRetry: number = 30, intervalMs: number = 200): Promise<boolean> {
  for (let i = 0; i < maxRetry; i++) {
    if (await getUserAuthGranted()) {
      return true;
    }
    await sleep(intervalMs);
  }
  return await getUserAuthGranted();
}

/** 查询屏时守护系统授权是否已授予 */
export async function checkScreenTimeAuthorized(): Promise<boolean> {
  return getUserAuthGranted();
}

export async function requestScreenTimeAuthorization(
  context: common.UIAbilityContext
): Promise<GuardResult<boolean>> {
  try {
    await guardService.requestUserAuth(context);
  } catch (error) {
    // 部分机型取消会抛错；仍以最终系统状态为准
    hilog.warn(DOMAIN, TAG, 'requestUserAuth: %{public}s', String(error));
  }
  const granted = await pollUserAuthGranted();
  return {
    ok: granted,
    data: granted,
    message: granted ? '已完成系统授权' : '请完成健康使用设备权限授权'
  };
}

export async function ensureScreenTimeAuthorization(
  context: common.UIAbilityContext
): Promise<GuardResult<boolean>> {
  if (await getUserAuthGranted()) {
    return { ok: true, data: true, message: '系统授权已开启' };
  }

  return requestScreenTimeAuthorization(context);
}

export async function chooseRestrictedApps(
  context: common.UIAbilityContext,
  selectedTokens: string[]
): Promise<GuardResult<string[]>> {
  try {
    const tokens = await appPicker.startAppPicker(context, { appTokens: selectedTokens });
    return {
      ok: true,
      data: tokens,
      message: tokens.length > 0 ? `已选择 ${tokens.length} 个应用` : '未选择应用'
    };
  } catch {
    return {
      ok: false,
      data: selectedTokens,
      message: toBusinessMessage('拉起应用选择失败')
    };
  }
}

/** 专注中打开系统「许可应用跳转页」，点击图标可启动白名单应用 */
export async function openTrustListAppForm(
  context: common.UIAbilityContext,
  selectedTokens: string[],
  subtitle: string = '点击图标打开应用'
): Promise<GuardResult<boolean>> {
  try {
    await appPicker.startAppForm(
      context,
      { appTokens: selectedTokens },
      subtitle,
      true
    );
    return { ok: true, data: true, message: '已打开白名单' };
  } catch {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('打开白名单失败')
    };
  }
}

export async function applyScreenRestriction(
  selectedTokens: string[],
  mode: 'shield' | 'allow'
): Promise<GuardResult<boolean>> {
  try {
    const restrictionType: guardService.RestrictionType = getRestrictionType(mode);

    await guardService.setAppsRestriction({ appTokens: selectedTokens }, restrictionType);
    return { ok: true, data: true, message: '专注已开始，限制已生效' };
  } catch {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('开启应用限制失败')
    };
  }
}

export async function releaseScreenRestriction(
  selectedTokens: string[],
  mode: 'shield' | 'allow'
): Promise<GuardResult<boolean>> {
  try {
    const restrictionType: guardService.RestrictionType = getRestrictionType(mode);

    await guardService.releaseAppsRestriction({ appTokens: selectedTokens }, restrictionType);
    return { ok: true, data: true, message: '已解除应用限制' };
  } catch {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('解除应用限制失败')
    };
  }
}

export async function syncScheduledSessionGuardStrategy(
  snapshot: ScheduledGuardSnapshot
): Promise<GuardResult<boolean>> {
  const strategyName = `session_${snapshot.sessionId}`;
  // 空 selectedTokens + allow = 全锁（TRUSTLIST 为空）；仍须注册并 start，不可移除
  const effectiveSnapshot: ScheduledGuardSnapshot = snapshot.selectedTokens.length === 0
    ? {
      sessionId: snapshot.sessionId,
      title: snapshot.title,
      startTime: snapshot.startTime,
      endTime: snapshot.endTime,
      repeatDays: snapshot.repeatDays,
      selectedTokens: [],
      mode: 'allow'
    }
    : snapshot;

  try {
    await addOrUpdateScheduledGuardStrategy(effectiveSnapshot);
    await startPlanGuardStrategy(strategyName);
    return {
      ok: true,
      data: true,
      message: effectiveSnapshot.selectedTokens.length === 0
        ? '屏时策略已注册（全锁兜底）'
        : '屏时策略已注册'
    };
  } catch (error) {
    logGuardError(`syncScheduledSessionGuardStrategy(${strategyName})`, error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('注册屏时策略失败')
    };
  }
}

export async function removeScheduledSessionGuardStrategy(sessionId: string): Promise<GuardResult<boolean>> {
  const strategyName = `session_${sessionId}`;
  try {
    await stopPlanGuardStrategy(strategyName);
    await removePlanGuardStrategyInternal(strategyName);
    return { ok: true, data: true, message: '屏时策略已移除' };
  } catch (error) {
    logGuardError(`removeScheduledSessionGuardStrategy(${strategyName})`, error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('移除屏时策略失败')
    };
  }
}

export async function syncPlanGuardStrategy(plan: FocusPlan): Promise<GuardResult<boolean>> {
  if (plan.selectedTokens.length === 0) {
    await stopPlanGuardStrategy(plan.id);
    await removePlanGuardStrategyInternal(plan.id);
    return { ok: true, data: true, message: '计划未选择应用，已移除系统契约策略' };
  }

  try {
    await addOrUpdatePlanGuardStrategy(plan);
    if (plan.enabled) {
      await startPlanGuardStrategy(plan.id);
      return { ok: true, data: true, message: '系统契约策略已更新并启用' };
    }

    await stopPlanGuardStrategy(plan.id);
    return { ok: true, data: true, message: '系统契约策略已更新并暂停' };
  } catch (error) {
    logGuardError(`syncPlanGuardStrategy(${plan.id})`, error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('同步系统契约策略失败')
    };
  }
}

export async function stopPlanGuardStrategyForWindow(planId: string): Promise<GuardResult<boolean>> {
  try {
    await stopPlanGuardStrategy(planId);
    return { ok: true, data: true, message: '已停止当前契约窗口' };
  } catch (error) {
    logGuardError(`stopPlanGuardStrategyForWindow(${planId})`, error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('停止契约策略失败')
    };
  }
}

export async function removePlanGuardStrategy(planId: string): Promise<GuardResult<boolean>> {
  try {
    await stopPlanGuardStrategy(planId);
    await removePlanGuardStrategyInternal(planId);
    return { ok: true, data: true, message: '系统契约策略已移除' };
  } catch (error) {
    logGuardError(`removePlanGuardStrategy(${planId})`, error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('移除系统契约策略失败')
    };
  }
}

function isSessionStrategyName(strategyName: string): boolean {
  return strategyName.startsWith('session_');
}

export async function removeAllSessionGuardStrategies(): Promise<GuardResult<boolean>> {
  try {
    const existingStrategies = await guardService.queryGuardStrategies();
    for (const strategy of existingStrategies) {
      if (!isSessionStrategyName(strategy.name)) {
        continue;
      }
      await stopPlanGuardStrategy(strategy.name);
      await removePlanGuardStrategyInternal(strategy.name);
    }
    return { ok: true, data: true, message: '已移除全部定时契约屏时策略' };
  } catch (error) {
    logGuardError('removeAllSessionGuardStrategies', error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('移除定时契约屏时策略失败')
    };
  }
}

/** 退出登录 / 卸载前：移除本应用注册的全部屏时策略（含 plan_、session_、周期守护等） */
export async function removeAllGuardStrategies(): Promise<GuardResult<boolean>> {
  try {
    const existingStrategies = await guardService.queryGuardStrategies();
    for (const strategy of existingStrategies) {
      await stopPlanGuardStrategy(strategy.name);
      await removePlanGuardStrategyInternal(strategy.name);
    }
    return { ok: true, data: true, message: '已移除全部屏时策略' };
  } catch (error) {
    logGuardError('removeAllGuardStrategies', error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('移除全部屏时策略失败')
    };
  }
}

export async function pruneSessionGuardStrategies(activeSessionIds: Set<string>): Promise<GuardResult<boolean>> {
  try {
    const existingStrategies = await guardService.queryGuardStrategies();
    for (const strategy of existingStrategies) {
      if (!isSessionStrategyName(strategy.name)) {
        continue;
      }
      const sessionId = strategy.name.replace('session_', '');
      if (activeSessionIds.has(sessionId)) {
        continue;
      }
      await stopPlanGuardStrategy(strategy.name);
      await removePlanGuardStrategyInternal(strategy.name);
    }
    return { ok: true, data: true, message: '已清理过期定时契约屏时策略' };
  } catch (error) {
    logGuardError('pruneSessionGuardStrategies', error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('清理过期定时契约屏时策略失败')
    };
  }
}

export async function syncAllPlanGuardStrategies(plans: FocusPlan[]): Promise<GuardResult<boolean>> {
  if (!(await getUserAuthGranted())) {
    return { ok: false, data: false, message: '未完成系统授权，跳过系统契约策略同步' };
  }

  try {
    const existingStrategies = await guardService.queryGuardStrategies();
    const existingNames = new Set<string>(
      existingStrategies.map((strategy: guardService.GuardStrategy) => strategy.name)
    );
    const activePlanIds = new Set<string>();

    for (const plan of plans) {
      activePlanIds.add(plan.id);
      if (plan.selectedTokens.length === 0) {
        await stopPlanGuardStrategy(plan.id);
        await removePlanGuardStrategyInternal(plan.id);
        continue;
      }

      await addOrUpdatePlanGuardStrategy(plan, existingNames);
      if (plan.enabled) {
        await startPlanGuardStrategy(plan.id);
      } else {
        await stopPlanGuardStrategy(plan.id);
      }
    }

    for (const strategy of existingStrategies) {
      if (strategy.name.startsWith('plan_') && !activePlanIds.has(strategy.name)) {
        await stopPlanGuardStrategy(strategy.name);
        await removePlanGuardStrategyInternal(strategy.name);
      }
    }

    return { ok: true, data: true, message: '系统契约策略已同步' };
  } catch (error) {
    logGuardError('syncAllPlanGuardStrategies', error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('同步全部系统契约策略失败')
    };
  }
}

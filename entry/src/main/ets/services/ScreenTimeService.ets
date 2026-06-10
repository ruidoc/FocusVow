import { common } from '@kit.AbilityKit';
import { appPicker, guardService } from '@kit.ScreenTimeGuardKit';
import { FocusPlan } from '../models/PlanModel';

export interface GuardResult<T> {
  ok: boolean;
  data?: T;
  message: string;
}

interface GuardErrorLike {
  code?: number;
}

function toBusinessMessage(fallback: string): string {
  return fallback;
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

async function addOrUpdatePlanGuardStrategy(
  plan: FocusPlan,
  existingNames?: Set<string>
): Promise<void> {
  const strategy = createPlanGuardStrategy(plan);
  const hasExistingStrategy = existingNames?.has(plan.id) ?? false;

  if (hasExistingStrategy) {
    await guardService.updateGuardStrategy(plan.id, strategy);
    return;
  }

  try {
    await guardService.addGuardStrategy(strategy);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (isGuardErrorCode(guardError, guardService.GuardServiceErrorCode.STRATEGY_NAME_ALREADY_EXIST)) {
      await guardService.updateGuardStrategy(plan.id, strategy);
      return;
    }
    throw new Error('Failed to add guard strategy.');
  }
}

async function startPlanGuardStrategy(planId: string): Promise<void> {
  try {
    await guardService.startGuardStrategy(planId);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (!shouldIgnoreStartError(guardError)) {
      throw new Error('Failed to start guard strategy.');
    }
  }
}

async function stopPlanGuardStrategy(planId: string): Promise<void> {
  try {
    await guardService.stopGuardStrategy(planId);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (!shouldIgnoreStopError(guardError)) {
      throw new Error('Failed to stop guard strategy.');
    }
  }
}

async function removePlanGuardStrategyInternal(planId: string): Promise<void> {
  try {
    await guardService.removeGuardStrategy(planId);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (!shouldIgnoreRemoveError(guardError)) {
      throw new Error('Failed to remove guard strategy.');
    }
  }
}

async function getUserAuthGranted(): Promise<boolean> {
  try {
    const authStatus = await guardService.getUserAuthStatus();
    return authStatus === guardService.AuthStatus.AUTH_GRANTED;
  } catch {
    return false;
  }
}

export async function requestScreenTimeAuthorization(
  context: common.UIAbilityContext
): Promise<GuardResult<boolean>> {
  try {
    await guardService.requestUserAuth(context);
    return { ok: true, data: true, message: '已完成系统授权' };
  } catch {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('系统授权失败，请确认 ACL 权限和 profile 已配置')
    };
  }
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
  } catch {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('同步系统契约策略失败')
    };
  }
}

export async function removePlanGuardStrategy(planId: string): Promise<GuardResult<boolean>> {
  try {
    await stopPlanGuardStrategy(planId);
    await removePlanGuardStrategyInternal(planId);
    return { ok: true, data: true, message: '系统契约策略已移除' };
  } catch {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('移除系统契约策略失败')
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
  } catch {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('同步全部系统契约策略失败')
    };
  }
}

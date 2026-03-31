import { common } from '@kit.AbilityKit';
import { appPicker, guardService } from '@kit.ScreenTimeGuardKit';

export interface GuardResult<T> {
  ok: boolean;
  data?: T;
  message: string;
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

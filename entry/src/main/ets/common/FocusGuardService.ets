import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { appPicker, guardService } from '@kit.ScreenTimeGuardKit';

export interface GuardResult<T> {
  ok: boolean;
  data?: T;
  message: string;
}

function toBusinessMessage(error: BusinessError | null | undefined, fallback: string): string {
  if (error?.message && error.message.length > 0) {
    return error.message;
  }
  return fallback;
}

export async function requestGuardAuthorization(context: common.UIAbilityContext): Promise<GuardResult<boolean>> {
  try {
    await guardService.requestUserAuth(context);
    return { ok: true, data: true, message: '已完成系统授权' };
  } catch (error) {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage(error, '系统授权失败，请确认 ACL 权限和 profile 已配置')
    };
  }
}

export async function pickRestrictedApps(
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
  } catch (error) {
    return {
      ok: false,
      data: selectedTokens,
      message: toBusinessMessage(error, '拉起应用选择失败')
    };
  }
}

export async function applyAppRestriction(selectedTokens: string[]): Promise<GuardResult<boolean>> {
  try {
    await guardService.setAppsRestriction(
      { appTokens: selectedTokens },
      guardService.RestrictionType.BLOCKLIST_TYPE
    );
    return { ok: true, data: true, message: '专注已开始，限制已生效' };
  } catch (error) {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage(error, '开启应用限制失败')
    };
  }
}

export async function releaseAppRestriction(selectedTokens: string[]): Promise<GuardResult<boolean>> {
  try {
    await guardService.releaseAppsRestriction(
      { appTokens: selectedTokens },
      guardService.RestrictionType.BLOCKLIST_TYPE
    );
    return { ok: true, data: true, message: '已解除应用限制' };
  } catch (error) {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage(error, '解除应用限制失败')
    };
  }
}

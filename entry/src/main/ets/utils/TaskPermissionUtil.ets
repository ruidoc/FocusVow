import { common } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';
import { showErrorToast } from '../common/Toast';
import { ensureScreenTimeAuthorization } from '../services/ScreenTimeService';
import { SettingsStore } from '../stores/SettingsStore';

export interface TaskPermissionOptions {
  entry_source?: string;
  screen_name?: string;
}

/**
 * 对齐 RN ensureTaskPermission：开始专注 / 同步定时 / 选应用前，先确保健康使用设备权限。
 * @returns true 已授权；false 未授权（已尝试拉起系统授权）
 */
export async function ensureTaskPermission(
  context: common.UIAbilityContext,
  uiContext?: UIContext,
  _options?: TaskPermissionOptions,
): Promise<boolean> {
  const authResult = await ensureScreenTimeAuthorization(context);
  SettingsStore.updateAuthorization(context, authResult.ok, authResult.message);
  if (authResult.ok) {
    return true;
  }
  const message =
    authResult.message.length > 0
      ? authResult.message
      : '请完成健康使用设备权限授权';
  if (uiContext) {
    showErrorToast(message, uiContext);
  }
  return false;
}

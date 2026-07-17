import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'NotifyPermission';
const ERR_USER_REFUSED: number = 1600004;

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms);
  });
}

/**
 * 通知权限：
 * - 点开只拉系统弹框，开关先保持关
 * - 弹框结束后（或关闭过程中）用 isNotificationEnabled 读真实状态
 * - 只有读到已开启才算开
 */
export class NotificationPermissionService {
  static async isNotifyEnabled(): Promise<boolean> {
    try {
      return notificationManager.isNotificationEnabledSync() === true;
    } catch (_syncError) {
      try {
        return (await notificationManager.isNotificationEnabled()) === true;
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'isNotificationEnabled failed: %{public}s', String(error));
        return false;
      }
    }
  }

  /**
   * 弹系统授权框，并在结束后读取真实权限。
   * 注意：部分机型 Promise 可能在弹框出现时就 resolve，因此 resolve 后会轮询读取，
   * 直到用户关框且系统状态变为已授权，或超时 / 明确拒绝。
   */
  static async requestNotify(context: common.UIAbilityContext): Promise<boolean> {
    if (await NotificationPermissionService.isNotifyEnabled()) {
      return true;
    }
    try {
      await notificationManager.requestEnableNotification(context);
      hilog.info(DOMAIN, TAG, 'requestEnableNotification promise settled, start polling');
    } catch (error) {
      const biz = error as BusinessError;
      if (biz.code === ERR_USER_REFUSED) {
        hilog.info(DOMAIN, TAG, 'user refused notification');
        return false;
      }
      hilog.warn(DOMAIN, TAG, 'requestEnableNotification failed: %{public}s', String(error));
    }
    // 等用户操作完弹框：以系统查询为准，同意才会变成 true
    return await NotificationPermissionService.pollNotifyEnabled();
  }

  /** 轮询真实权限（覆盖「Promise 先结束、用户还在弹框里」的情况） */
  static async pollNotifyEnabled(maxRetry: number = 40, intervalMs: number = 200): Promise<boolean> {
    for (let i = 0; i < maxRetry; i++) {
      const enabled = await NotificationPermissionService.isNotifyEnabled();
      hilog.info(DOMAIN, TAG, 'poll #%{public}s enabled=%{public}s', String(i), String(enabled));
      if (enabled) {
        return true;
      }
      await sleep(intervalMs);
    }
    return false;
  }

  /** 打开系统通知管理半模态，关闭后再读权限 */
  static async openSettingsAndRead(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await notificationManager.openNotificationSettings(context);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'openNotificationSettings failed: %{public}s', String(error));
    }
    return await NotificationPermissionService.pollNotifyEnabled(20, 150);
  }
}

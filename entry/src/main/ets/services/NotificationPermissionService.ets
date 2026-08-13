import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'NotifyPermission';
const ERR_USER_REFUSED: number = 1600004;
const ERR_SETTINGS_ALREADY_OPEN: number = 1600018;

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms);
  });
}

class SettingJson {
  bannerEnabled?: boolean;
}

export class NotifyStatus {
  enabled: boolean = false;
  bannerEnabled: boolean = false;
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
      return (await notificationManager.isNotificationEnabled()) === true;
    } catch (_asyncError) {
      try {
        return notificationManager.isNotificationEnabledSync() === true;
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'isNotificationEnabled failed: %{public}s', String(error));
        return false;
      }
    }
  }

  /** 横幅提醒是否开启；读不到时默认视为开，避免误报关闭 */
  static async isBannerEnabled(): Promise<boolean> {
    try {
      const setting = await notificationManager.getNotificationSetting();
      const raw: SettingJson = JSON.parse(JSON.stringify(setting)) as SettingJson;
      if (raw.bannerEnabled !== undefined) {
        return raw.bannerEnabled === true;
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'getNotificationSetting failed: %{public}s', String(error));
    }
    try {
      const slot = await notificationManager.getSlot(notificationManager.SlotType.SERVICE_INFORMATION);
      if (slot.notificationLevel !== undefined) {
        return slot.notificationLevel === notificationManager.SlotLevel.LEVEL_HIGH;
      }
    } catch (_slotError) {
      // 渠道尚未创建
    }
    return true;
  }

  static async readStatus(): Promise<NotifyStatus> {
    const status = new NotifyStatus();
    status.enabled = await NotificationPermissionService.isNotifyEnabled();
    status.bannerEnabled = status.enabled ? await NotificationPermissionService.isBannerEnabled() : false;
    return status;
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
    await sleep(300);
    return await NotificationPermissionService.pollUntilEnabled();
  }

  /** 等待变为已开启（开权限弹框） */
  static async pollUntilEnabled(maxRetry: number = 60, intervalMs: number = 250): Promise<boolean> {
    for (let i = 0; i < maxRetry; i++) {
      const enabled = await NotificationPermissionService.isNotifyEnabled();
      hilog.info(DOMAIN, TAG, 'poll-on #%{public}s enabled=%{public}s', String(i), String(enabled));
      if (enabled) {
        return true;
      }
      await sleep(intervalMs);
    }
    return false;
  }

  static async pollUntilStatusChanged(
    previous: NotifyStatus,
    maxRetry: number = 80,
    intervalMs: number = 250
  ): Promise<NotifyStatus> {
    for (let i = 0; i < maxRetry; i++) {
      const now = await NotificationPermissionService.readStatus();
      hilog.info(DOMAIN, TAG, 'poll-status #%{public}s notify %{public}s->%{public}s banner %{public}s->%{public}s',
        String(i), String(previous.enabled), String(now.enabled),
        String(previous.bannerEnabled), String(now.bannerEnabled));
      if (now.enabled !== previous.enabled || now.bannerEnabled !== previous.bannerEnabled) {
        return now;
      }
      await sleep(intervalMs);
    }
    return await NotificationPermissionService.readStatus();
  }

  static async openSettings(context: common.UIAbilityContext): Promise<void> {
    try {
      await notificationManager.openNotificationSettings(context);
    } catch (error) {
      const biz = error as BusinessError;
      if (biz.code === ERR_SETTINGS_ALREADY_OPEN) {
        hilog.info(DOMAIN, TAG, 'notification settings already open');
        return;
      }
      hilog.warn(DOMAIN, TAG, 'openNotificationSettings failed: %{public}s', String(error));
    }
  }

  /** 打开系统通知管理，等通知总开关或横幅状态变化后再读 */
  static async openSettingsAndRead(context: common.UIAbilityContext): Promise<NotifyStatus> {
    const previous = await NotificationPermissionService.readStatus();
    await NotificationPermissionService.openSettings(context);
    await sleep(300);
    return await NotificationPermissionService.pollUntilStatusChanged(previous);
  }
}

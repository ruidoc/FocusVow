import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { init, onProfileSignIn, onProfileSignOff } from '@umeng/analytics';
import { PushAgent } from '@umeng/push';
import { UmengConfig } from '../config/UmengConfig';
import { readStoredString, writeStoredString } from './PreferencesService';

const DOMAIN: number = 0x0000;
const TAG: string = 'UmengSdk';
const PRIVACY_AGREED_KEY: string = 'umeng.privacyAgreed';

let sdkInitialized: boolean = false;

export class UmengSdkService {
  static isPrivacyAgreed(context: common.Context): boolean {
    return readStoredString(context, PRIVACY_AGREED_KEY, '0') === '1';
  }

  static markPrivacyAgreed(context: common.Context): void {
    writeStoredString(context, PRIVACY_AGREED_KEY, '1');
  }

  static ensureInitialized(context: common.Context): void {
    if (sdkInitialized || !UmengSdkService.isPrivacyAgreed(context)) {
      return;
    }
    if (UmengConfig.APP_MESSAGE_SECRET.length === 0) {
      hilog.warn(DOMAIN, TAG, 'APP_MESSAGE_SECRET is empty, skip umeng init');
      return;
    }

    init();
    sdkInitialized = true;
    hilog.info(DOMAIN, TAG, 'umeng sdk initialized');
  }

  static enablePushNotification(context: common.UIAbilityContext): void {
    if (!sdkInitialized) {
      return;
    }

    PushAgent.enableNotification(context, (result: Record<string, string>) => {
      hilog.info(DOMAIN, TAG, 'push notification permission: %{public}s', JSON.stringify(result));
      void UmengSdkService.logPushDiagnostics();
    });
  }

  /** 用于确认厂商离线通道是否就绪：third token 成功才支持杀进程后收推送 */
  static async logPushDiagnostics(): Promise<void> {
    if (!sdkInitialized) {
      return;
    }

    try {
      const notifyState = await PushAgent.isNotificationEnabled();
      hilog.info(DOMAIN, TAG, 'notification switch: %{public}s', JSON.stringify(notifyState));
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'notification switch check failed: %{public}s', String(error));
    }

    try {
      const thirdToken = await PushAgent.getThirdToken();
      hilog.info(DOMAIN, TAG, 'huawei third token: %{public}s', JSON.stringify(thirdToken));
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'huawei third token failed: %{public}s', String(error));
    }
  }

  static bindUserAlias(userId: string): void {
    if (!sdkInitialized || userId.length === 0) {
      return;
    }

    PushAgent.setAlias(userId, UmengConfig.PUSH_ALIAS_TYPE, (result: Record<string, string>) => {
      hilog.info(DOMAIN, TAG, 'push alias bound: %{public}s', JSON.stringify(result));
    });
    onProfileSignIn(UmengConfig.PUSH_ALIAS_TYPE, userId);
  }

  static clearUserAlias(): void {
    if (!sdkInitialized) {
      return;
    }

    onProfileSignOff();
  }
}

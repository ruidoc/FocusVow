import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { init, onProfileSignIn, onProfileSignOff } from '@umeng/analytics';
import { PushAgent } from '@umeng/push';
import { DuoPushHandler } from './DuoPushHandler';
import { UmengConfig } from '../config/UmengConfig';
import { readStoredString, writeStoredString } from './PreferencesService';

const DOMAIN: number = 0x0000;
const TAG: string = 'UmengSdk';
const PRIVACY_AGREED_KEY: string = 'umeng.privacyAgreed';

let sdkInitialized: boolean = false;
let lastUmengDeviceToken: string = '';

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

  static getLastUmengDeviceToken(): string {
    return lastUmengDeviceToken;
  }

  static handlePushInitCallback(data: Record<string, string>): void {
    hilog.info(DOMAIN, TAG, 'push init callback: %{public}s', JSON.stringify(data));

    const code = String(data['code'] ?? '');
    if (code.length > 0 && code !== '0') {
      return;
    }

    const umengToken = String(data['data'] ?? data['device_token'] ?? '');
    if (umengToken.length > 0) {
      lastUmengDeviceToken = umengToken;
      hilog.info(DOMAIN, TAG, 'umeng device token (后台测试用这个): %{public}s', umengToken);
    }

    setTimeout(() => {
      void UmengSdkService.logPushDiagnostics();
    }, 1500);
  }

  static setupPushListeners(): void {
    PushAgent.onNotificationMessage((payload: Record<string, string>) => {
      hilog.info(DOMAIN, TAG, 'notification arrived (fg/bg): %{public}s', JSON.stringify(payload));
      const customText = String(payload['custom'] ?? payload['body'] ?? '');
      void DuoPushHandler.handlePayload(
        DuoPushHandler.parsePushPayload(payload, customText.length > 0 ? customText : undefined)
      );
    });
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
      hilog.info(DOMAIN, TAG, 'huawei third token (厂商通道用,勿填测试设备): %{public}s', JSON.stringify(thirdToken));
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

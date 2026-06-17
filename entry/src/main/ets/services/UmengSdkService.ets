import { common, wantAgent, Want, WantAgent } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { init, onProfileSignIn, onProfileSignOff } from '@umeng/analytics';
import { PushAgent } from '@umeng/push';
import { AppContextHolder } from '../common/AppContextHolder';
import { DuoPushHandler } from './DuoPushHandler';
import { UmengConfig } from '../config/UmengConfig';
import { readStoredString, writeStoredString } from './PreferencesService';
import { StoreKeys } from '../stores/StoreKeys';

const DOMAIN: number = 0x0000;
const TAG: string = 'UmengSdk';
const PRIVACY_AGREED_KEY: string = 'umeng.privacyAgreed';

let sdkInitialized: boolean = false;
let lastUmengDeviceToken: string = '';

interface PushMessageParts {
  extra: Record<string, string>;
  customText: string;
  title: string;
  text: string;
  msgId: string;
}

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

  // 监听友盟推送消息
  static setupPushListeners(): void {
    PushAgent.onNotificationMessage((payload: Record<string, string>) => {
      hilog.info(DOMAIN, TAG, 'notification arrived (fg/bg): %{public}s', JSON.stringify(payload));
      const parts = UmengSdkService.parseNotificationParts(payload as Record<string, Object>);
      const isForeground = UmengSdkService.isAppForeground();
      if (!isForeground) {
        void UmengSdkService.publishLocalNotification(parts);
      }
      void DuoPushHandler.handlePayload(
        DuoPushHandler.parsePushPayload(parts.extra, parts.customText.length > 0 ? parts.customText : undefined),
        {
          isForeground,
          title: parts.title,
          text: parts.text
        }
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

  static handleLaunchWant(want: Want, hostContext: common.UIAbilityContext): void {
    void PushAgent.onNewWant(want);
    void DuoPushHandler.processPendingBreach(hostContext);

    const pushExtra = UmengSdkService.extractPushExtraFromWant(want);
    if (!pushExtra) {
      return;
    }

    void DuoPushHandler.handlePayload(
      DuoPushHandler.parsePushPayload(pushExtra),
      { isForeground: AppStorage.get<boolean>(StoreKeys.AppIsForeground) ?? false },
      hostContext
    );
  }

  static extractPushExtraFromWant(want: Want): Record<string, string> | null {
    const params = want.parameters;
    if (!params) {
      return null;
    }

    const payloadText = String(params['focusvow_local_push'] ?? '');
    if (payloadText.length === 0) {
      return null;
    }

    try {
      const parsed = JSON.parse(payloadText) as Record<string, string>;
      return parsed;
    } catch {
      return null;
    }
  }

  private static isAppForeground(): boolean {
    return AppStorage.get<boolean>(StoreKeys.AppIsForeground) ?? true;
  }

  private static async publishLocalNotification(parts: PushMessageParts): Promise<void> {
    const title = parts.title.length > 0 ? parts.title : '专注契约提醒';
    const text = parts.text.length > 0 ? parts.text : '你有一条新的专注通知';
    const request: notificationManager.NotificationRequest = {
      id: UmengSdkService.createNotificationId(parts.msgId),
      notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title,
          text
        }
      }
    };
    if (parts.msgId.length > 0) {
      request.appMessageId = parts.msgId;
    }

    const hostContext = AppContextHolder.getAbility();
    if (hostContext) {
      const launchAgent: WantAgent | null = await UmengSdkService.buildNotificationWantAgent(hostContext, parts);
      if (launchAgent) {
        request.wantAgent = launchAgent;
      }
    }

    try {
      await notificationManager.publish(request);
      hilog.info(DOMAIN, TAG, 'local notification published: %{public}s', JSON.stringify({
        title,
        text,
        msg_id: parts.msgId
      }));
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'local notification publish failed: %{public}s', String(error));
    }
  }

  private static async buildNotificationWantAgent(
    context: common.UIAbilityContext,
    parts: PushMessageParts
  ): Promise<WantAgent | null> {
    const payload = UmengSdkService.clonePushPayload(parts);
    const wantParameters: Record<string, Object> = {
      'focusvow_local_push': JSON.stringify(payload)
    };

    const wantInfo: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName: context.applicationInfo.name,
        abilityName: 'EntryAbility',
        parameters: wantParameters
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: UmengSdkService.createNotificationId(parts.msgId),
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };

    try {
      return await wantAgent.getWantAgent(wantInfo);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'build notification wantAgent failed: %{public}s', String(error));
      return null;
    }
  }

  private static clonePushPayload(parts: PushMessageParts): Record<string, string> {
    const payload: Record<string, string> = {};
    const keys = Object.keys(parts.extra);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      payload[key] = parts.extra[key];
    }
    if (parts.customText.length > 0) {
      payload['custom'] = parts.customText;
    }
    return payload;
  }

  private static parseNotificationParts(payload: Record<string, Object>): PushMessageParts {
    const body = UmengSdkService.asObjectRecord(payload['body']);
    const extra = UmengSdkService.asObjectRecord(payload['extra']);
    const extraRecord = UmengSdkService.toStringRecord(extra ?? payload);
    const customFromBody = body ? String(body['custom'] ?? '') : '';
    const customFromPayload = String(payload['custom'] ?? '');
    const fallbackBodyText = body ? '' : String(payload['body'] ?? '');

    return {
      extra: Object.keys(extraRecord).length > 0 ? extraRecord : UmengSdkService.toStringRecord(payload),
      customText: customFromBody.length > 0
        ? customFromBody
        : (customFromPayload.length > 0 ? customFromPayload : fallbackBodyText),
      title: body ? String(body['title'] ?? '') : String(payload['title'] ?? ''),
      text: body ? String(body['text'] ?? body['message'] ?? '') : String(payload['text'] ?? payload['message'] ?? ''),
      msgId: String(payload['msg_id'] ?? payload['message_id'] ?? '')
    };
  }

  private static asObjectRecord(value: Object | undefined): Record<string, Object> | null {
    if (value === undefined || value === null) {
      return null;
    }
    if (typeof value === 'string') {
      if (value.length === 0) {
        return null;
      }
      try {
        return JSON.parse(value) as Record<string, Object>;
      } catch {
        return null;
      }
    }
    return value as Record<string, Object>;
  }

  private static toStringRecord(record: Record<string, Object>): Record<string, string> {
    const result: Record<string, string> = {};
    const keys = Object.keys(record);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = record[key];
      if (value === undefined || value === null) {
        continue;
      }
      result[key] = typeof value === 'object' ? JSON.stringify(value) : String(value);
    }
    return result;
  }

  private static createNotificationId(msgId: string): number {
    if (msgId.length === 0) {
      return Date.now() % 2147483647;
    }

    let hash = 0;
    for (let i = 0; i < msgId.length; i++) {
      hash = ((hash * 31) + msgId.charCodeAt(i)) % 2147483647;
    }
    return hash > 0 ? hash : Date.now() % 2147483647;
  }
}

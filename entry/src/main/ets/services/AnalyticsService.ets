import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getAppVersion } from '../common/AppInfo';
import { AppContextHolder } from '../common/AppContextHolder';
import { PostHogConfig } from '../config/PostHogConfig';
import { ApiConfig } from '../config/ApiConfig';
import { createEmptyUserInfo, UserInfo } from '../models/UserModel';
import { StoreKeys } from '../stores/StoreKeys';
import { ensureOnboardingDeviceId } from './OnboardingApiService';

const DOMAIN: number = 0x0000;
const TAG: string = 'Analytics';

export type LoginMethod = 'email' | 'wechat' | 'huawei';

let cachedAppVersion: string = 'unknown';
let initDone: boolean = false;

function resolveContext(context?: common.Context | null): common.Context | null {
  if (context) {
    return context;
  }
  return AppContextHolder.get();
}

function getAppEnv(): string {
  return ApiConfig.BASE_URL.includes('/dev-api') ? 'development' : 'production';
}

function normalizeEventName(eventName: string): string {
  if (eventName.startsWith('$')) {
    return eventName;
  }
  return eventName.startsWith('focus_') ? eventName : `focus_${eventName}`;
}

function getUserInfo(): UserInfo {
  return AppStorage.get<UserInfo>(StoreKeys.UserInfo) ?? createEmptyUserInfo();
}

function isLoggedIn(): boolean {
  return AppStorage.get<boolean>(StoreKeys.UserIsLoggedIn) ?? false;
}

function mergeProperties(
  base: Record<string, Object>,
  extra?: Record<string, Object>
): Record<string, Object> {
  if (!extra) {
    return base;
  }
  const merged: Record<string, Object> = {};
  const baseKeys = Object.keys(base);
  for (let i = 0; i < baseKeys.length; i++) {
    const key = baseKeys[i];
    merged[key] = base[key];
  }
  const extraKeys = Object.keys(extra);
  for (let j = 0; j < extraKeys.length; j++) {
    const extraKey = extraKeys[j];
    merged[extraKey] = extra[extraKey];
  }
  return merged;
}

export class AnalyticsService {
  static ensureInitialized(context?: common.Context | null): void {
    if (initDone) {
      return;
    }
    initDone = true;
    const ctx = resolveContext(context);
    if (ctx) {
      ensureOnboardingDeviceId(ctx);
    }
    void getAppVersion().then((version: string) => {
      cachedAppVersion = version;
    });
  }

  static trackEvent(
    eventName: string,
    properties?: Record<string, Object>,
    context?: common.Context | null
  ): void {
    AnalyticsService.ensureInitialized(context);
    const ctx = resolveContext(context);
    if (!ctx) {
      return;
    }
    void AnalyticsService.sendCapture(eventName, AnalyticsService.buildBaseProperties(ctx, properties), ctx);
  }

  static identifyUser(
    userId: string,
    properties?: Record<string, Object>,
    context?: common.Context | null
  ): void {
    if (userId.length === 0) {
      return;
    }
    AnalyticsService.ensureInitialized(context);
    const ctx = resolveContext(context);
    if (!ctx) {
      return;
    }
    const anonId = ensureOnboardingDeviceId(ctx);
    const setProps: Record<string, Object> = {
      'user_id': userId,
      'app_version': cachedAppVersion,
      'app_env': getAppEnv(),
      'platform': 'harmony',
      'device_id': anonId
    };
    if (properties) {
      const keys = Object.keys(properties);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        setProps[key] = properties[key];
      }
    }
    const identifyProps: Record<string, Object> = {
      'distinct_id': userId,
      '$anon_distinct_id': anonId,
      '$set': setProps
    };
    void AnalyticsService.sendCapture('$identify', identifyProps, ctx);
  }

  static resetUser(context?: common.Context | null): void {
    AnalyticsService.ensureInitialized(context);
    hilog.info(DOMAIN, TAG, 'user reset');
  }

  static trackLoginCompleted(
    method: LoginMethod,
    context?: common.Context | null,
    properties?: Record<string, Object>
  ): void {
    const props: Record<string, Object> = {
      'login_method': method
    };
    AnalyticsService.trackEvent('login_completed', mergeProperties(props, properties), context);
  }

  static trackRegisterCompleted(
    method: LoginMethod,
    context?: common.Context | null,
    properties?: Record<string, Object>
  ): void {
    const props: Record<string, Object> = {
      'register_method': method
    };
    AnalyticsService.trackEvent('register_completed', mergeProperties(props, properties), context);
  }

  static trackLogout(context?: common.Context | null): void {
    AnalyticsService.trackEvent('logout', undefined, context);
    AnalyticsService.resetUser(context);
  }

  private static buildBaseProperties(
    context: common.Context,
    extra?: Record<string, Object>
  ): Record<string, Object> {
    const userInfo = getUserInfo();
    const userId = userInfo.id;
    const deviceId = ensureOnboardingDeviceId(context);
    const distinctId = userId.length > 0 ? userId : deviceId;
    const base: Record<string, Object> = {
      'distinct_id': distinctId,
      'user_id': userId.length > 0 ? userId : 'anonymous',
      'app_version': cachedAppVersion,
      'app_env': getAppEnv(),
      'platform': 'harmony',
      'event_origin': 'harmony',
      'is_logged_in': isLoggedIn(),
      'device_id': deviceId
    };
    return mergeProperties(base, extra);
  }

  private static async sendCapture(
    eventName: string,
    properties: Record<string, Object>,
    _context: common.Context
  ): Promise<void> {
    const url = `${PostHogConfig.HOST}/capture/`;
    const payload: Record<string, Object> = {
      'api_key': PostHogConfig.API_KEY,
      'event': normalizeEventName(eventName),
      'properties': properties,
      'timestamp': new Date().toISOString()
    };
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify(payload),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 8000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        hilog.warn(DOMAIN, TAG, 'capture failed http=%{public}d event=%{public}s',
          response.responseCode, eventName);
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'capture error event=%{public}s err=%{public}s',
        eventName, String(error));
    } finally {
      httpRequest.destroy();
    }
  }
}

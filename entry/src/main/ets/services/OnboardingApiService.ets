import { common } from '@kit.AbilityKit';
import { getAppVersion, getDeviceModel } from '../common/AppInfo';
import { AppContextHolder } from '../common/AppContextHolder';
import { PageRoutes } from '../router/PageRoutes';
import { ApiEnvelope } from '../models/UserModel';
import { HttpService } from './HttpService';
import {
  readStoredString,
  writeStoredString
} from './PreferencesService';
import { SettingsStore } from '../stores/SettingsStore';
import { UserStore } from '../stores/UserStore';
import { markFirstFocusPromptDone } from './FirstFocusPromptService';
import deviceInfo from '@ohos.deviceInfo';

const COMPLETED_KEY: string = 'onboarding.completed';
const DEVICE_ID_KEY: string = 'analytics.device_id';

function resolveContext(context?: common.Context | null): common.Context | null {
  if (context) {
    return context;
  }
  return AppContextHolder.get();
}

export function isOnboardingCompleted(context?: common.Context | null): boolean {
  const ctx = resolveContext(context);
  if (!ctx) {
    return false;
  }
  return readStoredString(ctx, COMPLETED_KEY, '') === '1';
}

export function markOnboardingCompleted(context?: common.Context | null): void {
  const ctx = resolveContext(context);
  if (!ctx) {
    return;
  }
  writeStoredString(ctx, COMPLETED_KEY, '1');
}

/** 冷启动首页：未完成引导直接进欢迎页，避免先落到 MainTab 还能返回 */
export function resolveAppLaunchPage(context: common.UIAbilityContext): string {
  UserStore.hydrate(context);
  SettingsStore.hydrate(context);
  if (isOnboardingCompleted(context)) {
    return PageRoutes.FocusHome;
  }
  if (UserStore.isLoggedIn() || SettingsStore.getState().hasAuthorized) {
    markOnboardingCompleted(context);
    return PageRoutes.FocusHome;
  }
  return PageRoutes.Welcome;
}

export function ensureOnboardingDeviceId(context: common.Context): string {
  const existing = readStoredString(context, DEVICE_ID_KEY, '');
  if (existing.length > 0) {
    return existing;
  }
  const generated =
    `hm_${Date.now().toString(36)}_${Math.floor(Math.random() * 1e9).toString(36)}`;
  writeStoredString(context, DEVICE_ID_KEY, generated);
  return generated;
}

function parseOnboardingEnvelope(response: ApiEnvelope): Record<string, Object> | null {
  if (response.statusCode === 200 && response.data) {
    return response.data;
  }
  const raw = (response as Object) as Record<string, Object>;
  if (
    raw['identity'] ||
    raw['goal'] ||
    raw['finished'] ||
    raw['id']
  ) {
    return raw;
  }
  return null;
}

export async function fetchHasOnboardingProfile(context: common.Context): Promise<boolean> {
  try {
    const deviceId = ensureOnboardingDeviceId(context);
    const query: Record<string, string> = {
      'device_id': deviceId
    };
    const response = await HttpService.getWithQuery('/onboarding', query, false);
    const payload = parseOnboardingEnvelope(response);
    if (!payload) {
      return false;
    }
    return hasOnboardingProfileFromData(payload);
  } catch (_e) {
    return false;
  }
}

export async function fetchHasOnboardingProfileByUserId(
  context: common.Context,
  userId: string
): Promise<boolean> {
  if (userId.length === 0) {
    return false;
  }
  try {
    const query: Record<string, string> = {
      'user_id': userId
    };
    const response = await HttpService.getWithQuery('/onboarding', query, false);
    const payload = parseOnboardingEnvelope(response);
    if (!payload) {
      return false;
    }
    return hasOnboardingProfileFromData(payload);
  } catch (_e) {
    return false;
  }
}

function hasOnboardingProfileFromData(data: Record<string, Object>): boolean {
  const identity = String(data['identity'] ?? '');
  const goal = String(data['goal'] ?? '');
  const finishedRaw = data['finished'];
  const finished =
    finishedRaw === true ||
    finishedRaw === 'true' ||
    finishedRaw === 1 ||
    finishedRaw === '1';
  return finished || (identity.length > 0 && goal.length > 0);
}

/** 欢迎页老用户登录后：用登录返回的 user_id 查画像。true=进首页 */
export async function routeAfterWelcomeOldUserLogin(
  context: common.Context,
  userId: string
): Promise<boolean> {
  if (userId.length === 0) {
    return false;
  }
  const hasProfile = await fetchHasOnboardingProfileByUserId(context, userId);
  if (hasProfile) {
    markOnboardingCompleted(context);
    markFirstFocusPromptDone(context);
  }
  return hasProfile;
}

/**
 * 冷启动 / 回首页：对齐 RN app/index，有 onboarding 画像则标记完成并跳过首次专注引导。
 */
export async function reconcileOnboardingOnLaunch(context: common.Context): Promise<void> {
  const uiContext = context as common.UIAbilityContext;
  UserStore.hydrate(uiContext);
  SettingsStore.hydrate(uiContext);

  let hasProfile = false;
  if (UserStore.isLoggedIn()) {
    const userId = UserStore.getUserInfo().id.trim();
    if (userId.length > 0) {
      hasProfile = await fetchHasOnboardingProfileByUserId(context, userId);
    }
  } else if (!isOnboardingCompleted(context)) {
    hasProfile = await fetchHasOnboardingProfile(context);
  }

  if (hasProfile) {
    markOnboardingCompleted(context);
    markFirstFocusPromptDone(context);
    return;
  }

  if (!isOnboardingCompleted(context)) {
    if (UserStore.isLoggedIn() || SettingsStore.getState().hasAuthorized) {
      markOnboardingCompleted(context);
    }
  }
}

export class OnboardingApiService {
  static async reportWelcomeView(context: common.Context): Promise<void> {
    try {
      const deviceId = ensureOnboardingDeviceId(context);
      const version = await getAppVersion();
      const body: Record<string, Object> = {
        'device_id': deviceId,
        'device': getDeviceModel(),
        'os_version': String(deviceInfo.osFullName ?? ''),
        'platform': 'harmony',
        'app_version': version
      };
      await HttpService.post('/onboarding/welcome-view', body, false);
    } catch (error) {
      console.warn(`[Onboarding] welcome-view failed: ${String(error)}`);
    }
  }

  static async upsert(
    context: common.Context,
    payload: Record<string, Object>
  ): Promise<void> {
    try {
      const deviceId = ensureOnboardingDeviceId(context);
      const version = await getAppVersion();
      const body: Record<string, Object> = {
        'device_id': deviceId,
        'device': getDeviceModel(),
        'os_version': String(deviceInfo.osFullName ?? ''),
        'platform': 'harmony',
        'app_version': version
      };
      const keys = Object.keys(payload);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        body[key] = payload[key];
      }
      await HttpService.post('/onboarding', body, false);
    } catch (error) {
      console.warn(`[Onboarding] upsert failed: ${String(error)}`);
    }
  }

  /** 登录后绑定当前设备 onboarding 到 user_id（对齐 RN bindOnboardingToUser） */
  static async bindToUser(context: common.Context, userId: string): Promise<void> {
    const trimmed = String(userId || '').trim();
    if (trimmed.length === 0) {
      return;
    }
    try {
      const deviceId = ensureOnboardingDeviceId(context);
      if (deviceId.length === 0) {
        return;
      }
      const body: Record<string, Object> = {
        'device_id': deviceId,
        'user_id': trimmed,
        'device': getDeviceModel()
      };
      await HttpService.post('/onboarding/bind', body, true, true, context);
    } catch (error) {
      console.warn(`[Onboarding] bind failed: ${String(error)}`);
    }
  }
}

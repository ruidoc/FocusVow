import { common } from '@kit.AbilityKit';
import { getAppVersion, getDeviceModel } from '../common/AppInfo';
import { AppContextHolder } from '../common/AppContextHolder';
import { PageRoutes } from '../router/PageRoutes';
import { HttpService } from './HttpService';
import {
  readStoredString,
  writeStoredString
} from './PreferencesService';
import { SettingsStore } from '../stores/SettingsStore';
import { UserStore } from '../stores/UserStore';
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

export async function fetchHasOnboardingProfile(context: common.Context): Promise<boolean> {
  try {
    const deviceId = ensureOnboardingDeviceId(context);
    const query: Record<string, string> = {
      'device_id': deviceId
    };
    const response = await HttpService.getWithQuery('/onboarding', query, false);
    if (response.statusCode !== 200 || !response.data) {
      return false;
    }
    const data = response.data as Record<string, Object>;
    const identity = String(data['identity'] ?? '');
    const goal = String(data['goal'] ?? '');
    const finished = data['finished'] === true || data['finished'] === 'true';
    return finished || (identity.length > 0 && goal.length > 0);
  } catch (_e) {
    return false;
  }
}

export class OnboardingApiService {
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
}

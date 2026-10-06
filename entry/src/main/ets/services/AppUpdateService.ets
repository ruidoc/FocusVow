import { common, Want } from '@kit.AbilityKit';
import { getAppVersion } from '../common/AppInfo';
import { HttpService } from './HttpService';
import {
  readStoredString,
  writeStoredString,
} from './PreferencesService';

const CACHE_KEY: string = 'app_update_policy_v1';
const PROMPT_DAY_KEY: string = 'app_update_prompt_day';
const PROMPT_VERSION_KEY: string = 'app_update_prompt_version';
/** 鸿蒙应用市场详情（与 bundleName 一致） */
const APP_GALLERY_DETAIL_URL: string =
  'https://appgallery.huawei.com/app/detail?id=com.freeshore.focusvow';

const TITLE: string = '发现新版本';
const MESSAGE_SOFT: string = '请更新到最新版本，以获得更好的体验与稳定性。';
const MESSAGE_FORCE: string = '当前版本过旧，请更新后继续使用。';

type AppUpdateLevel = 'none' | 'soft' | 'force';

interface AppUpdateVersionPair {
  latest: string;
  min: string;
}

interface AppUpdatePolicy {
  harmony: AppUpdateVersionPair;
}

let presenting: boolean = false;

function isVersionOlder(current: string, target: string): boolean {
  const t = target.trim();
  if (t.length === 0) {
    return false;
  }
  const parse = (raw: string): number[] => {
    const parts = raw.trim().split('.');
    const out: number[] = [];
    for (let i = 0; i < parts.length; i++) {
      const n = Number.parseInt(parts[i], 10);
      out.push(Number.isFinite(n) ? n : 0);
    }
    return out;
  };
  const a = parse(current);
  const b = parse(t);
  const len = Math.max(a.length, b.length);
  for (let i = 0; i < len; i++) {
    const av = i < a.length ? a[i] : 0;
    const bv = i < b.length ? b[i] : 0;
    if (av < bv) {
      return true;
    }
    if (av > bv) {
      return false;
    }
  }
  return false;
}

function readHarmonyPair(raw: Record<string, Object> | undefined): AppUpdateVersionPair {
  const harmony = raw?.['harmony'] as Record<string, Object> | undefined;
  if (!harmony) {
    return { latest: '', min: '' };
  }
  return {
    latest: String(harmony['latest'] ?? '').trim(),
    min: String(harmony['min'] ?? '').trim(),
  };
}

function resolveUpdateLevel(current: string, pair: AppUpdateVersionPair): AppUpdateLevel {
  if (pair.min.length > 0 && isVersionOlder(current, pair.min)) {
    return 'force';
  }
  if (pair.latest.length > 0 && isVersionOlder(current, pair.latest)) {
    return 'soft';
  }
  return 'none';
}

function formatLocalDayKey(): string {
  const now = new Date();
  const y = now.getFullYear();
  const m = now.getMonth() + 1;
  const d = now.getDate();
  return `${y}-${m}-${d}`;
}

function shouldShowUpdateDialog(context: common.Context, latest: string): boolean {
  if (latest.length === 0) {
    return true;
  }
  const today = formatLocalDayKey();
  const day = readStoredString(context, PROMPT_DAY_KEY, '');
  const ver = readStoredString(context, PROMPT_VERSION_KEY, '');
  return day !== today || ver !== latest;
}

function markUpdateDialogShown(context: common.Context, latest: string): void {
  if (latest.length === 0) {
    return;
  }
  writeStoredString(context, PROMPT_DAY_KEY, formatLocalDayKey());
  writeStoredString(context, PROMPT_VERSION_KEY, latest);
}

async function fetchHarmonyPair(context: common.Context): Promise<AppUpdateVersionPair> {
  try {
    const response = await HttpService.get('/config/static', false);
    if (response.statusCode === 200 && response.data) {
      const data = response.data as Record<string, Object>;
      const raw = data['app_update'] as Record<string, Object> | undefined;
      const pair = readHarmonyPair(raw);
      const policy: AppUpdatePolicy = { harmony: pair };
      writeStoredString(context, CACHE_KEY, JSON.stringify(policy));
      return pair;
    }
  } catch (_e) {
    // use cache
  }
  const cached = readStoredString(context, CACHE_KEY, '');
  if (cached.length > 0) {
    try {
      const policy = JSON.parse(cached) as AppUpdatePolicy;
      if (policy && policy.harmony) {
        return policy.harmony;
      }
    } catch (_e) {
      // ignore
    }
  }
  return { latest: '', min: '' };
}

async function openHarmonyAppGallery(context: common.UIAbilityContext): Promise<void> {
  const want: Want = {
    action: 'ohos.want.action.viewData',
    uri: APP_GALLERY_DETAIL_URL,
  };
  try {
    await context.startAbility(want);
  } catch (error) {
    console.error(`openHarmonyAppGallery failed: ${String(error)}`);
  }
}

export async function isHarmonyUpdateAvailable(context: common.Context): Promise<boolean> {
  const pair = await fetchHarmonyPair(context);
  const current = await getAppVersion();
  return resolveUpdateLevel(current, pair) !== 'none';
}

export async function openHarmonyUpdate(context: common.UIAbilityContext): Promise<void> {
  await openHarmonyAppGallery(context);
}

export async function tryPresentAppUpdateOnLaunch(
  context: common.UIAbilityContext,
  uiContext: UIContext,
): Promise<void> {
  if (presenting) {
    return;
  }

  const pair = await fetchHarmonyPair(context);
  const current = await getAppVersion();
  let level = resolveUpdateLevel(current, pair);
  if (level === 'soft' && !shouldShowUpdateDialog(context, pair.latest)) {
    level = 'none';
  }
  if (level === 'none') {
    return;
  }

  presenting = true;
  if (level === 'soft') {
    markUpdateDialogShown(context, pair.latest);
  }
  const message = level === 'force' ? MESSAGE_FORCE : MESSAGE_SOFT;
  const finish = (): void => {
    presenting = false;
  };

  if (level === 'force') {
    uiContext.showAlertDialog({
      title: TITLE,
      message,
      autoCancel: false,
      primaryButton: {
        value: '立即更新',
        action: () => {
          finish();
          void openHarmonyAppGallery(context);
        },
      },
    });
    return;
  }

  uiContext.showAlertDialog({
    title: TITLE,
    message,
    autoCancel: false,
    primaryButton: {
      value: '稍后再说',
      action: () => {
        finish();
      },
    },
    secondaryButton: {
      value: '立即更新',
      action: () => {
        finish();
        void openHarmonyAppGallery(context);
      },
    },
  });
}

import { common } from '@kit.AbilityKit';
import { getAppVersionSync } from '../common/AppInfo';
import { FeatureFlagKeys } from '../config/FeatureFlags';
import { PageRoutes } from '../router/PageRoutes';
import { HttpService } from '../services/HttpService';
import { readStoredString, writeStoredString } from '../services/PreferencesService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

const CACHE_KEY: string = 'feature_flags_off';

function parseFeaturesOff(raw: Object | undefined): string[] {
  if (!raw || typeof raw !== 'object') {
    return [];
  }
  const data = raw as Record<string, Object>;
  const listRaw = data['features_off'];
  const list: string[] = [];
  if (Array.isArray(listRaw)) {
    const values = listRaw as Object[];
    for (let i = 0; i < values.length; i++) {
      const item = String(values[i]).trim();
      if (item.length > 0) {
        list.push(item);
      }
    }
  }
  return list;
}

function parseCached(raw: string): string[] {
  if (raw.length === 0) {
    return [];
  }
  try {
    const parsed = JSON.parse(raw) as Object;
    if (Array.isArray(parsed)) {
      const list: string[] = [];
      for (let i = 0; i < parsed.length; i++) {
        const item = String(parsed[i]).trim();
        if (item.length > 0) {
          list.push(item);
        }
      }
      return list;
    }
  } catch (_e) {
  }
  return [];
}

function syncAppStorageValue(key: string, value: string[]): void {
  if (!AppStorage.set<string[]>(key, value)) {
    AppStorage.setOrCreate<string[]>(key, value);
  }
}

export class FeatureFlagStore {
  static hydrate(context?: common.Context): void {
    bootstrapStores();
    if (!context) {
      return;
    }
    const raw = readStoredString(context, CACHE_KEY, '');
    FeatureFlagStore.applyFeaturesOff(raw.length === 0 ? [] : parseCached(raw));
  }

  static getFeaturesOff(): string[] {
    bootstrapStores();
    return AppStorage.get<string[]>(StoreKeys.FeatureFlagsOff) ?? [];
  }

  static applyFeaturesOff(list: string[]): void {
    bootstrapStores();
    syncAppStorageValue(StoreKeys.FeatureFlagsOff, list);
  }

  static isFeatureOff(key: string): boolean {
    return FeatureFlagStore.getFeaturesOff().includes(key);
  }

  static isPromoVipOn(): boolean {
    return !FeatureFlagStore.isFeatureOff(FeatureFlagKeys.PROMO_VIP);
  }

  static isWechatLoginOn(): boolean {
    return !FeatureFlagStore.isFeatureOff(FeatureFlagKeys.WECHAT_LOGIN);
  }

  static getVipPurchaseRoute(): string {
    return FeatureFlagStore.isPromoVipOn() ? PageRoutes.Paywall : PageRoutes.Redeem;
  }

  static async sync(context?: common.Context): Promise<void> {
    bootstrapStores();
    try {
      const version = getAppVersionSync();
      const query: Record<string, string> = {
        'platform': 'harmony',
        'version': version === 'unknown' ? '' : version,
      };
      const response = await HttpService.getWithQuery(
        '/config/feature-flags',
        query,
        false,
        true,
        context,
      );
      if (response.statusCode === 200 && response.data !== undefined) {
        const list = parseFeaturesOff(response.data as Object);
        FeatureFlagStore.applyFeaturesOff(list);
        if (context) {
          writeStoredString(context, CACHE_KEY, JSON.stringify(list));
        }
      }
    } catch (error) {
      console.warn(`[FeatureFlag] sync failed: ${String(error)}`);
    }
  }
}

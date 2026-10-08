import { common } from '@kit.AbilityKit';
import { HttpService } from '../services/HttpService';
import { readStoredString, writeStoredString } from '../services/PreferencesService';
import { loadAccessToken } from '../services/UserPersistenceService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

const CACHE_KEY: string = 'ab_variants';

function syncAppStorageValue(value: string): void {
  if (!AppStorage.set<string>(StoreKeys.AbVariants, value)) {
    AppStorage.setOrCreate<string>(StoreKeys.AbVariants, value);
  }
}

function readVariant(raw: string, key: string): string {
  if (raw.length === 0) {
    return '';
  }
  try {
    const parsed = JSON.parse(raw) as Record<string, Object>;
    const value = parsed[key];
    if (value === undefined || value === null) {
      return '';
    }
    const text = String(value);
    if (text === 'experiment' || text === 'control') {
      return text;
    }
  } catch (_e) {
  }
  return '';
}

/** 未入组返回空字符串。对照组和未入组的界面都走线上逻辑。 */
export class AbStore {
  static hydrate(context?: common.Context): void {
    bootstrapStores();
    if (!context) {
      return;
    }
    const raw = readStoredString(context, CACHE_KEY, '');
    if (raw.length > 0) {
      syncAppStorageValue(raw);
    }
  }

  static getVariant(key: string): string {
    bootstrapStores();
    const raw = AppStorage.get<string>(StoreKeys.AbVariants) ?? '';
    return readVariant(raw, key);
  }

  static isExperiment(key: string): boolean {
    return AbStore.getVariant(key) === 'experiment';
  }

  static clear(context?: common.Context): void {
    bootstrapStores();
    syncAppStorageValue('{}');
    if (context) {
      writeStoredString(context, CACHE_KEY, '{}');
    }
  }

  static async sync(context?: common.Context): Promise<void> {
    bootstrapStores();
    if (!context || loadAccessToken(context).length === 0) {
      return;
    }
    AbStore.hydrate(context);
    try {
      const response = await HttpService.get('/config/ab', true, true, context);
      if (response.statusCode !== 200 || response.data === undefined) {
        return;
      }
      const data = response.data as Record<string, Object>;
      const variantsRaw = data['variants'];
      if (variantsRaw === undefined || variantsRaw === null || typeof variantsRaw !== 'object') {
        return;
      }
      const encoded = JSON.stringify(variantsRaw);
      syncAppStorageValue(encoded);
      writeStoredString(context, CACHE_KEY, encoded);
    } catch (error) {
      console.warn(`[AB] sync failed: ${String(error)}`);
    }
  }
}

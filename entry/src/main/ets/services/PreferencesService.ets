import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'focus_vow_store';

function getPreferencesStore(context: common.Context): preferences.Preferences | null {
  try {
    return preferences.getPreferencesSync(context, { name: STORE_NAME });
  } catch {
    console.error('Failed to get preferences store.');
    return null;
  }
}

export function readStoredString(
  context: common.Context,
  key: string,
  fallbackValue: string
): string {
  try {
    const store = getPreferencesStore(context);
    if (!store) {
      return fallbackValue;
    }
    return store.getSync(key, fallbackValue) as string;
  } catch {
    console.error(`Failed to read ${key}.`);
    return fallbackValue;
  }
}

export function writeStoredString(
  context: common.Context,
  key: string,
  value: string
): boolean {
  try {
    const store = getPreferencesStore(context);
    if (!store) {
      return false;
    }
    store.putSync(key, value);
    store.flushSync();
    return true;
  } catch {
    console.error(`Failed to write ${key}.`);
    return false;
  }
}

export function removeStoredKey(context: common.Context, key: string): boolean {
  try {
    const store = getPreferencesStore(context);
    if (!store) {
      return false;
    }
    if (store.hasSync(key)) {
      store.deleteSync(key);
      store.flushSync();
    }
    return true;
  } catch {
    console.error(`Failed to remove ${key}.`);
    return false;
  }
}

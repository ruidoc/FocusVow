import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'focus_vow_store';

function getPreferencesStore(context: common.UIAbilityContext): preferences.Preferences {
  return preferences.getPreferencesSync(context, { name: STORE_NAME });
}

export function readStoredString(
  context: common.UIAbilityContext,
  key: string,
  fallbackValue: string
): string {
  try {
    return getPreferencesStore(context).getSync(key, fallbackValue) as string;
  } catch {
    console.error(`Failed to read ${key}.`);
    return fallbackValue;
  }
}

export function writeStoredString(
  context: common.UIAbilityContext,
  key: string,
  value: string
): boolean {
  try {
    const store = getPreferencesStore(context);
    store.putSync(key, value);
    store.flushSync();
    return true;
  } catch {
    console.error(`Failed to write ${key}.`);
    return false;
  }
}

export function removeStoredKey(context: common.UIAbilityContext, key: string): boolean {
  try {
    const store = getPreferencesStore(context);
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

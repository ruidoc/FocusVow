import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

export const PREFERENCES_STORE_NAME: string = 'focus_vow_store';
const STORE_NAME: string = PREFERENCES_STORE_NAME;
const DOMAIN: number = 0x0000;
const TAG: string = 'Preferences';

/** 一次性：把模块级旧数据迁入应用级 store，之后只读写应用级路径 */
const LEGACY_MODULE_KEYS: string[] = [
  'plan.collection',
  'plan.filterScope',
  'active.lock.state',
  'quickFocus.durationMinutes',
  'settings.state',
  'cycle.guard.state',
  'focus.durationMinutes',
  'quickFocus.duration',
  'focus.currentSession'
];

let moduleToAppMigrationDone: boolean = false;
let multiProcessObserverRegistered: boolean = false;

function getStoreOptions(): preferences.Options {
  return { name: STORE_NAME };
}

/**
 * 跨进程读写统一使用应用级 Context（base/preferences）。
 * UIAbility / Extension 传入任意 Context，均解析为 ApplicationContext。
 */
export function getApplicationStorageContext(context: common.Context): common.Context {
  try {
    return context.getApplicationContext();
  } catch {
    return context;
  }
}

function isApplicationContext(context: common.Context, appContext: common.Context): boolean {
  return context === appContext;
}

function invalidatePreferencesCache(context: common.Context): void {
  try {
    preferences.removePreferencesFromCacheSync(context, getStoreOptions());
    return;
  } catch {
    // fall through
  }

  try {
    preferences.removePreferencesFromCacheSync(context, STORE_NAME);
  } catch (error) {
    hilog.warn(DOMAIN, TAG, 'invalidate cache failed: %{public}s', String(error));
  }
}

function openPreferencesStore(context: common.Context, refreshFromDisk: boolean): preferences.Preferences | null {
  const appContext = getApplicationStorageContext(context);
  if (refreshFromDisk) {
    invalidatePreferencesCache(appContext);
  }

  try {
    return preferences.getPreferencesSync(appContext, getStoreOptions());
  } catch (error) {
    hilog.error(
      DOMAIN,
      TAG,
      'open store failed dir=%{public}s err=%{public}s',
      appContext.preferencesDir,
      String(error)
    );
    return null;
  }
}

function readFromStore(
  store: preferences.Preferences,
  key: string,
  fallbackValue: string
): string {
  if (!store.hasSync(key)) {
    return fallbackValue;
  }
  return store.getSync(key, fallbackValue) as string;
}

function ensureMultiProcessObserver(context: common.Context): void {
  if (multiProcessObserverRegistered) {
    return;
  }

  const store = openPreferencesStore(context, false);
  if (!store) {
    return;
  }

  try {
    store.on('multiProcessChange', (changedKey: string) => {
      hilog.info(DOMAIN, TAG, 'multiProcessChange key=%{public}s', changedKey);
      invalidatePreferencesCache(getApplicationStorageContext(context));
    });
    multiProcessObserverRegistered = true;
  } catch (error) {
    hilog.warn(DOMAIN, TAG, 'subscribe multiProcessChange failed: %{public}s', String(error));
  }
}

/** 首次启动：haps/entry/preferences → base/preferences（仅当应用级尚无数据时） */
export function migrateModulePreferencesToApplicationOnce(context: common.Context): void {
  if (moduleToAppMigrationDone) {
    return;
  }
  moduleToAppMigrationDone = true;

  const appContext = getApplicationStorageContext(context);
  if (isApplicationContext(context, appContext)) {
    return;
  }

  let moduleStore: preferences.Preferences | null = null;
  let appStore: preferences.Preferences | null = null;

  try {
    invalidatePreferencesCache(context);
    moduleStore = preferences.getPreferencesSync(context, getStoreOptions());
    invalidatePreferencesCache(appContext);
    appStore = preferences.getPreferencesSync(appContext, getStoreOptions());
  } catch (error) {
    hilog.warn(DOMAIN, TAG, 'legacy migration open failed: %{public}s', String(error));
    return;
  }

  if (!moduleStore || !appStore) {
    return;
  }

  let migratedCount: number = 0;
  for (const key of LEGACY_MODULE_KEYS) {
    if (!moduleStore.hasSync(key)) {
      continue;
    }

    const moduleValue = readFromStore(moduleStore, key, '');
    if (moduleValue.length === 0) {
      continue;
    }

    const appValue = readFromStore(appStore, key, '');
    if (appValue.length > 0) {
      continue;
    }

    appStore.putSync(key, moduleValue);
    migratedCount++;
  }

  if (migratedCount > 0) {
    appStore.flushSync();
    hilog.info(DOMAIN, TAG, 'migrated %{public}d keys module→app store', migratedCount);
  }
}

export function warmUpPreferencesStore(context: common.Context): void {
  migrateModulePreferencesToApplicationOnce(context);
  ensureMultiProcessObserver(context);
  invalidatePreferencesCache(getApplicationStorageContext(context));
}

export function getPreferencesStorageDir(context: common.Context): string {
  return getApplicationStorageContext(context).preferencesDir;
}

export function readStoredString(
  context: common.Context,
  key: string,
  fallbackValue: string
): string {
  try {
    migrateModulePreferencesToApplicationOnce(context);
    const appContext = getApplicationStorageContext(context);
    invalidatePreferencesCache(appContext);

    const store = openPreferencesStore(context, false);
    if (!store) {
      return fallbackValue;
    }

    return readFromStore(store, key, fallbackValue);
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'read %{public}s failed: %{public}s', key, String(error));
    return fallbackValue;
  }
}

export function writeStoredString(
  context: common.Context,
  key: string,
  value: string
): boolean {
  try {
    const appContext = getApplicationStorageContext(context);
    invalidatePreferencesCache(appContext);

    const store = openPreferencesStore(context, false);
    if (!store) {
      hilog.error(DOMAIN, TAG, 'write %{public}s failed: store is null', key);
      return false;
    }

    store.putSync(key, value);
    store.flushSync();
    return true;
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'write %{public}s failed: %{public}s', key, String(error));
    return false;
  }
}

export function removeStoredKey(context: common.Context, key: string): boolean {
  try {
    const appContext = getApplicationStorageContext(context);
    invalidatePreferencesCache(appContext);

    const store = openPreferencesStore(context, false);
    if (!store) {
      return false;
    }
    if (store.hasSync(key)) {
      store.deleteSync(key);
      store.flushSync();
    }
    return true;
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'remove %{public}s failed: %{public}s', key, String(error));
    return false;
  }
}

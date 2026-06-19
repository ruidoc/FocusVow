import { common } from '@kit.AbilityKit';
import { DuoSessionView } from '../models/DuoModel';
import { readStoredString, writeStoredString } from '../services/PreferencesService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

const SCHEDULED_LIST_NEEDS_REFRESH_KEY: string = 'scheduled.list.needsRefresh';

export type ScheduledListFilter = 'all' | 'initiated' | 'joined';

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

export class ScheduledListStore {
  static hydrate(): void {
    bootstrapStores();
  }

  static markDirty(): void {
    ScheduledListStore.hydrate();
    syncAppStorageValue(StoreKeys.ScheduledListDirty, true);
  }

  static clearDirty(): void {
    syncAppStorageValue(StoreKeys.ScheduledListDirty, false);
  }

  static isDirty(): boolean {
    ScheduledListStore.hydrate();
    return AppStorage.get<boolean>(StoreKeys.ScheduledListDirty) === true;
  }

  static getFilter(): ScheduledListFilter {
    ScheduledListStore.hydrate();
    const filter = AppStorage.get<string>(StoreKeys.ScheduledListFilter) ?? 'all';
    if (filter === 'initiated' || filter === 'joined') {
      return filter;
    }
    return 'all';
  }

  static setFilter(filter: ScheduledListFilter): void {
    ScheduledListStore.hydrate();
    syncAppStorageValue(StoreKeys.ScheduledListFilter, filter);
  }

  static getAllSessions(): DuoSessionView[] {
    ScheduledListStore.hydrate();
    return AppStorage.get<DuoSessionView[]>(StoreKeys.ScheduledListAll) ?? [];
  }

  static setAllSessions(items: DuoSessionView[]): void {
    ScheduledListStore.hydrate();
    syncAppStorageValue(StoreKeys.ScheduledListAll, items);
  }

  /** 扩展进程写入：通知主进程刷新契约列表 */
  static markNeedsRefreshPersisted(context: common.Context): void {
    writeStoredString(context, SCHEDULED_LIST_NEEDS_REFRESH_KEY, '1');
  }

  static consumePersistedNeedsRefresh(context: common.Context): boolean {
    const raw = readStoredString(context, SCHEDULED_LIST_NEEDS_REFRESH_KEY, '');
    if (raw !== '1') {
      return false;
    }
    writeStoredString(context, SCHEDULED_LIST_NEEDS_REFRESH_KEY, '');
    return true;
  }

  static patchSession(session: DuoSessionView): void {
    ScheduledListStore.hydrate();
    const items = ScheduledListStore.getAllSessions();
    if (items.length === 0) {
      return;
    }
    let changed = false;
    const next = items.map((item: DuoSessionView) => {
      if (item.session_id !== session.session_id) {
        return item;
      }
      changed = true;
      return session;
    });
    if (changed) {
      ScheduledListStore.setAllSessions(next);
    }
  }
}

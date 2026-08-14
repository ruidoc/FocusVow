import { InboxItem } from '../models/InboxModel';
import { ApiEnvelope } from '../models/UserModel';
import { InboxApiService } from '../services/InboxApiService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

function copyItem(item: InboxItem, read: boolean): InboxItem {
  return {
    id: item.id,
    title: item.title,
    subtitle: item.subtitle,
    body: item.body,
    link: item.link,
    kind: item.kind,
    created_at: item.created_at,
    read: read
  };
}

function applyUnreadFromItems(items: InboxItem[]): void {
  let unread = 0;
  let important = 0;
  for (let i = 0; i < items.length; i++) {
    if (items[i].read) {
      continue;
    }
    unread += 1;
    if (items[i].kind === 'important') {
      important += 1;
    }
  }
  syncAppStorageValue(StoreKeys.InboxUnread, unread);
  syncAppStorageValue(StoreKeys.InboxImportantUnread, important);
}

export class InboxStore {
  static getItems(): InboxItem[] {
    bootstrapStores();
    return AppStorage.get<InboxItem[]>(StoreKeys.InboxItems) ?? [];
  }

  static getUnreadCount(): number {
    bootstrapStores();
    return AppStorage.get<number>(StoreKeys.InboxUnread) ?? 0;
  }

  static getImportantCount(): number {
    bootstrapStores();
    return AppStorage.get<number>(StoreKeys.InboxImportantUnread) ?? 0;
  }

  static getOpenId(): string {
    bootstrapStores();
    return AppStorage.get<string>(StoreKeys.InboxOpenId) ?? '';
  }

  static setOpenId(id: string): void {
    bootstrapStores();
    syncAppStorageValue(StoreKeys.InboxOpenId, id);
  }

  static getDetailId(): string {
    bootstrapStores();
    return AppStorage.get<string>(StoreKeys.InboxDetailId) ?? '';
  }

  static setDetailId(id: string): void {
    bootstrapStores();
    syncAppStorageValue(StoreKeys.InboxDetailId, id);
  }

  static reset(): void {
    bootstrapStores();
    syncAppStorageValue(StoreKeys.InboxItems, []);
    syncAppStorageValue(StoreKeys.InboxUnread, 0);
    syncAppStorageValue(StoreKeys.InboxImportantUnread, 0);
    syncAppStorageValue(StoreKeys.InboxLoading, false);
    syncAppStorageValue(StoreKeys.InboxOpenId, '');
    syncAppStorageValue(StoreKeys.InboxDetailId, '');
  }

  static async fetchUnread(): Promise<void> {
    bootstrapStores();
    const response = await InboxApiService.unreadCount();
    if (response.statusCode === 200) {
      syncAppStorageValue(StoreKeys.InboxUnread, InboxApiService.parseUnreadCount(response));
      syncAppStorageValue(
        StoreKeys.InboxImportantUnread,
        InboxApiService.parseImportantCount(response)
      );
    }
  }

  static async fetchList(): Promise<ApiEnvelope> {
    bootstrapStores();
    syncAppStorageValue(StoreKeys.InboxLoading, true);
    try {
      const response = await InboxApiService.list();
      if (response.statusCode === 200) {
        syncAppStorageValue(StoreKeys.InboxItems, InboxApiService.parseList(response));
        syncAppStorageValue(StoreKeys.InboxUnread, InboxApiService.parseListUnread(response));
        syncAppStorageValue(
          StoreKeys.InboxImportantUnread,
          InboxApiService.parseListImportant(response)
        );
      }
      return response;
    } finally {
      syncAppStorageValue(StoreKeys.InboxLoading, false);
    }
  }

  static async fetchOne(id: string): Promise<InboxItem | null> {
    bootstrapStores();
    const items = InboxStore.getItems();
    for (let i = 0; i < items.length; i++) {
      if (items[i].id === id) {
        return items[i];
      }
    }
    const response = await InboxApiService.getOne(id);
    const item = InboxApiService.parseOne(response);
    if (item) {
      syncAppStorageValue(StoreKeys.InboxItems, [item, ...items]);
    }
    return item;
  }

  static async markRead(id: string): Promise<void> {
    bootstrapStores();
    const items = InboxStore.getItems();
    const next: InboxItem[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (item.id === id && !item.read) {
        next.push(copyItem(item, true));
      } else {
        next.push(item);
      }
    }
    syncAppStorageValue(StoreKeys.InboxItems, next);
    applyUnreadFromItems(next);
    await InboxApiService.markRead(id);
  }

  static async markAllRead(): Promise<void> {
    bootstrapStores();
    const items = InboxStore.getItems();
    const next: InboxItem[] = [];
    for (let i = 0; i < items.length; i++) {
      next.push(copyItem(items[i], true));
    }
    syncAppStorageValue(StoreKeys.InboxItems, next);
    syncAppStorageValue(StoreKeys.InboxUnread, 0);
    syncAppStorageValue(StoreKeys.InboxImportantUnread, 0);
    await InboxApiService.markAllRead();
  }
}

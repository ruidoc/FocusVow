import {
  OrgDetail,
  OrgListItem,
  OrgLive,
  OrgRank,
  parseOrgListItem,
  parseOrgListItems
} from '../models/OrgModel';
import { ApiEnvelope } from '../models/UserModel';
import { OrgApiService } from '../services/OrgApiService';
import { StatsPeriod } from '../services/StatsRecordUtil';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

function markMineJoined(items: OrgListItem[]): OrgListItem[] {
  const next: OrgListItem[] = [];
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    next.push({
      id: item.id,
      name: item.name,
      invite_code: item.invite_code,
      theme_color: item.theme_color,
      avatar: item.avatar,
      intro: item.intro,
      owner_id: item.owner_id,
      role: item.role,
      member_count: item.member_count,
      joined_at: item.joined_at,
      joined: true,
      visibility: item.visibility
    });
  }
  return next;
}

export class OrgStore {
  private static detailCache: OrgDetail | null = null;
  private static rankCache: OrgRank | null = null;
  private static liveCache: OrgLive | null = null;

  static hydrate(): void {
    bootstrapStores();
  }

  static getList(): OrgListItem[] {
    bootstrapStores();
    return AppStorage.get<OrgListItem[]>(StoreKeys.OrgList) ?? [];
  }

  static getDefaults(): OrgListItem[] {
    bootstrapStores();
    return AppStorage.get<OrgListItem[]>(StoreKeys.OrgDefaults) ?? [];
  }

  static getMine(): OrgListItem[] {
    bootstrapStores();
    return AppStorage.get<OrgListItem[]>(StoreKeys.OrgMine) ?? [];
  }

  static setDiscover(defaults: OrgListItem[], mine: OrgListItem[]): void {
    bootstrapStores();
    const markedMine = markMineJoined(mine);
    syncAppStorageValue(StoreKeys.OrgDefaults, defaults);
    syncAppStorageValue(StoreKeys.OrgMine, markedMine);
    const combined: OrgListItem[] = [];
    for (let i = 0; i < defaults.length; i++) {
      combined.push(defaults[i]);
    }
    for (let i = 0; i < markedMine.length; i++) {
      combined.push(markedMine[i]);
    }
    syncAppStorageValue(StoreKeys.OrgList, combined);
  }

  static setList(items: OrgListItem[]): void {
    bootstrapStores();
    const marked = markMineJoined(items);
    syncAppStorageValue(StoreKeys.OrgList, marked);
    syncAppStorageValue(StoreKeys.OrgDefaults, []);
    syncAppStorageValue(StoreKeys.OrgMine, marked);
  }

  static isLoading(): boolean {
    bootstrapStores();
    return AppStorage.get<boolean>(StoreKeys.OrgLoading) ?? false;
  }

  static setLoading(loading: boolean): void {
    bootstrapStores();
    syncAppStorageValue(StoreKeys.OrgLoading, loading);
  }

  static getDetail(): OrgDetail | null {
    return OrgStore.detailCache;
  }

  static getRank(): OrgRank | null {
    return OrgStore.rankCache;
  }

  static getLive(): OrgLive | null {
    return OrgStore.liveCache;
  }

  static clearDetail(): void {
    OrgStore.detailCache = null;
    OrgStore.rankCache = null;
    OrgStore.liveCache = null;
  }

  static findOwnedOrg(): OrgListItem | null {
    const mine = OrgStore.getMine();
    for (let i = 0; i < mine.length; i++) {
      if (mine[i].role === 'owner') {
        return mine[i];
      }
    }
    const list = OrgStore.getList();
    for (let i = 0; i < list.length; i++) {
      if (list[i].role === 'owner') {
        return list[i];
      }
    }
    return null;
  }

  static async listMine(): Promise<ApiEnvelope> {
    OrgStore.setLoading(true);
    try {
      const response = await OrgApiService.listMine();
      if (response.statusCode === 200) {
        OrgStore.setList(parseOrgListItems(response.data as Object | undefined));
      }
      return response;
    } finally {
      OrgStore.setLoading(false);
    }
  }

  /** 公开组织 + 我的组织 */
  static async listDiscover(): Promise<ApiEnvelope> {
    OrgStore.setLoading(true);
    try {
      const response = await OrgApiService.listDiscover();
      if (response.statusCode === 200 && response.data) {
        const data = response.data as Record<string, Object>;
        const defaults = parseOrgListItems(data['defaults']);
        const mine = parseOrgListItems(data['mine']);
        OrgStore.setDiscover(defaults, mine);
      }
      return response;
    } finally {
      OrgStore.setLoading(false);
    }
  }

  static async join(code: string): Promise<ApiEnvelope> {
    const response = await OrgApiService.join(code);
    if (response.statusCode === 200) {
      await OrgStore.listDiscover();
    }
    return response;
  }

  static async joinById(orgId: string): Promise<ApiEnvelope> {
    const response = await OrgApiService.joinById(orgId);
    if (response.statusCode === 200) {
      await OrgStore.listDiscover();
      if (OrgStore.detailCache?.id === orgId) {
        await OrgStore.fetchDetail(orgId);
      }
    }
    return response;
  }

  static async leave(orgId: string): Promise<ApiEnvelope> {
    const response = await OrgApiService.leave(orgId);
    if (response.statusCode === 200) {
      await OrgStore.listDiscover();
      if (OrgStore.detailCache?.id === orgId) {
        OrgStore.clearDetail();
      }
    }
    return response;
  }

  static async fetchDetail(orgId: string): Promise<ApiEnvelope> {
    const response = await OrgApiService.getDetail(orgId);
    const detail = OrgApiService.parseDetail(response);
    if (detail) {
      OrgStore.detailCache = detail;
    }
    return response;
  }

  static async fetchRank(orgId: string, period: StatsPeriod = 'today'): Promise<ApiEnvelope> {
    const response = await OrgApiService.getRank(orgId, period);
    const rank = OrgApiService.parseRank(response);
    if (rank) {
      OrgStore.rankCache = rank;
    }
    return response;
  }

  static async fetchLive(orgId: string): Promise<ApiEnvelope> {
    const response = await OrgApiService.getLive(orgId);
    OrgStore.liveCache = OrgApiService.parseLive(response);
    return response;
  }

  static async patchOrg(orgId: string, body: Record<string, Object>): Promise<ApiEnvelope> {
    const response = await OrgApiService.patchOrg(orgId, body);
    if (response.statusCode === 200 && response.data) {
      const patch = parseOrgListItem(response.data);
      const mergeItem = (item: OrgListItem): OrgListItem => {
        if (item.id !== orgId) {
          return item;
        }
        return {
          id: item.id,
          name: patch.name.length > 0 ? patch.name : item.name,
          invite_code: patch.invite_code.length > 0 ? patch.invite_code : item.invite_code,
          theme_color: patch.theme_color.length > 0 ? patch.theme_color : item.theme_color,
          avatar: patch.avatar.length > 0 ? patch.avatar : item.avatar,
          intro: patch.intro.length > 0 ? patch.intro : item.intro,
          owner_id: item.owner_id,
          role: item.role,
          member_count: item.member_count,
          joined_at: item.joined_at,
          joined: item.joined,
          visibility: patch.visibility.length > 0 ? patch.visibility : item.visibility
        };
      };

      const defaults = OrgStore.getDefaults().map(mergeItem);
      const mine = OrgStore.getMine().map(mergeItem);
      OrgStore.setDiscover(defaults, mine);

      if (OrgStore.detailCache?.id === orgId) {
        const current = OrgStore.detailCache;
        OrgStore.detailCache = {
          id: current.id,
          name: patch.name.length > 0 ? patch.name : current.name,
          invite_code: patch.invite_code.length > 0 ? patch.invite_code : current.invite_code,
          theme_color: patch.theme_color.length > 0 ? patch.theme_color : current.theme_color,
          avatar: patch.avatar.length > 0 ? patch.avatar : current.avatar,
          intro: patch.intro.length > 0 ? patch.intro : current.intro,
          owner_id: current.owner_id,
          member_count: current.member_count,
          members: current.members,
          is_member: current.is_member,
          role: current.role,
          visibility: patch.visibility.length > 0 ? patch.visibility : current.visibility
        };
      }
    }
    return response;
  }
}

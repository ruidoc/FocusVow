import { common } from '@kit.AbilityKit';
import { BenefitState, createEmptyBenefitState, MembershipStatus } from '../models/BenefitModel';
import { HttpService } from '../services/HttpService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

function asNumber(value: Object | undefined, fallback: number = 0): number {
  if (typeof value === 'number') {
    return value;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function asString(value: Object | undefined, fallback: string = ''): string {
  if (typeof value === 'string') {
    return value;
  }
  if (value === undefined || value === null) {
    return fallback;
  }
  return String(value);
}

export class BenefitStore {
  static hydrate(_context?: common.Context): void {
    bootstrapStores();
  }

  static getState(): BenefitState {
    bootstrapStores();
    return {
      dayDuration: AppStorage.get<number>(StoreKeys.BenefitDayDuration) ?? 0,
      todayUsed: AppStorage.get<number>(StoreKeys.BenefitTodayUsed) ?? 0,
      duoTodayUsed: AppStorage.get<number>(StoreKeys.BenefitDuoTodayUsed) ?? 0,
      isSubscribed: AppStorage.get<boolean>(StoreKeys.BenefitIsSubscribed) ?? false,
      membershipStatus: (AppStorage.get<string>(StoreKeys.BenefitMembershipStatus) ??
        'none') as MembershipStatus,
      communityQrUrl: AppStorage.get<string>(StoreKeys.BenefitCommunityQrUrl) ?? '',
      communityHint: AppStorage.get<string>(StoreKeys.BenefitCommunityHint) ?? '',
      features: AppStorage.get<string>(StoreKeys.BenefitFeatures) ?? ''
    };
  }

  static applyState(state: BenefitState): void {
    bootstrapStores();
    syncAppStorageValue(StoreKeys.BenefitDayDuration, state.dayDuration);
    syncAppStorageValue(StoreKeys.BenefitTodayUsed, state.todayUsed);
    syncAppStorageValue(StoreKeys.BenefitDuoTodayUsed, state.duoTodayUsed);
    syncAppStorageValue(StoreKeys.BenefitIsSubscribed, state.isSubscribed);
    syncAppStorageValue(StoreKeys.BenefitMembershipStatus, state.membershipStatus);
    syncAppStorageValue(StoreKeys.BenefitCommunityQrUrl, state.communityQrUrl);
    syncAppStorageValue(StoreKeys.BenefitCommunityHint, state.communityHint);
    syncAppStorageValue(StoreKeys.BenefitFeatures, state.features);
  }

  static async refresh(): Promise<BenefitState> {
    bootstrapStores();
    const response = await HttpService.get('/benefit');
    if (response.statusCode !== 200 || !response.data) {
      return BenefitStore.getState();
    }
    const raw = response.data;
    const isSubscribed = Boolean(raw['is_subscribed']);
    let membershipStatus = asString(raw['membership_status'], '') as MembershipStatus;
    if (membershipStatus.length === 0) {
      membershipStatus = isSubscribed ? 'active' : 'none';
    }
    const next: BenefitState = {
      dayDuration: asNumber(raw['day_duration'], 0),
      todayUsed: asNumber(raw['today_used'], 0),
      duoTodayUsed: asNumber(raw['duo_today_used'], 0),
      isSubscribed,
      membershipStatus,
      communityQrUrl: asString(raw['community_qr_url'], ''),
      communityHint: asString(raw['community_hint'], ''),
      features: asString(raw['features'], '')
    };
    BenefitStore.applyState(next);
    return next;
  }

  static reset(): void {
    BenefitStore.applyState(createEmptyBenefitState());
  }
}

export type PointTierKey = 'starter' | 'keeper' | 'guardian' | 'master';

export interface ContractProfile {
  id: string;
  username: string;
  avatar: string;
  isPro: boolean;
  isMe: boolean;
  points: number;
  tierLevel: number;
  tierKey: PointTierKey;
  joinDays: number;
  beatPercent: number;
  siteRank: number | null;
  streakDays: number;
  totalMins: number;
  successCount: number;
  finishRate: number;
  breakCount: number;
  identity: string;
  goal: string;
  bio: string;
  followingCount: number;
  followerCount: number;
  isFollowing: boolean;
  isFollowedBy: boolean;
  isMutual: boolean;
}

export interface PointLogItem {
  id: string;
  type: string;
  delta: number;
  balanceAfter: number;
  remark: string;
  createdAt: string;
}

export interface PointLogPage {
  page: number;
  hasMore: boolean;
  items: PointLogItem[];
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

function asNumber(value: Object | undefined, fallback: number = 0): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function asBool(value: Object | undefined): boolean {
  return value === true || value === 1 || value === '1' || value === 'true';
}

function normalizeTierKey(raw: string): PointTierKey {
  if (raw === 'keeper' || raw === 'guardian' || raw === 'master') {
    return raw;
  }
  return 'starter';
}

export function parseContractProfile(raw: Object | undefined): ContractProfile | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const data = raw as Record<string, Object>;
  const id = asString(data['id']).trim();
  if (id.length === 0) {
    return null;
  }
  const siteRankRaw = data['site_rank'];
  let siteRank: number | null = null;
  if (siteRankRaw !== undefined && siteRankRaw !== null && String(siteRankRaw).length > 0) {
    siteRank = asNumber(siteRankRaw, 0);
  }
  return {
    id,
    username: asString(data['username']),
    avatar: asString(data['avatar']),
    isPro: asBool(data['is_pro']),
    isMe: asBool(data['is_me']),
    points: Math.max(0, asNumber(data['points'], 0)),
    tierLevel: Math.max(1, asNumber(data['tier_level'], 1)),
    tierKey: normalizeTierKey(asString(data['tier_key'])),
    joinDays: asNumber(data['join_days'], 0),
    beatPercent: asNumber(data['beat_percent'], 0),
    siteRank,
    streakDays: asNumber(data['streak_days'], 0),
    totalMins: asNumber(data['total_mins'], 0),
    successCount: asNumber(data['success_count'], 0),
    finishRate: asNumber(data['finish_rate'], 0),
    breakCount: asNumber(data['break_count'], 0),
    identity: asString(data['identity']),
    goal: asString(data['goal']),
    bio: asString(data['bio']),
    followingCount: asNumber(data['following_count'], 0),
    followerCount: asNumber(data['follower_count'], 0),
    isFollowing: asBool(data['is_following']),
    isFollowedBy: asBool(data['is_followed_by']),
    isMutual: asBool(data['is_mutual']),
  };
}

export function parsePointLogPage(raw: Object | undefined): PointLogPage {
  const empty: PointLogPage = { page: 1, hasMore: false, items: [] };
  if (!raw || typeof raw !== 'object') {
    return empty;
  }
  const data = raw as Record<string, Object>;
  const itemsRaw = data['items'];
  const items: PointLogItem[] = [];
  if (Array.isArray(itemsRaw)) {
    const list = itemsRaw as Object[];
    for (let i = 0; i < list.length; i++) {
      const row = list[i];
      if (!row || typeof row !== 'object') {
        continue;
      }
      const item = row as Record<string, Object>;
      items.push({
        id: asString(item['id']),
        type: asString(item['type']),
        delta: asNumber(item['delta'], 0),
        balanceAfter: asNumber(item['balance_after'], 0),
        remark: asString(item['remark']),
        createdAt: asString(item['created_at']),
      });
    }
  }
  return {
    page: Math.max(1, asNumber(data['page'], 1)),
    hasMore: asBool(data['has_more']),
    items,
  };
}

export function tierLabel(key: PointTierKey): string {
  if (key === 'keeper') {
    return '坚韧';
  }
  if (key === 'guardian') {
    return '磐石';
  }
  if (key === 'master') {
    return '大师';
  }
  return '启蒙';
}

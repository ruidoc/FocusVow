export type GlobalRankPeriod = 'today' | 'week' | 'month' | 'all';
export type GlobalRankMode = 'solo' | 'duo';

export interface RankMember {
  userId: string;
  username: string;
  avatar: string;
  isPro: boolean;
}

export interface RankRow {
  key: string;
  rank: number;
  minutes: number;
  members: RankMember[];
  isDuo: boolean;
}

export interface GlobalRankData {
  period: GlobalRankPeriod;
  mode: GlobalRankMode;
  items: RankRow[];
  myRank: number;
  myMinutes: number;
  hasMyRank: boolean;
}

export const DUO_AI_PARTNER_ID: string = 'duo_online_match_bot';
export const GLOBAL_RANK_MIN_MINS: number = 5;

export function periodLabel(period: GlobalRankPeriod): string {
  if (period === 'week') {
    return '本周';
  }
  if (period === 'month') {
    return '本月';
  }
  if (period === 'all') {
    return '全部';
  }
  return '今日';
}

export function formatRankMinutes(minutes: number): string {
  const value = Math.max(0, Math.round(minutes));
  if (value < 60) {
    return `${value}m`;
  }
  const hours = Math.floor(value / 60);
  const remain = value % 60;
  if (remain === 0) {
    return `${hours}h`;
  }
  return `${hours}h ${remain}m`;
}

function readBool(raw: Object | undefined): boolean {
  return raw === true || raw === 1 || raw === '1' || raw === 'true';
}

function readMember(raw: Record<string, Object> | undefined): RankMember {
  return {
    userId: String(raw?.['user_id'] ?? ''),
    username: String(raw?.['username'] ?? '用户'),
    avatar: String(raw?.['avatar'] ?? ''),
    isPro: readBool(raw?.['is_pro']),
  };
}

export function parseGlobalRank(data: Object | undefined, period: GlobalRankPeriod, mode: GlobalRankMode): GlobalRankData {
  const record = data as Record<string, Object> | undefined;
  const rawItems = record?.['items'] as Object[] | undefined;
  const items: RankRow[] = [];
  if (rawItems) {
    for (let i = 0; i < rawItems.length; i++) {
      const row = rawItems[i] as Record<string, Object>;
      const membersRaw = row['members'] as Object[] | undefined;
      const members: RankMember[] = [];
      if (membersRaw && membersRaw.length > 0) {
        for (let j = 0; j < membersRaw.length; j++) {
          members.push(readMember(membersRaw[j] as Record<string, Object>));
        }
      } else {
        members.push(readMember(row));
      }
      const pairKey = String(row['pair_key'] ?? '');
      const userId = members.length > 0 ? members[0].userId : String(row['user_id'] ?? '');
      items.push({
        key: pairKey.length > 0 ? pairKey : `${userId}-${i}`,
        rank: Number(row['rank'] ?? i + 1),
        minutes: Number(row['actual_mins'] ?? 0),
        members,
        isDuo: mode === 'duo',
      });
    }
  }
  const myRankRaw = record?.['my_rank'];
  const hasMyRank = myRankRaw !== null && myRankRaw !== undefined && String(myRankRaw).length > 0;
  return {
    period,
    mode,
    items,
    myRank: hasMyRank ? Number(myRankRaw) : 0,
    myMinutes: Number(record?.['my_actual_mins'] ?? 0),
    hasMyRank,
  };
}

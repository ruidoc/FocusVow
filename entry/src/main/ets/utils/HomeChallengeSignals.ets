import { common } from '@kit.AbilityKit';
import { HttpService } from '../services/HttpService';
import { UserStore } from '../stores/UserStore';

/**
 * 对齐 focus-rn/src/stores/challenge.ts：首页挑战入口 / 红点所需的最小字段。
 */
export interface ChallengeSummaryLite {
  id: string;
  goal_once_mins: number;
  goal_repeat_days: number;
  title: string;
}

export interface UserChallengeLite {
  challenge_id: string;
  status: string;
  checked_in_today?: boolean;
  streak_days?: number;
  challenge?: ChallengeSummaryLite;
}

export interface HomeChallengeSignals {
  showEntry: boolean;
  dot: boolean;
  soloId: string;
  /** 上架中的进行中挑战数量，与 RN challenges.length 一致 */
  activeCount: number;
}

function asString(v: Object | undefined, fallback: string = ''): string {
  if (v === undefined || v === null) {
    return fallback;
  }
  return String(v);
}

function asBool(v: Object | undefined, fallback: boolean = false): boolean {
  if (v === undefined || v === null) {
    return fallback;
  }
  if (typeof v === 'boolean') {
    return v;
  }
  const n = Number(v);
  if (n === 1) {
    return true;
  }
  if (n === 0) {
    return false;
  }
  return fallback;
}

function parseChallengeSummary(raw: Object | undefined): ChallengeSummaryLite | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const row = raw as Record<string, Object>;
  const id = asString(row['id']).trim();
  if (id.length === 0) {
    return null;
  }
  return {
    id: id,
    goal_once_mins: Number(row['goal_once_mins']) || 0,
    goal_repeat_days: Number(row['goal_repeat_days']) || 0,
    title: asString(row['title']).trim(),
  };
}

function parseUserChallenge(raw: Object | undefined): UserChallengeLite | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const row = raw as Record<string, Object>;
  const challenge_id = asString(row['challenge_id']).trim();
  if (challenge_id.length === 0) {
    return null;
  }
  const nested = row['challenge'];
  return {
    challenge_id: challenge_id,
    status: asString(row['status']).trim(),
    checked_in_today: row['checked_in_today'] !== undefined ? asBool(row['checked_in_today']) : undefined,
    streak_days: row['streak_days'] !== undefined ? Number(row['streak_days']) : undefined,
    challenge: parseChallengeSummary(nested as Object | undefined) ?? undefined,
  };
}

/** 与 RN challengeCheckinPending 一致 */
export function challengeCheckinPending(uc: UserChallengeLite, todayFocusMin: number): boolean {
  if (uc.status !== 'in_progress') {
    return false;
  }
  if (uc.checked_in_today === true) {
    return false;
  }
  const once = Math.max(1, Number(uc.challenge?.goal_once_mins) || 25);
  return todayFocusMin >= once;
}

const EMPTY: HomeChallengeSignals = {
  showEntry: false,
  dot: false,
  soloId: '',
  activeCount: 0,
};

function encodeQuery(params: Record<string, string>): string {
  const parts: string[] = [];
  const keys = Object.keys(params);
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    parts.push(`${encodeURIComponent(k)}=${encodeURIComponent(params[k])}`);
  }
  return parts.join('&');
}

export class HomeChallengeSignalsUtil {
  /**
   * 拉活跃挑战 +（已登录）我的挑战，计算是否与 RN 首页一致的入口与红点。
   * todayFocusMin：与 RN fetchTodayFocusMinutes 同源，取今日 actual_mins 整分。
   */
  static async refresh(
    context: common.UIAbilityContext,
    todayFocusMin: number,
  ): Promise<HomeChallengeSignals> {
    /** 与 RN fetchActiveChallenges：仅 is_active=1，不按 ongoing 过滤 */
    const listRes = await HttpService.getWithQuery(
      '/challenge/list',
      {
        'is_active': '1',
      },
      true,
      false,
      context,
    );
    if (listRes.statusCode !== 200 || !Array.isArray(listRes.data) || listRes.data.length === 0) {
      return EMPTY;
    }
    const activeArr = listRes.data as Object[];
    const activeCount = activeArr.length;
    const soloFromList =
      activeArr.length === 1 ? asString((activeArr[0] as Record<string, Object>)['id']).trim() : '';

    if (!UserStore.isLoggedIn()) {
      return {
        showEntry: true,
        dot: false,
        soloId: soloFromList,
        activeCount: activeCount,
      };
    }

    const mineRes = await HttpService.get('/challenge/user/list', true, false, context);
    if (mineRes.statusCode !== 200 || !Array.isArray(mineRes.data)) {
      return {
        showEntry: true,
        dot: false,
        soloId: soloFromList,
        activeCount: activeCount,
      };
    }

    const mine: UserChallengeLite[] = [];
    for (const item of mineRes.data as Object[]) {
      const row = parseUserChallenge(item);
      if (row) {
        mine.push(row);
      }
    }

    const inProgress = mine.filter((uc: UserChallengeLite) => uc.status === 'in_progress');
    if (!inProgress.some((uc: UserChallengeLite) => uc.checked_in_today !== true)) {
      return {
        showEntry: true,
        dot: false,
        soloId: soloFromList,
        activeCount: activeCount,
      };
    }

    const pending = inProgress.find((uc: UserChallengeLite) =>
      challengeCheckinPending(uc, todayFocusMin),
    );

    let soloId: string = '';
    if (pending) {
      soloId = pending.challenge_id;
    } else if (activeArr.length === 1) {
      soloId = soloFromList;
    }

    return {
      showEntry: true,
      dot: pending !== undefined,
      soloId: soloId,
      activeCount: activeCount,
    };
  }

  /** 对齐 RN resolvePendingChallengeCheckinShareParams，返回 H5 与 Expo 路由 /challenges/checkin-share 等价的 query */
  static async resolveCheckinShareWebUrl(
    context: common.UIAbilityContext,
    todayFocusMin: number,
    listBaseUrl: string,
  ): Promise<string | null> {
    if (!UserStore.isLoggedIn()) {
      return null;
    }
    const mineRes = await HttpService.get('/challenge/user/list', true, false, context);
    if (mineRes.statusCode !== 200 || !Array.isArray(mineRes.data)) {
      return null;
    }
    const mine: UserChallengeLite[] = [];
    for (const item of mineRes.data as Object[]) {
      const row = parseUserChallenge(item);
      if (row) {
        mine.push(row);
      }
    }
    const pending = mine
      .filter((uc: UserChallengeLite) => uc.status === 'in_progress')
      .find((uc: UserChallengeLite) => challengeCheckinPending(uc, todayFocusMin));
    if (!pending) {
      return null;
    }
    let challenge = pending.challenge;
    if (!challenge || challenge.title.length === 0) {
      const detail = await HttpService.get(`/challenge/${pending.challenge_id}`, true, false, context);
      if (detail.statusCode !== 200 || !detail.data) {
        return null;
      }
      challenge = parseChallengeSummary(detail.data as Object) ?? undefined;
    }
    if (!challenge || challenge.title.length === 0) {
      return null;
    }
    const onceMins = Math.max(1, Number(challenge.goal_once_mins) || 25);
    const streakTarget = Math.max(1, Number(challenge.goal_repeat_days) || 1);
    const streakDays = pending.streak_days !== undefined ? Number(pending.streak_days) : 0;
    const checkinDay = Math.min(
      streakTarget,
      Math.max(1, streakDays + 1),
    );
    const q: Record<string, string> = {};
    q['challengeId'] = pending.challenge_id;
    q['title'] = challenge.title;
    q['onceMins'] = `${onceMins}`;
    q['checkinDay'] = `${checkinDay}`;
    q['streakTarget'] = `${streakTarget}`;
    q['pledge'] = '0';
    return `${listBaseUrl}/checkin-share?${encodeQuery(q)}`;
  }
}

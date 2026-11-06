export type FollowGraphTab = 'mutual' | 'following' | 'followers';

export interface FollowRow {
  id: string;
  username: string;
  avatar: string;
  isFollowing: boolean;
  isFollowedBy: boolean;
  isMutual: boolean;
}

export interface FollowRelation {
  isFollowing: boolean;
  isFollowedBy: boolean;
  isMutual: boolean;
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

function asBool(value: Object | undefined): boolean {
  return value === true || value === 1 || value === '1' || value === 'true';
}

export function parseFollowRow(raw: Object | undefined): FollowRow | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const data = raw as Record<string, Object>;
  const id = asString(data['id']).trim();
  if (id.length === 0) {
    return null;
  }
  const isFollowing = asBool(data['is_following']);
  const isFollowedBy = asBool(data['is_followed_by']);
  return {
    id,
    username: asString(data['username'], '用户'),
    avatar: asString(data['avatar']),
    isFollowing,
    isFollowedBy,
    isMutual: asBool(data['is_mutual']) || (isFollowing && isFollowedBy),
  };
}

export function parseFollowList(raw: Object | undefined): FollowRow[] {
  if (!raw || typeof raw !== 'object') {
    return [];
  }
  const data = raw as Record<string, Object>;
  const listRaw = data['list'];
  const rows: FollowRow[] = [];
  if (!Array.isArray(listRaw)) {
    return rows;
  }
  const list = listRaw as Object[];
  for (let i = 0; i < list.length; i++) {
    const parsed = parseFollowRow(list[i]);
    if (parsed) {
      rows.push(parsed);
    }
  }
  return rows;
}

export function parseFollowRelation(raw: Object | undefined): FollowRelation | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const data = raw as Record<string, Object>;
  const isFollowing = asBool(data['is_following']);
  const isFollowedBy = asBool(data['is_followed_by']);
  return {
    isFollowing,
    isFollowedBy,
    isMutual: asBool(data['is_mutual']) || (isFollowing && isFollowedBy),
  };
}

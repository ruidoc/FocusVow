import { StatsPeriod } from '../services/StatsRecordUtil';

export interface OrgListItem {
  id: string;
  name: string;
  invite_code: string;
  theme_color: string;
  avatar: string;
  intro: string;
  owner_id: string;
  role: string;
  member_count: number;
  joined_at: string;
  /** 发现页：是否已加入 */
  joined: boolean;
  visibility: string;
}

export interface OrgMember {
  user_id: string;
  username: string;
  avatar: string;
  role: string;
  joined_at: string;
  today_mins: number;
  week_mins: number;
}

export interface OrgDetail {
  id: string;
  name: string;
  invite_code: string;
  theme_color: string;
  avatar: string;
  intro: string;
  owner_id: string;
  member_count: number;
  members: OrgMember[];
  /** 当前用户是否已加入 */
  is_member: boolean;
  role: string;
  visibility: string;
}

export interface OrgRankItem {
  user_id: string;
  username: string;
  avatar: string;
  actual_mins: number;
  rank: number;
}

export interface OrgRank {
  period: StatsPeriod;
  items: OrgRankItem[];
  my_rank: number | null;
  my_actual_mins: number;
}

export interface OrgLiveWaiting {
  user_id: string;
  username: string;
  avatar: string;
  title: string;
  duo_session_id: string;
  duo_type: string;
  expire_at: string;
  duration_min: number;
}

export interface OrgLiveDuo {
  user_id: string;
  username: string;
  avatar: string;
  title: string;
  duo_session_id: string;
  duo_type: string;
  role: string;
  peer_user_id: string;
  peer_username: string;
  end_at: string;
  active_at: string;
  duration_min: number;
}

export interface OrgLiveSolo {
  user_id: string;
  username: string;
  avatar: string;
  title: string;
  source: string;
  duo_session_id: string;
  record_id: string;
  end_at: string;
  active_at: string;
  duration_min: number;
  total_min: number;
  actual_min: number;
}

export interface OrgLive {
  waiting: OrgLiveWaiting[];
  duo_active: OrgLiveDuo[];
  solo_active: OrgLiveSolo[];
}

export const ORG_DEFAULT_THEME: string = '#3D6B8C';
export const ORG_DEFAULT_INTRO: string = '一起专注，互相看见';

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
  if (typeof value === 'number') {
    return value;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function asNullableNumber(value: Object | undefined): number | null {
  if (value === undefined || value === null) {
    return null;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function parseOrgListItem(raw: Record<string, Object>): OrgListItem {
  const joinedRaw = raw['joined'];
  const joined = joinedRaw === true || joinedRaw === 'true' || asString(raw['role']).length > 0;
  return {
    id: asString(raw['id']),
    name: asString(raw['name']),
    invite_code: asString(raw['invite_code']),
    theme_color: asString(raw['theme_color']),
    avatar: asString(raw['avatar']),
    intro: asString(raw['intro']),
    owner_id: asString(raw['owner_id']),
    role: asString(raw['role']),
    member_count: asNumber(raw['member_count'], 0),
    joined_at: asString(raw['joined_at']),
    joined,
    visibility: asString(raw['visibility'])
  };
}

export function parseOrgListItems(raw: Object | undefined): OrgListItem[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const list = raw as Object[];
  const items: OrgListItem[] = [];
  for (let i = 0; i < list.length; i++) {
    const row = list[i];
    if (row && typeof row === 'object') {
      items.push(parseOrgListItem(row as Record<string, Object>));
    }
  }
  return items;
}

export function parseOrgMember(raw: Record<string, Object>): OrgMember {
  return {
    user_id: asString(raw['user_id']),
    username: asString(raw['username']),
    avatar: asString(raw['avatar']),
    role: asString(raw['role']),
    joined_at: asString(raw['joined_at']),
    today_mins: asNumber(raw['today_mins'], 0),
    week_mins: asNumber(raw['week_mins'], 0)
  };
}

export function parseOrgDetail(raw: Record<string, Object> | undefined): OrgDetail | null {
  if (!raw) {
    return null;
  }
  const id = asString(raw['id']);
  if (id.length === 0) {
    return null;
  }
  const membersRaw = raw['members'];
  const members: OrgMember[] = [];
  if (Array.isArray(membersRaw)) {
    const list = membersRaw as Object[];
    for (let i = 0; i < list.length; i++) {
      const row = list[i];
      if (row && typeof row === 'object') {
        members.push(parseOrgMember(row as Record<string, Object>));
      }
    }
  }
  const role = asString(raw['role']);
  const isMemberRaw = raw['is_member'];
  const isMember =
    isMemberRaw === true ||
    isMemberRaw === 'true' ||
    role === 'owner' ||
    role === 'member';
  return {
    id,
    name: asString(raw['name']),
    invite_code: asString(raw['invite_code']),
    theme_color: asString(raw['theme_color']),
    avatar: asString(raw['avatar']),
    intro: asString(raw['intro']),
    owner_id: asString(raw['owner_id']),
    member_count: asNumber(raw['member_count'], members.length),
    members,
    is_member: isMember,
    role,
    visibility: asString(raw['visibility'])
  };
}

export function parseOrgRankItem(raw: Record<string, Object>): OrgRankItem {
  return {
    user_id: asString(raw['user_id']),
    username: asString(raw['username']),
    avatar: asString(raw['avatar']),
    actual_mins: asNumber(raw['actual_mins'], 0),
    rank: asNumber(raw['rank'], 0)
  };
}

export function parseOrgRank(raw: Record<string, Object> | undefined): OrgRank | null {
  if (!raw) {
    return null;
  }
  const periodRaw = asString(raw['period'], 'today');
  const period = periodRaw === 'week' || periodRaw === 'month' ? periodRaw : 'today';
  const itemsRaw = raw['items'];
  const items: OrgRankItem[] = [];
  if (Array.isArray(itemsRaw)) {
    const list = itemsRaw as Object[];
    for (let i = 0; i < list.length; i++) {
      const row = list[i];
      if (row && typeof row === 'object') {
        items.push(parseOrgRankItem(row as Record<string, Object>));
      }
    }
  }
  return {
    period,
    items,
    my_rank: asNullableNumber(raw['my_rank']),
    my_actual_mins: asNumber(raw['my_actual_mins'], 0)
  };
}

function parseOrgLiveWaiting(raw: Record<string, Object>): OrgLiveWaiting {
  return {
    user_id: asString(raw['user_id']),
    username: asString(raw['username']),
    avatar: asString(raw['avatar']),
    title: asString(raw['title']),
    duo_session_id: asString(raw['duo_session_id']),
    duo_type: asString(raw['duo_type']),
    expire_at: asString(raw['expire_at']),
    duration_min: asNumber(raw['duration_min'], 0)
  };
}

function parseOrgLiveDuo(raw: Record<string, Object>): OrgLiveDuo {
  return {
    user_id: asString(raw['user_id']),
    username: asString(raw['username']),
    avatar: asString(raw['avatar']),
    title: asString(raw['title']),
    duo_session_id: asString(raw['duo_session_id']),
    duo_type: asString(raw['duo_type']),
    role: asString(raw['role']),
    peer_user_id: asString(raw['peer_user_id']),
    peer_username: asString(raw['peer_username']),
    end_at: asString(raw['end_at']),
    active_at: asString(raw['active_at']),
    duration_min: asNumber(raw['duration_min'], 0)
  };
}

function parseOrgLiveSolo(raw: Record<string, Object>): OrgLiveSolo {
  return {
    user_id: asString(raw['user_id']),
    username: asString(raw['username']),
    avatar: asString(raw['avatar']),
    title: asString(raw['title']),
    source: asString(raw['source']),
    duo_session_id: asString(raw['duo_session_id']),
    record_id: asString(raw['record_id']),
    end_at: asString(raw['end_at']),
    active_at: asString(raw['active_at']),
    duration_min: asNumber(raw['duration_min'], 0),
    total_min: asNumber(raw['total_min'], 0),
    actual_min: asNumber(raw['actual_min'], 0)
  };
}

function parseOrgLiveArray<T>(
  raw: Object | undefined,
  parser: (row: Record<string, Object>) => T
): T[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const list = raw as Object[];
  const items: T[] = [];
  for (let i = 0; i < list.length; i++) {
    const row = list[i];
    if (row && typeof row === 'object') {
      items.push(parser(row as Record<string, Object>));
    }
  }
  return items;
}

export function parseOrgLive(raw: Record<string, Object> | undefined): OrgLive {
  if (!raw) {
    return { waiting: [], duo_active: [], solo_active: [] };
  }
  return {
    waiting: parseOrgLiveArray(raw['waiting'], parseOrgLiveWaiting),
    duo_active: parseOrgLiveArray(raw['duo_active'], parseOrgLiveDuo),
    solo_active: parseOrgLiveArray(raw['solo_active'], parseOrgLiveSolo)
  };
}

export function formatOrgShortMins(min: number): string {
  if (min < 60) {
    return `${min}分`;
  }
  const h = Math.floor(min / 60);
  const m = min % 60;
  return m > 0 ? `${h}小时${m}分` : `${h}小时`;
}

function asBoolean(value: Object | undefined, fallback: boolean = false): boolean {
  if (typeof value === 'boolean') {
    return value;
  }
  const text = asString(value);
  if (text === 'true' || text === '1') {
    return true;
  }
  if (text === 'false' || text === '0') {
    return false;
  }
  return fallback;
}

export interface OrgClassroomSummary {
  id: string;
  org_id: string;
  title: string;
  duration_min: number;
  max_apps: number;
  allow_exit: boolean;
  status: string;
  created_by: string;
  active_at: string;
  end_at: string;
}

export interface OrgClassroomStats {
  joined: number;
  focusing: number;
  completed: number;
  left: number;
}

export interface OrgClassroomMember {
  user_id: string;
  username: string;
  avatar: string;
  record_id: string;
  status: string;
}

export interface OrgClassroomExitRequest {
  id: string;
  user_id: string;
  username: string;
  avatar: string;
  record_id: string;
  status: string;
}

export interface OrgClassroomMyExitRequest {
  id: string;
  status: string;
}

export interface OrgClassroomActive {
  classroom: OrgClassroomSummary;
  stats: OrgClassroomStats;
  members: OrgClassroomMember[];
  exit_requests: OrgClassroomExitRequest[];
  my_exit_request: OrgClassroomMyExitRequest | null;
}

export function parseOrgIsoMs(raw: string): number {
  if (raw.length === 0) {
    return 0;
  }
  const parsed = Date.parse(raw);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function formatOrgClassroomElapsed(startedAt: string, nowMs: number = Date.now()): string {
  const startMs = parseOrgIsoMs(startedAt);
  const sec = startMs > 0 ? Math.max(0, Math.floor((nowMs - startMs) / 1000)) : 0;
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;
  if (h > 0) {
    const mm = m < 10 ? `0${m}` : `${m}`;
    const ss = s < 10 ? `0${s}` : `${s}`;
    return `${h}:${mm}:${ss}`;
  }
  const mm = m < 10 ? `0${m}` : `${m}`;
  const ss = s < 10 ? `0${s}` : `${s}`;
  return `${mm}:${ss}`;
}

export function isOrgClassroomJoinable(active: OrgClassroomActive | null): boolean {
  if (!active) {
    return false;
  }
  return active.classroom.status === 'active';
}

export function isOrgClassroomFocusing(active: OrgClassroomActive | null, userId: string): boolean {
  if (!active || userId.length === 0) {
    return false;
  }
  for (let i = 0; i < active.members.length; i++) {
    if (active.members[i].user_id === userId && active.members[i].status === 'running') {
      return true;
    }
  }
  return false;
}

function parseOrgClassroomSummary(raw: Record<string, Object>): OrgClassroomSummary {
  return {
    id: asString(raw['id']),
    org_id: asString(raw['org_id']),
    title: asString(raw['title']),
    duration_min: asNumber(raw['duration_min'], 0),
    max_apps: asNumber(raw['max_apps'], 0),
    allow_exit: asBoolean(raw['allow_exit'], false),
    status: asString(raw['status']),
    created_by: asString(raw['created_by']),
    active_at: asString(raw['active_at']),
    end_at: asString(raw['end_at'])
  };
}

function parseOrgClassroomStats(raw: Record<string, Object> | undefined): OrgClassroomStats {
  if (!raw) {
    return { joined: 0, focusing: 0, completed: 0, left: 0 };
  }
  return {
    joined: asNumber(raw['joined'], 0),
    focusing: asNumber(raw['focusing'], 0),
    completed: asNumber(raw['completed'], 0),
    left: asNumber(raw['left'], 0)
  };
}

function parseOrgClassroomMember(raw: Record<string, Object>): OrgClassroomMember {
  return {
    user_id: asString(raw['user_id']),
    username: asString(raw['username']),
    avatar: asString(raw['avatar']),
    record_id: asString(raw['record_id']),
    status: asString(raw['status'])
  };
}

function parseOrgClassroomExitRequest(raw: Record<string, Object>): OrgClassroomExitRequest {
  return {
    id: asString(raw['id']),
    user_id: asString(raw['user_id']),
    username: asString(raw['username']),
    avatar: asString(raw['avatar']),
    record_id: asString(raw['record_id']),
    status: asString(raw['status'])
  };
}

export function parseOrgClassroomActive(raw: Record<string, Object> | undefined): OrgClassroomActive | null {
  if (!raw) {
    return null;
  }
  const classroomRaw = raw['classroom'];
  if (!classroomRaw || typeof classroomRaw !== 'object') {
    return null;
  }
  const members: OrgClassroomMember[] = [];
  const membersRaw = raw['members'];
  if (Array.isArray(membersRaw)) {
    const list = membersRaw as Object[];
    for (let i = 0; i < list.length; i++) {
      const row = list[i];
      if (row && typeof row === 'object') {
        members.push(parseOrgClassroomMember(row as Record<string, Object>));
      }
    }
  }
  const exitRequests: OrgClassroomExitRequest[] = [];
  const exitRaw = raw['exit_requests'];
  if (Array.isArray(exitRaw)) {
    const list = exitRaw as Object[];
    for (let i = 0; i < list.length; i++) {
      const row = list[i];
      if (row && typeof row === 'object') {
        exitRequests.push(parseOrgClassroomExitRequest(row as Record<string, Object>));
      }
    }
  }
  let myExit: OrgClassroomMyExitRequest | null = null;
  const myRaw = raw['my_exit_request'];
  if (myRaw && typeof myRaw === 'object') {
    const myRec = myRaw as Record<string, Object>;
    const id = asString(myRec['id']);
    if (id.length > 0) {
      myExit = {
        id,
        status: asString(myRec['status'])
      };
    }
  }
  const statsRaw = raw['stats'];
  return {
    classroom: parseOrgClassroomSummary(classroomRaw as Record<string, Object>),
    stats: parseOrgClassroomStats(
      statsRaw && typeof statsRaw === 'object' ? statsRaw as Record<string, Object> : undefined
    ),
    members,
    exit_requests: exitRequests,
    my_exit_request: myExit
  };
}

export function sanitizeOrgInviteCode(raw: string): string {
  let text = String(raw ?? '');
  const chars: string[] = [];
  for (let i = 0; i < text.length; i++) {
    const ch = text.charAt(i);
    if (/[a-zA-Z0-9]/.test(ch)) {
      chars.push(ch.toUpperCase());
    }
  }
  return chars.join('').slice(0, 8);
}

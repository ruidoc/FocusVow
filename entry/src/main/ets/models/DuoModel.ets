export type DuoSessionType = 'instant' | 'scheduled';

export type DuoParticipationMode = 'solo' | 'duo';

export interface DuoPartnerBrief {
  id: string;
  nickname: string;
  avatar?: string;
}

export interface DuoSessionView {
  session_id: string;
  token: string;
  type: DuoSessionType;
  status: string;
  title: string;
  duration_min: number;
  mode: string;
  participation_mode: DuoParticipationMode;
  schedule_json?: Record<string, string | number>;
  expire_at?: string;
  active_at?: string;
  end_at?: string;
  end_date?: string;
  my_record_id?: string;
  record_id?: string;
  invite_text?: string;
  viewer_role?: string;
  breached_by?: string;
  breached_by_name?: string;
  breach_reason?: string;
  initiator?: DuoPartnerBrief;
  partner?: DuoPartnerBrief | null;
  expects_duo?: boolean;
  has_ever_activated?: boolean;
  editable?: boolean;
  initiator_apps?: string[];
  partner_apps?: string[];
  my_apps?: string[];
  my_app_count?: number;
  schedule_start?: string;
  schedule_end?: string;
  schedule_repeat?: string;
}

export interface DuoStatsSummary {
  period: string;
  start_at: string;
  end_at: string;
  completed_count: number;
  failed_count: number;
  actual_mins: number;
  success_rate: number;
  streak_days: number;
  best_streak_days: number;
  total_completed_count: number;
  total_actual_mins: number;
  duo_success_rate: number;
}

export interface DuoTimelineRecord {
  id: string;
  duo_session_id: string;
  title: string;
  session_type: string;
  participation_mode: string;
  total_min: number;
  actual_min: number;
  completed_at?: string;
  partner?: DuoPartnerBrief | null;
}

export interface DuoTimelineDay {
  date: string;
  records: DuoTimelineRecord[];
}

export interface DuoShameRecord extends DuoTimelineRecord {
  breach_role: string;
  failed_reason: string;
}

export interface DuoShameDay {
  date: string;
  records: DuoShameRecord[];
}

export interface DuoStatsTimeline {
  period: string;
  items: DuoTimelineDay[];
}

export interface DuoStatsShame {
  period: string;
  items: DuoShameDay[];
}

export interface DuoScheduledCreatePayload {
  title: string;
  start: string;
  start_min: number;
  end: string;
  end_min: number;
  repeat: string;
  participation_mode?: DuoParticipationMode;
  initiator_apps?: string[];
  mode?: string;
}

export interface DuoScheduledUpdatePayload {
  title?: string;
  start?: string;
  start_min?: number;
  end?: string;
  end_min?: number;
  repeat?: string;
  mode?: string;
  initiator_apps?: string[];
  partner_apps?: string[];
}

export interface DuoScheduledListResult {
  items: DuoSessionView[];
}

export interface DuoPushPayload {
  type: string;
  session_id?: string;
  partner_name?: string;
  violator_name?: string;
  message?: string;
  duration_min?: string;
  active_at?: string;
  end_at?: string;
}

export interface PushDispatchOptions {
  isForeground?: boolean;
  title?: string;
  text?: string;
}

export interface UmengPushMessageBody {
  custom?: string;
}

export function getDuoPartnerDisplayName(partner?: DuoPartnerBrief | null): string {
  const nickname = partner?.nickname?.trim() ?? '';
  return nickname.length > 0 ? nickname : '搭子';
}

/** 当前用户视角下的双人契约对方昵称 */
export function resolveDuoCounterpartName(session: DuoSessionView): string {
  if (session.viewer_role === 'partner') {
    return getDuoPartnerDisplayName(session.initiator);
  }
  if (session.partner) {
    return getDuoPartnerDisplayName(session.partner);
  }
  return getDuoPartnerDisplayName(session.initiator);
}

export function parseStringArray(raw: Object | undefined): string[] {
  if (!raw || !Array.isArray(raw)) {
    return [];
  }
  const result: string[] = [];
  for (let i = 0; i < raw.length; i++) {
    const value = String(raw[i] ?? '');
    if (value.length > 0) {
      result.push(value);
    }
  }
  return result;
}

export function getScheduleRepeatDays(repeat: string): number[] {
  const days = repeat
    .split(',')
    .map((item: string) => Math.floor(Number(item.trim())))
    .filter((day: number) => day >= 1 && day <= 7);
  return days.length > 0 ? days : [1, 2, 3, 4, 5];
}

function parseClockToMinutes(clock: string): number {
  const parts = clock.split(':');
  return Math.floor(Number(parts[0]) || 0) * 60 + Math.floor(Number(parts[1]) || 0);
}

export function getScheduledSessionStartMin(session: DuoSessionView): number {
  const scheduleJson = session.schedule_json;
  const startMinRaw = Number(scheduleJson?.['start_min']);
  if (Number.isFinite(startMinRaw)) {
    return startMinRaw;
  }
  const startClock = session.schedule_start && session.schedule_start.length > 0
    ? session.schedule_start
    : String(scheduleJson?.['start'] ?? '09:00');
  return parseClockToMinutes(startClock);
}

export function getScheduledSessionEndMin(session: DuoSessionView): number {
  const scheduleJson = session.schedule_json;
  const endMinRaw = Number(scheduleJson?.['end_min']);
  if (Number.isFinite(endMinRaw)) {
    return endMinRaw;
  }
  const endClock = session.schedule_end && session.schedule_end.length > 0
    ? session.schedule_end
    : String(scheduleJson?.['end'] ?? '18:00');
  return parseClockToMinutes(endClock);
}

export function isInactiveScheduledSession(session: DuoSessionView): boolean {
  return session.status === 'completed'
    || session.status === 'failed'
    || session.status === 'cancelled'
    || session.status === 'breached'
    || session.status === 'expired';
}

function getScheduledRepeatWeekday(nowAt: number = Date.now()): number {
  const jsWeekday = new Date(nowAt).getDay();
  return jsWeekday === 0 ? 7 : jsWeekday;
}

function getPreviousScheduledWeekday(day: number): number {
  return day === 1 ? 7 : day - 1;
}

/**
 * 当前是否处于定时契约的排期窗口内（按 schedule_start/end + repeat）。
 * 跨午夜窗口沿用本地 PlanModel.isPlanRunning 规则。
 */
export function isScheduledSessionInWindow(
  session: DuoSessionView,
  nowAt: number = Date.now()
): boolean {
  const repeatRaw = session.schedule_repeat && session.schedule_repeat.length > 0
    ? session.schedule_repeat
    : String(session.schedule_json?.['repeat'] ?? '');
  const repeatDays = getScheduleRepeatDays(repeatRaw);
  if (repeatDays.length === 0) {
    return false;
  }

  const nowDate = new Date(nowAt);
  const currentWeekday = getScheduledRepeatWeekday(nowAt);
  const currentMinutes = nowDate.getHours() * 60 + nowDate.getMinutes();
  const startMinutes = getScheduledSessionStartMin(session);
  const endMinutes = getScheduledSessionEndMin(session);

  if (endMinutes > startMinutes) {
    return repeatDays.includes(currentWeekday) &&
      currentMinutes >= startMinutes &&
      currentMinutes < endMinutes;
  }

  if (currentMinutes >= startMinutes) {
    return repeatDays.includes(currentWeekday);
  }

  return repeatDays.includes(getPreviousScheduledWeekday(currentWeekday)) &&
    currentMinutes < endMinutes;
}

/**
 * 本次激活窗口是否仍有效：优先看 end_at；缺失时回退到排期窗口。
 */
export function isScheduledSessionActivationOpen(
  session: DuoSessionView,
  nowAt: number = Date.now()
): boolean {
  if (session.status !== 'active') {
    return false;
  }
  if (session.end_at && session.end_at.length > 0) {
    const endMs = Date.parse(session.end_at);
    if (Number.isFinite(endMs)) {
      return nowAt < endMs;
    }
  }
  return isScheduledSessionInWindow(session, nowAt);
}

/** 服务端仍为 active，但本地已判定本窗口结束，需要补报 complete-window */
export function shouldCompleteStaleScheduledWindow(
  session: DuoSessionView,
  nowAt: number = Date.now()
): boolean {
  return session.type === 'scheduled' &&
    session.status === 'active' &&
    !isScheduledSessionActivationOpen(session, nowAt);
}

export function sortScheduledSessions(sessions: DuoSessionView[]): DuoSessionView[] {
  const sorted = sessions.slice();
  sorted.sort((left: DuoSessionView, right: DuoSessionView) => {
    const inactiveLeft = isInactiveScheduledSession(left);
    const inactiveRight = isInactiveScheduledSession(right);
    if (inactiveLeft !== inactiveRight) {
      return inactiveLeft ? 1 : -1;
    }
    const activeLeft = isScheduledSessionActivationOpen(left);
    const activeRight = isScheduledSessionActivationOpen(right);
    if (activeLeft !== activeRight) {
      return activeLeft ? -1 : 1;
    }
    const startDiff = getScheduledSessionStartMin(left) - getScheduledSessionStartMin(right);
    if (startDiff !== 0) {
      return startDiff;
    }
    return left.title.localeCompare(right.title);
  });
  return sorted;
}

export function getScheduledSessionStatusLabel(session: DuoSessionView): string {
  if (session.status === 'active') {
    // 窗口已结束但 complete-window 未回写时，勿误导为「进行中」
    if (!isScheduledSessionActivationOpen(session)) {
      if (session.expects_duo && session.participation_mode !== 'duo') {
        return '等待搭子';
      }
      return '待开始';
    }
    return '进行中';
  }
  if (session.status === 'scheduled') {
    if (session.expects_duo && session.participation_mode !== 'duo') {
      return '等待搭子';
    }
    return '待开始';
  }
  if (session.status === 'cancelled') {
    return '已作废';
  }
  if (session.status === 'completed') {
    return '已完成';
  }
  if (session.status === 'failed') {
    return '已失败';
  }
  if (session.status === 'breached') {
    return '已撕毁';
  }
  if (session.status === 'expired') {
    return '已过期';
  }
  return session.status;
}

export function isDuoWaitPartnerJoined(
  session: DuoSessionView,
  isScheduled: boolean
): boolean {
  const partnerReady =
    session.participation_mode === 'duo' &&
    session.partner !== null &&
    session.partner !== undefined;
  if (isScheduled) {
    return partnerReady;
  }
  return partnerReady ||
    (session.status === 'active' && session.type !== 'scheduled');
}

function parsePartnerBrief(raw: Object | undefined | null): DuoPartnerBrief | undefined {
  if (!raw) {
    return undefined;
  }
  const record = raw as Record<string, Object>;
  const id = String(record['id'] ?? '');
  const nickname = String(record['nickname'] ?? '').trim();
  const avatar = String(record['avatar'] ?? '');
  if (id.length === 0 && nickname.length === 0) {
    return undefined;
  }
  return {
    id,
    nickname,
    avatar
  };
}

export function parseDuoSessionView(raw: Record<string, Object> | undefined): DuoSessionView | null {
  if (!raw) {
    return null;
  }
  const sessionId = String(raw['session_id'] ?? '');
  const recordId = String(raw['record_id'] ?? raw['my_record_id'] ?? '');
  if (sessionId.length === 0 && recordId.length === 0) {
    return null;
  }
  const partnerRaw = raw['partner'];
  const partner =
    partnerRaw === null
      ? null
      : parsePartnerBrief(partnerRaw as Object | undefined);
  return {
    session_id: sessionId,
    token: String(raw['token'] ?? ''),
    type: (String(raw['type'] ?? 'instant') as DuoSessionType),
    status: String(raw['status'] ?? ''),
    title: String(raw['title'] ?? ''),
    duration_min: Number(raw['duration_min'] ?? 0),
    mode: String(raw['mode'] ?? 'allow'),
    participation_mode: (String(raw['participation_mode'] ?? 'solo') as DuoParticipationMode),
    schedule_json: raw['schedule_json'] as Record<string, string | number> | undefined,
    expire_at: raw['expire_at'] ? String(raw['expire_at']) : undefined,
    active_at: raw['active_at'] ? String(raw['active_at']) : undefined,
    end_at: raw['end_at'] ? String(raw['end_at']) : undefined,
    end_date: raw['end_date'] ? String(raw['end_date']) : undefined,
    my_record_id: String(raw['my_record_id'] ?? raw['record_id'] ?? ''),
    record_id: recordId.length > 0 ? recordId : String(raw['my_record_id'] ?? ''),
    invite_text: String(raw['invite_text'] ?? ''),
    viewer_role: String(raw['viewer_role'] ?? ''),
    breached_by: raw['breached_by'] ? String(raw['breached_by']) : undefined,
    breached_by_name: raw['breached_by_name'] ? String(raw['breached_by_name']) : undefined,
    breach_reason: raw['breach_reason'] ? String(raw['breach_reason']) : undefined,
    initiator: parsePartnerBrief(raw['initiator'] as Object | undefined),
    partner: partner,
    expects_duo: raw['expects_duo'] === true || raw['expects_duo'] === 'true',
    has_ever_activated: raw['has_ever_activated'] === true || raw['has_ever_activated'] === 'true',
    editable: raw['editable'] === true || raw['editable'] === 'true',
    initiator_apps: parseStringArray(raw['initiator_apps'] as Object),
    partner_apps: parseStringArray(raw['partner_apps'] as Object),
    my_apps: parseStringArray(raw['my_apps'] as Object),
    my_app_count: Number(raw['my_app_count'] ?? 0),
    schedule_start: String(raw['schedule_start'] ?? ''),
    schedule_end: String(raw['schedule_end'] ?? ''),
    schedule_repeat: String(raw['schedule_repeat'] ?? '')
  };
}

export function parseDuoScheduledList(raw: Record<string, Object> | undefined): DuoScheduledListResult {
  const items: DuoSessionView[] = [];
  const listRaw = raw?.['items'] as Object[];
  if (listRaw) {
    for (let i = 0; i < listRaw.length; i++) {
      const session = parseDuoSessionView(listRaw[i] as Record<string, Object>);
      if (session) {
        items.push(session);
      }
    }
  }
  return { items };
}

export function parseDuoStatsSummary(raw: Record<string, Object> | undefined): DuoStatsSummary | null {
  if (!raw) {
    return null;
  }
  return {
    period: String(raw['period'] ?? 'today'),
    start_at: String(raw['start_at'] ?? ''),
    end_at: String(raw['end_at'] ?? ''),
    completed_count: Number(raw['completed_count'] ?? 0),
    failed_count: Number(raw['failed_count'] ?? 0),
    actual_mins: Number(raw['actual_mins'] ?? 0),
    success_rate: Number(raw['success_rate'] ?? 0),
    streak_days: Number(raw['streak_days'] ?? 0),
    best_streak_days: Number(raw['best_streak_days'] ?? 0),
    total_completed_count: Number(raw['total_completed_count'] ?? 0),
    total_actual_mins: Number(raw['total_actual_mins'] ?? 0),
    duo_success_rate: Number(raw['duo_success_rate'] ?? 0)
  };
}

function parseDuoTimelineRecord(raw: Record<string, Object>): DuoTimelineRecord {
  return {
    id: String(raw['id'] ?? ''),
    duo_session_id: String(raw['duo_session_id'] ?? ''),
    title: String(raw['title'] ?? ''),
    session_type: String(raw['session_type'] ?? ''),
    participation_mode: String(raw['participation_mode'] ?? ''),
    total_min: Number(raw['total_min'] ?? 0),
    actual_min: Number(raw['actual_min'] ?? 0),
    completed_at: raw['completed_at'] ? String(raw['completed_at']) : undefined,
    partner: raw['partner'] as DuoPartnerBrief | null | undefined
  };
}

function parseDuoShameRecord(raw: Record<string, Object>): DuoShameRecord {
  const base = parseDuoTimelineRecord(raw);
  return {
    id: base.id,
    duo_session_id: base.duo_session_id,
    title: base.title,
    session_type: base.session_type,
    participation_mode: base.participation_mode,
    total_min: base.total_min,
    actual_min: base.actual_min,
    completed_at: base.completed_at,
    partner: base.partner,
    breach_role: String(raw['breach_role'] ?? ''),
    failed_reason: String(raw['failed_reason'] ?? '')
  };
}

function parseDuoTimelineDay(raw: Record<string, Object>): DuoTimelineDay {
  const records: DuoTimelineRecord[] = [];
  const recordsRaw = raw['records'] as Object[];
  if (recordsRaw) {
    for (let i = 0; i < recordsRaw.length; i++) {
      records.push(parseDuoTimelineRecord(recordsRaw[i] as Record<string, Object>));
    }
  }
  return {
    date: String(raw['date'] ?? ''),
    records
  };
}

function parseDuoShameDay(raw: Record<string, Object>): DuoShameDay {
  const records: DuoShameRecord[] = [];
  const recordsRaw = raw['records'] as Object[];
  if (recordsRaw) {
    for (let i = 0; i < recordsRaw.length; i++) {
      records.push(parseDuoShameRecord(recordsRaw[i] as Record<string, Object>));
    }
  }
  return {
    date: String(raw['date'] ?? ''),
    records
  };
}

export function parseDuoStatsTimeline(raw: Record<string, Object> | undefined): DuoStatsTimeline | null {
  if (!raw) {
    return null;
  }
  const items: DuoTimelineDay[] = [];
  const itemsRaw = raw['items'] as Object[];
  if (itemsRaw) {
    for (let i = 0; i < itemsRaw.length; i++) {
      items.push(parseDuoTimelineDay(itemsRaw[i] as Record<string, Object>));
    }
  }
  return {
    period: String(raw['period'] ?? ''),
    items
  };
}

export function parseDuoStatsShame(raw: Record<string, Object> | undefined): DuoStatsShame | null {
  if (!raw) {
    return null;
  }
  const items: DuoShameDay[] = [];
  const itemsRaw = raw['items'] as Object[];
  if (itemsRaw) {
    for (let i = 0; i < itemsRaw.length; i++) {
      items.push(parseDuoShameDay(itemsRaw[i] as Record<string, Object>));
    }
  }
  return {
    period: String(raw['period'] ?? ''),
    items
  };
}

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
}

export interface DuoStatsSummary {
  period: string;
  start_at: string;
  end_at: string;
  completed_count: number;
  failed_count: number;
  actual_mins: number;
  success_rate: number;
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
}

export interface DuoPushPayload {
  type: string;
  session_id?: string;
  partner_name?: string;
  violator_name?: string;
  message?: string;
  duration_min?: string;
}

export interface UmengPushMessageBody {
  custom?: string;
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
  return {
    session_id: sessionId,
    token: String(raw['token'] ?? ''),
    type: (String(raw['type'] ?? 'instant') as DuoSessionType),
    status: String(raw['status'] ?? ''),
    title: String(raw['title'] ?? ''),
    duration_min: Number(raw['duration_min'] ?? 0),
    mode: String(raw['mode'] ?? 'allow'),
    participation_mode: (String(raw['participation_mode'] ?? 'solo') as DuoParticipationMode),
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
    initiator: raw['initiator'] as DuoPartnerBrief | undefined,
    partner: raw['partner'] as DuoPartnerBrief | null | undefined
  };
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
    success_rate: Number(raw['success_rate'] ?? 0)
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

import { common } from '@kit.AbilityKit';
import {
  DuoScheduledCreatePayload,
  DuoScheduledListResult,
  DuoScheduledUpdatePayload,
  DuoSessionView,
  DuoStatsByTask,
  DuoStatsShame,
  DuoStatsSummary,
  DuoStatsTimeline,
  parseDuoSessionView,
  parseDuoScheduledList,
  parseDuoStatsByTask,
  parseDuoStatsShame,
  parseDuoStatsSummary,
  parseDuoStatsTimeline
} from '../models/DuoModel';
import { ApiEnvelope } from '../models/UserModel';
import { ExtensionNetworkService } from './ExtensionNetworkService';
import { HttpService } from './HttpService';

export interface PendingFriendInvite {
  token: string;
  durationMin: number;
  initiatorName: string;
}

export class DuoApiService {
  static async instantStart(
    title: string,
    durationMin: number,
    timerMode: string = 'countdown'
  ): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'title': title,
      'duration_min': durationMin,
      'timer_mode': timerMode === 'countup' ? 'countup' : 'countdown'
    };
    return HttpService.post('/duo/instant/start', body);
  }

  static async inviteFriend(
    targetUserId: string,
    title: string,
    durationMin: number,
    timerMode: string = 'countdown'
  ): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'target_user_id': targetUserId,
      'title': title,
      'duration_min': durationMin,
      'timer_mode': timerMode === 'countup' ? 'countup' : 'countdown'
    };
    return HttpService.post('/duo/instant/invite-friend', body);
  }

  static async getPendingFriendInvite(): Promise<ApiEnvelope> {
    return HttpService.get('/duo/friend-invite/pending');
  }

  static async instantCreate(
    title: string,
    durationMin: number,
    timerMode: string = 'countdown'
  ): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'title': title,
      'duration_min': durationMin,
      'timer_mode': timerMode === 'countup' ? 'countup' : 'countdown'
    };
    return HttpService.post('/duo/instant/create', body);
  }

  static async getByToken(token: string): Promise<ApiEnvelope> {
    return HttpService.get(`/duo/instant/by-token/${encodeURIComponent(token)}`);
  }

  static async instantJoin(
    token: string,
    appCount: number,
    title?: string
  ): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'token': token,
      'app_count': appCount
    };
    const trimmed = (title ?? '').trim();
    if (trimmed.length > 0) {
      body['title'] = trimmed;
    }
    return HttpService.post('/duo/instant/join', body);
  }

  static async instantOnlineMatch(sessionId: string): Promise<ApiEnvelope> {
    return HttpService.post(
      `/duo/instant/${encodeURIComponent(sessionId)}/online-match`,
      {}
    );
  }

  static async getSession(sessionId: string): Promise<ApiEnvelope> {
    return HttpService.get(`/duo/session/${encodeURIComponent(sessionId)}`);
  }

  static async cancelSession(sessionId: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {};
    return HttpService.post(`/duo/session/${sessionId}/cancel`, body);
  }

  static async breachSession(sessionId: string, reason: string = 'tear'): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'reason': reason
    };
    return HttpService.post(`/duo/session/${sessionId}/breach`, body);
  }

  static async completeSession(sessionId: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {};
    return HttpService.post(`/duo/session/${sessionId}/complete`, body);
  }

  static async scheduledCreate(payload: DuoScheduledCreatePayload): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'title': payload.title,
      'start': payload.start,
      'start_min': payload.start_min,
      'end': payload.end,
      'end_min': payload.end_min,
      'repeat': payload.repeat
    };
    if (payload.participation_mode && payload.participation_mode.length > 0) {
      body['participation_mode'] = payload.participation_mode;
    }
    if (payload.initiator_apps && payload.initiator_apps.length > 0) {
      body['initiator_apps'] = payload.initiator_apps;
    }
    if (payload.mode && payload.mode.length > 0) {
      body['mode'] = payload.mode;
    }
    if (payload.friend_invite_user_id && payload.friend_invite_user_id.length > 0) {
      body['friend_invite_user_id'] = payload.friend_invite_user_id;
    }
    if (payload.kind && payload.kind.length > 0) {
      body['kind'] = payload.kind;
    }
    return HttpService.post('/duo/scheduled/create', body);
  }

  static async getScheduledList(role?: 'initiated' | 'joined'): Promise<ApiEnvelope> {
    if (role === undefined) {
      return HttpService.get('/duo/scheduled/list');
    }
    const query: Record<string, string> = {
      'role': role
    };
    return HttpService.getWithQuery('/duo/scheduled/list', query);
  }

  static async scheduledJoin(
    token: string,
    partnerApps: string[],
    title?: string
  ): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'token': token,
      'partner_apps': partnerApps
    };
    const trimmed = (title ?? '').trim();
    if (trimmed.length > 0) {
      body['title'] = trimmed;
    }
    return HttpService.post('/duo/scheduled/join', body);
  }

  static async scheduledUpdate(
    sessionId: string,
    payload: DuoScheduledUpdatePayload
  ): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {};
    if (payload.title !== undefined) {
      body['title'] = payload.title;
    }
    if (payload.start !== undefined) {
      body['start'] = payload.start;
    }
    if (payload.start_min !== undefined) {
      body['start_min'] = payload.start_min;
    }
    if (payload.end !== undefined) {
      body['end'] = payload.end;
    }
    if (payload.end_min !== undefined) {
      body['end_min'] = payload.end_min;
    }
    if (payload.repeat !== undefined) {
      body['repeat'] = payload.repeat;
    }
    if (payload.mode !== undefined) {
      body['mode'] = payload.mode;
    }
    if (payload.initiator_apps !== undefined) {
      body['initiator_apps'] = payload.initiator_apps;
    }
    if (payload.partner_apps !== undefined) {
      body['partner_apps'] = payload.partner_apps;
    }
    if (payload.enabled !== undefined) {
      body['enabled'] = payload.enabled === true;
    }
    return HttpService.post(`/duo/scheduled/${encodeURIComponent(sessionId)}/update`, body);
  }

  static async scheduledLeave(sessionId: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {};
    return HttpService.post(`/duo/scheduled/${encodeURIComponent(sessionId)}/leave`, body);
  }

  static async scheduledCancel(sessionId: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {};
    return HttpService.post(`/duo/scheduled/${encodeURIComponent(sessionId)}/cancel`, body);
  }

  static async getScheduledStats(sessionId: string): Promise<ApiEnvelope> {
    return HttpService.get(`/duo/scheduled/${encodeURIComponent(sessionId)}/stats`, true);
  }

  static async getScheduledRecords(
    sessionId: string,
    page: number,
    limit: number,
  ): Promise<ApiEnvelope> {
    const query: Record<string, string> = {};
    query['page'] = String(page);
    query['limit'] = String(limit);
    return HttpService.getWithQuery(
      `/duo/scheduled/${encodeURIComponent(sessionId)}/records`,
      query,
      true,
    );
  }

  static parseScheduledList(envelope: ApiEnvelope): DuoScheduledListResult {
    if (envelope.statusCode !== 200 || !envelope.data) {
      const empty: DuoScheduledListResult = { items: [] };
      return empty;
    }
    return parseDuoScheduledList(envelope.data as Record<string, Object>);
  }

  static async activateScheduledSession(
    sessionId: string,
    context?: common.Context
  ): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {};
    const path = `/duo/scheduled/${encodeURIComponent(sessionId)}/activate`;
    if (context) {
      return ExtensionNetworkService.post(context, path, body);
    }
    return HttpService.post(path, body, true, true);
  }

  static async completeScheduledWindow(
    sessionId: string,
    context?: common.Context,
    occurrenceId: string = '',
    startedAt: number = 0,
    endedAt: number = 0,
    result: string = '',
    failReason: string = ''
  ): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {};
    if (occurrenceId.length > 0) {
      body['occurrence_id'] = occurrenceId;
      body['started_at'] = startedAt;
      body['ended_at'] = endedAt;
      body['result'] = result.length > 0 ? result : 'SUCCESS';
      body['fail_reason'] = failReason;
    }
    return HttpService.post(
      `/duo/scheduled/${encodeURIComponent(sessionId)}/complete-window`,
      body,
      true,
      true,
      context
    );
  }

  static async getStatsSummary(period: string): Promise<ApiEnvelope> {
    const query: Record<string, string> = {
      'period': period
    };
    return HttpService.getWithQuery('/duo/stats/summary', query);
  }

  static async getStatsTimeline(period: string): Promise<ApiEnvelope> {
    const query: Record<string, string> = {
      'period': period
    };
    return HttpService.getWithQuery('/duo/stats/timeline', query);
  }

  static async getStatsShame(period: string): Promise<ApiEnvelope> {
    const query: Record<string, string> = {
      'period': period
    };
    return HttpService.getWithQuery('/duo/stats/shame', query);
  }

  static async getStatsByTask(period: string): Promise<ApiEnvelope> {
    const query: Record<string, string> = {
      'period': period
    };
    return HttpService.getWithQuery('/duo/stats/by-task', query);
  }

  static async getStatsByDay(period: string): Promise<ApiEnvelope> {
    const query: Record<string, string> = {
      'period': period
    };
    return HttpService.getWithQuery('/duo/stats/by-day', query);
  }

  static async getCheckinStatsByDay(period: string): Promise<ApiEnvelope> {
    const query: Record<string, string> = {
      'period': period
    };
    return HttpService.getWithQuery('/checkins/stats/by-day', query);
  }

  static parsePendingFriendInvite(envelope: ApiEnvelope): PendingFriendInvite | null {
    if (envelope.statusCode !== 200 || !envelope.data || typeof envelope.data !== 'object') {
      return null;
    }
    const data = envelope.data as Record<string, Object>;
    const token = String(data['token'] ?? '').trim();
    if (token.length === 0) {
      return null;
    }
    const initiatorRaw = data['initiator'];
    let name = '';
    if (initiatorRaw && typeof initiatorRaw === 'object') {
      name = String((initiatorRaw as Record<string, Object>)['nickname'] ?? '').trim();
    }
    const invite: PendingFriendInvite = {
      token: token,
      durationMin: Number(data['duration_min']) || 0,
      initiatorName: name.length > 0 ? name : '搭子',
    };
    return invite;
  }

  static parseSession(envelope: ApiEnvelope): DuoSessionView | null {
    if (envelope.statusCode !== 200) {
      return null;
    }
    return parseDuoSessionView(envelope.data as Record<string, Object>);
  }

  static parseSummary(envelope: ApiEnvelope): DuoStatsSummary | null {
    if (envelope.statusCode !== 200) {
      return null;
    }
    return parseDuoStatsSummary(envelope.data as Record<string, Object>);
  }

  static parseTimeline(envelope: ApiEnvelope): DuoStatsTimeline | null {
    if (envelope.statusCode !== 200 || !envelope.data) {
      return null;
    }
    return parseDuoStatsTimeline(envelope.data as Record<string, Object>);
  }

  static parseShame(envelope: ApiEnvelope): DuoStatsShame | null {
    if (envelope.statusCode !== 200 || !envelope.data) {
      return null;
    }
    return parseDuoStatsShame(envelope.data as Record<string, Object>);
  }

  static parseByTask(envelope: ApiEnvelope): DuoStatsByTask | null {
    if (envelope.statusCode !== 200 || !envelope.data) {
      return null;
    }
    return parseDuoStatsByTask(envelope.data as Record<string, Object>);
  }
}

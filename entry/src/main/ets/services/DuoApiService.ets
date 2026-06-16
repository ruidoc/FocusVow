import {
  DuoScheduledCreatePayload,
  DuoSessionView,
  DuoStatsShame,
  DuoStatsSummary,
  DuoStatsTimeline,
  parseDuoSessionView,
  parseDuoStatsShame,
  parseDuoStatsSummary,
  parseDuoStatsTimeline
} from '../models/DuoModel';
import { ApiEnvelope } from '../models/UserModel';
import { HttpService } from './HttpService';

export class DuoApiService {
  static async instantStart(title: string, durationMin: number): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'title': title,
      'duration_min': durationMin
    };
    return HttpService.post('/duo/instant/start', body);
  }

  static async instantCreate(title: string, durationMin: number): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'title': title,
      'duration_min': durationMin
    };
    return HttpService.post('/duo/instant/create', body);
  }

  static async getByToken(token: string): Promise<ApiEnvelope> {
    return HttpService.get(`/duo/instant/by-token/${encodeURIComponent(token)}`);
  }

  static async instantJoin(token: string, appCount: number): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'token': token,
      'app_count': appCount
    };
    return HttpService.post('/duo/instant/join', body);
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
    return HttpService.post('/duo/scheduled/create', body);
  }

  static async scheduledJoin(token: string, appCount: number): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'token': token,
      'app_count': appCount
    };
    return HttpService.post('/duo/scheduled/join', body);
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
}

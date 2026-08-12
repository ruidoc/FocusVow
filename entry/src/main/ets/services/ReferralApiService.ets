import { ApiEnvelope } from '../models/UserModel';
import { HttpService } from './HttpService';

export interface ReferralInvitee {
  user_id: string;
  username: string;
  status: string;
  created_at: string;
  granted_at: string;
  inviter_days: number;
}

export interface ReferralProgress {
  invite_code: string;
  successful_count: number;
  pending_count: number;
  invited_count: number;
  total_days_earned: number;
  invitees: ReferralInvitee[];
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

export function parseReferralProgress(raw: Object | undefined): ReferralProgress | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const data = raw as Record<string, Object>;
  const inviteesRaw = data['invitees'];
  const invitees: ReferralInvitee[] = [];
  if (Array.isArray(inviteesRaw)) {
    const list = inviteesRaw as Object[];
    for (let i = 0; i < list.length; i++) {
      const row = list[i];
      if (!row || typeof row !== 'object') {
        continue;
      }
      const item = row as Record<string, Object>;
      invitees.push({
        user_id: asString(item['user_id']),
        username: asString(item['username']),
        status: asString(item['status']),
        created_at: asString(item['created_at']),
        granted_at: asString(item['granted_at']),
        inviter_days: asNumber(item['inviter_days'], 15)
      });
    }
  }
  return {
    invite_code: asString(data['invite_code']),
    successful_count: asNumber(data['successful_count'], 0),
    pending_count: asNumber(data['pending_count'], 0),
    invited_count: asNumber(data['invited_count'], invitees.length),
    total_days_earned: asNumber(data['total_days_earned'], 0),
    invitees
  };
}

export class ReferralApiService {
  static async check(code: string): Promise<ApiEnvelope> {
    const query: Record<string, string> = {
      'code': code
    };
    return HttpService.getWithQuery('/referral/check', query, false);
  }

  static async progress(): Promise<ApiEnvelope> {
    return HttpService.get('/referral/progress', true);
  }

  static async bind(referralCode: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'referral_code': referralCode
    };
    return HttpService.post('/referral/bind', body, true);
  }
}

import { ApiEnvelope } from '../models/UserModel';
import { HttpService } from './HttpService';

export interface UserAppUpsertItem {
  app_key: string;
  app_type?: string;
  display_name?: string;
  token_payload?: string | null;
  group_id?: string;
  is_selected?: boolean;
}

/**
 * 新逻辑：双写统一表 user_apps（旧接口鸿蒙本来就不用）。
 * 失败仅打日志，不影响本机选 App。
 */
export class UserAppApiService {
  static async upsertSelectedTokens(tokens: string[]): Promise<void> {
    const apps: UserAppUpsertItem[] = tokens
      .map((token: string): UserAppUpsertItem | null => {
        const key = String(token || '').trim();
        if (key.length === 0) {
          return null;
        }
        return {
          app_key: key,
          app_type: 'application',
          display_name: '',
          token_payload: key,
          is_selected: true
        };
      })
      .filter((item: UserAppUpsertItem | null): boolean => item !== null) as UserAppUpsertItem[];

    try {
      const body: Record<string, Object> = {
        'platform': 'harmony',
        'replace_selected': true
      };
      body['apps'] = apps;
      const res: ApiEnvelope = await HttpService.post('/user-apps/upsert', body, true, true);
      if (res.statusCode !== 200) {
        console.warn('[user-apps] harmony upsert failed', res.message);
      }
    } catch (error) {
      console.warn('[user-apps] harmony upsert error', error);
    }
  }
}

import { InboxItem, parseInboxItem, parseInboxItems } from '../models/InboxModel';
import { ApiEnvelope } from '../models/UserModel';
import { HttpService } from './HttpService';

export class InboxApiService {
  static async unreadCount(): Promise<ApiEnvelope> {
    return HttpService.get('/inbox/unread-count');
  }

  static async list(): Promise<ApiEnvelope> {
    return HttpService.get('/inbox');
  }

  static async getOne(id: string): Promise<ApiEnvelope> {
    return HttpService.get(`/inbox/${encodeURIComponent(id)}`);
  }

  static async markRead(id: string): Promise<ApiEnvelope> {
    return HttpService.post(`/inbox/${encodeURIComponent(id)}/read`, {});
  }

  static async markAllRead(): Promise<ApiEnvelope> {
    return HttpService.post('/inbox/read-all', {});
  }

  static parseList(response: ApiEnvelope): InboxItem[] {
    if (response.statusCode !== 200 || !response.data) {
      return [];
    }
    const data = response.data as Record<string, Object>;
    return parseInboxItems(data['items']);
  }

  static parseOne(response: ApiEnvelope): InboxItem | null {
    if (response.statusCode !== 200 || !response.data) {
      return null;
    }
    return parseInboxItem(response.data as Record<string, Object>);
  }

  static parseUnreadCount(response: ApiEnvelope): number {
    if (response.statusCode !== 200 || !response.data) {
      return 0;
    }
    const data = response.data as Record<string, Object>;
    const raw = Number(data['count'] ?? data['unread_count'] ?? 0);
    return Number.isFinite(raw) ? raw : 0;
  }

  static parseImportantCount(response: ApiEnvelope): number {
    if (response.statusCode !== 200 || !response.data) {
      return 0;
    }
    const data = response.data as Record<string, Object>;
    const raw = Number(data['important_count'] ?? 0);
    return Number.isFinite(raw) ? raw : 0;
  }

  static parseListUnread(response: ApiEnvelope): number {
    if (response.statusCode !== 200 || !response.data) {
      return 0;
    }
    const data = response.data as Record<string, Object>;
    const raw = Number(data['unread_count'] ?? 0);
    return Number.isFinite(raw) ? raw : 0;
  }

  static parseListImportant(response: ApiEnvelope): number {
    if (response.statusCode !== 200 || !response.data) {
      return 0;
    }
    const data = response.data as Record<string, Object>;
    const raw = Number(data['important_count'] ?? 0);
    return Number.isFinite(raw) ? raw : 0;
  }
}

import { ApiEnvelope } from '../models/UserModel';
import { QuickTask, QuickTaskUpsertPayload, parseQuickTask } from '../models/QuickTaskModel';
import { HttpService } from './HttpService';

function buildUpsertBody(payload: QuickTaskUpsertPayload): Record<string, Object> {
  return {
    'title': payload.title,
    'duration_min': payload.duration_min,
    'timer_mode': payload.timer_mode,
    'mode': payload.mode,
    'delay_min': payload.delay_min,
    'no_stop': payload.no_stop,
    'apps': payload.apps
  };
}

export class QuickTaskApiService {
  static parseList(response: ApiEnvelope): QuickTask[] {
    if (response.statusCode !== 200 || !(response.data instanceof Array)) {
      return [];
    }
    const items: QuickTask[] = [];
    response.data.forEach((raw: Object) => {
      const task = parseQuickTask(raw as Record<string, Object>);
      if (task) {
        items.push(task);
      }
    });
    return items;
  }

  static parseTask(response: ApiEnvelope): QuickTask | null {
    if (response.statusCode !== 200 || !response.data) {
      return null;
    }
    return parseQuickTask(response.data);
  }

  static async list(): Promise<ApiEnvelope> {
    return HttpService.get('/quick-task/list');
  }

  static async add(payload: QuickTaskUpsertPayload): Promise<ApiEnvelope> {
    return HttpService.post('/quick-task/add', buildUpsertBody(payload));
  }

  static async edit(id: string, payload: QuickTaskUpsertPayload): Promise<ApiEnvelope> {
    return HttpService.put(`/quick-task/edit/${encodeURIComponent(id)}`, buildUpsertBody(payload));
  }

  static async remove(id: string): Promise<ApiEnvelope> {
    return HttpService.delete(`/quick-task/remove/${encodeURIComponent(id)}`);
  }
}

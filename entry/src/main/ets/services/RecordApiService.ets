import { ApiEnvelope } from '../models/UserModel';
import { HttpService } from './HttpService';

export class RecordApiService {
  static async completeRecord(recordId: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {};
    return HttpService.post(`/record/complete/${recordId}`, body);
  }

  static async failRecord(recordId: string, reason: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'reason': reason
    };
    return HttpService.post(`/record/fail/${recordId}`, body);
  }
}

import { ApiEnvelope } from '../models/UserModel';
import { HttpService } from './HttpService';

export class ExtendApiService {
  static sendEmailCode(email: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'email': email
    };
    return HttpService.post('/extend/email/send-code', body, false);
  }

  static verifyEmailCode(email: string, code: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'email': email,
      'code': code
    };
    return HttpService.post('/extend/email/verify-code', body, false);
  }
}

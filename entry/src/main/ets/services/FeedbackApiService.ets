import { ApiEnvelope } from '../models/UserModel';
import { HttpService } from './HttpService';

export class FeedbackApiService {
  static submitFeedback(
    type: string,
    content: string,
    contact: string,
    appVersion: string
  ): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'type': type,
      'content': content,
      'contact': contact,
      'app_version': appVersion
    };
    return HttpService.post('/feedback', body);
  }
}

import { ApiEnvelope } from '../models/UserModel';
import { HttpService } from './HttpService';

export class AuthApiService {
  static loginWithEmail(email: string, password: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'email': email,
      'password': password
    };
    return HttpService.post('/user/login', body, false);
  }

  static registerWithEmail(
    email: string,
    username: string,
    password: string
  ): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'email': email,
      'username': username,
      'password': password,
      'invite_code': ''
    };
    return HttpService.post('/user/register', body, false);
  }

  static fetchSelfInfo(): Promise<ApiEnvelope> {
    return HttpService.get('/user/info/self', true);
  }
}

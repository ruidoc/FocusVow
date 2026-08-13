import { common } from '@kit.AbilityKit';
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
    password: string,
    referralCode: string = ''
  ): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'email': email,
      'username': username,
      'password': password,
      'referral_code': referralCode
    };
    return HttpService.post('/user/register', body, false);
  }

  static fetchSelfInfo(): Promise<ApiEnvelope> {
    return HttpService.get('/user/info/self', true);
  }

  static updateUser(data: Record<string, Object>): Promise<ApiEnvelope> {
    return HttpService.post('/user/update', data, true);
  }

  static uploadAvatarFile(
    absolutePath: string,
    context?: common.Context
  ): Promise<ApiEnvelope> {
    return HttpService.uploadFile(
      '/extend/upload-uinfo-file',
      absolutePath,
      'file',
      'avatar.jpg',
      'image/jpeg',
      context
    );
  }

  /** App 微信 code 登录；新用户返回 statusCode 20003 + 微信资料 */
  static loginWithWechatCode(code: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'code': code
    };
    return HttpService.post('/user/wechat-app', body, false);
  }

  /** 微信新用户绑定邮箱建号/挂号 */
  static wechatBindByEmail(
    email: string,
    code: string,
    wxInfo: Record<string, Object>
  ): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'email': email,
      'code': code,
      'openid': wxInfo['openid'] ?? '',
      'unionid': wxInfo['unionid'] ?? '',
      'avatar': wxInfo['headimgurl'] ?? wxInfo['avatar'] ?? '',
      'username': wxInfo['nickname'] ?? wxInfo['username'] ?? '',
      'sex': wxInfo['sex'] ?? 0
    };
    return HttpService.post('/user/wechat-bind-by-email', body, false);
  }

  /** 微信新用户跳过邮箱直接建号 */
  static wechatCreate(wxInfo: Record<string, Object>): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'openid': wxInfo['openid'] ?? '',
      'unionid': wxInfo['unionid'] ?? '',
      'avatar': wxInfo['headimgurl'] ?? wxInfo['avatar'] ?? '',
      'username': wxInfo['nickname'] ?? wxInfo['username'] ?? '',
      'sex': wxInfo['sex'] ?? 0
    };
    return HttpService.post('/user/wechat-create', body, false);
  }

  /** 已登录用户绑定微信 */
  static bindWechatByCode(code: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'code': code
    };
    return HttpService.post('/user/wechat-bind-code', body, true);
  }

  /** 已登录用户绑定邮箱 */
  static bindEmailByCode(email: string, code: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'email': email,
      'code': code
    };
    return HttpService.post('/user/bind-email', body, true);
  }
}

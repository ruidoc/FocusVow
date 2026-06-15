import { http } from '@kit.NetworkKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { ApiConfig } from '../config/ApiConfig';
import { ApiEnvelope } from '../models/UserModel';
import { loadAccessToken } from './UserPersistenceService';

type HttpVerb = 'GET' | 'POST';

export class HttpService {
  static async get(path: string, requiresAuth: boolean = true): Promise<ApiEnvelope> {
    return HttpService.request('GET', path, undefined, requiresAuth);
  }

  static async post(path: string, body: Record<string, Object>, requiresAuth: boolean = true): Promise<ApiEnvelope> {
    return HttpService.request('POST', path, body, requiresAuth);
  }

  private static buildHeaders(requiresAuth: boolean): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'project-tag': ApiConfig.PROJECT_TAG,
      'os': ApiConfig.OS_TAG
    };

    if (requiresAuth) {
      const context = AppContextHolder.get();
      const token = context ? loadAccessToken(context) : '';
      if (token.length > 0) {
        headers['Authorization'] = `Bearer ${token}`;
      }
    }

    return headers;
  }

  private static async request(
    verb: HttpVerb,
    path: string,
    body: Record<string, Object> | undefined,
    requiresAuth: boolean
  ): Promise<ApiEnvelope> {
    const url = `${ApiConfig.BASE_URL}${path}`;
    const httpRequest = http.createHttp();

    try {
      const requestOptions: http.HttpRequestOptions = {
        method: verb === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST,
        header: HttpService.buildHeaders(requiresAuth),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: ApiConfig.CONNECT_TIMEOUT_MS,
        readTimeout: ApiConfig.READ_TIMEOUT_MS
      };
      if (verb === 'POST' && body) {
        requestOptions.extraData = JSON.stringify(body);
      }

      const response = await httpRequest.request(url, requestOptions);

      const rawResult = typeof response.result === 'string' ? response.result : '';
      if (rawResult.length === 0) {
        return {
          statusCode: response.responseCode,
          message: '服务器返回为空'
        };
      }

      const parsed = JSON.parse(rawResult) as ApiEnvelope;
      if (response.responseCode === 401) {
        parsed.statusCode = 401;
        if (!parsed.message) {
          parsed.message = '请重新登录';
        }
      }
      return parsed;
    } catch (error) {
      console.error(`HTTP ${verb} ${path} failed: ${String(error)}`);
      return {
        statusCode: -1,
        message: '网络连接失败，请稍后重试'
      };
    } finally {
      httpRequest.destroy();
    }
  }
}

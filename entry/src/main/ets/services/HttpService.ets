import { http } from '@kit.NetworkKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { ApiConfig } from '../config/ApiConfig';
import { ApiEnvelope } from '../models/UserModel';
import { FocusSyncService } from './FocusSyncService';
import { loadAccessToken } from './UserPersistenceService';

type HttpVerb = 'GET' | 'POST';

const LOG_TAG: string = 'HttpService';

export class HttpService {
  static async get(path: string, requiresAuth: boolean = true, skipPendingFlush: boolean = false): Promise<ApiEnvelope> {
    return HttpService.request('GET', path, undefined, requiresAuth, skipPendingFlush);
  }

  static async getWithQuery(
    path: string,
    query: Record<string, string>,
    requiresAuth: boolean = true,
    skipPendingFlush: boolean = false
  ): Promise<ApiEnvelope> {
    const queryString = Object.keys(query)
      .filter((key: string) => query[key].length > 0)
      .map((key: string) => `${encodeURIComponent(key)}=${encodeURIComponent(query[key])}`)
      .join('&');
    const urlPath = queryString.length > 0 ? `${path}?${queryString}` : path;
    return HttpService.get(urlPath, requiresAuth, skipPendingFlush);
  }

  static async post(
    path: string,
    body: Record<string, Object>,
    requiresAuth: boolean = true,
    skipPendingFlush: boolean = false
  ): Promise<ApiEnvelope> {
    return HttpService.request('POST', path, body, requiresAuth, skipPendingFlush);
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

  private static logApiError(
    verb: HttpVerb,
    url: string,
    statusCode: number,
    message: string,
    rawBody: string,
    requestBody?: Record<string, Object>
  ): void {
    const requestPart = requestBody ? ` | request=${JSON.stringify(requestBody)}` : '';
    console.error(
      `[${LOG_TAG}] ${verb} failed | baseURL=${ApiConfig.BASE_URL} | url=${url} | status=${statusCode} | message=${message}${requestPart} | response=${rawBody}`
    );
  }

  private static async request(
    verb: HttpVerb,
    path: string,
    body: Record<string, Object> | undefined,
    requiresAuth: boolean,
    skipPendingFlush: boolean = false
  ): Promise<ApiEnvelope> {
    if (requiresAuth && !skipPendingFlush && !path.startsWith('/focus/sync')) {
      const context = AppContextHolder.get();
      if (context) {
        await FocusSyncService.flushPending(context);
      }
    }

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
        const message = '服务器返回为空';
        HttpService.logApiError(verb, url, response.responseCode, message, rawResult, body);
        return {
          statusCode: response.responseCode,
          message
        };
      }

      const parsed = JSON.parse(rawResult) as ApiEnvelope;
      if (response.responseCode === 401) {
        parsed.statusCode = 401;
        if (!parsed.message) {
          parsed.message = '请重新登录';
        }
      }

      if (parsed.statusCode !== 200) {
        HttpService.logApiError(
          verb,
          url,
          parsed.statusCode,
          parsed.message ?? '未知错误',
          rawResult,
          body
        );
      }

      return parsed;
    } catch (error) {
      const errorText = String(error);
      console.error(
        `[${LOG_TAG}] ${verb} network error | baseURL=${ApiConfig.BASE_URL} | url=${url} | error=${errorText}`
      );
      return {
        statusCode: -1,
        message: '网络连接失败，请稍后重试'
      };
    } finally {
      httpRequest.destroy();
    }
  }
}

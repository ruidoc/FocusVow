import { http } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { request } from '@kit.BasicServicesKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { getAppVersion, getDeviceModel } from '../common/AppInfo';
import { ApiConfig } from '../config/ApiConfig';
import { ApiEnvelope } from '../models/UserModel';
import { FocusSyncService } from './FocusSyncService';
import { loadAccessToken } from './UserPersistenceService';

type HttpVerb = 'GET' | 'POST';

const LOG_TAG: string = 'HttpService';
const UPLOAD_TIMEOUT_MS: number = 60000;

function fileNameOf(path: string): string {
  const idx = path.lastIndexOf('/');
  return idx >= 0 ? path.substring(idx + 1) : path;
}

/** 确认沙箱文件可读，返回字节数 */
function assertReadableFile(absolutePath: string): number {
  const stat = fileIo.statSync(absolutePath);
  return Number(stat.size);
}

function parseJsonEnvelope(raw: string, httpHint: number): ApiEnvelope {
  let text = raw.trim();
  if (text.length === 0) {
    return {
      statusCode: httpHint > 0 ? httpHint : -1,
      message: '服务器返回为空'
    };
  }
  if (text.startsWith('"') && text.endsWith('"')) {
    try {
      text = JSON.parse(text) as string;
    } catch (_e) {
      // keep
    }
  }
  try {
    const parsed = JSON.parse(text) as ApiEnvelope;
    if (httpHint === 401) {
      parsed.statusCode = 401;
    } else if (httpHint >= 500 &&
      (parsed.statusCode === undefined || parsed.statusCode === 200)) {
      parsed.statusCode = httpHint;
      if (!parsed.message) {
        parsed.message = '服务器错误，请稍后重试';
      }
    }
    return parsed;
  } catch (_e) {
    return {
      statusCode: httpHint > 0 ? httpHint : -1,
      message: `响应异常: ${text.slice(0, 80)}`
    };
  }
}

function extractBodyFromHeader(header: object): string {
  const raw = header as Record<string, Object>;
  const bodyVal = raw['body'];
  if (typeof bodyVal === 'string') {
    return bodyVal;
  }
  if (bodyVal !== undefined && bodyVal !== null) {
    return JSON.stringify(bodyVal);
  }
  return '';
}

export class HttpService {
  static async get(
    path: string,
    requiresAuth: boolean = true,
    skipPendingFlush: boolean = false,
    context?: common.Context
  ): Promise<ApiEnvelope> {
    return HttpService.request('GET', path, undefined, requiresAuth, skipPendingFlush, context);
  }

  static async getWithQuery(
    path: string,
    query: Record<string, string>,
    requiresAuth: boolean = true,
    skipPendingFlush: boolean = false,
    context?: common.Context
  ): Promise<ApiEnvelope> {
    const queryString = Object.keys(query)
      .filter((key: string) => query[key].length > 0)
      .map((key: string) => `${encodeURIComponent(key)}=${encodeURIComponent(query[key])}`)
      .join('&');
    const urlPath = queryString.length > 0 ? `${path}?${queryString}` : path;
    return HttpService.get(urlPath, requiresAuth, skipPendingFlush, context);
  }

  static async post(
    path: string,
    body: Record<string, Object>,
    requiresAuth: boolean = true,
    skipPendingFlush: boolean = false,
    context?: common.Context
  ): Promise<ApiEnvelope> {
    return HttpService.request('POST', path, body, requiresAuth, skipPendingFlush, context);
  }

  /**
   * 上传本地沙箱文件（头像）。
   * 优先 request.uploadFile + internal://cache（鸿蒙官方头像上传写法）；
   * 失败再回退 http.multiFormDataList（须带 Content-Type: multipart/form-data）。
   */
  static async uploadFile(
    path: string,
    absolutePath: string,
    fieldName: string = 'file',
    fileName: string = 'avatar.jpg',
    contentType: string = 'image/jpeg',
    context?: common.Context
  ): Promise<ApiEnvelope> {
    const uploadContext = context ?? AppContextHolder.getAbility() ?? AppContextHolder.get();
    if (!uploadContext) {
      return { statusCode: -1, message: '上传失败：无应用上下文' };
    }

    let size = 0;
    try {
      size = assertReadableFile(absolutePath);
    } catch (error) {
      console.error(`[${LOG_TAG}] file not readable | path=${absolutePath} | ${String(error)}`);
      return { statusCode: -1, message: `头像文件不可读: ${absolutePath}` };
    }
    if (size <= 0) {
      return { statusCode: -1, message: '头像文件为空' };
    }

    const realName = fileNameOf(absolutePath);
    const uploadName = realName.length > 0 ? realName : fileName;
    const url = `${ApiConfig.BASE_URL}${path}`;
    console.info(`[${LOG_TAG}] upload | url=${url} | path=${absolutePath} | size=${size}`);

    const viaRequest = await HttpService.uploadViaRequestAgent(
      uploadContext,
      url,
      uploadName,
      fieldName,
      size
    );
    if (viaRequest.statusCode === 200) {
      return viaRequest;
    }
    console.warn(
      `[${LOG_TAG}] request.uploadFile failed, fallback http | ${viaRequest.message}`
    );

    return HttpService.uploadViaHttpMultipart(
      uploadContext,
      url,
      absolutePath,
      fieldName,
      uploadName,
      contentType,
      size
    );
  }

  /** 方案 A：request.uploadFile + internal://cache/文件名 */
  private static uploadViaRequestAgent(
    context: common.Context,
    url: string,
    fileName: string,
    fieldName: string,
    size: number
  ): Promise<ApiEnvelope> {
    const internalUri = `internal://cache/${fileName}`;
    return new Promise<ApiEnvelope>((resolve: (v: ApiEnvelope) => void) => {
      let settled = false;
      let bodyText = '';

      const finish = (env: ApiEnvelope): void => {
        if (settled) {
          return;
        }
        settled = true;
        resolve(env);
      };

      const timer = setTimeout(() => {
        finish({ statusCode: -1, message: '上传超时(request)' });
      }, UPLOAD_TIMEOUT_MS);

      void (async () => {
        const appVersion = await getAppVersion();
        const headers: Record<string, string> = {
          'project-tag': ApiConfig.PROJECT_TAG,
          'os': ApiConfig.OS_TAG,
          'x-platform': ApiConfig.OS_TAG,
          'device-model': getDeviceModel(),
          'app-version': appVersion,
          'x-app-version': appVersion
        };
        const token = loadAccessToken(context);
        if (token.length > 0) {
          headers['Authorization'] = `Bearer ${token}`;
        }

        const fileItem: request.File = {
          filename: fileName,
          name: fieldName,
          uri: internalUri,
          type: 'jpg'
        };
        const emptyData: request.RequestData[] = [];
        const config: request.UploadConfig = {
          url: url,
          header: headers,
          method: 'POST',
          files: [fileItem],
          data: emptyData
        };

        console.info(`[${LOG_TAG}] uploadViaRequest | uri=${internalUri} | size=${size}`);
        try {
          const task = await request.uploadFile(context, config);
          task.on('headerReceive', (header: object) => {
            bodyText = extractBodyFromHeader(header);
            console.info(`[${LOG_TAG}] headerReceive | ${bodyText.slice(0, 200)}`);
            // 部分机型 headerReceive 即含业务 body，可直接结束
            if (bodyText.length > 0 && bodyText.indexOf('statusCode') >= 0) {
              clearTimeout(timer);
              finish(parseJsonEnvelope(bodyText, 200));
            }
          });
          task.on('complete', (states: Array<request.TaskState>) => {
            const code = states.length > 0 ? states[0].responseCode : 0;
            console.info(`[${LOG_TAG}] request complete | task=${code}`);
            // 等 headerReceive 落到 body（部分机型 complete 先于 header）
            setTimeout(() => {
              clearTimeout(timer);
              if (code !== 0 && bodyText.length === 0) {
                finish({
                  statusCode: code,
                  message: states[0]?.message || `上传失败(${code})`
                });
                return;
              }
              finish(parseJsonEnvelope(bodyText, 200));
            }, 300);
          });
          task.on('fail', (states: Array<request.TaskState>) => {
            clearTimeout(timer);
            const code = states.length > 0 ? states[0].responseCode : -1;
            const msg = states.length > 0 ? states[0].message : 'upload fail';
            console.error(`[${LOG_TAG}] request fail | ${code} ${msg}`);
            if (bodyText.length > 0) {
              finish(parseJsonEnvelope(bodyText, code > 0 ? code : 500));
              return;
            }
            finish({ statusCode: code, message: msg || `上传失败(${code})` });
          });
        } catch (error) {
          clearTimeout(timer);
          finish({ statusCode: -1, message: `request启动失败: ${String(error)}` });
        }
      })();
    });
  }

  /**
   * 方案 B：http.multiFormDataList
   * 官方要求：Header 必须带 Content-Type: multipart/form-data，filePath 为沙箱绝对路径
   */
  private static async uploadViaHttpMultipart(
    context: common.Context,
    url: string,
    absolutePath: string,
    fieldName: string,
    fileName: string,
    contentType: string,
    size: number
  ): Promise<ApiEnvelope> {
    const appVersion = await getAppVersion();
    const headers: Record<string, string> = {
      // 关键：没有这行时 multiFormDataList 会被忽略
      'Content-Type': 'multipart/form-data',
      'project-tag': ApiConfig.PROJECT_TAG,
      'os': ApiConfig.OS_TAG,
      'x-platform': ApiConfig.OS_TAG,
      'device-model': getDeviceModel(),
      'app-version': appVersion,
      'x-app-version': appVersion
    };
    const token = loadAccessToken(context);
    if (token.length > 0) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const formItem: http.MultiFormData = {
      name: fieldName,
      contentType: contentType,
      remoteFileName: fileName,
      filePath: absolutePath
    };

    console.info(`[${LOG_TAG}] uploadViaHttp | filePath=${absolutePath} | size=${size}`);
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        multiFormDataList: [formItem],
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: ApiConfig.CONNECT_TIMEOUT_MS,
        readTimeout: Math.max(ApiConfig.READ_TIMEOUT_MS, 60000)
      });
      const raw = typeof response.result === 'string' ? response.result : '';
      console.info(`[${LOG_TAG}] http upload done | http=${response.responseCode} | ${raw.slice(0, 200)}`);
      if (raw.length === 0) {
        return {
          statusCode: response.responseCode,
          message: '服务器返回为空'
        };
      }
      return parseJsonEnvelope(raw, response.responseCode);
    } catch (error) {
      console.error(`[${LOG_TAG}] http upload error | ${String(error)}`);
      return { statusCode: -1, message: `HTTP上传失败: ${String(error)}` };
    } finally {
      httpRequest.destroy();
    }
  }

  private static async buildHeaders(
    requiresAuth: boolean,
    context?: common.Context
  ): Promise<Record<string, string>> {
    const appVersion = await getAppVersion();
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'project-tag': ApiConfig.PROJECT_TAG,
      'os': ApiConfig.OS_TAG,
      'x-platform': ApiConfig.OS_TAG,
      'device-model': getDeviceModel(),
      'app-version': appVersion,
      'x-app-version': appVersion
    };

    if (requiresAuth) {
      const authContext = context ?? AppContextHolder.get();
      const token = authContext ? loadAccessToken(authContext) : '';
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
    skipPendingFlush: boolean = false,
    context?: common.Context
  ): Promise<ApiEnvelope> {
    if (
      requiresAuth &&
      !skipPendingFlush &&
      !path.startsWith('/focus/sync') &&
      !path.startsWith('/focus/started')
    ) {
      const flushContext = context ?? AppContextHolder.get();
      if (flushContext) {
        await FocusSyncService.flushPending(flushContext);
      }
    }

    const url = `${ApiConfig.BASE_URL}${path}`;
    const httpRequest = http.createHttp();

    try {
      const requestOptions: http.HttpRequestOptions = {
        method: verb === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST,
        header: await HttpService.buildHeaders(requiresAuth, context),
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

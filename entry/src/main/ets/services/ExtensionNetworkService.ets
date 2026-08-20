import { common } from '@kit.AbilityKit';
import { http, connection } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getAppVersion, getDeviceModel } from '../common/AppInfo';
import { ApiConfig } from '../config/ApiConfig';
import { ApiEnvelope } from '../models/UserModel';
import { readStoredString, writeStoredString } from './PreferencesService';
import { loadAccessToken } from './UserPersistenceService';

const DOMAIN: number = 0x0000;
const TAG: string = 'ExtensionNet';
const APP_VERSION_KEY: string = 'http.app_version';
const DEVICE_MODEL_KEY: string = 'http.device_model';
/** 对齐 iOS NetworkManager：请求超时 6s */
const REQUEST_TIMEOUT_MS: number = 6000;

/**
 * 对齐 iOS Shared/Networking.swift：扩展进程专用短 POST。
 * 不走 HttpService（无 flush / 无主进程 Context）。
 */
export class ExtensionNetworkService {
  /** 主进程启动时写入，扩展读盘（对齐 iOS App Group app_version / device_model） */
  static persistClientMeta(context: common.Context): void {
    void getAppVersion().then((version: string) => {
      writeStoredString(context, APP_VERSION_KEY, version);
      const model = getDeviceModel();
      writeStoredString(context, DEVICE_MODEL_KEY, model.length > 0 ? model : 'harmony');
    });
  }

  static async post(
    context: common.Context,
    path: string,
    body: Record<string, Object>
  ): Promise<ApiEnvelope> {
    await ExtensionNetworkService.waitForConnectivity();
    const first = await ExtensionNetworkService.requestOnce(context, path, body);
    if (first.statusCode !== -1) {
      return first;
    }
    await ExtensionNetworkService.sleep(400);
    return ExtensionNetworkService.requestOnce(context, path, body);
  }

  private static async requestOnce(
    context: common.Context,
    path: string,
    body: Record<string, Object>
  ): Promise<ApiEnvelope> {
    const url = `${ApiConfig.BASE_URL}${path}`;
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: ExtensionNetworkService.buildHeaders(context),
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        connectTimeout: REQUEST_TIMEOUT_MS,
        readTimeout: REQUEST_TIMEOUT_MS
      });
      const raw = typeof response.result === 'string' ? response.result : '';
      const parsed = ExtensionNetworkService.parseEnvelope(raw, response.responseCode);
      hilog.info(
        DOMAIN,
        TAG,
        'POST %{public}s http=%{public}d status=%{public}d',
        path,
        response.responseCode,
        parsed.statusCode
      );
      return parsed;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'POST %{public}s failed: %{public}s', path, String(error));
      return { statusCode: -1, message: String(error) };
    } finally {
      httpRequest.destroy();
    }
  }

  private static buildHeaders(context: common.Context): Record<string, string> {
    let appVersion = readStoredString(context, APP_VERSION_KEY, '');
    if (appVersion.length === 0) {
      appVersion = 'unknown';
    }
    let deviceModel = readStoredString(context, DEVICE_MODEL_KEY, '');
    if (deviceModel.length === 0) {
      deviceModel = getDeviceModel();
    }
    if (deviceModel.length === 0) {
      deviceModel = 'harmony';
    }
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'project-tag': ApiConfig.PROJECT_TAG,
      'os': ApiConfig.OS_TAG,
      'x-platform': ApiConfig.OS_TAG,
      'device-model': deviceModel,
      'x-device-model': deviceModel,
      'app-version': appVersion,
      'x-app-version': appVersion
    };
    const token = loadAccessToken(context);
    if (token.length > 0) {
      headers['Authorization'] = `Bearer ${token}`;
    } else {
      hilog.warn(DOMAIN, TAG, 'auth token empty');
    }
    return headers;
  }

  /** 对齐 iOS waitsForConnectivity：无默认网时先等一会再发 */
  private static async waitForConnectivity(): Promise<void> {
    try {
      connection.getDefaultNetSync();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'wait net: %{public}s', String(error));
      await ExtensionNetworkService.sleep(800);
    }
  }

  private static parseEnvelope(raw: string, httpHint: number): ApiEnvelope {
    const text = raw.trim();
    if (text.length === 0) {
      return {
        statusCode: httpHint > 0 ? httpHint : -1,
        message: '服务器返回为空'
      };
    }
    try {
      const parsed = JSON.parse(text) as ApiEnvelope;
      if (httpHint === 401) {
        parsed.statusCode = 401;
      }
      return parsed;
    } catch (error) {
      return {
        statusCode: httpHint > 0 ? httpHint : -1,
        message: String(error)
      };
    }
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }
}

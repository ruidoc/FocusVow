import { common } from '@kit.AbilityKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { ExtensionNetworkService } from './ExtensionNetworkService';
import { readStoredString, writeStoredString } from './PreferencesService';

const LOG_TAG: string = 'FocusStartedNotify';
const DEVICE_ID_KEY: string = 'analytics.device_id';

export type FocusStartScene = 'solo_start' | 'delayed_solo_start' | 'duo_initiate_start' | 'duo_join_start';
export type FocusSessionType = 'instant' | 'scheduled' | 'solo_once';

export interface FocusStartedReportParams {
  scene: FocusStartScene;
  durationMin?: number;
  planId?: string;
  sessionId?: string;
  sessionType?: FocusSessionType;
  /** 用户输入的专注标题 */
  title?: string;
  /** countdown | countup */
  timerMode?: string;
  delayMinutes?: number;
  /** 毫秒时间戳，登录单人用于落 running */
  startedAtMs?: number;
}

/**
 * 开始锁机后上报飞书运营通知（静默、不阻塞主流程）。
 * - 即时单人：LockStore 锁机成功后调用
 * - 即时互督：DuoInstantLockService 锁机成功后调用（带设备头）
 * - 定时锁机：由服务端 activate 推送，勿在此重复报
 */
export class FocusStartedNotifyService {
  static reportSoloStarted(
    context: common.Context | undefined,
    durationMin: number,
    title?: string,
    timerMode?: string,
    planId?: string,
    startedAtMs?: number
  ): void {
    const params: FocusStartedReportParams = {
      scene: 'solo_start',
      durationMin: durationMin,
      sessionType: 'solo_once',
      title: title,
      timerMode: timerMode,
      planId: planId,
      startedAtMs: startedAtMs
    };
    FocusStartedNotifyService.report(context, params);
  }

  static report(
    context: common.Context | undefined,
    params: FocusStartedReportParams
  ): void {
    const host = context ?? AppContextHolder.get();
    if (!host) {
      console.warn(`[${LOG_TAG}] skip: no context`);
      return;
    }
    void FocusStartedNotifyService.postStarted(
      host,
      FocusStartedNotifyService.buildBody(host, params),
    );
  }

  /** TimeGuard 扩展必须 await，否则 onStart 返回后进程退出，请求发不出去 */
  static async reportAndWait(
    context: common.Context | undefined,
    params: FocusStartedReportParams
  ): Promise<boolean> {
    const host = context ?? AppContextHolder.get();
    if (!host) {
      console.warn(`[${LOG_TAG}] skip: no context`);
      return false;
    }
    return FocusStartedNotifyService.postStarted(host, FocusStartedNotifyService.buildBody(host, params));
  }

  private static buildBody(
    host: common.Context,
    params: FocusStartedReportParams
  ): Record<string, Object> {
    const body: Record<string, Object> = {
      'scene': params.scene
    };
    const deviceId = FocusStartedNotifyService.ensureDeviceId(host);
    if (deviceId.length > 0) {
      body['device_id'] = deviceId;
    }
    if (params.durationMin !== undefined && params.durationMin > 0) {
      body['duration_min'] = params.durationMin;
    }
    if (params.planId !== undefined && params.planId.length > 0) {
      body['plan_id'] = params.planId;
    }
    if (params.sessionId !== undefined && params.sessionId.length > 0) {
      body['session_id'] = params.sessionId;
    }
    if (params.sessionType !== undefined) {
      body['session_type'] = params.sessionType;
    }
    if (params.timerMode !== undefined && params.timerMode.length > 0) {
      body['timer_mode'] = params.timerMode;
    }
    if (params.delayMinutes !== undefined && params.delayMinutes > 0) {
      body['delay_minutes'] = params.delayMinutes;
    }
    const focusTitle = (params.title ?? '').trim();
    if (focusTitle.length > 0) {
      body['title'] = focusTitle;
    }
    const startedAt =
      params.startedAtMs !== undefined && params.startedAtMs > 0
        ? Math.round(params.startedAtMs)
        : Date.now();
    body['started_at'] = startedAt;
    if (
      (params.scene === 'solo_start' || params.scene === 'delayed_solo_start') &&
      params.planId !== undefined &&
      params.planId.length > 0
    ) {
      body['client_key'] = params.planId.startsWith('once_')
        ? `solo_plan_${params.planId}`
        : `solo_plan_${startedAt}`;
    }
    return body;
  }

  private static async postStarted(
    host: common.Context,
    body: Record<string, Object>
  ): Promise<boolean> {
    try {
      const res = await ExtensionNetworkService.post(host, '/focus/started', body);
      if (res.statusCode === 200) {
        console.info(`[${LOG_TAG}] report ok scene=${String(body['scene'])}`);
        return true;
      }
      console.warn(`[${LOG_TAG}] report failed: ${res.message}`);
      return false;
    } catch (error) {
      console.warn(`[${LOG_TAG}] report failed: ${String(error)}`);
      return false;
    }
  }

  private static ensureDeviceId(context: common.Context): string {
    const existing = readStoredString(context, DEVICE_ID_KEY, '');
    if (existing.length > 0) {
      return existing;
    }
    const generated =
      `hm_${Date.now().toString(36)}_${Math.floor(Math.random() * 1e9).toString(36)}`;
    writeStoredString(context, DEVICE_ID_KEY, generated);
    return generated;
  }
}

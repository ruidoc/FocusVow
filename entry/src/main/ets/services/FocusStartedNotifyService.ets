import { common } from '@kit.AbilityKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { HttpService } from './HttpService';
import { readStoredString, writeStoredString } from './PreferencesService';

const LOG_TAG: string = 'FocusStartedNotify';
const DEVICE_ID_KEY: string = 'analytics.device_id';

export type FocusStartScene = 'solo_start' | 'duo_initiate_start' | 'duo_join_start';
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
    timerMode?: string
  ): void {
    const params: FocusStartedReportParams = {
      scene: 'solo_start',
      durationMin: durationMin,
      sessionType: 'solo_once',
      title: title,
      timerMode: timerMode
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
    const focusTitle = (params.title ?? '').trim();
    if (focusTitle.length > 0) {
      body['title'] = focusTitle;
    }

    // requiresAuth=true：有 token 则带上；skipPendingFlush=true：不阻塞锁机
    HttpService.post('/focus/started', body, true, true, host)
      .then(() => {
        // no-op
      })
      .catch((error: Object) => {
        console.warn(`[${LOG_TAG}] report failed: ${String(error)}`);
      });
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

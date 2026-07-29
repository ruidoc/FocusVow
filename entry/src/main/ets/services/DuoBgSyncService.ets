import { common, wantAgent, Want, WantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppContextHolder } from '../common/AppContextHolder';
import {
  formatRemainingSeconds,
  getRemainingSeconds,
  isLocked
} from '../models/ActiveLockModel';
import { LockStore } from '../stores/LockStore';
import { StoreKeys } from '../stores/StoreKeys';

const DOMAIN: number = 0x0000;
const TAG: string = 'DuoBgSync';
/** 与安卓前台服务一致：每秒刷新倒计时 */
const TICK_MS: number = 1000;
/** 会话状态轮询间隔 */
const SYNC_EVERY_TICKS: number = 5;
/** 上传/下载类实况窗 typeCode，见长时任务 DATA_TRANSFER 更新示例 */
const LIVE_VIEW_TYPE_DATA_TRANSFER: number = 8;

type DuoBgPollFn = (context: common.UIAbilityContext) => Promise<void>;

interface StatusCopy {
  title: string;
  text: string;
  /**
   * 0~100，按「已流逝 / 总时长」计算，与倒计时一致：
   * 刚开始 ≈ 0，接近结束 ≈ 100。
   * 仅 showProgress=true（专注中）时写入 downloadTemplate。
   */
  progress: number;
  /** 等待搭子：只要文案；专注中：带进度圆环 */
  showProgress: boolean;
}

/** 系统实况窗更新字段（与 NotificationSystemLiveViewContent 对齐） */
interface DuoLiveViewContent {
  typeCode: number;
  title: string;
  text: string;
}

let pollFn: DuoBgPollFn | null = null;
let running: boolean = false;
let starting: boolean = false;
let tickId: number = -1;
let tickCount: number = 0;
let notificationId: number = -1;
let cachedWantAgent: WantAgent | null = null;
let lastPublishedText: string = '';

/** 单人 / 搭子专注锁定（不含 cycle_guard） */
function isFocusLockActive(context: common.Context): boolean {
  LockStore.hydrate(context);
  const state = LockStore.getState();
  return isLocked(state) && (state.kind === 'quick_focus' || state.kind === 'covenant');
}

function needsBgSync(context: common.Context): boolean {
  const waitId = AppStorage.get<string>(StoreKeys.DuoWaitSessionId) ?? '';
  const waitScheduled = AppStorage.get<boolean>(StoreKeys.DuoWaitIsScheduled) === true;
  if (waitId.length > 0 && !waitScheduled) {
    return true;
  }

  return isFocusLockActive(context);
}

function isAppForeground(): boolean {
  return AppStorage.get<boolean>(StoreKeys.AppIsForeground) === true;
}

/** 已完成比例 0~100（圆环随时间前进填充） */
function elapsedProgress(remainSec: number, totalSec: number): number {
  if (totalSec <= 0) {
    return 100;
  }
  const elapsed = Math.max(0, totalSec - Math.max(0, remainSec));
  return Math.min(100, Math.round((elapsed / totalSec) * 100));
}

function buildStatusCopy(context: common.Context): StatusCopy {
  if (isFocusLockActive(context)) {
    const state = LockStore.getState();
    if (state.timerMode === 'countup') {
      const elapsed = Math.max(0, Math.floor((Date.now() - state.startedAt) / 1000));
      const totalSec = Math.max(1, state.minDurationMin) * 60;
      return {
        title: '专注进行中',
        text: `已专注 ${formatRemainingSeconds(elapsed)}`,
        progress: Math.min(100, Math.round((elapsed / totalSec) * 100)),
        showProgress: true
      };
    }
    const remain = getRemainingSeconds(state, Date.now());
    const totalSec = state.endAt > state.startedAt
      ? Math.max(1, Math.ceil((state.endAt - state.startedAt) / 1000))
      : 1;
    if (remain > 0) {
      return {
        title: '专注进行中',
        text: `剩余 ${formatRemainingSeconds(remain)}`,
        progress: elapsedProgress(remain, totalSec),
        showProgress: true
      };
    }
    return {
      title: '专注进行中',
      text: '契约锁机已开启',
      progress: 100,
      showProgress: true
    };
  }

  const waitId = AppStorage.get<string>(StoreKeys.DuoWaitSessionId) ?? '';
  if (waitId.length > 0) {
    const expireAt = AppStorage.get<number>(StoreKeys.DuoWaitExpireAtMs) ?? 0;
    const remainSec = expireAt > 0
      ? Math.max(0, Math.ceil((expireAt - Date.now()) / 1000))
      : 0;
    if (remainSec > 0) {
      return {
        title: '等待搭子加入',
        text: `剩余 ${formatRemainingSeconds(remainSec)}`,
        progress: 0,
        showProgress: false
      };
    }
    return {
      title: '等待搭子加入',
      text: '邀请即将过期',
      progress: 0,
      showProgress: false
    };
  }

  return {
    title: '专注契约',
    text: '后台同步中',
    progress: 0,
    showProgress: false
  };
}

/**
 * 即时搭子等待 / 单人与搭子专注锁定：仅在退后台时申请 DATA_TRANSFER 长时任务。
 * 用同一 notificationId + downloadTemplate 更新系统 LIVE_VIEW 通知。
 * 注意：downloadTemplate 进度色由系统固定（蓝），无法改成品牌色。
 */
export class DuoBgSyncService {
  static bindPoll(fn: DuoBgPollFn): void {
    pollFn = fn;
  }

  static ensure(hostContext?: common.UIAbilityContext): void {
    const context = hostContext ?? AppContextHolder.getAbility();
    if (!context) {
      return;
    }
    if (needsBgSync(context) && !isAppForeground()) {
      void DuoBgSyncService.start(context);
      return;
    }
    void DuoBgSyncService.stop(context);
  }

  private static async start(context: common.UIAbilityContext): Promise<void> {
    if (running || starting) {
      DuoBgSyncService.startTicking(context);
      return;
    }

    starting = true;
    try {
      const launchWant: Want = {
        bundleName: context.abilityInfo.bundleName,
        abilityName: context.abilityInfo.name
      };
      const wantInfo: wantAgent.WantAgentInfo = {
        wants: [launchWant],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent: WantAgent = await wantAgent.getWantAgent(wantInfo);
      cachedWantAgent = agent;
      const res: backgroundTaskManager.ContinuousTaskNotification =
        await backgroundTaskManager.startBackgroundRunning(
          context,
          ['dataTransfer'],
          agent
        );
      notificationId = res.notificationId;
      running = true;
      lastPublishedText = '';
      hilog.info(DOMAIN, TAG, 'continuous task started, notificationId=%{public}d', notificationId);
      await DuoBgSyncService.updateContinuousTaskNotification(context);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'start continuous task failed: %{public}s', String(error));
    } finally {
      starting = false;
    }
    DuoBgSyncService.startTicking(context);
  }

  private static async stop(context: common.UIAbilityContext): Promise<void> {
    DuoBgSyncService.stopTicking();
    if (!running) {
      notificationId = -1;
      cachedWantAgent = null;
      lastPublishedText = '';
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(context);
      hilog.info(DOMAIN, TAG, 'continuous task stopped');
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'stop continuous task failed: %{public}s', String(error));
    } finally {
      running = false;
      notificationId = -1;
      cachedWantAgent = null;
      lastPublishedText = '';
    }
  }

  private static startTicking(context: common.UIAbilityContext): void {
    if (tickId !== -1) {
      return;
    }
    tickCount = 0;
    tickId = setInterval(() => {
      void DuoBgSyncService.onTick(context);
    }, TICK_MS);
    void DuoBgSyncService.onTick(context);
  }

  private static stopTicking(): void {
    if (tickId === -1) {
      return;
    }
    clearInterval(tickId);
    tickId = -1;
    tickCount = 0;
  }

  private static async onTick(context: common.UIAbilityContext): Promise<void> {
    if (!needsBgSync(context) || isAppForeground()) {
      DuoBgSyncService.ensure(context);
      return;
    }

    await DuoBgSyncService.updateContinuousTaskNotification(context);

    tickCount += 1;
    if (tickCount % SYNC_EVERY_TICKS !== 0) {
      return;
    }
    if (!pollFn) {
      return;
    }
    await pollFn(context);
  }

  /**
   * 更新系统长时任务 LIVE_VIEW（同一 id）。
   * DATA_TRANSFER 必须带 downloadTemplate 才能盖掉默认「正在运行数据传输任务」；
   * - 等待搭子：template 只带 title/fileName（无 progressValue → 无圆环）
   * - 专注中：再带 progressValue 显示进度圆环
   */
  private static async updateContinuousTaskNotification(context: common.UIAbilityContext): Promise<void> {
    if (notificationId < 0) {
      return;
    }
    const copy = buildStatusCopy(context);
    const fingerprint = `${copy.title}|${copy.text}|${copy.progress}|${copy.showProgress}`;
    if (fingerprint === lastPublishedText) {
      return;
    }

    const liveViewContent: DuoLiveViewContent = {
      typeCode: LIVE_VIEW_TYPE_DATA_TRANSFER,
      title: copy.title,
      text: copy.text
    };
    const content: notificationManager.NotificationContent = {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
      systemLiveView: liveViewContent
    };
    const templateData: Record<string, Object> = {};
    templateData['title'] = copy.title;
    templateData['fileName'] = copy.text;
    if (copy.showProgress) {
      templateData['progressValue'] = copy.progress;
    }
    const downLoadTemplate: notificationManager.NotificationTemplate = {
      name: 'downloadTemplate',
      data: templateData
    };
    const request: notificationManager.NotificationRequest = {
      id: notificationId,
      notificationSlotType: notificationManager.SlotType.LIVE_VIEW,
      content: content,
      template: downLoadTemplate,
      isAlertOnce: true
    };
    if (cachedWantAgent) {
      request.wantAgent = cachedWantAgent;
    }

    try {
      await notificationManager.publish(request);
      lastPublishedText = fingerprint;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'update continuous task notification failed: %{public}s', String(error));
    }
  }
}

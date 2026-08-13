import { common } from '@kit.AbilityKit';
import { isOnboardingCompleted } from './OnboardingApiService';
import { readStoredString, writeStoredString } from './PreferencesService';
import { NotificationPermissionService } from './NotificationPermissionService';
import { UmengSdkService } from './UmengSdkService';

const NOTIFY_AUTO_ASKED_KEY: string = 'notify_permission_auto_asked';

let inFlight: Promise<void> | null = null;

/**
 * 对齐 RN ensureNotifyOnLaunch：
 * - 引导未完成：绝不申请（也不记 asked，避免引导期把机会用掉）
 * - 进入已完成引导的首页后再弹系统通知授权（只自动弹一次）
 * - 并发调用共用同一次弹窗，方便首页等弹完再出首次专注引导
 */
export function ensureNotifyOnLaunch(context: common.UIAbilityContext): Promise<void> {
  if (inFlight) {
    return inFlight;
  }
  inFlight = runEnsureNotifyOnLaunch(context).finally(() => {
    inFlight = null;
  });
  return inFlight;
}

async function runEnsureNotifyOnLaunch(context: common.UIAbilityContext): Promise<void> {
  try {
    if (!isOnboardingCompleted(context)) {
      return;
    }
    if (await NotificationPermissionService.isNotifyEnabled()) {
      UmengSdkService.enablePushNotification(context);
      return;
    }
    const asked = readStoredString(context, NOTIFY_AUTO_ASKED_KEY, '') === '1';
    if (asked) {
      return;
    }
    writeStoredString(context, NOTIFY_AUTO_ASKED_KEY, '1');
    await NotificationPermissionService.requestNotify(context);
    if (await NotificationPermissionService.isNotifyEnabled()) {
      UmengSdkService.enablePushNotification(context);
    }
  } catch (_e) {
    // 静默：不阻塞首页
  }
}

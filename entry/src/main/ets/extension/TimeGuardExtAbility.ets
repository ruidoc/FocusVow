import { common } from '@kit.AbilityKit';
import { TimeGuardExtensionAbility } from '@kit.ScreenTimeGuardKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { handleCycleStrategyStart, handleCycleStrategyStop, isCycleGuardStrategyName } from '../services/CycleGuardService';
import { loadPersistedActiveLockState } from '../services/ActiveLockPersistenceService';
import { getApplicationStorageContext } from '../services/PreferencesService';
import { handlePlanStrategyStart, handlePlanStrategyStop } from '../services/TimeGuardRuntimeService';

const DOMAIN = 0x0000;
const TAG = '扩展事件';

export default class TimeGuardExtAbility extends TimeGuardExtensionAbility {
  private getAppContext(): common.Context {
    return getApplicationStorageContext(this.context as common.Context);
  }

  private beginSuspendDelay(reason: string): number {
    try {
      const info: backgroundTaskManager.DelaySuspendInfo =
        backgroundTaskManager.requestSuspendDelay(reason, () => {
          hilog.warn(DOMAIN, TAG, 'suspend delay timeout reason=%{public}s', reason);
        });
      return info.requestId;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'requestSuspendDelay failed: %{public}s', String(error));
      return -1;
    }
  }

  private endSuspendDelay(delayId: number): void {
    if (delayId < 0) {
      return;
    }
    try {
      backgroundTaskManager.cancelSuspendDelay(delayId);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'cancelSuspendDelay failed: %{public}s', String(error));
    }
  }

  async onStart(strategyName: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'started: %{public}s', strategyName);
    const delayId = this.beginSuspendDelay('timeguard lock start');
    const appContext = this.getAppContext();
    try {
      if (isCycleGuardStrategyName(strategyName)) {
        await handleCycleStrategyStart(appContext, strategyName);
        return;
      }
      await handlePlanStrategyStart(appContext, strategyName);
      const lockState = loadPersistedActiveLockState(appContext);
      hilog.info(
        DOMAIN,
        TAG,
        'after onStart lock kind=%{public}s planId=%{public}s',
        lockState?.kind ?? 'null',
        lockState?.planId ?? ''
      );
    } finally {
      this.endSuspendDelay(delayId);
    }
  }

  async onStop(strategyName: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'stopped: %{public}s', strategyName);
    const delayId = this.beginSuspendDelay('timeguard lock stop');
    const appContext = this.getAppContext();
    try {
      if (isCycleGuardStrategyName(strategyName)) {
        await handleCycleStrategyStop(appContext, strategyName);
        return;
      }
      await handlePlanStrategyStop(appContext, strategyName);
    } finally {
      this.endSuspendDelay(delayId);
    }
  }

  async onUserAuthSwitchOn(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'User authorized ScreenTimeGuard.');
  }

  async onUserAuthSwitchOff(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'User revoked ScreenTimeGuard authorization.');
  }
}

import { common } from '@kit.AbilityKit';
import { TimeGuardExtensionAbility } from '@kit.ScreenTimeGuardKit';
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

  async onStart(strategyName: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'started: %{public}s', strategyName);
    const appContext = this.getAppContext();
    if (isCycleGuardStrategyName(strategyName)) {
      await handleCycleStrategyStart(appContext, strategyName);
      return;
    }
    handlePlanStrategyStart(appContext, strategyName);
    const lockState = loadPersistedActiveLockState(appContext);
    hilog.info(
      DOMAIN,
      TAG,
      'after onStart lock kind=%{public}s planId=%{public}s',
      lockState?.kind ?? 'null',
      lockState?.planId ?? ''
    );
  }

  async onStop(strategyName: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'stopped: %{public}s', strategyName);
    const appContext = this.getAppContext();
    if (isCycleGuardStrategyName(strategyName)) {
      await handleCycleStrategyStop(appContext, strategyName);
      return;
    }
    await handlePlanStrategyStop(appContext, strategyName);
  }

  async onUserAuthSwitchOn(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'User authorized ScreenTimeGuard.');
  }

  async onUserAuthSwitchOff(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'User revoked ScreenTimeGuard authorization.');
  }
}

import { common } from '@kit.AbilityKit';
import { TimeGuardExtensionAbility } from '@kit.ScreenTimeGuardKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { handleCycleStrategyStart, handleCycleStrategyStop, isCycleGuardStrategyName } from '../services/CycleGuardService';
import { handlePlanStrategyStart, handlePlanStrategyStop } from '../services/TimeGuardRuntimeService';

const DOMAIN = 0x0000;
const TAG = '扩展事件';

export default class TimeGuardExtAbility extends TimeGuardExtensionAbility {
  async onStart(strategyName: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'started: %{public}s', strategyName);
    if (isCycleGuardStrategyName(strategyName)) {
      await handleCycleStrategyStart(this.context as common.Context, strategyName);
      return;
    }
    handlePlanStrategyStart(this.context as common.Context, strategyName);
  }

  async onStop(strategyName: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'stopped: %{public}s', strategyName);
    if (isCycleGuardStrategyName(strategyName)) {
      await handleCycleStrategyStop(this.context as common.Context, strategyName);
      return;
    }
    handlePlanStrategyStop(this.context as common.Context, strategyName);
  }

  async onUserAuthSwitchOn(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'User authorized ScreenTimeGuard.');
  }

  async onUserAuthSwitchOff(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'User revoked ScreenTimeGuard authorization.');
  }
}

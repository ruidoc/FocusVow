import { application } from '@kit.AbilityKit';
import { TimeGuardExtensionAbility } from '@kit.ScreenTimeGuardKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { handleCycleStrategyStart, handleCycleStrategyStop } from '../services/CycleGuardService';

const DOMAIN = 0x0000;
const TAG = 'FocusTimeGuard';

export default class FocusTimeGuardExtensionAbility extends TimeGuardExtensionAbility {
  async onStart(strategyName: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Guard strategy started: %{public}s', strategyName);
    await handleCycleStrategyStart(application.getApplicationContext(), strategyName);
  }

  async onStop(strategyName: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Guard strategy stopped: %{public}s', strategyName);
    await handleCycleStrategyStop(application.getApplicationContext(), strategyName);
  }

  async onUserAuthSwitchOn(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'User authorized ScreenTimeGuard.');
  }

  async onUserAuthSwitchOff(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'User revoked ScreenTimeGuard authorization.');
  }
}

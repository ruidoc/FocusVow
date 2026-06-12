import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppContextHolder } from '../common/AppContextHolder';
import { getPreferencesStorageDir, warmUpPreferencesStore } from '../services/PreferencesService';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch {
      hilog.error(DOMAIN, 'testTag', '%{public}s', 'Failed to set colorMode.');
    }
    AppContextHolder.bind(this.context);
    warmUpPreferencesStore(this.context);
    hilog.info(DOMAIN, 'testTag', 'preferences storage dir=%{public}s', getPreferencesStorageDir(this.context));
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/tabs/MainTabPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');

      windowStage.getMainWindow((winErr, win) => {
        if (winErr.code) {
          hilog.error(DOMAIN, 'testTag', 'getMainWindow failed: %{public}s', JSON.stringify(winErr));
          return;
        }
        try {
          win.setWindowLayoutFullScreen(true);
          const barProps: window.SystemBarProperties = {
            statusBarColor: '#00000000',
            navigationBarColor: '#00000000',
            statusBarContentColor: '#FF0F172A',
            navigationBarContentColor: '#FF0F172A'
          };
          win.setWindowSystemBarProperties(barProps);
        } catch (e) {
          hilog.error(DOMAIN, 'testTag', 'Immersive window failed: %{public}s', String(e));
        }
      });
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}

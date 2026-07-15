import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { MsgContent, PushAgent } from '@umeng/push';
import { AppContextHolder } from '../common/AppContextHolder';
import { getPreferencesStorageDir, warmUpPreferencesStore } from '../services/PreferencesService';
import { DuoBgSyncService } from '../services/DuoBgSyncService';
import { DuoPushHandler } from '../services/DuoPushHandler';
import { UmengPushMessageBody } from '../models/DuoModel';
import { FocusSyncService } from '../services/FocusSyncService';
import { UmengSdkService } from '../services/UmengSdkService';
import { StoreKeys } from '../stores/StoreKeys';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch {
      hilog.error(DOMAIN, TAG, '%{public}s', 'Failed to set colorMode.');
    }
    AppContextHolder.bind(this.context);
    webview.WebviewController.initializeWebEngine();
    AppStorage.setOrCreate(StoreKeys.AppIsForeground, false);
    warmUpPreferencesStore(this.context);
    DuoBgSyncService.bindPoll((ctx) => {
      return DuoPushHandler.syncActiveDuoSessionIfNeeded(ctx, { isForeground: false });
    });
    this.setupPushAgent();
    UmengSdkService.handleLaunchWant(want, this.context);
    hilog.info(DOMAIN, TAG, 'preferences storage dir=%{public}s', getPreferencesStorageDir(this.context));
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    UmengSdkService.handleLaunchWant(want, this.context);
  }

  private setupPushAgent(): void {
    UmengSdkService.setupPushListeners();

    PushAgent.initCallback((data: Record<string, string>) => {
      UmengSdkService.handlePushInitCallback(data);
    });

    PushAgent.onClickMessage((extra: Record<string, string>) => {
      hilog.info(DOMAIN, TAG, 'push click extra: %{public}s', JSON.stringify(extra));
      void DuoPushHandler.handlePayload(
        DuoPushHandler.parsePushPayload(extra),
        { isForeground: AppStorage.get<boolean>(StoreKeys.AppIsForeground) ?? false },
        this.context
      );
    });

    PushAgent.onCustomMessage((customMsg: MsgContent) => {
      hilog.info(DOMAIN, TAG, 'push custom message: %{public}s', JSON.stringify(customMsg));
      const bodyText = DuoPushHandler.extractCustomBody(customMsg.body as UmengPushMessageBody);
      const payload = DuoPushHandler.parsePushPayload(
        customMsg.extra as Record<string, string>,
        bodyText
      );
      void DuoPushHandler.handlePayload(payload, {
        isForeground: AppStorage.get<boolean>(StoreKeys.AppIsForeground) ?? false
      }, this.context);
    });
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
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    AppStorage.setOrCreate(StoreKeys.AppIsForeground, true);
    AppStorage.setOrCreate(StoreKeys.AppForegroundAt, Date.now());
    const context = AppContextHolder.get();
    if (context) {
      void FocusSyncService.flushPending(context);
      void DuoPushHandler.processPendingBreach(this.context).then(() => {
        return DuoPushHandler.syncActiveDuoSessionIfNeeded(this.context, { isForeground: true });
      }).then(() => {
        DuoBgSyncService.ensure(this.context);
      });
    }
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    AppStorage.setOrCreate(StoreKeys.AppIsForeground, false);
    DuoBgSyncService.ensure(this.context);
  }
}

import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../../constants/Theme';
import { ActiveLockState, createIdleLockState, normalizeActiveLockState } from '../../models/ActiveLockModel';
import { endQuickFocus } from '../../services/ActiveLockLifecycleService';
import { queueHonorCertificate, tryPresentCertificateGuide } from '../../services/CertificatePendingService';
import { DuoInviteClipboardService } from '../../services/DuoInviteClipboardService';
import { FocusSyncService } from '../../services/FocusSyncService';
import { CycleGuardStore } from '../../stores/CycleGuardStore';
import { warmUpPreferencesStore } from '../../services/PreferencesService';
import { syncAllPlanGuardStrategies } from '../../services/ScreenTimeService';
import { reconcileLockLifecycle } from '../../services/LockReconcileService';
import { UmengSdkService } from '../../services/UmengSdkService';
import { LockStore } from '../../stores/LockStore';
import { PlanStore } from '../../stores/PlanStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { PageRoutes, pushRoute, pushPrivacyPolicy } from '../../router/PageRoutes';
import { ContractTabPage } from './ContractTabPage';
import { FocusHomePage } from './FocusHomePage';
import { ProfilePage } from './ProfilePage';
import { StatsPage } from './StatsPage';
import { InAppMessageBanner } from '../../components/common/InAppMessageBanner';

bootstrapStores();

export type MainTabKey = 'focus' | 'plans' | 'stats' | 'profile';

@Entry
@Component
struct MainTabPage {
  @State currentTab: MainTabKey = 'focus';
  @State private bottomGestureInsetVp: number = 0;
  @StorageLink(StoreKeys.LockActiveState) activeLock: ActiveLockState = createIdleLockState();
  @StorageLink(StoreKeys.AppForegroundAt) foregroundAt: number = 0;
  @StorageLink(StoreKeys.MainTabTarget) @Watch('onMainTabTargetChanged') pendingTab: string = '';

  private timerId: number = -1;
  private isEndingLock: boolean = false;
  private lastClipboardProbeAt: number = 0;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const ui = this.getUIContext();
    warmUpPreferencesStore(hostContext);
    UserStore.hydrate(hostContext);
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
    void UserStore.syncRemoteIfLoggedIn(hostContext);
    if (UserStore.isLoggedIn()) {
      void FocusSyncService.flushPending(hostContext);
    }
    void syncAllPlanGuardStrategies(PlanStore.getPlans());
    this.startTimer();
    this.bootstrapUmengSdk(hostContext);
    void this.probeClipboardInvite(hostContext);
    this.consumePendingTab();

    window.getLastWindow(hostContext, (err, win) => {
      if (err !== undefined && err.code !== 0) {
        return;
      }
      const navAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.bottomGestureInsetVp = ui.px2vp(navAvoid.bottomRect.height);
    });
  }

  aboutToDisappear(): void {
    this.clearTimer();
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private startTimer(): void {
    this.clearTimer();
    this.timerId = setInterval(() => {
      this.syncLockLifecycle();
    }, 1000);
  }

  private onMainTabTargetChanged(): void {
    this.consumePendingTab();
  }

  private consumePendingTab(): void {
    if (this.pendingTab === 'focus' ||
      this.pendingTab === 'plans' ||
      this.pendingTab === 'stats' ||
      this.pendingTab === 'profile') {
      this.currentTab = this.pendingTab;
      this.pendingTab = '';
    }
  }

  private async probeClipboardInvite(context: common.UIAbilityContext): Promise<void> {
    await DuoInviteClipboardService.probeClipboard(context, this.getUIContext());
  }

  private maybeProbeClipboardOnForeground(context: common.UIAbilityContext): void {
    if (this.foregroundAt <= this.lastClipboardProbeAt) {
      return;
    }
    this.lastClipboardProbeAt = this.foregroundAt;
    void this.probeClipboardInvite(context);
  }

  private bootstrapUmengSdk(context: common.UIAbilityContext): void {
    const afterInit = (): void => {
      UmengSdkService.ensureInitialized(context);
      UmengSdkService.enablePushNotification(context);
      if (UserStore.isLoggedIn()) {
        UmengSdkService.bindUserAlias(UserStore.getUserInfo().id);
      }
    };

    if (UmengSdkService.isPrivacyAgreed(context)) {
      afterInit();
      return;
    }

    this.getUIContext().showAlertDialog({
      title: '服务说明',
      message: '为向你发送专注提醒等通知，应用将使用友盟推送与统计服务。你可随时在系统设置中关闭通知权限。',
      autoCancel: false,
      primaryButton: {
        value: '同意并继续',
        action: () => {
          UmengSdkService.markPrivacyAgreed(context);
          afterInit();
        }
      },
      secondaryButton: {
        value: '查看隐私政策',
        action: () => {
          pushPrivacyPolicy();
        }
      }
    });
  }

  private syncLockLifecycle(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.maybeProbeClipboardOnForeground(hostContext);
    warmUpPreferencesStore(hostContext);
    SettingsStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
    void reconcileLockLifecycle(hostContext);
    tryPresentCertificateGuide(this.getUIContext());

    if (this.activeLock.kind === 'quick_focus' && LockStore.shouldAutoFinish()) {
      void this.finishQuickFocus();
    }
  }

  private async finishQuickFocus(): Promise<void> {
    if (this.activeLock.kind !== 'quick_focus' || this.isEndingLock) {
      return;
    }

    this.isEndingLock = true;
    const lockSnapshot = normalizeActiveLockState(this.activeLock);
    const endedAt = Date.now();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const ok = await endQuickFocus(
      hostContext,
      lockSnapshot,
      '契约已履行，恭喜上岸',
      '专注已结束，但解除限制失败'
    );
    if (ok) {
      queueHonorCertificate(lockSnapshot, endedAt);
      tryPresentCertificateGuide(this.getUIContext());
    }
    this.isEndingLock = false;
  }

  @Builder
  private buildTabSymbol(tab: MainTabKey): void {
    SymbolGlyph(this.getTabSymbol(tab))
      .fontSize(21)
      .fontColor([this.currentTab === tab ? AppTheme.colors.primary : AppTheme.colors.textSecondary])
      .fontWeight(this.currentTab === tab ? 500 : 400)
  }

  private getTabSymbol(tab: MainTabKey): Resource {
    const selected = this.currentTab === tab;
    if (tab === 'focus') {
      return selected ? $r('sys.symbol.timer_circle_fill') : $r('sys.symbol.timer');
    }

    if (tab === 'plans') {
      return selected ? $r('sys.symbol.doc_plaintext_fill') : $r('sys.symbol.doc_plaintext');
    }

    if (tab === 'stats') {
      return selected ? $r('sys.symbol.calendar') : $r('sys.symbol.calendar');
    }

    return selected ? $r('sys.symbol.person_fill') : $r('sys.symbol.person');
  }

  @Builder
  private buildTabItem(tab: MainTabKey, title: string): void {
    Column({ space: 6 }) {
      this.buildTabSymbol(tab)

      Text(title)
        .fontSize(12)
        .fontWeight(this.currentTab === tab ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentTab === tab ? AppTheme.colors.primary : AppTheme.colors.textSecondary)
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 2 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.currentTab = tab;
    })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        Stack() {
          FocusHomePage({
            onSelectTab: (tab: 'plans') => {
              this.currentTab = tab;
            }
          })
            .width('100%')
            .height('100%')
            .visibility(this.currentTab === 'focus' ? Visibility.Visible : Visibility.Hidden)

          ContractTabPage({ isPageActive: this.currentTab === 'plans' })
            .width('100%')
            .height('100%')
            .visibility(this.currentTab === 'plans' ? Visibility.Visible : Visibility.Hidden)

          StatsPage()
            .width('100%')
            .height('100%')
            .visibility(this.currentTab === 'stats' ? Visibility.Visible : Visibility.Hidden)

          ProfilePage()
            .width('100%')
            .height('100%')
            .visibility(this.currentTab === 'profile' ? Visibility.Visible : Visibility.Hidden)
        }
        .width('100%')
        .layoutWeight(1)

        Row() {
          this.buildTabItem('focus', '专注')
          this.buildTabItem('plans', '计划')
          this.buildTabItem('stats', '统计')
          this.buildTabItem('profile', '我的')
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 + this.bottomGestureInsetVp })
        .backgroundColor(AppTheme.colors.backgroundSoft)
        .border({ width: 1, color: AppTheme.colors.border })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppTheme.colors.background)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      InAppMessageBanner()
    }
    .width('100%')
    .height('100%')
  }
}

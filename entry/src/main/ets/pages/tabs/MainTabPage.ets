import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../../constants/Theme';
import { ActiveLockState, createIdleLockState } from '../../models/ActiveLockModel';
import { endQuickFocus } from '../../services/ActiveLockLifecycleService';
import { CycleGuardStore } from '../../stores/CycleGuardStore';
import { warmUpPreferencesStore } from '../../services/PreferencesService';
import { syncAllPlanGuardStrategies } from '../../services/ScreenTimeService';
import { LockStore } from '../../stores/LockStore';
import { PlanStore } from '../../stores/PlanStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';
import { ContractTabPage } from './ContractTabPage';
import { CycleGuardDetailPage } from './CycleGuardDetailPage';
import { FocusHomePage } from './FocusHomePage';
import { ProfilePage } from './ProfilePage';

bootstrapStores();

export type MainTabKey = 'focus' | 'contract' | 'guard' | 'profile';

@Entry
@Component
struct MainTabPage {
  @State currentTab: MainTabKey = 'focus';
  @State private bottomGestureInsetVp: number = 0;
  @StorageLink(StoreKeys.LockActiveState) activeLock: ActiveLockState = createIdleLockState();

  private timerId: number = -1;
  private isEndingLock: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const ui = this.getUIContext();
    warmUpPreferencesStore(hostContext);
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
    void syncAllPlanGuardStrategies(PlanStore.getPlans());
    this.startTimer();

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

  private syncLockLifecycle(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    warmUpPreferencesStore(hostContext);
    SettingsStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);

    if (this.activeLock.kind === 'quick_focus' && LockStore.shouldAutoFinish()) {
      this.finishQuickFocus();
    }
  }

  private async finishQuickFocus(): Promise<void> {
    if (this.activeLock.kind !== 'quick_focus' || this.isEndingLock) {
      return;
    }

    this.isEndingLock = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await endQuickFocus(
      hostContext,
      this.activeLock,
      '专注已完成，限制已自动解除',
      '专注已结束，但解除限制失败'
    );
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

    if (tab === 'contract') {
      return selected ? $r('sys.symbol.doc_plaintext_fill') : $r('sys.symbol.doc_plaintext');
    }

    if (tab === 'guard') {
      return selected ? $r('sys.symbol.bolt_shield_fill') : $r('sys.symbol.bolt_shield');
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
    Column() {
      if (this.currentTab === 'focus') {
        FocusHomePage({
          onSelectTab: (tab: 'contract' | 'guard') => {
            this.currentTab = tab;
          }
        })
          .layoutWeight(1)
      } else if (this.currentTab === 'contract') {
        ContractTabPage()
          .layoutWeight(1)
      } else if (this.currentTab === 'guard') {
        CycleGuardDetailPage()
          .layoutWeight(1)
      } else {
        ProfilePage()
          .layoutWeight(1)
      }

      Row() {
        this.buildTabItem('focus', '专注')
        this.buildTabItem('contract', '契约')
        this.buildTabItem('guard', '限额')
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
  }
}

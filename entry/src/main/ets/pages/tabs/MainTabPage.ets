import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../../constants/Theme';
import { FocusRunStatus, FocusSession, createIdleFocusSession } from '../../models/FocusSession';
import { finishRunningFocusSession } from '../../services/FocusLifecycleService';
import { FocusStore } from '../../stores/FocusStore';
import { PlanStore } from '../../stores/PlanStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';
import { FocusHomePage } from './FocusHomePage';
import { ProfilePage } from './ProfilePage';
import { StatsPage } from './StatsPage';

bootstrapStores();

type MainTabKey = 'focus' | 'stats' | 'profile';

@Entry
@Component
struct MainTabPage {
  @State currentTab: MainTabKey = 'focus';
  @State private bottomGestureInsetVp: number = 0;
  @StorageLink(StoreKeys.FocusCurrentSession) currentSession: FocusSession = createIdleFocusSession();

  private timerId: number = -1;
  private isStopping: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const ui = this.getUIContext();
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    FocusStore.hydrate(hostContext);
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
      this.syncFocusLifecycle();
    }, 1000);
  }

  private syncFocusLifecycle(): void {
    if (FocusStore.shouldAutoFinish()) {
      this.finishCurrentFocus();
    }
  }

  private async finishCurrentFocus(): Promise<void> {
    if (this.currentSession.status !== FocusRunStatus.Running || this.isStopping) {
      return;
    }

    this.isStopping = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await finishRunningFocusSession(
      hostContext,
      this.currentSession,
      '专注已完成，限制已自动解除',
      '专注已结束，但解除限制失败'
    );
    this.isStopping = false;
  }

  @Builder
  private buildTabSymbol(tab: MainTabKey): void {
    SymbolGlyph(this.getTabSymbol(tab))
      .fontSize(22)
      .fontColor([this.currentTab === tab ? AppTheme.colors.primary : AppTheme.colors.textSecondary])
      .fontWeight(this.currentTab === tab ? 500 : 400)
  }

  private getTabSymbol(tab: MainTabKey): Resource {
    const selected = this.currentTab === tab;
    if (tab === 'focus') {
      return selected ? $r('sys.symbol.timer_circle_fill') : $r('sys.symbol.timer');
    }

    if (tab === 'stats') {
      return selected ? $r('sys.symbol.doc_plaintext_fill') : $r('sys.symbol.doc_plaintext');
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
    .padding({ top: 10, bottom: 0 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.currentTab = tab;
    })
  }

  build() {
    Column() {
      if (this.currentTab === 'focus') {
        FocusHomePage()
          .layoutWeight(1)
      } else if (this.currentTab === 'stats') {
        StatsPage()
          .layoutWeight(1)
      } else {
        ProfilePage()
          .layoutWeight(1)
      }

      Row() {
        this.buildTabItem('focus', '专注')
        this.buildTabItem('stats', '统计')
        this.buildTabItem('profile', '我的')
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 6, bottom: 6 + this.bottomGestureInsetVp })
      .backgroundColor(AppTheme.colors.backgroundSoft)
      .border({ width: 1, color: AppTheme.colors.border })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.colors.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

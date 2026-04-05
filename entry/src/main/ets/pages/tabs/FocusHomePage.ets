import { common } from '@kit.AbilityKit';
import { PageScaffold } from '../../components/common/PageScaffold';
import { AppTheme } from '../../constants/Theme';
import { FocusPlan } from '../../models/PlanModel';
import { FocusRunStatus, FocusSession, createIdleFocusSession } from '../../models/FocusSession';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { finishRunningFocusSession } from '../../services/FocusLifecycleService';
import { FocusStore } from '../../stores/FocusStore';
import { PlanStore } from '../../stores/PlanStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Component
export struct FocusHomePage {
  @StorageLink(StoreKeys.FocusCurrentSession) currentSession: FocusSession = createIdleFocusSession();
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.SettingsStatusMessage) statusMessage: string = '先申请系统授权，再选择需要限制的应用';
  @State remainingLabel: string = FocusStore.getRemainingLabel();

  private timerId: number = -1;
  private isStopping: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    FocusStore.hydrate(hostContext);
    this.syncRemainingLabel();
    this.startTimer();
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
      this.syncRemainingLabel();
    }, 1000);
  }

  private syncRemainingLabel(): void {
    this.remainingLabel = FocusStore.getRemainingLabel();
  }

  private async finishCurrentFocus(isAutoFinished: boolean): Promise<void> {
    if (this.currentSession.status !== FocusRunStatus.Running || this.isStopping) {
      return;
    }

    this.isStopping = true;
    this.clearTimer();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await finishRunningFocusSession(
      hostContext,
      this.currentSession,
      isAutoFinished ? '专注已完成，限制已自动解除' : '你已手动结束专注',
      isAutoFinished ? '专注已结束，但解除限制失败' : '结束专注失败'
    );

    this.remainingLabel = FocusStore.getRemainingLabel();
    this.isStopping = false;
    this.startTimer();
  }

  private getGreeting(): string {
    const currentHour = new Date().getHours();
    if (currentHour < 12) {
      return '上午好';
    }
    if (currentHour < 18) {
      return '下午好';
    }
    return '晚上好';
  }

  private getTodayPlanBadge(): string {
    return this.planCollection.length > 0 ? `今日 ${this.planCollection.length} 个契约` : '今日无契约';
  }

  private getHeaderStatusText(): string {
    if (this.currentSession.status === FocusRunStatus.Running) {
      return '这段专注正在进行，继续保持。';
    }
    return '今天还没开始，加油！';
  }

  @Builder
  private buildHomeHeader(): void {
    Row() {
      Column({ space: 6 }) {
        Text(`${this.getGreeting()}，专注者！`)
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')

        Text(this.getHeaderStatusText())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(16)
          .fontColor([AppTheme.colors.textPrimary])
        Text(this.getTodayPlanBadge())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
      }
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(AppTheme.colors.surfaceRaised)
      .borderRadius(AppTheme.radius.pill)
      .border({ width: 1, color: AppTheme.colors.border })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private buildRunningState(): void {
    Column({ space: 18 }) {
      Text(this.remainingLabel)
        .fontSize(56)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)

      Text(this.currentSession.planName.length > 0 ? this.currentSession.planName : '快速专注进行中')
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .textAlign(TextAlign.Center)

      Text(`已限制 ${this.currentSession.selectedCount} 个应用，结束后会自动解除限制`)
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .textAlign(TextAlign.Center)

      Button('结束当前专注')
        .width('100%')
        .height(56)
        .type(ButtonType.Capsule)
        .backgroundColor(AppTheme.colors.dangerSoft)
        .fontColor(AppTheme.colors.danger)
        .border({ width: 1, color: AppTheme.colors.danger })
        .onClick(() => {
          this.finishCurrentFocus(false);
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildEmptyState(): void {
    Column({ space: 18 }) {
      Stack() {
        Column()
          .width(112)
          .height(112)
          .borderRadius(56)
          .backgroundColor(AppTheme.colors.primarySoft)
          .opacity(0.22)
          .blur(40)

        Column()
          .width(72)
          .height(72)
          .borderRadius(36)
          .backgroundColor('#2B213D')
          .opacity(0.75)

        SymbolGlyph($r('sys.symbol.timer'))
          .fontSize(40)
          .fontColor(['#F3B562'])
          .fontWeight(500)
      }
      .width(120)
      .height(120)
      .alignContent(Alignment.Center)

      Column({ space: 10 }) {
        Text('改变，从一个契约开始')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)

        Text('设定时间段，每日自动锁定分心应用')
          .fontSize(16)
          .fontColor(AppTheme.colors.textSecondary)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Button('创建契约')
        .width('100%')
        .height(58)
        .type(ButtonType.Capsule)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .onClick(() => {
          pushRoute(PageRoutes.PlanAdd);
        })

      Row({ space: 6 }) {
        Text('临时使用？')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)

        SymbolGlyph($r('sys.symbol.bolt'))
          .fontSize(14)
          .fontColor([AppTheme.colors.primary])
        Text('快速专注')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.primary)
      }
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        pushRoute(PageRoutes.QuickStart);
      })
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildHomeContent(): void {
    Column() {
      Blank()

      if (this.currentSession.status === FocusRunStatus.Running) {
        this.buildRunningState()
      } else {
        this.buildEmptyState()
      }

      Blank()

      Text(this.statusMessage)
        .fontSize(12)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 8 })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    PageScaffold({
      headerMode: 'custom',
      showDecoration: true,
      topPadding: 18,
      bottomPadding: 12,
      header: () => { this.buildHomeHeader() },
      content: () => { this.buildHomeContent() }
    })
  }
}

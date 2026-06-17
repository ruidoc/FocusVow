import { common } from '@kit.AbilityKit';
import { AppActionButton } from '../../components/common/AppActionButton';
import { AppTheme } from '../../constants/Theme';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import {
  ActiveLockState,
  createIdleLockState,
  isLocked
} from '../../models/ActiveLockModel';
import { FocusPlan } from '../../models/PlanModel';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import {
  endCycleGuardLock,
  skipCovenantWindow,
  tearQuickFocus
} from '../../services/ActiveLockLifecycleService';
import { LockStore } from '../../stores/LockStore';
import { PlanStore } from '../../stores/PlanStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Component
export struct FocusHomePage {
  onSelectTab?: (tab: 'plans') => void;
  @StorageLink(StoreKeys.LockActiveState) activeLock: ActiveLockState = createIdleLockState();
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @StorageLink(StoreKeys.SettingsStatusMessage) statusMessage: string = '先申请系统授权，再选择需要限制的应用';
  @State remainingLabel: string = LockStore.getRemainingLabel();

  private timerId: number = -1;
  private isEndingLock: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
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
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    this.remainingLabel = LockStore.getRemainingLabel();
  }

  private isActiveLocked(): boolean {
    return isLocked(this.activeLock);
  }

  private getTearFirstMessage(): string {
    if (this.activeLock.participationMode === 'duo') {
      return '撕毁后本次专注立即失败，搭子也会被连坐。';
    }
    return '撕毁后本次专注记为违约，会进入耻辱柱。';
  }

  private getTearSecondMessage(): string {
    if (this.activeLock.participationMode === 'duo') {
      return '再次确认：撕毁契约后无法撤销，你与搭子都将受到连坐惩罚。';
    }
    return '再次确认：撕毁契约后无法撤销，本次将记入耻辱柱。';
  }

  private async endCurrentLock(): Promise<void> {
    if (this.isEndingLock || !this.isActiveLocked()) {
      return;
    }

    if (this.activeLock.kind === 'quick_focus') {
      this.openFirstTearConfirm();
      return;
    }

    await this.performEndLock();
  }

  private openFirstTearConfirm(): void {
    this.getUIContext().showAlertDialog({
      title: '撕毁契约',
      message: `${this.getTearFirstMessage()}这是第一次确认，请想清楚。`,
      autoCancel: true,
      primaryButton: {
        value: '继续',
        fontColor: AppTheme.colors.danger,
        action: () => {
          this.openSecondTearConfirm();
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  private openSecondTearConfirm(): void {
    this.getUIContext().showAlertDialog({
      title: '撕毁契约',
      message: `${this.getTearSecondMessage()}这是第二次确认，请再次想清楚。`,
      autoCancel: true,
      primaryButton: {
        value: '确认撕毁',
        fontColor: AppTheme.colors.danger,
        action: () => {
          void this.performTearLock();
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  private async performTearLock(): Promise<void> {
    if (this.isEndingLock || this.activeLock.kind !== 'quick_focus') {
      return;
    }
    this.isEndingLock = true;
    this.clearTimer();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await tearQuickFocus(hostContext, this.activeLock);
    this.remainingLabel = LockStore.getRemainingLabel();
    this.isEndingLock = false;
    this.startTimer();
  }

  private async performEndLock(): Promise<void> {
    if (this.isEndingLock || !this.isActiveLocked()) {
      return;
    }

    this.isEndingLock = true;
    this.clearTimer();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

    if (this.activeLock.kind === 'covenant') {
      await skipCovenantWindow(hostContext, this.activeLock);
    } else if (this.activeLock.kind === 'cycle_guard') {
      await endCycleGuardLock(hostContext);
    }

    this.remainingLabel = LockStore.getRemainingLabel();
    this.isEndingLock = false;
    this.startTimer();
  }

  private getLockSubtitle(): string {
    const count = this.activeLock.selectedCount;
    if (this.activeLock.kind === 'covenant') {
      return `已限制 ${count} 个应用，当前由契约自动锁定`;
    }
    if (this.activeLock.kind === 'cycle_guard') {
      return `娱乐限额已用完，当前已限制 ${count} 个应用`;
    }
    return `已限制 ${count} 个应用，计时结束后自动上岸`;
  }

  private getEndLockButtonLabel(): string {
    if (this.activeLock.kind === 'quick_focus') {
      return '撕毁契约';
    }
    if (this.activeLock.kind === 'covenant') {
      return '结束本次契约';
    }
    if (this.activeLock.kind === 'cycle_guard') {
      return '结束当前锁定';
    }
    return '结束';
  }

  private getLockHint(): string {
    if (this.activeLock.kind === 'cycle_guard') {
      return '结束后会重新开始一轮娱乐限额计时';
    }
    if (this.activeLock.kind === 'covenant') {
      return '仅跳过本次窗口，下一周期仍会正常执行';
    }
    if (this.activeLock.kind === 'quick_focus') {
      return '提前结束视为撕毁契约，自然跑满才算上岸';
    }
    return '';
  }

  @Builder
  private buildStatusIcon(isLockedState: boolean): void {
    Stack() {
      if (!isLockedState) {
        Column()
          .width(112)
          .height(112)
          .borderRadius(56)
          .backgroundColor(AppTheme.colors.primarySoft)
          .opacity(0.22)
          .blur(40)
      }

      Column()
        .width(72)
        .height(72)
        .borderRadius(36)
        .backgroundColor(AppTheme.colors.surface)
        .opacity(0.82)

      SymbolGlyph(isLockedState ? $r('sys.symbol.lock_fill') : $r('sys.symbol.timer'))
        .fontSize(40)
        .fontColor([isLockedState ? AppTheme.colors.success : '#F3B562'])
        .fontWeight(500)
    }
    .width(120)
    .height(120)
    .alignContent(Alignment.Center)
  }

  @Builder
  private buildLockedState(): void {
    Column({ space: 18 }) {
      this.buildStatusIcon(true)

      if (this.activeLock.endAt > 0) {
        Text(this.remainingLabel)
          .fontSize(56)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)

        Text(this.activeLock.title)
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
      } else {
        Text(this.activeLock.title)
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
      }

      Text(this.getLockSubtitle())
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .textAlign(TextAlign.Center)

      if (this.activeLock.kind === 'covenant' && this.activeLock.planId.length > 0) {
        Button('查看当前契约')
          .width('100%')
          .height(56)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .fontColor(AppTheme.colors.textPrimary)
          .border({ width: 1, color: AppTheme.colors.border })
          .onClick(() => {
            PlanStore.setCurrentPlanId(this.activeLock.planId);
            pushRoute(PageRoutes.PlanDetail);
          })
      }

      AppActionButton({
        label: this.getEndLockButtonLabel(),
        variant: 'danger',
        isEnabled: !this.isEndingLock,
        onPress: () => {
          this.endCurrentLock();
        }
      })

      if (this.getLockHint().length > 0) {
        Text(this.getLockHint())
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .alignItems(HorizontalAlign.Center)
  }

  private ensureLoginThen(route: string): void {
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }
    pushRoute(route);
  }

  @Builder
  private buildEmptyState(): void {
    Column({ space: 18 }) {
      this.buildStatusIcon(false)

      Column({ space: 10 }) {
        Text('选择一种专注方式')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)

        Text('第一次建议先用 15 分钟单人修炼；熟悉后再和搭子连坐。')
          .fontSize(16)
          .fontColor(AppTheme.colors.textSecondary)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      AppActionButton({
        label: '单人修炼',
        onPress: () => {
          this.ensureLoginThen(PageRoutes.QuickStart);
        }
      })

      Row({ space: 12 }) {
        Button('发起连坐')
          .layoutWeight(1)
          .height(52)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.surface)
          .fontColor(AppTheme.colors.textPrimary)
          .fontWeight(FontWeight.Medium)
          .border({ width: 1, color: AppTheme.colors.border })
          .onClick(() => {
            this.ensureLoginThen(PageRoutes.DuoCreate);
          })

        Button('加入连坐')
          .layoutWeight(1)
          .height(52)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.surface)
          .fontColor(AppTheme.colors.textPrimary)
          .fontWeight(FontWeight.Medium)
          .border({ width: 1, color: AppTheme.colors.border })
          .onClick(() => {
            this.ensureLoginThen(PageRoutes.DuoJoin);
          })
      }
      .width('100%')

      Text('双人连坐：一人撕毁，两人都记为失败。')
        .fontSize(13)
        .fontColor(AppTheme.colors.textMuted)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildModeEntry(
    title: string,
    value: string,
    detail: string,
    symbol: Resource,
    onPress: () => void
  ): void {
    Button() {
      Row({ space: 14 }) {
        Row() {
          SymbolGlyph(symbol)
            .fontSize(20)
            .fontColor([AppTheme.colors.primary])
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.primarySoft)
        .borderRadius(20)

        Column({ space: 4 }) {
          Text(title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')

          Text(detail)
            .fontSize(12)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
            .maxLines(2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(value)
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
      }
      .width('100%')
    }
    .width('100%')
    .type(ButtonType.Normal)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .padding(16)
    .onClick(() => {
      onPress();
    })
  }

  @Builder
  private buildModePanel(): void {
    Column({ space: 12 }) {
      Text('定时契约')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      this.buildModeEntry(
        '计划模式',
        this.planCollection.length > 0 ? `${this.planCollection.length} 条` : '去创建',
        '按固定时间自动生效，适合每日学习节奏',
        $r('sys.symbol.doc_plaintext'),
        () => {
          this.onSelectTab?.('plans');
        }
      )
    }
    .width('100%')
  }

  private getFooterStatusMessage(): string {
    return this.statusMessage;
  }

  @Builder
  private buildHomeContent(): void {
    if (this.isActiveLocked()) {
      Column() {
        this.buildLockedState()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      Column({ space: 24 }) {
        this.buildEmptyState()

        this.buildModePanel()

        Text(this.getFooterStatusMessage())
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 4 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    SystemNavPage({
      title: '专注',
      showTitleBar: false,
      usePageScroll: !this.isActiveLocked(),
      content: (): void => {
        this.buildHomeContent();
      }
    })
  }
}

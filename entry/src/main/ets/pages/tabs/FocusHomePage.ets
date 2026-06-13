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
  endQuickFocus,
  skipCovenantWindow
} from '../../services/ActiveLockLifecycleService';
import { CycleGuardStore } from '../../stores/CycleGuardStore';
import { LockStore } from '../../stores/LockStore';
import { PlanStore } from '../../stores/PlanStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Component
export struct FocusHomePage {
  onSelectTab?: (tab: 'contract' | 'guard') => void;
  @StorageLink(StoreKeys.LockActiveState) activeLock: ActiveLockState = createIdleLockState();
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @StorageLink(StoreKeys.SettingsStatusMessage) statusMessage: string = '先申请系统授权，再选择需要限制的应用';
  @StorageLink(StoreKeys.CycleGuardEnabled) cycleEnabled: boolean = false;
  @StorageLink(StoreKeys.CycleGuardSelectedAppCount) cycleSelectedAppCount: number = 0;
  @StorageLink(StoreKeys.CycleGuardStatusMessage) cycleGuardStatusMessage: string = '';
  @State remainingLabel: string = LockStore.getRemainingLabel();

  private timerId: number = -1;
  private isEndingLock: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
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
    CycleGuardStore.hydrate(hostContext);
    this.remainingLabel = LockStore.getRemainingLabel();
  }

  private isActiveLocked(): boolean {
    return isLocked(this.activeLock);
  }

  private async endCurrentLock(): Promise<void> {
    if (this.isEndingLock || !this.isActiveLocked()) {
      return;
    }

    this.isEndingLock = true;
    this.clearTimer();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

    if (this.activeLock.kind === 'quick_focus') {
      await endQuickFocus(hostContext, this.activeLock, '你已手动结束专注', '结束专注失败');
    } else if (this.activeLock.kind === 'covenant') {
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
    return `已限制 ${count} 个应用，结束后会自动解除限制`;
  }

  private getEndLockButtonLabel(): string {
    if (this.activeLock.kind === 'covenant') {
      return '结束本次契约';
    }
    if (this.activeLock.kind === 'cycle_guard') {
      return '结束当前锁定';
    }
    return '结束专注';
  }

  private getLockHint(): string {
    if (this.activeLock.kind === 'cycle_guard') {
      return '结束后会重新开始一轮娱乐限额计时';
    }
    if (this.activeLock.kind === 'covenant') {
      return '仅跳过本次窗口，下一周期仍会正常执行';
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

  @Builder
  private buildEmptyState(): void {
    Column({ space: 18 }) {
      this.buildStatusIcon(false)

      Column({ space: 10 }) {
        Text('当前还没有进行中的专注')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)

        Text('快速专注适合立即进入状态，契约和娱乐限额适合长期管理分心应用。')
          .fontSize(16)
          .fontColor(AppTheme.colors.textSecondary)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      AppActionButton({
        label: '开始快速专注',
        onPress: () => {
          pushRoute(PageRoutes.QuickStart);
        }
      })
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
      Text('其他方式')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      this.buildModeEntry(
        '契约模式',
        this.planCollection.length > 0 ? `${this.planCollection.length} 条` : '去创建',
        '按固定时间自动生效，适合日常学习、工作和休息节奏',
        $r('sys.symbol.doc_plaintext'),
        () => {
          this.onSelectTab?.('contract');
        }
      )

      this.buildModeEntry(
        '娱乐限额',
        this.cycleEnabled ? '运行中' : '去设置',
        this.cycleSelectedAppCount > 0
          ? `已为 ${this.cycleSelectedAppCount} 个娱乐应用设置总时长`
          : '给娱乐类应用设置总可用时长，用完后统一锁定',
        $r('sys.symbol.bolt_shield'),
        () => {
          this.onSelectTab?.('guard');
        }
      )
    }
    .width('100%')
  }

  private getFooterStatusMessage(): string {
    if (this.isActiveLocked() && this.activeLock.kind === 'cycle_guard') {
      return this.cycleGuardStatusMessage;
    }
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

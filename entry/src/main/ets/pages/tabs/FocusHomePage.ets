import { common } from '@kit.AbilityKit';
import { AppActionButton } from '../../components/common/AppActionButton';
import { InputConfirmSheet } from '../../components/common/InputConfirmSheet';
import { AppTheme } from '../../constants/Theme';
import { TEAR_CONFIRM_REQUIRED_TEXT } from '../../constants/TearConfirm';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import {
  ActiveLockState,
  createIdleLockState,
  isDuoCovenantLock,
  isLocked,
  normalizeActiveLockState
} from '../../models/ActiveLockModel';
import { FocusPlan } from '../../models/PlanModel';
import { isDuoWaitPartnerJoined } from '../../models/DuoModel';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import {
  endCycleGuardLock,
  tearCovenantWindow,
  tearQuickFocus
} from '../../services/ActiveLockLifecycleService';
import { DuoApiService } from '../../services/DuoApiService';
import { queueShameCertificate, tryPresentCertificateGuide } from '../../services/CertificatePendingService';
import { clearDuoWaitContext, openDuoWaitPage } from '../../services/DuoWaitContextService';
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
  @StorageLink(StoreKeys.DuoWaitSessionId) duoWaitSessionId: string = '';
  @StorageLink(StoreKeys.DuoWaitTitle) duoWaitTitle: string = '';
  @StorageLink(StoreKeys.DuoWaitIsScheduled) duoWaitIsScheduled: boolean = false;
  @StorageLink(StoreKeys.DuoWaitScheduleLabel) duoWaitScheduleLabel: string = '';
  @State remainingLabel: string = LockStore.getRemainingLabel();
  @State showTearConfirm: boolean = false;

  private timerId: number = -1;
  private isEndingLock: boolean = false;
  private duoWaitPollTick: number = 0;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    this.syncRemainingLabel();
    void this.reconcileDuoWait();
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
      this.duoWaitPollTick += 1;
      if (this.duoWaitSessionId.length > 0 && this.duoWaitPollTick % 5 === 0) {
        void this.reconcileDuoWait();
      }
    }, 1000);
  }

  private hasPendingDuoWait(): boolean {
    return this.duoWaitSessionId.length > 0;
  }

  private getDuoWaitEntryDetail(): string {
    if (this.duoWaitIsScheduled) {
      if (this.duoWaitScheduleLabel.length > 0) {
        return `定时契约 · ${this.duoWaitScheduleLabel}`;
      }
      return '定时契约 · 等待搭子加入后可复制口令';
    }
    const title = this.duoWaitTitle.length > 0 ? this.duoWaitTitle : '搭子互督';
    return `${title} · 点击进入复制口令`;
  }

  private async reconcileDuoWait(): Promise<void> {
    if (this.duoWaitSessionId.length === 0) {
      return;
    }

    const response = await DuoApiService.getSession(this.duoWaitSessionId);
    const session = DuoApiService.parseSession(response);
    if (!session) {
      if (response.statusCode === 400 || response.statusCode === 404) {
        clearDuoWaitContext();
      }
      return;
    }

    if (session.status === 'expired' || session.status === 'cancelled') {
      clearDuoWaitContext();
      return;
    }

    if (isDuoWaitPartnerJoined(session, this.duoWaitIsScheduled)) {
      clearDuoWaitContext();
      return;
    }

    if (!this.duoWaitIsScheduled && session.status === 'active' && session.type !== 'scheduled') {
      openDuoWaitPage();
    }
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

  private getTearConfirmMessage(): string {
    if (this.activeLock.participationMode === 'duo') {
      return '撕毁后本次专注立即失败，搭子也会被连带。撕毁契约后无法撤销，你与搭子都将记为失败。';
    }
    return '撕毁后本次专注记为违约，会生成耻辱证。撕毁契约后无法撤销，本次将记入耻辱柱。';
  }

  private async endCurrentLock(): Promise<void> {
    if (this.isEndingLock || !this.isActiveLocked()) {
      return;
    }

    if (this.activeLock.kind === 'quick_focus' || this.activeLock.kind === 'covenant') {
      this.showTearConfirm = true;
      return;
    }

    await this.performEndLock();
  }

  private async performTearLock(): Promise<void> {
    if (this.isEndingLock) {
      return;
    }
    const lockSnapshot = normalizeActiveLockState(this.activeLock);
    const endedAt = Date.now();
    if (this.activeLock.kind === 'quick_focus') {
      this.isEndingLock = true;
      this.clearTimer();
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const ok = await tearQuickFocus(hostContext, lockSnapshot);
      if (ok) {
        queueShameCertificate(lockSnapshot, endedAt, 'violator', 'tear');
        tryPresentCertificateGuide(this.getUIContext());
      }
      this.remainingLabel = LockStore.getRemainingLabel();
      this.isEndingLock = false;
      this.startTimer();
      return;
    }
    if (this.activeLock.kind === 'covenant') {
      this.isEndingLock = true;
      this.clearTimer();
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const ok = await tearCovenantWindow(hostContext, lockSnapshot);
      if (ok) {
        queueShameCertificate(lockSnapshot, endedAt, 'violator', 'tear');
        tryPresentCertificateGuide(this.getUIContext());
      }
      this.remainingLabel = LockStore.getRemainingLabel();
      this.isEndingLock = false;
      this.startTimer();
    }
  }

  private async performEndLock(): Promise<void> {
    if (this.isEndingLock || !this.isActiveLocked()) {
      return;
    }

    this.isEndingLock = true;
    this.clearTimer();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

    if (this.activeLock.kind === 'cycle_guard') {
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
    if (this.activeLock.kind === 'quick_focus' || this.activeLock.kind === 'covenant') {
      return '撕毁契约';
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
      if (isDuoCovenantLock(this.activeLock)) {
        return '提前结束视为撕毁契约，你与搭子都将记为失败';
      }
      return '提前结束视为撕毁契约，自然跑满才算上岸';
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
        .fontColor([AppTheme.colors.accentGreen])
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
  private buildDuoActionButton(
    label: string,
    symbol: Resource,
    iconColor: string,
    onPress: () => void
  ): void {
    Button() {
      Column({ space: 8 }) {
        Row() {
          SymbolGlyph(symbol)
            .fontSize(20)
            .fontColor([iconColor])
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .borderRadius(18)

        Text(label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .layoutWeight(1)
    .height(88)
    .type(ButtonType.Normal)
    .padding({ left: 8, right: 8, top: 12, bottom: 12 })
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(18)
    .onClick(() => {
      onPress();
    })
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

        Text('先尝试单人专注，熟悉后再和搭子互督。')
          .fontSize(16)
          .fontColor(AppTheme.colors.textSecondary)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      AppActionButton({
        label: '单人专注',
        onPress: () => {
          pushRoute(PageRoutes.QuickStart);
        }
      })

      Column({ space: 10 }) {
        Text('搭子互督：一人毁约，两人都记为失败。')
          .fontSize(14)
          .fontColor(AppTheme.colors.textMuted)
          .textAlign(TextAlign.Center)
          .width('100%')

        Row({ space: 12 }) {
          this.buildDuoActionButton(
            '发起互督',
            $r('sys.symbol.person_badge_plus'),
            AppTheme.colors.accentBlue,
            () => {
              this.ensureLoginThen(PageRoutes.DuoCreate);
            }
          )

          this.buildDuoActionButton(
            '加入互督',
            $r('sys.symbol.link'),
            AppTheme.colors.accentOrange,
            () => {
              this.ensureLoginThen(PageRoutes.DuoJoin);
            }
          )
        }
        .width('100%')
      }

    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildDuoWaitEntry(): void {
    Button() {
      Row({ space: 14 }) {
        Row() {
          SymbolGlyph($r('sys.symbol.person_fill'))
            .fontSize(20)
            .fontColor([AppTheme.colors.primary])
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.primarySoft)
        .borderRadius(20)

        Column({ space: 4 }) {
          Text('等待搭子加入')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')

          Text(this.getDuoWaitEntryDetail())
            .fontSize(12)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([AppTheme.colors.textMuted])
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    }
    .type(ButtonType.Normal)
    .width('100%')
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.primarySoft })
    .borderRadius(16)
    .onClick(() => {
      openDuoWaitPage();
    })
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
            .fontSize(15)
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
          .visibility(value.length > 0 ? Visibility.Visible : Visibility.None)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([AppTheme.colors.textMuted])
          .visibility(value.length > 0 ? Visibility.None : Visibility.Visible)
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
      Column({ space: 4 }) {
        Text('长期专注，定时契约效率更高')
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      this.buildModeEntry(
        '创建定时契约',
        '',
        '设定开始时间，到点自动进入专注',
        $r('sys.symbol.calendar'),
        () => {
          this.onSelectTab?.('plans');
        }
      )
    }
    .width('100%')
    .margin({ top: 18 })
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

        if (this.hasPendingDuoWait()) {
          this.buildDuoWaitEntry()
        }

        this.buildModePanel()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      SystemNavPage({
        title: '专注',
        showTitleBar: false,
        usePageScroll: !this.isActiveLocked(),
        content: (): void => {
          this.buildHomeContent();
        }
      })

      InputConfirmSheet({
        visible: this.showTearConfirm,
        title: '撕毁契约',
        message: this.getTearConfirmMessage(),
        requiredText: TEAR_CONFIRM_REQUIRED_TEXT,
        confirmText: '确认撕毁',
        cancelText: '继续专注',
        inputHint: '确定要撕毁？请输入以下文字：',
        onConfirm: () => {
          void this.performTearLock();
        },
        onCancel: () => {
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

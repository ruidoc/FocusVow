import { common } from "@kit.AbilityKit";
import { window } from "@kit.ArkUI";
import { InputConfirmSheet } from "../../components/common/InputConfirmSheet";
import { DuoFocusHeader } from "../../components/focus/DuoFocusHeader";
import { FocusTimeRing } from "../../components/focus/FocusTimeRing";
import { AppTheme } from "../../constants/Theme";
import { TEAR_CONFIRM_REQUIRED_TEXT } from "../../constants/TearConfirm";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { UsersIcon } from "../../components/common/UsersIcon";
import {
  ActiveLockState,
  createIdleLockState,
  getRemainingSeconds,
  isLocked,
  minutesToHours,
  normalizeActiveLockState,
  resolveDuoSessionIdFromLock,
} from "../../models/ActiveLockModel";
import { FocusPlan } from "../../models/PlanModel";
import { isDuoWaitPartnerJoined, resolveDuoCounterpartName } from "../../models/DuoModel";
import { PageRoutes, pushRoute } from "../../router/PageRoutes";
import {
  endCycleGuardLock,
  tearCovenantWindow,
  tearQuickFocus,
} from "../../services/ActiveLockLifecycleService";
import { DuoApiService } from "../../services/DuoApiService";
import {
  queueShameCertificate,
  tryPresentCertificateGuide,
} from "../../services/CertificatePendingService";
import { clearDuoWaitContext, openDuoWaitPage } from "../../services/DuoWaitContextService";
import {
  DuoInstantLockOptions,
  startOrAlignInstantDuoFocus,
} from "../../services/DuoInstantLockService";
import {
  afterGuestSoloFocusEnded,
  ensureSoloFocusAccess,
} from "../../services/GuestSoloFocusService";
import { LockStore } from "../../stores/LockStore";
import { PlanStore } from "../../stores/PlanStore";
import { SettingsStore } from "../../stores/SettingsStore";
import { UserStore } from "../../stores/UserStore";
import { bootstrapStores } from "../../stores/StoreBootstrap";
import { StoreKeys } from "../../stores/StoreKeys";

bootstrapStores();
@Component
export struct FocusHomePage {
  onSelectTab?: (tab: "plans") => void;
  @StorageLink(StoreKeys.LockActiveState) activeLock: ActiveLockState = createIdleLockState();
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @StorageLink(StoreKeys.DuoWaitSessionId) duoWaitSessionId: string = "";
  @StorageLink(StoreKeys.DuoWaitTitle) duoWaitTitle: string = "";
  @StorageLink(StoreKeys.DuoWaitIsScheduled) duoWaitIsScheduled: boolean = false;
  @StorageLink(StoreKeys.DuoWaitScheduleLabel) duoWaitScheduleLabel: string = "";
  @State remainingLabel: string = LockStore.getRemainingLabel();
  @State showTearConfirm: boolean = false;
  @State topSafeInsetVp: number = 0;
  /** 单人入口按压缩放透明度，对齐 iOS activeOpacity=0.7 */
  @State soloLinkPressed: boolean = false;

  private timerId: number = -1;
  private isEndingLock: boolean = false;
  private duoWaitPollTick: number = 0;
  private duoPartnerSyncSessionId: string = "";

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    this.syncRemainingLabel();
    void this.reconcileDuoWait();
    void this.syncDuoPartnerDisplay();
    this.startTimer();
    this.loadTopSafeInset(hostContext);
  }

  private loadTopSafeInset(hostContext: common.UIAbilityContext): void {
    const ui = this.getUIContext();
    window.getLastWindow(hostContext, (err, win) => {
      if (err.code) {
        return;
      }
      const systemAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topSafeInsetVp = ui.px2vp(systemAvoid.topRect.height);
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
      this.syncRemainingLabel();
      this.duoWaitPollTick += 1;
      if (this.duoWaitSessionId.length > 0 && this.duoWaitPollTick % 5 === 0) {
        void this.reconcileDuoWait();
      }
      if (this.isDuoFocus() && this.duoWaitPollTick % 5 === 0) {
        void this.syncDuoPartnerDisplay();
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
      return "定时契约 · 等待搭子加入后可发给搭子";
    }
    const title = this.duoWaitTitle.length > 0 ? this.duoWaitTitle : "搭子互督";
    return `${title} · 点击进入发给搭子`;
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

    if (
      session.status === "expired" ||
      session.status === "cancelled" ||
      session.status === "breached"
    ) {
      clearDuoWaitContext();
      return;
    }

    // 即时契约已激活：首页直接按服务端 end_at 补锁，不再只清等待态
    if (!this.duoWaitIsScheduled && session.status === "active" && session.type !== "scheduled") {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      SettingsStore.hydrate(hostContext);
      const tokens = SettingsStore.getState().selectedTokens;
      const title = this.duoWaitTitle.length > 0 ? this.duoWaitTitle : session.title;
      const lockOptions: DuoInstantLockOptions = {
        title,
        navigateHome: false,
        clearWait: true,
        alignToServerEnd: true,
      };
      await startOrAlignInstantDuoFocus(hostContext, session, tokens, lockOptions);
      return;
    }

    if (isDuoWaitPartnerJoined(session, this.duoWaitIsScheduled)) {
      clearDuoWaitContext();
    }
  }

  private async syncDuoPartnerDisplay(): Promise<void> {
    if (!this.isDuoFocus()) {
      this.duoPartnerSyncSessionId = "";
      return;
    }

    const sessionId = resolveDuoSessionIdFromLock(this.activeLock);
    if (sessionId.length === 0) {
      return;
    }

    if (
      this.duoPartnerSyncSessionId === sessionId &&
      this.activeLock.partnerNickname.trim().length > 0
    ) {
      return;
    }

    const response = await DuoApiService.getSession(sessionId);
    const session = DuoApiService.parseSession(response);
    if (!session) {
      return;
    }

    const partnerNickname = resolveDuoCounterpartName(session);
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const currentState = LockStore.getState();
    const nextTitle =
      currentState.title.length > 0
        ? currentState.title
        : session.title.length > 0
          ? session.title
          : "搭子互督";

    LockStore.setState(
      hostContext,
      normalizeActiveLockState({
        kind: currentState.kind,
        strategyName: currentState.strategyName,
        title: nextTitle,
        planId: currentState.planId,
        selectedTokens: currentState.selectedTokens,
        selectedCount: currentState.selectedCount,
        mode: currentState.mode,
        startedAt: currentState.startedAt,
        endAt: currentState.endAt,
        updatedAt: currentState.updatedAt,
        duoSessionId: currentState.duoSessionId,
        recordId: currentState.recordId,
        participationMode: currentState.participationMode,
        partnerNickname,
      }),
    );
    this.duoPartnerSyncSessionId = sessionId;
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
    if (this.activeLock.participationMode === "duo") {
      return "撕毁后本次专注立即失败，搭子也会因连坐记为失败。撕毁契约后无法撤销，你与搭子都将记为失败。";
    }
    return "撕毁后本次专注记为违约，会生成耻辱证。撕毁契约后无法撤销，本次将记入耻辱柱。";
  }

  private async endCurrentLock(): Promise<void> {
    if (this.isEndingLock || !this.isActiveLocked()) {
      return;
    }

    if (this.activeLock.kind === "quick_focus" || this.activeLock.kind === "covenant") {
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
    if (this.activeLock.kind === "quick_focus") {
      this.isEndingLock = true;
      this.clearTimer();
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const endResult = await tearQuickFocus(hostContext, lockSnapshot);
      if (endResult.ok && !endResult.tooShort && UserStore.isLoggedIn()) {
        // 已登录：弹耻辱证；游客单人只走登录引导
        queueShameCertificate(lockSnapshot, endedAt, "violator", "tear");
        tryPresentCertificateGuide(this.getUIContext());
      } else if (endResult.ok && endResult.tooShort) {
        // 短场无效：提示已写在 statusMessage
      } else {
        afterGuestSoloFocusEnded(this.getUIContext(), lockSnapshot, hostContext, false);
      }
      this.remainingLabel = LockStore.getRemainingLabel();
      this.isEndingLock = false;
      this.startTimer();
      return;
    }
    if (this.activeLock.kind === "covenant") {
      this.isEndingLock = true;
      this.clearTimer();
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const endResult = await tearCovenantWindow(hostContext, lockSnapshot);
      if (endResult.ok && !endResult.tooShort) {
        queueShameCertificate(lockSnapshot, endedAt, "violator", "tear");
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

    if (this.activeLock.kind === "cycle_guard") {
      await endCycleGuardLock(hostContext);
    }

    this.remainingLabel = LockStore.getRemainingLabel();
    this.isEndingLock = false;
    this.startTimer();
  }

  private isDuoFocus(): boolean {
    return this.activeLock.participationMode === "duo";
  }

  private getSelfDisplayName(): string {
    const username = UserStore.getUserInfo().username.trim();
    return username.length > 0 ? username : "我";
  }

  private getPartnerDisplayName(): string {
    const nickname = this.activeLock.partnerNickname.trim();
    return nickname.length > 0 ? nickname : "搭子";
  }

  private getFocusKindLabel(): string {
    if (this.isDuoFocus()) {
      return "搭子互督";
    }
    if (this.activeLock.kind === "covenant") {
      return "单人定时契约";
    }
    if (this.activeLock.kind === "quick_focus") {
      return "单人即时契约";
    }
    return "专注中";
  }

  private getLockStatusText(): string {
    const count = this.activeLock.selectedCount;
    const modeLabel = this.activeLock.mode === "allow" ? "白名单模式" : "黑名单模式";
    if (this.activeLock.mode === "allow") {
      return `已放行 ${count} 个应用 · ${modeLabel}`;
    }
    return `已限制 ${count} 个应用 · ${modeLabel}`;
  }

  private getTotalDurationMinutes(): number {
    if (this.activeLock.endAt <= 0 || this.activeLock.startedAt <= 0) {
      return 0;
    }
    return Math.max(Math.floor((this.activeLock.endAt - this.activeLock.startedAt) / 60000), 0);
  }

  private getFocusSubtitle(): string {
    const kindLabel = this.getFocusKindLabel();
    const totalMinutes = this.getTotalDurationMinutes();
    if (totalMinutes > 0) {
      return `${kindLabel} · 共 ${minutesToHours(totalMinutes)}`;
    }
    return kindLabel;
  }

  private getProgressValue(): number {
    if (this.activeLock.endAt <= 0 || this.activeLock.startedAt <= 0) {
      return 0;
    }
    const totalMs = this.activeLock.endAt - this.activeLock.startedAt;
    if (totalMs <= 0) {
      return 0;
    }
    const remainingMs = Math.max(this.activeLock.endAt - Date.now(), 0);
    const elapsedMs = totalMs - remainingMs;
    return Math.min(Math.max((elapsedMs / totalMs) * 100, 0), 100);
  }

  private getElapsedMinutes(): number {
    if (this.activeLock.endAt <= 0 || this.activeLock.startedAt <= 0) {
      return 0;
    }
    const totalSeconds = Math.floor((this.activeLock.endAt - this.activeLock.startedAt) / 1000);
    const remainingSeconds = getRemainingSeconds(this.activeLock, Date.now());
    return Math.max(Math.floor((totalSeconds - remainingSeconds) / 60), 0);
  }

  private shouldUseCompactTime(): boolean {
    return this.remainingLabel.length > 5;
  }

  private canShowTearButton(): boolean {
    return (
      this.activeLock.kind === "quick_focus" ||
      this.activeLock.kind === "covenant" ||
      this.activeLock.kind === "cycle_guard"
    );
  }

  private getEndLockButtonLabel(): string {
    if (this.activeLock.kind === "quick_focus" || this.activeLock.kind === "covenant") {
      return "撕毁契约";
    }
    if (this.activeLock.kind === "cycle_guard") {
      return "结束当前锁定";
    }
    return "结束";
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
          .blur(40);
      }
      Column()
        .width(72)
        .height(72)
        .borderRadius(36)
        .backgroundColor(AppTheme.colors.primarySoft)
        .opacity(1)
      if (isLockedState) {
        SymbolGlyph($r("sys.symbol.lock_fill"))
          .fontSize(40)
          .fontColor([AppTheme.colors.primary])
          .fontWeight(500)
      } else {
        UsersIcon({ iconSize: 40, color: AppTheme.colors.primary })
      }
    }
    .width(120)
    .height(120)
    .alignContent(Alignment.Center);
  }

  @Builder
  private buildWeakTearButton(): void {
    Row() {
      Text(this.getEndLockButtonLabel())
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textMuted)
    }
    .height(40)
    .padding({ left: 20, right: 20 })
    .margin({ top: 10 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(20)
    .opacity(this.isEndingLock ? 0.5 : 1)
    .enabled(!this.isEndingLock)
    .onClick(() => {
      void this.endCurrentLock();
    });
  }

  @Builder
  private buildLockStatusChip(): void {
    Row({ space: 6 }) {
      SymbolGlyph(
        this.activeLock.mode === "allow"
          ? $r("sys.symbol.checkmark_circle")
          : $r("sys.symbol.lock_fill"),
      )
        .fontSize(14)
        .fontColor([AppTheme.colors.primary])
      Text(this.getLockStatusText())
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.primary)
    }
    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
    .backgroundColor(AppTheme.colors.primarySoft)
    .borderRadius(AppTheme.radius.pill)
    .margin({ bottom: 10 });
  }

  @Builder
  private buildLockedState(): void {
    Column({ space: 24 }) {
      FocusTimeRing({
        remainingLabel: this.remainingLabel,
        elapsedMinutes: this.getElapsedMinutes(),
        progressValue: this.getProgressValue(),
        isDuo: this.isDuoFocus(),
        useCompactTime: this.shouldUseCompactTime(),
      })

      this.buildLockStatusChip()
      Column({ space: 4 }) {
        Text(this.activeLock.title)
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.getFocusSubtitle())
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .textAlign(TextAlign.Center)
          .lineHeight(22)
      }
      .width("100%")
      .alignItems(HorizontalAlign.Center)

      if (this.canShowTearButton()) {
        this.buildWeakTearButton();
      }
    }
    .width("100%")
    .padding({
      left: 24,
      right: 24,
      top: this.isDuoFocus() ? 48 : 0,
    })
    .alignItems(HorizontalAlign.Center);
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
    onPress: () => void,
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
      .width("100%")
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
    });
  }

  @Builder
  private buildSoloFocusLink(): void {
    Row({ space: 4 }) {
      SymbolGlyph($r("sys.symbol.bolt"))
        .fontSize(15)
        .fontColor([AppTheme.colors.primary])
      Text("先自己练练？单人专注")
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.primary)
    }
    .justifyContent(FlexAlign.Center)
    .height(40)
    .padding({ left: 12, right: 12 })
    .opacity(this.soloLinkPressed ? 0.7 : 1)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.soloLinkPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.soloLinkPressed = false;
      }
    })
    .onClick(() => {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (!ensureSoloFocusAccess(hostContext)) {
        return;
      }
      pushRoute(PageRoutes.QuickStart);
    });
  }

  @Builder
  private buildEmptyState(): void {
    Column({ space: 18 }) {
      this.buildStatusIcon(false)
      Column({ space: 10 }) {
        Text("和搭子一起专注")
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
        Text("双人互督，连坐机制，一人毁约两人失败")
          .fontSize(16)
          .fontColor(AppTheme.colors.textSecondary)
          .textAlign(TextAlign.Center)
      }
      .width("100%")
      .alignItems(HorizontalAlign.Center)

      Row({ space: 12 }) {
        this.buildDuoActionButton(
          "发起互督",
          $r("sys.symbol.person_badge_plus"),
          AppTheme.colors.accentBlue,
          () => {
            this.ensureLoginThen(PageRoutes.DuoCreate);
          },
        )

        this.buildDuoActionButton(
          "加入互督",
          $r("sys.symbol.link"),
          AppTheme.colors.accentOrange,
          () => {
            this.ensureLoginThen(PageRoutes.DuoJoin);
          },
        )
      }.width("100%")

      this.buildSoloFocusLink()
    }
    .width("100%")
    .padding({ left: 12, right: 12 })
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private buildDuoWaitBanner(): void {
    Column() {
      Row({ space: 12 }) {
        Row() {
          UsersIcon({ iconSize: 18, color: AppTheme.colors.primary })
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.primarySoft)
        .borderRadius(18)

        Column({ space: 2 }) {
          Text("等待搭子加入")
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .width("100%")
          Text(this.getDuoWaitEntryDetail())
            .fontSize(12)
            .fontColor(AppTheme.colors.textSecondary)
            .width("100%")
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r("sys.symbol.chevron_right"))
          .fontSize(14)
          .fontColor([AppTheme.colors.textMuted])
      }
      .width("100%")
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.primarySoft })
      .borderRadius(28)
      // 对齐 iOS：轻阴影（低透明度 + 大模糊），避免 Button 默认材质阴影发硬
      .shadow({
        radius: 16,
        color: '#14000000',
        offsetX: 0,
        offsetY: 4,
      })
      .onClick(() => {
        openDuoWaitPage();
      })
    }
    .width("100%")
    .padding({
      left: 20,
      right: 20,
      top: this.topSafeInsetVp + 6,
    })
  }

  @Builder
  private buildModeEntry(
    title: string,
    value: string,
    detail: string,
    symbol: Resource,
    onPress: () => void,
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
            .width("100%")
          Text(detail)
            .fontSize(12)
            .fontColor(AppTheme.colors.textSecondary)
            .width("100%")
            .maxLines(2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(value)
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
          .visibility(value.length > 0 ? Visibility.Visible : Visibility.None)
        SymbolGlyph($r("sys.symbol.chevron_right"))
          .fontSize(14)
          .fontColor([AppTheme.colors.textMuted])
          .visibility(value.length > 0 ? Visibility.None : Visibility.Visible)
      }.width("100%")
    }
    .width("100%")
    .type(ButtonType.Normal)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .padding(16)
    .onClick(() => {
      onPress();
    });
  }

  @Builder
  private buildModePanel(): void {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text("长期专注，定时契约效率更高")
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%")
          .textAlign(TextAlign.Center)
      }
      .width("100%")
      .alignItems(HorizontalAlign.Center)

      this.buildModeEntry(
        "创建定时契约",
        "",
        "设定开始时间，到点自动进入专注",
        $r("sys.symbol.calendar"),
        () => {
          this.onSelectTab?.("plans");
        },
      )
    }
    .width("100%")
    .margin({ top: 18 });
  }

  @Builder
  private buildHomeContent(): void {
    if (this.isActiveLocked()) {
      Column() {
        this.buildLockedState()
      }
      .width("100%")
      .height("100%")
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center);
    } else {
      Column({ space: 24 }) {
        this.buildEmptyState()
        this.buildModePanel()
      }
      .width("100%")
      .padding({ top: this.hasPendingDuoWait() ? 64 : 0 })
      .alignItems(HorizontalAlign.Start);
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      SystemNavPage({
        title: "专注",
        showTitleBar: false,
        usePageScroll: !this.isActiveLocked(),
        content: (): void => {
          this.buildHomeContent();
        },
      })

      if (!this.isActiveLocked() && this.hasPendingDuoWait()) {
        this.buildDuoWaitBanner();
      }

      if (this.isActiveLocked() && this.isDuoFocus()) {
        DuoFocusHeader({
          selfName: this.getSelfDisplayName(),
          partnerName: this.getPartnerDisplayName(),
        }).padding({
          left: 24,
          right: 24,
          top: this.topSafeInsetVp + 16,
        });
      }
      InputConfirmSheet({
        visible: this.showTearConfirm,
        title: "撕毁契约",
        message: this.getTearConfirmMessage(),
        requiredText: TEAR_CONFIRM_REQUIRED_TEXT,
        confirmText: "确认撕毁",
        cancelText: "继续专注",
        inputHint: "确定要撕毁？请输入以下文字：",
        onConfirm: () => {
          void this.performTearLock();
        },
        onCancel: () => {},
      })
    }
    .width("100%")
    .height("100%");
  }
}

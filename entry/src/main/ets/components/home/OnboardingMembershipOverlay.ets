import { common } from '@kit.AbilityKit';
import { AppTheme } from '../../constants/Theme';
import { FLOATING_TAB_EXTRA_BOTTOM_VP, CAPSULE_ABOVE_TAB_GAP_VP } from '../../pages/tabs/MainTabUtil';
import {
  FIRST_FOCUS_MINUTES,
  FIRST_FOCUS_TITLE,
} from '../../services/FirstFocusPromptService';
import { pushQuickStart, pushRoute, PageRoutes } from '../../router/PageRoutes';
import { AnalyticsService } from '../../services/AnalyticsService';
import { buildOnboardingAnalyticsProps } from '../../utils/OnboardingMetaUtil';
import { BenefitStore } from '../../stores/BenefitStore';
import { FeatureFlagStore } from '../../stores/FeatureFlagStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import {
  expireMembershipUrgencyIfNeeded,
  formatMembershipUrgencyCountdown,
  getMembershipUrgencySecondsLeft,
  MEMBERSHIP_URGENCY_WINDOW_MINUTES,
  shouldShowMembershipUrgencyCapsule,
  startMembershipUrgencyCountdown,
} from '../../utils/OnboardingMembershipUtil';

@Component
export struct OnboardingMembershipOverlay {
  @Link showActivationModal: boolean;
  @Link activationGuestPath: boolean;
  @StorageLink(StoreKeys.ShowGuestMembershipReclaim) @Watch('onGuestReclaimShown') showGuestReclaim: boolean = false;
  @StorageLink(StoreKeys.ShowSignupTrialCelebration) @Watch('onCelebrationShown') showCelebration: boolean = false;
  @StorageLink(StoreKeys.MainTabFloatingBar) floatingTabBar: boolean = false;
  @Prop hasActiveLock: boolean = false;
  @Prop hasPendingQuickStart: boolean = false;
  onActivationModalClosed: () => void = () => {};
  @State private capsuleTick: number = 0;

  private timerId: number = -1;

  aboutToAppear(): void {
    this.startCapsuleTimer();
  }

  aboutToDisappear(): void {
    this.clearCapsuleTimer();
  }

  private startCapsuleTimer(): void {
    this.clearCapsuleTimer();
    this.capsuleTick += 1;
    this.timerId = setInterval(() => {
      this.capsuleTick += 1;
    }, 1000);
  }

  private clearCapsuleTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private getHostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private shouldShowCapsule(): boolean {
    const _tick = this.capsuleTick;
    const hostContext = this.getHostContext();
    expireMembershipUrgencyIfNeeded(hostContext);
    return shouldShowMembershipUrgencyCapsule(
      hostContext,
      this.hasActiveLock,
      this.hasPendingQuickStart,
    );
  }

  private getUrgencyLabel(): string {
    const _tick = this.capsuleTick;
    return formatMembershipUrgencyCountdown(getMembershipUrgencySecondsLeft(this.getHostContext()));
  }

  private getCapsuleBottomVp(): number {
    return this.floatingTabBar
      ? FLOATING_TAB_EXTRA_BOTTOM_VP + CAPSULE_ABOVE_TAB_GAP_VP
      : FLOATING_TAB_EXTRA_BOTTOM_VP;
  }

  private onGuestReclaimShown(): void {
    if (!this.showGuestReclaim) {
      return;
    }
    AnalyticsService.trackEvent('guest_membership_reclaim_modal_shown', buildOnboardingAnalyticsProps({
      'onboarding_path': 'focus_first',
    }));
  }

  private onCelebrationShown(): void {
    if (!this.showCelebration) {
      return;
    }
    AnalyticsService.trackEvent('signup_trial_celebration_shown', buildOnboardingAnalyticsProps({}));
    AnalyticsService.trackEvent('onboarding_benefit_claimed', buildOnboardingAnalyticsProps({}));
  }

  private onActivationStart(): void {
    AnalyticsService.trackEvent('onboarding_activation_modal_clicked', buildOnboardingAnalyticsProps({
      'action': 'start',
      'is_logged_in': UserStore.isLoggedIn(),
      'guest_path': this.activationGuestPath,
    }));
    this.showActivationModal = false;
    AppStorage.setOrCreate(StoreKeys.OnboardingActivationModalVisible, false);
    this.onActivationModalClosed();
    pushQuickStart(FIRST_FOCUS_TITLE, FIRST_FOCUS_MINUTES, true);
  }

  private onActivationDismiss(): void {
    AnalyticsService.trackEvent('onboarding_activation_modal_clicked', buildOnboardingAnalyticsProps({
      'action': 'dismiss',
      'is_logged_in': UserStore.isLoggedIn(),
      'guest_path': this.activationGuestPath,
    }));
    startMembershipUrgencyCountdown(this.getHostContext());
    this.showActivationModal = false;
    AppStorage.setOrCreate(StoreKeys.OnboardingActivationModalVisible, false);
    this.onActivationModalClosed();
  }

  private onGuestReclaimConfirm(): void {
    AnalyticsService.trackEvent('guest_membership_reclaim_modal_clicked', buildOnboardingAnalyticsProps({
      'action': 'confirm',
    }));
    this.showGuestReclaim = false;
    AppStorage.setOrCreate(StoreKeys.LoginFrom, 'guest_membership_reclaim');
    pushRoute(PageRoutes.Login);
  }

  private onGuestReclaimDismiss(): void {
    AnalyticsService.trackEvent('guest_membership_reclaim_modal_clicked', buildOnboardingAnalyticsProps({
      'action': 'dismiss',
    }));
    AnalyticsService.trackEvent('guest_focus_login_deferred', buildOnboardingAnalyticsProps({
      'prompt_type': 'reclaim_modal',
      'has_pending': true,
    }));
    this.showGuestReclaim = false;
  }

  private onCelebrationDismiss(): void {
    AnalyticsService.trackEvent('signup_trial_celebration_clicked', buildOnboardingAnalyticsProps({
      'action': 'dismiss',
    }));
    this.showCelebration = false;
  }

  private onCelebrationViewBenefits(): void {
    AnalyticsService.trackEvent('signup_trial_celebration_clicked', buildOnboardingAnalyticsProps({
      'action': 'view_benefits',
    }));
    this.showCelebration = false;
    const benefit = BenefitStore.getState();
    const isActive = benefit.isSubscribed || benefit.membershipStatus === 'active';
    FeatureFlagStore.openVipEntry('onboarding_signup_benefit', isActive);
  }

  @Builder
  private buildCheckIcon(large: boolean): void {
    if (large) {
      SymbolGlyph($r('sys.symbol.checkmark_circle'))
        .fontSize(56)
        .fontColor([AppTheme.colors.accentGreen])
        .margin({ bottom: 20 })
    } else {
      Row() {
        SymbolGlyph($r('sys.symbol.checkmark_circle'))
          .fontSize(26)
          .fontColor([AppTheme.colors.accentGreen])
      }
      .width(48)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .borderRadius(24)
      .backgroundColor('#ECFDF5')
      .margin({ bottom: 20 })
    }
  }

  @Builder
  private buildCenterModal(
    iconKind: string,
    title: string,
    message: string,
    primaryLabel: string,
    primaryAction: () => void,
    secondaryLabel: string,
    secondaryAction: () => void,
  ): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')

      Column({ space: 0 }) {
        if (iconKind === 'check-large') {
          this.buildCheckIcon(true)
        } else if (iconKind === 'check-badge') {
          this.buildCheckIcon(false)
        } else if (iconKind === 'party') {
          Text('🎉')
            .fontSize(52)
            .margin({ bottom: 16 })
        }

        Text(title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ bottom: 10 })

        Text(message)
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .lineHeight(22)
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ bottom: 28 })

        Button(primaryLabel)
          .width('100%')
          .height(48)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(AppTheme.colors.primary)
          .borderRadius(30)
          .onClick(() => primaryAction())

        Button(secondaryLabel)
          .width('100%')
          .height(44)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .fontSize(15)
          .fontColor(AppTheme.colors.textMuted)
          .backgroundColor(Color.Transparent)
          .margin({ top: 4 })
          .onClick(() => secondaryAction())
      }
      .width('88%')
      .constraintSize({ maxWidth: 340 })
      .padding({
        top: 32,
        left: 24,
        right: 24,
        bottom: 22,
      })
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(28)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Default)
  }

  @Builder
  private buildUrgencyCapsule(): void {
    Row({ space: 6 }) {
      SymbolGlyph($r('sys.symbol.gift'))
        .fontSize(15)
        .fontColor(['#D4A44A'])
      Text(this.getUrgencyLabel())
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#A16207')
      Text('后权益失效')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textSecondary)
    }
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor('#FFFBF0')
    .border({ width: 1, color: 'rgba(212,164,74,0.55)' })
    .borderRadius(999)
    .margin({ bottom: this.getCapsuleBottomVp() })
    .hitTestBehavior(HitTestMode.Default)
    .onClick(() => {
      AnalyticsService.trackEvent('membership_urgency_capsule_clicked', {
        'seconds_left': getMembershipUrgencySecondsLeft(this.getHostContext()),
      });
      pushQuickStart(FIRST_FOCUS_TITLE, FIRST_FOCUS_MINUTES, true);
    })
  }

  build() {
    Stack() {
      if (this.shouldShowCapsule()) {
        Stack({ alignContent: Alignment.Bottom }) {
          Row() {
            this.buildUrgencyCapsule();
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }

      if (this.showActivationModal) {
        this.buildCenterModal(
          'check-large',
          '恭喜，准备工作已完成',
          this.activationGuestPath
            ? `接下来开始 ${FIRST_FOCUS_MINUTES} 分钟专注。坚持完成后登录，仍可领取 7 天会员（${MEMBERSHIP_URGENCY_WINDOW_MINUTES} 分钟内有效）。`
            : `接下来开始 ${FIRST_FOCUS_MINUTES} 分钟专注。坚持完成后 7 天会员立即到账（${MEMBERSHIP_URGENCY_WINDOW_MINUTES} 分钟内有效）。`,
          '开始 5 分钟专注',
          () => this.onActivationStart(),
          '稍后再说',
          () => this.onActivationDismiss(),
        )
      }

      if (this.showGuestReclaim) {
        this.buildCenterModal(
          'party',
          '恭喜完成首次专注',
          '本次专注已保存在本地。现在登录，7 天会员立即到账（本次专注已计入）。',
          '登录领取会员',
          () => this.onGuestReclaimConfirm(),
          '稍后再说',
          () => this.onGuestReclaimDismiss(),
        )
      }

      if (this.showCelebration) {
        this.buildCenterModal(
          'party',
          '恭喜，7 天会员已到账',
          '首次专注奖励已发放，尽情体验全部功能吧',
          '查看会员权益',
          () => this.onCelebrationViewBenefits(),
          '我知道了',
          () => this.onCelebrationDismiss(),
        )
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}

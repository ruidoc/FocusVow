import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { showToast } from '../../common/Toast';
import { AgreementConsentRow } from '../../components/common/AgreementConsentRow';
import { AppTheme } from '../../constants/Theme';
import { PageRoutes, backRoute, pushQuickStart, pushRoute, returnToMainTab } from '../../router/PageRoutes';
import {
  FIRST_FOCUS_MINUTES,
  FIRST_FOCUS_TITLE,
  markFirstFocusPromptDone
} from '../../services/FirstFocusPromptService';
import {
  isOnboardingCompleted,
  markOnboardingCompleted,
  OnboardingApiService
} from '../../services/OnboardingApiService';
import { ReferralApiService } from '../../services/ReferralApiService';
import { AnalyticsService } from '../../services/AnalyticsService';
import {
  checkScreenTimeAuthorized,
  requestScreenTimeAuthorization
} from '../../services/ScreenTimeService';
import { SettingsStore } from '../../stores/SettingsStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import {
  clearPendingReferralCode,
  getPendingReferralCode,
  normalizeReferralCode,
  savePendingReferralCode
} from '../../utils/ReferralUtil';
import { confirmPrivacyAgreementForAuth } from '../../utils/PrivacyConsentUtil';
import {
  getGoalsForIdentity,
  goalToProblem,
  IDENTITY_OPTIONS,
  OnboardingOption
} from '../../utils/OnboardingProfile';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

const PARTNER_OPTIONS: OnboardingOption[] = [
  { id: 'yes', title: '有，拉朋友一起', desc: '' },
  { id: 'no', title: '没有，需要匹配', desc: '' }
];

const GUIDE_STEPS_YES: string[] = [
  '进入首页，点「发起互督」',
  '把邀请发给朋友',
  '两人同时开锁，一起专注'
];

const GUIDE_STEPS_NO: string[] = [
  '进入首页，点「发起互督」',
  '进入在线匹配',
  '匹配成功后一起互督锁机'
];

const WECHAT_GREEN: string = '#07C160';
const HUAWEI_RED: string = '#CF0A2C';

@Entry
@Component
struct OnboardingPage {
  @State step: number = 1;
  @State totalSteps: number = 5;
  @State viaOldUser: boolean = false;
  @State identity: string = '';
  @State goal: string = '';
  @State hasBuddy: string = '';
  @State referralCode: string = '';
  @State referralStatus: string = 'idle'; // idle | checking | valid | invalid
  @State showReferralInput: boolean = false;
  @State screenTimeOk: boolean = false;
  @State screenTimeDenied: boolean = false;
  @State busy: boolean = false;
  @State wechatLoading: boolean = false;
  @State huaweiLoading: boolean = false;
  @State agreedToTerms: boolean = false;
  @State topInset: number = 0;
  @State bottomInset: number = 0;
  @State goalOptions: OnboardingOption[] = [];
  @State partnerGuideTexts: string[] = [];
  @State private progressWidthPercent: number = 20;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    SettingsStore.hydrate(hostContext);
    this.viaOldUser = AppStorage.get<boolean>(StoreKeys.OnboardingViaOldUser) === true;
    this.totalSteps = this.viaOldUser ? 4 : 5;
    this.progressWidthPercent = Math.max(8, (this.step / this.totalSteps) * 100);
    if (isOnboardingCompleted(hostContext) && !this.viaOldUser) {
      replaceToHome();
      return;
    }
    const ui = this.getUIContext();
    window.getLastWindow(hostContext, (err, win) => {
      if (err.code) {
        return;
      }
      const systemAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.topInset = ui.px2vp(systemAvoid.topRect.height);
      this.bottomInset = ui.px2vp(navAvoid.bottomRect.height);
    });
    void this.syncPermission();
    const pending = getPendingReferralCode(hostContext);
    if (pending.length > 0) {
      this.referralCode = pending;
      this.showReferralInput = true;
      void this.onReferralBlur();
    }
  }

  onPageShow(): void {
    void this.syncPermission();
  }

  private async syncPermission(): Promise<void> {
    this.screenTimeOk = await checkScreenTimeAuthorized();
    if (this.screenTimeOk) {
      this.screenTimeDenied = false;
    }
  }

  private upsert(payload: Record<string, Object>): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    payload['via_old_user'] = this.viaOldUser;
    void OnboardingApiService.upsert(hostContext, payload);
  }

  private applyStep(next: number): void {
    this.step = next;
    const nextWidth = Math.max(8, (this.step / this.totalSteps) * 100);
    animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.progressWidthPercent = nextWidth;
    });
  }

  private goBack(): void {
    if (this.step <= 1) {
      backRoute();
      return;
    }
    this.applyStep(this.step - 1);
  }

  private selectIdentity(id: string): void {
    this.identity = id;
    this.goal = '';
    this.goalOptions = getGoalsForIdentity(id);
    AnalyticsService.trackEvent('identity_selected', { 'identity': id });
    this.upsert({
      'current_step': 'identity',
      'identity': id
    });
    setTimeout(() => {
      this.applyStep(2);
    }, 180);
  }

  private selectGoal(id: string): void {
    this.goal = id;
    AnalyticsService.trackEvent('goal_selected', {
      'goal': id,
      'identity': this.identity
    });
    this.upsert({
      'current_step': 'goal',
      'identity': this.identity,
      'goal': id,
      'problem': goalToProblem(id)
    });
    setTimeout(() => {
      this.applyStep(3);
    }, 180);
  }

  private selectPartner(id: string): void {
    if (this.hasBuddy === id) {
      return;
    }
    this.hasBuddy = id;
    this.partnerGuideTexts = id === 'yes' ? GUIDE_STEPS_YES.slice() : GUIDE_STEPS_NO.slice();
  }

  private async continueFromPartner(): Promise<void> {
    if (this.hasBuddy.length === 0) {
      return;
    }
    const hasStudyBuddy = this.hasBuddy === 'yes';
    AnalyticsService.trackEvent('study_buddy_selected', {
      'has_study_buddy': hasStudyBuddy,
      'identity': this.identity,
      'goal': this.goal
    });
    const meta: Record<string, Object> = {
      'has_study_buddy': hasStudyBuddy
    };
    this.upsert({
      'current_step': 'partner',
      'identity': this.identity,
      'goal': this.goal,
      'problem': goalToProblem(this.goal),
      'meta': meta
    });

    if (this.viaOldUser) {
      await this.syncPermission();
      if (this.screenTimeOk) {
        this.finish();
        return;
      }
      this.totalSteps = 4;
      this.applyStep(4);
      return;
    }
    AnalyticsService.trackEvent('signup_benefit_viewed', {
      'entry_source': 'onboarding_signup_benefit',
      'screen_name': 'onboarding_signup_benefit'
    });
    this.applyStep(4);
  }

  private async onReferralBlur(): Promise<void> {
    const code = normalizeReferralCode(this.referralCode);
    if (code.length === 0) {
      this.referralStatus = 'idle';
      clearPendingReferralCode();
      return;
    }
    this.referralStatus = 'checking';
    const response = await ReferralApiService.check(code);
    const data = response.data as Record<string, Object> | undefined;
    const valid = data ? data['valid'] === true : false;
    if (valid) {
      this.referralStatus = 'valid';
      savePendingReferralCode(code);
    } else {
      this.referralStatus = 'invalid';
      clearPendingReferralCode();
    }
  }

  private trackSignupBenefitContinue(action: string, loginMethod?: string): void {
    const props: Record<string, Object> = {
      'action': action,
      'referral_code_status': this.referralStatus,
      'has_valid_referral_code': this.referralStatus === 'valid',
      'entry_source': 'onboarding_signup_benefit',
      'screen_name': 'onboarding_signup_benefit'
    };
    if (loginMethod && loginMethod.length > 0) {
      props['login_method'] = loginMethod;
    }
    AnalyticsService.trackEvent('signup_benefit_continued', props);
  }

  private continueInviteToPermission(action: string = 'skip', loginMethod?: string): void {
    if (this.referralStatus === 'checking') {
      return;
    }
    if (this.referralStatus === 'valid') {
      savePendingReferralCode(this.referralCode);
    } else {
      clearPendingReferralCode();
    }
    this.trackSignupBenefitContinue(action, loginMethod);
    this.upsert({
      'current_step': 'invite_login',
      'identity': this.identity,
      'goal': this.goal,
      'problem': goalToProblem(this.goal)
    });
    this.applyStep(5);
    void this.syncPermission();
  }

  private async ensurePrivacy(): Promise<boolean> {
    if (!this.agreedToTerms) {
      const accepted = await confirmPrivacyAgreementForAuth(this.getUIContext());
      if (!accepted) {
        return false;
      }
      this.agreedToTerms = true;
    }
    return true;
  }

  private async onInviteWechatLogin(): Promise<void> {
    if (this.referralStatus === 'checking') {
      return;
    }
    if (!(await this.ensurePrivacy())) {
      return;
    }
    if (this.referralStatus === 'valid') {
      savePendingReferralCode(this.referralCode);
    } else {
      clearPendingReferralCode();
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.wechatLoading = true;
    const result = await UserStore.loginWithWechat(hostContext);
    if (result === UserStore.WECHAT_NEED_BIND) {
      const createError = await UserStore.wechatCreateSkipEmail(hostContext);
      this.wechatLoading = false;
      if (createError) {
        showToast(createError, this.getUIContext());
        return;
      }
      if (!UserStore.isLoggedIn()) {
        return;
      }
      this.continueInviteToPermission('login', 'wechat');
      return;
    }
    this.wechatLoading = false;
    if (result) {
      showToast(result, this.getUIContext());
      return;
    }
    if (!UserStore.isLoggedIn()) {
      return;
    }
    showToast('7 天会员仅限新用户领取', this.getUIContext(), 3000);
    this.continueInviteToPermission('login', 'wechat');
  }

  private async onInviteHuaweiLogin(): Promise<void> {
    if (this.referralStatus === 'checking') {
      return;
    }
    if (!(await this.ensurePrivacy())) {
      return;
    }
    if (this.referralStatus === 'valid') {
      savePendingReferralCode(this.referralCode);
    } else {
      clearPendingReferralCode();
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.huaweiLoading = true;
    const result = await UserStore.loginWithHuawei(hostContext);
    this.huaweiLoading = false;
    if (result) {
      showToast(result, this.getUIContext());
      return;
    }
    if (!UserStore.isLoggedIn()) {
      return;
    }
    this.continueInviteToPermission('login', 'huawei');
  }

  private async requestScreenTime(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    AnalyticsService.trackEvent('permission_request_clicked', {
      'permission_type': 'screen_time',
      'scene': 'onboarding',
      'entry_source': 'onboarding',
      'screen_name': 'onboarding_permission_setup'
    });
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await requestScreenTimeAuthorization(hostContext);
    // 以系统真实授权为准（request 返回后可能仍在弹框中）
    const authorized = result.ok || (await checkScreenTimeAuthorized());
    SettingsStore.updateAuthorization(
      hostContext,
      authorized,
      authorized ? '系统授权已开启' : result.message
    );
    this.screenTimeOk = authorized;
    if (authorized) {
      this.screenTimeDenied = false;
    } else {
      this.screenTimeDenied = true;
    }
    AnalyticsService.trackEvent('permission_result', {
      'permission_type': 'screen_time',
      'result': authorized ? 'approved' : 'denied',
      'scene': 'onboarding'
    });
    this.busy = false;
  }

  private getScreenTimeStatus(): string {
    if (this.screenTimeOk) {
      return 'approved';
    }
    if (this.screenTimeDenied) {
      return 'denied';
    }
    return 'skipped';
  }

  private finish(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const screenTimeStatus = this.getScreenTimeStatus();
    const meta: Record<string, Object> = {
      'has_study_buddy': this.hasBuddy === 'yes'
    };
    AnalyticsService.trackEvent('onboarding_finished', {
      'with_login': UserStore.isLoggedIn(),
      'entry_source': this.viaOldUser ? 'welcome_old_user' : 'onboarding',
      'identity': this.identity,
      'goal': this.goal,
      'has_study_buddy': this.hasBuddy === 'yes',
      'via_old_user': this.viaOldUser,
      'screen_time_status': screenTimeStatus
    });
    this.upsert({
      'current_step': 'done',
      'finished': true,
      'identity': this.identity,
      'goal': this.goal,
      'problem': goalToProblem(this.goal),
      'screen_time_status': screenTimeStatus,
      'meta': meta
    });
    markOnboardingCompleted(hostContext);
    markFirstFocusPromptDone(hostContext);
    AppStorage.setOrCreate(StoreKeys.OnboardingViaOldUser, false);
    AppStorage.setOrCreate(StoreKeys.LoginFrom, '');
    returnToMainTab('focus');
    setTimeout(() => {
      pushQuickStart(FIRST_FOCUS_TITLE, FIRST_FOCUS_MINUTES, true);
    }, 80);
  }

  private isInviteStep(): boolean {
    return !this.viaOldUser && this.step === 4;
  }

  private isPermissionStep(): boolean {
    if (this.viaOldUser) {
      return this.step === 4;
    }
    return this.step === 5;
  }

  @Builder
  private buildTopBar(): void {
    Row() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(18)
          .fontColor([AppTheme.colors.textPrimary])
      }
      .width(36)
      .height(36)
      .backgroundColor('rgba(0,0,0,0.04)')
      .onClick(() => {
        this.goBack();
      })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(8)
          .borderRadius(4)
          .backgroundColor(AppTheme.colors.border)
        Row()
          .width(`${this.progressWidthPercent}%`)
          .height(8)
          .borderRadius(4)
          .backgroundColor(AppTheme.colors.primary)
      }
      .layoutWeight(1)
      .height(8)
      .clip(true)
      .margin({ left: 12, right: 12 })

      Row()
        .width(36)
        .height(36)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildIdentityStep(): void {
    Column({ space: 16 }) {
      Text('你的身份是？')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .textAlign(TextAlign.Center)
        .width('100%')
      Text('正确选择，精准匹配搭子')
        .fontSize(15)
        .fontColor(AppTheme.colors.textSecondary)
        .lineHeight(24)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 24 })
      ForEach(IDENTITY_OPTIONS, (option: OnboardingOption) => {
        Button() {
          Row() {
            Text(option.title)
              .layoutWeight(1)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.identity === option.id ? AppTheme.colors.primary : AppTheme.colors.textPrimary)
            if (this.identity === option.id) {
              Text('✓')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.colors.primary)
            }
          }
          .width('100%')
          .height(60)
          .padding({ left: 20, right: 20 })
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .type(ButtonType.Normal)
        .backgroundColor(this.identity === option.id ? 'rgba(122, 90, 248, 0.08)' : 'rgba(0,0,0,0.04)')
        .border({
          width: 1.5,
          color: this.identity === option.id ? AppTheme.colors.primary : Color.Transparent
        })
        .borderRadius(16)
        .onClick(() => {
          this.selectIdentity(option.id);
        })
      }, (option: OnboardingOption) => option.id)
    }
    .width('100%')
    .padding({ left: 32, right: 32, top: 8 })
  }

  @Builder
  private buildGoalStep(): void {
    Column({ space: 16 }) {
      Text('你的专注目标是？')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 24 })
      ForEach(this.goalOptions, (option: OnboardingOption) => {
        Button() {
          Row() {
            Text(option.title)
              .layoutWeight(1)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.goal === option.id ? AppTheme.colors.primary : AppTheme.colors.textPrimary)
            if (this.goal === option.id) {
              Text('✓')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.colors.primary)
            }
          }
          .width('100%')
          .height(60)
          .padding({ left: 20, right: 20 })
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .type(ButtonType.Normal)
        .backgroundColor(this.goal === option.id ? 'rgba(122, 90, 248, 0.08)' : 'rgba(0,0,0,0.04)')
        .border({
          width: 1.5,
          color: this.goal === option.id ? AppTheme.colors.primary : Color.Transparent
        })
        .borderRadius(16)
        .onClick(() => {
          this.selectGoal(option.id);
        })
      }, (option: OnboardingOption) => option.id)
    }
    .width('100%')
    .padding({ left: 32, right: 32, top: 8 })
  }

  @Builder
  private buildPartnerStep(): void {
    Column() {
      Column({ space: 16 }) {
        Text('你有学习搭子吗？')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ bottom: 24 })
        ForEach(PARTNER_OPTIONS, (option: OnboardingOption) => {
          Button() {
            Row() {
              Text(option.title)
                .layoutWeight(1)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.hasBuddy === option.id ? AppTheme.colors.primary : AppTheme.colors.textPrimary)
              if (this.hasBuddy === option.id) {
                Text('✓')
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppTheme.colors.primary)
              }
            }
            .width('100%')
            .height(60)
            .padding({ left: 20, right: 20 })
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .type(ButtonType.Normal)
          .backgroundColor(this.hasBuddy === option.id ? 'rgba(122, 90, 248, 0.08)' : 'rgba(0,0,0,0.04)')
          .border({
            width: 1.5,
            color: this.hasBuddy === option.id ? AppTheme.colors.primary : Color.Transparent
          })
          .borderRadius(16)
          .onClick(() => {
            this.selectPartner(option.id);
          })
        }, (option: OnboardingOption) => option.id)

        if (this.partnerGuideTexts.length > 0) {
          Column() {
            ForEach(this.partnerGuideTexts, (text: string, index: number) => {
              Row({ space: 12 }) {
                Column({ space: 2 }) {
                  Text(`${index + 1}`)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#64748B')
                    .width(22)
                    .height(22)
                    .textAlign(TextAlign.Center)
                    .borderRadius(11)
                    .backgroundColor('rgba(100,116,139,0.1)')
                  if (index < this.partnerGuideTexts.length - 1) {
                    Row()
                      .width(1)
                      .height(14)
                      .backgroundColor('rgba(100,116,139,0.2)')
                  }
                }
                .width(22)
                .alignItems(HorizontalAlign.Center)
                Text(text)
                  .layoutWeight(1)
                  .fontSize(13)
                  .fontColor(AppTheme.colors.textSecondary)
                  .lineHeight(20)
                  .padding({ top: 1, bottom: index < this.partnerGuideTexts.length - 1 ? 6 : 0 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (text: string, index: number) => `${this.hasBuddy}-${index}-${text}`)
          }
          .width('100%')
          .margin({ top: 28, left: 4 })
          .alignItems(HorizontalAlign.Start)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 32, right: 32, top: 8 })
      .alignItems(HorizontalAlign.Start)

      Column() {
        Button('下一步')
          .width('100%')
          .height(52)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(AppTheme.colors.primary)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .enabled(this.hasBuddy.length > 0)
          .opacity(this.hasBuddy.length > 0 ? 1 : 0.45)
          .onClick(() => {
            void this.continueFromPartner();
          })
      }
      .width('100%')
      .padding({
        left: 32,
        right: 32,
        bottom: Math.max(this.bottomInset, 8) + 24
      })
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private buildInviteStep(): void {
    Column() {
      Column({ space: 0 }) {
        Text('新用户权益')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
          .width('100%')
        Text('注册并完成首次专注后，领取 7 天会员')
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .lineHeight(22)
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 12, bottom: 32 })

        Button() {
          Row({ space: 8 }) {
            Image($r('app.media.huawei'))
              .width(22)
              .height(22)
              .objectFit(ImageFit.Contain)
            Text(this.huaweiLoading ? '请稍候...' : '华为账号登录')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
        }
        .width('100%')
        .height(52)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .backgroundColor(HUAWEI_RED)
        .borderRadius(AppTheme.radius.button)
        .clip(true)
        .enabled(this.referralStatus !== 'checking' && !this.wechatLoading && !this.huaweiLoading)
        .opacity(this.referralStatus === 'checking' || this.wechatLoading || this.huaweiLoading ? 0.6 : 1)
        .margin({ bottom: 12 })
        .onClick(() => {
          void this.onInviteHuaweiLogin();
        })

        Button() {
          Row({ space: 8 }) {
            Image($r('app.media.wechat'))
              .width(22)
              .height(22)
              .objectFit(ImageFit.Contain)
            Text(this.wechatLoading ? '请稍候...' : '微信登录/注册')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
        }
        .width('100%')
        .height(52)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .backgroundColor(WECHAT_GREEN)
        .borderRadius(AppTheme.radius.button)
        .clip(true)
        .enabled(this.referralStatus !== 'checking' && !this.wechatLoading && !this.huaweiLoading)
        .opacity(this.referralStatus === 'checking' || this.wechatLoading || this.huaweiLoading ? 0.6 : 1)
        .onClick(() => {
          void this.onInviteWechatLogin();
        })

        if (this.showReferralInput) {
          Column() {
            Text('有邀请码，首次专注后再 +15 天')
              .fontSize(13)
              .fontColor(AppTheme.colors.textMuted)
              .width('100%')
              .margin({ bottom: 12 })
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.gift'))
                .fontSize(18)
                .fontColor([AppTheme.colors.textMuted])
              TextInput({ placeholder: '输入邀请码', text: this.referralCode })
                .layoutWeight(1)
                .height(48)
                .fontSize(16)
                .padding(0)
                .backgroundColor(Color.Transparent)
                .onChange((value: string) => {
                  this.referralCode = value;
                  if (this.referralStatus !== 'idle' && this.referralStatus !== 'checking') {
                    this.referralStatus = 'idle';
                  }
                  if (normalizeReferralCode(value).length === 0) {
                    this.referralStatus = 'idle';
                    clearPendingReferralCode();
                  }
                })
                .onBlur(() => {
                  void this.onReferralBlur();
                })
              if (this.referralStatus === 'checking') {
                LoadingProgress()
                  .width(18)
                  .height(18)
                  .color(AppTheme.colors.primary)
              } else if (this.referralStatus === 'valid') {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                  .fontSize(20)
                  .fontColor([AppTheme.colors.success])
              }
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
            .backgroundColor('rgba(0,0,0,0.04)')
            .borderRadius(16)

            if (this.referralStatus === 'invalid') {
              Text('邀请码无效，注册时将忽略')
                .fontSize(12)
                .fontColor(AppTheme.colors.danger)
                .lineHeight(18)
                .width('100%')
                .textAlign(TextAlign.Start)
                .margin({ top: 8 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 32 })
        } else {
          Text('我有邀请码')
            .fontSize(14)
            .fontColor(AppTheme.colors.textMuted)
            .margin({ top: 32 })
            .onClick(() => {
              this.showReferralInput = true;
            })
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 32, right: 32, top: 8 })
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Start)

      Column({ space: 8 }) {
        AgreementConsentRow({
          agreed: this.agreedToTerms,
          centered: true,
          onAgreedChange: (agreed: boolean) => {
            this.agreedToTerms = agreed;
          }
        })
        Text('先看看')
          .fontSize(14)
          .fontColor(AppTheme.colors.textMuted)
          .padding({ top: 12, bottom: 8 })
          .opacity(this.referralStatus === 'checking' ? 0.4 : 1)
          .onClick(() => {
            if (this.referralStatus === 'checking') {
              return;
            }
            this.continueInviteToPermission('skip');
          })
      }
      .width('100%')
      .padding({
        left: 32,
        right: 32,
        bottom: Math.max(this.bottomInset, 8) + 16
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private buildPermissionStepItem(): void {
    // 直接读 this.screenTimeOk，避免 @Builder 入参不随 @State 刷新
    Row({ space: 14 }) {
      Row() {
        if (this.screenTimeOk) {
          Text('✓')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.accentGreen)
        } else {
          Text('1')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textSecondary)
        }
      }
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .borderRadius(14)
      .backgroundColor(this.screenTimeOk ? 'rgba(16,185,129,0.13)' : 'rgba(0,0,0,0.06)')
      .margin({ top: 2 })

      Column({ space: 4 }) {
        Text('健康使用设备权限')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.screenTimeOk ? AppTheme.colors.accentGreen : AppTheme.colors.textPrimary)
          .width('100%')
        Text('用于专注期间锁住分心应用')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .lineHeight(19)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.screenTimeOk ? '已开启' : (this.screenTimeDenied ? '已拒绝' : '未开启'))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.screenTimeOk
          ? AppTheme.colors.accentGreen
          : (this.screenTimeDenied ? AppTheme.colors.danger : AppTheme.colors.textSecondary))
        .margin({ top: 4 })
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Top)
    .onClick(() => {
      if (this.screenTimeOk) {
        return;
      }
      void this.requestScreenTime();
    })
  }

  @Builder
  private buildPermissionStep(): void {
    Column() {
      Column({ space: 0 }) {
        Text('需要权限')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
          .width('100%')
        Text('开始专注之前，先开一下必要权限')
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .lineHeight(24)
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 8, bottom: 20 })

        this.buildPermissionStepItem()
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 32, right: 32, top: 8 })

      Column({ space: 8 }) {
        if (this.screenTimeOk) {
          Button('开始第一次专注')
            .width('100%')
            .height(52)
            .type(ButtonType.Normal)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(AppTheme.colors.primary)
            .borderRadius(AppTheme.radius.button)
            .clip(true)
            .onClick(() => {
              this.finish();
            })
        } else if (this.screenTimeDenied) {
          Button(this.busy ? '授权中...' : '重新授权')
            .width('100%')
            .height(52)
            .type(ButtonType.Normal)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(AppTheme.colors.primary)
            .borderRadius(AppTheme.radius.button)
            .clip(true)
            .enabled(!this.busy)
            .opacity(this.busy ? 0.6 : 1)
            .onClick(() => {
              void this.requestScreenTime();
            })

          Button('开始第一次专注')
            .width('100%')
            .height(52)
            .type(ButtonType.Normal)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.primary)
            .backgroundColor(AppTheme.colors.surface)
            .border({ width: 1, color: AppTheme.colors.primary })
            .borderRadius(AppTheme.radius.button)
            .clip(true)
            .onClick(() => {
              this.finish();
            })
        } else {
          Button(this.busy ? '授权中...' : '去开启')
            .width('100%')
            .height(52)
            .type(ButtonType.Normal)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(AppTheme.colors.primary)
            .borderRadius(AppTheme.radius.button)
            .clip(true)
            .enabled(!this.busy)
            .opacity(this.busy ? 0.6 : 1)
            .onClick(() => {
              void this.requestScreenTime();
            })
        }
      }
      .width('100%')
      .padding({
        left: 32,
        right: 32,
        bottom: Math.max(this.bottomInset, 8) + 24
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private buildCurrentStep(): void {
    if (this.step === 1) {
      this.buildIdentityStep()
    } else if (this.step === 2) {
      this.buildGoalStep()
    } else if (this.step === 3) {
      this.buildPartnerStep()
    } else if (this.isInviteStep()) {
      this.buildInviteStep()
    } else if (this.isPermissionStep()) {
      this.buildPermissionStep()
    }
  }

  build() {
    Column() {
      this.buildTopBar()
      this.buildCurrentStep()
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topInset })
    .backgroundColor(AppTheme.colors.background)
  }
}

function replaceToHome(): void {
  returnToMainTab('focus');
}

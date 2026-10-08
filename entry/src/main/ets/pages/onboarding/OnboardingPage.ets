import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { showErrorToast, showToast } from '../../common/Toast';
import { AgreementConsentRow } from '../../components/common/AgreementConsentRow';
import { OnboardingPlanReveal } from '../../components/onboarding/OnboardingPlanReveal';
import { PageBackgroundDecoration } from '../../components/common/PageBackgroundDecoration';
import { AppTheme } from '../../constants/Theme';
import { FeatureFlagKeys } from '../../config/FeatureFlags';
import { backRoute, PageRoutes, pushQuickStart, pushRoute, returnToMainTab } from '../../router/PageRoutes';
import {
  FIRST_FOCUS_MINUTES,
  FIRST_FOCUS_TITLE
} from '../../services/FirstFocusPromptService';
import {
  isOnboardingCompleted,
  markOnboardingCompleted,
  OnboardingApiService
} from '../../services/OnboardingApiService';
import { ReferralApiService } from '../../services/ReferralApiService';
import { WeComCustomerService } from '../../services/WeComCustomerService';
import { AnalyticsService } from '../../services/AnalyticsService';
import {
  checkScreenTimeAuthorized,
  requestScreenTimeAuthorization
} from '../../services/ScreenTimeService';
import { SettingsStore } from '../../stores/SettingsStore';
import { FeatureFlagStore } from '../../stores/FeatureFlagStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import {
  clearMembershipSignupSkipped,
  hasSkippedMembershipSignup,
  isOnboardingMembershipBenefitActive,
  markMembershipSignupSkipped,
  setPendingOnboardingActivationModal,
} from '../../utils/OnboardingMembershipUtil';
import { SIGNUP_TRIAL_EXISTING_USER_TOAST } from '../../utils/SignupTrialUtil';
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
import {
  buildOnboardingAnalyticsProps,
  buildOnboardingMetaPatch,
  OnboardingPath,
  patchOnboardingMeta,
} from '../../utils/OnboardingMetaUtil';
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

const LOGIN_BENEFIT_LINES: string[] = [
  '专注记录云端同步，换机也不丢',
  'iOS / Android / 鸿蒙 三端共享',
  '在线找搭子，一起互督锁机',
  '账号安全保存，专注数据长期留存',
];

const WECHAT_GREEN: string = '#07C160';
const HUAWEI_RED: string = '#CF0A2C';

@Entry
@Component
struct OnboardingPage {
  @State step: number = 1;
  @State totalSteps: number = 5;
  @State viaOldUser: boolean = false;
  @State permOnly: boolean = false;
  @State identity: string = '';
  @State goal: string = '';
  @State hasBuddy: string = '';
  @State referralCode: string = '';
  @State referralStatus: string = 'idle'; // idle | checking | valid | invalid
  @State showSkipConfirm: boolean = false;
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
  @StorageLink(StoreKeys.FeatureFlagsOff) @Watch('onFeaturesOffChanged') featuresOff: string[] = [];
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';

  aboutToAppear(): void {
    void this.initOnboarding();
  }

  private async initOnboarding(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    SettingsStore.hydrate(hostContext);
    FeatureFlagStore.hydrate(hostContext);
    await FeatureFlagStore.sync(hostContext);
    this.viaOldUser = AppStorage.get<boolean>(StoreKeys.OnboardingViaOldUser) === true;
    if (AppStorage.get<boolean>(StoreKeys.OnboardingPermOnly) === true) {
      AppStorage.setOrCreate(StoreKeys.OnboardingPermOnly, false);
      this.permOnly = true;
    }
    patchOnboardingMeta({
      entry_source: this.viaOldUser ? 'welcome_old_user' : 'new_explore',
    });
    this.totalSteps = this.getTotalSteps();
    if (this.permOnly) {
      this.step = 1;
      this.progressWidthPercent = 100;
      void this.syncPermission();
      return;
    }
    if (AppStorage.get<boolean>(StoreKeys.OnboardingAfterRegister) === true) {
      AppStorage.setOrCreate(StoreKeys.OnboardingAfterRegister, false);
      patchOnboardingMeta({
        onboarding_path: 'register_first',
        benefit_eligible: true,
        entry_source: 'new_explore',
      });
      AnalyticsService.trackEvent('onboarding_path_decided', buildOnboardingAnalyticsProps({
        'action': 'email_register',
        'login_method': 'email',
      }));
      if (UserStore.isLoggedIn()) {
        AnalyticsService.trackEvent('onboarding_registered', buildOnboardingAnalyticsProps({
          'login_method': 'email',
        }));
      }
      if (this.viaOldUser) {
        this.step = this.stepPermission();
      } else {
        this.step = this.stepReferral();
      }
    }
    this.progressWidthPercent = Math.max(8, (this.step / this.totalSteps) * 100);
    if (isOnboardingCompleted(hostContext) && !this.viaOldUser && !this.permOnly) {
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
      this.referralCode = pending.slice(0, 11);
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
    if (this.permOnly) {
      returnToMainTab('focus');
      return;
    }
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
      if (this.showPartnerStep()) {
        this.applyStep(this.stepPartner());
      } else {
        this.applyStep(this.stepPlan());
      }
    }, 180);
  }

  private onPlanComplete(): void {
    AnalyticsService.trackEvent('onboarding_plan_finished', {
      'identity': this.identity,
      'goal': this.goal,
    });
    this.upsert({
      'current_step': 'plan_reveal',
      'identity': this.identity,
      'goal': this.goal,
      'problem': goalToProblem(this.goal),
    });
    void this.continueAfterPlan();
  }

  private async continueAfterPlan(): Promise<void> {
    if (this.showPartnerStep()) {
      this.applyStep(this.stepPartner());
      return;
    }
    if (this.viaOldUser) {
      await this.syncPermission();
      if (this.screenTimeOk) {
        this.finish();
        return;
      }
      this.applyStep(this.stepPermission());
      return;
    }
    AnalyticsService.trackEvent('signup_benefit_viewed', {
      'entry_source': 'onboarding_signup_benefit',
      'screen_name': 'onboarding_signup_benefit',
    });
    this.applyStep(this.stepInvite());
  }

  private onFeaturesOffChanged(): void {
    this.totalSteps = this.getTotalSteps();
    if (!this.showPartnerStep() && this.isPartnerStep()) {
      void this.skipPartnerStep();
    }
  }

  private showPartnerStep(): boolean {
    // 搭子步骤暂隐藏，buildPartnerStep 保留供后续恢复
    return false;
  }

  private isScreenTimeRequired(): boolean {
    return !FeatureFlagStore.isFeatureOff(FeatureFlagKeys.SKIP_OVERLAY);
  }

  private isLoginSkipHidden(): boolean {
    return FeatureFlagStore.isFeatureOff(FeatureFlagKeys.OB_LOGIN_SKIP);
  }

  private async onContactSupport(entrySource: string): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const errorMessage = await WeComCustomerService.open(hostContext, entrySource);
    if (errorMessage !== null) {
      showErrorToast(errorMessage, this.getUIContext());
    }
  }

  private stepPlan(): number {
    return 3;
  }

  private stepPartner(): number {
    return 4;
  }

  private stepInvite(): number {
    return this.showPartnerStep() ? 5 : 4;
  }

  private stepReferral(): number {
    return this.showPartnerStep() ? 6 : 5;
  }

  private stepPermission(): number {
    if (this.permOnly) {
      return 1;
    }
    if (this.viaOldUser) {
      return this.showPartnerStep() ? 5 : 4;
    }
    return this.showPartnerStep() ? 7 : 6;
  }

  private getTotalSteps(): number {
    return this.stepPermission();
  }

  private getPermissionStepNumber(): number {
    return this.stepPermission();
  }

  private async skipPartnerStep(): Promise<void> {
    if (this.viaOldUser) {
      await this.syncPermission();
      if (this.screenTimeOk) {
        this.finish();
        return;
      }
      this.applyStep(this.getPermissionStepNumber());
      return;
    }
    AnalyticsService.trackEvent('signup_benefit_viewed', {
      'entry_source': 'onboarding_signup_benefit',
      'screen_name': 'onboarding_signup_benefit'
    });
    this.applyStep(this.stepInvite());
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
      this.totalSteps = this.getTotalSteps();
      this.applyStep(this.getPermissionStepNumber());
      return;
    }
    AnalyticsService.trackEvent('signup_benefit_viewed', {
      'entry_source': 'onboarding_signup_benefit',
      'screen_name': 'onboarding_signup_benefit'
    });
    this.applyStep(this.stepInvite());
  }

  private async onReferralBlur(): Promise<boolean> {
    const code = normalizeReferralCode(this.referralCode);
    if (code.length === 0) {
      this.referralStatus = 'idle';
      clearPendingReferralCode();
      return false;
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
    return valid;
  }

  private trackSignupBenefitContinue(
    action: string,
    loginMethod?: string,
    benefitEligible: boolean = true,
    onboardingPath?: OnboardingPath,
  ): void {
    const path = onboardingPath ?? (action === 'skip' ? 'focus_first' : 'register_first');
    const props: Record<string, Object> = buildOnboardingAnalyticsProps({
      'action': action,
      'referral_code_status': this.referralStatus,
      'has_valid_referral_code': this.referralStatus === 'valid',
      'entry_source': 'onboarding_signup_benefit',
      'screen_name': 'onboarding_signup_benefit',
      'benefit_eligible': benefitEligible,
      'onboarding_path': path,
    });
    if (loginMethod && loginMethod.length > 0) {
      props['login_method'] = loginMethod;
    }
    AnalyticsService.trackEvent('signup_benefit_continued', props);
  }

  private decideOnboardingPath(
    onboardingPath: OnboardingPath,
    action: string,
    loginMethod?: string,
    benefitEligible: boolean = true,
  ): void {
    patchOnboardingMeta({
      onboarding_path: onboardingPath,
      benefit_eligible: benefitEligible,
      entry_source: 'new_explore',
    });
    const decidedProps: Record<string, Object> = buildOnboardingAnalyticsProps({
      'onboarding_path': onboardingPath,
      'action': action,
      'benefit_eligible': benefitEligible,
    });
    if (loginMethod && loginMethod.length > 0) {
      decidedProps['login_method'] = loginMethod;
    }
    AnalyticsService.trackEvent('onboarding_path_decided', decidedProps);
    if (!benefitEligible) {
      AnalyticsService.trackEvent('onboarding_benefit_ineligible', buildOnboardingAnalyticsProps({
        'login_method': loginMethod ?? '',
      }));
    }
    if (
      onboardingPath === 'register_first' &&
      benefitEligible &&
      UserStore.isLoggedIn()
    ) {
      AnalyticsService.trackEvent('onboarding_registered', buildOnboardingAnalyticsProps({
        'login_method': loginMethod ?? '',
      }));
    }
  }

  private goInviteContinue(
    action: string = 'skip',
    loginMethod?: string,
    benefitEligible: boolean = true,
    skipReferral: boolean = false,
  ): void {
    const onboardingPath: OnboardingPath = action === 'skip' ? 'focus_first' : 'register_first';
    this.decideOnboardingPath(onboardingPath, action, loginMethod, benefitEligible);
    this.trackSignupBenefitContinue(action, loginMethod, benefitEligible, onboardingPath);
    const meta = buildOnboardingMetaPatch({
      onboarding_path: onboardingPath,
      benefit_eligible: benefitEligible,
      entry_source: 'new_explore',
    });
    meta['has_study_buddy'] = this.hasBuddy === 'yes';
    this.upsert({
      'current_step': 'invite_login',
      'identity': this.identity,
      'goal': this.goal,
      'problem': goalToProblem(this.goal),
      'meta': meta,
    });
    if (onboardingPath === 'focus_first' || this.viaOldUser || skipReferral) {
      if (action === 'skip') {
        clearPendingReferralCode();
      }
      this.applyStep(this.stepPermission());
      void this.syncPermission();
      return;
    }
    AnalyticsService.trackEvent('onboarding_referral_viewed', {
      'entry_source': 'onboarding_signup_benefit',
    });
    this.applyStep(this.stepReferral());
  }

  private continueFromReferral(skipped: boolean): void {
    AnalyticsService.trackEvent('onboarding_referral_continued', {
      'referral_code_status': skipped ? 'idle' : this.referralStatus,
      'has_valid_referral_code': !skipped && this.referralStatus === 'valid',
      'skipped': skipped,
    });
    this.upsert({
      'current_step': 'referral',
      'identity': this.identity,
      'goal': this.goal,
      'problem': goalToProblem(this.goal),
    });
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!skipped && this.referralStatus === 'valid' && UserStore.isLoggedIn()) {
      void UserStore.flushPendingReferral(hostContext);
    }
    if (skipped) {
      clearPendingReferralCode();
    }
    this.applyStep(this.stepPermission());
    void this.syncPermission();
  }

  private async onReferralVerify(): Promise<void> {
    if (this.referralStatus === 'checking') {
      return;
    }
    const valid = await this.onReferralBlur();
    if (!valid) {
      return;
    }
    this.continueFromReferral(false);
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
    if (!(await this.ensurePrivacy())) {
      return;
    }
    clearPendingReferralCode();
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
      this.afterInviteLoginSuccess('wechat');
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
    if (!UserStore.lastLoginIsNew) {
      showToast(SIGNUP_TRIAL_EXISTING_USER_TOAST, this.getUIContext(), 3000);
    }
    this.afterInviteLoginSuccess('wechat');
  }

  private async onInviteHuaweiLogin(): Promise<void> {
    if (!(await this.ensurePrivacy())) {
      return;
    }
    clearPendingReferralCode();
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
    if (!UserStore.lastLoginIsNew) {
      showToast(SIGNUP_TRIAL_EXISTING_USER_TOAST, this.getUIContext(), 3000);
    }
    this.afterInviteLoginSuccess('huawei');
  }

  private afterInviteLoginSuccess(loginMethod: string): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    clearMembershipSignupSkipped(hostContext);
    const benefitEligible = UserStore.lastLoginIsNew;
    this.goInviteContinue('login', loginMethod, benefitEligible, !UserStore.lastLoginIsNew);
  }

  private onInviteEmailRegister(): void {
    clearPendingReferralCode();
    this.trackSignupBenefitContinue('email_register', 'email', false, 'register_first');
    AppStorage.setOrCreate(StoreKeys.LoginFrom, 'onboarding_signup_benefit');
    pushRoute(PageRoutes.Register);
  }

  private referralHasInput(): boolean {
    return normalizeReferralCode(this.referralCode).length > 0;
  }

  private openSkipConfirm(): void {
    AnalyticsService.trackEvent('onboarding_skip_modal_shown', {
      'entry_source': 'onboarding_signup_benefit',
    });
    this.showSkipConfirm = true;
  }

  private confirmSkipMembership(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.showSkipConfirm = false;
    markMembershipSignupSkipped(hostContext);
    this.goInviteContinue('skip');
  }

  private async requestScreenTime(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    AnalyticsService.trackEvent('permission_request_clicked', {
      'permission_type': 'screen_time_harmony',
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
      'permission_type': 'screen_time_harmony',
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
    const finishMeta = buildOnboardingMetaPatch({
      entry_source: this.viaOldUser ? 'welcome_old_user' : 'new_explore',
    });
    finishMeta['has_study_buddy'] = this.hasBuddy === 'yes';
    AnalyticsService.trackEvent('onboarding_finished', buildOnboardingAnalyticsProps({
      'with_login': UserStore.isLoggedIn(),
      'entry_source': this.viaOldUser ? 'welcome_old_user' : 'onboarding',
      'identity': this.identity,
      'goal': this.goal,
      'has_study_buddy': this.hasBuddy === 'yes',
      'via_old_user': this.viaOldUser,
      'perm_only': this.permOnly,
      'screen_time_status': screenTimeStatus,
    }));
    this.upsert({
      'current_step': 'done',
      'finished': true,
      'identity': this.identity,
      'goal': this.goal,
      'problem': goalToProblem(this.goal),
      'screen_time_status': screenTimeStatus,
      'meta': finishMeta
    });
    markOnboardingCompleted(hostContext);
    AppStorage.setOrCreate(StoreKeys.OnboardingViaOldUser, false);
    AppStorage.setOrCreate(StoreKeys.LoginFrom, '');
    if (this.permOnly) {
      returnToMainTab('focus');
      return;
    }
    if (hasSkippedMembershipSignup(hostContext)) {
      returnToMainTab('focus');
      setTimeout(() => {
        pushQuickStart(FIRST_FOCUS_TITLE, FIRST_FOCUS_MINUTES, true);
      }, 80);
      return;
    }
    if (isOnboardingMembershipBenefitActive(hostContext)) {
      setPendingOnboardingActivationModal(hostContext);
    }
    returnToMainTab('focus');
  }

  private isPlanStep(): boolean {
    return !this.permOnly && this.step === this.stepPlan();
  }

  private isInviteStep(): boolean {
    if (this.permOnly || this.viaOldUser) {
      return false;
    }
    return this.step === this.stepInvite();
  }

  private isReferralStep(): boolean {
    if (this.permOnly || this.viaOldUser) {
      return false;
    }
    return this.step === this.stepReferral();
  }

  private isPermissionStep(): boolean {
    return this.step === this.stepPermission();
  }

  private isPartnerStep(): boolean {
    return !this.permOnly && this.showPartnerStep() && this.step === this.stepPartner();
  }

  private getPermissionFinishLabel(): string {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return hasSkippedMembershipSignup(hostContext) ? '开始第一次专注' : '完成';
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
      Text('正确选择，为您定制专属方案')
        .fontSize(15)
        .fontColor(AppTheme.colors.textSecondary)
        .lineHeight(24)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 24 })
      ForEach(IDENTITY_OPTIONS, (option: OnboardingOption) => {
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
        .backgroundColor(this.identity === option.id ? AppTheme.colors.primarySoft : (this.themeMode === 'dark' ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)'))
        .clip(true)
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
        .backgroundColor(this.goal === option.id ? AppTheme.colors.primarySoft : (this.themeMode === 'dark' ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)'))
        .clip(true)
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
          .backgroundColor(this.hasBuddy === option.id ? AppTheme.colors.primarySoft : (this.themeMode === 'dark' ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)'))
          .clip(true)
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
  private buildLoginBenefitLine(text: string): void {
    Row({ space: 8 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(11)
          .fontColor(['#16A34A'])
      }
      .width(18)
      .height(18)
      .justifyContent(FlexAlign.Center)
      .borderRadius(9)
      .backgroundColor('rgba(22, 163, 74, 0.12)')

      Text(text)
        .fontSize(15)
        .lineHeight(22)
        .fontColor(AppTheme.colors.textSecondary)
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildInviteStep(): void {
    Column() {
      Scroll() {
        Column() {
          Text('登录领取方案')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ bottom: 8 })

          Text('登录后专属方案自动同步到你的账号')
            .fontSize(15)
            .lineHeight(22)
            .fontColor(AppTheme.colors.textSecondary)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ bottom: 32 })

          Column({ space: 10 }) {
            ForEach(LOGIN_BENEFIT_LINES, (line: string) => {
              this.buildLoginBenefitLine(line)
            }, (line: string) => line)
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 80 })

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
          .enabled(!this.wechatLoading && !this.huaweiLoading)
          .opacity(this.wechatLoading || this.huaweiLoading ? 0.6 : 1)
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
          .enabled(!this.wechatLoading && !this.huaweiLoading)
          .opacity(this.wechatLoading || this.huaweiLoading ? 0.6 : 1)
          .margin({ bottom: 12 })
          .onClick(() => {
            void this.onInviteWechatLogin();
          })

          Button() {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.envelope'))
                .fontSize(20)
                .fontColor([AppTheme.colors.textPrimary])
              Text('邮箱注册')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.colors.textPrimary)
            }
          }
          .width('100%')
          .height(52)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .backgroundColor(AppTheme.colors.surfaceSecondary)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .enabled(!this.wechatLoading && !this.huaweiLoading)
          .onClick(() => {
            this.onInviteEmailRegister();
          })

          AgreementConsentRow({
            agreed: this.agreedToTerms,
            centered: true,
            onAgreedChange: (agreed: boolean) => {
              this.agreedToTerms = agreed;
            }
          })
          .margin({ top: 12 })
        }
        .width('100%')
        .padding({ left: 32, right: 32, top: 24, bottom: 24 })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      if (this.isLoginSkipHidden()) {
        Text('有疑问？联系客服')
          .fontSize(14)
          .fontColor(AppTheme.colors.textMuted)
          .padding({ top: 8, bottom: 8 })
          .onClick(() => {
            void this.onContactSupport('onboarding_login');
          })
      } else {
        Text('放弃权益，去专注')
          .fontSize(14)
          .fontColor(AppTheme.colors.textMuted)
          .padding({ top: 8, bottom: 8 })
          .onClick(() => {
            this.openSkipConfirm();
          })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({
      bottom: Math.max(this.bottomInset, 8) + 16
    })
  }

  @Builder
  private buildReferralStep(): void {
    Column() {
      Scroll() {
        Column() {
          Text('有邀请码吗？')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ bottom: 8 })

          Text('填写邀请码领会员，或联系客服')
            .fontSize(15)
            .lineHeight(24)
            .fontColor(AppTheme.colors.textSecondary)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ bottom: 32 })

          Row({ space: 8 }) {
            TextInput({ placeholder: '输入邀请码', text: this.referralCode })
              .layoutWeight(1)
              .height(48)
              .fontSize(17)
              .maxLength(11)
              .textAlign(TextAlign.Center)
              .padding(0)
              .backgroundColor(Color.Transparent)
              .onChange((value: string) => {
                this.referralCode = value.slice(0, 11);
                if (this.referralStatus !== 'idle' && this.referralStatus !== 'checking') {
                  this.referralStatus = 'idle';
                }
                if (normalizeReferralCode(this.referralCode).length === 0) {
                  this.referralStatus = 'idle';
                  clearPendingReferralCode();
                }
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
          .constraintSize({ minHeight: 48 })
          .padding({ left: 8, right: 8, bottom: 6 })
          .border({
            width: { bottom: 1 },
            color: this.referralStatus === 'invalid' ? AppTheme.colors.danger :
              (this.referralStatus === 'valid' ? AppTheme.colors.success : AppTheme.colors.border)
          })

          if (this.referralStatus === 'invalid') {
            Text('邀请码无效，请重试或者跳过')
              .fontSize(12)
              .fontColor(AppTheme.colors.danger)
              .lineHeight(18)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8 })
          }

          Button('验证')
            .width('100%')
            .height(52)
            .type(ButtonType.Normal)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .backgroundColor(
              !this.referralHasInput() || this.referralStatus === 'checking' ?
                'rgba(122, 90, 248, 0.22)' : AppTheme.colors.primary)
            .fontColor(
              !this.referralHasInput() || this.referralStatus === 'checking' ?
                AppTheme.colors.primaryMutedForeground : Color.White)
            .borderRadius(AppTheme.radius.button)
            .margin({ top: 16 })
            .enabled(this.referralHasInput() && this.referralStatus !== 'checking')
            .onClick(() => {
              void this.onReferralVerify();
            })

          Text('没有邀请码？参与调研可领取会员权益')
            .fontSize(14)
            .lineHeight(20)
            .fontColor(AppTheme.colors.textSecondary)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 56, bottom: 16 })

          Button() {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.headphones'))
                .fontSize(22)
                .fontColor([Color.Black])
              Text('联系客服领会员')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.Black)
            }
          }
          .width('100%')
          .height(52)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .backgroundColor(Color.White)
          .borderRadius(AppTheme.radius.button)
          .onClick(() => {
            void this.onContactSupport('onboarding_referral');
          })

          Text('跳过，下一步')
            .fontSize(14)
            .fontColor(AppTheme.colors.textMuted)
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ top: 16, bottom: 8 })
            .onClick(() => {
              this.continueFromReferral(true);
            })
        }
        .width('100%')
        .padding({ left: 32, right: 32, top: 24, bottom: 24 })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({
      bottom: Math.max(this.bottomInset, 8) + 16
    })
  }

  @Builder
  private buildSkipConfirmModal(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.45)')
        .onClick(() => {
          AnalyticsService.trackEvent('onboarding_skip_modal_dismissed', {
            'action': 'close',
            'entry_source': 'onboarding_signup_benefit',
          });
          this.showSkipConfirm = false;
        })

      Column() {
        Row() {
          Blank()
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([AppTheme.colors.textMuted])
            .onClick(() => {
              this.showSkipConfirm = false;
            })
        }
        .width('100%')
        .padding({ bottom: 4 })

        Column() {
          Row() {
            SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
              .fontSize(26)
              .fontColor([AppTheme.colors.warning])
          }
          .width(56)
          .height(56)
          .justifyContent(FlexAlign.Center)
          .borderRadius(28)
          .backgroundColor('#F5F7FB')
          .margin({ bottom: 18 })

          Text('暂不领取新用户权益？')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)
            .textAlign(TextAlign.Center)
            .lineHeight(28)
            .width('100%')
            .margin({ bottom: 10 })

          Text('暂时不想登录的话，可以先体验 5 分钟专注锁机。完成后再登录，权益仍可领取。')
            .fontSize(15)
            .fontColor(AppTheme.colors.textSecondary)
            .lineHeight(22)
            .textAlign(TextAlign.Center)
            .width('100%')

          Text('中途撕毁契约即放弃新用户权益，不可再领。')
            .fontSize(13)
            .fontColor(AppTheme.colors.warning)
            .lineHeight(19)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 10 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 4, right: 4, bottom: 32 })

        Row({ space: 12 }) {
          Button('继续领取')
            .layoutWeight(1)
            .height(50)
            .type(ButtonType.Normal)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor(AppTheme.colors.primary)
            .borderRadius(30)
            .onClick(() => {
              AnalyticsService.trackEvent('onboarding_skip_modal_dismissed', {
                'action': 'continue_claim',
                'entry_source': 'onboarding_signup_benefit',
              });
              this.showSkipConfirm = false;
            })
          Button('先去专注')
            .layoutWeight(1)
            .height(50)
            .type(ButtonType.Normal)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .backgroundColor('#F5F7FB')
            .borderRadius(30)
            .onClick(() => {
              this.confirmSkipMembership();
            })
        }
        .width('100%')
      }
      .width('88%')
      .constraintSize({ maxWidth: 360, minHeight: 320 })
      .padding({
        left: 24,
        right: 24,
        top: 16,
        bottom: 26
      })
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(28)
      .onClick(() => {})
    }
    .width('100%')
    .height('100%')
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
          .visibility(this.isScreenTimeRequired() ? Visibility.Visible : Visibility.None)

        Text('建议开启健康使用设备权限，专注体验更完整。也可稍后再授权。')
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .lineHeight(24)
          .textAlign(TextAlign.Center)
          .width('100%')
          .margin({ top: 8, bottom: 20 })
          .visibility(this.isScreenTimeRequired() ? Visibility.None : Visibility.Visible)

        this.buildPermissionStepItem()
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 32, right: 32, top: 8 })

      Column({ space: 8 }) {
        if (this.screenTimeOk) {
          Button(this.getPermissionFinishLabel())
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

          Button(this.getPermissionFinishLabel())
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
        } else if (!this.isScreenTimeRequired()) {
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

          Button(this.getPermissionFinishLabel())
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
    if (this.permOnly) {
      this.buildPermissionStep()
    } else if (this.step === 1) {
      this.buildIdentityStep()
    } else if (this.step === 2) {
      this.buildGoalStep()
    } else if (this.isPlanStep()) {
      OnboardingPlanReveal({
        identity: this.identity,
        goal: this.goal,
        onComplete: () => {
          this.onPlanComplete();
        },
      })
    } else if (this.isPartnerStep()) {
      this.buildPartnerStep()
    } else if (this.isInviteStep()) {
      this.buildInviteStep()
    } else if (this.isReferralStep()) {
      this.buildReferralStep()
    } else if (this.isPermissionStep()) {
      this.buildPermissionStep()
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      PageBackgroundDecoration()
      Column() {
        this.buildTopBar()
        this.buildCurrentStep()
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.topInset })
      .backgroundColor('#00000000')

      if (this.showSkipConfirm) {
        this.buildSkipConfirmModal()
      }
    }
    .width('100%')
    .height('100%')
  }
}

function replaceToHome(): void {
  returnToMainTab('focus');
}

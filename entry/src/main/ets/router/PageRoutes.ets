import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { LegalUrls } from '../constants/LegalUrls';
import { StoreKeys } from '../stores/StoreKeys';
import { bootstrapStores } from '../stores/StoreBootstrap';

bootstrapStores();

export type MainTabKey = 'focus' | 'plans' | 'stats' | 'profile';

export class PageRoutes {
  static readonly FocusHome: string = 'pages/tabs/MainTabPage';
  static readonly QuickStart: string = 'pages/quickStart/QuickStartPage';
  static readonly DuoCreate: string = 'pages/focus/DuoCreatePage';
  static readonly DuoWait: string = 'pages/focus/DuoWaitPage';
  static readonly DuoJoin: string = 'pages/focus/DuoJoinPage';
  static readonly DuoMatch: string = 'pages/focus/DuoMatchPage';
  static readonly Welcome: string = 'pages/onboarding/WelcomePage';
  static readonly Onboarding: string = 'pages/onboarding/OnboardingPage';
  static readonly PlanList: string = 'pages/plans/PlanListPage';
  static readonly PlanAdd: string = 'pages/plans/PlanAddPage';
  static readonly PlanDetail: string = 'pages/plans/PlanDetailPage';
  static readonly StatsDetail: string = 'pages/stats/StatsDetailPage';
  static readonly CertificatePreview: string = 'pages/certificate/CertificatePreviewPage';
  static readonly Settings: string = 'pages/settings/SettingsPage';
  static readonly Permission: string = 'pages/settings/PermissionPage';
  static readonly CycleGuard: string = 'pages/settings/CycleGuardPage';
  static readonly CycleGuardEdit: string = 'pages/settings/CycleGuardPage';
  static readonly PrivacyPolicy: string = 'pages/settings/PrivacyPolicyPage';
  static readonly UserAgreement: string = 'pages/settings/UserAgreementPage';
  static readonly WebView: string = 'pages/settings/WebViewPage';
  static readonly About: string = 'pages/settings/AboutPage';
  static readonly Feedback: string = 'pages/settings/FeedbackPage';
  static readonly Login: string = 'pages/login/LoginPage';
  static readonly EmailLogin: string = 'pages/login/EmailLoginPage';
  static readonly Register: string = 'pages/login/RegisterPage';
  static readonly WechatBindEmail: string = 'pages/login/WechatBindEmailPage';
  static readonly WechatBind: string = 'pages/login/WechatBindPage';
  static readonly Redeem: string = 'pages/user/RedeemPage';
  static readonly InviteRecord: string = 'pages/user/InviteRecordPage';
  static readonly ProfileEdit: string = 'pages/user/ProfileEditPage';
  static readonly AvatarCrop: string = 'pages/user/AvatarCropPage';
  static readonly OrgList: string = 'pages/org/OrgListPage';
  static readonly OrgJoin: string = 'pages/org/OrgJoinPage';
  static readonly OrgDetail: string = 'pages/org/OrgDetailPage';
  static readonly OrgMembers: string = 'pages/org/OrgMembersPage';
  static readonly OrgManage: string = 'pages/org/OrgManagePage';
}

function logRouteError(actionName: string, error: BusinessError): void {
  console.error(`${actionName} failed. Code=${error.code}, message=${error.message}`);
}

export function pushRoute(url: string): void {
  router.pushUrl({ url }).catch((error: BusinessError) => {
    logRouteError('pushRoute', error);
  });
}

/** 普通登录入口：清掉欢迎页老用户标记，避免误进补画像 */
export function pushLogin(): void {
  AppStorage.setOrCreate(StoreKeys.LoginFrom, '');
  pushRoute(PageRoutes.Login);
}

export function pushOrgDetail(orgId: string): void {
  AppStorage.setOrCreate(StoreKeys.OrgDetailId, orgId);
  pushRoute(PageRoutes.OrgDetail);
}

export function pushOrgMembers(orgId: string): void {
  AppStorage.setOrCreate(StoreKeys.OrgDetailId, orgId);
  pushRoute(PageRoutes.OrgMembers);
}

export function pushAvatarCrop(uri: string): void {
  router.pushUrl({
    url: PageRoutes.AvatarCrop,
    params: {
      uri: uri
    }
  }).catch((error: BusinessError) => {
    logRouteError('pushAvatarCrop', error);
  });
}

export function pushWebView(url: string, title: string): void {
  router.pushUrl({
    url: PageRoutes.WebView,
    params: {
      url: url,
      title: title
    }
  }).catch((error: BusinessError) => {
    logRouteError('pushWebView', error);
  });
}

export function pushPrivacyPolicy(): void {
  pushWebView(LegalUrls.PRIVACY, '隐私政策');
}

export function pushUserAgreement(): void {
  pushWebView(LegalUrls.USER_AGREEMENT, '用户协议');
}

export function replaceRoute(url: string): void {
  router.replaceUrl({ url }).catch((error: BusinessError) => {
    logRouteError('replaceRoute', error);
  });
}

export function backRoute(): void {
  router.back();
}

/** 已在主 Tab 内时，仅切换底部 Tab（如「我的」页内入口） */
export function openMainTab(tab: MainTabKey = 'focus'): void {
  AppStorage.setOrCreate(StoreKeys.MainTabTarget, tab);
}

/**
 * 从二级页回到主 Tab，避免 replace 再叠一层 MainTabPage。
 * 栈里已有主页时用 back 回到该实例；否则 replace 兜底。
 */
export function returnToMainTab(tab: MainTabKey = 'focus'): void {
  openMainTab(tab);
  const stackLength = Number(router.getLength());
  if (stackLength > 1) {
    router.back({ url: PageRoutes.FocusHome });
    return;
  }
  replaceRoute(PageRoutes.FocusHome);
}

/** 从二级页返回主 Tab，并打开指定 Tab */
export function navigateToMainTab(tab: MainTabKey = 'plans'): void {
  returnToMainTab(tab);
}

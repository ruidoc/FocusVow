import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
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
  static readonly PlanList: string = 'pages/plans/PlanListPage';
  static readonly PlanAdd: string = 'pages/plans/PlanAddPage';
  static readonly PlanDetail: string = 'pages/plans/PlanDetailPage';
  static readonly StatsDetail: string = 'pages/stats/StatsDetailPage';
  static readonly Settings: string = 'pages/settings/SettingsPage';
  static readonly Permission: string = 'pages/settings/PermissionPage';
  static readonly CycleGuard: string = 'pages/settings/CycleGuardPage';
  static readonly CycleGuardEdit: string = 'pages/settings/CycleGuardPage';
  static readonly PrivacyPolicy: string = 'pages/settings/PrivacyPolicyPage';
  static readonly UserAgreement: string = 'pages/settings/UserAgreementPage';
  static readonly About: string = 'pages/settings/AboutPage';
  static readonly Login: string = 'pages/login/LoginPage';
  static readonly Register: string = 'pages/login/RegisterPage';
}

function logRouteError(actionName: string, error: BusinessError): void {
  console.error(`${actionName} failed. Code=${error.code}, message=${error.message}`);
}

export function pushRoute(url: string): void {
  router.pushUrl({ url }).catch((error: BusinessError) => {
    logRouteError('pushRoute', error);
  });
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
export function openMainTab(tab: MainTabKey = 'plans'): void {
  AppStorage.setOrCreate(StoreKeys.MainTabTarget, tab);
}

/** 从二级页返回主 Tab，并打开指定 Tab */
export function navigateToMainTab(tab: MainTabKey = 'plans'): void {
  openMainTab(tab);
  replaceRoute(PageRoutes.FocusHome);
}

import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

export class PageRoutes {
  static readonly FocusHome: string = 'pages/tabs/MainTabPage';
  static readonly QuickStart: string = 'pages/quickStart/QuickStartPage';
  static readonly PlanList: string = 'pages/plans/PlanListPage';
  static readonly PlanAdd: string = 'pages/plans/PlanAddPage';
  static readonly PlanDetail: string = 'pages/plans/PlanDetailPage';
  static readonly Settings: string = 'pages/settings/SettingsPage';
  static readonly Permission: string = 'pages/settings/PermissionPage';
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

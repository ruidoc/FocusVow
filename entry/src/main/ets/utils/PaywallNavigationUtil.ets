import { router } from '@kit.ArkUI';
import { BenefitStore } from '../stores/BenefitStore';
import { FeatureFlagStore } from '../stores/FeatureFlagStore';
import { StoreKeys } from '../stores/StoreKeys';

export const PRO_UNLOCK_TITLE: string = '解锁 Pro 后继续';

export const PRO_UNLOCK_DEFAULT_SUBTITLE: string =
  '解锁全部专注能力，订阅可随时在系统设置中取消';

export interface OpenVipPurchaseOptions {
  proUnlock?: boolean;
  /** onboarding 权限完成后展示，关闭后进首页 */
  afterOnboarding?: boolean;
  /** 快付首行，同 RN subtitle */
  reason?: string;
  /** 快付首行备选，同 RN title */
  title?: string;
  /** 快付次行整句，同 RN line2 */
  line2?: string;
}

export function isMemberActive(): boolean {
  return BenefitStore.isMemberActive();
}

/** @returns true 可继续；false 已拦截并跳转 Paywall */
export function ensureProMembership(
  entrySource: string,
  options?: OpenVipPurchaseOptions,
): boolean {
  if (isMemberActive()) {
    return true;
  }
  openVipPurchase(entrySource, options);
  return false;
}

export function openVipPurchase(entrySource: string, options?: OpenVipPurchaseOptions): void {
  if (options?.proUnlock === true) {
    AppStorage.setOrCreate(StoreKeys.ProQuickPaySource, entrySource);
    AppStorage.setOrCreate(StoreKeys.ProQuickPayReason, options.reason?.trim() ?? '');
    AppStorage.setOrCreate(StoreKeys.ProQuickPayTitle, options.title?.trim() ?? '');
    AppStorage.setOrCreate(StoreKeys.ProQuickPayLine2, options.line2?.trim() ?? '');
    AppStorage.setOrCreate(StoreKeys.ProQuickPayVisible, true);
    return;
  }
  const params: Record<string, Object> = {
    'entry_source': entrySource,
  };
  if (options?.afterOnboarding === true) {
    params['after_onboarding'] = '1';
  }
  const reason = options?.reason?.trim() ?? '';
  if (reason.length > 0) {
    params['pro_unlock_reason'] = reason;
  }
  router.pushUrl({
    url: FeatureFlagStore.getVipPurchaseRoute(),
    params: params,
  }).catch((error: Error) => {
    console.warn(`[PaywallNav] openVipPurchase failed: ${String(error)}`);
  });
}

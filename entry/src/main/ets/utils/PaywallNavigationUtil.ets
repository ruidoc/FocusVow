import { router } from '@kit.ArkUI';
import { BenefitStore } from '../stores/BenefitStore';
import { FeatureFlagStore } from '../stores/FeatureFlagStore';

export const PRO_UNLOCK_TITLE: string = '解锁 Pro 后继续';

export const PRO_UNLOCK_DEFAULT_SUBTITLE: string =
  '解锁全部专注能力，订阅可随时在系统设置中取消';

export interface OpenVipPurchaseOptions {
  proUnlock?: boolean;
  reason?: string;
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
  const params: Record<string, Object> = {
    'entry_source': entrySource,
  };
  if (options?.proUnlock === true) {
    params['pro_unlock'] = '1';
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

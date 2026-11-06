import { VipProduct, SubscriptionSnapshot } from '../services/SubscriptionApiService';

export const QUICK_PAY_DEFAULT_PERIOD: number = 2;

export function localMidnightEndsAt(now: number = Date.now()): number {
  const end = new Date(now);
  end.setHours(24, 0, 0, 0);
  return end.getTime();
}

export function isWechatCouponActive(endsAt: number | null | undefined, now: number = Date.now()): boolean {
  return typeof endsAt === 'number' && Number.isFinite(endsAt) && endsAt > now;
}

export function isProductCouponDeal(product: VipProduct | null | undefined, now: number = Date.now()): boolean {
  if (!product || (product.coupon_delta_fen ?? 0) <= 0) {
    return false;
  }
  const endsAt = product.coupon_ends_at;
  if (endsAt === null || endsAt === undefined) {
    return true;
  }
  return isWechatCouponActive(endsAt, now);
}

export function displayCouponEndsAt(product: VipProduct | null | undefined, now: number = Date.now()): number | null {
  if (!isProductCouponDeal(product, now)) {
    return null;
  }
  const endsAt = product?.coupon_ends_at;
  if (typeof endsAt === 'number' && Number.isFinite(endsAt)) {
    return endsAt;
  }
  return localMidnightEndsAt(now);
}

function holdBimonthlyUntilMonthDeal(catalog: VipProduct[], now: number): boolean {
  for (let i = 0; i < catalog.length; i++) {
    if (catalog[i].month_deal_active === true) {
      return false;
    }
  }
  for (let j = 0; j < catalog.length; j++) {
    if (catalog[j].month_deal_active === false) {
      return true;
    }
  }
  const month = catalog.find(p => p.period === 1);
  return !isProductCouponDeal(month, now);
}

/** 对齐 RN resolveQuickPayProduct（鸿蒙无 AB 实验，默认主推双月） */
export function resolveQuickPayProduct(
  catalog: VipProduct[],
  now: number = Date.now(),
): VipProduct | null {
  if (catalog.length === 0) {
    return null;
  }
  let bimonthly: VipProduct | null = null;
  for (let i = 0; i < catalog.length; i++) {
    if (catalog[i].period === QUICK_PAY_DEFAULT_PERIOD) {
      bimonthly = catalog[i];
      break;
    }
  }
  if (holdBimonthlyUntilMonthDeal(catalog, now) && bimonthly) {
    return bimonthly;
  }
  if (bimonthly) {
    return bimonthly;
  }
  return catalog[0];
}

export function planPromoEndsAt(
  product: VipProduct | null | undefined,
  catalog: VipProduct[],
  now: number = Date.now(),
): number | null {
  if (!product) {
    return null;
  }
  const featured = resolveQuickPayProduct(catalog, now);
  if (!featured || featured.product_id !== product.product_id) {
    return null;
  }
  const real = displayCouponEndsAt(product, now);
  if (real) {
    return real;
  }
  if (product.period === 2) {
    return localMidnightEndsAt(now);
  }
  let monthDealOn = false;
  for (let i = 0; i < catalog.length; i++) {
    if (catalog[i].month_deal_active === true) {
      monthDealOn = true;
      break;
    }
  }
  if (product.period === 1 && monthDealOn) {
    return localMidnightEndsAt(now);
  }
  return null;
}

export function formatPromoCountdown(endsAtMs: number, now: number = Date.now()): string {
  const left = Math.max(0, endsAtMs - now);
  const totalSec = Math.floor(left / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  const pad = (v: number): string => (v < 10 ? `0${v}` : `${v}`);
  if (h > 0) {
    return `${pad(h)}:${pad(m)}:${pad(s)}`;
  }
  return `${pad(m)}:${pad(s)}`;
}

export function quickPayPeriodLabel(period: number): string {
  if (period >= 12) {
    return '年度';
  }
  if (period === 3) {
    return '季度';
  }
  if (period === 2) {
    return '双月';
  }
  if (period === 7) {
    return '周度';
  }
  return '月度';
}

export function quickPayBadgeLabel(period: number): string {
  return `${quickPayPeriodLabel(period)} Pro`;
}

export function quickPayCtaLabel(period: number): string {
  return `升级${quickPayPeriodLabel(period)}Pro`;
}

export function withFeaturedFirst(list: VipProduct[], now: number = Date.now()): VipProduct[] {
  const featured = resolveQuickPayProduct(list, now);
  if (!featured) {
    return list;
  }
  const rest: VipProduct[] = [];
  for (let i = 0; i < list.length; i++) {
    if (list[i].product_id !== featured.product_id) {
      rest.push(list[i]);
    }
  }
  return [featured, ...rest];
}

export function isMembershipTrial(subscription: SubscriptionSnapshot | null): boolean {
  if (!subscription) {
    return false;
  }
  if (subscription.membership_kind === 'free_trial') {
    return true;
  }
  return subscription.source === 'signup_trial';
}

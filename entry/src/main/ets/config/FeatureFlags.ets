/** 与 RN feature-flags.ts 约定一致 */
export class FeatureFlagKeys {
  static readonly PRO_CARD: string = 'pro_card';
  static readonly WECHAT_LOGIN: string = 'wechat_login';
  /** 在 features_off 中则隐藏开通会员（走兑换页） */
  static readonly PROMO_VIP: string = 'promo_vip';
}

/** Android / 鸿蒙微信支付会员商品 */
export const PROMO_VIP_PRODUCT_IDS: string[] = [
  'com.focusone.vip_month_399',
  'com.focusone.vip_2month_699',
];

export function isPromoVipProductId(productId: string): boolean {
  return PROMO_VIP_PRODUCT_IDS.includes(productId);
}

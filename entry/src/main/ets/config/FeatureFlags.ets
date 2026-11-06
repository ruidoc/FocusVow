/** 与 RN feature-flags.ts 约定一致 */
export class FeatureFlagKeys {
  static readonly PRO_CARD: string = 'pro_card';
  static readonly WECHAT_LOGIN: string = 'wechat_login';
  /** 在 features_off 中则隐藏开通会员（走兑换页） */
  static readonly PROMO_VIP: string = 'promo_vip';
  /** Onboarding 搭子步骤；在 features_off 黑名单中则隐藏 */
  static readonly PARTNER: string = 'partner';
  /** 在 features_off 黑名单中则允许跳过悬浮窗 */
  static readonly SKIP_OVERLAY: string = 'skip_overlay';
  /** Onboarding 注册领会员页「放弃权益，去专注」；在 features_off 中则隐藏 */
  static readonly OB_LOGIN_SKIP: string = 'ob_login_skip';
  /** 快付弹窗「邀请好友」入口；在 features_off 中则隐藏 */
  static readonly QUICK_PAY_INVITE: string = 'quick_pay_invite';
}

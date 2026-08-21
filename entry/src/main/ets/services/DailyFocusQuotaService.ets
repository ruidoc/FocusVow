import { showErrorToast } from "../common/Toast";
import { pushRoute } from "../router/PageRoutes";
import { BenefitStore } from "../stores/BenefitStore";
import { FeatureFlagStore } from "../stores/FeatureFlagStore";
import { UserStore } from "../stores/UserStore";

/** 免费用户今日总专注时长是否已用完（会员不限制） */
export function isDailyFocusQuotaExhausted(): boolean {
  if (!UserStore.isLoggedIn()) {
    return false;
  }
  const benefit = BenefitStore.getState();
  if (benefit.isSubscribed || benefit.membershipStatus === "active") {
    return false;
  }
  if (benefit.dayDuration <= 0) {
    return false;
  }
  return benefit.todayUsed >= benefit.dayDuration;
}

/** 今日剩余免费分钟；会员 / 未登录 / 未下发额度 → 足够大 */
export function getDailyFocusRemainingMinutes(): number {
  if (!UserStore.isLoggedIn()) {
    return 999999;
  }
  const benefit = BenefitStore.getState();
  if (benefit.isSubscribed || benefit.membershipStatus === "active") {
    return 999999;
  }
  if (benefit.dayDuration <= 0) {
    return 999999;
  }
  return Math.max(0, benefit.dayDuration - benefit.todayUsed);
}

/**
 * 开始专注 / 发起互督前校验每日免费时长（对齐 RN ensureDailyFocusQuota）。
 * 会先刷新 /benefit，避免「我的」页外 dayDuration 仍为 0 导致不拦截。
 * @param requiredMinutes 本次计划分钟（倒计时）；>0 时若剩余不足也会拦截
 * @returns true 可继续；false 已拦截并引导兑换
 */
export async function ensureDailyFocusQuota(
  uiContext?: UIContext,
  requiredMinutes: number = 0,
): Promise<boolean> {
  if (UserStore.isLoggedIn()) {
    try {
      await BenefitStore.refresh();
    } catch (_e) {
      // 刷新失败时仍用本地缓存判断
    }
  }

  if (isDailyFocusQuotaExhausted()) {
    showErrorToast("今日专注时长已用完", uiContext);
    pushRoute(FeatureFlagStore.getVipPurchaseRoute());
    return false;
  }

  if (requiredMinutes > 0) {
    const remaining = getDailyFocusRemainingMinutes();
    if (remaining < 999999 && remaining < requiredMinutes) {
      showErrorToast(
        `今日剩余免费专注时长不足（剩 ${remaining} 分钟），兑换会员可无限专注`,
        uiContext,
      );
      pushRoute(FeatureFlagStore.getVipPurchaseRoute());
      return false;
    }
  }

  return true;
}

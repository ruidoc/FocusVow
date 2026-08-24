import { common } from "@kit.AbilityKit";
import { AppContextHolder } from "../common/AppContextHolder";
import { ActiveLockState } from "../models/ActiveLockModel";
import { AppTheme } from "../constants/Theme";
import { PageRoutes, pushRoute } from "../router/PageRoutes";
import { StoreKeys } from "../stores/StoreKeys";
import { UserStore } from "../stores/UserStore";
import { isMembershipReclaimEligible } from "../utils/OnboardingMembershipUtil";
import { AnalyticsService } from "./AnalyticsService";
import { readStoredString, writeStoredString } from "../services/PreferencesService";
import { buildOnboardingAnalyticsProps } from "../utils/OnboardingMetaUtil";

const GUEST_SOLO_FOCUS_USED_KEY: string = "guest_solo_focus_used";

/** 证书弹窗关闭后再引导登录 */
let pendingLoginPromptAfterCert: boolean = false;
let loginPromptReadyAt: number = 0;

export function isSoloQuickFocusLock(lock: ActiveLockState): boolean {
  return (
    lock.kind === "quick_focus" &&
    lock.duoSessionId.length === 0 &&
    lock.participationMode !== "duo"
  );
}

export function hasUsedGuestSoloFocus(context?: common.Context): boolean {
  const host = context ?? AppContextHolder.get();
  if (!host) {
    return false;
  }
  return readStoredString(host, GUEST_SOLO_FOCUS_USED_KEY, "") === "1";
}

export function markGuestSoloFocusUsed(context?: common.Context): void {
  const host = context ?? AppContextHolder.get();
  if (!host) {
    return;
  }
  writeStoredString(host, GUEST_SOLO_FOCUS_USED_KEY, "1");
}

/** 未登录且已用过首次额度时，不可再开单人专注 */
export function mustLoginForSoloFocus(context?: common.Context): boolean {
  if (UserStore.isLoggedIn()) {
    return false;
  }
  return hasUsedGuestSoloFocus(context);
}

/**
 * 开始单人专注前校验。
 * @returns true 可继续；false 已跳转登录
 */
export function ensureSoloFocusAccess(context?: common.Context): boolean {
  if (!mustLoginForSoloFocus(context)) {
    return true;
  }
  pushRoute(PageRoutes.Login);
  return false;
}

export function showGuestSoloLoginPrompt(uiContext: UIContext): void {
  if (UserStore.isLoggedIn()) {
    return;
  }
  uiContext.showAlertDialog({
    title: "登录后查看统计",
    message: "本次专注已保存在本地。登录后会自动同步记录，即可查看时长与履约证明。",
    autoCancel: true,
    primaryButton: {
      value: "去登录",
      fontColor: AppTheme.colors.primary,
      action: () => {
        AppStorage.setOrCreate(StoreKeys.LoginFrom, "guest_solo_ended");
        pushRoute(PageRoutes.Login);
      },
    },
    secondaryButton: {
      value: "稍后再说",
      action: () => {
        AnalyticsService.trackEvent('guest_focus_login_deferred', buildOnboardingAnalyticsProps({
          'prompt_type': 'stats_dialog',
          'has_pending': true,
        }));
      },
    },
  });
}

/**
 * 未登录单人结束后：标记额度并引导登录。
 * 锁结束会重建首页，延迟弹出，避免弹窗被冲掉。
 */
export function afterGuestSoloFocusEnded(
  uiContext: UIContext,
  lock: ActiveLockState,
  context: common.Context | undefined,
  willShowCertificate: boolean,
): void {
  if (!isSoloQuickFocusLock(lock)) {
    return;
  }
  if (UserStore.isLoggedIn()) {
    return;
  }
  const host = context ?? AppContextHolder.get();
  if (!host) {
    return;
  }
  markGuestSoloFocusUsed(host);
  if (isMembershipReclaimEligible(host)) {
    pendingLoginPromptAfterCert = false;
    AppStorage.setOrCreate(StoreKeys.ShowGuestMembershipReclaim, true);
    AnalyticsService.trackEvent('onboarding_guest_focus_done', buildOnboardingAnalyticsProps({
      'guest_path': true,
      'api_synced': false,
      'onboarding_path': 'focus_first',
    }));
    return;
  }
  pendingLoginPromptAfterCert = true;
  loginPromptReadyAt = Date.now() + 200;
  if (willShowCertificate) {
    return;
  }
  setTimeout(() => {
    onCertificateGuideDismissed(uiContext);
  }, 240);
}

/** 证书弹窗关闭后，或首页空闲时补弹登录引导 */
export function onCertificateGuideDismissed(uiContext: UIContext): void {
  if (!pendingLoginPromptAfterCert || UserStore.isLoggedIn()) {
    pendingLoginPromptAfterCert = false;
    return;
  }
  if (Date.now() < loginPromptReadyAt) {
    return;
  }
  pendingLoginPromptAfterCert = false;
  showGuestSoloLoginPrompt(uiContext);
}

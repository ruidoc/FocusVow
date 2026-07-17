import { common } from "@kit.AbilityKit";
import { AppContextHolder } from "../common/AppContextHolder";
import { ActiveLockState } from "../models/ActiveLockModel";
import { AppTheme } from "../constants/Theme";
import { PageRoutes, pushRoute } from "../router/PageRoutes";
import { UserStore } from "../stores/UserStore";
import { readStoredString, writeStoredString } from "./PreferencesService";

const GUEST_SOLO_FOCUS_USED_KEY: string = "guest_solo_focus_used";

/** 证书弹窗关闭后再引导登录 */
let pendingLoginPromptAfterCert: boolean = false;

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
    message: "未登录时本次专注不会产生统计数据。登录后可同步记录、查看时长与履约证明。",
    autoCancel: true,
    primaryButton: {
      value: "去登录",
      fontColor: AppTheme.colors.primary,
      action: () => {
        pushRoute(PageRoutes.Login);
      },
    },
    secondaryButton: {
      value: "稍后再说",
      action: () => {
        // no-op
      },
    },
  });
}

/**
 * 未登录单人结束后调用：标记额度并立刻弹登录引导。
 * 游客结束不弹证书，调用方应传 willShowCertificate=false。
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
  markGuestSoloFocusUsed(context);
  if (willShowCertificate) {
    pendingLoginPromptAfterCert = true;
    return;
  }
  showGuestSoloLoginPrompt(uiContext);
}

/** 证书弹窗 primary/secondary 关闭后调用 */
export function onCertificateGuideDismissed(uiContext: UIContext): void {
  if (!pendingLoginPromptAfterCert) {
    return;
  }
  pendingLoginPromptAfterCert = false;
  showGuestSoloLoginPrompt(uiContext);
}

import { common } from "@kit.AbilityKit";
import { window } from "@kit.ArkUI";
import {
  ActiveLockState,
  createIdleLockState,
  normalizeActiveLockState,
} from "../../models/ActiveLockModel";
import { MainTabKey } from "../../router/PageRoutes";
import { endQuickFocus } from "../../services/ActiveLockLifecycleService";
import {
  queueHonorCertificate,
  tryPresentCertificateGuide,
  getPendingCertificate,
} from "../../services/CertificatePendingService";
import { DuoInviteClipboardService } from "../../services/DuoInviteClipboardService";
import { FocusSyncService } from "../../services/FocusSyncService";
import {
  afterGuestSoloFocusEnded,
  onCertificateGuideDismissed,
} from "../../services/GuestSoloFocusService";
import { warmUpPreferencesStore } from "../../services/PreferencesService";
import { reconcileLockLifecycle } from "../../services/LockReconcileService";
import { CycleGuardStore } from "../../stores/CycleGuardStore";
import { LockStore } from "../../stores/LockStore";
import { PlanStore } from "../../stores/PlanStore";
import { SettingsStore } from "../../stores/SettingsStore";
import { bootstrapStores } from "../../stores/StoreBootstrap";
import { StoreKeys } from "../../stores/StoreKeys";
import { UserStore } from "../../stores/UserStore";
import { InAppMessageBanner } from "../../components/common/InAppMessageBanner";
import { MainTabImmersiveLayout } from "./MainTabImmersiveLayout";
import { MainTabLegacyLayout } from "./MainTabLegacyLayout";
import { shouldHideMainTabBar, supportsImmersiveTab } from "./MainTabUtil";

bootstrapStores();

@Entry
@Component
struct MainTabPage {
  @State currentTab: MainTabKey = "focus";
  @State private bottomGestureInsetVp: number = 0;
  @State private useImmersiveTab: boolean = false;
  @StorageLink(StoreKeys.LockActiveState)
  @Watch("onActiveLockChanged")
  activeLock: ActiveLockState = createIdleLockState();
  @StorageLink(StoreKeys.AppForegroundAt) foregroundAt: number = 0;
  @StorageLink(StoreKeys.MainTabTarget) @Watch("onMainTabTargetChanged") pendingTab: string = "";

  private timerId: number = -1;
  private isEndingLock: boolean = false;
  private lastClipboardProbeAt: number = 0;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const ui = this.getUIContext();
    this.useImmersiveTab = supportsImmersiveTab();
    AppStorage.setOrCreate(StoreKeys.MainTabFloatingBar, false);
    warmUpPreferencesStore(hostContext);
    UserStore.hydrate(hostContext);
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
    void UserStore.syncRemoteIfLoggedIn(hostContext);
    if (UserStore.isLoggedIn()) {
      void FocusSyncService.flushPending(hostContext);
      void UserStore.syncGuardsOnLogin(hostContext);
    }
    this.startTimer();
    void this.probeClipboardInvite(hostContext);
    this.consumePendingTab();

    window.getLastWindow(hostContext, (err, win) => {
      if (err !== undefined && err.code !== 0) {
        return;
      }
      const navAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.bottomGestureInsetVp = ui.px2vp(navAvoid.bottomRect.height);
    });
  }

  aboutToDisappear(): void {
    this.clearTimer();
    AppStorage.set(StoreKeys.MainTabFloatingBar, false);
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private startTimer(): void {
    this.clearTimer();
    this.timerId = setInterval(() => {
      this.syncLockLifecycle();
    }, 1000);
  }

  private onMainTabTargetChanged(): void {
    this.consumePendingTab();
  }

  private consumePendingTab(): void {
    if (
      this.pendingTab === "focus" ||
      this.pendingTab === "plans" ||
      this.pendingTab === "stats" ||
      this.pendingTab === "profile"
    ) {
      this.currentTab = this.pendingTab;
      this.pendingTab = "";
    }
  }

  private async probeClipboardInvite(context: common.UIAbilityContext): Promise<void> {
    await DuoInviteClipboardService.probeClipboard(context, this.getUIContext());
  }

  private maybeProbeClipboardOnForeground(context: common.UIAbilityContext): void {
    if (this.foregroundAt <= this.lastClipboardProbeAt) {
      return;
    }
    this.lastClipboardProbeAt = this.foregroundAt;
    void this.probeClipboardInvite(context);
  }

  private syncLockLifecycle(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.maybeProbeClipboardOnForeground(hostContext);
    warmUpPreferencesStore(hostContext);
    SettingsStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
    void reconcileLockLifecycle(hostContext);
    tryPresentCertificateGuide(this.getUIContext());
    // 证书弹窗展示中仍占着 pending；关闭/回首页后再引导登录
    if (!getPendingCertificate()) {
      onCertificateGuideDismissed(this.getUIContext());
    }

    if (this.activeLock.kind === "quick_focus" && LockStore.shouldAutoFinish()) {
      void this.finishQuickFocus();
    }
  }

  private async finishQuickFocus(): Promise<void> {
    if (this.activeLock.kind !== "quick_focus" || this.isEndingLock) {
      return;
    }

    this.isEndingLock = true;
    const lockSnapshot = normalizeActiveLockState(this.activeLock);
    const endedAt = Date.now();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const ok = await endQuickFocus(
      hostContext,
      lockSnapshot,
      "契约已履行",
      "专注已结束，但解除限制失败",
    );
    if (ok && UserStore.isLoggedIn()) {
      // 已登录：弹荣誉证；游客单人只走登录引导
      queueHonorCertificate(lockSnapshot, endedAt);
      tryPresentCertificateGuide(this.getUIContext());
    } else {
      afterGuestSoloFocusEnded(this.getUIContext(), lockSnapshot, hostContext, false);
    }
    this.isEndingLock = false;
  }

  private handleTabChange(tab: MainTabKey): void {
    if (shouldHideMainTabBar(this.activeLock) && tab !== "focus") {
      return;
    }
    this.currentTab = tab;
  }

  private onActiveLockChanged(): void {
    if (shouldHideMainTabBar(this.activeLock) && this.currentTab !== "focus") {
      this.currentTab = "focus";
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.useImmersiveTab) {
        MainTabImmersiveLayout({
          currentTab: this.currentTab,
          bottomGestureInsetVp: this.bottomGestureInsetVp,
          hideTabBar: shouldHideMainTabBar(this.activeLock),
          onTabChange: (tab: MainTabKey) => {
            this.handleTabChange(tab);
          },
        });
      } else {
        MainTabLegacyLayout({
          currentTab: this.currentTab,
          bottomGestureInsetVp: this.bottomGestureInsetVp,
          hideTabBar: shouldHideMainTabBar(this.activeLock),
          onTabChange: (tab: MainTabKey) => {
            this.handleTabChange(tab);
          },
        });
      }
      InAppMessageBanner()
    }
    .width("100%")
    .height("100%");
  }
}

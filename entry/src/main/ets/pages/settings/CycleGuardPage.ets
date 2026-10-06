import { common } from "@kit.AbilityKit";
import { showErrorToast, showToast } from "../../common/Toast";
import { AppActionButton } from "../../components/common/AppActionButton";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { FocusDurationCard } from "../../components/focus/FocusDurationCard";
import { AppTheme } from "../../constants/Theme";
import { CycleGuardPhase } from "../../models/CycleGuardModel";
import { backRoute } from "../../router/PageRoutes";
import {
  chooseRestrictedApps,
  requestScreenTimeAuthorization,
} from "../../services/ScreenTimeService";
import { CycleGuardStore } from "../../stores/CycleGuardStore";
import { SettingsStore } from "../../stores/SettingsStore";
import { bootstrapStores } from "../../stores/StoreBootstrap";
import { StoreKeys } from "../../stores/StoreKeys";

bootstrapStores();

@Entry
@Component
struct CycleGuardPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.CycleGuardSelectedTokens) selectedTokens: string[] = [];
  @StorageLink(StoreKeys.CycleGuardSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.CycleGuardQuotaMinutes) storedQuotaMinutes: number = 60;
  @StorageLink(StoreKeys.CycleGuardLockMinutes) storedLockMinutes: number = 25;
  @StorageLink(StoreKeys.CycleGuardEnabled) cycleEnabled: boolean = false;
  @StorageLink(StoreKeys.CycleGuardConfigured) cycleConfigured: boolean = false;
  @StorageLink(StoreKeys.CycleGuardPhase) phase: string = "idle";
  @State private draftQuotaMinutes: number = 60;
  @State private draftLockMinutes: number = 25;
  @State private isSaving: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
    this.syncDraftValues();
  }

  private syncDraftValues(): void {
    this.draftQuotaMinutes = this.storedQuotaMinutes;
    this.draftLockMinutes = this.storedLockMinutes;
  }

  private normalizeMinutes(raw: number): number {
    let next = Math.max(5, Math.min(180, Math.floor(raw)));
    next = Math.round(next / 5) * 5;
    return Math.max(5, Math.min(180, next));
  }

  private async ensureAuthorized(): Promise<boolean> {
    if (this.hasAuthorized) {
      return true;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await requestScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, result.ok, result.message);
    return result.ok;
  }

  private async chooseApps(): Promise<void> {
    if (!(await this.ensureAuthorized())) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    if (result.data) {
      CycleGuardStore.updateSelectedTokens(hostContext, result.data, result.message);
    }
  }

  private async saveDraft(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    if (this.cycleEnabled) {
      showToast("请先关闭短视频限额开关后再编辑", this.getUIContext());
      return;
    }
    if (this.selectedAppCount === 0) {
      showToast("请先选择娱乐应用", this.getUIContext());
      return;
    }
    if (!(await this.ensureAuthorized())) {
      return;
    }
    this.isSaving = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    CycleGuardStore.updateQuotaMinutes(hostContext, this.draftQuotaMinutes);
    CycleGuardStore.updateLockMinutes(hostContext, this.draftLockMinutes);
    CycleGuardStore.markConfigured(hostContext);
    CycleGuardStore.updateRuntimeState(
      hostContext,
      false,
      this.phase as CycleGuardPhase,
      "配置已保存",
    );
    this.isSaving = false;
    showToast("配置已保存", this.getUIContext());
    backRoute();
  }

  @Builder
  private buildAppsCard(): void {
    Column({ space: 12 }) {
      Row() {
        Text("要限制的娱乐应用")
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
        Text("+ 选择")
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.primary)
          .onClick(() => {
            void this.chooseApps();
          })
      }
      .width("100%")
      .alignItems(VerticalAlign.Center)
      Text(
        this.selectedAppCount > 0 ? `已选 ${this.selectedAppCount} 个娱乐应用` : "未选择娱乐应用",
      )
        .fontSize(14)
        .fontColor(
          this.selectedAppCount > 0 ? AppTheme.colors.textSecondary : AppTheme.colors.textMuted,
        )
        .width("100%")
    }
    .width("100%")
    .padding(16)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildBody(): void {
    Column({ space: 16 }) {
      Text("选择娱乐应用并设置总时长。用满后自动锁定，结束锁定后额度归零继续累计。")
        .fontSize(13)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textSecondary)
        .width("100%")

      this.buildAppsCard()
      FocusDurationCard({
        title: '娱乐总时长',
        durationMinutes: this.draftQuotaMinutes,
        onDurationChange: (value: number) => {
          this.draftQuotaMinutes = this.normalizeMinutes(value);
        },
      })
      FocusDurationCard({
        title: '锁定最短时长',
        durationMinutes: this.draftLockMinutes,
        onDurationChange: (value: number) => {
          this.draftLockMinutes = this.normalizeMinutes(value);
        },
      })

      AppActionButton({
        label: this.cycleConfigured ? '保存' : '添加',
        isEnabled: !this.isSaving && !this.cycleEnabled,
        onPress: () => {
          void this.saveDraft();
        },
      })
    }
    .width("100%")
    .padding({ left: 16, right: 16 })
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.cycleConfigured ? "编辑短视频限额" : "添加短视频限额",
        showBack: true,
        usePageScroll: true,
        horizontalPadding: 0,
        useFloatingTabInset: false,
        bottomSpacerHeight: 24,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildBody();
        },
      })
    }
    .width("100%")
    .height("100%");
  }
}

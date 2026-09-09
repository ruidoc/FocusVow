import { common } from "@kit.AbilityKit";
import { showErrorToast } from "../../common/Toast";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { FocusDurationCard } from "../../components/focus/FocusDurationCard";
import { TimerModeSegmented } from "../../components/focus/TimerModeSegmented";
import { AppTheme } from "../../constants/Theme";
import { PageRoutes, backRoute, pushRoute, replaceRoute } from "../../router/PageRoutes";
import {
  chooseRestrictedApps,
} from "../../services/ScreenTimeService";
import { ensureTaskPermission } from "../../utils/TaskPermissionUtil";
import { DuoApiService } from "../../services/DuoApiService";
import { DuoInviteClipboardService } from "../../services/DuoInviteClipboardService";
import { setInstantDuoWait } from "../../services/DuoWaitContextService";
import { SettingsStore } from "../../stores/SettingsStore";
import { UserStore } from "../../stores/UserStore";
import { BenefitStore } from "../../stores/BenefitStore";
import { bootstrapStores } from "../../stores/StoreBootstrap";
import { StoreKeys } from "../../stores/StoreKeys";
import { TimerMode } from "../../utils/TimerMode";

bootstrapStores();

@Entry
@Component
struct DuoCreatePage {
  @StorageLink(StoreKeys.SettingsSelectedTokens) selectedTokens: string[] = [];
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @State title: string = "";
  @State durationMinutes: number = 45;
  @State timerMode: TimerMode = "countdown";
  @State isSubmitting: boolean = false;

  private readonly durationMin: number = 5;
  private readonly durationMax: number = 180;
  private readonly durationStep: number = 5;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    BenefitStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }
    void BenefitStore.refresh();
  }

  private normalizeDuration(raw: number): number {
    let d = Math.max(this.durationMin, Math.min(this.durationMax, Math.floor(raw)));
    d = Math.round(d / this.durationStep) * this.durationStep;
    return Math.max(this.durationMin, Math.min(this.durationMax, d));
  }

  private toastError(message: string): void {
    showErrorToast(message, this.getUIContext());
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!(await ensureTaskPermission(hostContext, this.getUIContext(), {
      entry_source: 'duo_create',
      screen_name: 'duo_create',
    }))) {
      return;
    }
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    if (result.data) {
      SettingsStore.updateSelectedTokens(hostContext, result.data, result.message);
      return;
    }
    this.toastError(result.message);
  }

  private async createInvite(): Promise<void> {
    if (this.isSubmitting) {
      return;
    }
    if (this.title.trim().length === 0) {
      this.toastError("请先填写本次契约要做什么");
      return;
    }

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!(await ensureTaskPermission(hostContext, this.getUIContext(), {
      entry_source: 'duo_create',
      screen_name: 'duo_create',
    }))) {
      return;
    }

    this.isSubmitting = true;
    const response = await DuoApiService.instantCreate(
      this.title.trim(),
      this.durationMinutes,
      this.timerMode,
    );
    const session = DuoApiService.parseSession(response);
    if (!session) {
      this.toastError(response.message ?? "创建失败");
      this.isSubmitting = false;
      return;
    }

    setInstantDuoWait(session, this.title.trim(), this.durationMinutes);
    if (session.token.length > 0) {
      DuoInviteClipboardService.dismissToken(session.token);
    }
    this.isSubmitting = false;
    replaceRoute(PageRoutes.DuoWait);
  }

  @Builder
  private buildAppCard(): void {
    Column({ space: 14 }) {
      Row() {
        Text("允许使用的应用")
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

      if (this.selectedAppCount === 0) {
        Text("未选择应用").fontSize(15).fontColor(AppTheme.colors.textMuted).width("100%");
      } else {
        Text(`已选 ${this.selectedAppCount} 个应用`)
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%");
      }
    }
    .width("100%")
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg);
  }

  @Builder
  private buildPageBody(): void {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text("邀请搭子一起开始；一人撕毁，两人失败。")
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%")
      }
      .width("100%")
      .alignItems(HorizontalAlign.Start)
      Row() {
        Blank()
        TimerModeSegmented({
          value: this.timerMode,
          onChange: (mode: TimerMode) => {
            this.timerMode = mode;
          },
        })
        Blank()
      }.width("100%")
      TextInput({ text: this.title, placeholder: "今天要完成什么？" })
        .width("100%")
        .height(44)
        .enterKeyType(EnterKeyType.Done)
        .onChange((value: string) => {
          this.title = value;
        })
        .onSubmit(() => {
          focusControl.requestFocus("");
        })

      this.buildAppCard()
      FocusDurationCard({
        timerMode: this.timerMode,
        durationMinutes: this.durationMinutes,
        onDurationChange: (value: number) => {
          this.durationMinutes = this.normalizeDuration(value);
        },
      })
      Button("生成口令")
        .width("100%")
        .height(52)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .borderRadius(AppTheme.radius.button)
        .clip(true)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor("#FFFFFF")
        .enabled(!this.isSubmitting)
        .opacity(this.isSubmitting ? 0.55 : 1)
        .onClick(() => {
          void this.createInvite();
        })
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Stack() {
      SystemNavPage({
        title: "发起互督",
        showBack: true,
        usePageScroll: true,
        bottomSpacerHeight: 28,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildPageBody();
        },
      })
    }
    .width("100%")
    .height("100%");
  }
}

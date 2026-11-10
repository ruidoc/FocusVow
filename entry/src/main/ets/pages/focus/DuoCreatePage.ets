import { common } from "@kit.AbilityKit";
import { showErrorToast, showToast } from "../../common/Toast";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { FocusDurationCard } from "../../components/focus/FocusDurationCard";
import { TimerModeSegmented } from "../../components/focus/TimerModeSegmented";
import { AppTheme } from "../../constants/Theme";
import { QuickTaskUpsertPayload } from "../../models/QuickTaskModel";
import {
  PageRoutes,
  backRoute,
  openDuoTaskTabOnce,
  pushDuoPickFriend,
  pushRoute,
  replaceRoute,
} from "../../router/PageRoutes";
import { ALLOW_APP_SELECTION_LIMIT, chooseRestrictedApps, rejectOverAppSelection } from "../../services/ScreenTimeService";
import { ensureTaskPermission } from "../../utils/TaskPermissionUtil";
import { DuoApiService } from "../../services/DuoApiService";
import { QuickTaskApiService } from "../../services/QuickTaskApiService";
import { DuoInviteClipboardService } from "../../services/DuoInviteClipboardService";
import { takeDuoPartnerPick } from "../../services/DuoPartnerPickService";
import { setInstantDuoWait } from "../../services/DuoWaitContextService";
import {
  getPendingRemainSeconds,
  hasPendingQuickStart,
} from "../../services/PendingQuickStartService";
import { promptSlotUpsellIfDisabled, upsellIfProSlotQuota } from "../../services/ProQuotaService";
import { SettingsStore } from "../../stores/SettingsStore";
import { UserStore } from "../../stores/UserStore";
import { BenefitStore } from "../../stores/BenefitStore";
import { QuickTaskStore } from "../../stores/QuickTaskStore";
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
  @State targetId: string = "";
  @State targetName: string = "";
  @State saveToDuoTask: boolean = false;

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

  onPageShow(): void {
    const picked = takeDuoPartnerPick();
    if (!picked) {
      return;
    }
    this.targetId = picked.target.trim();
    this.targetName = picked.name.trim();
    if (this.targetId.length === 0) {
      this.saveToDuoTask = false;
    }
  }

  private submitLabel(): string {
    if (this.saveToDuoTask && this.targetId.length > 0) {
      return this.isSubmitting ? "保存中..." : "保存到互督任务";
    }
    if (this.targetName.length > 0) {
      return `邀请 ${this.targetName}`;
    }
    return "生成口令";
  }

  private async saveDuoTask(): Promise<void> {
    if (this.targetId.length === 0) {
      this.isSubmitting = false;
      return;
    }
    if (QuickTaskStore.isDirty()) {
      await QuickTaskStore.loadAll();
    }
    if (QuickTaskStore.duoTitleExists(this.title.trim())) {
      this.toastError("已有同名快捷任务，请修改名称");
      this.isSubmitting = false;
      return;
    }
    const payload: QuickTaskUpsertPayload = {
      title: this.title.trim(),
      duration_min: this.durationMinutes,
      timer_mode: this.timerMode,
      mode: "allow",
      delay_min: 0,
      no_stop: false,
      apps: [...this.selectedTokens],
      partner_user_id: this.targetId,
      partner_nickname: this.targetName,
    };
    try {
      const response = await QuickTaskStore.createTask(payload);
      if (response.statusCode !== 200) {
        const errMsg =
          typeof response.message === "string" && response.message.length > 0
            ? response.message
            : "保存快捷任务失败";
        if (!upsellIfProSlotQuota(errMsg, "duo")) {
          this.toastError(errMsg);
        }
        this.isSubmitting = false;
        return;
      }
      const created = QuickTaskApiService.parseTask(response);
      promptSlotUpsellIfDisabled(created ? created.enabled : undefined, "duo");
      showToast("已保存到互督任务", this.getUIContext());
      this.isSubmitting = false;
      openDuoTaskTabOnce();
    } catch (_error) {
      this.toastError("保存快捷任务失败");
      this.isSubmitting = false;
    }
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
    if (
      !(await ensureTaskPermission(hostContext, this.getUIContext(), {
        entry_source: "duo_create",
        screen_name: "duo_create",
      }))
    ) {
      return;
    }
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    if (result.data) {
      if (rejectOverAppSelection(result.data.length, ALLOW_APP_SELECTION_LIMIT, this.getUIContext())) {
        return;
      }
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

    this.isSubmitting = true;
    if (this.saveToDuoTask && this.targetId.length > 0) {
      await this.saveDuoTask();
      return;
    }

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (hasPendingQuickStart(hostContext) && getPendingRemainSeconds(hostContext) <= 20 * 60) {
      this.toastError("已有即将开始的预约专注");
      this.isSubmitting = false;
      return;
    }
    if (
      !(await ensureTaskPermission(hostContext, this.getUIContext(), {
        entry_source: "duo_create",
        screen_name: "duo_create",
      }))
    ) {
      this.isSubmitting = false;
      return;
    }

    const response =
      this.targetId.length > 0
        ? await DuoApiService.inviteFriend(
            this.targetId,
            this.title.trim(),
            this.durationMinutes,
            this.timerMode,
          )
        : await DuoApiService.instantCreate(
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
      Row() {
        Row({ space: 6 }) {
          Text("互督搭子")
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
          Text("新")
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor("#FFFFFF")
            .lineHeight(14)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .backgroundColor("#FF3B30")
            .borderRadius(4)
        }
        .alignItems(VerticalAlign.Center)
        .layoutWeight(1)
        Text(this.targetName.length > 0 ? this.targetName : "口令邀请")
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 160 })
        SymbolGlyph($r("sys.symbol.chevron_right"))
          .fontSize(16)
          .fontColor([AppTheme.colors.textMuted])
          .margin({ left: 4 })
      }
      .width("100%")
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(AppTheme.radius.lg)
      .onClick(() => {
        pushDuoPickFriend(this.targetId);
      })

      if (this.targetId.length > 0) {
        Row({ space: 8 }) {
          Checkbox()
            .select(this.saveToDuoTask)
            .selectedColor(AppTheme.colors.primary)
            .onChange((checked: boolean) => {
              this.saveToDuoTask = checked;
            })
          Text("保存到互督任务，下次一键开启专注")
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
            .layoutWeight(1)
        }
        .width("100%")
        .alignItems(VerticalAlign.Center);
      }
      Button(this.submitLabel())
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

import { common } from "@kit.AbilityKit";
import { showErrorToast, showToast } from "../../common/Toast";
import { copyDuoInviteText, shareDuoInviteText } from "../../services/DuoInviteShareService";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { AppTheme } from "../../constants/Theme";
import {
  DuoSessionView,
  isDuoWaitPartnerJoined,
} from "../../models/DuoModel";
import { backRoute, navigateToMainTab, returnToMainTab } from "../../router/PageRoutes";
import { DuoApiService } from "../../services/DuoApiService";
import {
  DuoInstantLockOptions,
  startOrAlignInstantDuoFocus,
} from "../../services/DuoInstantLockService";
import { clearDuoWaitContext } from "../../services/DuoWaitContextService";
import { bootstrapStores } from "../../stores/StoreBootstrap";
import { ScheduledListStore } from "../../stores/ScheduledListStore";
import { StoreKeys } from "../../stores/StoreKeys";

bootstrapStores();

@Entry
@Component
struct DuoWaitPage {
  @StorageLink(StoreKeys.SettingsSelectedTokens) selectedTokens: string[] = [];
  @State session: DuoSessionView | null = null;
  @State inviteText: string = "";
  @State remainSeconds: number = 600;
  @State isStarting: boolean = false;
  @State partnerReady: boolean = false;

  private sessionId: string = "";
  private isScheduled: boolean = false;
  private scheduleLabel: string = "";
  private timerId: number = -1;
  private pollId: number = -1;

  aboutToAppear(): void {
    this.sessionId = String(AppStorage.get<string>(StoreKeys.DuoWaitSessionId) ?? "");
    this.inviteText = String(AppStorage.get<string>(StoreKeys.DuoWaitInviteText) ?? "");
    this.isScheduled = AppStorage.get<boolean>(StoreKeys.DuoWaitIsScheduled) === true;
    this.scheduleLabel = String(AppStorage.get<string>(StoreKeys.DuoWaitScheduleLabel) ?? "");
    if (this.sessionId.length === 0) {
      backRoute();
      return;
    }
    void this.refreshSession();
    this.startTimers();
  }

  aboutToDisappear(): void {
    this.clearTimers();
  }

  private clearTimers(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.pollId !== -1) {
      clearInterval(this.pollId);
      this.pollId = -1;
    }
  }

  private startTimers(): void {
    this.clearTimers();
    // 定时 / 即时均轮询 session：搭子加入后推送可能不到达，需靠轮询兜底开锁并回首页
    this.pollId = setInterval(() => {
      void this.refreshSession();
    }, 3000);
    if (this.isScheduled) {
      return;
    }

    this.timerId = setInterval(() => {
      if (this.remainSeconds > 0) {
        this.remainSeconds -= 1;
      }
    }, 1000);
  }

  private toastError(message: string): void {
    showErrorToast(message, this.getUIContext());
  }

  private remainLabel(): string {
    const minutes = Math.floor(this.remainSeconds / 60);
    const seconds = (this.remainSeconds % 60).toString().padStart(2, "0");
    return `${minutes}:${seconds}`;
  }

  private getSessionTitle(): string {
    return (
      this.session?.title ?? String(AppStorage.get<string>(StoreKeys.DuoWaitTitle) ?? "搭子互督")
    );
  }

  private getSessionDurationLabel(): string {
    if (this.isScheduled && this.scheduleLabel.length > 0) {
      return this.scheduleLabel;
    }

    const durationMin = Number(
      AppStorage.get<number>(StoreKeys.DuoWaitDurationMin) ?? this.session?.duration_min ?? 0,
    );
    if (durationMin >= 60) {
      const h = Math.floor(durationMin / 60);
      const m = durationMin % 60;
      return m === 0 ? `${h} 小时` : `${h} 小时 ${m} 分钟`;
    }
    return `${durationMin} 分钟`;
  }

  private getInitiatorName(): string {
    return this.session?.initiator?.nickname ?? "我";
  }

  private getPartnerName(): string {
    return this.session?.partner?.nickname ?? "等待搭子";
  }

  private getHeaderTitle(): string {
    if (this.isScheduled) {
      return this.partnerReady ? "搭子已就位" : "等待搭子加入";
    }
    return "等待搭子加入";
  }

  private getHeaderValue(): string {
    if (this.isScheduled) {
      return this.scheduleLabel.length > 0 ? this.scheduleLabel : "定时履约";
    }
    return this.remainLabel();
  }

  private getHintText(): string {
    if (this.isScheduled) {
      return this.partnerReady
        ? "契约已保存，到点将按定时计划自动履约。"
        : "把下方口令发给搭子，对方加入后将在定时时段一起履约。";
    }
    return "把下方口令发给搭子，对方加入后双方将同时开始锁机。";
  }

  private getPartnerStatus(): string {
    if (this.session?.partner) {
      return this.isScheduled ? "已加入，等待定时开始" : "已加入，准备开始";
    }
    return "等待加入";
  }

  private exitToPlansOrFocus(): void {
    if (this.isScheduled) {
      navigateToMainTab("plans");
      return;
    }
    returnToMainTab("focus");
  }

  private async refreshSession(): Promise<void> {
    const response = await DuoApiService.getSession(this.sessionId);
    const next = DuoApiService.parseSession(response);
    if (!next) {
      if (response.statusCode === 400 && (response.message ?? "").includes("过期")) {
        this.toastError("邀请已过期");
        this.clearTimers();
        clearDuoWaitContext();
        this.exitToPlansOrFocus();
      }
      return;
    }

    this.session = next;
    if (next.invite_text && next.invite_text.length > 0) {
      this.inviteText = next.invite_text;
      AppStorage.setOrCreate(StoreKeys.DuoWaitInviteText, next.invite_text);
    }
    if (!this.isScheduled && next.expire_at) {
      const remain = Math.max(
        0,
        Math.floor((new Date(next.expire_at).getTime() - Date.now()) / 1000),
      );
      this.remainSeconds = remain;
    }

    if (next.status === "expired" || next.status === "cancelled") {
      this.clearTimers();
      clearDuoWaitContext();
      this.toastError(next.status === "cancelled" ? "已取消邀请" : "邀请已过期");
      this.exitToPlansOrFocus();
      return;
    }

    if (this.isScheduled) {
      const wasReady = this.partnerReady;
      this.partnerReady = isDuoWaitPartnerJoined(next, true);
      if (!wasReady && this.partnerReady) {
        ScheduledListStore.markDirty();
        clearDuoWaitContext();
      }
      return;
    }

    if (next.status === "active" && next.type !== "scheduled") {
      await this.startLocalFocus(next);
    }
  }

  private async startLocalFocus(session: DuoSessionView): Promise<void> {
    if (this.isStarting) {
      return;
    }
    this.isStarting = true;
    this.clearTimers();

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const title = String(AppStorage.get<string>(StoreKeys.DuoWaitTitle) ?? session.title);
    const lockOptions: DuoInstantLockOptions = {
      title,
      navigateHome: true,
      clearWait: true,
      alignToServerEnd: true,
    };
    const result = await startOrAlignInstantDuoFocus(
      hostContext,
      session,
      this.selectedTokens,
      lockOptions,
    );
    if (!result.ok && !result.alreadyLocked) {
      const tip = result.message === "no_selected_tokens"
        ? "请先选择要限制的应用"
        : (result.message === "session_already_ended"
          ? "契约已结束"
          : (result.message.length > 0 ? result.message : "开启锁机失败"));
      this.toastError(tip);
      this.isStarting = false;
      return;
    }
    // 成功或已锁：确保离开等待页（navigateHome 可能在 alreadyLocked 路径遗漏）
    returnToMainTab("focus");
  }

  private async copyInvite(): Promise<void> {
    if (this.inviteText.length === 0) {
      return;
    }
    await copyDuoInviteText(this.getUIContext(), this.inviteText);
  }

  private async shareInvite(): Promise<void> {
    if (this.inviteText.length === 0) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await shareDuoInviteText(hostContext, this.getUIContext(), this.inviteText);
  }

  private async cancelInvite(): Promise<void> {
    if (this.isScheduled) {
      await DuoApiService.scheduledCancel(this.sessionId);
    } else {
      await DuoApiService.cancelSession(this.sessionId);
    }
    this.clearTimers();
    clearDuoWaitContext();
    this.exitToPlansOrFocus();
  }

  private confirmCancelInvite(): void {
    this.getUIContext().showAlertDialog({
      title: this.isScheduled ? "取消契约" : "取消邀请",
      message: this.isScheduled
        ? "取消后这条定时契约将被作废，确认取消吗？"
        : "取消后邀请口令将失效，确认取消吗？",
      autoCancel: true,
      primaryButton: {
        value: "确认取消",
        fontColor: AppTheme.colors.danger,
        action: () => {
          void this.cancelInvite();
        },
      },
      secondaryButton: {
        value: "暂不取消",
        action: () => {},
      },
    });
  }

  private finishScheduledInvite(): void {
    this.clearTimers();
    clearDuoWaitContext();
    navigateToMainTab("plans");
  }

  @Builder
  private buildParticipantRow(name: string, status: string, active: boolean): void {
    Row({ space: 10 }) {
      Text(name.substring(0, 1))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(active ? AppTheme.colors.primary : AppTheme.colors.textMuted)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor(active ? AppTheme.colors.primarySoft : AppTheme.colors.surfaceRaised)
        .borderRadius(18)
      Column({ space: 2 }) {
        Text(name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .width("100%")
        Text(status)
          .fontSize(12)
          .fontColor(active ? AppTheme.colors.success : AppTheme.colors.textMuted)
          .width("100%")
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width("100%")
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private buildRitualCard(): void {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Text(this.getSessionTitle())
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width("100%")
          .textAlign(TextAlign.Center)
        Text(`${this.getSessionDurationLabel()} · 一人撕毁，两人失败`)
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%")
          .textAlign(TextAlign.Center)
      }.width("100%")
      Column({ space: 12 }) {
        this.buildParticipantRow(this.getInitiatorName(), "已发起契约", true)
        this.buildParticipantRow(
          this.getPartnerName(),
          this.getPartnerStatus(),
          this.session?.partner !== null && this.session?.partner !== undefined,
        )
      }.width("100%")
    }
    .width("100%")
    .padding(20)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg);
  }

  @Builder
  private buildInviteCard(): void {
    Column({ space: 12 }) {
      Text("邀请口令")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width("100%")
      Text(this.inviteText.length > 0 ? this.inviteText : "正在生成口令…")
        .fontSize(14)
        .lineHeight(22)
        .fontColor(AppTheme.colors.textSecondary)
        .width("100%")
    }
    .width("100%")
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg);
  }

  @Builder
  private buildPageBody(): void {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text(this.getHeaderValue())
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width("100%")
          .textAlign(TextAlign.Center)
        Text(this.getHeaderTitle())
          .fontSize(16)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%")
          .textAlign(TextAlign.Center)
      }.width("100%")
      Text(this.getHintText())
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .width("100%")

      this.buildRitualCard()
      this.buildInviteCard()

      if (!this.partnerReady) {
        Row({ space: 12 }) {
          Button("发给搭子")
            .layoutWeight(2)
            .height(52)
            .type(ButtonType.Capsule)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(AppTheme.colors.primary)
            .fontColor("#FFFFFF")
            .onClick(() => {
              void this.shareInvite();
            })
          Button("复制口令")
            .layoutWeight(1)
            .height(52)
            .type(ButtonType.Capsule)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(AppTheme.colors.primarySoft)
            .fontColor(AppTheme.colors.primary)
            .onClick(() => {
              void this.copyInvite();
            })
        }.width("100%");
      } else {
        Button("返回计划")
          .width("100%")
          .height(52)
          .type(ButtonType.Capsule)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(AppTheme.colors.primary)
          .fontColor("#FFFFFF")
          .onClick(() => {
            this.finishScheduledInvite();
          });
      }
      Button(this.isScheduled ? "取消契约" : "取消邀请")
        .width("100%")
        .height(52)
        .type(ButtonType.Capsule)
        .backgroundColor(AppTheme.colors.surface)
        .fontColor(AppTheme.colors.textPrimary)
        .border({ width: 1, color: AppTheme.colors.border })
        .onClick(() => {
          this.confirmCancelInvite();
        })
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.isScheduled ? "邀请搭子" : "等待搭子",
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

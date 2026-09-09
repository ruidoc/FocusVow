import { common } from "@kit.AbilityKit";
import { createEmptyUserInfo, UserInfo } from "../../models/UserModel";
import {
  FocusPlan,
  findNextUpcomingPlanToday,
  getPlanSecondsUntilStart,
} from "../../models/PlanModel";
import { PageRoutes, openScheduledTaskTabOnce, pushRoute } from "../../router/PageRoutes";
import { DuoApiService } from "../../services/DuoApiService";
import { homeTodayMetricsBg } from "../../constants/HomeCardStyle";
import { HomeGlassSurface } from "./HomeGlassSurface";
import { StoreKeys } from "../../stores/StoreKeys";
import { UserStore } from "../../stores/UserStore";

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 6) {
    return "早上好";
  }
  if (hour < 12) {
    return "上午好";
  }
  if (hour < 18) {
    return "下午好";
  }
  return "晚上好";
}

function formatSuccessRate(raw: number | string): string {
  const text = String(raw ?? "");
  if (text.includes("%")) {
    return text;
  }
  const n = Number(raw);
  if (!Number.isFinite(n)) {
    return "0%";
  }
  return `${Math.round(n)}%`;
}

function formatNextPlanCountdown(totalSeconds: number): string {
  const minutes = Math.max(0, Math.ceil(totalSeconds / 60));
  if (minutes < 60) {
    return `${minutes}m`;
  }
  const hours = Math.floor(totalSeconds / 3600);
  const remainMinutes = Math.floor((totalSeconds % 3600) / 60);
  if (remainMinutes === 0) {
    return `${hours}h`;
  }
  return `${hours}h ${remainMinutes}m`;
}
@Component
export struct HomeTodayCard {
  @StorageLink(StoreKeys.UserInfo) userInfo: UserInfo = createEmptyUserInfo();
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = "light";
  @Prop @Watch("onRefreshTickChanged") refreshTick: number = 0;
  @State actualMins: number = 0;
  @State taskCount: number = 0;
  @State failCount: number = 0;
  @State successRateLabel: string = "0%";
  @State nextPlanName: string = "";
  @State nextPlanSecondsLeft: number = 0;
  @State showNextPlan: boolean = false;
  private timerId: number = -1;
  private cardTick: number = 0;

  aboutToAppear(): void {
    void this.loadTodayStats();
    this.refreshNextPlan();
    this.startTimer();
  }

  aboutToDisappear(): void {
    this.clearTimer();
  }

  private onRefreshTickChanged(): void {
    void this.loadTodayStats();
    this.refreshNextPlan();
  }

  private startTimer(): void {
    this.clearTimer();
    this.timerId = setInterval(() => {
      this.cardTick += 1;
      this.refreshNextPlan();
    }, 1000);
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private getHostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async loadTodayStats(): Promise<void> {
    if (!UserStore.isLoggedIn()) {
      this.actualMins = 0;
      this.taskCount = 0;
      this.failCount = 0;
      this.successRateLabel = "0%";
      return;
    }
    const response = await DuoApiService.getStatsSummary("today");
    const summary = DuoApiService.parseSummary(response);
    if (!summary) {
      return;
    }
    this.actualMins = summary.actual_mins ?? 0;
    this.taskCount = summary.completed_count ?? 0;
    this.failCount = summary.failed_count ?? 0;
    this.successRateLabel = formatSuccessRate(summary.success_rate ?? 0);
  }

  private refreshNextPlan(): void {
    const _tick = this.cardTick;
    const nextPlan = findNextUpcomingPlanToday(this.planCollection);
    if (!nextPlan) {
      this.showNextPlan = false;
      this.nextPlanName = "";
      this.nextPlanSecondsLeft = 0;
      return;
    }
    const secondsLeft = getPlanSecondsUntilStart(nextPlan);
    if (secondsLeft <= 0) {
      this.showNextPlan = false;
      this.nextPlanName = "";
      this.nextPlanSecondsLeft = 0;
      return;
    }
    this.showNextPlan = true;
    this.nextPlanName = nextPlan.name.trim().length > 0 ? nextPlan.name.trim() : "定时契约";
    this.nextPlanSecondsLeft = secondsLeft;
  }

  private onNextPlanPress(): void {
    const nextPlan = findNextUpcomingPlanToday(this.planCollection);
    if (!nextPlan) {
      return;
    }
    const sessionId = nextPlan.duoSessionId?.trim() ?? "";
    if (sessionId.length > 0) {
      AppStorage.setOrCreate(StoreKeys.ScheduledSessionCurrentId, sessionId);
      pushRoute(PageRoutes.PlanDetail);
      return;
    }
    openScheduledTaskTabOnce();
  }


  private getDisplayName(): string {
    const name = this.userInfo.username.trim();
    return name.length > 0 ? name : "朋友";
  }

  private getTodayFocusMins(): number {
    return Math.max(0, Math.floor(this.actualMins));
  }

  private getTodayCardGradientStart(): string {
    return this.themeMode === "dark" ? "#7B68D8" : "#B39FFB";
  }

  private getTodayCardGradientEnd(): string {
    return this.themeMode === "dark" ? "#5C4AB8" : "#8B73ED";
  }

  @Builder
  private buildTodayMetricsRow(): void {
    Row() {
      this.buildMetricCell("专注次数", String(this.taskCount))
      this.buildMetricCell("成功率", this.successRateLabel)
      this.buildMetricCell("毁约次数", String(this.failCount))
    }
    .width("100%")
    .padding({ top: 10, bottom: 10 });
  }

  @Builder
  private buildTodayMetricsGlass(): void {
    HomeGlassSurface({
      glassBackgroundColor: homeTodayMetricsBg(),
      enableBlur: true,
      blurStyle: BlurStyle.Thin,
      useLightBlurTint: true,
      content: (): void => {
        this.buildTodayMetricsRow();
      },
    })
  }

  @Builder
  private buildFocusUnitText(label: string): void {
    Text(label)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor("rgba(255,255,255,0.96)")
      .lineHeight(16)
      .height(16)
      .padding({ top: 0, bottom: 0 });
  }

  @Builder
  private buildFocusNumberText(value: number): void {
    Text(`${value}`)
      .fontSize(34)
      .fontWeight(FontWeight.Medium)
      .fontColor("#FFFFFF")
      .lineHeight(34)
      .height(34)
      .padding({ top: 0, bottom: 0 })
      .margin({ left: 4, right: 4 })
      .translate({ y: 1 });
  }

  @Builder
  private buildTodayFocusLine(): void {
    Flex({
      direction: FlexDirection.Row,
      wrap: FlexWrap.NoWrap,
      justifyContent: FlexAlign.Start,
      alignItems: ItemAlign.Baseline,
    }) {
      Text("今日专注")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor("rgba(255,255,255,0.96)")
        .lineHeight(16)
        .height(16)
        .padding({ top: 0, bottom: 0 })
        .margin({ right: 4 })
      if (this.getTodayFocusMins() < 60) {
        this.buildFocusNumberText(this.getTodayFocusMins());
        this.buildFocusUnitText("分钟");
      } else {
        this.buildFocusNumberText(Math.floor(this.getTodayFocusMins() / 60));
        this.buildFocusUnitText("小时");
        if (this.getTodayFocusMins() % 60 > 0) {
          this.buildFocusNumberText(this.getTodayFocusMins() % 60);
          this.buildFocusUnitText("分钟");
        }
      }
    }
    .width("100%");
  }

  @Builder
  private buildMetricCell(label: string, value: string): void {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(13)
        .fontColor("rgba(255,255,255,0.78)")
        .textAlign(TextAlign.Center)
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor("rgba(255,255,255,0.96)")
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center);
  }

  build() {
    Column() {
      Stack() {
        Column()
          .width(168)
          .height(168)
          .borderRadius(84)
          .backgroundColor("rgba(255,255,255,0.18)")
          .position({ x: "72%", y: -48 })
        Column()
          .width(110)
          .height(110)
          .borderRadius(55)
          .backgroundColor("rgba(255,255,255,0.08)")
          .position({ x: -28, y: 120 })
        Column() {
          Row() {
            if (this.showNextPlan) {
              Row({ space: 6 }) {
                SymbolGlyph($r("sys.symbol.alarm"))
                  .fontSize(17)
                  .fontColor(["#FFFFFF"])
                Text(
                  `${formatNextPlanCountdown(this.nextPlanSecondsLeft)} 后开始任务 · ${this.nextPlanName}`,
                )
                  .fontSize(13)
                  .fontColor("rgba(255,255,255,0.86)")
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                SymbolGlyph($r("sys.symbol.chevron_right"))
                  .fontSize(14)
                  .fontColor(["rgba(255,255,255,0.86)"])
              }
              .layoutWeight(1)
              .onClick(() => {
                this.onNextPlanPress();
              });
            } else {
              Text(`${getGreeting()}，${this.getDisplayName()} 👋`)
                .fontSize(13)
                .fontColor("rgba(255,255,255,0.78)")
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1);
            }
          }
          .width("100%")
          .alignItems(VerticalAlign.Center)
          Column() {
            this.buildTodayFocusLine()
          }
          .width("100%")
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 12 })
          Column() {
            this.buildTodayMetricsGlass()
          }
          .width("100%")
          .height(58)
          .margin({ top: 12 })
          .borderRadius(16)
          .clip(true)
        }
        .width("100%")
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 18, right: 18, top: 18, bottom: 14 })
      }.width("100%")
    }
    .width("100%")
    .margin({ top: 12 })
    .borderRadius(22)
    .clip(true)
    .linearGradient({
      angle: 135,
      colors: [
        [this.getTodayCardGradientStart(), 0],
        [this.getTodayCardGradientEnd(), 1],
      ],
    });
  }
}

import { common } from "@kit.AbilityKit";
import { showToast } from "../../common/Toast";
import { createEmptyUserInfo, UserInfo } from "../../models/UserModel";
import {
  FocusPlan,
  findNextUpcomingPlanToday,
  getPlanSecondsUntilStart,
} from "../../models/PlanModel";
import { PageRoutes, openScheduledTaskTabOnce, pushLogin, pushRoute } from "../../router/PageRoutes";
import { isHarmonyUpdateAvailable, openHarmonyUpdate } from "../../services/AppUpdateService";
import { AnalyticsService } from "../../services/AnalyticsService";
import { CheckinPickerDialog } from "./CheckinPickerDialog";
import { homeTodayMetricsBg } from "../../constants/HomeCardStyle";
import { HomeGlassSurface } from "./HomeGlassSurface";
import { StoreKeys } from "../../stores/StoreKeys";
import { UserStore } from "../../stores/UserStore";
import {
  CheckinKind,
  isSleepCheckinOpen,
  isWakeCheckinOpen,
  sleepWindowLabel,
  wakeWindowLabel,
} from "../../utils/CheckinUtil";

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

const HOME_HEADER_ICON_SIZE: number = 25;

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
  @Prop actualMins: number = 0;
  @Prop taskCount: number = 0;
  @Prop failCount: number = 0;
  @Prop successRate: number = 0;
  @State nextPlanName: string = "";
  @State nextPlanSecondsLeft: number = 0;
  @State showNextPlan: boolean = false;
  @State updateAvailable: boolean = false;
  private timerId: number = -1;
  private cardTick: number = 0;
  private checkinDialog: CustomDialogController = new CustomDialogController({
    builder: CheckinPickerDialog({
      onSelect: (kind: string): void => {
        this.onCheckinSelected(kind);
      }
    }),
    customStyle: true,
    alignment: DialogAlignment.Center,
    autoCancel: true,
    maskColor: 'rgba(0, 0, 0, 0.4)'
  });

  aboutToAppear(): void {
    this.refreshNextPlan();
    this.startTimer();
    this.refreshAppUpdate();
  }

  private refreshAppUpdate(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    void isHarmonyUpdateAvailable(hostContext).then((available: boolean) => {
      this.updateAvailable = available;
    });
  }

  private trackHomeEntry(entryKey: string): void {
    const props: Record<string, Object> = {};
    props['entry_key'] = entryKey;
    AnalyticsService.trackEvent('home_entry_clicked', props);
  }

  aboutToDisappear(): void {
    this.clearTimer();
    this.checkinDialog.close();
  }

  private openCheckin(kind: CheckinKind, open: boolean): void {
    if (!open) {
      const windowLabel = kind === 'wake' ? wakeWindowLabel() : sleepWindowLabel();
      showToast(`开放时段 ${windowLabel}`, this.getUIContext());
      return;
    }
    if (!UserStore.isLoggedIn()) {
      showToast('请先登录', this.getUIContext());
      pushLogin();
      return;
    }
    AppStorage.setOrCreate(StoreKeys.CheckinKind, kind);
    pushRoute(PageRoutes.Checkin);
  }

  private onCheckinSelected(kind: string): void {
    if (kind === 'wake') {
      this.openCheckin('wake', isWakeCheckinOpen());
      return;
    }
    if (kind === 'sleep') {
      this.openCheckin('sleep', isSleepCheckinOpen());
      return;
    }
    if (kind === 'focus') {
      this.openCheckin('focus', true);
    }
  }

  private openCheckinPicker(): void {
    this.trackHomeEntry('checkin');
    this.checkinDialog.open();
  }

  private onAppUpdatePress(): void {
    this.trackHomeEntry('app_update');
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    void openHarmonyUpdate(hostContext);
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

  private getTodayCardGradientStart(): string {
    return this.themeMode === "dark" ? "#7B68D8" : "#B39FFB";
  }

  private getTodayCardGradientEnd(): string {
    return this.themeMode === "dark" ? "#5C4AB8" : "#8B73ED";
  }

  @Builder
  private buildMetricsGlass(): void {
    HomeGlassSurface({
      glassBackgroundColor: homeTodayMetricsBg(),
      enableBlur: true,
      blurStyle: BlurStyle.Thin,
      useLightBlurTint: true,
      content: (): void => {
        Row()
      },
    })
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
            Row({ space: 8 }) {
              Row() {
                Image($r("app.media.check_in"))
                  .width(this.updateAvailable ? HOME_HEADER_ICON_SIZE : 20)
                  .height(this.updateAvailable ? HOME_HEADER_ICON_SIZE : 20)
                if (!this.updateAvailable) {
                  Text("打卡")
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor("rgba(255,255,255,0.96)")
                    .margin({ left: 4 })
                    .letterSpacing(0.3)
                }
              }
              .padding(this.updateAvailable ? { left: 0, right: 0, top: 0, bottom: 0 } : {
                left: 8,
                right: 11,
                top: 5,
                bottom: 5
              })
              .borderRadius(this.updateAvailable ? 0 : 18)
              .backgroundColor(this.updateAvailable ? Color.Transparent : "rgba(255,255,255,0.18)")
              .border({
                width: this.updateAvailable ? 0 : 1,
                color: "rgba(255,255,255,0.32)"
              })
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                this.openCheckinPicker();
              })

              if (this.updateAvailable) {
                Image($r("app.media.upversion"))
                  .width(HOME_HEADER_ICON_SIZE)
                  .height(HOME_HEADER_ICON_SIZE)
                  .onClick(() => {
                    this.onAppUpdatePress();
                  })
              }
            }
          }
          .width("100%")
          .alignItems(VerticalAlign.Center)
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
              .margin({ right: 4 })
            Text(`${Math.max(0, Math.floor(this.actualMins))}`)
              .fontSize(34)
              .fontWeight(FontWeight.Medium)
              .fontColor("#FFFFFF")
              .margin({ left: 4, right: 4 })
            Text("分钟")
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor("rgba(255,255,255,0.96)")
          }
          .width("100%")
          .margin({ top: 12 })
          Stack({ alignContent: Alignment.Center }) {
            this.buildMetricsGlass()
            Row() {
              Column({ space: 2 }) {
                Text("专注次数")
                  .fontSize(13)
                  .fontColor("rgba(255,255,255,0.78)")
                  .textAlign(TextAlign.Center)
                Text(`${this.taskCount}`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor("rgba(255,255,255,0.96)")
                  .textAlign(TextAlign.Center)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)

              Column({ space: 2 }) {
                Text("成功率")
                  .fontSize(13)
                  .fontColor("rgba(255,255,255,0.78)")
                  .textAlign(TextAlign.Center)
                Text(`${Math.round(this.successRate)}%`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor("rgba(255,255,255,0.96)")
                  .textAlign(TextAlign.Center)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)

              Column({ space: 2 }) {
                Text("毁约次数")
                  .fontSize(13)
                  .fontColor("rgba(255,255,255,0.78)")
                  .textAlign(TextAlign.Center)
                Text(`${this.failCount}`)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor("rgba(255,255,255,0.96)")
                  .textAlign(TextAlign.Center)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)
            }
            .width("100%")
            .padding({ top: 10, bottom: 10 })
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

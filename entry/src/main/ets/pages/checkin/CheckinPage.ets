import { common } from "@kit.AbilityKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { showErrorToast, showToast } from "../../common/Toast";
import { CheckinPeekCarousel } from "../../components/checkin/CheckinPeekCarousel";
import { GallerySaveButton } from "../../components/common/GallerySaveButton";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { AppTheme } from "../../constants/Theme";
import { createEmptyUserInfo, UserInfo } from "../../models/UserModel";
import { backRoute } from "../../router/PageRoutes";
import {
  captureComponentSnapshot,
  formatSaveError,
  saveCertificateSnapshot,
} from "../../services/CertificateImageService";
import { HttpService } from "../../services/HttpService";
import {
  buildStatsShareCachePath,
  formatShareError,
  shareStatsImageFile,
  writePixelMapToFile,
} from "../../services/StatsShareService";
import { StoreKeys } from "../../stores/StoreKeys";
import { bootstrapStores } from "../../stores/StoreBootstrap";
import {
  CheckinKind,
  fallbackShareCard,
  isSleepCheckinOpen,
  isWakeCheckinOpen,
  parseShareCards,
  ShareCardItem,
  sleepWindowLabel,
  wakeWindowLabel,
} from "../../utils/CheckinUtil";

bootstrapStores();

function formatSuccessRate(raw: number | string | undefined): string {
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

@Entry
@Component
struct CheckinPage {
  @StorageLink(StoreKeys.CheckinKind) kindRaw: string = "focus";
  @StorageLink(StoreKeys.UserInfo) userInfo: UserInfo = createEmptyUserInfo();
  @State cards: ShareCardItem[] = [];
  @State index: number = 0;
  @State phase: string = "loading";
  @State submitting: boolean = false;
  @State focusMinGate: number = 30;
  @State busy: string = "";
  @State focusMinutes: number = 0;
  @State taskCount: number = 0;
  @State successRate: string = "0%";
  @State clockText: string = "";
  private clockTimer: number = -1;

  aboutToAppear(): void {
    this.tickClock();
    this.clockTimer = setInterval(() => {
      this.tickClock();
    }, 1000);
    void this.prepare();
  }

  aboutToDisappear(): void {
    if (this.clockTimer >= 0) {
      clearInterval(this.clockTimer);
      this.clockTimer = -1;
    }
  }

  private pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private tickClock(): void {
    const now = new Date();
    this.clockText = `${this.pad2(now.getHours())}:${this.pad2(now.getMinutes())}:${this.pad2(now.getSeconds())}`;
  }

  private idleHint(): string {
    const kind = this.kind();
    if (kind === "wake") {
      return `开放时段 ${wakeWindowLabel()}`;
    }
    if (kind === "sleep") {
      return `开放时段 ${sleepWindowLabel()}`;
    }
    return `今日已专注 ${Math.max(0, Math.round(this.focusMinutes))} 分钟`;
  }

  private todayKey(): string {
    const now = new Date();
    const month = now.getMonth() + 1;
    const day = now.getDate();
    const monthText = month < 10 ? `0${month}` : `${month}`;
    const dayText = day < 10 ? `0${day}` : `${day}`;
    return `${now.getFullYear()}-${monthText}-${dayText}`;
  }

  private clockLabel(): string {
    const now = new Date();
    const weeks = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"];
    return `${now.getMonth() + 1}月${now.getDate()}日 ${weeks[now.getDay()]}`;
  }

  private kind(): CheckinKind {
    if (this.kindRaw === "wake" || this.kindRaw === "sleep") {
      return this.kindRaw;
    }
    return "focus";
  }

  private currentCard(): ShareCardItem {
    if (this.cards.length === 0) {
      return fallbackShareCard(this.kind());
    }
    const i = Math.min(this.index, this.cards.length - 1);
    return this.cards[i];
  }

  private snapshotId(): string {
    return `checkinPoster_${this.currentCard().id}`;
  }

  private displayName(): string {
    const name = this.userInfo.username.trim();
    return name.length > 0 ? name : "朋友";
  }

  private canFocus(): boolean {
    return (
      this.kind() !== "focus" || Math.max(0, Math.floor(this.focusMinutes)) >= this.focusMinGate
    );
  }

  private async prepare(): Promise<void> {
    const config = await HttpService.get("/config/static", true);
    if (config.statusCode === 200 && config.data) {
      const root = config.data as Record<string, Object>;
      const checkin = root["checkin"] as Record<string, Object> | undefined;
      const minutes = Number(checkin?.["focus_min_minutes"] ?? 30);
      if (Number.isFinite(minutes) && minutes >= 1) {
        this.focusMinGate = Math.min(Math.floor(minutes), 600);
      }
    }
    const todayQuery: Record<string, string> = {};
    todayQuery["kind"] = this.kind();
    todayQuery["date"] = this.todayKey();
    const today = await HttpService.getWithQuery("/checkins/today", todayQuery, true);
    const checked =
      today.statusCode === 200 &&
      today.data &&
      (today.data as Record<string, Object>)["checked"] === true;
    if (checked) {
      await this.loadPoster();
      this.phase = "done";
      return;
    }
    const stats = await HttpService.get("/record/statis");
    if (stats.statusCode === 200 && stats.data) {
      this.focusMinutes = Number(stats.data["actual_mins"] ?? 0);
      this.taskCount = Number(stats.data["task_count"] ?? 0);
      this.successRate = formatSuccessRate(String(stats.data["success_rate"] ?? ""));
    }
    this.phase = "idle";
  }

  private async submitCheckin(): Promise<void> {
    if (this.submitting || this.phase !== "idle") {
      return;
    }
    const kind = this.kind();
    if ((kind === "wake" && !isWakeCheckinOpen()) || (kind === "sleep" && !isSleepCheckinOpen())) {
      showToast("当前不在打卡时段", this.getUIContext());
      return;
    }
    if (!this.canFocus()) {
      showToast(`专注满${this.focusMinGate}分钟后可打卡`, this.getUIContext());
      return;
    }
    this.submitting = true;
    const checkinBody: Record<string, Object> = {};
    checkinBody["kind"] = kind;
    checkinBody["date"] = this.todayKey();
    const response = await HttpService.post("/checkins", checkinBody, true);
    this.submitting = false;
    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? "打卡失败", this.getUIContext());
      return;
    }
    await this.loadPoster();
    this.phase = "done";
  }

  private async loadPoster(): Promise<void> {
    const kind = this.kind();
    const query: Record<string, string> = {};
    query["scene"] = kind;
    const response = await HttpService.getWithQuery("/share-cards", query, true);
    if (response.statusCode === 200) {
      this.cards = parseShareCards(response.data, kind);
    } else {
      this.cards = [fallbackShareCard(kind)];
    }
    this.index = 0;
    const stats = await HttpService.get("/record/statis");
    if (stats.statusCode === 200 && stats.data) {
      this.focusMinutes = Number(stats.data["actual_mins"] ?? 0);
      this.taskCount = Number(stats.data["task_count"] ?? 0);
      this.successRate = formatSuccessRate(String(stats.data["success_rate"] ?? ""));
    }
  }

  private async savePoster(): Promise<void> {
    if (this.busy.length > 0 || this.cards.length === 0) {
      return;
    }
    this.busy = "save";
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await saveCertificateSnapshot(this.getUIContext(), hostContext, this.snapshotId());
      showToast("已保存到相册", this.getUIContext());
    } catch (error) {
      showErrorToast(formatSaveError(error as BusinessError), this.getUIContext());
    }
    this.busy = "";
  }

  private async sharePoster(): Promise<void> {
    if (this.busy.length > 0 || this.cards.length === 0) {
      return;
    }
    this.busy = "share";
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const pixelMap = await captureComponentSnapshot(this.getUIContext(), this.snapshotId(), {
        scale: 1,
        waitUntilRenderFinished: true,
      });
      const cachePath = buildStatsShareCachePath(hostContext);
      await writePixelMapToFile(pixelMap, cachePath);
      await shareStatsImageFile(hostContext, cachePath, "打卡", "专注契约打卡");
    } catch (error) {
      showErrorToast(formatShareError(error as BusinessError), this.getUIContext());
    }
    this.busy = "";
  }

  @Builder
  private buildContent(): void {
    Column() {
      if (this.phase === "loading") {
        Column() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(AppTheme.colors.textPrimary)
        }
        .width("100%")
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else if (this.phase === "idle") {
        Column() {
          Text(this.clockLabel())
            .fontSize(15)
            .fontColor(AppTheme.colors.textSecondary)
          Text(this.clockText)
            .fontSize(56)
            .fontWeight(FontWeight.Lighter)
            .fontColor(AppTheme.colors.textPrimary)
            .letterSpacing(1)
            .margin({ top: 8 })
          Text(this.idleHint())
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
            .margin({ top: 8 })
          Column() {
            if (this.submitting) {
              LoadingProgress().width(28).height(28).color("#FFFFFF");
            } else {
              Text("打卡").fontSize(22).fontWeight(FontWeight.Bold).fontColor("#FFFFFF");
            }
          }
          .width(168)
          .height(168)
          .margin({ top: 48 })
          .justifyContent(FlexAlign.Center)
          .borderRadius(84)
          .clip(true)
          .opacity(this.canFocus() ? 1 : 0.45)
          .linearGradient({
            angle: 135,
            colors: this.canFocus()
              ? [
                  ["#4F8CFF", 0.0],
                  ["#7A5AF8", 1.0],
                ]
              : [
                  ["#94A3B8", 0.0],
                  ["#A78BFA", 1.0],
                ],
          })
          .onClick(() => {
            void this.submitCheckin();
          })
          if (this.kind() === "focus" && !this.canFocus()) {
            Text(`专注满${this.focusMinGate}分钟后可打卡`)
              .fontSize(14)
              .fontColor(AppTheme.colors.primary)
              .textAlign(TextAlign.Center)
              .margin({ top: 28 });
          }
        }
        .width("100%")
        .layoutWeight(1)
        .padding({ top: 28 })
        .alignItems(HorizontalAlign.Center);
      } else {
        Column() {
          Row({ space: 8 }) {
            SymbolGlyph($r("sys.symbol.checkmark_circle_fill"))
              .fontSize(28)
              .fontColor(["#16B364"])
            Text("今日已打卡")
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor("#16B364")
          }
          .margin({ bottom: 30 })
          if (this.cards.length > 0) {
            CheckinPeekCarousel({
              kind: this.kind(),
              cards: this.cards,
              focusMinutes: this.focusMinutes,
              taskCount: this.taskCount,
              successRate: this.successRate,
              username: this.displayName(),
              avatar: this.userInfo.avatar,
              activeIndex: $index,
            }).width("100%");
          }
        }
        .width("100%")
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Start)
        .padding({ top: 12 });
      }

      if (this.phase === "done") {
        Row({ space: 12 }) {
          GallerySaveButton({
            saving: this.busy === "save",
            onSave: () => {
              void this.savePoster();
            },
          })
          Row() {
            if (this.busy === "share") {
              LoadingProgress().width(22).height(22).color("#FFFFFF");
            } else {
              Text("分享").fontSize(15).fontWeight(FontWeight.Bold).fontColor("#FFFFFF");
            }
          }
          .layoutWeight(1)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .borderRadius(24)
          .backgroundColor(AppTheme.colors.primary)
          .onClick(() => {
            void this.sharePoster();
          })
        }
        .width("100%")
        .padding({ left: 20, right: 20, bottom: 28 });
      }
    }
    .width("100%")
    .height("100%")
    .alignItems(HorizontalAlign.Center);
  }

  build() {
    Stack() {
      SystemNavPage({
        title: "",
        showBack: true,
        usePageScroll: false,
        horizontalPadding: 0,
        bottomSpacerHeight: 0,
        useFloatingTabInset: false,
        onBack: () => {
          backRoute();
        },
        content: (): void => {
          this.buildContent();
        },
      })
    }
    .width("100%")
    .height("100%");
  }
}

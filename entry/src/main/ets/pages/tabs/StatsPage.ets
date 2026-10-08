import { showErrorToast, showToast } from "../../common/Toast";
import {
  buildHonorCertificateData,
  buildShameCertificateData,
} from "../../services/CertificateCopyService";
import {
  openHonorCertificatePreview,
  openShameCertificatePreview,
} from "../../services/CertificateNavigationService";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import {
  ContractFulfillment,
  ContractFulfillmentChart,
} from "../../components/stats/ContractFulfillmentChart";
import { HonorRecordListSection } from "../../components/stats/HonorRecordListSection";
import { MixedDuration } from "../../components/stats/MixedDuration";
import { ShameRecordListSection } from "../../components/stats/ShameRecordListSection";
import { CheckinDailyChart } from "../../components/stats/CheckinDailyChart";
import { DailyDurationChart } from "../../components/stats/DailyDurationChart";
import { TaskDurationChart } from "../../components/stats/TaskDurationChart";
import { AppTheme } from "../../constants/Theme";
import {
  DuoShameDay,
  DuoShameRecord,
  DuoStatsSummary,
  DuoStatsTaskItem,
  DuoTimelineDay,
  DuoTimelineRecord,
} from "../../models/DuoModel";
import { PageRoutes, pushRoute } from "../../router/PageRoutes";
import { DuoApiService } from "../../services/DuoApiService";
import {
  CheckinByDay,
  parseCheckinByDay,
  parseStatsByDay,
  StatsDayItem,
} from "../../models/StatsChartModel";
import {
  flattenShameDays,
  flattenTimelineDays,
  formatSuccessDurationLabel,
  getDuoBlastReputationHint,
  getStatsPeriodLabel,
  getShameSectionBorderColor,
  getStatsRecordSectionBgColor,
  HONOR_SECTION_BORDER_COLOR,
  HonorRecordItem,
  ShameRecordItem,
  StatsDetailSection,
  StatsPeriod,
} from "../../services/StatsRecordUtil";
import { StoreKeys } from "../../stores/StoreKeys";
import { registerStatsReload, unregisterStatsReload } from "../../stores/StatsStore";
import { UserStore } from "../../stores/UserStore";
import { bootstrapStores } from "../../stores/StoreBootstrap";
import { FLOATING_TAB_EXTRA_BOTTOM_VP } from "./MainTabUtil";
import { TasksTabTitleBar } from "../../components/plans/TasksTabTitleBar";
import { common } from "@kit.AbilityKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { image } from "@kit.ImageKit";
import {
  buildStatsShareCachePath,
  captureStatsShareSnapshot,
  formatShareError,
  shareStatsImageFile,
  STATS_SNAPSHOT_ID,
  writePixelMapToFile,
} from "../../services/StatsShareService";

bootstrapStores();

const STATS_SHARE_BOTTOM_PADDING: number = 24;
@Component
export struct StatsPage {
  @StorageLink(StoreKeys.UserIsLoggedIn) @Watch("onLoginChanged") isLoggedIn: boolean = false;
  @StorageLink(StoreKeys.MainTabFloatingBar) floatingTabBar: boolean = false;
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = "light";
  @State currentPeriod: StatsPeriod = "today";
  @State summary: DuoStatsSummary | null = null;
  @State timeline: DuoTimelineDay[] = [];
  @State shame: DuoShameDay[] = [];
  @State byTask: DuoStatsTaskItem[] = [];
  @State byDay: StatsDayItem[] = [];
  @State prevActualMins: number = 0;
  @State hasPrev: boolean = false;
  @State checkinByDay: CheckinByDay | null = null;
  @State statsTab: number = 0;
  @State tabProgress: number = 0;
  @State swiperWidth: number = 0;
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  @State errorMessage: string = "";
  private overviewScroller: Scroller = new Scroller();
  private recordsScroller: Scroller = new Scroller();
  @State private overviewScrollerReady: boolean = false;
  @State private recordsScrollerReady: boolean = false;
  private readonly swiperAnimDuration: number = 300;
  private swiperController: SwiperController = new SwiperController();
  private reloadVersion: number = 0;
  private isSharing: boolean = false;

  aboutToAppear(): void {
    registerStatsReload(() => {
      void this.reload();
    });
    void this.reload();
  }

  aboutToDisappear(): void {
    unregisterStatsReload();
  }

  private onLoginChanged(): void {
    if (!this.isLoggedIn) {
      this.resetStatsView();
      return;
    }
    void this.reload();
  }

  private resetStatsView(): void {
    this.reloadVersion++;
    this.currentPeriod = "today";
    this.summary = null;
    this.timeline = [];
    this.shame = [];
    this.byTask = [];
    this.byDay = [];
    this.prevActualMins = 0;
    this.hasPrev = false;
    this.checkinByDay = null;
    this.errorMessage = "";
    this.isLoading = false;
    this.isRefreshing = false;
    this.goToStatsTab(0, false);
  }

  private async reload(fromPull: boolean = false): Promise<void> {
    const requestVersion = ++this.reloadVersion;
    if (fromPull) {
      this.isRefreshing = true;
    } else {
      this.isLoading = true;
    }
    this.errorMessage = "";

    if (!UserStore.isLoggedIn()) {
      this.resetStatsView();
      return;
    }

    const period = this.currentPeriod;
    const responses = await Promise.all([
      DuoApiService.getStatsSummary(period),
      DuoApiService.getStatsTimeline(period),
      DuoApiService.getStatsShame(period),
      DuoApiService.getStatsByTask(period),
      DuoApiService.getStatsByDay(period),
      DuoApiService.getCheckinStatsByDay(period),
    ]);
    const summaryRes = responses[0];
    const timelineRes = responses[1];
    const shameRes = responses[2];
    const byTaskRes = responses[3];
    const byDayRes = responses[4];
    const checkinRes = responses[5];

    if (requestVersion !== this.reloadVersion) {
      return;
    }

    const errors: string[] = [];
    if (summaryRes.statusCode !== 200) {
      errors.push(summaryRes.message ?? "统计摘要加载失败");
    }
    if (timelineRes.statusCode !== 200) {
      errors.push(timelineRes.message ?? "荣誉墙加载失败");
    }
    if (shameRes.statusCode !== 200) {
      errors.push(shameRes.message ?? "耻辱柱加载失败");
    }
    if (byTaskRes.statusCode !== 200) {
      errors.push(byTaskRes.message ?? "任务分布加载失败");
    }
    if (byDayRes.statusCode !== 200) {
      errors.push(byDayRes.message ?? "每日时长加载失败");
    }
    if (checkinRes.statusCode !== 200) {
      errors.push(checkinRes.message ?? "打卡统计加载失败");
    }
    if (errors.length > 0) {
      this.errorMessage = errors[0];
      showErrorToast(this.errorMessage, this.getUIContext());
    }

    this.summary = DuoApiService.parseSummary(summaryRes);
    const timelineData = DuoApiService.parseTimeline(timelineRes);
    const shameData = DuoApiService.parseShame(shameRes);
    const byTaskData = DuoApiService.parseByTask(byTaskRes);
    this.timeline = timelineData?.items ?? [];
    this.shame = shameData?.items ?? [];
    this.byTask = byTaskData?.items ?? [];
    const byDayData = parseStatsByDay(byDayRes.data);
    this.byDay = byDayRes.statusCode === 200 ? (byDayData?.items ?? []) : [];
    this.prevActualMins = byDayData?.prevActualMins ?? 0;
    this.hasPrev = byDayRes.statusCode === 200;
    this.checkinByDay = checkinRes.statusCode === 200 ? parseCheckinByDay(checkinRes.data) : null;
    this.isLoading = false;
    this.isRefreshing = false;
  }

  private getDurationHint(): string {
    if (this.currentPeriod === "yesterday") {
      return "昨日成功专注";
    }
    if (this.currentPeriod === "week") {
      return "本周成功专注";
    }
    if (this.currentPeriod === "month") {
      return "本月成功专注";
    }
    return "今日成功专注";
  }

  private getViolationCount(): number {
    return this.summary?.failed_count ?? 0;
  }

  private getFulfillment(): ContractFulfillment {
    return {
      solo_completed_count: this.summary?.solo_completed_count ?? 0,
      solo_failed_count: this.summary?.solo_failed_count ?? 0,
      duo_completed_count: this.summary?.duo_completed_count ?? 0,
      duo_violator_count: this.summary?.duo_violator_count ?? 0,
      duo_cohort_count: this.summary?.duo_cohort_count ?? 0,
    };
  }

  private hasFulfillmentRecords(): boolean {
    const completed = this.summary?.completed_count ?? 0;
    const failed = this.summary?.failed_count ?? 0;
    return completed + failed > 0;
  }

  private getTimelineCount(): number {
    let count = 0;
    for (let i = 0; i < this.timeline.length; i++) {
      count += this.timeline[i].records.length;
    }
    return count;
  }

  private getShameCount(): number {
    let count = 0;
    for (let i = 0; i < this.shame.length; i++) {
      count += this.shame[i].records.length;
    }
    return count;
  }

  private getTimelinePreviewItems(limit: number = 5): HonorRecordItem[] {
    return flattenTimelineDays(this.timeline).slice(0, limit);
  }

  private getShamePreviewItems(limit: number = 5): ShameRecordItem[] {
    return flattenShameDays(this.shame).slice(0, limit);
  }

  private openStatsDetail(section: StatsDetailSection): void {
    AppStorage.setOrCreate(StoreKeys.StatsDetailPeriod, this.currentPeriod);
    AppStorage.setOrCreate(StoreKeys.StatsDetailSection, section);
    pushRoute(PageRoutes.StatsDetail);
  }

  private openShameRecord(record: DuoShameRecord, fallbackDate: string): void {
    const data = buildShameCertificateData(record, fallbackDate, UserStore.getUserInfo());
    openShameCertificatePreview(data);
  }

  private openHonorRecord(record: DuoTimelineRecord, fallbackDate: string): void {
    const data = buildHonorCertificateData(
      record,
      fallbackDate,
      UserStore.getUserInfo(),
      this.summary?.success_rate,
    );
    openHonorCertificatePreview(data);
  }

  private async handleSharePress(): Promise<void> {
    if (this.isSharing) {
      return;
    }
    if (this.isLoading) {
      showToast("战报加载中，请稍候", this.getUIContext());
      return;
    }
    if (!UserStore.isLoggedIn()) {
      showToast("登录后可分享战报", this.getUIContext());
      return;
    }

    this.isSharing = true;
    let pixelMap: image.PixelMap | null = null;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const periodLabel = getStatsPeriodLabel(this.currentPeriod);

    try {
      pixelMap = await captureStatsShareSnapshot(this.getUIContext());
      const cachePath = buildStatsShareCachePath(hostContext);
      await writePixelMapToFile(pixelMap, cachePath);
      await shareStatsImageFile(
        hostContext,
        cachePath,
        `${periodLabel}专注战报`,
        "FocusPact 专注统计",
      );
    } catch (error) {
      showErrorToast(formatShareError(error as BusinessError), this.getUIContext());
    } finally {
      pixelMap?.release();
      this.isSharing = false;
    }
  }

  @Builder
  private buildPeriodButton(period: StatsPeriod): void {
    Text(getStatsPeriodLabel(period))
      .fontSize(12)
      .fontWeight(this.currentPeriod === period ? FontWeight.Bold : FontWeight.Regular)
      .fontColor(
        this.currentPeriod === period ? AppTheme.colors.primary : AppTheme.colors.textSecondary,
      )
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .backgroundColor(
        this.currentPeriod === period ? AppTheme.colors.primarySoft : AppTheme.colors.surface,
      )
      .borderRadius(AppTheme.radius.pill)
      .border({
        width: 1,
        color: this.currentPeriod === period ? AppTheme.colors.primary : AppTheme.colors.border,
      })
      .onClick(() => {
        if (this.currentPeriod === period) {
          return;
        }
        this.currentPeriod = period;
        void this.reload();
      });
  }

  @Builder
  private buildStatusNotice(): void {
    if (this.isLoading) {
      Text(`正在加载${getStatsPeriodLabel(this.currentPeriod)}战报...`)
        .fontSize(13)
        .fontColor(AppTheme.colors.textMuted)
        .width("100%")
        .textAlign(TextAlign.Center)
        .margin({ top: 16 });
    } else if (this.errorMessage.length > 0) {
      Text(this.errorMessage)
        .fontSize(13)
        .fontColor(AppTheme.colors.danger)
        .width("100%")
        .textAlign(TextAlign.Center);
    }
  }

  @Builder
  private buildLoadingCard(height: number, backgroundColor: string, borderColor: string): void {
    Column({ space: 10 }) {
      Blank()
        .width("42%")
        .height(12)
        .backgroundColor(AppTheme.colors.surfaceSecondary)
        .borderRadius(999)
      Blank()
        .width("68%")
        .height(20)
        .backgroundColor(AppTheme.colors.surfaceSecondary)
        .borderRadius(999)
      Blank()
        .width("56%")
        .height(12)
        .backgroundColor(AppTheme.colors.surfaceSecondary)
        .borderRadius(999)
    }
    .width("100%")
    .height(height)
    .padding(18)
    .backgroundColor(backgroundColor)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: borderColor })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  private buildLoadingState(): void {
    Column({ space: 18 }) {
      Row({ space: 12 }) {
        Column() {
          this.buildLoadingCard(118, AppTheme.colors.surface, '#00000000')
        }.layoutWeight(1)
        Column() {
          this.buildLoadingCard(118, AppTheme.colors.surface, '#00000000')
        }.layoutWeight(1)
        Column() {
          this.buildLoadingCard(118, AppTheme.colors.surface, '#00000000')
        }.layoutWeight(1)
      }.width("100%")

      this.buildLoadingCard(160, AppTheme.colors.surface, '#00000000')
      this.buildLoadingCard(180, AppTheme.colors.surface, '#00000000')
      this.buildLoadingCard(132, getStatsRecordSectionBgColor(), HONOR_SECTION_BORDER_COLOR)
      this.buildLoadingCard(132, getStatsRecordSectionBgColor(), getShameSectionBorderColor())
    }.width("100%");
  }

  @Builder
  private buildCompactMetricCard(title: string, value: string, hint: string): void {
    Column({ space: 6 }) {
      Text(title)
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width("100%")
        .maxLines(1)
      MixedDuration({
        text: value,
        color: AppTheme.colors.textPrimary,
        numberSize: 22,
        unitSize: 12,
        numberWeight: FontWeight.Medium,
      })
      Text(hint)
        .fontSize(11)
        .fontColor(AppTheme.colors.textMuted)
        .width("100%")
        .lineHeight(16)
        .maxLines(2)
    }
    .padding(14)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
    .width("100%");
  }

  @Builder
  private buildMetricBoard(): void {
    Row({ space: 12 }) {
      Column() {
        this.buildCompactMetricCard(
          "连续专注",
          `${this.summary?.streak_days ?? 0} 天`,
          `最长 ${this.summary?.best_streak_days ?? 0} 天`,
        )
      }.layoutWeight(1)
      Column() {
        this.buildCompactMetricCard(
          "履约总时长",
          formatSuccessDurationLabel(this.summary?.actual_mins ?? 0),
          this.getDurationHint(),
        )
      }.layoutWeight(1)
      Column() {
        this.buildCompactMetricCard(
          "违约次数",
          `${this.getViolationCount()} 次`,
          getDuoBlastReputationHint(this.getViolationCount()),
        )
      }.layoutWeight(1)
    }
    .width("100%")
    .alignItems(VerticalAlign.Top);
  }

  @Builder
  private buildSectionHeader(title: string, count: number, onPress: () => void): void {
    Row({ space: 12 }) {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .layoutWeight(1)
      Button() {
        Row({ space: 3 }) {
          Text(`查看全部(${count})`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textMuted)
          SymbolGlyph($r("sys.symbol.chevron_right"))
            .fontSize(16)
            .fontColor([AppTheme.colors.textMuted])
        }
      }
      .type(ButtonType.Normal)
      .backgroundColor('#00000000')
      .padding(0)
      .onClick(() => {
        onPress();
      })
    }
    .width("100%")
    .alignItems(VerticalAlign.Center)
    .margin({ top: 10 });
  }

  @Builder
  private buildTimelinePreviewList(items: HonorRecordItem[]): void {
    HonorRecordListSection({
      items: items,
      onItemPress: (item: HonorRecordItem) => {
        this.openHonorRecord(item.record, item.day);
      },
    });
  }

  @Builder
  private buildShamePreviewList(items: ShameRecordItem[]): void {
    ShameRecordListSection({
      items: items,
      onItemPress: (item: ShameRecordItem) => {
        this.openShameRecord(item.record, item.day);
      },
    });
  }

  @Builder
  private buildTimelineSection(): void {
    Column({ space: 12 }) {
      this.buildSectionHeader("履约荣誉墙", this.getTimelineCount(), () => {
        this.openStatsDetail("timeline");
      })

      if (this.timeline.length === 0) {
        Column({ space: 8 }) {
          Text("今天还没有荣誉记录")
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
          Text("先完成一局专注，开始积累你的荣誉档案")
            .fontSize(12)
            .fontColor(AppTheme.colors.textMuted)
        }
        .width("100%")
        .padding(18)
        .backgroundColor(getStatsRecordSectionBgColor())
        .borderRadius(AppTheme.radius.lg)
        .border({ width: 1, color: HONOR_SECTION_BORDER_COLOR })
        .alignItems(HorizontalAlign.Start);
      } else {
        this.buildTimelinePreviewList(this.getTimelinePreviewItems());
      }
    }.width("100%");
  }

  @Builder
  private buildShameSection(): void {
    Column({ space: 12 }) {
      this.buildSectionHeader("违约耻辱柱", this.getShameCount(), () => {
        this.openStatsDetail("shame");
      })

      if (this.shame.length === 0) {
        Column({ space: 8 }) {
          Text("耻辱柱目前一片空白")
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
          Text("很好，你的自律决心战胜了对手机的渴望")
            .fontSize(12)
            .fontColor(AppTheme.colors.textMuted)
            .width("100%")
            .lineHeight(18)
        }
        .width("100%")
        .padding(18)
        .backgroundColor(getStatsRecordSectionBgColor())
        .borderRadius(AppTheme.radius.lg)
        .border({ width: 1, color: getShameSectionBorderColor() })
        .alignItems(HorizontalAlign.Start);
      } else {
        this.buildShamePreviewList(this.getShamePreviewItems());
      }
    }.width("100%");
  }

  private updateTabProgressFromOffset(pageIndex: number, currentOffset: number): void {
    if (this.swiperWidth <= 0) {
      this.tabProgress = pageIndex;
      return;
    }
    const next = pageIndex - (currentOffset / this.swiperWidth);
    this.tabProgress = Math.max(0, Math.min(1, next));
  }

  private animateTabProgressToTarget(pageIndex: number, targetIndex: number, extraInfo: SwiperAnimationEvent): void {
    this.updateTabProgressFromOffset(pageIndex, extraInfo.currentOffset);
    if (Math.abs(this.tabProgress - targetIndex) < 0.001) {
      this.tabProgress = targetIndex;
      return;
    }
    this.getUIContext().animateTo({
      duration: this.swiperAnimDuration,
      curve: Curve.EaseOut,
      onFinish: () => {
        this.tabProgress = targetIndex;
      }
    }, () => {
      this.tabProgress = targetIndex;
    });
  }

  private goToStatsTab(index: number, animate: boolean = true): void {
    this.statsTab = index;
    this.tabProgress = index;
    this.swiperController.changeIndex(index, animate);
  }

  private onStatsTabChanged(index: number): void {
    this.statsTab = index;
  }

  @Builder
  private buildStatsTabHeader(): void {
    Row() {
      Row() {
        TasksTabTitleBar({
          progress: this.tabProgress,
          firstTabLabel: "数据总览",
          secondTabLabel: "荣辱记录",
          onTabPress: (index: number) => {
            this.goToStatsTab(index);
          },
        })
      }
      .layoutWeight(1)
      .padding({ left: 20 })
      .alignItems(VerticalAlign.Bottom)
      .height(34)

      if (this.statsTab === 0) {
        Row() {
          SymbolGlyph($r("sys.symbol.share"))
            .fontSize(22)
            .fontColor([AppTheme.colors.textPrimary])
        }
        .width(42)
        .height(42)
        .borderRadius(21)
        .backgroundColor(AppTheme.colors.surface)
        .border({ width: 1, color: AppTheme.colors.border })
        .justifyContent(FlexAlign.Center)
        .margin({ right: 20 })
        .onClick(() => {
          void this.handleSharePress();
        })
      } else {
        Row()
          .width(42)
          .height(42)
          .margin({ right: 20 })
      }
    }
    .width("100%")
    .padding({ bottom: 4 })
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  private buildPeriodSelector(): void {
    Row({ space: 8 }) {
      this.buildPeriodButton("today")
      this.buildPeriodButton("yesterday")
      this.buildPeriodButton("week")
      this.buildPeriodButton("month")
    }
    .width("100%")
    .margin({ top: 14 })
  }

  @Builder
  private buildOverviewBody(): void {
    Column({ space: 18 }) {
      this.buildStatusNotice()
      if (this.isLoading) {
        this.buildLoadingState();
      } else {
        this.buildMetricBoard();
        TaskDurationChart({
          data: this.byTask,
          onViewAll: () => {
            this.openStatsDetail("byTask");
          },
        });
        if (this.hasFulfillmentRecords()) {
          ContractFulfillmentChart({
            data: this.getFulfillment(),
          });
        }
        DailyDurationChart({
          period: this.currentPeriod,
          items: this.byDay,
          currentMins: this.summary?.actual_mins ?? 0,
          prevActualMins: this.prevActualMins,
          hasPrev: this.hasPrev,
        })
        CheckinDailyChart({
          period: this.currentPeriod,
          data: this.checkinByDay,
        })
      }
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildRecordsBody(): void {
    Column({ space: 18 }) {
      this.buildStatusNotice()
      if (this.isLoading) {
        this.buildLoadingState();
      } else {
        this.buildTimelineSection();
        this.buildShameSection();
      }
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildOverviewTabPage(): void {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll(this.overviewScroller) {
        Column({ space: 18 }) {
          this.buildPeriodSelector()
          this.buildOverviewBody()
        }
        .width("100%")
        .padding({ left: 20, right: 20, bottom: this.getScrollBottomPadding() })
        .backgroundColor(AppTheme.colors.background)
        .alignItems(HorizontalAlign.Start)
        .id(STATS_SNAPSHOT_ID)
      }
      .width("100%")
      .height("100%")
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onAppear(() => {
        this.overviewScrollerReady = true;
      })
    }
    .pullToRefresh(true)
    .onRefreshing(() => {
      void this.reload(true);
    })
    .width("100%")
    .height("100%")
    .align(Alignment.TopStart);
  }

  @Builder
  private buildRecordsTabPage(): void {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll(this.recordsScroller) {
        Column({ space: 18 }) {
          this.buildPeriodSelector()
          this.buildRecordsBody()
        }
        .width("100%")
        .padding({ left: 20, right: 20, bottom: this.getScrollBottomPadding() })
        .backgroundColor(AppTheme.colors.background)
        .alignItems(HorizontalAlign.Start)
      }
      .width("100%")
      .height("100%")
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onAppear(() => {
        this.recordsScrollerReady = true;
      })
    }
    .pullToRefresh(true)
    .onRefreshing(() => {
      void this.reload(true);
    })
    .width("100%")
    .height("100%")
    .align(Alignment.TopStart);
  }

  @Builder
  private buildStatsPager(): void {
    Swiper(this.swiperController) {
      Column() {
        this.buildOverviewTabPage()
      }
      .width("100%")
      .height("100%")

      Column() {
        this.buildRecordsTabPage()
      }
      .width("100%")
      .height("100%")
    }
    .index(this.statsTab)
    .indicator(false)
    .loop(false)
    .cachedCount(1)
    .duration(this.swiperAnimDuration)
    .curve(Curve.EaseOut)
    .layoutWeight(1)
    .width("100%")
    .onAreaChange((_old: Area, area: Area) => {
      const width = Number(area.width);
      if (width > 0) {
        this.swiperWidth = width;
      }
    })
    .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
      this.updateTabProgressFromOffset(index, extraInfo.currentOffset);
    })
    .onAnimationStart((index: number, targetIndex: number, extraInfo: SwiperAnimationEvent) => {
      this.animateTabProgressToTarget(index, targetIndex, extraInfo);
    })
    .onAnimationEnd((index: number, _extraInfo: SwiperAnimationEvent) => {
      this.tabProgress = index;
    })
    .onChange((index: number) => {
      this.onStatsTabChanged(index);
    })
  }

  private getScrollBottomPadding(): number {
    return STATS_SHARE_BOTTOM_PADDING + (this.floatingTabBar ? FLOATING_TAB_EXTRA_BOTTOM_VP : 0);
  }

  @Builder
  private buildStatsPageBody(): void {
    Column() {
      this.buildStatsTabHeader()
      this.buildStatsPager()
    }
    .width("100%")
    .height("100%")
  }

  private getBindScrollers(): Scroller[] {
    if (this.statsTab === 0 && this.overviewScrollerReady) {
      return [this.overviewScroller];
    }
    if (this.statsTab === 1 && this.recordsScrollerReady) {
      return [this.recordsScroller];
    }
    return [];
  }

  build() {
    SystemNavPage({
      title: "",
      showBack: false,
      showTitleBar: false,
      showAction: false,
      horizontalPadding: 0,
      topSpacerHeight: 8,
      titleBarBottomPadding: 0,
      hiddenTitleTopPadding: 0,
      bottomSpacerHeight: 0,
      useFloatingTabInset: false,
      usePageScroll: false,
      bindScrollers: this.getBindScrollers(),
      content: (): void => {
        this.buildStatsPageBody();
      },
    });
  }
}

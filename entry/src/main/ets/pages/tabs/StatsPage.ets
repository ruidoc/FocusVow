import { showErrorToast, showToast } from '../../common/Toast';
import { buildHonorCertificateData, buildShameCertificateData } from '../../services/CertificateCopyService';
import {
  openHonorCertificatePreview,
  openShameCertificatePreview
} from '../../services/CertificateNavigationService';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import {
  ContractFulfillment,
  ContractFulfillmentChart
} from '../../components/stats/ContractFulfillmentChart';
import { HonorRecordListSection } from '../../components/stats/HonorRecordListSection';
import { MixedDuration } from '../../components/stats/MixedDuration';
import { ShameRecordListSection } from '../../components/stats/ShameRecordListSection';
import { TaskDurationChart } from '../../components/stats/TaskDurationChart';
import { AppTheme } from '../../constants/Theme';
import {
  DuoShameDay,
  DuoShameRecord,
  DuoStatsSummary,
  DuoStatsTaskItem,
  DuoTimelineDay,
  DuoTimelineRecord
} from '../../models/DuoModel';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import {
  flattenShameDays,
  flattenTimelineDays,
  formatSuccessDurationLabel,
  getDuoBlastReputationHint,
  getStatsPeriodLabel,
  HONOR_SECTION_BORDER_COLOR,
  HonorRecordItem,
  SHAME_SECTION_BORDER_COLOR,
  ShameRecordItem,
  STATS_RECORD_SECTION_BG_COLOR,
  StatsDetailSection,
  StatsPeriod
} from '../../services/StatsRecordUtil';
import { StoreKeys } from '../../stores/StoreKeys';
import { registerStatsReload, unregisterStatsReload } from '../../stores/StatsStore';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import {
  buildStatsShareCachePath,
  captureStatsShareSnapshot,
  formatShareError,
  shareStatsImageFile,
  STATS_SNAPSHOT_ID,
  writePixelMapToFile
} from '../../services/StatsShareService';

bootstrapStores();

const STATS_SHARE_BOTTOM_PADDING: number = 24;

@Component
export struct StatsPage {
  @State currentPeriod: StatsPeriod = 'today';
  @State summary: DuoStatsSummary | null = null;
  @State timeline: DuoTimelineDay[] = [];
  @State shame: DuoShameDay[] = [];
  @State byTask: DuoStatsTaskItem[] = [];
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  @State errorMessage: string = '';
  private scroller: Scroller = new Scroller();
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

  private async reload(fromPull: boolean = false): Promise<void> {
    const requestVersion = ++this.reloadVersion;
    if (fromPull) {
      this.isRefreshing = true;
    } else {
      this.isLoading = true;
    }
    this.errorMessage = '';

    if (!UserStore.isLoggedIn()) {
      this.errorMessage = '登录后可查看履约荣誉墙与耻辱柱';
      this.summary = null;
      this.timeline = [];
      this.shame = [];
      this.byTask = [];
      this.isLoading = false;
      this.isRefreshing = false;
      return;
    }

    const period = this.currentPeriod;
    const responses = await Promise.all([
      DuoApiService.getStatsSummary(period),
      DuoApiService.getStatsTimeline(period),
      DuoApiService.getStatsShame(period),
      DuoApiService.getStatsByTask(period)
    ]);
    const summaryRes = responses[0];
    const timelineRes = responses[1];
    const shameRes = responses[2];
    const byTaskRes = responses[3];

    if (requestVersion !== this.reloadVersion) {
      return;
    }

    const errors: string[] = [];
    if (summaryRes.statusCode !== 200) {
      errors.push(summaryRes.message ?? '统计摘要加载失败');
    }
    if (timelineRes.statusCode !== 200) {
      errors.push(timelineRes.message ?? '荣誉墙加载失败');
    }
    if (shameRes.statusCode !== 200) {
      errors.push(shameRes.message ?? '耻辱柱加载失败');
    }
    if (byTaskRes.statusCode !== 200) {
      errors.push(byTaskRes.message ?? '任务分布加载失败');
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
    this.isLoading = false;
    this.isRefreshing = false;
  }

  private getDurationHint(): string {
    if (this.currentPeriod === 'week') {
      return '本周成功专注';
    }
    if (this.currentPeriod === 'month') {
      return '本月成功专注';
    }
    return '今日成功专注';
  }

  private getFulfillment(): ContractFulfillment {
    return {
      solo_completed_count: this.summary?.solo_completed_count ?? 0,
      solo_failed_count: this.summary?.solo_failed_count ?? 0,
      duo_completed_count: this.summary?.duo_completed_count ?? 0,
      duo_violator_count: this.summary?.duo_violator_count ?? 0,
      duo_cohort_count: this.summary?.duo_cohort_count ?? 0
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
      this.summary?.success_rate
    );
    openHonorCertificatePreview(data);
  }

  private async handleSharePress(): Promise<void> {
    if (this.isSharing) {
      return;
    }
    if (this.isLoading) {
      showToast('战报加载中，请稍候', this.getUIContext());
      return;
    }
    if (!UserStore.isLoggedIn()) {
      showToast('登录后可分享战报', this.getUIContext());
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
        'FocusPact 专注统计'
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
      .fontSize(13)
      .fontWeight(this.currentPeriod === period ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.currentPeriod === period ? AppTheme.colors.primary : AppTheme.colors.textSecondary)
      .padding({ left: 16, right: 16, top: 9, bottom: 9 })
      .backgroundColor(this.currentPeriod === period ? AppTheme.colors.primarySoft : AppTheme.colors.surface)
      .borderRadius(AppTheme.radius.pill)
      .border({
        width: 1,
        color: this.currentPeriod === period ? AppTheme.colors.primary : AppTheme.colors.border
      })
      .onClick(() => {
        if (this.currentPeriod === period) {
          return;
        }
        this.currentPeriod = period;
        void this.reload();
      })
  }

  @Builder
  private buildStatusNotice(): void {
    if (this.isLoading) {
      Text(`正在加载${getStatsPeriodLabel(this.currentPeriod)}战报...`)
        .fontSize(13)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 16 })
    } else if (this.errorMessage.length > 0) {
      Text(this.errorMessage)
        .fontSize(13)
        .fontColor(AppTheme.colors.danger)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  private buildLoadingCard(height: number, backgroundColor: string, borderColor: string): void {
    Column({ space: 10 }) {
      Blank()
        .width('42%')
        .height(12)
        .backgroundColor('#E9ECF5')
        .borderRadius(999)

      Blank()
        .width('68%')
        .height(20)
        .backgroundColor('#E9ECF5')
        .borderRadius(999)

      Blank()
        .width('56%')
        .height(12)
        .backgroundColor('#E9ECF5')
        .borderRadius(999)
    }
    .width('100%')
    .height(height)
    .padding(18)
    .backgroundColor(backgroundColor)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: borderColor })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private buildLoadingState(): void {
    Column({ space: 18 }) {
      Row({ space: 12 }) {
        Column() {
          this.buildLoadingCard(118, AppTheme.colors.surface, AppTheme.colors.border)
        }
        .layoutWeight(1)

        Column() {
          this.buildLoadingCard(118, AppTheme.colors.surface, AppTheme.colors.border)
        }
        .layoutWeight(1)

        Column() {
          this.buildLoadingCard(118, AppTheme.colors.surface, AppTheme.colors.border)
        }
        .layoutWeight(1)
      }
      .width('100%')

      this.buildLoadingCard(160, AppTheme.colors.surface, AppTheme.colors.border)
      this.buildLoadingCard(180, AppTheme.colors.surface, AppTheme.colors.border)
      this.buildLoadingCard(132, STATS_RECORD_SECTION_BG_COLOR, HONOR_SECTION_BORDER_COLOR)
      this.buildLoadingCard(132, STATS_RECORD_SECTION_BG_COLOR, SHAME_SECTION_BORDER_COLOR)
    }
    .width('100%')
  }

  @Builder
  private buildCompactMetricCard(title: string, value: string, hint: string): void {
    Column({ space: 6 }) {
      Text(title)
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
        .maxLines(1)
      MixedDuration({
        text: value,
        color: AppTheme.colors.textPrimary,
        numberSize: 20,
        unitSize: 11
      })
      Text(hint)
        .fontSize(11)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .lineHeight(16)
        .maxLines(2)
    }
    .padding(14)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.md)
    .border({ width: 1, color: AppTheme.colors.border })
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .constraintSize({ minHeight: 100 })
  }

  @Builder
  private buildMetricBoard(): void {
    Row({ space: 12 }) {
      Column() {
        this.buildCompactMetricCard(
          '连续专注',
          `${this.summary?.streak_days ?? 0} 天`,
          `历史最长 ${this.summary?.best_streak_days ?? 0} 天`
        )
      }
      .layoutWeight(1)

      Column() {
        this.buildCompactMetricCard(
          '履约总时长',
          formatSuccessDurationLabel(this.summary?.actual_mins ?? 0),
          this.getDurationHint()
        )
      }
      .layoutWeight(1)

      Column() {
        this.buildCompactMetricCard(
          '违约次数',
          `${this.summary?.duo_violator_count ?? 0} 次`,
          getDuoBlastReputationHint(this.summary?.duo_violator_count ?? 0)
        )
      }
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
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

          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([AppTheme.colors.textMuted])
        }
      }
      .type(ButtonType.Normal)
      .backgroundColor(Color.Transparent)
      .padding(0)
      .onClick(() => {
        onPress();
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 10 })
  }

  @Builder
  private buildTimelinePreviewList(items: HonorRecordItem[]): void {
    HonorRecordListSection({
      items: items,
      onItemPress: (item: HonorRecordItem) => {
        this.openHonorRecord(item.record, item.day);
      }
    })
  }

  @Builder
  private buildShamePreviewList(items: ShameRecordItem[]): void {
    ShameRecordListSection({
      items: items,
      onItemPress: (item: ShameRecordItem) => {
        this.openShameRecord(item.record, item.day);
      }
    })
  }

  @Builder
  private buildTimelineSection(): void {
    Column({ space: 12 }) {
      this.buildSectionHeader('履约荣誉墙', this.getTimelineCount(), () => {
        this.openStatsDetail('timeline');
      })

      if (this.timeline.length === 0) {
        Column({ space: 8 }) {
          Text('今天还没有荣誉记录')
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
          Text('先完成一局专注，开始积累你的荣誉档案')
            .fontSize(12)
            .fontColor(AppTheme.colors.textMuted)
        }
        .width('100%')
        .padding(18)
        .backgroundColor(STATS_RECORD_SECTION_BG_COLOR)
        .borderRadius(AppTheme.radius.lg)
        .border({ width: 1, color: HONOR_SECTION_BORDER_COLOR })
        .alignItems(HorizontalAlign.Start)
      } else {
        this.buildTimelinePreviewList(this.getTimelinePreviewItems())
      }
    }
    .width('100%')
  }

  @Builder
  private buildShameSection(): void {
    Column({ space: 12 }) {
      this.buildSectionHeader('违约耻辱柱', this.getShameCount(), () => {
        this.openStatsDetail('shame');
      })

      if (this.shame.length === 0) {
        Column({ space: 8 }) {
          Text('耻辱柱目前一片空白')
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
          Text('很好，你的自律决心战胜了对手机的渴望')
            .fontSize(12)
            .fontColor(AppTheme.colors.textMuted)
            .width('100%')
            .lineHeight(18)
        }
        .width('100%')
        .padding(18)
        .backgroundColor(STATS_RECORD_SECTION_BG_COLOR)
        .borderRadius(AppTheme.radius.lg)
        .border({ width: 1, color: SHAME_SECTION_BORDER_COLOR })
        .alignItems(HorizontalAlign.Start)
      } else {
        this.buildShamePreviewList(this.getShamePreviewItems())
      }
    }
    .width('100%')
  }

  @Builder
  private buildStatsContent(): void {
    Column({ space: 18 }) {
      Row({ space: 10 }) {
        this.buildPeriodButton('today');
        this.buildPeriodButton('week');
        this.buildPeriodButton('month');
      }
      .width('100%')
      .padding({ top: 16 })

      this.buildStatusNotice()
      if (this.isLoading) {
        this.buildLoadingState()
      } else {
        this.buildMetricBoard()
        TaskDurationChart({
          data: this.byTask,
          onViewAll: () => {
            this.openStatsDetail('byTask');
          }
        })
        if (this.hasFulfillmentRecords()) {
          ContractFulfillmentChart({
            data: this.getFulfillment()
          })
        }
        this.buildTimelineSection()
        this.buildShameSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildStatsBody(): void {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll(this.scroller) {
        Column() {
          this.buildStatsContent()
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
        .padding({ bottom: STATS_SHARE_BOTTOM_PADDING })
        .backgroundColor(AppTheme.colors.background)
        .alignItems(HorizontalAlign.Start)
        .id(STATS_SNAPSHOT_ID)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .pullToRefresh(true)
    .onRefreshing(() => {
      void this.reload(true);
    })
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
  }

  build() {
    SystemNavPage({
      title: '统计',
      showBack: false,
      showAction: true,
      actionLabel: '分享',
      actionIcon: $r('sys.symbol.share'),
      bottomSpacerHeight: 0,
      usePageScroll: false,
      bindScrollers: [this.scroller],
      onAction: () => {
        void this.handleSharePress();
      },
      content: (): void => {
        this.buildStatsBody();
      }
    })
  }
}

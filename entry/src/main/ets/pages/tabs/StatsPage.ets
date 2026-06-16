import { showErrorToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import {
  DuoShameDay,
  DuoShameRecord,
  DuoStatsSummary,
  DuoTimelineDay,
  DuoTimelineRecord
} from '../../models/DuoModel';
import { DuoApiService } from '../../services/DuoApiService';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

type StatsPeriod = 'today' | 'week' | 'month';

@Component
export struct StatsPage {
  @State currentPeriod: StatsPeriod = 'today';
  @State summary: DuoStatsSummary | null = null;
  @State timeline: DuoTimelineDay[] = [];
  @State shame: DuoShameDay[] = [];
  @State isRefreshing: boolean = false;

  private statsScroller: Scroller = new Scroller();
  @State private scrollerReady: boolean = false;

  aboutToAppear(): void {
    this.scrollerReady = true;
    void this.reload();
  }

  private getPeriodLabel(period: StatsPeriod): string {
    if (period === 'week') {
      return '本周';
    }
    if (period === 'month') {
      return '本月';
    }
    return '今日';
  }

  private async reload(fromPull: boolean = false): Promise<void> {
    if (fromPull) {
      this.isRefreshing = true;
    }

    if (!UserStore.isLoggedIn()) {
      showErrorToast('登录后可查看上岸时光轴与耻辱柱', this.getUIContext());
      this.summary = null;
      this.timeline = [];
      this.shame = [];
      this.isRefreshing = false;
      return;
    }

    const period = this.currentPeriod;
    const summaryRes = await DuoApiService.getStatsSummary(period);
    const timelineRes = await DuoApiService.getStatsTimeline(period);
    const shameRes = await DuoApiService.getStatsShame(period);

    this.summary = DuoApiService.parseSummary(summaryRes);
    const timelineData = DuoApiService.parseTimeline(timelineRes);
    const shameData = DuoApiService.parseShame(shameRes);
    this.timeline = timelineData?.items ?? [];
    this.shame = shameData?.items ?? [];
    this.isRefreshing = false;
  }

  @Builder
  private buildPeriodButton(period: StatsPeriod, active: boolean): void {
    Text(this.getPeriodLabel(period))
      .fontSize(13)
      .fontWeight(active ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(active ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary)
      .padding({ left: 16, right: 16, top: 9, bottom: 9 })
      .backgroundColor(active ? AppTheme.colors.surfaceRaised : AppTheme.colors.surface)
      .borderRadius(AppTheme.radius.pill)
      .border({ width: 1, color: active ? AppTheme.colors.border : AppTheme.colors.border })
      .onClick(() => {
        this.currentPeriod = period;
        void this.reload();
      })
  }

  @Builder
  private buildSummaryCard(): void {
    Column({ space: 8 }) {
      Text(`${this.getPeriodLabel(this.currentPeriod)}汇总`)
        .fontSize(12)
        .fontColor(AppTheme.colors.textMuted)
      Text(`${this.summary?.actual_mins ?? 0} 分钟`)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
      Text(`完成 ${this.summary?.completed_count ?? 0} 次 · 失败 ${this.summary?.failed_count ?? 0} 次 · 成功率 ${this.summary?.success_rate ?? 0}%`)
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildTimelineSection(): void {
    Column({ space: 10 }) {
      Text('上岸时光轴')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      if (this.timeline.length === 0) {
        Text('暂无完成记录')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
      } else {
        ForEach(this.timeline, (day: DuoTimelineDay) => {
          Column({ space: 8 }) {
            Text(day.date)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textPrimary)
            ForEach(day.records, (record: DuoTimelineRecord) => {
              Text(`${record.title} · ${record.actual_min}/${record.total_min} 分钟`)
                .fontSize(13)
                .fontColor(AppTheme.colors.textSecondary)
            })
          }
          .width('100%')
          .padding(12)
          .backgroundColor(AppTheme.colors.surface)
          .borderRadius(AppTheme.radius.md)
          .border({ width: 1, color: AppTheme.colors.border })
        })
      }
    }
    .width('100%')
  }

  @Builder
  private buildShameSection(): void {
    Column({ space: 10 }) {
      Text('违约耻辱柱')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      if (this.shame.length === 0) {
        Text('暂无违约记录')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
      } else {
        ForEach(this.shame, (day: DuoShameDay) => {
          Column({ space: 8 }) {
            Text(day.date)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textPrimary)
            ForEach(day.records, (record: DuoShameRecord) => {
              Text(`${record.title} · ${record.breach_role === 'violator' ? '主动撕毁' : '被连坐'}`)
                .fontSize(13)
                .fontColor(AppTheme.colors.danger)
            })
          }
          .width('100%')
          .padding(12)
          .backgroundColor(AppTheme.colors.surface)
          .borderRadius(AppTheme.radius.md)
          .border({ width: 1, color: AppTheme.colors.border })
        })
      }
    }
    .width('100%')
  }

  @Builder
  private buildStatsBody(): void {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll(this.statsScroller) {
        Column({ space: 16 }) {
          Row({ space: 10 }) {
            this.buildPeriodButton('today', this.currentPeriod === 'today')
            this.buildPeriodButton('week', this.currentPeriod === 'week')
            this.buildPeriodButton('month', this.currentPeriod === 'month')
          }
          .width('100%')

          this.buildSummaryCard()
          this.buildTimelineSection()
          this.buildShameSection()
        }
        .width('100%')
        .padding({ top: 16, bottom: 24 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .layoutWeight(1)
    }
    .onRefreshing(() => {
      void this.reload(true);
    })
    .pullToRefresh(true)
    .width('100%')
    .height('100%')
    .layoutWeight(1)
  }

  build() {
    SystemNavPage({
      title: '统计',
      showBack: false,
      usePageScroll: false,
      bindScrollers: this.scrollerReady ? [this.statsScroller] : [],
      content: (): void => {
        this.buildStatsBody();
      }
    })
  }
}

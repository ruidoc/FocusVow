import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import {
  DuoShameDay,
  DuoShameRecord,
  DuoTimelineDay,
  DuoTimelineRecord
} from '../../models/DuoModel';
import { PageRoutes, backRoute } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

type StatsPeriod = 'today' | 'week' | 'month';
type StatsDetailSection = 'timeline' | 'shame';

interface TimelineDetailItem {
  day: string;
  record: DuoTimelineRecord;
}

interface ShameDetailItem {
  day: string;
  record: DuoShameRecord;
}

@Entry
@Component
struct StatsDetailPage {
  @State currentPeriod: StatsPeriod = 'today';
  @State currentSection: StatsDetailSection = 'timeline';
  @State timeline: DuoTimelineDay[] = [];
  @State shame: DuoShameDay[] = [];
  @State isLoading: boolean = false;
  @State errorMessage: string = '';

  private listScroller: Scroller = new Scroller();
  @State private scrollerReady: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    const storedPeriod = String(AppStorage.get<string>(StoreKeys.StatsDetailPeriod) ?? 'today');
    const storedSection = String(AppStorage.get<string>(StoreKeys.StatsDetailSection) ?? 'timeline');
    this.currentPeriod = storedPeriod === 'week' || storedPeriod === 'month' ? storedPeriod : 'today';
    this.currentSection = storedSection === 'shame' ? 'shame' : 'timeline';
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

  private async reload(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';

    if (!UserStore.isLoggedIn()) {
      this.errorMessage = '登录后可查看完整战报';
      this.timeline = [];
      this.shame = [];
      this.isLoading = false;
      return;
    }

    const responses = await Promise.all([
      DuoApiService.getStatsTimeline(this.currentPeriod),
      DuoApiService.getStatsShame(this.currentPeriod)
    ]);
    const timelineRes = responses[0];
    const shameRes = responses[1];

    if (timelineRes.statusCode !== 200 || shameRes.statusCode !== 200) {
      this.errorMessage = timelineRes.message ?? shameRes.message ?? '战报加载失败';
      showErrorToast(this.errorMessage, this.getUIContext());
    }

    const timelineData = DuoApiService.parseTimeline(timelineRes);
    const shameData = DuoApiService.parseShame(shameRes);
    this.timeline = timelineData?.items ?? [];
    this.shame = shameData?.items ?? [];
    this.isLoading = false;
  }

  private getTimelineItems(): TimelineDetailItem[] {
    const items: TimelineDetailItem[] = [];
    for (let i = 0; i < this.timeline.length; i++) {
      const day = this.timeline[i];
      for (let j = 0; j < day.records.length; j++) {
        items.push({ day: day.date, record: day.records[j] });
      }
    }
    return items;
  }

  private getShameItems(): ShameDetailItem[] {
    const items: ShameDetailItem[] = [];
    for (let i = 0; i < this.shame.length; i++) {
      const day = this.shame[i];
      for (let j = 0; j < day.records.length; j++) {
        items.push({ day: day.date, record: day.records[j] });
      }
    }
    return items;
  }

  private formatDateTimeLabel(raw: string, fallbackDate: string): string {
    if (raw.length === 0) {
      return fallbackDate;
    }
    const normalized = raw.replace('T', ' ');
    const parts = normalized.split(' ');
    const datePart = parts.length > 0 ? parts[0] : fallbackDate;
    if (parts.length < 2) {
      return datePart;
    }
    const timePart = parts[1];
    const trimmedTime = timePart.length >= 5 ? timePart.substring(0, 5) : timePart;
    return `${datePart} ${trimmedTime}`;
  }

  private getTimelineRecordTime(record: DuoTimelineRecord, fallbackDate: string): string {
    return this.formatDateTimeLabel(record.completed_at ?? fallbackDate, fallbackDate);
  }

  private getShameRecordTime(record: DuoShameRecord, fallbackDate: string): string {
    return this.formatDateTimeLabel(record.completed_at ?? fallbackDate, fallbackDate);
  }

  private getTimelineModeLabel(record: DuoTimelineRecord): string {
    if (record.participation_mode === 'duo') {
      return '1v1 连坐模式';
    }
    return '单人闭关模式';
  }

  private getShameModeLabel(record: DuoShameRecord): string {
    if (record.participation_mode === 'duo') {
      if (record.breach_role === 'violator') {
        return '导致连坐炸房，搭子被无罪释放';
      }
      return '被搭子连坐波及，本局判定失败';
    }
    if (record.breach_role === 'violator') {
      return '主动撕毁契约，清白记录已作废';
    }
    return '本局未成功履约';
  }

  private getShameReasonLabel(record: DuoShameRecord): string {
    const reason = record.failed_reason.trim().toLowerCase();
    if (reason.length === 0) {
      return record.breach_role === 'violator' ? '强杀断开' : '连带失败';
    }
    if (reason === 'tear' || reason === 'breach' || reason === 'manual_stop') {
      return '强杀断开';
    }
    if (reason === 'partner_breach') {
      return '被搭子连坐';
    }
    if (reason === 'timeout') {
      return '超时失守';
    }
    return record.failed_reason;
  }

  private getShameDurationLabel(record: DuoShameRecord): string {
    return `坚持 ${record.actual_min}/${record.total_min} 分钟`;
  }

  private openShameRecord(record: DuoShameRecord, fallbackDate: string): void {
    const timeLabel = this.getShameRecordTime(record, fallbackDate);
    const message =
      `${timeLabel}\n` +
      `「${record.title}」\n` +
      `${this.getShameReasonLabel(record)} · ${this.getShameDurationLabel(record)}\n` +
      `${this.getShameModeLabel(record)}`;
    this.getUIContext().showAlertDialog({
      title: '社死耻辱证',
      message,
      autoCancel: true,
      primaryButton: {
        value: '生成海报',
        fontColor: AppTheme.colors.danger,
        action: () => {
          showToast('社死耻辱证生成功能下一版接入', this.getUIContext());
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  @Builder
  private buildSegmentButton(section: StatsDetailSection, title: string): void {
    Text(title)
      .layoutWeight(1)
      .fontSize(15)
      .fontWeight(this.currentSection === section ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.currentSection === section ? AppTheme.colors.primary : AppTheme.colors.textSecondary)
      .textAlign(TextAlign.Center)
      .padding({ top: 10, bottom: 10 })
      .borderRadius(20)
      .backgroundColor(this.currentSection === section ? AppTheme.colors.primarySoft : Color.Transparent)
      .onClick(() => {
        this.currentSection = section;
      })
  }

  @Builder
  private buildStatusBlock(): void {
    if (this.isLoading) {
      Text(`正在加载${this.getPeriodLabel(this.currentPeriod)}完整战报...`)
        .fontSize(13)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .textAlign(TextAlign.Center)
    } else if (this.errorMessage.length > 0) {
      Text(this.errorMessage)
        .fontSize(13)
        .fontColor(AppTheme.colors.danger)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  private buildTimelineList(items: TimelineDetailItem[]): void {
    if (items.length === 0) {
      Column({ space: 8 }) {
        Text('当前周期还没有上岸记录。')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
        Text('先完成一局专注，这里会完整记录你的履约战绩。')
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
      }
      .width('100%')
      .padding(18)
      .backgroundColor('rgba(31,157,85,0.08)')
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: 'rgba(31,157,85,0.18)' })
      .alignItems(HorizontalAlign.Start)
    } else {
      Column({ space: 0 }) {
        ForEach(items, (item: TimelineDetailItem) => {
          Column({ space: 0 }) {
            Column({ space: 6 }) {
              Text(`${this.getTimelineRecordTime(item.record, item.day)} · 成功通关 ${item.record.actual_min} 分钟`)
                .fontSize(14)
                .fontColor(AppTheme.colors.textPrimary)
                .width('100%')
                .lineHeight(20)
              Text(`「${item.record.title}」· ${this.getTimelineModeLabel(item.record)}`)
                .fontSize(13)
                .fontColor(AppTheme.colors.textSecondary)
                .width('100%')
                .lineHeight(20)
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })

            Divider()
              .color(AppTheme.colors.border)
              .strokeWidth(1)
              .width('100%')
          }
          .width('100%')
        }, (item: TimelineDetailItem) => `${item.day}-${item.record.id}`)
      }
      .width('100%')
      .padding({ left: 18, right: 18 })
      .backgroundColor('rgba(31,157,85,0.08)')
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: 'rgba(31,157,85,0.18)' })
    }
  }

  @Builder
  private buildShameList(items: ShameDetailItem[]): void {
    if (items.length === 0) {
      Column({ space: 8 }) {
        Text('当前周期还没有违约记录。')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
        Text('很好，当前周期的清白记录仍然完好。')
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
      }
      .width('100%')
      .padding(18)
      .backgroundColor('#FFF0F0')
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: '#F3D6D6' })
      .alignItems(HorizontalAlign.Start)
    } else {
      Column({ space: 0 }) {
        ForEach(items, (item: ShameDetailItem) => {
          Column({ space: 0 }) {
            Column({ space: 6 }) {
              Text(`${this.getShameRecordTime(item.record, item.day)} · ${this.getShameReasonLabel(item.record)}（${this.getShameDurationLabel(item.record)}）`)
                .fontSize(14)
                .fontColor('#5A2020')
                .width('100%')
                .lineHeight(20)
              Text(`「${item.record.title}」· ${this.getShameModeLabel(item.record)}`)
                .fontSize(13)
                .fontColor('#9A5A5A')
                .width('100%')
                .lineHeight(20)
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 16, bottom: 16 })
            .backgroundColor('#FFF7F7')
            .onClick(() => {
              this.openShameRecord(item.record, item.day);
            })

            Divider()
              .color('#EECFCF')
              .strokeWidth(1)
              .width('100%')
          }
          .width('100%')
        }, (item: ShameDetailItem) => `${item.day}-${item.record.id}`)
      }
      .width('100%')
      .backgroundColor('#FFF0F0')
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: '#F3D6D6' })
    }
  }

  @Builder
  private buildPageBody(): void {
    List({ space: 18, scroller: this.listScroller }) {
      ListItem() {
        Row({ space: 8 }) {
          this.buildSegmentButton('timeline', '履约荣誉墙')
          this.buildSegmentButton('shame', '违约耻辱柱')
        }
        .width('100%')
        .padding(4)
        .backgroundColor(AppTheme.colors.surface)
        .borderRadius(AppTheme.radius.lg)
        .border({ width: 1, color: AppTheme.colors.border })
      }

      ListItem() {
        Column({ space: 18 }) {
          this.buildStatusBlock()
          if (!this.isLoading) {
            if (this.currentSection === 'timeline') {
              this.buildTimelineList(this.getTimelineItems())
            } else {
              this.buildShameList(this.getShameItems())
            }
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: `${this.getPeriodLabel(this.currentPeriod)}全部记录`,
        showBack: true,
        usePageScroll: false,
        bindScrollers: this.scrollerReady ? [this.listScroller] : [],
        horizontalPadding: 14,
        bottomSpacerHeight: 0,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildPageBody();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

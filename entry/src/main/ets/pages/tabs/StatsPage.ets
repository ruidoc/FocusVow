import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import {
  DuoShameDay,
  DuoShameRecord,
  DuoStatsSummary,
  DuoTimelineDay,
  DuoTimelineRecord
} from '../../models/DuoModel';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

type StatsPeriod = 'today' | 'week' | 'month';
type StatsDetailSection = 'timeline' | 'shame';

interface TimelinePreviewItem {
  day: string;
  record: DuoTimelineRecord;
}

interface ShamePreviewItem {
  day: string;
  record: DuoShameRecord;
}

@Component
export struct StatsPage {
  @State currentPeriod: StatsPeriod = 'today';
  @State summary: DuoStatsSummary | null = null;
  @State timeline: DuoTimelineDay[] = [];
  @State shame: DuoShameDay[] = [];
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  private reloadVersion: number = 0;

  aboutToAppear(): void {
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
    const requestVersion = ++this.reloadVersion;
    this.isLoading = true;
    this.errorMessage = '';

    if (!UserStore.isLoggedIn()) {
      this.errorMessage = '登录后可查看上岸时光轴与耻辱柱';
      this.summary = null;
      this.timeline = [];
      this.shame = [];
      this.isLoading = false;
      return;
    }

    const period = this.currentPeriod;
    const responses = await Promise.all([
      DuoApiService.getStatsSummary(period),
      DuoApiService.getStatsTimeline(period),
      DuoApiService.getStatsShame(period)
    ]);
    const summaryRes = responses[0];
    const timelineRes = responses[1];
    const shameRes = responses[2];

    if (requestVersion !== this.reloadVersion) {
      return;
    }

    if (summaryRes.statusCode !== 200 || timelineRes.statusCode !== 200 || shameRes.statusCode !== 200) {
      this.errorMessage = summaryRes.message ?? timelineRes.message ?? shameRes.message ?? '统计加载失败';
      showErrorToast(this.errorMessage, this.getUIContext());
    }

    this.summary = DuoApiService.parseSummary(summaryRes);
    const timelineData = DuoApiService.parseTimeline(timelineRes);
    const shameData = DuoApiService.parseShame(shameRes);
    this.timeline = timelineData?.items ?? [];
    this.shame = shameData?.items ?? [];
    this.isLoading = false;
  }

  private getSuccessMinutes(): number {
    return this.summary?.actual_mins ?? 0;
  }

  private getSuccessDurationLabel(): string {
    const minutes = this.getSuccessMinutes();
    if (minutes < 60) {
      return `${minutes} 分钟`;
    }
    const hours = Math.floor(minutes / 60);
    const remainMinutes = minutes % 60;
    if (remainMinutes === 0) {
      return `${hours} 小时`;
    }
    return `${hours} 小时 ${remainMinutes} 分钟`;
  }

  private getCompletedCount(): number {
    return this.summary?.completed_count ?? 0;
  }

  private getFailedCount(): number {
    return this.summary?.failed_count ?? 0;
  }

  private getContractWinRate(): number {
    return this.summary?.success_rate ?? 0;
  }

  private getDuoBlastCount(): number {
    let count = 0;
    for (let i = 0; i < this.shame.length; i++) {
      const day = this.shame[i];
      for (let j = 0; j < day.records.length; j++) {
        const record = day.records[j];
        if (record.participation_mode === 'duo' && record.breach_role === 'violator') {
          count += 1;
        }
      }
    }
    return count;
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

  private getTimelinePreviewItems(limit: number = 5): TimelinePreviewItem[] {
    const items: TimelinePreviewItem[] = [];
    for (let i = 0; i < this.timeline.length; i++) {
      const day = this.timeline[i];
      for (let j = 0; j < day.records.length; j++) {
        items.push({ day: day.date, record: day.records[j] });
        if (items.length >= limit) {
          return items;
        }
      }
    }
    return items;
  }

  private getShamePreviewItems(limit: number = 5): ShamePreviewItem[] {
    const items: ShamePreviewItem[] = [];
    for (let i = 0; i < this.shame.length; i++) {
      const day = this.shame[i];
      for (let j = 0; j < day.records.length; j++) {
        items.push({ day: day.date, record: day.records[j] });
        if (items.length >= limit) {
          return items;
        }
      }
    }
    return items;
  }

  private getTimelineRecordTime(record: DuoTimelineRecord, fallbackDate: string): string {
    const raw = record.completed_at ?? fallbackDate;
    return this.formatDateTimeLabel(raw, fallbackDate);
  }

  private getShameRecordTime(record: DuoShameRecord, fallbackDate: string): string {
    const raw = record.completed_at ?? fallbackDate;
    return this.formatDateTimeLabel(raw, fallbackDate);
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

  private getLeaderboardHint(): string {
    return `按${this.getPeriodLabel(this.currentPeriod)}数据更新`;
  }

  private openStatsDetail(section: StatsDetailSection): void {
    AppStorage.setOrCreate(StoreKeys.StatsDetailPeriod, this.currentPeriod);
    AppStorage.setOrCreate(StoreKeys.StatsDetailSection, section);
    pushRoute(PageRoutes.StatsDetail);
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
  private buildPeriodButton(period: StatsPeriod): void {
    Text(this.getPeriodLabel(period))
      .layoutWeight(1)
      .fontSize(15)
      .fontWeight(this.currentPeriod === period ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.currentPeriod === period ? AppTheme.colors.primary : AppTheme.colors.textSecondary)
      .textAlign(TextAlign.Center)
      .padding({ top: 10, bottom: 10 })
      .borderRadius(20)
      .backgroundColor(this.currentPeriod === period ? AppTheme.colors.primarySoft : Color.Transparent)
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
      Text(`正在加载${this.getPeriodLabel(this.currentPeriod)}战报...`)
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
      this.buildLoadingCard(112, AppTheme.colors.surface, AppTheme.colors.border)

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

      this.buildLoadingCard(132, 'rgba(31,157,85,0.08)', 'rgba(31,157,85,0.18)')
      this.buildLoadingCard(132, '#FFF0F0', '#F3D6D6')
    }
    .width('100%')
  }

  @Builder
  private buildSuccessCard(): void {
    Column({ space: 10 }) {
      Text(`${this.getPeriodLabel(this.currentPeriod)}成功专注`)
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
      Text(this.getSuccessDurationLabel())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)

      Row({ space: 2 }) {
        Text('完成')
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
        Text(`${this.getCompletedCount()}`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.success)
        Text('次，放弃')
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
        Text(`${this.getFailedCount()}`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.danger)
        Text('次')
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
        Text('（失败碎裂时间不计入）')
        .fontSize(12)
        .fontColor(AppTheme.colors.textMuted)
        .lineHeight(18)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      
    }
    .width('100%')
    .padding(20)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildCompactMetricCard(
    title: string,
    value: string,
    hint: string,
    backgroundColor: string = AppTheme.colors.surface,
    borderColor: string = AppTheme.colors.border,
    valueColor: string = AppTheme.colors.textPrimary,
    hintColor: string = AppTheme.colors.textMuted
  ): void {
    Column({ space: 6 }) {
      Text(title)
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
        .width('100%')
      Text(hint)
        .fontSize(11)
        .fontColor(hintColor)
        .width('100%')
        .lineHeight(18)
        .maxLines(2)
    }
    .padding(14)
    .backgroundColor(backgroundColor)
    .borderRadius(AppTheme.radius.md)
    .border({ width: 1, color: borderColor })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildContractBoard(): void {
    Column({ space: 12 }) {
      // Text('契约看板')
      //   .fontSize(17)
      //   .fontWeight(FontWeight.Medium)
      //   .fontColor(AppTheme.colors.textPrimary)
      //   .width('100%')

      Row({ space: 12 }) {
        Column() {
          this.buildCompactMetricCard(
            '连续上岸',
            `${this.summary?.streak_days ?? 0} 天`,
            `历史最长 ${this.summary?.best_streak_days ?? 0} 天`,
            AppTheme.colors.surface,
            AppTheme.colors.border,
            AppTheme.colors.textPrimary
          )
        }
        .layoutWeight(1)

        Column() {
          this.buildCompactMetricCard(
            '契约总胜率',
            `${this.getContractWinRate()}%`,
            this.getLeaderboardHint(),
            AppTheme.colors.surface,
            AppTheme.colors.border,
            AppTheme.colors.textPrimary
          )
        }
        .layoutWeight(1)

        Column() {
          this.buildCompactMetricCard(
            '连累搭子',
            `${this.getDuoBlastCount()} 次`,
            '信誉良好',
            AppTheme.colors.surface,
            AppTheme.colors.border,
            AppTheme.colors.textPrimary,
          )
        }
        .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private buildSectionTitle(title: string): void {
    Text(title)
      .fontSize(17)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppTheme.colors.textPrimary)
      .width('100%')
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
  }

  @Builder
  private buildTimelinePreviewList(items: TimelinePreviewItem[]): void {
    Column({ space: 0 }) {
      ForEach(items, (item: TimelinePreviewItem) => {
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
      }, (item: TimelinePreviewItem) => `${item.day}-${item.record.id}`)
    }
    .width('100%')
  }

  @Builder
  private buildShamePreviewList(items: ShamePreviewItem[]): void {
    Column({ space: 0 }) {
      ForEach(items, (item: ShamePreviewItem) => {
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
      }, (item: ShamePreviewItem) => `${item.day}-${item.record.id}`)
    }
    .width('100%')
  }

  @Builder
  private buildTimelineSection(): void {
    Column({ space: 10 }) {
      this.buildSectionHeader('🏆 履约荣誉墙', this.getTimelineCount(), () => {
        this.openStatsDetail('timeline');
      })

      if (this.timeline.length === 0) {
        Column({ space: 8 }) {
          Text('今天还没有留下上岸记录。')
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
          Text('先完成一局专注，这里会开始积累你的清白档案。')
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
          this.buildTimelinePreviewList(this.getTimelinePreviewItems())
        }
        .width('100%')
        .padding({ left: 18, right: 18 })
        .backgroundColor('rgba(31,157,85,0.08)')
        .borderRadius(AppTheme.radius.lg)
        .border({ width: 1, color: 'rgba(31,157,85,0.18)' })
      }
    }
    .width('100%')
  }

  @Builder
  private buildShameSection(): void {
    Column({ space: 16 }) {
      this.buildSectionHeader('💀 违约耻辱柱', this.getShameCount(), () => {
        this.openStatsDetail('shame');
      })

      Column({ space: 0 }) {
        Text('点击任一记录，直接生成「社死耻辱证」海报')
          .fontSize(13)
          .fontColor('#9A5A5A')
          .width('100%')
          .padding({ top: 16, bottom: 16, left: 18, right: 18 })

        if (this.shame.length === 0) {
          Column({ space: 10 }) {
            Text('耻辱柱目前是一片空白。')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#5A2020')
              .width('100%')
            Text('很好，看来你对手机的渴望还没战胜你的自律决心。')
              .fontSize(13)
              .fontColor('#9A5A5A')
              .width('100%')
              .lineHeight(20)
          }
          .width('100%')
          .padding(18)
          .alignItems(HorizontalAlign.Start)
        } else {
          Divider()
            .color('#EECFCF')
            .strokeWidth(1)
            .width('100%')

          this.buildShamePreviewList(this.getShamePreviewItems())
        }
      }
      .width('100%')
      .backgroundColor('#FFF0F0')
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: '#F3D6D6' })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  @Builder
  private buildStatsBody(): void {
    Column({ space: 18 }) {
      Row({ space: 8 }) {
        this.buildPeriodButton('today');
        this.buildPeriodButton('week');
        this.buildPeriodButton('month');
      }
      .width('100%')
      .padding(4)
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: AppTheme.colors.border })

      this.buildStatusNotice()
      if (this.isLoading) {
        this.buildLoadingState()
      } else {
        this.buildSuccessCard()
        this.buildContractBoard()
        this.buildTimelineSection()
        this.buildShameSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    SystemNavPage({
      title: '统计',
      showBack: false,
      horizontalPadding: 14,
      contentSpace: 18,
      bottomSpacerHeight: 0,
      content: (): void => {
        this.buildStatsBody();
      }
    })
  }
}

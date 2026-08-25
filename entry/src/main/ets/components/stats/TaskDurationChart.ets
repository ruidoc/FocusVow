import { AppTheme } from '../../constants/Theme';
import { StoreKeys } from '../../stores/StoreKeys';
import { DuoStatsTaskItem } from '../../models/DuoModel';
import { formatTaskDurationMinutes } from '../../services/StatsRecordUtil';

const BAR_PALETTE: string[] = [
  '#6366F1',
  '#06B6D4',
  '#7A5AF8',
  '#F59E0B',
  '#EC4899',
  '#8B5CF6',
  '#14B8A6',
  '#F97316'
];

const MIN_BAR_WIDTH_STANDARD: number = 25;
const MIN_BAR_WIDTH_LOW: number = 8;
const LOW_MAX_THRESHOLD_MIN: number = 25;

@Component
export struct TaskDurationChart {
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';
  @Prop @Watch('onDataChange') data: DuoStatsTaskItem[] = [];
  @Prop title: string = '专注时长分布';
  @Prop emptyHint: string = '完成几次专注后，这里会展示你常做的任务';
  @Prop visibleLimit: number = 6;
  onViewAll?: () => void;

  @State private sorted: DuoStatsTaskItem[] = [];
  @State private visible: DuoStatsTaskItem[] = [];
  @State private maxMins: number = 0;
  @State private totalMins: number = 0;
  @State private minBarWidth: number = MIN_BAR_WIDTH_STANDARD;
  @State private overflow: boolean = false;

  aboutToAppear(): void {
    this.refreshDerived();
  }

  onDataChange(): void {
    this.refreshDerived();
  }

  private refreshDerived(): void {
    const filtered: DuoStatsTaskItem[] = [];
    for (let i = 0; i < this.data.length; i++) {
      const item = this.data[i];
      if (item.actual_mins > 0 || item.task_count > 0) {
        filtered.push(item);
      }
    }
    filtered.sort((a: DuoStatsTaskItem, b: DuoStatsTaskItem) => b.actual_mins - a.actual_mins);
    this.sorted = filtered;
    this.overflow = filtered.length > this.visibleLimit;
    this.visible = filtered.slice(0, this.visibleLimit);
    let max = 0;
    let sum = 0;
    for (let i = 0; i < filtered.length; i++) {
      if (filtered[i].actual_mins > max) {
        max = filtered[i].actual_mins;
      }
      sum += filtered[i].actual_mins;
    }
    this.maxMins = max;
    this.totalMins = sum;
    this.minBarWidth =
      max > 0 && max < LOW_MAX_THRESHOLD_MIN ? MIN_BAR_WIDTH_LOW : MIN_BAR_WIDTH_STANDARD;
  }

  private getBarValue(item: DuoStatsTaskItem): number {
    if (this.maxMins <= 0) {
      return this.minBarWidth;
    }
    const ratio = item.actual_mins / this.maxMins;
    return Math.max(this.minBarWidth, Math.min(100, ratio * 100));
  }

  private getBarColor(index: number): string {
    return BAR_PALETTE[index % BAR_PALETTE.length];
  }

  private getSuccessLabel(item: DuoStatsTaskItem): string {
    if (item.task_count <= 0) {
      return '· 违约';
    }
    const rate = Math.round((item.success_count / item.task_count) * 100);
    return rate === 100 ? '· 履约' : '· 违约';
  }

  @Builder
  private buildBarRow(item: DuoStatsTaskItem, index: number): void {
    Column({ space: 6 }) {
      Row() {
        Row({ space: 8 }) {
          Blank()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor(this.getBarColor(index))
          Text(item.title)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .layoutWeight(1)
        .margin({ right: 12 })

        Row({ space: 8 }) {
          Text(formatTaskDurationMinutes(item.actual_mins))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
          Text(this.getSuccessLabel(item))
            .fontSize(11)
            .fontColor(AppTheme.colors.textMuted)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Row()
          .width(`${this.getBarValue(item)}%`)
          .height(10)
          .borderRadius(999)
          .backgroundColor(this.getBarColor(index))
      }
      .width('100%')
      .height(10)
      .borderRadius(999)
      .backgroundColor(AppTheme.colors.ring)
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
          Text(formatTaskDurationMinutes(this.totalMins))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(`共 ${this.sorted.length} 项任务`)
          .fontSize(11)
          .fontColor(AppTheme.colors.textMuted)
          .margin({ bottom: 4 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      if (this.sorted.length === 0) {
        Text(this.emptyHint)
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 16, bottom: 8 })
      } else {
        Column({ space: 12 }) {
          ForEach(this.visible, (item: DuoStatsTaskItem, index: number) => {
            this.buildBarRow(item, index)
          }, (item: DuoStatsTaskItem, index: number) => `${item.title}-${index}-${item.actual_mins}`)
        }
        .width('100%')

        if (this.overflow) {
          Text(`查看全部 (${this.sorted.length})`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textMuted)
            .margin({ top: 4 })
            .onClick(() => {
              this.onViewAll?.();
            })
        }
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
    .alignItems(HorizontalAlign.Start)
  }
}

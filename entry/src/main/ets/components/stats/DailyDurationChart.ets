import { AppTheme } from '../../constants/Theme';
import {
  alignWeekDays,
  dayOfMonth,
  durationDeltaText,
  isFutureDate,
  statsAnchorDate,
  StatsDayItem,
  weekdayLabel,
} from '../../models/StatsChartModel';
import { StoreKeys } from '../../stores/StoreKeys';

const BAR_MAX: number = 88;

@Component
export struct DailyDurationChart {
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';
  @Prop period: string = 'today';
  @Prop items: StatsDayItem[] = [];
  @Prop currentMins: number = 0;
  @Prop prevActualMins: number = 0;
  @Prop hasPrev: boolean = false;

  private chartItems(): StatsDayItem[] {
    return alignWeekDays(this.items, this.period);
  }

  private dense(): boolean {
    return this.chartItems().length > 7;
  }

  private maxMins(): number {
    const rows = this.chartItems();
    let max = 0;
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].actualMins > max) {
        max = rows[i].actualMins;
      }
    }
    return max;
  }

  private caption(mins: number): string {
    const value = Math.round(mins);
    if (value <= 0) {
      return '';
    }
    if (value < 60) {
      return `${value}分`;
    }
    const hours = Math.floor(value / 60);
    const remain = value % 60;
    return remain === 0 ? `${hours}时` : `${hours}时${remain}`;
  }

  private barHeight(mins: number, max: number): number {
    if (max <= 0 || mins <= 0) {
      return 4;
    }
    return Math.max(8, Math.round(BAR_MAX * mins / max));
  }

  private isAnchor(date: string): boolean {
    return date.slice(0, 10) === statsAnchorDate(this.period);
  }

  private barColor(item: StatsDayItem): string {
    if (item.actualMins <= 0) {
      return AppTheme.colors.ring;
    }
    if (this.isAnchor(item.date)) {
      return AppTheme.colors.primary;
    }
    return AppTheme.colors.primaryMuted;
  }

  private barWidth(): number {
    return this.dense() ? 8 : 14;
  }

  private deltaText(): string {
    if (!this.hasPrev) {
      return '';
    }
    return durationDeltaText(this.period, this.currentMins, this.prevActualMins);
  }

  @Builder
  private buildColumn(item: StatsDayItem, max: number): void {
    Column() {
      if (!this.dense()) {
        Text(this.caption(item.actualMins))
          .fontSize(10)
          .fontColor(this.isAnchor(item.date) ? AppTheme.colors.primary : AppTheme.colors.text3)
          .maxLines(1)
          .margin({ bottom: 4 })
          .height(14)
      }
      Column() {
        Column()
          .width(this.barWidth())
          .height(this.barHeight(item.actualMins, max))
          .borderRadius(999)
          .backgroundColor(this.barColor(item))
          .opacity(isFutureDate(item.date) ? 0.35 : 1)
      }
      .width('100%')
      .height(BAR_MAX)
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.Center)
      Text(this.dense() ? dayOfMonth(item.date) : weekdayLabel(item.date))
        .fontSize(11)
        .fontWeight(this.isAnchor(item.date) ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(this.isAnchor(item.date) ? AppTheme.colors.primary : AppTheme.colors.text3)
        .margin({ top: 6 })
      if (!this.dense()) {
        Text(dayOfMonth(item.date))
          .fontSize(10)
          .fontColor(AppTheme.colors.text3)
      }
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildBars(max: number): void {
    if (this.dense()) {
      Scroll() {
        Row({ space: 4 }) {
          ForEach(this.chartItems(), (item: StatsDayItem) => {
            Column() {
              this.buildColumn(item, max)
            }
            .width(28)
          }, (item: StatsDayItem) => item.date)
        }
        .alignItems(VerticalAlign.Bottom)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    } else {
      Row() {
        ForEach(this.chartItems(), (item: StatsDayItem) => {
          Column() {
            this.buildColumn(item, max)
          }
          .layoutWeight(1)
        }, (item: StatsDayItem) => item.date)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    }
  }

  build() {
    if (this.chartItems().length === 0 && this.deltaText().length === 0) {
      Column()
    } else {
      Column() {
        Row() {
          Text('每日专注对比')
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
          if (this.deltaText().length > 0) {
            Text(this.deltaText())
              .fontSize(12)
              .fontColor(AppTheme.colors.textSecondary)
              .layoutWeight(1)
              .textAlign(TextAlign.End)
              .margin({ left: 12 })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({ bottom: 16 })

        if (this.chartItems().length > 0) {
          this.buildBars(this.maxMins())
        }
      }
      .width('100%')
      .padding(20)
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(16)
      .alignItems(HorizontalAlign.Start)
    }
  }
}

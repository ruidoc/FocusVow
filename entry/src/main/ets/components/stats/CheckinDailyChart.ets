import { AppTheme } from '../../constants/Theme';
import {
  alignCheckinWeekDays,
  CheckinByDay,
  CheckinDayFlags,
  dayOfMonth,
  isFutureDate,
  statsAnchorDate,
  weekdayLabel,
} from '../../models/StatsChartModel';
import { StoreKeys } from '../../stores/StoreKeys';

const BAR_MAX: number = 88;
const SEGMENT: number = BAR_MAX / 3;
const COLOR_FOCUS: string = '#16B364';
const COLOR_WAKE: string = '#EF6820';
const COLOR_SLEEP: string = '#2E90FA';

@Component
export struct CheckinDailyChart {
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';
  @Prop period: string = 'today';
  @Prop data: CheckinByDay | null = null;

  private items(): CheckinDayFlags[] {
    return alignCheckinWeekDays(this.data?.items ?? [], this.period);
  }

  private dense(): boolean {
    return this.items().length > 7;
  }

  private barWidth(): number {
    return this.dense() ? 8 : 14;
  }

  private isAnchor(date: string): boolean {
    return date.slice(0, 10) === statsAnchorDate(this.period);
  }

  private segmentColor(kind: string, anchor: boolean): string {
    let base = COLOR_SLEEP;
    if (kind === 'focus') {
      base = COLOR_FOCUS;
    } else if (kind === 'wake') {
      base = COLOR_WAKE;
    }
    return anchor ? base : `${base}AA`;
  }

  private fillHeight(item: CheckinDayFlags): number {
    let count = 0;
    if (item.focus) {
      count++;
    }
    if (item.wake) {
      count++;
    }
    if (item.sleep) {
      count++;
    }
    return count * SEGMENT;
  }

  @Builder
  private buildLegend(color: string, label: string): void {
    Row({ space: 6 }) {
      Column()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(color)
      Text(label)
        .fontSize(11)
        .fontColor(AppTheme.colors.text3)
    }
  }

  @Builder
  private buildStack(item: CheckinDayFlags): void {
    Column() {
      if (item.sleep) {
        Column()
          .width('100%')
          .height(SEGMENT)
          .backgroundColor(this.segmentColor('sleep', this.isAnchor(item.date)))
      }
      if (item.wake) {
        Column()
          .width('100%')
          .height(SEGMENT)
          .backgroundColor(this.segmentColor('wake', this.isAnchor(item.date)))
      }
      if (item.focus) {
        Column()
          .width('100%')
          .height(SEGMENT)
          .backgroundColor(this.segmentColor('focus', this.isAnchor(item.date)))
      }
    }
    .width('100%')
    .height(this.fillHeight(item))
    .clip(true)
    .borderRadius(999)
  }

  @Builder
  private buildColumn(item: CheckinDayFlags): void {
    Column() {
      Column() {
        if (this.fillHeight(item) > 0) {
          this.buildStack(item)
        }
      }
      .width(this.barWidth())
      .height(BAR_MAX)
      .borderRadius(999)
      .clip(true)
      .justifyContent(FlexAlign.End)
      .backgroundColor(AppTheme.colors.ring)
      .opacity(isFutureDate(item.date) ? 0.35 : 1)
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
  private buildBars(): void {
    if (this.dense()) {
      Scroll() {
        Row({ space: 4 }) {
          ForEach(this.items(), (item: CheckinDayFlags) => {
            Column() {
              this.buildColumn(item)
            }
            .width(28)
          }, (item: CheckinDayFlags) => item.date)
        }
        .alignItems(VerticalAlign.Bottom)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    } else {
      Row() {
        ForEach(this.items(), (item: CheckinDayFlags) => {
          Column() {
            this.buildColumn(item)
          }
          .layoutWeight(1)
        }, (item: CheckinDayFlags) => item.date)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    }
  }

  build() {
    if (!this.data || this.items().length === 0) {
      Column()
    } else {
      Column() {
        Row() {
          Text('打卡统计')
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
          Text(`连续打卡 ${this.data.streakDays} 天`)
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        Column() {
          this.buildBars()
        }
        .width('100%')
        .margin({ top: 16 })

        Row({ space: 20 }) {
          this.buildLegend(COLOR_FOCUS, '专注')
          this.buildLegend(COLOR_WAKE, '早起')
          this.buildLegend(COLOR_SLEEP, '早睡')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 16 })
      }
      .width('100%')
      .padding(20)
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(16)
      .alignItems(HorizontalAlign.Start)
    }
  }
}

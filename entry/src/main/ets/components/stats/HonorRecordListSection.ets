import { HonorRecordRow } from './HonorRecordRow';
import { AppTheme } from '../../constants/Theme';
import {
  formatStatsDateTimeLabel,
  getParticipationModeTag,
  getShameSectionBorderColor,
  getShameSectionDividerColor,
  getStatsRecordSectionBgColor,
  HONOR_SECTION_BORDER_COLOR,
  HONOR_SECTION_DIVIDER_COLOR,
  HonorRecordItem,
  ShameRecordItem,
} from '../../services/StatsRecordUtil';
import { StoreKeys } from '../../stores/StoreKeys';

@Component
export struct HonorRecordListSection {
  @Prop items: HonorRecordItem[] = [];
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';
  onItemPress?: (item: HonorRecordItem) => void;

  build() {
    if (this.items.length === 0) {
      Column({ space: 8 }) {
        Text('当前周期还没有荣誉记录。')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
        Text('先完成一局专注，这里会完整记录你的履约战绩。')
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
      }
      .width('100%')
      .padding(18)
      .backgroundColor(getStatsRecordSectionBgColor())
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: HONOR_SECTION_BORDER_COLOR })
      .alignItems(HorizontalAlign.Start)
    } else {
      Column({ space: 0 }) {
        ForEach(this.items, (item: HonorRecordItem, index: number) => {
          Column({ space: 0 }) {
            HonorRecordRow({
              title: item.record.title,
              timeLabel: formatStatsDateTimeLabel(item.record.completed_at ?? item.day, item.day),
              modeTag: getParticipationModeTag(item.record.participation_mode),
              durationMinutes: item.record.actual_min,
              onPress: () => {
                this.onItemPress?.(item);
              }
            })

            if (index < this.items.length - 1) {
              Divider()
                .color(HONOR_SECTION_DIVIDER_COLOR)
                .strokeWidth(1)
                .width('100%')
            }
          }
          .width('100%')
        }, (item: HonorRecordItem) => `${item.day}-${item.record.id}`)
      }
      .width('100%')
      .padding({ left: 18, right: 18 })
      .backgroundColor(getStatsRecordSectionBgColor())
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: HONOR_SECTION_BORDER_COLOR })
    }
  }
}

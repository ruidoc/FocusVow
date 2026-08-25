import { ShameRecordRow } from './ShameRecordRow';
import { AppTheme } from '../../constants/Theme';
import {
  formatStatsDateTimeLabel,
  getParticipationModeTag,
  getShameSectionBorderColor,
  getShameSectionDividerColor,
  getStatsRecordSectionBgColor,
  ShameRecordItem,
} from '../../services/StatsRecordUtil';
import { StoreKeys } from '../../stores/StoreKeys';

@Component
export struct ShameRecordListSection {
  @Prop items: ShameRecordItem[] = [];
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';
  onItemPress?: (item: ShameRecordItem) => void;

  build() {
    if (this.items.length === 0) {
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
      .backgroundColor(getStatsRecordSectionBgColor())
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: getShameSectionBorderColor() })
      .alignItems(HorizontalAlign.Start)
    } else {
      Column({ space: 0 }) {
        ForEach(this.items, (item: ShameRecordItem, index: number) => {
          Column({ space: 0 }) {
            ShameRecordRow({
              title: item.record.title,
              timeLabel: formatStatsDateTimeLabel(item.record.completed_at ?? item.day, item.day),
              modeTag: getParticipationModeTag(item.record.participation_mode),
              actualMinutes: item.record.actual_min,
              totalMinutes: item.record.total_min,
              onPress: () => {
                this.onItemPress?.(item);
              }
            })

            if (index < this.items.length - 1) {
              Divider()
                .color(getShameSectionDividerColor())
                .strokeWidth(1)
                .width('100%')
            }
          }
          .width('100%')
        }, (item: ShameRecordItem) => `${item.day}-${item.record.id}`)
      }
      .width('100%')
      .padding({ left: 18, right: 18 })
      .backgroundColor(getStatsRecordSectionBgColor())
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: getShameSectionBorderColor() })
    }
  }
}

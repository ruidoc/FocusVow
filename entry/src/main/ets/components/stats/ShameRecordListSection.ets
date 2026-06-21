import { ShameRecordRow } from './ShameRecordRow';
import { AppTheme } from '../../constants/Theme';
import {
  formatStatsDateTimeLabel,
  getParticipationModeTag,
  SHAME_SECTION_BORDER_COLOR,
  SHAME_SECTION_DIVIDER_COLOR,
  ShameRecordItem,
  STATS_RECORD_SECTION_BG_COLOR
} from '../../services/StatsRecordUtil';

@Component
export struct ShameRecordListSection {
  @Prop items: ShameRecordItem[] = [];
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
      .backgroundColor(STATS_RECORD_SECTION_BG_COLOR)
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: SHAME_SECTION_BORDER_COLOR })
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
                .color(SHAME_SECTION_DIVIDER_COLOR)
                .strokeWidth(1)
                .width('100%')
            }
          }
          .width('100%')
        }, (item: ShameRecordItem) => `${item.day}-${item.record.id}`)
      }
      .width('100%')
      .padding({ left: 18, right: 18 })
      .backgroundColor(STATS_RECORD_SECTION_BG_COLOR)
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: SHAME_SECTION_BORDER_COLOR })
    }
  }
}

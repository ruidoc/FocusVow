import { AppTheme } from '../../constants/Theme';

const TITLE_ROW_HEIGHT: number = 20;

@Component
export struct HonorRecordRow {
  @Prop title: string = '';
  @Prop timeLabel: string = '';
  @Prop modeTag: string = '单人';
  @Prop durationMinutes: number = 0;
  onPress?: () => void;

  @Builder
  private buildModeTag(): void {
    Row() {
      Text(this.modeTag)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.success)
    }
    .height(TITLE_ROW_HEIGHT)
    .padding({ left: 8, right: 8 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.successSoft)
    .borderRadius(AppTheme.radius.pill)
    .flexShrink(0)
  }

  build() {
    Row({ space: 12 }) {
      Column({ space: 0 }) {
        Text(`${this.durationMinutes}`)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.success)
        Text('分钟')
          .fontSize(11)
          .fontColor(AppTheme.colors.textMuted)
      }
      .width(52)
      .alignItems(HorizontalAlign.Center)
      .flexShrink(0)

      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(this.title.length > 0 ? this.title : '专注契约')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .height(TITLE_ROW_HEIGHT)
            .lineHeight(TITLE_ROW_HEIGHT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .flexShrink(1)

          if (this.modeTag === '搭子') {
            this.buildModeTag()
          }
        }
        .width('100%')
        .height(TITLE_ROW_HEIGHT)
        .alignItems(VerticalAlign.Center)

        Text(this.timeLabel)
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([AppTheme.colors.textMuted])
        .flexShrink(0)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .onClick(() => {
      this.onPress?.();
    })
  }
}

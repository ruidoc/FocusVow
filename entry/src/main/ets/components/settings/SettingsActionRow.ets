import { AppTheme } from '../../constants/Theme';

@Component
export struct SettingsActionRow {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop description: string = '';
  @Prop symbol: Resource = $r('sys.symbol.square_grid_2x2');
  onPress?: () => void;

  build() {
    Button() {
      Row({ space: 14 }) {
        Row() {
          SymbolGlyph(this.symbol)
            .fontSize(18)
            .fontColor([AppTheme.colors.primary])
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.primarySoft)
        .borderRadius(18)

        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')

          if (this.description.length > 0) {
            Text(this.description)
              .fontSize(12)
              .fontColor(AppTheme.colors.textSecondary)
              .width('100%')
              .maxLines(2)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.value.length > 0) {
          Text(this.value)
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
        }

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([AppTheme.colors.textMuted])
      }
      .width('100%')
    }
    .width('100%')
    .type(ButtonType.Normal)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.md)
    .padding(16)
    .onClick(() => {
      this.onPress?.();
    })
  }
}

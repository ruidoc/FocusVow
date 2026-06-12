import { AppTheme } from '../../constants/Theme';

@Component
export struct PageHeader {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop showBack: boolean = false;
  @Prop showAction: boolean = false;
  @Prop actionSymbol: Resource = $r('sys.symbol.plus');
  onBack?: () => void;
  onAction?: () => void;

  build() {
    Row({ space: 12 }) {
      if (this.showBack) {
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor([AppTheme.colors.textPrimary])
        }
          .width(32)
          .height(32)
          .padding(0)
          .backgroundColor(Color.Transparent)
          .border({ width: 0 })
          .onClick(() => {
            this.onBack?.();
          })
      }

      Column({ space: 6 }) {
        Text(this.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')

        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
            .maxLines(2)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)

      if (this.showAction) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph(this.actionSymbol)
            .fontSize(18)
            .fontColor([AppTheme.colors.primary])
        }
          .width(40)
          .height(40)
          .backgroundColor(AppTheme.colors.primarySoft)
          .border({ width: 1, color: AppTheme.colors.border })
          .onClick(() => {
            this.onAction?.();
          })
      } else {
        Row()
          .width(40)
          .height(40)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .constraintSize({ minHeight: 40 })
  }
}

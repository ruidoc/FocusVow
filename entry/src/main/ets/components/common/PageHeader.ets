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
    Column({ space: 10 }) {
      Row() {
        if (this.showBack) {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(20)
              .fontColor([AppTheme.colors.textPrimary])
          }
            .width(40)
            .height(40)
            .backgroundColor(AppTheme.colors.surfaceRaised)
            .border({ width: 1, color: AppTheme.colors.border })
            .onClick(() => {
              this.onBack?.();
            })
        } else {
          Row()
            .width(40)
            .height(40)
        }

        Text(this.title)
          .layoutWeight(1)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)

        if (this.showAction) {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph(this.actionSymbol)
              .fontSize(20)
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

      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

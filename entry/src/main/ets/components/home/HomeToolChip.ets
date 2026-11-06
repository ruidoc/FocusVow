import { AppTheme } from '../../constants/Theme';
import { homeGlassCardBg } from '../../constants/HomeCardStyle';
import { HomeGlassSurface } from './HomeGlassSurface';

@Component
export struct HomeToolChip {
  @Prop label: string = '';
  @Prop symbol: Resource = $r('sys.symbol.star');
  @Prop iconColor: string = AppTheme.colors.primary;
  onPress?: () => void;

  @Builder
  private buildChipBody(): void {
    Column({ space: 0 }) {
      SymbolGlyph(this.symbol)
        .fontSize(22)
        .fontColor([this.iconColor])
      Text(this.label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .margin({ top: 6 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 8, bottom: 8 })
  }

  build() {
    Column() {
      HomeGlassSurface({
        glassBackgroundColor: homeGlassCardBg(),
        content: (): void => {
          this.buildChipBody();
        },
      })
    }
    .layoutWeight(1)
    .height(76)
    .borderRadius(16)
    .clip(true)
    .onClick(() => {
      if (this.onPress) {
        this.onPress();
      }
    })
  }
}

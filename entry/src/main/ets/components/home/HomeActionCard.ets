import { AppTheme } from '../../constants/Theme';
import { homeGlassCardBg } from '../../constants/HomeCardStyle';
import { StoreKeys } from '../../stores/StoreKeys';
import { HomeGlassSurface } from './HomeGlassSurface';

/** Harmony 色值为 #AARRGGBB */
function hexWithAlpha(hex: string, alpha: number): string {
  if (!hex.startsWith('#') || hex.length !== 7) {
    return hex;
  }
  const n = Math.round(Math.max(0, Math.min(1, alpha)) * 255);
  let aa = n.toString(16);
  if (aa.length < 2) {
    aa = `0${aa}`;
  }
  return `#${aa}${hex.substring(1)}`;
}

@Component
export struct HomeActionCard {
  @Prop label: string = '';
  @Prop symbol: Resource = $r('sys.symbol.star');
  @Prop iconColor: string = AppTheme.colors.primary;
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';
  onPress?: () => void;

  build() {
    Column() {
      HomeGlassSurface({
        glassBackgroundColor: homeGlassCardBg(),
        content: (): void => {
          this.buildCardContent();
        },
      })
    }
    .layoutWeight(1)
    .height(92)
    .borderRadius(12)
    .clip(true)
    .onClick(() => {
      this.onPress?.();
    })
  }

  @Builder
  private buildIconGlow(): void {
    Column()
      .width(40)
      .height(20)
      .borderRadius(10)
      .radialGradient({
        center: ['50%', '55%'],
        radius: '58%',
        colors: [
          [hexWithAlpha(this.iconColor, this.themeMode === 'dark' ? 0.42 : 0.34), 0.0],
          [hexWithAlpha(this.iconColor, this.themeMode === 'dark' ? 0.16 : 0.14), 0.45],
          [hexWithAlpha(this.iconColor, 0), 0.75],
        ],
      })
      .blur(6)
      .hitTestBehavior(HitTestMode.None)
      .translate({ y: 6 })
  }

  @Builder
  private buildCardContent(): void {
    Column({ space: 0 }) {
      Stack({ alignContent: Alignment.Center }) {
        this.buildIconGlow()
        SymbolGlyph(this.symbol)
          .fontSize(26)
          .fontColor([this.iconColor])
      }
      .width(36)
      .height(32)
      .clip(true)
      .margin({ bottom: 8 })

      Text(this.label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 12, bottom: 12 })
  }
}

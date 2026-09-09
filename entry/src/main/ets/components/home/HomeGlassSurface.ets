import { StoreKeys } from '../../stores/StoreKeys';

@Builder
function EmptyGlassBuilder(): void {
}

@Component
export struct HomeGlassSurface {
  @Prop glassBackgroundColor: string = '';
  /** 对齐 RN HomeGlassSurface：半透明底 + 背景模糊 */
  @Prop enableBlur: boolean = true;
  @Prop blurStyle: BlurStyle = BlurStyle.Thin;
  /** 对齐 RN tint="light"：暗色模式下仍用浅色模糊（今日卡内层指标区） */
  @Prop useLightBlurTint: boolean = false;
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';
  @BuilderParam content: () => void = EmptyGlassBuilder;

  private getBlurColorMode(): ThemeColorMode {
    if (this.useLightBlurTint) {
      return ThemeColorMode.LIGHT;
    }
    return this.themeMode === 'dark' ? ThemeColorMode.DARK : ThemeColorMode.LIGHT;
  }

  @Builder
  private buildGlassBackground(): void {
    if (this.enableBlur) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.glassBackgroundColor)
        .backgroundBlurStyle(this.blurStyle, {
          colorMode: this.getBlurColorMode(),
          adaptiveColor: AdaptiveColor.DEFAULT,
        })
    } else {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.glassBackgroundColor)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildGlassBackground()
      Column() {
        this.content()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}

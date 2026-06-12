import { LengthMetrics } from '@kit.ArkUI';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { AppTheme } from '../../constants/Theme';
import { backRoute } from '../../router/PageRoutes';

@Builder
function EmptyBuilder(): void {
}

@Component
export struct SystemNavPage {
  @Prop title: string = '';
  @Prop showBack: boolean = false;
  @Prop showAction: boolean = false;
  @Prop actionLabel: string = '操作';
  @Prop actionIcon: Resource = $r('sys.symbol.plus');
  @Prop horizontalPadding: number = 20;
  @Prop topSpacerHeight: number = 56;
  @Prop contentSpace: number = 16;
  @Prop bottomSpacerHeight: number = 24;
  onBack?: () => void;
  onAction?: () => void;

  @BuilderParam content: () => void = EmptyBuilder;

  private scroller: Scroller = new Scroller();

  @Builder
  private buildScrollContent(): void {
    Scroll(this.scroller) {
      Column({ space: this.contentSpace }) {
        Blank()
          .width('100%')
          .height(this.topSpacerHeight)

        Column({ space: this.contentSpace }) {
          this.content()
        }
        .width('100%')
        .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
        .alignItems(HorizontalAlign.Start)

        Blank()
          .width('100%')
          .height(this.bottomSpacerHeight)
      }
      .width('100%')
      .backgroundColor(AppTheme.colors.background)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  private handleBack(): boolean {
    if (!this.showBack) {
      return false;
    }
    if (this.onBack) {
      this.onBack();
    } else {
      backRoute();
    }
    return true;
  }

  build() {
    if (this.showAction) {
      HdsNavDestination() {
        this.buildScrollContent()
      }
      .titleMode(HdsNavDestinationTitleMode.MINI)
      .hideBackButton(!this.showBack)
      .bindToScrollable([this.scroller])
      .onBackPressed(() => this.handleBack())
      .titleBar({
        padding: {
          start: LengthMetrics.vp(4),
          end: LengthMetrics.vp(4)
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.COMMON_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(0),
            blurEffectiveEndOffset: LengthMetrics.vp(18)
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: $r('sys.color.ohos_id_color_background')
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: $r('sys.color.ohos_id_color_background_transparent')
            }
          }
        },
        content: {
          title: {
            mainTitle: this.title
          },
          menu: {
            value: [{
              content: {
                label: this.actionLabel,
                icon: this.actionIcon,
                isEnabled: true,
                action: () => {
                  this.onAction?.();
                }
              }
            }]
          }
        }
      })
      .backgroundColor(AppTheme.colors.background)
      .width('100%')
      .height('100%')
    } else {
      HdsNavDestination() {
        this.buildScrollContent()
      }
      .titleMode(HdsNavDestinationTitleMode.MINI)
      .hideBackButton(!this.showBack)
      .bindToScrollable([this.scroller])
      .onBackPressed(() => this.handleBack())
      .titleBar({
        padding: {
          start: LengthMetrics.vp(4),
          end: LengthMetrics.vp(4)
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.COMMON_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(0),
            blurEffectiveEndOffset: LengthMetrics.vp(18)
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: $r('sys.color.ohos_id_color_background')
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: $r('sys.color.ohos_id_color_background_transparent')
            }
          }
        },
        content: {
          title: {
            mainTitle: this.title
          }
        }
      })
      .backgroundColor(AppTheme.colors.background)
      .width('100%')
      .height('100%')
    }
  }
}

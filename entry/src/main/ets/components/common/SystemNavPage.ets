import { common } from '@kit.AbilityKit';
import { LengthMetrics, window } from '@kit.ArkUI';
import {
  DividerShowType,
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { AppTheme } from '../../constants/Theme';

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
  @Prop usePageScroll: boolean = true;
  @Prop bindScrollers: Scroller[] = [];
  @Prop horizontalPadding: number = 16;
  @Prop topSpacerHeight: number = 56;
  @Prop titleBarBottomPadding: number = 30;
  @Prop showTitleBar: boolean = true;
  @Prop hiddenTitleTopPadding: number = 12;
  @Prop contentSpace: number = 16;
  @Prop bottomSpacerHeight: number = 24;
  onBack?: () => void;
  onAction?: () => void;

  @BuilderParam content: () => void = EmptyBuilder;

  private scroller: Scroller = new Scroller();
  @State private topSafeInsetVp: number = 0;

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    const hostContext = ctx as common.UIAbilityContext;
    const ui = this.getUIContext();
    window.getLastWindow(hostContext, (err, win) => {
      if (err.code) {
        return;
      }
      const systemAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topSafeInsetVp = ui.px2vp(systemAvoid.topRect.height);
    });
  }

  private getTopSpacerHeight(): number {
    if (this.showTitleBar) {
      return this.topSpacerHeight + this.titleBarBottomPadding;
    }
    return this.topSafeInsetVp + this.hiddenTitleTopPadding;
  }

  // 静态标题栏的高度
  private getStaticTopSpacerHeight(): number {
    if (this.showTitleBar) {
      return this.topSpacerHeight + this.titleBarBottomPadding;
    }
    return this.topSafeInsetVp + this.hiddenTitleTopPadding;
  }

  private getBindScrollers(): Scroller[] {
    if (this.usePageScroll || this.bindScrollers.length === 0) {
      return [this.scroller];
    }
    return this.bindScrollers;
  }

  @Builder
  private buildScrollContent(): void {
    Scroll(this.scroller) {
      Column({ space: this.contentSpace }) {
        Blank()
          .width('100%')
          .height(this.getTopSpacerHeight())

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
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(AppTheme.colors.background)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private buildStaticContent(): void {
    Column() {
      Blank()
        .width('100%')
        .height(this.getStaticTopSpacerHeight())

      Column() {
        this.content()
      }
      .width('100%')
      .layoutWeight(1)
      .padding({
        left: this.horizontalPadding,
        right: this.horizontalPadding,
        bottom: this.bottomSpacerHeight
      })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.background)
  }

  @Builder
  private buildPageContent(): void {
    if (this.usePageScroll) {
      this.buildScrollContent();
    } else {
      this.buildStaticContent();
    }
  }

  build() {
    if (this.showAction) {
      HdsNavigation() {
        this.buildPageContent()
      }
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideTitleBar(!this.showTitleBar)
      .hideBackButton(!this.showBack)
      .bindToScrollable(this.getBindScrollers())
      .titleBar({
        avoidLayoutSafeArea: true,
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(0),
            blurEffectiveEndOffset: LengthMetrics.vp(18)
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: '#FFFFFF'
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('sys.color.font_primary')
              },
              menuStyle: {
                iconColor: $r('sys.color.icon_primary')
              },
              backIconStyle: {
                iconColor: $r('sys.color.icon_primary')
              }
            }
          }
        },
        content: {
          title: {
            mainTitle: this.title
          },
          backIcon: this.showBack && this.onBack ? {
            label: 'back',
            icon: $r('sys.symbol.chevron_left'),
            isEnabled: true,
            action: () => {
              this.onBack?.();
            }
          } : undefined,
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
          },
          divider: {
            showType: DividerShowType.OFF
          }
        }
      })
      .backgroundColor(AppTheme.colors.background)
      .width('100%')
      .height('100%')
    } else {
      HdsNavigation() {
        this.buildPageContent()
      }
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideTitleBar(!this.showTitleBar)
      .hideBackButton(!this.showBack)
      .bindToScrollable(this.getBindScrollers())
      .titleBar({
        avoidLayoutSafeArea: true,
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(0),
            blurEffectiveEndOffset: LengthMetrics.vp(23)
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: '#FFFFFF'
            },
            contentStyle: {
              titleStyle: {
                mainTitleColor: $r('sys.color.font_primary')
              },
              backIconStyle: {
                iconColor: $r('sys.color.icon_primary')
              }
            }
          }
        },
        content: {
          title: {
            mainTitle: this.title
          },
          backIcon: this.showBack && this.onBack ? {
            label: 'back',
            icon: $r('sys.symbol.chevron_left'),
            isEnabled: true,
            action: () => {
              this.onBack?.();
            }
          } : undefined,
          divider: {
            showType: DividerShowType.OFF
          }
        }
      })
      .backgroundColor(AppTheme.colors.background)
      .width('100%')
      .height('100%')
    }
  }
}

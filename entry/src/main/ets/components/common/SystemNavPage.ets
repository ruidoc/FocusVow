import { common } from '@kit.AbilityKit';
import { LengthMetrics, window } from '@kit.ArkUI';
import {
  DividerShowType,
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { AppTheme, resolveContentMaxWidthVp } from '../../constants/Theme';
import { FLOATING_TAB_EXTRA_BOTTOM_VP } from '../../pages/tabs/MainTabUtil';
import { StoreKeys } from '../../stores/StoreKeys';

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
  @Prop showActionIcon: boolean = true;
  @Prop usePageScroll: boolean = true;
  @Prop bindScrollers: Scroller[] = [];
  @Prop horizontalPadding: number = 16;
  @Prop topSpacerHeight: number = 56;
  @Prop titleBarBottomPadding: number = 30;
  @Prop showTitleBar: boolean = true;
  @Prop hiddenTitleTopPadding: number = 12;
  @Prop contentSpace: number = 16;
  @Prop bottomSpacerHeight: number = 24;
  @Prop useFloatingTabInset: boolean = true;
  @Prop pageBackgroundColor: string = AppTheme.colors.background;
  @Prop titleBarBackgroundColor: string = '#FFFFFF';
  @StorageLink(StoreKeys.MainTabFloatingBar) floatingTabBar: boolean = false;
  onBack?: () => void;
  onAction?: () => void;

  @BuilderParam content: () => void = EmptyBuilder;

  private scroller: Scroller = new Scroller();
  @State private topSafeInsetVp: number = 0;
  /** 取窗口短边宽度：竖屏铺满，横屏与竖屏同宽 */
  @State private contentMaxWidthVp: number = Number.MAX_VALUE;
  private mainWindow: window.Window | undefined = undefined;

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
      this.mainWindow = win;
      const systemAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topSafeInsetVp = ui.px2vp(systemAvoid.topRect.height);
      this.syncContentMaxWidth(win);
      win.on('windowSizeChange', () => {
        this.syncContentMaxWidth(win);
      });
    });
  }

  aboutToDisappear(): void {
    if (this.mainWindow !== undefined) {
      this.mainWindow.off('windowSizeChange');
      this.mainWindow = undefined;
    }
  }

  private syncContentMaxWidth(win: window.Window): void {
    const ui = this.getUIContext();
    const rect = win.getWindowProperties().windowRect;
    this.contentMaxWidthVp = resolveContentMaxWidthVp(
      ui.px2vp(rect.width),
      ui.px2vp(rect.height)
    );
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

  private getEffectiveBottomSpacerHeight(): number {
    const floatingExtra = (this.floatingTabBar && this.useFloatingTabInset)
      ? FLOATING_TAB_EXTRA_BOTTOM_VP
      : 0;
    return this.bottomSpacerHeight + floatingExtra;
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
        .constraintSize({ maxWidth: this.contentMaxWidthVp })
        .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
        .alignItems(HorizontalAlign.Start)

        Blank()
          .width('100%')
          .height(this.getEffectiveBottomSpacerHeight())
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.pageBackgroundColor)
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
      .constraintSize({ maxWidth: this.contentMaxWidthVp })
      .layoutWeight(1)
      .padding({
        left: this.horizontalPadding,
        right: this.horizontalPadding,
        bottom: this.getEffectiveBottomSpacerHeight()
      })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.pageBackgroundColor)
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
      // 默认 Auto 会在宽屏自动 Split，右侧出现空内容区；强制 Stack 保持单栏全宽
      .mode(NavigationMode.Stack)
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
              backgroundColor: this.titleBarBackgroundColor
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
                icon: this.showActionIcon ? this.actionIcon : undefined,
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
      .backgroundColor(this.pageBackgroundColor)
      .width('100%')
      .height('100%')
    } else {
      HdsNavigation() {
        this.buildPageContent()
      }
      // 默认 Auto 会在宽屏自动 Split，右侧出现空内容区；强制 Stack 保持单栏全宽
      .mode(NavigationMode.Stack)
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
              backgroundColor: this.titleBarBackgroundColor
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
      .backgroundColor(this.pageBackgroundColor)
      .width('100%')
      .height('100%')
    }
  }
}

import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppTheme, resolveContentMaxWidthVp } from '../../constants/Theme';
import { PageHeader } from './PageHeader';

type PageHeaderMode = 'default' | 'custom' | 'none';

@Builder
function EmptyBuilder(): void {
}

@Component
export struct PageScaffold {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop showBack: boolean = false;
  @Prop showAction: boolean = false;
  @Prop actionSymbol: Resource = $r('sys.symbol.plus');
  @Prop headerMode: PageHeaderMode = 'default';
  @Prop topPadding: number = 22;
  @Prop horizontalPadding: number = 20;
  @Prop bottomPadding: number = 20;
  @Prop showDecoration: boolean = true;
  @Prop scrollPage: boolean = false;
  /** 是否在 topPadding 上额外叠加状态栏高度（与系统 TitleBar 同用时建议关） */
  @Prop includeTopSafeInset: boolean = true;
  /** 是否在 bottomPadding 上额外叠加上滑指示条/导航条区域 */
  @Prop includeBottomSafeInset: boolean = true;
  /** custom 标题栏是否横向通栏（如 ComposeTitleBar）；为 true 时仅内容区保留 horizontalPadding */
  @Prop fullBleedCustomHeader: boolean = false;
  onBack?: () => void;
  onAction?: () => void;

  @BuilderParam header: () => void = EmptyBuilder;
  @BuilderParam content: () => void = EmptyBuilder;

  @State private topSafeInsetVp: number = 0;
  @State private bottomSafeInsetVp: number = 0;
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
      const navIndicatorAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.topSafeInsetVp = ui.px2vp(systemAvoid.topRect.height);
      this.bottomSafeInsetVp = ui.px2vp(navIndicatorAvoid.bottomRect.height);
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

  private getPaddingTop(): number {
    const extraTop = this.includeTopSafeInset ? this.topSafeInsetVp : 0;
    return this.topPadding + extraTop;
  }

  private getPaddingBottom(): number {
    const extraBottom = this.includeBottomSafeInset ? this.bottomSafeInsetVp : 0;
    return this.bottomPadding + extraBottom;
  }

  private isFullBleedCustomHeader(): boolean {
    return this.fullBleedCustomHeader && this.headerMode === 'custom';
  }

  @Builder
  private buildDecoration(): void {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppTheme.colors.background)

      Column()
        .width(220)
        .height(220)
        .borderRadius(110)
        .backgroundColor(AppTheme.colors.primarySoft)
        .opacity(0.9)
        .blur(36)
        .position({ x: '-12%', y: '-6%' })

      Column()
        .width(180)
        .height(180)
        .borderRadius(90)
        .backgroundColor(AppTheme.colors.primarySoft)
        .opacity(0.65)
        .blur(28)
        .position({ x: '66%', y: '-2%' })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildPageBody(): void {
    Column({ space: 16 }) {
      if (this.headerMode === 'custom') {
        this.header()
      } else if (this.headerMode === 'default' && (this.title.length > 0 || this.showBack)) {
        PageHeader({
          title: this.title,
          subtitle: this.subtitle,
          showBack: this.showBack,
          showAction: this.showAction,
          actionSymbol: this.actionSymbol,
          onBack: this.onBack,
          onAction: this.onAction
        })
      }

      if (this.scrollPage) {
        this.content()
      } else {
        Column() {
          this.content()
        }
        .width('100%')
        .layoutWeight(1)
        .padding({
          left: this.isFullBleedCustomHeader() ? this.horizontalPadding : 0,
          right: this.isFullBleedCustomHeader() ? this.horizontalPadding : 0
        })
      }
    }
    .width('100%')
    .height(this.scrollPage ? undefined : '100%')
  }

  build() {
    Stack() {
      if (this.showDecoration) {
        this.buildDecoration()
      }

      if (this.scrollPage) {
        Scroll() {
          Column() {
            Column() {
              this.buildPageBody()
            }
            .width('100%')
            .constraintSize({ maxWidth: this.contentMaxWidthVp })
            .padding({
              left: this.isFullBleedCustomHeader() ? 0 : this.horizontalPadding,
              right: this.isFullBleedCustomHeader() ? 0 : this.horizontalPadding,
              top: this.getPaddingTop(),
              bottom: this.getPaddingBottom()
            })
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .alignItems(HorizontalAlign.Center)
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      } else {
        Column() {
          Column() {
            this.buildPageBody()
          }
          .width('100%')
          .constraintSize({ maxWidth: this.contentMaxWidthVp })
          .layoutWeight(1)
          .padding({
            left: this.isFullBleedCustomHeader() ? 0 : this.horizontalPadding,
            right: this.isFullBleedCustomHeader() ? 0 : this.horizontalPadding,
            top: this.getPaddingTop(),
            bottom: this.getPaddingBottom()
          })
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.colors.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

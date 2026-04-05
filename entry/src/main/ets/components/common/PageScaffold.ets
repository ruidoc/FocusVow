import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../../constants/Theme';
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
  @Prop headerMode: PageHeaderMode = 'default';
  @Prop topPadding: number = 22;
  @Prop horizontalPadding: number = 20;
  @Prop bottomPadding: number = 20;
  @Prop showDecoration: boolean = true;
  /** 是否在 topPadding 上额外叠加状态栏高度（与系统 TitleBar 同用时建议关） */
  @Prop includeTopSafeInset: boolean = true;
  /** 是否在 bottomPadding 上额外叠加上滑指示条/导航条区域 */
  @Prop includeBottomSafeInset: boolean = true;
  /** custom 标题栏是否横向通栏（如 ComposeTitleBar）；为 true 时仅内容区保留 horizontalPadding */
  @Prop fullBleedCustomHeader: boolean = false;
  onBack?: () => void;

  @BuilderParam header: () => void = EmptyBuilder;
  @BuilderParam content: () => void = EmptyBuilder;

  @State private topSafeInsetVp: number = 0;
  @State private bottomSafeInsetVp: number = 0;

  private readonly starIndexes: number[] = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
    10, 11, 12, 13, 14, 15, 16, 17,
    18, 19, 20, 21, 22, 23
  ];

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
      const navIndicatorAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.topSafeInsetVp = ui.px2vp(systemAvoid.topRect.height);
      this.bottomSafeInsetVp = ui.px2vp(navIndicatorAvoid.bottomRect.height);
    });
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

  private getStarLeft(index: number): string {
    return `${(index * 37 + 11) % 100}%`;
  }

  private getStarTop(index: number): string {
    return `${(index * 19 + 7) % 100}%`;
  }

  private getStarOpacity(index: number): number {
    return index % 3 === 0 ? 0.28 : (index % 3 === 1 ? 0.18 : 0.12);
  }

  @Builder
  private buildDecoration(): void {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppTheme.colors.background)

      ForEach(this.starIndexes, (item: number) => {
        Column()
          .width(item % 5 === 0 ? 3 : 2)
          .height(item % 5 === 0 ? 3 : 2)
          .borderRadius(2)
          .backgroundColor('#FFFFFF')
          .opacity(this.getStarOpacity(item))
          .position({
            x: this.getStarLeft(item),
            y: this.getStarTop(item)
          })
      }, (item: number) => item.toString())
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      if (this.showDecoration) {
        this.buildDecoration()
      }

      Column({ space: 16 }) {
        if (this.headerMode === 'custom') {
          this.header()
        } else if (this.headerMode === 'default' && (this.title.length > 0 || this.showBack)) {
          PageHeader({
            title: this.title,
            subtitle: this.subtitle,
            showBack: this.showBack,
            onBack: this.onBack
          })
        }

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
      .width('100%')
      .height('100%')
      .padding({
        left: this.isFullBleedCustomHeader() ? 0 : this.horizontalPadding,
        right: this.isFullBleedCustomHeader() ? 0 : this.horizontalPadding,
        top: this.getPaddingTop(),
        bottom: this.getPaddingBottom()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.colors.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

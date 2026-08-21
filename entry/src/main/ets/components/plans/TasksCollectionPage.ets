import { common } from '@kit.AbilityKit';
import { showToast } from '../../common/Toast';
import { AppTheme } from '../../constants/Theme';
import { SystemNavPage } from '../common/SystemNavPage';
import { PlanListContent } from './PlanListContent';
import { QuickTaskListContent } from './QuickTaskListContent';
import { TasksTabTitleBar } from './TasksTabTitleBar';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { LockStore } from '../../stores/LockStore';
import { UserStore } from '../../stores/UserStore';
import { ScheduledListStore } from '../../stores/ScheduledListStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Component
export struct TasksCollectionPage {
  @Prop showBack: boolean = false;
  @Prop isPageActive: boolean = true;

  @State private subTabIndex: number = 0;
  /** 0=快捷任务，1=定时任务；跟手滑动时为连续值 */
  @State private tabProgress: number = 0;
  @State private swiperWidth: number = 0;

  private readonly swiperAnimDuration: number = 300;
  private swiperController: SwiperController = new SwiperController();
  private quickScroller: Scroller = new Scroller();
  private scheduledScroller: Scroller = new Scroller();
  @State private quickScrollerReady: boolean = false;
  @State private scheduledScrollerReady: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    ScheduledListStore.hydrate();

    if (AppStorage.get<boolean>(StoreKeys.OpenQuickTaskTabOnce) === true) {
      AppStorage.setOrCreate(StoreKeys.OpenQuickTaskTabOnce, false);
      this.subTabIndex = 0;
      this.tabProgress = 0;
    } else {
      const saved = AppStorage.get<number>(StoreKeys.TasksSubTabIndex) ?? 0;
      this.subTabIndex = saved === 1 ? 1 : 0;
      this.tabProgress = this.subTabIndex;
    }
  }

  private onSubTabChange(index: number): void {
    this.subTabIndex = index;
    AppStorage.setOrCreate(StoreKeys.TasksSubTabIndex, index);
  }

  /** 与 RN PagerView 一致：progress = pageIndex - offset / pageWidth */
  private updateTabProgressFromOffset(pageIndex: number, currentOffset: number): void {
    if (this.swiperWidth <= 0) {
      this.tabProgress = pageIndex;
      return;
    }
    const next = pageIndex - (currentOffset / this.swiperWidth);
    this.tabProgress = Math.max(0, Math.min(1, next));
  }

  /** 松手惯性 / 点击 Tab：Swiper 内部动画，用 animateTo 跟 Swiper 同步补帧 */
  private animateTabProgressToTarget(pageIndex: number, targetIndex: number, extraInfo: SwiperAnimationEvent): void {
    this.updateTabProgressFromOffset(pageIndex, extraInfo.currentOffset);
    if (Math.abs(this.tabProgress - targetIndex) < 0.001) {
      this.tabProgress = targetIndex;
      return;
    }
    this.getUIContext().animateTo({
      duration: this.swiperAnimDuration,
      curve: Curve.EaseOut,
      onFinish: () => {
        this.tabProgress = targetIndex;
      }
    }, () => {
      this.tabProgress = targetIndex;
    });
  }

  private goToTab(index: number): void {
    if (this.subTabIndex === index) {
      return;
    }
    this.swiperController.changeIndex(index, true);
  }

  private openCreate(): void {
    if (!UserStore.isLoggedIn()) {
      showToast('请先登录', this.getUIContext());
      pushRoute(PageRoutes.Login);
      return;
    }
    if (LockStore.isLocked()) {
      const message = this.subTabIndex === 0
        ? '专注进行中，不可以创建任务'
        : '专注进行中，不可以创建契约';
      showToast(message, this.getUIContext());
      return;
    }
    if (this.subTabIndex === 0) {
      AppStorage.setOrCreate(StoreKeys.QuickTaskCurrentId, '');
      pushRoute(PageRoutes.QuickTaskForm);
      return;
    }
    AppStorage.setOrCreate(StoreKeys.ScheduledSessionCurrentId, '');
    ScheduledListStore.clearEditingSession();
    pushRoute(PageRoutes.PlanAdd);
  }

  @Builder
  private buildTabHeader(): void {
    Row() {
      Row() {
        TasksTabTitleBar({
          progress: this.tabProgress,
          onTabPress: (index: number) => {
            this.goToTab(index);
          }
        })
      }
      .layoutWeight(1)
      .padding({ left: 20 })
      .alignItems(VerticalAlign.Bottom)
      .height(34)

      Row() {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(22)
          .fontColor([AppTheme.colors.textPrimary])
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .justifyContent(FlexAlign.Center)
      .margin({ right: 20 })
      .onClick(() => {
        this.openCreate();
      })
    }
    .width('100%')
    .padding({ bottom: 4 })
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  private buildPager(): void {
    Swiper(this.swiperController) {
      QuickTaskListContent({
        isPageActive: this.isPageActive,
        onCreateTask: () => {
          this.openCreate();
        },
        onScrollerReady: (scroller: Scroller) => {
          this.quickScroller = scroller;
          this.quickScrollerReady = true;
        }
      })
      PlanListContent({
        isPageActive: this.isPageActive,
        onCreatePlan: () => {
          this.openCreate();
        },
        onScrollerReady: (scroller: Scroller) => {
          this.scheduledScroller = scroller;
          this.scheduledScrollerReady = true;
        }
      })
    }
    .index(this.subTabIndex)
    .indicator(false)
    .loop(false)
    .cachedCount(1)
    .duration(this.swiperAnimDuration)
    .curve(Curve.EaseOut)
    .layoutWeight(1)
    .width('100%')
    .onAreaChange((_old: Area, area: Area) => {
      const width = Number(area.width);
      if (width > 0) {
        this.swiperWidth = width;
      }
    })
    .onGestureSwipe((index: number, extraInfo: SwiperAnimationEvent) => {
      this.updateTabProgressFromOffset(index, extraInfo.currentOffset);
    })
    .onAnimationStart((index: number, targetIndex: number, extraInfo: SwiperAnimationEvent) => {
      this.animateTabProgressToTarget(index, targetIndex, extraInfo);
    })
    .onAnimationEnd((index: number, _extraInfo: SwiperAnimationEvent) => {
      this.tabProgress = index;
    })
    .onChange((index: number) => {
      this.onSubTabChange(index);
    })
  }

  @Builder
  private buildContent(): void {
    Column() {
      this.buildTabHeader()
      this.buildPager()
    }
    .width('100%')
    .height('100%')
  }

  build() {
    SystemNavPage({
      title: '',
      showTitleBar: this.showBack,
      showBack: this.showBack,
      showAction: false,
      usePageScroll: false,
      horizontalPadding: 0,
      topSpacerHeight: 8,
      titleBarBottomPadding: 0,
      hiddenTitleTopPadding: 0,
      bindScrollers: this.subTabIndex === 0
        ? (this.quickScrollerReady ? [this.quickScroller] : [])
        : (this.scheduledScrollerReady ? [this.scheduledScroller] : []),
      onBack: () => {
        backRoute();
      },
      content: (): void => {
        this.buildContent();
      }
    })
  }
}

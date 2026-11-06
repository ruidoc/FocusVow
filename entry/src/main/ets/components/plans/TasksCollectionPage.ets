import { common } from '@kit.AbilityKit';
import { showToast } from '../../common/Toast';
import { SystemNavPage } from '../common/SystemNavPage';
import { QuickTaskListContent } from './QuickTaskListContent';
import { TasksTabTitleBar } from './TasksTabTitleBar';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { LockStore } from '../../stores/LockStore';
import { UserStore } from '../../stores/UserStore';
import { QuickTaskStore } from '../../stores/QuickTaskStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import {
  consumeOpenDuoTaskTabOnce,
  consumeOpenQuickTaskTabOnce,
} from '../../services/ScheduledCovenantService';

bootstrapStores();

@Component
export struct TasksCollectionPage {
  @Prop showBack: boolean = false;
  @Prop @Watch('onIsPageActiveChanged') isPageActive: boolean = true;

  @State private subTabIndex: number = 0;
  /** 0=快捷任务，1=互督任务；跟手滑动时为连续值 */
  @State private tabProgress: number = 0;
  @State private swiperWidth: number = 0;

  private readonly swiperAnimDuration: number = 300;
  private swiperController: SwiperController = new SwiperController();
  private quickScroller: Scroller = new Scroller();
  private duoScroller: Scroller = new Scroller();
  @State private quickScrollerReady: boolean = false;
  @State private duoScrollerReady: boolean = false;
  @StorageLink(StoreKeys.OpenDuoTaskTabOnce)
  @Watch('onOpenDuoTabOnceChanged')
  private openDuoTabOnce: boolean = false;
  @StorageLink(StoreKeys.TasksSubTabIndex)
  @Watch('onTasksSubTabIndexChanged')
  private tasksSubTabIndex: number = 0;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);

    const initialTab = this.resolveInitialTabIndex();
    this.subTabIndex = initialTab;
    this.tabProgress = initialTab;
    this.swiperController.changeIndex(initialTab, false);
  }

  private onTasksSubTabIndexChanged(): void {
    const next = AppStorage.get<number>(StoreKeys.TasksSubTabIndex) ?? 0;
    if (next !== 0 && next !== 1) {
      return;
    }
    this.goToTab(next, false);
  }

  private resolveInitialTabIndex(): number {
    if (consumeOpenDuoTaskTabOnce()) {
      return 1;
    }
    if (consumeOpenQuickTaskTabOnce()) {
      return 0;
    }
    const saved = AppStorage.get<number>(StoreKeys.TasksSubTabIndex) ?? 0;
    return saved === 1 ? 1 : 0;
  }

  private onOpenDuoTabOnceChanged(): void {
    if (!consumeOpenDuoTaskTabOnce()) {
      return;
    }
    this.goToTab(1, false);
  }

  private onIsPageActiveChanged(): void {
    if (!this.isPageActive) {
      return;
    }
    if (consumeOpenDuoTaskTabOnce()) {
      this.goToTab(1, false);
      return;
    }
    if (consumeOpenQuickTaskTabOnce()) {
      this.goToTab(0, false);
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

  private goToTab(index: number, animate: boolean = true): void {
    this.subTabIndex = index;
    this.tabProgress = index;
    AppStorage.setOrCreate(StoreKeys.TasksSubTabIndex, index);
    this.swiperController.changeIndex(index, animate);
  }

  private openCreate(): void {
    if (!UserStore.isLoggedIn()) {
      showToast('请先登录', this.getUIContext());
      pushRoute(PageRoutes.Login);
      return;
    }
    if (LockStore.isLocked()) {
      showToast('专注进行中，不可以创建任务', this.getUIContext());
      return;
    }
    QuickTaskStore.hydrate();
    if (this.subTabIndex === 0) {
      AppStorage.setOrCreate(StoreKeys.QuickTaskCurrentId, '');
      pushRoute(PageRoutes.QuickTaskForm);
      return;
    }
    pushRoute(PageRoutes.DuoCreate);
  }

  @Builder
  private buildTabHeader(): void {
    Row() {
      Row() {
        TasksTabTitleBar({
          progress: this.tabProgress,
          secondTabLabel: '互督任务',
          onTabPress: (index: number) => {
            this.goToTab(index);
          }
        })
      }
      .layoutWeight(1)
      .padding({ left: 20 })
      .alignItems(VerticalAlign.Bottom)
      .height(34)

      Row()
        .width(42)
        .height(42)
        .margin({ right: 20 })
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
      QuickTaskListContent({
        isPageActive: this.isPageActive,
        listMode: 'duo',
        onCreateTask: () => {
          this.openCreate();
        },
        onScrollerReady: (scroller: Scroller) => {
          this.duoScroller = scroller;
          this.duoScrollerReady = true;
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
        : (this.duoScrollerReady ? [this.duoScroller] : []),
      onBack: () => {
        backRoute();
      },
      content: (): void => {
        this.buildContent();
      }
    })
  }
}

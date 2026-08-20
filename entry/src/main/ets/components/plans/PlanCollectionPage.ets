import { common } from '@kit.AbilityKit';
import { showToast } from '../../common/Toast';
import { SystemNavPage } from '../common/SystemNavPage';
import { PlanListContent } from './PlanListContent';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { LockStore } from '../../stores/LockStore';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { ScheduledListStore } from '../../stores/ScheduledListStore';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Component
export struct PlanCollectionPage {
  @Prop title: string = '契约';
  @Prop showBack: boolean = false;
  @Prop isPageActive: boolean = true;

  private listScroller: Scroller = new Scroller();
  @State private scrollerReady: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    ScheduledListStore.hydrate();
  }

  private openCreatePlan(): void {
    if (!UserStore.isLoggedIn()) {
      showToast('请先登录', this.getUIContext());
      pushRoute(PageRoutes.Login);
      return;
    }
    if (LockStore.isLocked()) {
      showToast('专注进行中，不可以创建契约', this.getUIContext());
      return;
    }
    AppStorage.setOrCreate(StoreKeys.ScheduledSessionCurrentId, '');
    ScheduledListStore.clearEditingSession();
    pushRoute(PageRoutes.PlanAdd);
  }

  @Builder
  private buildContent(): void {
    PlanListContent({
      isPageActive: this.isPageActive,
      onCreatePlan: () => {
        this.openCreatePlan();
      },
      onScrollerReady: (scroller: Scroller) => {
        this.listScroller = scroller;
        this.scrollerReady = true;
      }
    })
  }

  build() {
    SystemNavPage({
      title: this.title,
      showBack: this.showBack,
      showAction: true,
      actionLabel: '新建',
      actionIcon: $r('sys.symbol.plus'),
      usePageScroll: false,
      bindScrollers: this.scrollerReady ? [this.listScroller] : [],
      onBack: this.showBack ? () => backRoute() : undefined,
      onAction: () => {
        this.openCreatePlan();
      },
      content: (): void => {
        this.buildContent();
      }
    })
  }
}

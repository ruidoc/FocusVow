import { common } from '@kit.AbilityKit';
import { SystemNavPage } from '../common/SystemNavPage';
import { PlanListContent } from './PlanListContent';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
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
    ScheduledListStore.hydrate();
  }

  @Builder
  private buildContent(): void {
    PlanListContent({
      isPageActive: this.isPageActive,
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
        if (!UserStore.isLoggedIn()) {
          pushRoute(PageRoutes.Login);
          return;
        }
        AppStorage.setOrCreate(StoreKeys.ScheduledSessionCurrentId, '');
        pushRoute(PageRoutes.PlanAdd);
      },
      content: (): void => {
        this.buildContent();
      }
    })
  }
}

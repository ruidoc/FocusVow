import { common } from '@kit.AbilityKit';
import { SystemNavPage } from '../common/SystemNavPage';
import { PlanListContent } from './PlanListContent';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { PlanStore } from '../../stores/PlanStore';

@Component
export struct PlanCollectionPage {
  @Prop title: string = '契约';
  @Prop showBack: boolean = false;

  private listScroller: Scroller = new Scroller();
  @State private scrollerReady: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    PlanStore.hydrate(hostContext);
  }

  @Builder
  private buildContent(): void {
    PlanListContent({
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
        PlanStore.setCurrentPlanId('');
        pushRoute(PageRoutes.PlanAdd);
      },
      content: (): void => {
        this.buildContent();
      }
    })
  }
}

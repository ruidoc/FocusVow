import { common } from '@kit.AbilityKit';
import { PageScaffold } from '../../components/common/PageScaffold';
import { PlanListContent } from '../../components/plans/PlanListContent';
import { FocusPlan } from '../../models/PlanModel';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { PlanStore } from '../../stores/PlanStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Entry
@Component
struct PlanListPage {
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    PlanStore.hydrate(hostContext);
  }

  private getPageSubtitle(): string {
    return this.planCollection.length > 0
      ? `共 ${this.planCollection.length} 条契约，按时间自动开始专注限制`
      : '创建契约后，可在固定时段自动开始专注'
  }

  @Builder
  private buildContent(): void {
    PlanListContent()
  }

  build() {
    Stack() {
      PageScaffold({
        title: '契约列表',
        subtitle: this.getPageSubtitle(),
        showDecoration: false,
        showBack: true,
        showAction: true,
        actionSymbol: $r('sys.symbol.plus'),
        headerMode: 'default',
        topPadding: 12,
        bottomPadding: 12,
        horizontalPadding: 20,
        onBack: () => backRoute(),
        onAction: () => {
          PlanStore.setCurrentPlanId('');
          pushRoute(PageRoutes.PlanAdd);
        },
        content: (): void => {
          this.buildContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

import { common } from '@kit.AbilityKit';
import { PageScaffold } from '../../components/common/PageScaffold';
import { PlanListContent } from '../../components/plans/PlanListContent';
import { FocusPlan } from '../../models/PlanModel';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { PlanStore } from '../../stores/PlanStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Component
export struct ContractTabPage {
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    PlanStore.hydrate(hostContext);
  }

  private getPageSubtitle(): string {
    return this.planCollection.length > 0
      ? `共 ${this.planCollection.length} 条契约，按时间自动开始专注限制`
      : '为固定时段创建专注契约，到点后自动开始'
  }

  @Builder
  private buildContent(): void {
    PlanListContent()
  }

  build() {
    PageScaffold({
      title: '契约',
      subtitle: this.getPageSubtitle(),
      showAction: true,
      actionSymbol: $r('sys.symbol.plus'),
      headerMode: 'default',
      showDecoration: false,
      topPadding: 12,
      bottomPadding: 12,
      horizontalPadding: 20,
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

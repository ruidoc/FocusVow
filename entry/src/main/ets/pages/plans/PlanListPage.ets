import { common } from '@kit.AbilityKit';
import { PageHeader } from '../../components/common/PageHeader';
import { PlanCard } from '../../components/plans/PlanCard';
import { AppTheme } from '../../constants/Theme';
import { FocusPlan, PlanFilterScope } from '../../models/PlanModel';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { PlanStore } from '../../stores/PlanStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Entry
@Component
struct PlanListPage {
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @StorageLink(StoreKeys.PlanFilterScope) filterScope: string = 'today';

  private readonly filterOptions: PlanFilterScope[] = ['today', 'all'];

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    PlanStore.hydrate(hostContext);
  }

  private getFilterLabel(scope: PlanFilterScope): string {
    switch (scope) {
      case 'today':
        return '今天';
      default:
        return '全部';
    }
  }

  private getVisiblePlans(): FocusPlan[] {
    return PlanStore.getFilteredPlans();
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        PageHeader({
          title: '计划列表',
          subtitle: this.planCollection.length > 0
            ? `当前共有 ${this.planCollection.length} 条本地契约，按 iOS 的列表/新增/详情结构拆分`
            : '先创建第一条本地契约，再继续补齐结构',
          showBack: true,
          onBack: () => backRoute()
        })

        Row({ space: 10 }) {
          ForEach(this.filterOptions, (item: PlanFilterScope) => {
            Button(this.getFilterLabel(item))
              .type(ButtonType.Capsule)
              .backgroundColor(this.filterScope === item ? AppTheme.colors.primary : AppTheme.colors.surface)
              .fontColor(this.filterScope === item ? '#FFFFFF' : AppTheme.colors.textPrimary)
              .border({ width: 1, color: this.filterScope === item ? AppTheme.colors.primary : AppTheme.colors.border })
              .onClick(() => {
                const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
                PlanStore.setFilterScope(hostContext, item);
                this.filterScope = item;
              })
          }, (item: PlanFilterScope) => item)
        }
        .width('100%')

        if (this.getVisiblePlans().length === 0) {
          Column({ space: 10 }) {
            Text('还没有契约计划')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textPrimary)
            Text('先去新增一条计划，后续就能在详情页继续编辑、启停和启动专注。')
              .fontSize(13)
              .fontColor(AppTheme.colors.textSecondary)
              .width('100%')
          }
          .width('100%')
          .padding(24)
          .backgroundColor(AppTheme.colors.surface)
          .border({ width: 1, color: AppTheme.colors.border })
          .borderRadius(24)
          .alignItems(HorizontalAlign.Start)
        } else {
          Column({ space: 12 }) {
            ForEach(this.getVisiblePlans(), (plan: FocusPlan) => {
              PlanCard({
                plan,
                onPress: () => {
                  PlanStore.setCurrentPlanId(plan.id);
                  pushRoute(PageRoutes.PlanDetail);
                }
              })
            }, (plan: FocusPlan) => plan.id)
          }
          .width('100%')
        }

        Button('新增计划')
          .width('100%')
          .height(52)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.primary)
          .fontColor('#FFFFFF')
          .onClick(() => {
            PlanStore.setCurrentPlanId('');
            pushRoute(PageRoutes.PlanAdd);
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28, bottom: 28 })
      .backgroundColor(AppTheme.colors.background)
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}

import { common } from '@kit.AbilityKit';
import { PageScaffold } from '../../components/common/PageScaffold';
import { PlanCard } from '../../components/plans/PlanCard';
import { AppTheme } from '../../constants/Theme';
import { FocusPlan, PlanFilterScope } from '../../models/PlanModel';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { removePlanGuardStrategy } from '../../services/ScreenTimeService';
import { PlanStore } from '../../stores/PlanStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Entry
@Component
struct PlanListPage {
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @StorageLink(StoreKeys.PlanFilterScope) filterScope: string = 'today';

  @State isRefreshing: boolean = false;
  @State statusMessage: string = '';

  private readonly filterOptions: PlanFilterScope[] = ['today', 'all'];

  aboutToAppear(): void {
    this.refreshPlans();
  }

  private refreshPlans(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    PlanStore.hydrate(hostContext);
    this.filterScope = PlanStore.getFilterScope();
    this.isRefreshing = false;
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

  private getPageSubtitle(): string {
    return this.planCollection.length > 0 ? `共 ${this.planCollection.length} 个契约` : '还没有创建契约';
  }

  private getSectionTitle(): string {
    return this.filterScope === 'today' ? '今日契约' : '全部契约';
  }

  private confirmDeletePlan(plan: FocusPlan): void {
    this.getUIContext().showAlertDialog({
      title: '删除契约',
      message: `确认删除「${plan.name}」吗？`,
      autoCancel: true,
      primaryButton: {
        value: '删除',
        fontColor: AppTheme.colors.danger,
        action: () => {
          void this.deletePlan(plan);
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  private async deletePlan(plan: FocusPlan): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const removeResult = await removePlanGuardStrategy(plan.id);
    if (!removeResult.ok) {
      this.statusMessage = removeResult.message;
      return;
    }

    PlanStore.removePlan(hostContext, plan.id);
    this.statusMessage = `已删除契约「${plan.name}」`;
  }

  @Builder
  private buildFilterRow(): void {
    Row({ space: 8 }) {
      ForEach(this.filterOptions, (item: PlanFilterScope) => {
        Button(this.getFilterLabel(item))
          .type(ButtonType.Capsule)
          .height(40)
          .backgroundColor(this.filterScope === item ? AppTheme.colors.primary : Color.Transparent)
          .fontColor(this.filterScope === item ? '#FFFFFF' : AppTheme.colors.textPrimary)
          .border({ width: 0 })
          .onClick(() => {
            const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
            PlanStore.setFilterScope(hostContext, item);
            this.filterScope = item;
          })
      }, (item: PlanFilterScope) => item)
    }
    .padding(4)
    .backgroundColor(AppTheme.colors.surfaceRaised)
    .borderRadius(AppTheme.radius.pill)
  }

  @Builder
  private buildSectionHeader(): void {
    Row() {
      Text(this.getSectionTitle())
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)

      Blank()

      Text(`${this.getVisiblePlans().length} 个`)
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
    }
    .width('100%')
  }

  @Builder
  private buildPlanBody(): void {
    Column({ space: 14 }) {
      this.buildFilterRow()
      this.buildSectionHeader()

      if (this.statusMessage.length > 0) {
        Text(this.statusMessage)
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
      }

      Refresh({ refreshing: $$this.isRefreshing }) {
        if (this.getVisiblePlans().length === 0) {
          Column({ space: 10 }) {
            Text('还没有契约计划')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textPrimary)
            Text('点击右上角新建第一条契约，后续就能继续编辑和自动锁定。')
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
          List({ space: 12 }) {
            ForEach(this.getVisiblePlans(), (plan: FocusPlan) => {
              ListItem() {
                Column() {
                  PlanCard({
                    plan,
                    onPress: () => {
                      PlanStore.setCurrentPlanId(plan.id);
                      pushRoute(PageRoutes.PlanDetail);
                    }
                  })
                }
                .gesture(
                  LongPressGesture({ duration: 500 })
                    .onAction(() => {
                      this.confirmDeletePlan(plan);
                    })
                )
              }
            }, (plan: FocusPlan) => plan.id)
          }
          .width('100%')
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .onRefreshing(() => {
        this.refreshPlans();
      })
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      PageScaffold({
        title: '计划列表',
        subtitle: this.getPageSubtitle(),
        showBack: true,
        showAction: true,
        actionSymbol: $r('sys.symbol.plus'),
        headerMode: 'default',
        showDecoration: false,
        topPadding: 12,
        bottomPadding: 12,
        horizontalPadding: 20,
        onBack: () => backRoute(),
        onAction: () => {
          PlanStore.setCurrentPlanId('');
          pushRoute(PageRoutes.PlanAdd);
        },
        content: (): void => {
          this.buildPlanBody();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

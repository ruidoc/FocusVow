import { common } from '@kit.AbilityKit';
import { PlanCard } from './PlanCard';
import { AppTheme } from '../../constants/Theme';
import {
  comparePlansForDisplay,
  FocusPlan,
  getPlanNextStartText,
  isPlanRunning
} from '../../models/PlanModel';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { removePlanGuardStrategy, syncPlanGuardStrategy } from '../../services/ScreenTimeService';
import { PlanStore } from '../../stores/PlanStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Component
export struct PlanListContent {
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  onScrollerReady?: (scroller: Scroller) => void;

  private listScroller: Scroller = new Scroller();
  @State isRefreshing: boolean = false;
  @State statusMessage: string = '';

  aboutToAppear(): void {
    this.onScrollerReady?.(this.listScroller);
    this.refreshPlans();
  }

  private refreshPlans(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    PlanStore.hydrate(hostContext);
    this.isRefreshing = false;
  }

  private getVisiblePlans(): FocusPlan[] {
    return [...this.planCollection].sort((left: FocusPlan, right: FocusPlan) => comparePlansForDisplay(left, right));
  }

  private getRunningPlanCount(): number {
    return this.planCollection.filter((plan: FocusPlan) => isPlanRunning(plan)).length;
  }

  private getEnabledPlanCount(): number {
    return this.planCollection.filter((plan: FocusPlan) => plan.enabled).length;
  }

  private getProtectedAppCount(): number {
    return this.planCollection.reduce((total: number, plan: FocusPlan) => total + plan.selectedCount, 0);
  }

  private getNextPlanSummary(): string {
    if (this.getRunningPlanCount() > 0) {
      return `当前有 ${this.getRunningPlanCount()} 条契约正在生效`;
    }

    const enabledPlans = this.getVisiblePlans().filter((plan: FocusPlan) => plan.enabled);
    if (enabledPlans.length === 0) {
      return '新建后可在指定时间自动开始专注限制';
    }

    return getPlanNextStartText(enabledPlans[0]);
  }

  private getNextPlanValue(): string {
    const enabledPlans = this.getVisiblePlans().filter((plan: FocusPlan) => plan.enabled);
    if (enabledPlans.length === 0) {
      return '--:--';
    }
    return enabledPlans[0].startTime;
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

  private async togglePlan(plan: FocusPlan): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    PlanStore.togglePlanEnabled(hostContext, plan.id, !plan.enabled);
    const nextPlan = PlanStore.getPlans().find((item: FocusPlan) => item.id === plan.id);
    if (!nextPlan) {
      return;
    }

    const result = await syncPlanGuardStrategy(nextPlan);
    this.statusMessage = result.message;
    this.refreshPlans();
  }

  @Builder
  private buildSummaryCard(title: string, value: string, detail: string): void {
    Column({ space: 6 }) {
      Text(title)
        .fontSize(12)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')

      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Text(detail)
        .fontSize(12)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
        .maxLines(2)
    }
    .padding(16)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildSummaryPanel(): void {
    Column({ space: 12 }) {
      Text('契约概览')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Row({ space: 10 }) {
        Column() {
          this.buildSummaryCard('已启用', `${this.getEnabledPlanCount()}`, '当前仍会自动生效的契约')
        }
        .layoutWeight(1)

        Column() {
          this.buildSummaryCard('进行中', `${this.getRunningPlanCount()}`, '此刻正在限制应用的契约')
        }
        .layoutWeight(1)
      }
      .width('100%')

      this.buildSummaryCard(
        '下一次开始',
        this.getNextPlanValue(),
        this.getNextPlanSummary()
      )
    }
    .width('100%')
    .padding({ top: 16 })
  }

  @Builder
  private buildSectionHeader(): void {
    Row() {
      Text('全部契约')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)

      Blank()

      Text(`${this.getVisiblePlans().length} 条 · ${this.getProtectedAppCount()} 个应用`)
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
    }
    .width('100%')
  }

  @Builder
  private buildEmptyState(): void {
    Column({ space: 10 }) {
      Text('还没有契约计划')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
      Text('创建后可以在指定时间自动限制应用，适合固定学习、工作和休息节奏。')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      Button('新建第一条契约')
        .width('100%')
        .height(46)
        .type(ButtonType.Capsule)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
        .margin({ top: 4 })
        .onClick(() => {
          pushRoute(PageRoutes.PlanAdd);
        })
    }
    .width('100%')
    .padding(24)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      List({ space: 12, scroller: this.listScroller }) {
        ListItem() {
          this.buildSummaryPanel()
        }
        .margin({ bottom: 16 })

        ListItem() {
          this.buildSectionHeader()
        }

        if (this.statusMessage.length > 0) {
          ListItem() {
            Text(this.statusMessage)
              .width('100%')
              .fontSize(12)
              .fontColor(AppTheme.colors.textSecondary)
          }
        }

        if (this.getVisiblePlans().length === 0) {
          ListItem() {
            this.buildEmptyState()
          }
        } else {
          ForEach(this.getVisiblePlans(), (plan: FocusPlan) => {
            ListItem() {
              PlanCard({
                plan,
                onPress: () => {
                  PlanStore.setCurrentPlanId(plan.id);
                  pushRoute(PageRoutes.PlanDetail);
                },
                onToggle: () => {
                  void this.togglePlan(plan);
                },
                onDelete: () => {
                  this.confirmDeletePlan(plan);
                }
              })
            }
          }, (plan: FocusPlan) => plan.id)
        }
      }
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
    }
    .pullToRefresh(true)
    .onRefreshing(() => {
      this.refreshPlans();
    })
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
  }
}

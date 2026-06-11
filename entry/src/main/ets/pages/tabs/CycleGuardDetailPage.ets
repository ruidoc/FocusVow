import { common } from '@kit.AbilityKit';
import { PageScaffold } from '../../components/common/PageScaffold';
import { AppTheme } from '../../constants/Theme';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { activateCycleGuard, deactivateCycleGuard } from '../../services/CycleGuardService';
import { requestScreenTimeAuthorization } from '../../services/ScreenTimeService';
import { CycleGuardStore } from '../../stores/CycleGuardStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Component
export struct CycleGuardDetailPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.CycleGuardEnabled) cycleEnabled: boolean = false;
  @StorageLink(StoreKeys.CycleGuardQuotaMinutes) quotaMinutes: number = 60;
  @StorageLink(StoreKeys.CycleGuardSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.CycleGuardPhase) phase: string = 'idle';
  @StorageLink(StoreKeys.CycleGuardStatusMessage) statusMessage: string = '配置共享时长和目标应用后，即可启动循环守护';
  @State private isSubmitting: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
  }

  private hasConfiguration(): boolean {
    return this.selectedAppCount > 0;
  }

  private getPhaseLabel(): string {
    if (this.phase === 'quota_running') {
      return '额度计时中';
    }
    if (this.phase === 'locked') {
      return '当前已锁定';
    }
    return this.cycleEnabled ? '准备中' : '未启动';
  }

  private async authorize(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await requestScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, result.ok, result.message);
  }

  private async startCycle(): Promise<void> {
    if (this.isSubmitting || !this.hasConfiguration()) {
      return;
    }
    this.isSubmitting = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await activateCycleGuard(hostContext);
    CycleGuardStore.hydrate(hostContext);
    this.isSubmitting = false;
  }

  private async stopCycle(): Promise<void> {
    if (this.isSubmitting) {
      return;
    }
    this.isSubmitting = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await deactivateCycleGuard(hostContext);
    CycleGuardStore.hydrate(hostContext);
    this.isSubmitting = false;
  }

  @Builder
  private buildMetricCard(title: string, value: string, detail: string): void {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(12)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')

      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Text(detail)
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildEmptyState(): void {
    Column({ space: 14 }) {
      Text('还没有配置循环守护')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Text('先选择目标应用，再设置共享可用时长。配置完成后，这里会展示完整详情。')
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      Button('去配置循环守护')
        .width('100%')
        .height(50)
        .type(ButtonType.Capsule)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Bold)
        .onClick(() => {
          pushRoute(PageRoutes.CycleGuardEdit);
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(AppTheme.colors.surfaceRaised)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildConfiguredContent(): void {
    Column({ space: 16 }) {
      this.buildMetricCard(
        '当前状态',
        this.cycleEnabled ? this.getPhaseLabel() : '已配置，未启动',
        this.statusMessage
      )
      this.buildMetricCard(
        '共享可用时长',
        `${this.quotaMinutes} 分钟`,
        '额度用完后会自动锁定目标应用'
      )
      this.buildMetricCard(
        '目标应用',
        `${this.selectedAppCount} 个`,
        this.hasAuthorized ? '已具备系统授权，可直接启停' : '还需要先完成系统授权'
      )

      if (!this.hasAuthorized) {
        Button('申请系统授权')
          .width('100%')
          .height(48)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.surface)
          .fontColor(AppTheme.colors.textPrimary)
          .border({ width: 1, color: AppTheme.colors.border })
          .onClick(() => {
            this.authorize();
          })
      }

      Button('编辑配置')
        .width('100%')
        .height(48)
        .type(ButtonType.Capsule)
        .backgroundColor(AppTheme.colors.surface)
        .fontColor(AppTheme.colors.textPrimary)
        .border({ width: 1, color: AppTheme.colors.border })
        .onClick(() => {
          pushRoute(PageRoutes.CycleGuardEdit);
        })

      if (this.cycleEnabled) {
        Button('停止循环守护')
          .width('100%')
          .height(52)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.dangerSoft)
          .fontColor(AppTheme.colors.danger)
          .border({ width: 1, color: AppTheme.colors.danger })
          .enabled(!this.isSubmitting)
          .opacity(this.isSubmitting ? 0.7 : 1)
          .onClick(() => {
            this.stopCycle();
          })
      } else {
        Button('启动循环守护')
          .width('100%')
          .height(52)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.primary)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .enabled(!this.isSubmitting)
          .opacity(this.isSubmitting ? 0.7 : 1)
          .onClick(() => {
            this.startCycle();
          })
      }
    }
    .width('100%')
  }

  @Builder
  private buildContent(): void {
    Scroll() {
      Column({ space: 18 }) {
        if (this.hasConfiguration()) {
          this.buildConfiguredContent();
        } else {
          this.buildEmptyState();
        }
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.Top)
  }

  build() {
    PageScaffold({
      subtitle: this.hasConfiguration()
        ? '详情页负责展示配置与运行状态，编辑动作收敛到单独页面'
        : '还没有配置循环守护，先完成一次配置即可在这里查看详情',
      headerMode: 'default',
      showDecoration: false,
      topPadding: 12,
      bottomPadding: 12,
      horizontalPadding: 20,
      content: (): void => {
        this.buildContent();
      }
    })
  }
}

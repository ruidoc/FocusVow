import { common } from '@kit.AbilityKit';
import { AppActionButton } from '../../components/common/AppActionButton';
import { AppTheme } from '../../constants/Theme';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { activateCycleGuard, deactivateCycleGuard } from '../../services/CycleGuardService';
import { CycleGuardStore } from '../../stores/CycleGuardStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Component
export struct CycleGuardDetailPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.CycleGuardEnabled) cycleEnabled: boolean = false;
  @StorageLink(StoreKeys.CycleGuardQuotaMinutes) storedQuotaMinutes: number = 60;
  @StorageLink(StoreKeys.CycleGuardSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.CycleGuardPhase) phase: string = 'idle';
  @StorageLink(StoreKeys.CycleGuardStatusMessage) statusMessage: string = '配置总可用时长和目标应用后，即可启动娱乐限额';
  @State private isSubmitting: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
  }

  private formatMinutesLabel(value: number): string {
    if (value >= 60) {
      const hours = Math.floor(value / 60);
      const minutes = value % 60;
      if (minutes === 0) {
        return `${hours} 小时`;
      }
      return `${hours} 小时 ${minutes} 分钟`;
    }
    return `${value} 分钟`;
  }

  private getStatusLabel(): string {
    return this.cycleEnabled ? '生效中' : '未生效';
  }

  private getStatusColor(): string {
    return this.cycleEnabled ? AppTheme.colors.success : AppTheme.colors.danger;
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

  private async startCycle(): Promise<void> {
    if (this.isSubmitting) {
      return;
    }
    this.isSubmitting = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await activateCycleGuard(hostContext);
    CycleGuardStore.hydrate(hostContext);
    this.isSubmitting = false;
  }

  @Builder
  private buildMetricChip(label: string, value: string, valueColor: string = AppTheme.colors.textPrimary): void {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(11)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')

      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(valueColor)
        .width('100%')
    }
    .layoutWeight(1)
    .padding(14)
    .backgroundColor(AppTheme.colors.surfaceRaised)
    .borderRadius(AppTheme.radius.md)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildOverviewCard(): void {
    Column({ space: 12 }) {
      Text('这里仅查看当前限额状态与配置摘要，具体修改请点右上角进入设置。')
        .fontSize(13)
        .lineHeight(22)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      Row({ space: 12 }) {
        this.buildMetricChip('状态', this.getStatusLabel(), this.getStatusColor())
        this.buildMetricChip('已选应用', `${this.selectedAppCount} 个`)
        this.buildMetricChip('可用时长', this.formatMinutesLabel(this.storedQuotaMinutes))
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildSummaryCard(): void {
    Column({ space: 16 }) {
      Row() {
        Text('当前配置')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
        Blank()
        Text(this.hasAuthorized ? '已授权' : '未授权')
          .fontSize(12)
          .fontColor(this.hasAuthorized ? AppTheme.colors.success : AppTheme.colors.danger)
      }
      .width('100%')

      Row() {
        Text('目标应用')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
        Blank()
        Text(this.selectedAppCount > 0 ? `${this.selectedAppCount} 个` : '尚未选择')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
      }
      .width('100%')

      Row() {
        Text('可用时长')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
        Blank()
        Text(this.formatMinutesLabel(this.storedQuotaMinutes))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  private confirmStopCycle(): void {
    this.getUIContext().showAlertDialog({
      title: '停止娱乐限额',
      message: '停止后会结束当前娱乐限额计时，确认停止吗？',
      autoCancel: true,
      primaryButton: {
        value: '停止',
        fontColor: AppTheme.colors.danger,
        action: () => {
          void this.stopCycle();
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  @Builder
  private buildContent(): void {
    Column({ space: 18 }) {
      this.buildOverviewCard()
      this.buildSummaryCard()

      if (this.cycleEnabled) {
        Text('停止娱乐限额')
          .fontSize(13)
          .fontColor(this.isSubmitting ? AppTheme.colors.textMuted : AppTheme.colors.danger)
          .opacity(this.isSubmitting ? 0.5 : 0.8)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 10, bottom: 4 })
          .onClick(() => {
            if (!this.isSubmitting) {
              this.confirmStopCycle();
            }
          })
      } else {
        AppActionButton({
          label: '启用娱乐限额',
          isEnabled: !this.isSubmitting,
          onPress: () => {
            void this.startCycle();
          }
        })
          .margin({ top: 10, bottom: 4 })
      }
    }
    .width('100%')
    .padding({ bottom: 24 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    SystemNavPage({
      title: '娱乐限额',
      showAction: true,
      actionLabel: '设置',
      actionIcon: $r('sys.symbol.gearshape'),
      onAction: () => {
        pushRoute(PageRoutes.CycleGuardEdit);
      },
      content: (): void => {
        this.buildContent();
      }
    })
  }
}

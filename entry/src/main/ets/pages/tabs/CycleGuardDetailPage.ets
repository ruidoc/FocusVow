import { common } from '@kit.AbilityKit';
import { AppTheme } from '../../constants/Theme';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { activateCycleGuard, deactivateCycleGuard } from '../../services/CycleGuardService';
import { chooseRestrictedApps, requestScreenTimeAuthorization } from '../../services/ScreenTimeService';
import { CycleGuardStore } from '../../stores/CycleGuardStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';
import { CycleGuardPhase } from '../../models/CycleGuardModel';

bootstrapStores();

@Component
export struct CycleGuardDetailPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.CycleGuardEnabled) cycleEnabled: boolean = false;
  @StorageLink(StoreKeys.CycleGuardQuotaMinutes) storedQuotaMinutes: number = 60;
  @StorageLink(StoreKeys.CycleGuardSelectedTokens) selectedTokens: string[] = [];
  @StorageLink(StoreKeys.CycleGuardSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.CycleGuardPhase) phase: string = 'idle';
  @StorageLink(StoreKeys.CycleGuardStatusMessage) statusMessage: string = '配置总可用时长和目标应用后，即可启动娱乐限额';
  @State private draftQuotaMinutes: number = 60;
  @State private isSubmitting: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
    this.draftQuotaMinutes = this.storedQuotaMinutes;
  }

  private hasConfiguration(): boolean {
    return this.selectedAppCount > 0;
  }

  private normalizeMinutes(raw: number): number {
    let next = Math.max(5, Math.min(180, Math.floor(raw)));
    next = Math.round(next / 5) * 5;
    return Math.max(5, Math.min(180, next));
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

  private getPhaseLabel(): string {
    if (this.phase === 'quota_running') {
      return '可用时长消耗中';
    }
    if (this.phase === 'locked') {
      return '额度已用完，当前锁定中';
    }
    return this.cycleEnabled ? '已启动' : '未启动';
  }

  private async authorize(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await requestScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, result.ok, result.message);
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    if (result.data) {
      CycleGuardStore.updateSelectedTokens(hostContext, result.data, result.message);
      return;
    }
    CycleGuardStore.updateRuntimeState(
      hostContext,
      this.cycleEnabled,
      this.phase as CycleGuardPhase,
      result.message
    );
  }

  private async saveDraft(): Promise<void> {
    if (this.isSubmitting) {
      return;
    }
    this.isSubmitting = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    CycleGuardStore.updateQuotaMinutes(hostContext, this.draftQuotaMinutes);
    CycleGuardStore.updateRuntimeState(
      hostContext,
      this.cycleEnabled,
      this.phase as CycleGuardPhase,
      '娱乐限额配置已保存'
    );
    CycleGuardStore.hydrate(hostContext);
    this.isSubmitting = false;
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
  private buildOverviewCard(): void {
    Column({ space: 12 }) {
      Text('娱乐限额')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Text('为娱乐类应用设置总可用时长，时间用完后统一锁定，适合短视频、游戏和社交软件。')
        .fontSize(13)
        .lineHeight(22)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      Row({ space: 12 }) {
        this.buildMetricChip('状态', this.getPhaseLabel())
        this.buildMetricChip('已选应用', `${this.selectedAppCount} 个`)
        this.buildMetricChip('总时长', this.formatMinutesLabel(this.draftQuotaMinutes))
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
  private buildMetricChip(label: string, value: string): void {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(11)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')

      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
    }
    .layoutWeight(1)
    .padding(14)
    .backgroundColor(AppTheme.colors.surfaceRaised)
    .borderRadius(AppTheme.radius.md)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildActionCard(title: string, value: string, detail: string, label: string, onPress: () => void): void {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text(title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')

          Text(value)
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button(label)
          .height(34)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.primarySoft)
          .fontColor(AppTheme.colors.primary)
          .border({ width: 0, color: AppTheme.colors.primarySoft })
          .onClick(() => {
            onPress();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(detail)
        .fontSize(12)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildQuotaCard(): void {
    Column({ space: 14 }) {
      Text('总可用时长')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Text(this.formatMinutesLabel(this.draftQuotaMinutes))
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.primary)
        .width('100%')
        .textAlign(TextAlign.Center)

      Slider({
        value: this.draftQuotaMinutes,
        min: 5,
        max: 180,
        step: 5,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .blockColor(AppTheme.colors.primary)
        .trackColor(AppTheme.colors.border)
        .selectedColor(AppTheme.colors.primary)
        .showSteps(false)
        .showTips(false)
        .onChange((nextValue: number) => {
          this.draftQuotaMinutes = this.normalizeMinutes(nextValue);
        })

      Row() {
        Text('5 分钟')
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
        Blank()
        Text('3 小时')
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildFooterActions(): void {
    Column({ space: 12 }) {
      Button('保存配置')
        .width('100%')
        .height(50)
        .type(ButtonType.Capsule)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .fontColor(AppTheme.colors.textPrimary)
        .border({ width: 0, color: AppTheme.colors.surfaceRaised })
        .enabled(!this.isSubmitting)
        .opacity(this.isSubmitting ? 0.7 : 1)
        .onClick(() => {
          void this.saveDraft();
        })

      Button(this.cycleEnabled ? '停止娱乐限额' : '启动娱乐限额')
        .width('100%')
        .height(52)
        .type(ButtonType.Capsule)
        .backgroundColor(this.cycleEnabled ? AppTheme.colors.dangerSoft : AppTheme.colors.primary)
        .fontColor(this.cycleEnabled ? AppTheme.colors.danger : '#FFFFFF')
        .fontWeight(FontWeight.Bold)
        .enabled(!this.isSubmitting && this.hasConfiguration())
        .opacity((this.isSubmitting || !this.hasConfiguration()) ? 0.7 : 1)
        .onClick(() => {
          if (this.cycleEnabled) {
            void this.stopCycle();
            return;
          }
          void this.startCycle();
        })

      if (this.statusMessage.length > 0) {
        Text(this.statusMessage)
          .fontSize(12)
          .lineHeight(20)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private buildContent(): void {
    Column({ space: 16 }) {
      this.buildOverviewCard()

      this.buildActionCard(
        '系统授权',
        this.hasAuthorized ? '已完成授权' : '未完成授权',
        '授权后才能对你主动选择的娱乐应用应用总时长限制。',
        this.hasAuthorized ? '重新授权' : '申请授权',
        () => {
          void this.authorize();
        }
      )

      this.buildActionCard(
        '目标应用',
        this.selectedAppCount > 0 ? `已选择 ${this.selectedAppCount} 个应用` : '尚未选择应用',
        '建议优先选择短视频、游戏、社交等高频娱乐应用，避免把必要通信工具一起锁住。',
        this.selectedAppCount > 0 ? '重新选择' : '选择应用',
        () => {
          void this.chooseApps();
        }
      )

      this.buildQuotaCard()
      this.buildFooterActions()
    }
    .width('100%')
    .padding({ bottom: 24 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    SystemNavPage({
      title: '娱乐限额',
      horizontalPadding: 20,
      content: (): void => {
        this.buildContent();
      }
    })
  }
}

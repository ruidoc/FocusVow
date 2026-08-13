import { common } from '@kit.AbilityKit';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { CycleGuardPhase } from '../../models/CycleGuardModel';
import { backRoute } from '../../router/PageRoutes';
import { chooseRestrictedApps, requestScreenTimeAuthorization } from '../../services/ScreenTimeService';
import { CycleGuardStore } from '../../stores/CycleGuardStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Entry
@Component
struct CycleGuardPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.CycleGuardSelectedTokens) selectedTokens: string[] = [];
  @StorageLink(StoreKeys.CycleGuardSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.CycleGuardStatusMessage) statusMessage: string = '配置总可用时长和目标应用后，即可启动娱乐限额';
  @StorageLink(StoreKeys.CycleGuardQuotaMinutes) storedQuotaMinutes: number = 60;
  @StorageLink(StoreKeys.CycleGuardEnabled) cycleEnabled: boolean = false;
  @StorageLink(StoreKeys.CycleGuardPhase) phase: string = 'idle';
  @State private draftQuotaMinutes: number = 60;
  @State private isSaving: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
    this.syncDraftValues();
  }

  private syncDraftValues(): void {
    this.draftQuotaMinutes = this.storedQuotaMinutes;
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

  private getStatusLabel(): string {
    return this.cycleEnabled ? '生效中' : '未生效';
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
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    CycleGuardStore.updateQuotaMinutes(hostContext, this.draftQuotaMinutes);
    CycleGuardStore.updateRuntimeState(
      hostContext,
      this.cycleEnabled,
      this.phase as CycleGuardPhase,
      '娱乐限额配置已保存'
    );
    this.isSaving = false;
  }

  @Builder
  private buildStatusCard(): void {
    Column({ space: 12 }) {

      Text('这里单独调整目标应用和可用时长；启动与停止动作统一放在限额主页。')
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      Row({ space: 18 }) {
        Column({ space: 4 }) {
          Text('系统授权')
            .fontSize(11)
            .fontColor(AppTheme.colors.textMuted)
          Text(this.hasAuthorized ? '已授权' : '未授权')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.hasAuthorized ? AppTheme.colors.success : AppTheme.colors.danger)
        }
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text('目标应用')
            .fontSize(11)
            .fontColor(AppTheme.colors.textMuted)
          Text(`${this.selectedAppCount} 个`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
        }
        .alignItems(HorizontalAlign.Start)

        Column({ space: 4 }) {
          Text('状态')
            .fontSize(11)
            .fontColor(AppTheme.colors.textMuted)
          Text(this.getStatusLabel())
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.cycleEnabled ? AppTheme.colors.success : AppTheme.colors.danger)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      if (this.statusMessage.length > 0) {
        Text(this.statusMessage)
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(AppTheme.colors.surfaceRaised)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildQuotaSliderCard(): void {
    Column({ space: 14 }) {
      Text('可用时长')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Text(this.formatMinutesLabel(this.draftQuotaMinutes))
        .fontSize(24)
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
    .padding(20)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildBody(): void {
    Column({ space: 18 }) {
      this.buildStatusCard()

      if (!this.hasAuthorized) {
        Button('授权')
          .width('100%')
          .height(48)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .backgroundColor(AppTheme.colors.surface)
          .fontColor(AppTheme.colors.textPrimary)
          .border({ width: 1, color: AppTheme.colors.border })
          .onClick(() => {
            this.authorize();
          })
      }

      Button(this.selectedAppCount > 0 ? `重新选择目标应用（${this.selectedAppCount} 个）` : '选择目标应用')
        .width('100%')
        .height(48)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .borderRadius(AppTheme.radius.button)
        .clip(true)
        .backgroundColor(AppTheme.colors.surface)
        .fontColor(AppTheme.colors.textPrimary)
        .border({ width: 1, color: AppTheme.colors.border })
        .onClick(() => {
          this.chooseApps();
        })

      this.buildQuotaSliderCard()

      Button('保存配置')
        .width('100%')
        .height(52)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .borderRadius(AppTheme.radius.button)
        .clip(true)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Bold)
        .enabled(!this.isSaving)
        .opacity(this.isSaving ? 0.7 : 1)
        .onClick(() => {
          this.saveDraft();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 10 })
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '娱乐限额设置',
        showBack: true,
        bottomSpacerHeight: 24,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildBody();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

import { common } from '@kit.AbilityKit';
import { FeatureIntroCard } from '../../components/common/FeatureIntroCard';
import { showToast } from '../../common/Toast';
import { AppTheme } from '../../constants/Theme';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { activateCycleGuard, deactivateCycleGuard } from '../../services/CycleGuardService';
import { BenefitStore } from '../../stores/BenefitStore';
import { CycleGuardStore } from '../../stores/CycleGuardStore';
import { ensureProMembership } from '../../utils/PaywallNavigationUtil';
import { ensureTaskPermission } from '../../utils/TaskPermissionUtil';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Entry
@Component
struct CycleGuardDetailPage {
  @StorageLink(StoreKeys.CycleGuardEnabled) cycleEnabled: boolean = false;
  @StorageLink(StoreKeys.CycleGuardConfigured) cycleConfigured: boolean = false;
  @StorageLink(StoreKeys.CycleGuardQuotaMinutes) storedQuotaMinutes: number = 60;
  @StorageLink(StoreKeys.CycleGuardLockMinutes) storedLockMinutes: number = 25;
  @StorageLink(StoreKeys.CycleGuardSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.CycleGuardPhase) phase: string = 'idle';
  @StorageLink(StoreKeys.CycleGuardStatusMessage) statusMessage: string = '配置总可用时长和目标应用后，即可启动短视频限额';
  @State private isSubmitting: boolean = false;
  @State private enableSwitchValue: boolean = false;
  @State private enableSwitchKey: number = 0;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
    this.syncEnableSwitchValue();
  }

  onPageShow(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    CycleGuardStore.hydrate(hostContext);
    this.syncEnableSwitchValue(true);
  }

  private syncEnableSwitchValue(forceRemount: boolean = false): void {
    this.enableSwitchValue = this.cycleEnabled;
    if (forceRemount) {
      this.enableSwitchKey += 1;
    }
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

  private getAppSummaryLabel(): string {
    if (this.selectedAppCount > 0) {
      return `已选 ${this.selectedAppCount} 个娱乐应用`;
    }
    return '未选择娱乐应用';
  }

  private getQuotaSummaryLabel(): string {
    return `娱乐总时长：${this.formatMinutesLabel(this.storedQuotaMinutes)}`;
  }

  private getLockSummaryLabel(): string {
    return `锁定最短时长：${this.formatMinutesLabel(this.storedLockMinutes)}`;
  }

  private getStatusText(): string | null {
    if (!this.cycleEnabled) {
      return null;
    }
    if (this.phase === 'quota_running' && this.statusMessage.length > 0) {
      return this.statusMessage;
    }
    if (this.statusMessage.length > 0) {
      return this.statusMessage;
    }
    return `生效中：已选 ${this.selectedAppCount} 项，累计满 ${this.storedQuotaMinutes} 分钟后上锁`;
  }

  private openEditor(): void {
    pushRoute(PageRoutes.CycleGuardEdit);
  }

  private async applyEnabled(enabled: boolean): Promise<void> {
    this.isSubmitting = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (enabled) {
      await activateCycleGuard(hostContext);
    } else {
      await deactivateCycleGuard(hostContext);
    }
    CycleGuardStore.hydrate(hostContext);
    this.syncEnableSwitchValue();
    this.isSubmitting = false;
  }

  private async onToggle(enabled: boolean): Promise<void> {
    if (enabled === this.cycleEnabled) {
      this.syncEnableSwitchValue(true);
      return;
    }
    if (this.isSubmitting) {
      this.syncEnableSwitchValue(true);
      return;
    }
    if (!this.cycleConfigured) {
      this.syncEnableSwitchValue(true);
      return;
    }
    if (enabled) {
      if (this.selectedAppCount === 0) {
        showToast('请先添加短视频限额配置', this.getUIContext());
        this.syncEnableSwitchValue(true);
        return;
      }
      await BenefitStore.refresh();
      if (!ensureProMembership('cycle_guard', {
        proUnlock: true,
      })) {
        this.syncEnableSwitchValue(true);
        return;
      }
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (!(await ensureTaskPermission(hostContext, this.getUIContext(), {
        entry_source: 'cycle_guard',
        screen_name: 'cycle_guard',
      }))) {
        this.syncEnableSwitchValue(true);
        return;
      }
      await this.applyEnabled(true);
      return;
    }
    this.syncEnableSwitchValue();
    this.confirmDisable();
  }

  private confirmDisable(): void {
    this.getUIContext().showAlertDialog({
      title: '关闭短视频限额？',
      message: '关闭后额度监控会立即停止，可能控制不住无限刷短视频或玩游戏。',
      autoCancel: true,
      primaryButton: {
        value: '确认关闭',
        fontColor: AppTheme.colors.danger,
        action: () => {
          void this.applyEnabled(false);
        },
      },
      secondaryButton: {
        value: '保持开启',
        action: () => {
          this.syncEnableSwitchValue();
        },
      },
    });
  }

  @Builder
  private buildEnableSwitchCard(): void {
    Row() {
      Text('启用短视频限额')
        .layoutWeight(1)
        .fontSize(16)
        .fontColor(AppTheme.colors.textPrimary)
      Toggle({ type: ToggleType.Switch, isOn: this.enableSwitchValue })
        .key(`cycle-guard-enable-${this.enableSwitchKey}`)
        .selectedColor(AppTheme.colors.primary)
        .switchPointColor('#FFFFFF')
        .enabled(!this.isSubmitting && this.cycleConfigured)
        .onChange((enabled: boolean) => {
          void this.onToggle(enabled);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildEmptyState(): void {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.plus_circle'))
        .fontSize(36)
        .fontColor([AppTheme.colors.primary])
      Text('添加短视频限额')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
      Text('选择要管的应用，设定能用多久')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textSecondary)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 24, bottom: 24 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .border({
      width: 1,
      color: AppTheme.colors.border,
      style: BorderStyle.Dashed,
    })
    .borderRadius(AppTheme.radius.lg)
    .backgroundColor(AppTheme.colors.surface)
    .onClick(() => {
      this.openEditor();
    })
  }

  @Builder
  private buildConfigCard(): void {
    Column({ space: 12 }) {
      Row() {
        Text('短视频限额配置')
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
        if (!this.cycleEnabled) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.square_and_pencil'))
              .fontSize(14)
              .fontColor([AppTheme.colors.primary])
            Text('编辑')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.primary)
          }
          .onClick(() => {
            this.openEditor();
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.getQuotaSummaryLabel())
        .fontSize(14)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
      Text(this.getLockSummaryLabel())
        .fontSize(14)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
      Text(this.getAppSummaryLabel())
        .fontSize(14)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildContent(): void {
    Column({ space: 12 }) {
      FeatureIntroCard({
        introId: 'cycle_guard',
        title: '给娱乐 App 设个上限',
        description: '抖音、游戏刷到停不下来？别拍，把它们加到限额，设置可用时长，用满了就自动锁住，帮你及时收手',
        confirmTitle: '确定关闭功能介绍？',
        confirmMessage: '如果了解了短视频限额功能，可以点击确认关闭，关闭后不再显示此介绍',
      })

      this.buildEnableSwitchCard()

      if (!this.cycleConfigured) {
        Text('先添加限额，再开启开关')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
          .padding({ left: 2, right: 2 })
      }

      if (this.getStatusText() !== null) {
        Text(this.getStatusText() ?? '')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(this.phase === 'quota_running' ? AppTheme.colors.primary : AppTheme.colors.textSecondary)
          .width('100%')
          .padding({ left: 2, right: 2 })
      }

      if (!this.cycleConfigured) {
        this.buildEmptyState()
      } else {
        this.buildConfigCard()
      }
    }
    .width('100%')
    .padding({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '短视频限额',
        showBack: true,
        usePageScroll: true,
        useFloatingTabInset: false,
        bottomSpacerHeight: 16,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

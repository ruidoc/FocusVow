import { common } from '@kit.AbilityKit';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { backRoute, replaceRoute, PageRoutes } from '../../router/PageRoutes';
import {
  applyScreenRestriction,
  chooseRestrictedApps,
  requestScreenTimeAuthorization
} from '../../services/ScreenTimeService';
import { LockStore } from '../../stores/LockStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Entry
@Component
struct QuickStartPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedTokens) selectedTokens: string[] = [];
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.SettingsStatusMessage) statusMessage: string = '';
  @State durationMinutes: number = 15;
  @State mode: 'shield' | 'allow' = 'shield';

  private readonly durationMin: number = 5;
  private readonly durationMax: number = 180;
  private readonly durationStep: number = 5;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    const rawDuration = LockStore.getQuickFocusDurationMinutes();
    const normalized = this.normalizeDurationMinutes(rawDuration);
    this.durationMinutes = normalized;
    if (normalized !== rawDuration) {
      LockStore.setQuickFocusDurationMinutes(hostContext, normalized);
    }
  }

  private normalizeDurationMinutes(raw: number): number {
    let d = Math.max(this.durationMin, Math.min(this.durationMax, Math.floor(raw)));
    d = Math.round(d / this.durationStep) * this.durationStep;
    return Math.max(this.durationMin, Math.min(this.durationMax, d));
  }

  private durationLabel(): string {
    if (this.durationMinutes >= 60) {
      const h = Math.floor(this.durationMinutes / 60);
      const m = this.durationMinutes % 60;
      if (m === 0) {
        return `${h} 小时`;
      }
      return `${h} 小时 ${m} 分钟`;
    }
    return `${this.durationMinutes} 分钟`;
  }

  private appCardTitle(): string {
    return this.mode === 'shield' ? '要锁定的应用' : '要放行的应用';
  }

  private durationCardTitle(): string {
    return this.mode === 'shield' ? '锁定时长' : '放行时长';
  }

  private shouldShowStatusLine(): boolean {
    if (this.statusMessage.length === 0) {
      return false;
    }
    if (this.statusMessage === '先申请系统授权，再选择需要限制的应用') {
      return false;
    }
    const m = /^已选择 (\d+) 个应用$/.exec(this.statusMessage);
    if (m !== null && Number(m[1]) === this.selectedAppCount) {
      return false;
    }
    return true;
  }

  private async authorize(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await requestScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, result.ok, result.message);
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!this.hasAuthorized) {
      await this.authorize();
      if (!SettingsStore.getState().hasAuthorized) {
        return;
      }
    }
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    if (result.data) {
      SettingsStore.updateSelectedTokens(hostContext, result.data, result.message);
    } else {
      SettingsStore.updateStatusMessage(hostContext, result.message);
    }
  }

  private async startFocus(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (LockStore.isLocked()) {
      SettingsStore.updateStatusMessage(hostContext, '当前已有进行中的锁定，请先回首页结束后再开始新的专注');
      return;
    }

    if (this.selectedTokens.length === 0) {
      SettingsStore.updateStatusMessage(hostContext, '请先选择至少 1 个应用');
      return;
    }

    if (!this.hasAuthorized) {
      await this.authorize();
      if (!SettingsStore.getState().hasAuthorized) {
        return;
      }
    }

    const result = await applyScreenRestriction(this.selectedTokens, this.mode);
    SettingsStore.updateStatusMessage(hostContext, result.message);
    if (!result.ok) {
      return;
    }

    LockStore.startQuickFocus(hostContext, this.selectedTokens, this.durationMinutes, this.mode);
    replaceRoute(PageRoutes.FocusHome);
  }

  private onDurationSliderChange(value: number): void {
    const next = this.normalizeDurationMinutes(value);
    this.durationMinutes = next;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    LockStore.setQuickFocusDurationMinutes(hostContext, next);
  }

  @Builder
  buildModeSegment(): void {
    Row({ space: 0 }) {
      Text('锁定模式')
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(this.mode === 'shield' ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary)
        .fontWeight(this.mode === 'shield' ? FontWeight.Medium : FontWeight.Regular)
        .textAlign(TextAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .borderRadius(20)
        .backgroundColor(this.mode === 'shield' ? AppTheme.colors.surfaceRaised : Color.Transparent)
        .onClick(() => {
          this.mode = 'shield';
        })

      Text('放行模式')
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(this.mode === 'allow' ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary)
        .fontWeight(this.mode === 'allow' ? FontWeight.Medium : FontWeight.Regular)
        .textAlign(TextAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .borderRadius(20)
        .backgroundColor(this.mode === 'allow' ? AppTheme.colors.surfaceRaised : Color.Transparent)
        .onClick(() => {
          this.mode = 'allow';
        })
    }
    .width('80%')
    .padding(4)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(999)
  }

  @Builder
  buildAppCard(): void {
    Column({ space: 14 }) {
      Row() {
        Text(this.appCardTitle())
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)

        Text('+ 选择')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.primary)
          .onClick(() => {
            this.chooseApps();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.selectedAppCount === 0) {
        Text('未选择应用')
          .fontSize(15)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
      } else {
        Text(`已选 ${this.selectedAppCount} 个应用`)
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }

      if (this.shouldShowStatusLine()) {
        Text(this.statusMessage)
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
  }

  @Builder
  buildDurationCard(): void {
    Column({ space: 16 }) {
      Text(this.durationCardTitle())
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Text(this.durationLabel())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.primary)
        .width('100%')
        .textAlign(TextAlign.Center)

      Slider({
        value: this.durationMinutes,
        min: this.durationMin,
        max: this.durationMax,
        step: this.durationStep,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .blockColor(AppTheme.colors.primary)
        .trackColor(AppTheme.colors.border)
        .selectedColor(AppTheme.colors.primary)
        .showSteps(false)
        .showTips(false)
        .onChange((v: number) => {
          this.onDurationSliderChange(v);
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
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
  }

  @Builder
  buildQuickBody(): void {
    Column({ space: 18 }) {
      Row() {
        this.buildModeSegment()
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 8 })

      this.buildAppCard()
      this.buildDurationCard()

      Button('开始专注')
        .width('100%')
        .height(52)
        .type(ButtonType.Capsule)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .margin({ top: 8 })
        .onClick(() => {
          this.startFocus();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '快速专注',
        showBack: true,
        usePageScroll: true,
        bottomSpacerHeight: 28,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildQuickBody();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { TimerModeSegmented } from '../../components/focus/TimerModeSegmented';
import { AppTheme } from '../../constants/Theme';
import { filterSessionAppsForHarmony, mergeSessionAppsForHarmony } from '../../models/DuoModel';
import { QuickTask, QuickTaskUpsertPayload } from '../../models/QuickTaskModel';
import { PageRoutes, backRoute } from '../../router/PageRoutes';
import {
  chooseRestrictedApps,
  requestScreenTimeAuthorization,
} from '../../services/ScreenTimeService';
import { getQuickStartDelayOptions } from '../../services/PendingQuickStartService';
import { BenefitStore } from '../../stores/BenefitStore';
import { QuickTaskStore } from '../../stores/QuickTaskStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { UserStore } from '../../stores/UserStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { TimerMode } from '../../utils/TimerMode';

bootstrapStores();

@Entry
@Component
struct QuickTaskFormPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedTokens) selectedTokens: string[] = [];
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.BenefitFeatures) benefitFeatures: string = '';

  @State private editingId: string = '';
  @State private title: string = '';
  @State private durationMinutes: number = 25;
  @State private timerMode: TimerMode = 'countdown';
  @State private mode: 'shield' | 'allow' = 'allow';
  @State private noStop: boolean = false;
  @State private startDelayMinutes: number = 0;
  @State private isSaving: boolean = false;
  @State private existingApps: string[] = [];

  private readonly durationMin: number = 5;
  private readonly durationMax: number = 180;
  private readonly durationStep: number = 5;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    UserStore.hydrate(hostContext);
    BenefitStore.hydrate(hostContext);
    QuickTaskStore.hydrate();

    this.editingId = AppStorage.get<string>(StoreKeys.QuickTaskCurrentId) ?? '';
    if (this.editingId.length > 0) {
      const existing = QuickTaskStore.getTasks().find((item: QuickTask) => item.id === this.editingId);
      if (existing) {
        this.applyTask(existing);
      } else {
        void QuickTaskStore.loadAll().then(() => {
          const loaded = QuickTaskStore.getTasks().find((item: QuickTask) => item.id === this.editingId);
          if (loaded) {
            this.applyTask(loaded);
          }
        });
      }
    }
  }

  private applyTask(task: QuickTask): void {
    this.title = task.title;
    this.durationMinutes = task.duration_min;
    this.timerMode = task.timer_mode;
    this.mode = task.mode;
    this.noStop = task.no_stop;
    this.startDelayMinutes = task.delay_min;
    this.existingApps = [...task.apps];
    const harmonyApps = filterSessionAppsForHarmony(task.apps);
    if (harmonyApps.length > 0) {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      SettingsStore.updateSelectedTokens(hostContext, harmonyApps, '已载入任务应用');
    }
  }

  private isEditing(): boolean {
    return this.editingId.length > 0;
  }

  private hasForceFocusFeature(): boolean {
    return this.benefitFeatures.includes('force-focus');
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
    return this.timerMode === 'countup' ? '最短时长' : '专注时长';
  }

  private async authorize(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await requestScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, result.ok, result.message);
    if (!result.ok) {
      showErrorToast(result.message, this.getUIContext());
    }
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
    if (!result.ok) {
      showErrorToast(result.message, this.getUIContext());
      return;
    }
    if (!result.data) {
      return;
    }
    SettingsStore.updateSelectedTokens(hostContext, result.data, result.message);
  }

  private getStartDelayPickerLabel(minutes: number): string {
    if (minutes === 0) {
      return '立即';
    }
    if (minutes === 60) {
      return '1 小时后';
    }
    return `${minutes} 分钟后`;
  }

  private getStartDelayPickerLabels(): string[] {
    const labels: string[] = [];
    getQuickStartDelayOptions().forEach((minutes: number) => {
      labels.push(this.getStartDelayPickerLabel(minutes));
    });
    return labels;
  }

  private getStartDelayPickerSelectedIndex(): number {
    const options = getQuickStartDelayOptions();
    const idx = options.indexOf(this.startDelayMinutes);
    return idx >= 0 ? idx : 0;
  }

  private resolvePickerIndex(raw: number | number[]): number {
    if (raw instanceof Array) {
      if (raw.length > 0) {
        return raw[0];
      }
      return -1;
    }
    return raw;
  }

  private openStartDelayPicker(): void {
    this.getUIContext().showTextPickerDialog({
      range: this.getStartDelayPickerLabels(),
      selected: this.getStartDelayPickerSelectedIndex(),
      canLoop: false,
      onAccept: (value: TextPickerResult) => {
        const index = this.resolvePickerIndex(value.index);
        const options = getQuickStartDelayOptions();
        if (index >= 0 && index < options.length) {
          this.startDelayMinutes = options[index];
        }
      },
    });
  }

  private async saveTask(): Promise<void> {
    if (!UserStore.isLoggedIn()) {
      showToast('请先登录', this.getUIContext());
      return;
    }
    if (this.title.trim().length === 0) {
      showErrorToast('请先填写任务名称', this.getUIContext());
      return;
    }
    if (QuickTaskStore.titleExists(this.title.trim(), this.editingId)) {
      showErrorToast('已有同名快捷任务，请修改名称', this.getUIContext());
      return;
    }

    this.isSaving = true;
    try {
      if (QuickTaskStore.isDirty()) {
        await QuickTaskStore.loadAll();
        if (QuickTaskStore.titleExists(this.title.trim(), this.editingId)) {
          showErrorToast('已有同名快捷任务，请修改名称', this.getUIContext());
          return;
        }
      }
      const apps = mergeSessionAppsForHarmony(this.existingApps, [...this.selectedTokens]);
      const payload: QuickTaskUpsertPayload = {
        title: this.title.trim(),
        duration_min: this.durationMinutes,
        timer_mode: this.timerMode,
        mode: this.mode,
        delay_min: this.startDelayMinutes,
        no_stop: this.noStop,
        apps: apps
      };
      const response = this.isEditing()
        ? await QuickTaskStore.updateTask(this.editingId, payload)
        : await QuickTaskStore.createTask(payload);
      if (response.statusCode === 200) {
        showToast(this.isEditing() ? '已保存' : '快捷任务已创建', this.getUIContext());
        backRoute();
        return;
      }
      showErrorToast(response.message ?? '保存失败', this.getUIContext());
    } finally {
      this.isSaving = false;
    }
  }

  @Builder
  private buildStartDelayCard(): void {
    Column({ space: 14 }) {
      Row() {
        Text('开始时间')
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
        Text(this.getStartDelayPickerLabel(this.startDelayMinutes))
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .margin({ right: 4 })
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([AppTheme.colors.textMuted])
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.openStartDelayPicker();
      })

      if (this.startDelayMinutes > 0) {
        Text(`可以玩一会手机，${this.startDelayMinutes}分钟后自动进入专注`)
          .fontSize(13)
          .fontColor(AppTheme.colors.warning)
          .width('100%')
      }
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg);
  }

  @Builder
  private buildAppCard(): void {
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
            void this.chooseApps();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.selectedAppCount === 0) {
        Text('未选择应用').fontSize(15).fontColor(AppTheme.colors.textMuted).width('100%');
      } else {
        Text(`已选 ${this.selectedAppCount} 个应用`)
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%');
      }
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg);
  }

  @Builder
  private buildDurationCard(): void {
    Column({ space: 16 }) {
      Text(this.durationCardTitle())
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      if (this.timerMode === 'countup') {
        Text('满最短时长后可随时正常结束。')
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%');
      }
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
        style: SliderStyle.OutSet,
      })
        .width('100%')
        .blockColor(AppTheme.colors.primary)
        .trackColor(AppTheme.colors.border)
        .selectedColor(AppTheme.colors.primary)
        .showSteps(false)
        .showTips(false)
        .onChange((v: number) => {
          this.durationMinutes = this.normalizeDurationMinutes(v);
        })
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg);
  }

  @Builder
  private buildNoStopCard(): void {
    if (this.hasForceFocusFeature() && this.timerMode !== 'countup') {
      Column({ space: 12 }) {
        Row() {
          Text('全程专注')
            .layoutWeight(1)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
          Toggle({ type: ToggleType.Switch, isOn: this.noStop })
            .onChange((checked: boolean) => {
              this.noStop = checked;
            })
        }
        .width('100%')

        if (this.noStop) {
          Text('开启后，专注期间无法手动结束，只能等待时间自然结束')
            .fontSize(13)
            .fontColor(AppTheme.colors.textMuted)
            .width('100%')
        }
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(AppTheme.radius.lg);
    }
  }

  @Builder
  private buildFormBody(): void {
    Column({ space: 18 }) {
      Row() {
        Blank()
        TimerModeSegmented({
          value: this.timerMode,
          onChange: (mode: TimerMode) => {
            this.timerMode = mode;
          },
        })
        Blank()
      }.width('100%')

      TextInput({ text: this.title, placeholder: '每天要完成什么？' })
        .width('100%')
        .height(44)
        .enterKeyType(EnterKeyType.Done)
        .onChange((value: string) => {
          this.title = value;
        })

      this.buildAppCard()
      this.buildDurationCard()
      this.buildStartDelayCard()
      this.buildNoStopCard()

      Button(this.isEditing() ? '保存' : '创建')
        .width('100%')
        .height(52)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .borderRadius(AppTheme.radius.button)
        .clip(true)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .enabled(!this.isSaving)
        .onClick(() => {
          void this.saveTask();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.isEditing() ? '编辑快捷任务' : '新建快捷任务',
        showBack: true,
        usePageScroll: true,
        bottomSpacerHeight: 28,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildFormBody();
        },
      })
    }
    .width('100%')
    .height('100%');
  }
}

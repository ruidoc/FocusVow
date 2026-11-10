import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { FocusDurationCard } from '../../components/focus/FocusDurationCard';
import { TimerModeSegmented } from '../../components/focus/TimerModeSegmented';
import { AppTheme } from '../../constants/Theme';
import {
  filterSessionAppsForHarmony,
  mergeSessionAppsForHarmony,
} from '../../models/DuoModel';
import {
  isDuoQuickTask,
  QuickTask,
  QuickTaskUpsertPayload,
} from '../../models/QuickTaskModel';
import { backRoute, pushDuoPickFriend } from '../../router/PageRoutes';
import { ALLOW_APP_SELECTION_LIMIT, chooseRestrictedApps, rejectOverAppSelection, requestScreenTimeAuthorization } from '../../services/ScreenTimeService';
import { takeDuoPartnerPick } from '../../services/DuoPartnerPickService';
import { upsellIfProSlotQuota } from '../../services/ProQuotaService';
import { LockStore } from '../../stores/LockStore';
import { QuickTaskStore } from '../../stores/QuickTaskStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { UserStore } from '../../stores/UserStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { TimerMode } from '../../utils/TimerMode';

bootstrapStores();

@Entry
@Component
struct DuoQuickTaskFormPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedTokens) selectedTokens: string[] = [];
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;

  @State private editingId: string = '';
  @State private title: string = '';
  @State private durationMinutes: number = 45;
  @State private timerMode: TimerMode = 'countdown';
  @State private targetId: string = '';
  @State private targetName: string = '';
  @State private taskEnabled: boolean = true;
  @State private isSaving: boolean = false;
  @State private existingApps: string[] = [];

  private readonly durationMin: number = 5;
  private readonly durationMax: number = 180;
  private readonly durationStep: number = 5;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    UserStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    QuickTaskStore.hydrate();

    this.editingId = AppStorage.get<string>(StoreKeys.QuickTaskCurrentId) ?? '';
    if (this.editingId.length === 0) {
      showErrorToast('任务不存在', this.getUIContext());
      backRoute();
      return;
    }
    const cached = QuickTaskStore.getTasks().find((item: QuickTask) => item.id === this.editingId);
    if (cached) {
      this.applyTask(cached);
    } else {
      void QuickTaskStore.loadAll().then(() => {
        const loaded = QuickTaskStore.getTasks().find((item: QuickTask) => item.id === this.editingId);
        if (!loaded || !isDuoQuickTask(loaded)) {
          showErrorToast('任务不存在', this.getUIContext());
          backRoute();
          return;
        }
        this.applyTask(loaded);
      });
    }
  }

  onPageShow(): void {
    const picked = takeDuoPartnerPick();
    if (!picked) {
      return;
    }
    this.targetId = picked.target.trim();
    this.targetName = picked.name.trim();
  }

  private applyTask(task: QuickTask): void {
    if (!isDuoQuickTask(task)) {
      showErrorToast('任务不存在', this.getUIContext());
      backRoute();
      return;
    }
    this.title = task.title;
    this.durationMinutes = task.duration_min;
    this.timerMode = task.timer_mode;
    this.targetId = (task.partner_user_id ?? '').trim();
    this.targetName = (task.partner_nickname ?? '').trim();
    this.taskEnabled = task.enabled;
    this.existingApps = [...task.apps];
    const harmonyApps = filterSessionAppsForHarmony(task.apps);
    if (harmonyApps.length > 0) {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      SettingsStore.updateSelectedTokens(hostContext, harmonyApps, '已载入任务应用');
    }
  }

  private normalizeDurationMinutes(raw: number): number {
    let d = Math.max(this.durationMin, Math.min(this.durationMax, Math.floor(raw)));
    d = Math.round(d / this.durationStep) * this.durationStep;
    return Math.max(this.durationMin, Math.min(this.durationMax, d));
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
    if (rejectOverAppSelection(result.data.length, ALLOW_APP_SELECTION_LIMIT, this.getUIContext())) {
      return;
    }
    SettingsStore.updateSelectedTokens(hostContext, result.data, result.message);
  }

  private async saveTask(): Promise<void> {
    if (!UserStore.isLoggedIn()) {
      showToast('请先登录', this.getUIContext());
      return;
    }
    if (LockStore.isLocked()) {
      showToast('专注进行中，不可以修改任务', this.getUIContext());
      return;
    }
    if (this.title.trim().length === 0) {
      showErrorToast('请先填写任务名称', this.getUIContext());
      return;
    }
    if (this.targetId.length === 0) {
      showErrorToast('请选择互督搭子', this.getUIContext());
      return;
    }

    this.isSaving = true;
    try {
      if (QuickTaskStore.isDirty()) {
        await QuickTaskStore.loadAll();
      }
      if (QuickTaskStore.duoTitleExists(this.title.trim(), this.editingId)) {
        showErrorToast('已有同名互督任务，请修改名称', this.getUIContext());
        return;
      }
      const apps = mergeSessionAppsForHarmony(this.existingApps, [...this.selectedTokens]);
      const payload: QuickTaskUpsertPayload = {
        title: this.title.trim(),
        duration_min: this.durationMinutes,
        timer_mode: this.timerMode,
        mode: 'allow',
        delay_min: 0,
        no_stop: false,
        apps: apps,
        enabled: this.taskEnabled,
        partner_user_id: this.targetId,
        partner_nickname: this.targetName,
      };
      const response = await QuickTaskStore.updateTask(this.editingId, payload);
      if (response.statusCode === 200) {
        showToast('已保存', this.getUIContext());
        backRoute();
        return;
      }
      const failMessage = response.message ?? '保存失败';
      if (!upsellIfProSlotQuota(failMessage, 'duo')) {
        showErrorToast(failMessage, this.getUIContext());
      }
    } finally {
      this.isSaving = false;
    }
  }

  @Builder
  private buildAppCard(): void {
    Column({ space: 14 }) {
      Row() {
        Text('允许使用的应用')
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
  private buildPartnerRow(): void {
    Row() {
      Text('互督搭子')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .layoutWeight(1)
      Text(this.targetName.length > 0 ? this.targetName : '选择互督搭子')
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 160 })
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([AppTheme.colors.textMuted])
        .margin({ left: 4 })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .onClick(() => {
      pushDuoPickFriend(this.targetId);
    })
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
      TextInput({ text: this.title, placeholder: '今天要一起完成什么？' })
        .width('100%')
        .height(44)
        .enterKeyType(EnterKeyType.Done)
        .onChange((value: string) => {
          this.title = value;
        })

      this.buildAppCard()
      FocusDurationCard({
        timerMode: this.timerMode,
        durationMinutes: this.durationMinutes,
        outlined: true,
        onDurationChange: (value: number) => {
          this.durationMinutes = this.normalizeDurationMinutes(value);
        },
      })
      this.buildPartnerRow()
      Button('保存')
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
        title: '编辑互督任务',
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

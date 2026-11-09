import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { minutesToHours } from '../../models/ActiveLockModel';
import { filterSessionAppsForHarmony } from '../../models/DuoModel';
import { isDuoQuickTask, QuickTask, QuickTaskUpsertPayload, startWhenLabel } from '../../models/QuickTaskModel';
import { PageRoutes, backRoute, navigateToMainTab, pushRoute } from '../../router/PageRoutes';
import { LockStore } from '../../stores/LockStore';
import { QuickTaskStore } from '../../stores/QuickTaskStore';
import { UserStore } from '../../stores/UserStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { promptEnableDuoTaskSlot, promptEnableQuickTaskSlot, upsellIfProSlotQuota } from '../../services/ProQuotaService';

bootstrapStores();

@Entry
@Component
struct QuickTaskDetailPage {
  @State private taskId: string = '';
  @State private task: QuickTask | null = null;
  @State private isLoading: boolean = true;
  @State private switchEnabled: boolean = true;
  @State private toggleBusy: boolean = false;
  @State private switchSlot: number = 0;
  @State private rowTitle: string = '';
  @State private rowDuration: string = '';
  @State private rowTimer: string = '';
  @State private rowExtraLabel: string = '';
  @State private rowExtraValue: string = '';
  @State private rowApps: string = '';
  @State private rowMode: string = '';
  @State private rowDelayTag: string = '';
  @State private showDelayTag: boolean = false;
  @State private showNoStopRow: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    QuickTaskStore.hydrate();
    this.taskId = AppStorage.get<string>(StoreKeys.QuickTaskCurrentId) ?? '';
    if (this.taskId.length === 0 || !UserStore.isLoggedIn()) {
      navigateToMainTab('plans');
      return;
    }
    this.loadTask();
  }

  onPageShow(): void {
    if (this.taskId.length === 0 || !UserStore.isLoggedIn()) {
      return;
    }
    this.refreshTaskFromStore();
  }

  private applyLoadedTask(loaded: QuickTask): void {
    this.task = loaded;
    const duo = isDuoQuickTask(loaded);
    const partner = (loaded.partner_nickname ?? '').trim();
    this.rowTitle = loaded.title.length > 0 ? loaded.title : (duo ? '互督任务' : '快捷任务');
    this.rowDuration = minutesToHours(loaded.duration_min);
    this.rowTimer = loaded.timer_mode === 'countup' ? '正计时' : '倒计时';
    this.rowExtraLabel = duo ? '互督搭子' : '开始时间';
    this.rowExtraValue = duo ? (partner.length > 0 ? partner : '搭子') : startWhenLabel(loaded.delay_min);
    this.rowApps = `${filterSessionAppsForHarmony(loaded.apps).length} 个`;
    this.rowMode = loaded.mode === 'shield' ? '锁定模式' : '放行模式';
    this.rowDelayTag = loaded.delay_min > 0 ? '延时' : '即时';
    this.showDelayTag = !duo;
    this.showNoStopRow = !duo && loaded.no_stop === true;
    if (!this.toggleBusy) {
      this.switchEnabled = loaded.enabled;
    }
    this.isLoading = false;
  }

  private refreshTaskFromStore(): void {
    void QuickTaskStore.loadAll().then(() => {
      const loaded = QuickTaskStore.getTasks().find((item: QuickTask) => item.id === this.taskId) ?? null;
      if (!loaded) {
        if (this.task === null) {
          showErrorToast('任务不存在', this.getUIContext());
          navigateToMainTab('plans');
        }
        return;
      }
      this.applyLoadedTask(loaded);
    });
  }

  private loadTask(): void {
    const cached = QuickTaskStore.getTasks().find((item: QuickTask) => item.id === this.taskId) ?? null;
    if (cached) {
      this.applyLoadedTask(cached);
      return;
    }
    void QuickTaskStore.loadAll().then(() => {
      const loaded = QuickTaskStore.getTasks().find((item: QuickTask) => item.id === this.taskId) ?? null;
      if (!loaded) {
        showErrorToast('任务不存在', this.getUIContext());
        navigateToMainTab('plans');
        return;
      }
      this.applyLoadedTask(loaded);
    });
  }

  private buildTogglePayload(task: QuickTask, enabled: boolean): QuickTaskUpsertPayload {
    const base: QuickTaskUpsertPayload = {
      title: task.title,
      duration_min: task.duration_min,
      timer_mode: task.timer_mode,
      mode: task.mode,
      delay_min: task.delay_min,
      no_stop: task.no_stop,
      apps: task.apps,
      enabled: enabled,
    };
    if (isDuoQuickTask(task)) {
      base.partner_user_id = (task.partner_user_id ?? '').trim();
      base.partner_nickname = (task.partner_nickname ?? '').trim();
    }
    return base;
  }

  private applySwitch(enabled: boolean): void {
    this.switchEnabled = enabled;
    this.switchSlot += 1;
  }

  private async onToggleEnabled(next: boolean): Promise<void> {
    const task = this.task;
    if (!task || this.toggleBusy) {
      return;
    }
    if (next) {
      const allowEnable = isDuoQuickTask(task)
        ? promptEnableDuoTaskSlot(task.id)
        : promptEnableQuickTaskSlot(task.id);
      if (!allowEnable) {
        this.applySwitch(false);
        return;
      }
      this.toggleBusy = true;
      const response = await QuickTaskStore.updateTask(task.id, this.buildTogglePayload(task, true));
      this.toggleBusy = false;
      const loaded = QuickTaskStore.getTasks().find((item: QuickTask) => item.id === task.id) ?? null;
      if (response.statusCode !== 200 || !loaded || !loaded.enabled) {
        const message = response.message ?? '保存失败';
        if (response.statusCode !== 200 && !upsellIfProSlotQuota(message, isDuoQuickTask(task) ? 'duo' : 'quick')) {
          showErrorToast(message, this.getUIContext());
        }
        this.applySwitch(false);
        return;
      }
      this.task = loaded;
      this.applySwitch(true);
      return;
    }
    this.switchEnabled = false;
    task.enabled = false;
    this.task = task;
    this.toggleBusy = true;
    const response = await QuickTaskStore.updateTask(task.id, this.buildTogglePayload(task, false));
    this.toggleBusy = false;
    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? '保存失败', this.getUIContext());
      this.loadTask();
      return;
    }
    const loaded = QuickTaskStore.getTasks().find((item: QuickTask) => item.id === task.id) ?? null;
    if (loaded) {
      this.task = loaded;
      this.switchEnabled = loaded.enabled;
    }
  }

  private toEdit(): void {
    if (!this.task) {
      return;
    }
    if (LockStore.isLocked()) {
      showToast('专注进行中，不可以修改任务', this.getUIContext());
      return;
    }
    AppStorage.setOrCreate(StoreKeys.QuickTaskCurrentId, this.task.id);
    pushRoute(
      isDuoQuickTask(this.task)
        ? PageRoutes.DuoQuickTaskForm
        : PageRoutes.QuickTaskForm,
    );
  }

  private confirmCancel(): void {
    if (!this.task) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '作废任务',
      message: '作废后任务将无法恢复，确认作废吗？',
      autoCancel: true,
      primaryButton: {
        value: '确认作废',
        fontColor: AppTheme.colors.danger,
        action: () => {
          void QuickTaskStore.removeTask(this.task!.id).then((response) => {
            if (response.statusCode === 200) {
              showToast('任务已作废', this.getUIContext());
              backRoute();
            }
          });
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  private getPageTitle(): string {
    return this.rowTitle.length > 0 ? this.rowTitle : '任务详情';
  }

  private shouldShowEditAction(): boolean {
    return !this.isLoading && this.task !== null;
  }

  private shouldShowDestructiveFooter(): boolean {
    return !this.isLoading && this.task !== null;
  }

  private getBottomSpacerHeight(): number {
    return this.shouldShowDestructiveFooter() ? 84 : 28;
  }

  @Builder
  private buildViewBody(): void {
    Column({ space: 18 }) {
      Column({ space: 14 }) {
        Row() {
          Text(this.rowTitle)
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .layoutWeight(1)

          if (this.showDelayTag) {
            Text(this.rowDelayTag)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.primary)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(AppTheme.colors.primarySoft)
              .borderRadius(AppTheme.radius.pill)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column({ space: 12 }) {
          Row() {
            Text('专注时长')
              .fontSize(15)
              .fontColor(AppTheme.colors.textMuted)
              .width(88)
            Text(this.rowDuration)
              .fontSize(15)
              .fontColor(AppTheme.colors.textPrimary)
              .layoutWeight(1)
          }
          .width('100%')

          Row() {
            Text('计时方式')
              .fontSize(15)
              .fontColor(AppTheme.colors.textMuted)
              .width(88)
            Text(this.rowTimer)
              .fontSize(15)
              .fontColor(AppTheme.colors.textPrimary)
              .layoutWeight(1)
          }
          .width('100%')

          Row() {
            Text(this.rowExtraLabel)
              .fontSize(15)
              .fontColor(AppTheme.colors.textMuted)
              .width(88)
            Text(this.rowExtraValue)
              .fontSize(15)
              .fontColor(AppTheme.colors.textPrimary)
              .layoutWeight(1)
          }
          .width('100%')

          Row() {
            Text('应用数量')
              .fontSize(15)
              .fontColor(AppTheme.colors.textMuted)
              .width(88)
            Text(this.rowApps)
              .fontSize(15)
              .fontColor(AppTheme.colors.textPrimary)
              .layoutWeight(1)
          }
          .width('100%')

          Row() {
            Text('锁机模式')
              .fontSize(15)
              .fontColor(AppTheme.colors.textMuted)
              .width(88)
            Text(this.rowMode)
              .fontSize(15)
              .fontColor(AppTheme.colors.textPrimary)
              .layoutWeight(1)
          }
          .width('100%')

          if (this.showNoStopRow) {
            Row() {
              Text('全程专注')
                .fontSize(15)
                .fontColor(AppTheme.colors.textMuted)
                .width(88)
              Text('已开启')
                .fontSize(15)
                .fontColor(AppTheme.colors.textPrimary)
                .layoutWeight(1)
            }
            .width('100%')
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(AppTheme.radius.lg)

      Column({ space: 8 }) {
        Row() {
          Text('启用任务')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .layoutWeight(1)
          if (this.switchSlot % 2 === 0) {
            Toggle({ type: ToggleType.Switch, isOn: this.switchEnabled })
              .enabled(!this.toggleBusy)
              .onChange((isOn: boolean) => {
                if (isOn === this.switchEnabled) {
                  return;
                }
                void this.onToggleEnabled(isOn);
              })
          } else {
            Toggle({ type: ToggleType.Switch, isOn: this.switchEnabled })
              .enabled(!this.toggleBusy)
              .onChange((isOn: boolean) => {
                if (isOn === this.switchEnabled) {
                  return;
                }
                void this.onToggleEnabled(isOn);
              })
          }
        }
        .width('100%')
        Text('启用后才会生效，关闭则不生效')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(AppTheme.radius.lg)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildDestructiveFooter(): void {
    Column({ space: 8 }) {
      Text('作废任务')
        .fontSize(13)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 8, bottom: 8 })
        .onClick(() => {
          this.confirmCancel();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 24 })
    .backgroundColor(AppTheme.colors.background)
  }

  @Builder
  private buildBody(): void {
    if (this.isLoading || this.task === null) {
      Text('加载中...')
        .fontColor(AppTheme.colors.textSecondary)
    } else {
      this.buildViewBody()
    }
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.getPageTitle(),
        showBack: true,
        usePageScroll: true,
        bottomSpacerHeight: this.getBottomSpacerHeight(),
        showAction: this.shouldShowEditAction(),
        actionLabel: '编辑',
        actionIcon: $r('sys.symbol.square_and_pencil'),
        onAction: () => {
          this.toEdit();
        },
        onBack: () => {
          backRoute();
        },
        content: (): void => {
          this.buildBody();
        }
      })

      if (this.shouldShowDestructiveFooter()) {
        Stack({ alignContent: Alignment.Bottom }) {
          this.buildDestructiveFooter()
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .height('100%')
  }
}

import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { minutesToHours } from '../../models/ActiveLockModel';
import { filterSessionAppsForHarmony } from '../../models/DuoModel';
import { QuickTask, getStartDelayLabel } from '../../models/QuickTaskModel';
import { PageRoutes, backRoute, navigateToMainTab, pushRoute } from '../../router/PageRoutes';
import { LockStore } from '../../stores/LockStore';
import { QuickTaskStore } from '../../stores/QuickTaskStore';
import { UserStore } from '../../stores/UserStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct QuickTaskDetailPage {
  @State private taskId: string = '';
  @State private task: QuickTask | null = null;
  @State private isLoading: boolean = true;

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

  private loadTask(): void {
    const cached = QuickTaskStore.getTasks().find((item: QuickTask) => item.id === this.taskId) ?? null;
    if (cached) {
      this.task = cached;
      this.isLoading = false;
      return;
    }
    void QuickTaskStore.loadAll().then(() => {
      const loaded = QuickTaskStore.getTasks().find((item: QuickTask) => item.id === this.taskId) ?? null;
      if (!loaded) {
        showErrorToast('任务不存在', this.getUIContext());
        navigateToMainTab('plans');
        return;
      }
      this.task = loaded;
      this.isLoading = false;
    });
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
    pushRoute(PageRoutes.QuickTaskForm);
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
    if (this.task && this.task.title.length > 0) {
      return this.task.title;
    }
    return '任务详情';
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

  private getTaskTitle(): string {
    if (this.task && this.task.title.length > 0) {
      return this.task.title;
    }
    return '快捷任务';
  }

  private getDelayTagLabel(): string {
    return this.task !== null && this.task.delay_min > 0 ? '延时' : '即时';
  }

  private getDurationLabel(): string {
    return minutesToHours(this.task !== null ? this.task.duration_min : 0);
  }

  private getTimerModeLabel(): string {
    return this.task?.timer_mode === 'countup' ? '正计时' : '倒计时';
  }

  private getStartDelayText(): string {
    return getStartDelayLabel(this.task !== null ? this.task.delay_min : 0);
  }

  private getAppCountLabel(): string {
    const apps = this.task !== null ? this.task.apps : [];
    return `${filterSessionAppsForHarmony(apps).length} 个`;
  }

  private getModeLabel(): string {
    return this.task?.mode === 'shield' ? '锁定模式' : '放行模式';
  }

  private showNoStop(): boolean {
    return this.task?.no_stop === true;
  }

  @Builder
  private buildStatusTag(label: string): void {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppTheme.colors.primary)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(AppTheme.colors.primarySoft)
      .borderRadius(AppTheme.radius.pill)
  }

  @Builder
  private buildViewRow(label: string, value: string): void {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppTheme.colors.textMuted)
        .width(88)
      Text(value)
        .fontSize(15)
        .fontColor(AppTheme.colors.textPrimary)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private buildViewBody(): void {
    Column({ space: 18 }) {
      Column({ space: 14 }) {
        Row() {
          Text(this.getTaskTitle())
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .layoutWeight(1)

          this.buildStatusTag(this.getDelayTagLabel())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column({ space: 12 }) {
          this.buildViewRow('专注时长', this.getDurationLabel())
          this.buildViewRow('计时方式', this.getTimerModeLabel())
          this.buildViewRow('开始时间', this.getStartDelayText())
          this.buildViewRow('应用数量', this.getAppCountLabel())
          this.buildViewRow('锁机模式', this.getModeLabel())
          if (this.showNoStop()) {
            this.buildViewRow('全程专注', '已开启')
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

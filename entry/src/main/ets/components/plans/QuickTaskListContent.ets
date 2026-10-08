import { common } from '@kit.AbilityKit';
import { showToast } from '../../common/Toast';
import { QuickTask, startWhenLabel } from '../../models/QuickTaskModel';
import { minutesToHours } from '../../models/ActiveLockModel';
import { AppTheme } from '../../constants/Theme';
import { PageRoutes, pushRoute, returnToMainTab } from '../../router/PageRoutes';
import { startQuickTask } from '../../services/StartQuickTaskService';
import { QuickTaskStore } from '../../stores/QuickTaskStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Component
export struct QuickTaskListContent {
  @Prop @Watch('onIsPageActiveChanged') isPageActive: boolean = true;

  onCreateTask?: () => void;
  onScrollerReady?: (scroller: Scroller) => void;

  private listScroller: Scroller = new Scroller();
  @StorageLink(StoreKeys.QuickTaskDirty) @Watch('onListDirtyChanged') listDirty: boolean = true;
  @StorageLink(StoreKeys.QuickTaskList) @Watch('onTasksChanged') tasks: QuickTask[] = [];
  @State instantTasks: QuickTask[] = [];
  @State delayedTasks: QuickTask[] = [];
  @State statusMessage: string = '';
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  @State startingTaskId: string = '';

  aboutToAppear(): void {
    QuickTaskStore.hydrate();
    this.syncSections();
    this.onScrollerReady?.(this.listScroller);
    if (this.isPageActive) {
      void this.syncOnVisible();
    }
  }

  private onIsPageActiveChanged(): void {
    if (this.isPageActive) {
      void this.syncOnVisible();
    }
  }

  private onTasksChanged(): void {
    this.syncSections();
  }

  private syncSections(): void {
    const instant: QuickTask[] = [];
    const delayed: QuickTask[] = [];
    for (let i = 0; i < this.tasks.length; i++) {
      const task = this.tasks[i];
      if (task.delay_min <= 0) {
        instant.push(task);
      } else {
        delayed.push(task);
      }
    }
    this.instantTasks = instant;
    this.delayedTasks = delayed;
  }

  private onListDirtyChanged(): void {
    if (!this.listDirty) {
      return;
    }
    void this.loadAll(false);
  }

  private async syncOnVisible(): Promise<void> {
    if (this.listDirty || this.tasks.length === 0) {
      await this.loadAll(false);
    }
  }

  private async loadAll(fromPull: boolean = false): Promise<void> {
    const hasCachedTasks = this.tasks.length > 0;
    if (fromPull) {
      this.isRefreshing = true;
    } else if (!hasCachedTasks) {
      this.isLoading = true;
    }

    if (!UserStore.isLoggedIn()) {
      this.statusMessage = '';
      this.isLoading = false;
      this.isRefreshing = false;
      return;
    }

    this.statusMessage = '';
    const response = await QuickTaskStore.loadAll();
    if (response.statusCode !== 200 && response.message) {
      this.statusMessage = response.message;
    }
    this.isLoading = false;
    this.isRefreshing = false;
  }

  private openDetail(task: QuickTask): void {
    AppStorage.setOrCreate(StoreKeys.QuickTaskCurrentId, task.id);
    pushRoute(PageRoutes.QuickTaskDetail);
  }

  private async handleStart(task: QuickTask): Promise<void> {
    if (!task.enabled) {
      showToast('该任务未启用，请在详情中开启', this.getUIContext());
      return;
    }
    if (this.startingTaskId.length > 0) {
      return;
    }
    this.startingTaskId = task.id;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const ok = await startQuickTask(hostContext, this.getUIContext(), task);
      if (ok) {
        returnToMainTab('focus');
      }
    } finally {
      this.startingTaskId = '';
    }
  }

  private handleCreate(): void {
    this.onCreateTask?.();
  }

  @Builder
  private buildSectionTitle(title: string): void {
    Text(title)
      .fontSize(14)
      .fontColor(AppTheme.colors.textSecondary)
      .width('100%')
      .margin({ left: 4, bottom: 10 })
  }

  @Builder
  private buildGroupedTaskList(): void {
    Column({ space: 0 }) {
      if (this.instantTasks.length > 0) {
        Column({ space: 0 }) {
          this.buildSectionTitle('即时任务')
          ForEach(this.instantTasks, (task: QuickTask, index: number) => {
            this.buildTaskCard(task, index, this.instantTasks.length)
          }, (task: QuickTask) => task.id)
        }
        .width('100%')
      }

      if (this.delayedTasks.length > 0) {
        Column({ space: 0 }) {
          this.buildSectionTitle('延时任务')
          ForEach(this.delayedTasks, (task: QuickTask, index: number) => {
            this.buildTaskCard(task, index, this.delayedTasks.length)
          }, (task: QuickTask) => task.id)
        }
        .width('100%')
        .margin({ top: this.instantTasks.length > 0 ? 20 : 0 })
      }
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
  }

  @Builder
  private buildEmptyState(): void {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.bolt'))
        .fontSize(50)
        .fontColor([AppTheme.colors.textMuted])
        .opacity(0.85)
        .margin({ bottom: 12 })

      Text('还没有快捷任务')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
        .textAlign(TextAlign.Center)

      Text('把常用的专注存成模版，每天点一下就开始。')
        .fontSize(14)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textMuted)
        .textAlign(TextAlign.Center)
        .width('100%')

      Button('新建快捷任务')
        .width('100%')
        .height(46)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .borderRadius(AppTheme.radius.button)
        .clip(true)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
        .margin({ top: 20 })
        .onClick(() => {
          this.handleCreate();
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 78 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildTaskCard(task: QuickTask, index: number, total: number): void {
    Row() {
      Column({ space: 10 }) {
        Text(task.title.length > 0 ? task.title : '快捷任务')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Column({ space: 4 }) {
          Text(`${minutesToHours(task.duration_min)} · ${task.timer_mode === 'countup' ? '正计时' : '倒计时'}`)
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')

          Text(startWhenLabel(task.delay_min))
            .fontSize(13)
            .fontColor(AppTheme.colors.textMuted)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .padding({ right: 12 })
      .alignItems(HorizontalAlign.Start)

      Button(task.enabled ? '开始' : '未启用')
        .height(28)
        .padding({ left: 14, right: 14 })
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .borderRadius(999)
        .clip(true)
        .backgroundColor(task.enabled ? AppTheme.colors.primary : AppTheme.colors.surfaceSecondary)
        .fontColor(task.enabled ? '#FFFFFF' : AppTheme.colors.textMuted)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .enabled(this.startingTaskId.length === 0)
        .onClick(() => {
          void this.handleStart(task);
        })
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: index < total - 1 ? 14 : 0 })
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(16)
    .onClick(() => {
      this.openDetail(task);
    })
  }

  build() {
    Refresh({ refreshing: $$this.isRefreshing, offset: 64, friction: 100 }) {
      Scroll(this.listScroller) {
        Column() {
          if (this.statusMessage.length > 0) {
            Text(this.statusMessage)
              .fontSize(13)
              .fontColor(AppTheme.colors.warning)
              .width('100%')
              .margin({ bottom: 8 })
          }

          if (this.isLoading && this.tasks.length === 0) {
            Column() {
              Row({ space: 8 }) {
                LoadingProgress().width(24).height(24).color(AppTheme.colors.primary)
                Text('加载中...')
                  .fontSize(14)
                  .fontColor(AppTheme.colors.textMuted)
              }
              .justifyContent(FlexAlign.Center)
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .height(220)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else if (this.tasks.length === 0) {
            this.buildEmptyState()
          } else {
            this.buildGroupedTaskList()
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .onRefreshing(() => {
      void this.loadAll(true);
    })
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .padding({ left: 20, right: 20 })
  }
}

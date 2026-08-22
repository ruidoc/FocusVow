import { common } from '@kit.AbilityKit';
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
  @State statusMessage: string = '';
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  @State startingTaskId: string = '';

  aboutToAppear(): void {
    QuickTaskStore.hydrate();
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

  private confirmRemove(task: QuickTask): void {
    this.getUIContext().showAlertDialog({
      title: '删除快捷任务',
      message: '删除后不会影响正在进行的专注。',
      primaryButton: {
        value: '删除',
        fontColor: AppTheme.colors.danger,
        action: () => {
          void QuickTaskStore.removeTask(task.id);
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  private async handleStart(task: QuickTask): Promise<void> {
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

      Text('把常用的即时、延时专注存成模版，每天点一下就开始。')
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
  private buildTaskCard(task: QuickTask, index: number): void {
    Row() {
      Column({ space: 2 }) {
        Text(task.title.length > 0 ? task.title : '快捷任务')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(`${minutesToHours(task.duration_min)} · ${task.timer_mode === 'countup' ? '正计时' : '倒计时'}`)
          .fontSize(14)
          .lineHeight(20)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')

        Text(startWhenLabel(task.delay_min))
          .fontSize(13)
          .lineHeight(18)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
      }
      .layoutWeight(1)
      .padding({ right: 12 })
      .alignItems(HorizontalAlign.Start)

      Button('开始')
        .height(28)
        .padding({ left: 14, right: 14 })
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .borderRadius(999)
        .clip(true)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .enabled(this.startingTaskId.length === 0)
        .onClick(() => {
          void this.handleStart(task);
        })
    }
    .width('100%')
    .padding(16)
    .margin({ bottom: index < this.tasks.length - 1 ? 14 : 0 })
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(16)
    .onClick(() => {
      this.openDetail(task);
    })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          this.confirmRemove(task);
        })
    )
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
            Row() {
              LoadingProgress().width(24).height(24).color(AppTheme.colors.primary)
              Text('加载中...')
                .fontSize(14)
                .fontColor(AppTheme.colors.textMuted)
                .margin({ left: 8 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
            .padding({ top: 48 })
          } else if (this.tasks.length === 0) {
            this.buildEmptyState()
          } else {
            Column() {
              ForEach(this.tasks, (task: QuickTask, index: number) => {
                this.buildTaskCard(task, index)
              }, (task: QuickTask) => task.id)
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
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

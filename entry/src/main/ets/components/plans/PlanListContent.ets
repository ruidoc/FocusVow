import { common } from '@kit.AbilityKit';
import { ScheduledSessionCard } from './ScheduledSessionCard';
import { ScheduledSceneCards } from './ScheduledSceneCards';
import { FeatureIntroCard, isFeatureIntroDismissed } from '../common/FeatureIntroCard';
import { AppTheme } from '../../constants/Theme';
import { ScheduledScenePreset } from '../../models/ScheduledScenePreset';
import { showErrorToast, showToast } from '../../common/Toast';
import { DuoSessionView, sortScheduledSessions } from '../../models/DuoModel';
import { PageRoutes, pushPlanAddFromPreset, pushRoute } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import {
  hydrateScheduledGuardSyncFlags,
  reconcileStaleScheduledWindows,
  applyScheduledGuardSyncCheckAfterListLoad,
  syncScheduledGuardsManually
} from '../../services/ScheduledCovenantService';
import { ensureScreenTimeAuthorization } from '../../services/ScreenTimeService';
import { ScheduledListFilter, ScheduledListStore } from '../../stores/ScheduledListStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

/** 定时契约暂不展示「我发起的 / 我加入的」，默认全部；改 true 可恢复 */
const SHOW_SCHEDULED_ROLE_FILTER: boolean = false;

@Component
export struct PlanListContent {
  @Prop @Watch('onIsPageActiveChanged') isPageActive: boolean = true;

  onScrollerReady?: (scroller: Scroller) => void;
  onCreatePlan?: () => void;

  private listScroller: Scroller = new Scroller();
  @StorageLink(StoreKeys.ScheduledListDirty) @Watch('onListDirtyChanged') listDirty: boolean = true;
  @StorageLink(StoreKeys.ScheduledListAll) @Watch('onAllSessionsChanged') allSessions: DuoSessionView[] = [];
  @State activeFilter: ScheduledListFilter = 'all';
  @State displaySessions: DuoSessionView[] = [];
  @State statusMessage: string = '';
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  @State syncingGuards: boolean = false;
  @StorageLink(StoreKeys.NeedsScheduledGuardSync) needsScheduledGuardSync: boolean = false;
  @StorageLink(StoreKeys.UserIsLoggedIn) isLoggedIn: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    hydrateScheduledGuardSyncFlags(hostContext);
    ScheduledListStore.hydrate();
    this.syncFilterFromStore();
    this.refreshDisplaySessions();
    this.onScrollerReady?.(this.listScroller);
    if (this.isPageActive) {
      void this.syncOnVisible();
    }
  }

  private syncFilterFromStore(): void {
    this.activeFilter = ScheduledListStore.getFilter();
  }

  private refreshDisplaySessions(): void {
    const filter = this.getCurrentFilter();
    const filtered = this.allSessions.filter((session: DuoSessionView) =>
      this.matchesFilter(session, filter));
    this.displaySessions = sortScheduledSessions(filtered);
  }

  private onIsPageActiveChanged(): void {
    if (this.isPageActive) {
      this.syncFilterFromStore();
      this.refreshDisplaySessions();
      void this.syncOnVisible();
    }
  }

  private onAllSessionsChanged(): void {
    this.refreshDisplaySessions();
  }

  private onListDirtyChanged(): void {
    if (!this.listDirty) {
      return;
    }
    void this.loadAll(false);
  }

  private async syncOnVisible(): Promise<void> {
    if (this.listDirty || this.allSessions.length === 0) {
      await this.loadAll(false);
    }
  }

  private getCurrentFilter(): ScheduledListFilter {
    if (!SHOW_SCHEDULED_ROLE_FILTER) {
      return 'all';
    }
    return this.activeFilter;
  }

  private matchesFilter(session: DuoSessionView, filter: ScheduledListFilter): boolean {
    if (filter === 'all') {
      return true;
    }
    if (filter === 'initiated') {
      return session.viewer_role === 'initiator';
    }
    return session.viewer_role === 'partner';
  }

  private async loadAll(fromPull: boolean = false): Promise<void> {
    if (fromPull) {
      this.isRefreshing = true;
    } else {
      this.isLoading = true;
    }

    if (!UserStore.isLoggedIn()) {
      this.statusMessage = '';
      this.isLoading = false;
      this.isRefreshing = false;
      return;
    }

    this.statusMessage = '';
    const response = await DuoApiService.getScheduledList();
    const list = DuoApiService.parseScheduledList(response);
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const reconciled = response.statusCode === 200
      ? await reconcileStaleScheduledWindows(list.items, hostContext)
      : list.items;
    ScheduledListStore.setAllSessions(reconciled);
    this.refreshDisplaySessions();

    if (response.statusCode !== 200 && response.message) {
      this.statusMessage = response.message;
    } else {
      ScheduledListStore.clearDirty();
      applyScheduledGuardSyncCheckAfterListLoad(hostContext, reconciled.length);
    }
    this.isLoading = false;
    this.isRefreshing = false;
  }

  private toggleFilter(filter: 'initiated' | 'joined'): void {
    const next: ScheduledListFilter = this.activeFilter === filter ? 'all' : filter;
    this.activeFilter = next;
    ScheduledListStore.setFilter(next);
    this.refreshDisplaySessions();
  }
  private openSession(session: DuoSessionView): void {
    AppStorage.setOrCreate(StoreKeys.ScheduledSessionCurrentId, session.session_id);
    pushRoute(PageRoutes.PlanDetail);
  }

  private handleCreatePlan(): void {
    this.onCreatePlan?.();
  }

  private shouldShowScenePresets(): boolean {
    return this.allSessions.length < 3;
  }

  private handleSelectPreset(preset: ScheduledScenePreset): void {
    pushPlanAddFromPreset(
      preset.name,
      preset.startTime,
      preset.endTime,
      JSON.stringify(preset.repeat),
    );
  }

  private showPendingSync(): boolean {
    return this.isLoggedIn && this.needsScheduledGuardSync && this.allSessions.length > 0;
  }

  private async syncLocalGuards(): Promise<void> {
    if (this.syncingGuards) {
      return;
    }
    this.syncingGuards = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const authResult = await ensureScreenTimeAuthorization(hostContext);
      SettingsStore.updateAuthorization(hostContext, authResult.ok, authResult.message);
      if (!authResult.ok) {
        showErrorToast('未完成系统授权，无法同步定时任务', this.getUIContext());
        return;
      }

      const result = await syncScheduledGuardsManually(hostContext);
      if (result.ok) {
        showToast('已同步到本机', this.getUIContext());
      } else if (result.message.length > 0) {
        showErrorToast(result.message, this.getUIContext());
      }
    } finally {
      this.syncingGuards = false;
    }
  }

  @Builder
  private buildSyncButton(): void {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        if (!this.syncingGuards) {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(18)
            .fontColor([AppTheme.colors.primary])
        }
        Text(this.syncingGuards ? '同步中...' : '同步定时任务')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.primary)
      }
      .width('100%')
      .height(44)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(AppTheme.radius.button)
      .opacity(this.syncingGuards ? 0.6 : 1)
      .onClick(() => {
        if (!this.syncingGuards) {
          void this.syncLocalGuards();
        }
      })

      Text('登录后需要点击同步，否则定时任务不生效')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  private buildFeatureIntro(): void {
    FeatureIntroCard({
      introId: 'scheduled_plan',
      title: '到点自动锁机',
      description: '主动开始困难？刷手机过头？在这里设置一个时间段，到点自动开始，每天帮你夺回时间',
      confirmTitle: '确定关闭功能介绍？',
      confirmMessage: '如果了解了定时任务功能，可以点击确认关闭，关闭后不再显示此介绍',
    })
  }

  private isScheduledIntroVisible(): boolean {
    return !isFeatureIntroDismissed('scheduled_plan');
  }

  @Builder
  private buildTaskListBody(): void {
    Column({ space: 0 }) {
      this.buildMyTasksHeading()
      ForEach(this.displaySessions, (session: DuoSessionView, index: number) => {
        ScheduledSessionCard({
          session,
          onPress: () => {
            this.openSession(session);
          }
        })
          .margin({ bottom: index < this.displaySessions.length - 1 ? 14 : 0 })
      }, (session: DuoSessionView) =>
        `${this.activeFilter}_${session.session_id}_${session.status}_${session.title}_${session.schedule_start}_${session.schedule_end}`)
    }
    .width('100%')
  }

  @Builder
  private buildScheduledMainContent(): void {
    Column({ space: 0 }) {
      if (this.isScheduledIntroVisible()) {
        this.buildFeatureIntro()
      }
      if (this.showPendingSync()) {
        this.buildSyncButton()
      }
      if (this.displaySessions.length > 0) {
        this.buildTaskListBody()
      } else if (!this.isLoading) {
        this.buildEmptyState()
      }
    }
    .width('100%')
  }

  @Builder
  private buildMyTasksHeading(): void {
    Text('我的任务')
      .fontSize(14)
      .fontColor(AppTheme.colors.textSecondary)
      .width('100%')
      .margin({ left: 4, bottom: 10 })
  }

  @Builder
  private buildEmptyState(): void {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.clock'))
        .fontSize(50)
        .fontColor([AppTheme.colors.textMuted])
        .opacity(0.85)
        .margin({ bottom: 12 })

      Text(this.getCurrentFilter() === 'all' ? '还没有定时任务' : '没有符合筛选的契约')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)

      Text(this.getCurrentFilter() === 'all'
        ? '到点自动锁机，不用每次手动点开启'
        : '试试取消筛选，或新建一条契约。')
        .fontSize(14)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textMuted)
        .textAlign(TextAlign.Center)
        .width('100%')

      if (this.shouldShowScenePresets() && this.getCurrentFilter() === 'all') {
        ScheduledSceneCards({
          onSelect: (preset: ScheduledScenePreset) => {
            this.handleSelectPreset(preset);
          },
        })
          .margin({ top: 24, bottom: 8 })
      }

      if (this.getCurrentFilter() === 'all' || this.getCurrentFilter() === 'initiated') {
        if (this.shouldShowScenePresets() && this.getCurrentFilter() === 'all') {
          Button('我要自定义')
            .width('100%')
            .height(46)
            .type(ButtonType.Normal)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .borderRadius(AppTheme.radius.button)
            .clip(true)
            .backgroundColor(AppTheme.colors.surface)
            .fontColor(AppTheme.colors.primary)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 8 })
            .onClick(() => {
              this.handleCreatePlan();
            })
        } else {
          Button('新建定时任务')
            .width('100%')
            .height(46)
            .type(ButtonType.Normal)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .borderRadius(AppTheme.radius.button)
            .clip(true)
            .backgroundColor(AppTheme.colors.primary)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .margin({ top: 12 })
            .onClick(() => {
              this.handleCreatePlan();
            })
        }
      }
    }
    .width('100%')
    .padding({
      left: 24,
      right: 24,
      top: 72,
      bottom: 72
    })
    .constraintSize({ minHeight: 320 })
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      List({ space: 0, scroller: this.listScroller }) {
        if (SHOW_SCHEDULED_ROLE_FILTER) {
          ListItem() {
            Row({ space: 10 }) {
              Text('我发起的')
                .fontSize(13)
                .fontWeight(this.activeFilter === 'initiated' ? FontWeight.Medium : FontWeight.Regular)
                .fontColor(this.activeFilter === 'initiated' ? AppTheme.colors.primary : AppTheme.colors.textSecondary)
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .backgroundColor(this.activeFilter === 'initiated' ? AppTheme.colors.primarySoft : AppTheme.colors.surface)
                .borderRadius(AppTheme.radius.pill)
                .border({
                  width: 1,
                  color: this.activeFilter === 'initiated' ? AppTheme.colors.primary : AppTheme.colors.border
                })
                .onClick(() => {
                  this.toggleFilter('initiated');
                })

              Text('我加入的')
                .fontSize(13)
                .fontWeight(this.activeFilter === 'joined' ? FontWeight.Medium : FontWeight.Regular)
                .fontColor(this.activeFilter === 'joined' ? AppTheme.colors.primary : AppTheme.colors.textSecondary)
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .backgroundColor(this.activeFilter === 'joined' ? AppTheme.colors.primarySoft : AppTheme.colors.surface)
                .borderRadius(AppTheme.radius.pill)
                .border({
                  width: 1,
                  color: this.activeFilter === 'joined' ? AppTheme.colors.primary : AppTheme.colors.border
                })
                .onClick(() => {
                  this.toggleFilter('joined');
                })
            }
            .width('100%')
            .padding({ top: 16 })
          }
          .margin({ bottom: 8 })
        }

        if (this.statusMessage.length > 0) {
          ListItem() {
            Text(this.statusMessage)
              .width('100%')
              .fontSize(12)
              .fontColor(AppTheme.colors.textSecondary)
          }
        }

        ListItem() {
          this.buildScheduledMainContent()
        }

        if (this.displaySessions.length > 0 && this.shouldShowScenePresets()) {
          ListItem() {
            ScheduledSceneCards({
              onSelect: (preset: ScheduledScenePreset) => {
                this.handleSelectPreset(preset);
              },
            })
              .margin({ top: 28 })
          }
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: SHOW_SCHEDULED_ROLE_FILTER ? 0 : 16 })
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
    }
    .pullToRefresh(true)
    .onRefreshing(() => {
      void this.loadAll(true);
    })
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .padding({ left: 20, right: 20 })
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean) => {
      if (isVisible && this.isPageActive) {
        void this.syncOnVisible();
      }
    })
  }
}

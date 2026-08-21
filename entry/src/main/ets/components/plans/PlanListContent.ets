import { common } from '@kit.AbilityKit';
import { ScheduledSessionCard } from './ScheduledSessionCard';
import { AppTheme } from '../../constants/Theme';
import { DuoSessionView, sortScheduledSessions } from '../../models/DuoModel';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import { getGuardSyncIssueCount, reconcileStaleScheduledWindows } from '../../services/ScheduledCovenantService';
import { ScheduledListFilter, ScheduledListStore } from '../../stores/ScheduledListStore';
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

  aboutToAppear(): void {
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
      this.statusMessage = '登录后可查看云端契约';
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
      const guardIssueCount = getGuardSyncIssueCount(hostContext);
      if (guardIssueCount > 0) {
        this.statusMessage = `有 ${guardIssueCount} 条契约待完成本机屏时配置`;
      }
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

  @Builder
  private buildEmptyState(): void {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.clock'))
        .fontSize(50)
        .fontColor([AppTheme.colors.textMuted])
        .opacity(0.85)
        .margin({ bottom: 12 })

      Text(this.getCurrentFilter() === 'all' ? '还没有契约' : '没有符合筛选的契约')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)

      Text(this.getCurrentFilter() === 'all'
        ? '创建后会在指定时间自动锁机。'
        : '试试取消筛选，或新建一条契约。')
        .fontSize(14)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textMuted)
        .textAlign(TextAlign.Center)
        .width('100%')

      if (this.getCurrentFilter() === 'all' || this.getCurrentFilter() === 'initiated') {
        Button('新建契约')
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
      List({ space: 12, scroller: this.listScroller }) {
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

        if (this.displaySessions.length === 0 && !this.isLoading) {
          ListItem() {
            this.buildEmptyState()
          }
        }

        ForEach(this.displaySessions, (session: DuoSessionView) => {
          ListItem() {
            ScheduledSessionCard({
              session,
              onPress: () => {
                this.openSession(session);
              }
            })
          }
        }, (session: DuoSessionView) =>
          `${this.activeFilter}_${session.session_id}_${session.status}_${session.title}_${session.schedule_start}_${session.schedule_end}`)
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

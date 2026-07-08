import { common } from '@kit.AbilityKit';
import { ScheduledSessionCard } from './ScheduledSessionCard';
import { AppTheme } from '../../constants/Theme';
import { DuoSessionView } from '../../models/DuoModel';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import { getGuardSyncIssueCount } from '../../services/ScheduledCovenantService';
import { ScheduledListFilter, ScheduledListStore } from '../../stores/ScheduledListStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Component
export struct PlanListContent {
  @Prop @Watch('onIsPageActiveChanged') isPageActive: boolean = true;

  onScrollerReady?: (scroller: Scroller) => void;

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
    this.displaySessions = this.allSessions.filter((session: DuoSessionView) =>
      this.matchesFilter(session, this.activeFilter));
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
    ScheduledListStore.setAllSessions(list.items);
    this.refreshDisplaySessions();

    if (response.statusCode !== 200 && response.message) {
      this.statusMessage = response.message;
    } else {
      ScheduledListStore.clearDirty();
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
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

  @Builder
  private buildEmptyState(): void {
    Column({ space: 10 }) {
      Text(this.getCurrentFilter() === 'all' ? '还没有契约' : '没有符合筛选的契约')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
      Text(this.getCurrentFilter() === 'all'
        ? '创建后会在指定时间自动锁机。'
        : '试试取消筛选，或新建一条契约。')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      if (this.getCurrentFilter() === 'all' || this.getCurrentFilter() === 'initiated') {
        Button('新建契约')
          .width('100%')
          .height(46)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.primary)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
          .margin({ top: 4 })
          .onClick(() => {
            pushRoute(PageRoutes.PlanAdd);
          })
      }
    }
    .width('100%')
    .padding(24)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      List({ space: 12, scroller: this.listScroller }) {
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

        ListItem() {
          Row() {
            Text('全部契约')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textPrimary)
            Blank()
            if (this.isLoading) {
              Text('加载中')
                .fontSize(13)
                .fontColor(AppTheme.colors.textMuted)
            }
          }
          .width('100%')
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
          `${this.activeFilter}_${session.session_id}_${session.title}_${session.schedule_start}_${session.schedule_end}`)
      }
      .width('100%')
      .height('100%')
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
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean) => {
      if (isVisible && this.isPageActive) {
        void this.syncOnVisible();
      }
    })
  }
}

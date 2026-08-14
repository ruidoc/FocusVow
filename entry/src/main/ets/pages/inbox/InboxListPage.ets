import { common } from '@kit.AbilityKit';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { InboxItem, formatInboxTime } from '../../models/InboxModel';
import { backToHome, pushInboxDetail, pushLogin } from '../../router/PageRoutes';
import { InboxStore } from '../../stores/InboxStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct InboxListPage {
  @StorageLink(StoreKeys.InboxItems) items: InboxItem[] = [];
  @StorageLink(StoreKeys.InboxLoading) loading: boolean = false;
  @StorageLink(StoreKeys.InboxUnread) unreadCount: number = 0;
  @State refreshing: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushLogin();
      return;
    }
    void this.loadList();
  }

  onPageShow(): void {
    if (!UserStore.isLoggedIn()) {
      return;
    }
    void this.loadList();
  }

  private async loadList(): Promise<void> {
    await InboxStore.fetchList();
  }

  private async onRefresh(): Promise<void> {
    this.refreshing = true;
    try {
      await this.loadList();
    } finally {
      this.refreshing = false;
    }
  }

  @Builder
  private buildEmptyState(): void {
    Column() {
      Text('暂无消息')
        .fontSize(15)
        .fontColor(AppTheme.colors.textMuted)
    }
    .width('100%')
    .padding({ top: 80 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildRow(item: InboxItem, showDivider: boolean): void {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(item.title)
            .fontSize(16)
            .fontWeight(item.read ? FontWeight.Regular : FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          if (item.subtitle.length > 0) {
            Text(item.subtitle)
              .fontSize(13)
              .fontColor(AppTheme.colors.textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Column({ space: 4 }) {
          Text(item.kind === 'important' ? '重要' : ' ')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.danger)
            .lineHeight(16)
          Text(formatInboxTime(item.created_at))
            .fontSize(12)
            .fontColor(AppTheme.colors.textMuted)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .onClick(() => {
        pushInboxDetail(item.id);
      })
      if (showDivider) {
        Divider()
          .color(AppTheme.colors.border)
          .strokeWidth(1)
      }
    }
    .width('100%')
    .backgroundColor(AppTheme.colors.surface)
  }

  @Builder
  private buildListContent(): void {
    if (this.loading && this.items.length === 0) {
      Column() {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.colors.primary)
      }
      .width('100%')
      .padding({ top: 80 })
      .alignItems(HorizontalAlign.Center)
    } else if (this.items.length === 0) {
      this.buildEmptyState()
    } else {
      Column() {
        ForEach(this.items, (item: InboxItem, index: number) => {
          this.buildRow(item, index < this.items.length - 1)
        }, (item: InboxItem) => item.id)
      }
      .width('100%')
    }
  }

  @Builder
  private buildPageBody(): void {
    Refresh({ refreshing: $$this.refreshing }) {
      Column() {
        this.buildListContent()
      }
      .width('100%')
      .padding({ bottom: 32 })
      .alignItems(HorizontalAlign.Start)
    }
    .onRefreshing(() => {
      void this.onRefresh();
    })
    .pullToRefresh(true)
    .width('100%')
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '消息中心',
        showBack: true,
        showAction: this.unreadCount > 0,
        actionLabel: '全部已读',
        actionIcon: $r('sys.symbol.checkmark'),
        showActionIcon: true,
        horizontalPadding: 0,
        onBack: (): void => {
          backToHome();
        },
        onAction: (): void => {
          void InboxStore.markAllRead();
        },
        content: (): void => {
          this.buildPageBody();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

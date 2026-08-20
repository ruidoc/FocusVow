import { common } from '@kit.AbilityKit';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { UsersIcon } from '../../components/common/UsersIcon';
import { AppTheme } from '../../constants/Theme';
import { OrgListItem } from '../../models/OrgModel';
import { PageRoutes, backRoute, pushLogin, pushOrgDetail, pushRoute } from '../../router/PageRoutes';
import { OrgStore } from '../../stores/OrgStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct OrgListPage {
  @StorageLink(StoreKeys.OrgDefaults) defaults: OrgListItem[] = [];
  @StorageLink(StoreKeys.OrgMine) mine: OrgListItem[] = [];
  @StorageLink(StoreKeys.OrgLoading) loading: boolean = false;
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
    await OrgStore.listDiscover();
  }

  private async onRefresh(): Promise<void> {
    this.refreshing = true;
    try {
      await this.loadList();
    } finally {
      this.refreshing = false;
    }
  }

  private getThemeColor(item: OrgListItem): string {
    return item.theme_color.length > 0 ? item.theme_color : AppTheme.colors.primary;
  }

  private getSubtitle(item: OrgListItem): string {
    const intro = item.intro.trim();
    if (intro.length > 0) {
      return `${item.member_count} 人 · ${intro}`;
    }
    return `${item.member_count} 人`;
  }

  private isEmpty(): boolean {
    return !this.loading && this.defaults.length === 0 && this.mine.length === 0;
  }

  @Builder
  private buildEmptyState(): void {
    Column({ space: 16 }) {
      UsersIcon({ iconSize: 48, color: AppTheme.colors.textMuted })
      Text('还没有组织')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
      Text('用邀请码加入组织，和同伴一起看专注排行')
        .fontSize(13)
        .fontColor(AppTheme.colors.textMuted)
        .textAlign(TextAlign.Center)
        .lineHeight(20)
        .padding({ left: 32, right: 32 })
      Button('邀请码加入')
        .height(44)
        .padding({ left: 28, right: 28 })
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(AppTheme.colors.primary)
        .borderRadius(AppTheme.radius.button)
        .clip(true)
        .margin({ top: 8 })
        .onClick(() => {
          pushRoute(PageRoutes.OrgJoin);
        })
    }
    .width('100%')
    .padding({ top: 80, bottom: 40 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildOrgRow(item: OrgListItem): void {
    Button() {
      Row({ space: 12 }) {
        Row() {
          if (item.avatar.length > 0) {
            Image(item.avatar)
              .width(44)
              .height(44)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
          } else {
            UsersIcon({ iconSize: 22, color: '#FFFFFF' })
          }
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.getThemeColor(item))
        .borderRadius(12)
        .clip(true)

        Column({ space: 2 }) {
          Text(item.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.getSubtitle(item))
            .fontSize(12)
            .fontColor(AppTheme.colors.textMuted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([AppTheme.colors.textMuted])
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .type(ButtonType.Normal)
    .buttonStyle(ButtonStyleMode.NORMAL)
    .stateEffect(false)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(14)
    .padding(16)
    .onClick(() => {
      pushOrgDetail(item.id);
    })
  }

  @Builder
  private buildSection(title: string, items: OrgListItem[]): void {
    if (items.length > 0) {
      Column({ space: 12 }) {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
          .padding({ left: 2 })
        ForEach(items, (item: OrgListItem) => {
          this.buildOrgRow(item)
        }, (item: OrgListItem) => item.id)
      }
      .width('100%')
      .margin({ bottom: 24 })
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private buildListContent(): void {
    if (this.loading && this.defaults.length === 0 && this.mine.length === 0) {
      Column() {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.colors.primary)
      }
      .width('100%')
      .padding({ top: 80 })
      .alignItems(HorizontalAlign.Center)
    } else if (this.isEmpty()) {
      this.buildEmptyState()
    } else {
      Column() {
        this.buildSection('公开组织', this.defaults)
        this.buildSection('我的组织', this.mine)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private buildPageBody(): void {
    Refresh({ refreshing: $$this.refreshing }) {
      Scroll() {
        Column() {
          this.buildListContent()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 32 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
    }
    .onRefreshing(() => {
      void this.onRefresh();
    })
    .pullToRefresh(true)
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '组织',
        showBack: true,
        showAction: true,
        actionIcon: $r('sys.symbol.plus'),
        showActionIcon: true,
        usePageScroll: false,
        horizontalPadding: 0,
        onBack: (): void => {
          backRoute();
        },
        onAction: (): void => {
          pushRoute(PageRoutes.OrgJoin);
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

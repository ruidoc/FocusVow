import { router } from '@kit.ArkUI';
import { showErrorToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { FollowGraphTab, FollowRow } from '../../models/UserSocialModel';
import { backRoute, pushUserProfile } from '../../router/PageRoutes';
import { UserSocialApiService } from '../../services/UserSocialApiService';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

function readRouteParam(key: string, fallback: string = ''): string {
  try {
    const params = router.getParams() as Record<string, Object> | undefined;
    const raw = params?.[key];
    if (typeof raw === 'string') {
      return raw;
    }
    if (raw !== undefined && raw !== null) {
      return String(raw);
    }
  } catch (_e) {
  }
  return fallback;
}

const TABS: FollowGraphTab[] = ['mutual', 'following', 'followers'];

@Entry
@Component
struct UserFollowsPage {
  @State userId: string = '';
  @State tab: FollowGraphTab = 'mutual';
  @State loading: boolean = true;
  @State list: FollowRow[] = [];
  @State actionId: string = '';

  aboutToAppear(): void {
    this.userId = readRouteParam('userId').trim();
    const tabRaw = readRouteParam('tab', 'mutual');
    this.tab = TABS.indexOf(tabRaw as FollowGraphTab) >= 0 ? tabRaw as FollowGraphTab : 'mutual';
    if (this.userId.length === 0) {
      backRoute();
      return;
    }
    void this.reload();
  }

  private tabLabel(tab: FollowGraphTab): string {
    if (tab === 'following') {
      return '关注';
    }
    if (tab === 'followers') {
      return '粉丝';
    }
    return '互关';
  }

  private async reload(): Promise<void> {
    this.loading = true;
    this.list = await UserSocialApiService.getFollowGraph(this.userId, this.tab);
    this.loading = false;
  }

  private async toggleFollow(row: FollowRow): Promise<void> {
    const myId = UserStore.getUserInfo().id;
    if (myId.length === 0 || row.id === myId || this.actionId.length > 0) {
      return;
    }
    this.actionId = row.id;
    const response = row.isFollowing
      ? await UserSocialApiService.unfollow(row.id)
      : await UserSocialApiService.follow(row.id);
    this.actionId = '';
    if (!response) {
      showErrorToast('操作失败', this.getUIContext());
      return;
    }
    await this.reload();
  }

  @Builder
  private buildPageContent(): void {
    Column() {
      Row({ space: 8 }) {
        ForEach(TABS, (item: FollowGraphTab) => {
          Text(this.tabLabel(item))
            .fontSize(14)
            .fontWeight(this.tab === item ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.tab === item ? AppTheme.colors.primary : AppTheme.colors.textSecondary)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.tab === item ? AppTheme.colors.surface : Color.Transparent)
            .borderRadius(14)
            .onClick(() => {
              this.tab = item;
              void this.reload();
            })
        }, (item: FollowGraphTab) => item)
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.loading) {
        LoadingProgress().width(28).height(28)
      } else if (this.list.length === 0) {
        Text('暂无数据')
          .fontColor(AppTheme.colors.textSecondary)
      } else {
        List({ space: 10 }) {
          ForEach(this.list, (row: FollowRow) => {
            ListItem() {
              Row({ space: 10 }) {
                if (row.avatar.trim().length > 0) {
                  Image(row.avatar).width(40).height(40).borderRadius(20)
                } else {
                  Column().width(40).height(40).borderRadius(20).backgroundColor(AppTheme.colors.surface)
                }
                Text(row.username)
                  .fontSize(15)
                  .layoutWeight(1)
                  .onClick(() => {
                    pushUserProfile(row.id);
                  })
                if (UserStore.isLoggedIn() && row.id !== UserStore.getUserInfo().id) {
                  Button(row.isFollowing ? '已关注' : '关注')
                    .height(32)
                    .fontSize(12)
                    .enabled(this.actionId.length === 0)
                    .backgroundColor(row.isFollowing ? AppTheme.colors.surface : AppTheme.colors.primary)
                    .fontColor(row.isFollowing ? AppTheme.colors.textPrimary : Color.White)
                    .onClick(() => {
                      void this.toggleFollow(row);
                    })
                }
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
            }
          }, (row: FollowRow) => row.id)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '关注列表',
        showBack: true,
        onBack: (): void => {
          backRoute();
        },
        content: (): void => {
          this.buildPageContent();
        },
      })
    }
    .width('100%')
    .height('100%')
  }
}

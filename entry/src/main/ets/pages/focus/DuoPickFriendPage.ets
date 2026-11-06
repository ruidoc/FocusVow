import { router } from '@kit.ArkUI';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { backRoute } from '../../router/PageRoutes';
import { MutualFriendRow, UserSocialApiService } from '../../services/UserSocialApiService';
import { stageDuoPartnerPick } from '../../services/DuoPartnerPickService';

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

@Entry
@Component
struct DuoPickFriendPage {
  @State loading: boolean = true;
  @State list: MutualFriendRow[] = [];
  @State selectedId: string = '';

  aboutToAppear(): void {
    this.selectedId = readRouteParam('target').trim();
    void this.reload();
  }

  private async reload(): Promise<void> {
    this.loading = true;
    this.list = await UserSocialApiService.getMutualFriends();
    this.loading = false;
  }

  private applyPick(target: string, name: string): void {
    stageDuoPartnerPick(target, name);
    backRoute();
  }

  @Builder
  private buildInviteByCodeRow(): void {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.link'))
        .fontSize(22)
        .fontColor([AppTheme.colors.textPrimary])
      Text('邀请码 / 链接邀请')
        .fontSize(16)
        .fontColor(AppTheme.colors.textPrimary)
        .layoutWeight(1)
      if (this.selectedId.length === 0) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(18)
          .fontColor([AppTheme.colors.primary])
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 18, right: 18 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
    .onClick(() => {
      this.applyPick('', '');
    })
  }

  @Builder
  private buildFriendRow(friend: MutualFriendRow): void {
    Row({ space: 12 }) {
      if (friend.avatar.length > 0) {
        Image(friend.avatar)
          .width(40)
          .height(40)
          .borderRadius(14)
          .objectFit(ImageFit.Cover)
          .backgroundColor(AppTheme.colors.surfaceRaised)
      } else {
        SymbolGlyph($r('sys.symbol.person'))
          .fontSize(36)
          .fontColor([AppTheme.colors.textMuted])
      }
      Text(friend.username.length > 0 ? friend.username : '用户')
        .fontSize(16)
        .fontColor(AppTheme.colors.textPrimary)
        .layoutWeight(1)
      if (this.selectedId === friend.id) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(18)
          .fontColor([AppTheme.colors.primary])
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 18, right: 18 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
    .margin({ top: 10 })
    .onClick(() => {
      this.applyPick(friend.id, friend.username);
    })
  }

  @Builder
  private buildContent(): void {
    Column({ space: 12 }) {
      this.buildInviteByCodeRow()

      if (this.loading) {
        LoadingProgress()
          .width(32)
          .height(32)
          .margin({ top: 24 })
      } else if (this.list.length === 0) {
        Text('暂无互关好友')
          .fontSize(14)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 20 })
        Text('互相关注后可在此直接指定搭子，或使用邀请码。')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
          .textAlign(TextAlign.Center)
      } else {
        Text('从互关好友中选择')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
          .margin({ top: 8, bottom: 4 })
        ForEach(this.list, (friend: MutualFriendRow) => {
          this.buildFriendRow(friend)
        }, (friend: MutualFriendRow) => friend.id)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '选择搭子',
        showBack: true,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildContent();
        },
      })
    }
    .width('100%')
    .height('100%')
  }
}

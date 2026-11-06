import { common } from '@kit.AbilityKit';
import { showErrorToast } from '../../common/Toast';
import { UsersIcon } from '../common/UsersIcon';
import { AppTheme } from '../../constants/Theme';
import { homeGlassCardBg, homeGlassPrimaryIconBg } from '../../constants/HomeCardStyle';
import { DuoSessionView } from '../../models/DuoModel';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import { DuoInviteClipboardService } from '../../services/DuoInviteClipboardService';
import { getPendingRemainSeconds, hasPendingQuickStart } from '../../services/PendingQuickStartService';
import { hydrateScheduledGuardSyncFlags } from '../../services/ScheduledCovenantService';
import { StoreKeys } from '../../stores/StoreKeys';
import { HomeDuoWaitBanner } from './HomeDuoWaitBanner';
import { HomeGlassSurface } from './HomeGlassSurface';
import { HomeScheduledSyncBanner } from './HomeScheduledSyncBanner';

@Component
export struct HomeNoticePrimaryBanner {
  @StorageLink(StoreKeys.DuoWaitSessionId) duoWaitSessionId: string = '';
  @StorageLink(StoreKeys.DuoWaitIsScheduled) duoWaitIsScheduled: boolean = false;
  @StorageLink(StoreKeys.UserIsLoggedIn) @Watch('onLoggedInChanged') isLoggedIn: boolean = false;
  @StorageLink(StoreKeys.NeedsScheduledGuardSync) needsScheduledGuardSync: boolean = false;
  @StorageLink(StoreKeys.ScheduledListAll) scheduledSessions: DuoSessionView[] = [];
  @State friendInviteToken: string = '';
  @State friendInviteName: string = '';
  @State friendInviteMinutes: number = 0;
  private pollTimer: number = -1;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    hydrateScheduledGuardSyncFlags(hostContext);
    void this.loadFriendInvite();
    this.pollTimer = setInterval(() => {
      void this.loadFriendInvite();
    }, 8000);
  }

  aboutToDisappear(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private onLoggedInChanged(): void {
    void this.loadFriendInvite();
  }

  private async loadFriendInvite(): Promise<void> {
    if (!this.isLoggedIn) {
      this.friendInviteToken = '';
      return;
    }
    try {
      const response = await DuoApiService.getPendingFriendInvite();
      const invite = DuoApiService.parsePendingFriendInvite(response);
      if (!invite) {
        this.friendInviteToken = '';
        return;
      }
      this.friendInviteToken = invite.token;
      this.friendInviteName = invite.initiatorName;
      this.friendInviteMinutes = invite.durationMin;
    } catch (_error) {
      this.friendInviteToken = '';
    }
  }

  private showDuoWaitPrimary(): boolean {
    return this.duoWaitSessionId.length > 0 && !this.duoWaitIsScheduled;
  }

  private showFriendInvitePrimary(): boolean {
    return this.isLoggedIn && this.friendInviteToken.length > 0;
  }

  private showScheduledSyncPrimary(): boolean {
    return this.isLoggedIn && this.needsScheduledGuardSync && this.scheduledSessions.length > 0;
  }

  private openFriendInvite(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (hasPendingQuickStart(hostContext) && getPendingRemainSeconds(hostContext) <= 20 * 60) {
      showErrorToast('已有即将开始的预约专注', this.getUIContext());
      return;
    }
    DuoInviteClipboardService.stashJoinToken(this.friendInviteToken);
    pushRoute(PageRoutes.DuoJoin);
  }

  @Builder
  private buildFriendInviteBanner(): void {
    Row({ space: 12 }) {
      Row() {
        UsersIcon({ iconSize: 18, color: AppTheme.colors.primary })
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .borderRadius(18)
      .backgroundColor(homeGlassPrimaryIconBg())

      Column({ space: 2 }) {
        Text('立即加入')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(1)
        Text(`${this.friendInviteName} 邀请你专注 ${this.friendInviteMinutes} 分钟`)
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([AppTheme.colors.textMuted])
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .onClick(() => {
      this.openFriendInvite();
    })
  }

  build() {
    if (this.showDuoWaitPrimary()) {
      Column() {
        HomeDuoWaitBanner({ embedInNoticeHub: true })
      }
      .width('100%')
      .margin({ top: 12 })
    } else if (this.showFriendInvitePrimary()) {
      Column() {
        HomeGlassSurface({
          glassBackgroundColor: homeGlassCardBg(),
          fitContent: true,
          content: (): void => {
            this.buildFriendInviteBanner();
          },
        })
      }
      .width('100%')
      .margin({ top: 12 })
    } else if (this.showScheduledSyncPrimary()) {
      Column() {
        HomeScheduledSyncBanner({ embedInNoticeHub: true })
      }
      .width('100%')
      .margin({ top: 12 })
    } else {
      Column().width('100%').height(0)
    }
  }
}

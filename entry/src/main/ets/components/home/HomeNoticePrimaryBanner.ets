import { common } from '@kit.AbilityKit';
import { showErrorToast } from '../../common/Toast';
import { UsersIcon } from '../common/UsersIcon';
import { AppTheme } from '../../constants/Theme';
import { homeGlassCardBg, homeGlassPrimaryIconBg } from '../../constants/HomeCardStyle';
import { DuoSessionView } from '../../models/DuoModel';
import { PageRoutes, pushFocusScheduled, pushRoute } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import { DuoInviteClipboardService } from '../../services/DuoInviteClipboardService';
import {
  formatPendingQuickStartClockTime,
  formatPendingRemainClock,
  getPendingQuickStart,
  getPendingRemainSeconds,
  hasPendingQuickStart,
  isClockPendingQuickStart,
} from '../../services/PendingQuickStartService';
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
  @StorageLink(StoreKeys.PendingQuickStartStartAtMs) @Watch('onPendingQuickStartChanged') pendingStartAtMs: number = 0;
  @StorageLink(StoreKeys.PendingQuickStartTitle) @Watch('onPendingQuickStartChanged') pendingTitle: string = '';
  @State pendingSubtitle: string = '';
  private pollTimer: number = -1;
  private remainTimer: number = -1;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    hydrateScheduledGuardSyncFlags(hostContext);
    this.refreshPendingSubtitle();
    void this.loadFriendInvite();
    this.pollTimer = setInterval(() => {
      void this.loadFriendInvite();
    }, 8000);
    this.remainTimer = setInterval(() => {
      this.refreshPendingSubtitle();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
    if (this.remainTimer >= 0) {
      clearInterval(this.remainTimer);
      this.remainTimer = -1;
    }
  }

  private onLoggedInChanged(): void {
    void this.loadFriendInvite();
  }

  private onPendingQuickStartChanged(): void {
    this.refreshPendingSubtitle();
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

  private showPendingQuickStartPrimary(): boolean {
    return this.pendingStartAtMs > 0 && this.pendingTitle.length > 0;
  }

  private refreshPendingSubtitle(): void {
    if (!this.showPendingQuickStartPrimary()) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const pending = getPendingQuickStart(hostContext);
    if (pending === null) {
      this.pendingSubtitle = this.pendingTitle;
      return;
    }
    if (isClockPendingQuickStart(pending)) {
      const clock = formatPendingQuickStartClockTime(pending.startAtMs);
      this.pendingSubtitle = `${clock} 开始 · ${pending.title}`;
      return;
    }
    const time = formatPendingRemainClock(getPendingRemainSeconds(hostContext));
    this.pendingSubtitle = `${time} 后开始 · ${pending.title}`;
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
  private buildPendingQuickStartBanner(): void {
    Row({ space: 12 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.clock'))
          .fontSize(18)
          .fontColor([AppTheme.colors.primary])
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .borderRadius(18)
      .backgroundColor(homeGlassPrimaryIconBg())

      Column({ space: 2 }) {
        Text('预约专注')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(1)
        Text(this.pendingSubtitle)
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
          .maxLines(2)
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
      pushFocusScheduled();
    })
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
    if (this.showPendingQuickStartPrimary()) {
      Column() {
        HomeGlassSurface({
          glassBackgroundColor: homeGlassCardBg(),
          fitContent: true,
          content: (): void => {
            this.buildPendingQuickStartBanner();
          },
        })
      }
      .width('100%')
      .margin({ top: 12 })
      .borderRadius(28)
      .clip(true)
    } else if (this.showDuoWaitPrimary()) {
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
      .borderRadius(28)
      .clip(true)
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

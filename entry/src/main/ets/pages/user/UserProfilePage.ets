import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { router, window } from '@kit.ArkUI';
import { showErrorToast, showToast } from '../../common/Toast';
import { AppTheme, isDarkThemeMode } from '../../constants/Theme';
import { ContractProfile, PointTierKey, tierLabel } from '../../models/PointModel';
import { backRoute, PageRoutes, pushPointLogs, pushRoute, pushUserFollows } from '../../router/PageRoutes';
import { stageDuoPartnerPick } from '../../services/DuoPartnerPickService';
import { getPendingRemainSeconds, hasPendingQuickStart } from '../../services/PendingQuickStartService';
import { PointApiService } from '../../services/PointApiService';
import { UserSocialApiService } from '../../services/UserSocialApiService';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { formatContractPoints } from '../../utils/ContractPointUtil';

bootstrapStores();

const HERO_INK: string = '#FFFFFF';
const HERO_MUTED: string = 'rgba(255,255,255,0.78)';
const PRO_GOLD: string = '#D4A44A';

function readRouteParam(key: string): string {
  try {
    const params = router.getParams() as Record<string, Object> | undefined;
    const raw = params?.[key];
    if (typeof raw === 'string') {
      return raw.trim();
    }
    if (raw !== undefined && raw !== null) {
      return String(raw).trim();
    }
  } catch (_error) {
  }
  return '';
}

function formatRateMain(rate: number): string {
  if (!Number.isFinite(rate)) {
    return '0';
  }
  const rounded = Math.round(rate * 10) / 10;
  if (rounded % 1 === 0) {
    return `${Math.round(rounded)}`;
  }
  return `${rounded}`;
}

function tierBadgeColor(key: PointTierKey): string {
  if (key === 'keeper') {
    return '#06B6D4';
  }
  if (key === 'guardian') {
    return '#F97316';
  }
  if (key === 'master') {
    return '#F59E0B';
  }
  return '#94A3B8';
}

@Entry
@Component
struct UserProfilePage {
  @State userId: string = '';
  @State loading: boolean = true;
  @State profile: ContractProfile | null = null;
  @State followBusy: boolean = false;
  @State topInset: number = 0;
  @State bottomInset: number = 0;

  private sheetBg(): string {
    return isDarkThemeMode() ? AppTheme.colors.surface : '#FFFFFF';
  }

  aboutToAppear(): void {
    const id = readRouteParam('userId');
    if (id.length === 0) {
      backRoute();
      return;
    }
    this.userId = id;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const ui = this.getUIContext();
    window.getLastWindow(hostContext, (err, win) => {
      if (err.code) {
        return;
      }
      const statusAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topInset = Math.max(ui.px2vp(statusAvoid.topRect.height), 0);
      const navAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.bottomInset = Math.max(ui.px2vp(navAvoid.bottomRect.height), 0);
    });
    void this.reload();
  }

  onPageShow(): void {
    if (this.userId.length > 0) {
      void this.reload();
    }
  }

  private async reload(): Promise<void> {
    const data = await PointApiService.getProfile(this.userId);
    if (!data) {
      this.loading = false;
      this.profile = null;
      showErrorToast('该用户不存在', this.getUIContext());
      backRoute();
      return;
    }
    this.profile = data;
    this.loading = false;
  }

  private rateColor(): string {
    const rate = this.profile?.finishRate ?? 0;
    if (rate >= 90) {
      return '#A7F3D0';
    }
    if (rate >= 70) {
      return HERO_INK;
    }
    return '#FDE68A';
  }

  private idSuffix(): string {
    const id = this.profile?.id ?? '';
    if (id.length <= 8) {
      return id;
    }
    return id.slice(id.length - 8);
  }

  private copyUserId(): void {
    const suffix = this.idSuffix();
    if (suffix.length === 0) {
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, suffix);
    pasteboard.getSystemPasteboard().setData(data);
    showToast('ID 已复制', this.getUIContext());
  }

  private openFollows(tab: string): void {
    const profile = this.profile;
    if (!profile || !profile.isMe) {
      return;
    }
    pushUserFollows(profile.id, tab);
  }

  private async toggleFollow(): Promise<void> {
    const profile = this.profile;
    if (!profile || profile.isMe || this.followBusy) {
      return;
    }
    this.followBusy = true;
    const response = profile.isFollowing
      ? await UserSocialApiService.unfollow(profile.id)
      : await UserSocialApiService.follow(profile.id);
    this.followBusy = false;
    if (!response) {
      showErrorToast('操作失败', this.getUIContext());
      return;
    }
    const next: ContractProfile = {
      id: profile.id,
      username: profile.username,
      avatar: profile.avatar,
      isPro: profile.isPro,
      isMe: profile.isMe,
      points: profile.points,
      tierLevel: profile.tierLevel,
      tierKey: profile.tierKey,
      joinDays: profile.joinDays,
      beatPercent: profile.beatPercent,
      siteRank: profile.siteRank,
      streakDays: profile.streakDays,
      totalMins: profile.totalMins,
      successCount: profile.successCount,
      finishRate: profile.finishRate,
      breakCount: profile.breakCount,
      identity: profile.identity,
      goal: profile.goal,
      bio: profile.bio,
      followingCount: profile.followingCount,
      followerCount: profile.followerCount,
      isFollowing: response.isFollowing,
      isFollowedBy: response.isFollowedBy,
      isMutual: response.isMutual,
    };
    this.profile = next;
  }

  private inviteDuo(): void {
    const profile = this.profile;
    if (!profile) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (hasPendingQuickStart(hostContext) && getPendingRemainSeconds(hostContext) <= 20 * 60) {
      showErrorToast('已有即将开始的预约专注', this.getUIContext());
      return;
    }
    stageDuoPartnerPick(profile.id, profile.username);
    pushRoute(PageRoutes.DuoCreate);
  }

  private onFollowPress(): void {
    const profile = this.profile;
    if (!profile || this.followBusy) {
      return;
    }
    if (profile.isMutual) {
      this.inviteDuo();
      return;
    }
    void this.toggleFollow();
  }

  @Builder
  private buildAvatar(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.profile !== null && this.profile.avatar.trim().length > 0) {
        Image(this.profile.avatar)
          .width(80)
          .height(80)
          .borderRadius(40)
          .objectFit(ImageFit.Cover)
          .border({ width: 3, color: 'rgba(255,255,255,0.92)' })
      } else {
        Image($r('app.media.startIcon'))
          .width(80)
          .height(80)
          .borderRadius(40)
          .objectFit(ImageFit.Cover)
          .border({ width: 3, color: 'rgba(255,255,255,0.92)' })
      }
      Text(`Lv.${this.profile !== null ? this.profile.tierLevel : 1}`)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .padding({ left: 6, right: 6, top: 1, bottom: 1 })
        .borderRadius(6)
        .backgroundColor(tierBadgeColor(this.profile !== null ? this.profile.tierKey : 'starter'))
        .margin({ right: -4, bottom: -2 })
    }
    .width(80)
    .height(80)
  }

  @Builder
  private buildNumUnit(num: string, unit: string, color: string): void {
    Row() {
      Text(num)
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
      Text(unit)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
        .margin({ left: 2, bottom: 2 })
    }
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  private buildDurationValue(mins: number, color: string): void {
    if (mins < 60) {
      this.buildNumUnit(`${mins}`, '分钟', color)
    } else if (mins % 60 === 0) {
      this.buildNumUnit(`${Math.floor(mins / 60)}`, '小时', color)
    } else {
      Row({ space: 4 }) {
        this.buildNumUnit(`${Math.floor(mins / 60)}`, '小时', color)
        this.buildNumUnit(`${mins % 60}`, '分钟', color)
      }
    }
  }

  @Builder
  private buildStatCard(symbol: Resource, label: string, color: string, kind: string): void {
    Column() {
      SymbolGlyph(symbol)
        .fontSize(18)
        .fontColor([AppTheme.colors.textMuted])
      Column() {
        if (kind === 'time') {
          this.buildDurationValue(Math.max(0, Math.floor(this.profile !== null ? this.profile.totalMins : 0)), color)
        } else if (kind === 'total') {
          this.buildNumUnit(
            `${(this.profile !== null ? this.profile.successCount : 0) + (this.profile !== null ? this.profile.breakCount : 0)}`,
            '次',
            color,
          )
        } else if (kind === 'keep') {
          this.buildNumUnit(`${this.profile !== null ? this.profile.successCount : 0}`, '次', color)
        } else {
          this.buildNumUnit(`${this.profile !== null ? this.profile.breakCount : 0}`, '次', color)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 8, bottom: 6 })
      Text(label)
        .fontSize(11)
        .fontColor(AppTheme.colors.textMuted)
        .maxLines(1)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(14)
    .borderRadius(16)
    .backgroundColor(isDarkThemeMode() ? AppTheme.colors.background : '#F5F7FB')
  }

  @Builder
  private buildHero(): void {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(26)
          .fontColor([HERO_INK])
          .onClick(() => {
            backRoute();
          })
        Blank().layoutWeight(1)
        if (this.profile !== null && !this.profile.isMe && this.profile.siteRank !== null &&
          this.profile.siteRank >= 1 && this.profile.siteRank <= 50) {
          Row({ space: 4 }) {
            Text(`契约分排行第 ${this.profile.siteRank}`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(HERO_INK)
              .maxLines(1)
          }
          .margin({ right: 8 })
        }
        if (this.profile !== null && this.profile.isMe) {
          Text('编辑')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(HERO_INK)
            .padding({ left: 4, right: 4, top: 8, bottom: 8 })
            .onClick(() => {
              router.pushUrl({ url: PageRoutes.ProfileEdit }).catch(() => {});
            })
        }
      }
      .width('100%')
      .height(44)
      .alignItems(VerticalAlign.Center)

      Row() {
        this.buildAvatar()
        Column() {
          Row({ space: 6 }) {
            Text(this.profile !== null && this.profile.username.length > 0 ? this.profile.username : '用户')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(HERO_INK)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: '70%' })
            if (this.profile !== null && this.profile.isPro) {
              Text('Pro')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(6)
                .backgroundColor(PRO_GOLD)
            }
          }
          .width('100%')
          Row({ space: 8 }) {
            Text(tierLabel(this.profile !== null ? this.profile.tierKey : 'starter'))
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(HERO_INK)
              .padding({ left: 10, right: 10, top: 2, bottom: 2 })
              .borderRadius(999)
              .backgroundColor('rgba(255,255,255,0.22)')
            if (this.profile !== null && this.profile.joinDays > 0) {
              Text(`已专注 ${this.profile.joinDays} 天`)
                .fontSize(12)
                .fontColor(HERO_MUTED)
            }
          }
          .margin({ top: 8 })
          Row({ space: 16 }) {
            Text() {
              Span(`${this.profile !== null ? this.profile.followingCount : 0}`)
                .fontColor(HERO_INK)
                .fontWeight(FontWeight.Bold)
              Span('  关注')
                .fontColor(HERO_MUTED)
            }
            .fontSize(13)
            .onClick(() => {
              this.openFollows('following');
            })
            Text() {
              Span(`${this.profile !== null ? this.profile.followerCount : 0}`)
                .fontColor(HERO_INK)
                .fontWeight(FontWeight.Bold)
              Span('  粉丝')
                .fontColor(HERO_MUTED)
            }
            .fontSize(13)
            .onClick(() => {
              this.openFollows('followers');
            })
          }
          .margin({ top: 10 })
          if (this.profile !== null && this.profile.bio.length > 0) {
            Text(this.profile.bio)
              .fontSize(13)
              .fontColor(HERO_MUTED)
              .lineHeight(18)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 8 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 14 })
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 6 })

      Row() {
        Column() {
          Row({ space: 4 }) {
            Text('契约分')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(HERO_MUTED)
          }
          Text(formatContractPoints(this.profile !== null ? this.profile.points : 0))
            .fontSize(36)
            .fontWeight(FontWeight.Medium)
            .fontColor(HERO_INK)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          if (this.profile !== null && this.profile.isMe) {
            pushPointLogs();
          }
        })
        Row()
          .width(1)
          .height(40)
          .backgroundColor('rgba(255,255,255,0.28)')
        Column() {
          Text('守约率')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(HERO_MUTED)
          Row() {
            Text(formatRateMain(this.profile !== null ? this.profile.finishRate : 0))
              .fontSize(36)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.rateColor())
            Text('%')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.rateColor())
              .margin({ left: 1, bottom: 4 })
          }
          .alignItems(VerticalAlign.Bottom)
          .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .margin({ top: 28 })
      .alignItems(VerticalAlign.Center)

      if (this.profile !== null && this.profile.streakDays > 0) {
        Text(`连续专注 ${this.profile.streakDays} 天`)
          .fontSize(12)
          .fontColor(HERO_MUTED)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: this.topInset,
      bottom: 40,
    })
    .alignItems(HorizontalAlign.Start)
    .linearGradient({
      angle: 135,
      colors: [['#9B8AF8', 0], ['#6D5AF8', 1]],
    })
  }

  @Builder
  private buildSheet(): void {
    Column() {
      Text('自律档案')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
        .margin({ bottom: 14 })
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          this.buildStatCard($r('sys.symbol.timer'), '累计专注', AppTheme.colors.textPrimary, 'time')
          this.buildStatCard($r('sys.symbol.square_grid_2x2'), '累计场次', AppTheme.colors.textPrimary, 'total')
        }
        .width('100%')
        Row({ space: 10 }) {
          this.buildStatCard($r('sys.symbol.checkmark_circle'), '守约', AppTheme.colors.success, 'keep')
          this.buildStatCard(
            $r('sys.symbol.xmark'),
            '毁约',
            this.profile !== null && this.profile.breakCount === 0
              ? AppTheme.colors.textPrimary
              : AppTheme.colors.danger,
            'tear',
          )
        }
        .width('100%')
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 22, bottom: 16 })
    .margin({ top: -24 })
    .layoutWeight(1)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .backgroundColor(this.sheetBg())
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildBottomBar(): void {
    if (this.profile !== null && this.profile.isMe && this.idSuffix().length > 0) {
      Row({ space: 6 }) {
        Text(`ID：${this.idSuffix()}`)
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
        SymbolGlyph($r('sys.symbol.doc_plaintext'))
          .fontSize(17)
          .fontColor([AppTheme.colors.primary])
          .onClick(() => {
            this.copyUserId();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 10, bottom: Math.max(this.bottomInset, 12) + 8 })
      .backgroundColor(this.sheetBg())
    } else if (this.profile !== null && !this.profile.isMe && UserStore.isLoggedIn()) {
      Column({ space: 8 }) {
        Row({ space: 4 }) {
          if (this.followBusy) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color(this.profile.isMutual || !this.profile.isFollowing ? '#FFFFFF' : AppTheme.colors.textPrimary)
          } else {
            if (!this.profile.isFollowing) {
              SymbolGlyph($r('sys.symbol.plus'))
                .fontSize(20)
                .fontColor(['#FFFFFF'])
            }
            Text(this.profile.isMutual ? '邀请 TA 互督' : this.profile.isFollowing ? '已关注' : '关注')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.profile.isMutual || !this.profile.isFollowing ? '#FFFFFF' : AppTheme.colors.textPrimary)
          }
        }
        .width('100%')
        .height(48)
        .justifyContent(FlexAlign.Center)
        .borderRadius(30)
        .backgroundColor(this.profile.isMutual || !this.profile.isFollowing ? AppTheme.colors.primary : Color.Transparent)
        .border({
          width: this.profile.isMutual || !this.profile.isFollowing ? 0 : 1,
          color: AppTheme.colors.border,
        })
        .opacity(this.followBusy ? 0.65 : 1)
        .onClick(() => {
          this.onFollowPress();
        })
        if (this.profile.isMutual) {
          Text('互相关注可以直接发起互督')
            .fontSize(12)
            .fontColor(AppTheme.colors.textMuted)
            .width('100%')
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10, bottom: Math.max(this.bottomInset, 12) + 8 })
      .backgroundColor(this.sheetBg())
    }
  }

  build() {
    Column() {
      if (this.loading && this.profile === null) {
        Column() {
          LoadingProgress().width(32).height(32).color(AppTheme.colors.primary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.profile === null) {
        Column() {
          Text('该用户不存在')
            .fontColor(AppTheme.colors.textSecondary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          this.buildHero()
          this.buildSheet()
        }
        .layoutWeight(1)
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
        .backgroundColor(this.sheetBg())
        this.buildBottomBar()
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.sheetBg())
  }
}

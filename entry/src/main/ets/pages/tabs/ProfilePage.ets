import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { common } from '@kit.AbilityKit';
import { OrgListItem } from '../../models/OrgModel';
import { createEmptyUserInfo, UserInfo } from '../../models/UserModel';
import { PageRoutes, pushLogin, pushRoute } from '../../router/PageRoutes';
import { CycleGuardStore } from '../../stores/CycleGuardStore';
import { BenefitStore } from '../../stores/BenefitStore';
import { OrgStore } from '../../stores/OrgStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { SettingsStore } from '../../stores/SettingsStore';
import { FeatureFlagKeys } from '../../config/FeatureFlags';
import { FeatureFlagStore } from '../../stores/FeatureFlagStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';

bootstrapStores();

/** 娱乐限额入口暂时隐藏，恢复时改为 true */
const SHOW_CYCLE_GUARD_MENU: boolean = false;

/** 会员卡片展示兑换入口 */
const SHOW_MEMBERSHIP_CARD: boolean = true;

function formatMinutesLabel(min: number): string {
  if (min >= 60) {
    const h = Math.floor(min / 60);
    const m = min % 60;
    return m > 0 ? `${h}小时${m}分钟` : `${h}小时`;
  }
  return `${min}分钟`;
}

@Component
export struct ProfilePage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.CycleGuardSelectedAppCount) cycleSelectedAppCount: number = 0;
  @StorageLink(StoreKeys.CycleGuardEnabled) cycleEnabled: boolean = false;
  @StorageLink(StoreKeys.UserIsLoggedIn) isLoggedIn: boolean = false;
  @StorageLink(StoreKeys.UserInfo) userInfo: UserInfo = createEmptyUserInfo();
  @StorageLink(StoreKeys.BenefitDayDuration) dayDuration: number = 0;
  @StorageLink(StoreKeys.BenefitTodayUsed) todayUsed: number = 0;
  @StorageLink(StoreKeys.BenefitIsSubscribed) isSubscribed: boolean = false;
  @StorageLink(StoreKeys.BenefitMembershipStatus) membershipStatus: string = 'none';
  @StorageLink(StoreKeys.OrgList) orgList: OrgListItem[] = [];
  @StorageLink(StoreKeys.FeatureFlagsOff) featuresOff: string[] = [];
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    SettingsStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
    BenefitStore.hydrate(hostContext);
    FeatureFlagStore.hydrate(hostContext);
    void FeatureFlagStore.sync(hostContext);
    OrgStore.hydrate();
    void UserStore.syncRemoteIfLoggedIn(hostContext);
    if (UserStore.isLoggedIn()) {
      void BenefitStore.refresh();
      void OrgStore.listMine();
    }
  }

  private hasOwnedOrg(): boolean {
    for (let i = 0; i < this.orgList.length; i++) {
      if (this.orgList[i].role === 'owner') {
        return true;
      }
    }
    return false;
  }

  private openOrgManage(): void {
    if (!this.isLoggedIn) {
      pushLogin();
      return;
    }
    pushRoute(PageRoutes.OrgManage);
  }

  private getDisplayName(): string {
    if (this.isLoggedIn && this.userInfo.username.length > 0) {
      return this.userInfo.username;
    }
    if (this.isLoggedIn) {
      return '用户';
    }
    return '请登录';
  }

  private getDisplaySubtitle(): string {
    if (!this.isLoggedIn) {
      return '';
    }
    if (this.userInfo.email.length > 0) {
      return this.userInfo.email;
    }
    if (this.userInfo.phone.length > 0) {
      return this.userInfo.phone;
    }
    return '账号已登录';
  }

  private openProfileEntry(): void {
    if (!this.isLoggedIn) {
      pushLogin();
      return;
    }
    pushRoute(PageRoutes.ProfileEdit);
  }

  private openMembershipPage(): void {
    if (!this.isLoggedIn) {
      pushLogin();
      return;
    }
    if (this.isMembershipActive()) {
      pushRoute(PageRoutes.Redeem);
      return;
    }
    pushRoute(this.isPromoVipEnabled() ? PageRoutes.Paywall : PageRoutes.Redeem);
  }

  private isPromoVipEnabled(): boolean {
    return !this.featuresOff.includes(FeatureFlagKeys.PROMO_VIP);
  }

  private getMembershipActionLabel(): string {
    return this.isPromoVipEnabled() ? '开通' : '兑换';
  }

  private getPermissionLabel(): string {
    return this.hasAuthorized ? '已授权' : '未授权';
  }

  private getCycleStatusLabel(): string {
    return this.cycleEnabled ? '生效中' : '未生效';
  }

  private isMembershipActive(): boolean {
    return this.isSubscribed || this.membershipStatus === 'active';
  }

  private getMemberTitle(): string {
    return 'Pro 会员';
  }

  private getMemberDesc(): string {
    if (this.isMembershipActive()) {
      return '邀请搭子加入，再领60天会员！';
    }
    return this.isPromoVipEnabled()
      ? '开通会员，解锁每日无限专注'
      : '兑换会员，解锁每日无限专注';
  }

  private getQuotaProgress(): number {
    if (this.dayDuration <= 0) {
      return 0;
    }
    return Math.min(this.todayUsed / this.dayDuration, 1);
  }

  @Builder
  private buildProfileAvatar(): void {
    if (this.isLoggedIn && this.userInfo.avatar.length > 0) {
      Image(this.userInfo.avatar)
        .width(56)
        .height(56)
        .borderRadius(18)
        .objectFit(ImageFit.Cover)
        .backgroundColor(AppTheme.colors.surfaceRaised)
    } else {
      Image($r('app.media.startIcon'))
        .width(56)
        .height(56)
        .borderRadius(18)
        .objectFit(ImageFit.Cover)
        .backgroundColor(AppTheme.colors.surfaceRaised)
    }
  }

  @Builder
  private buildProfileCard(): void {
    Row() {
      Row({ space: 14 }) {
        this.buildProfileAvatar()

        Column({ space: 2 }) {
          Text(this.getDisplayName())
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')

          if (this.isLoggedIn) {
            Text(this.getDisplaySubtitle())
              .fontSize(13)
              .fontColor(AppTheme.colors.textMuted)
              .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.openProfileEntry();
      })

      if (this.isLoggedIn) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(20)
          .fontColor([AppTheme.colors.textMuted])
          .padding(8)
          .onClick(() => {
            this.openProfileEntry();
          })
      }
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildMembershipCard(): void {
    if (this.isLoggedIn) {
      Column({ space: 12 }) {
        Row() {
          Column({ space: 8 }) {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.gift'))
                .fontSize(18)
                .fontColor([this.isMembershipActive() ? '#A16207' : '#D4A44A'])
                .offset({ top: -1 })

              Text(this.getMemberTitle())
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isMembershipActive() ? '#A16207' : '#D4A44A')

              if (this.isMembershipActive()) {
                Text('生效中')
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#16A34A')
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  .backgroundColor('rgba(22,163,74,0.12)')
                  .borderRadius(6)
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Text(this.getMemberDesc())
              .fontSize(12)
              .fontColor(this.isMembershipActive() ? '#D4A44A' : '#8A8A9890')
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (!this.isMembershipActive()) {
            Button(this.getMembershipActionLabel())
              .height(32)
              .padding({ left: 14, right: 14 })
              .type(ButtonType.Normal)
              .buttonStyle(ButtonStyleMode.NORMAL)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#461702')
              .backgroundColor('#D4A44A')
              .borderRadius(16)
              .clip(true)
              .onClick(() => {
                this.openMembershipPage();
              })
          } else {
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor(['#C4A574'])
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (!this.isMembershipActive() && this.dayDuration > 0) {
          Column({ space: 6 }) {
            Row() {
              Text('今日专注时长')
                .fontSize(12)
                .fontColor(AppTheme.colors.textSecondary)
              Blank()
              Text(`${formatMinutesLabel(this.todayUsed)} / ${formatMinutesLabel(this.dayDuration)}`)
                .fontSize(12)
                .fontColor(AppTheme.colors.textSecondary)
            }
            .width('100%')

            Progress({ value: this.getQuotaProgress() * 100, total: 100, type: ProgressType.Linear })
              .width('100%')
              .height(4)
              .color(this.todayUsed >= this.dayDuration ? '#EF4444' : AppTheme.colors.primary)
              .backgroundColor(AppTheme.colors.ring)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(18)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(AppTheme.colors.surface)
      .border({
        width: 1,
        color: AppTheme.colors.border
      })
      .borderRadius(AppTheme.radius.lg)
      .clip(true)
      .onClick(() => {
        this.openMembershipPage();
      })
    }
  }

  @Builder
  private buildMenuRow(title: string, symbol: Resource, value: string, showDivider: boolean, onPress: () => void): void {
    Button() {
      Column({ space: 0 }) {
        Row({ space: 14 }) {
          SymbolGlyph(symbol)
            .fontSize(24)
            .fontColor([AppTheme.colors.textPrimary])

          Text(title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)

          Blank()

          if (value.length > 0) {
            Text(value)
              .fontSize(13)
              .fontColor(AppTheme.colors.textSecondary)
          }

          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([AppTheme.colors.textMuted])
        }
        .width('100%')
        .height(56)
        .alignItems(VerticalAlign.Center)

        if (showDivider) {
          Divider()
            .color(AppTheme.colors.divider)
            .strokeWidth(1)
        }
      }
      .width('100%')
    }
    .width('100%')
    .type(ButtonType.Normal)
    .backgroundColor(Color.Transparent)
    .padding({ left: 18, right: 18 })
    .onClick(() => {
      onPress();
    })
  }

  @Builder
  private buildProfileContent(): void {
    Column({ space: 18 }) {
      this.buildProfileCard()
      if (SHOW_MEMBERSHIP_CARD) {
        this.buildMembershipCard()
      }

      Column({ space: 0 }) {
        if (SHOW_CYCLE_GUARD_MENU) {
          this.buildMenuRow('娱乐限额', $r('sys.symbol.bolt'), this.getCycleStatusLabel(), true, () => {
            pushRoute(PageRoutes.CycleGuardEdit);
          })
        }
        this.buildMenuRow('权限管理', $r('sys.symbol.bolt_shield'), this.getPermissionLabel(), true, () => {
          pushRoute(PageRoutes.Permission);
        })
        this.buildMenuRow('意见反馈', $r('sys.symbol.ellipsis_message'), '', true, () => {
          pushRoute(PageRoutes.Feedback);
        })
        if (this.hasOwnedOrg()) {
          this.buildMenuRow('组织管理', $r('sys.symbol.person_2'), '', true, () => {
            this.openOrgManage();
          })
        }
        this.buildMenuRow('关于我们', $r('sys.symbol.square_grid_2x2'), '', true, () => {
          pushRoute(PageRoutes.About);
        })
        this.buildMenuRow('设置', $r('sys.symbol.gearshape'), '', false, () => {
          pushRoute(PageRoutes.Settings);
        })
      }
      .width('100%')
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(24)
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    SystemNavPage({
      title: '我的',
      showBack: false,
      showTitleBar: false
    }) {
      this.buildProfileContent()
    }
  }
}

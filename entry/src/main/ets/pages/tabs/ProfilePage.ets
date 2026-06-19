import { SystemNavPage } from '../../components/common/SystemNavPage';
import { showToast } from '../../common/Toast';
import { AppTheme } from '../../constants/Theme';
import { common } from '@kit.AbilityKit';
import { FocusPlan } from '../../models/PlanModel';
import { createEmptyUserInfo, UserInfo } from '../../models/UserModel';
import { PageRoutes, pushRoute, openMainTab } from '../../router/PageRoutes';
import { CycleGuardStore } from '../../stores/CycleGuardStore';
import { PlanStore } from '../../stores/PlanStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { SettingsStore } from '../../stores/SettingsStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';

bootstrapStores();

@Component
export struct ProfilePage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @StorageLink(StoreKeys.CycleGuardSelectedAppCount) cycleSelectedAppCount: number = 0;
  @StorageLink(StoreKeys.CycleGuardEnabled) cycleEnabled: boolean = false;
  @StorageLink(StoreKeys.UserIsLoggedIn) isLoggedIn: boolean = false;
  @StorageLink(StoreKeys.UserInfo) userInfo: UserInfo = createEmptyUserInfo();

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
    void UserStore.syncRemoteIfLoggedIn(hostContext);
  }

  private getDisplayName(): string {
    if (this.isLoggedIn && this.userInfo.username.length > 0) {
      return this.userInfo.username;
    }
    return '未登录';
  }

  private getDisplaySubtitle(): string {
    if (this.isLoggedIn) {
      if (this.userInfo.email.length > 0) {
        return this.userInfo.email;
      }
      return '账号已登录';
    }
    return '登录后可同步账号数据';
  }

  private openAuthPage(): void {
    if (this.isLoggedIn) {
      return;
    }
    pushRoute(PageRoutes.Login);
  }

  private logout(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.logout(hostContext);
    showToast('已退出登录', this.getUIContext());
  }

  private getPermissionLabel(): string {
    return this.hasAuthorized ? `已授权 · ${this.selectedAppCount} 个应用` : '未授权';
  }

  private getCycleStatusLabel(): string {
    return this.cycleEnabled ? '生效中' : '未生效';
  }

  @Builder
  private buildProfileCard(): void {
    Button() {
      Row({ space: 14 }) {
        Row() {
          Text('FV')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width(56)
        .height(56)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.primary)
        .borderRadius(28)

        Column({ space: 4 }) {
          Text(this.getDisplayName())
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')

          Text(this.getDisplaySubtitle())
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (!this.isLoggedIn) {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(16)
            .fontColor([AppTheme.colors.textMuted])
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .type(ButtonType.Normal)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: '#F1F3F8' })
    .borderRadius(24)
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .onClick(() => {
      this.openAuthPage();
    })
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
            .color('#EEF1F6')
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

      Column({ space: 0 }) {
        this.buildMenuRow('权限与应用', $r('sys.symbol.bolt_shield'), this.getPermissionLabel(), true, () => {
          pushRoute(PageRoutes.Permission);
        })
        this.buildMenuRow('契约管理', $r('sys.symbol.doc_plaintext'), `${this.planCollection.length} 条`, true, () => {
          openMainTab('plans');
        })
        this.buildMenuRow('娱乐限额', $r('sys.symbol.bolt'), this.getCycleStatusLabel(), true, () => {
          pushRoute(PageRoutes.CycleGuardEdit);
        })
        this.buildMenuRow('快速专注', $r('sys.symbol.timer'), '', false, () => {
          pushRoute(PageRoutes.QuickStart);
        })
      }
      .width('100%')
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: '#F1F3F8' })
      .borderRadius(24)
      .clip(true)

      Column({ space: 0 }) {
        this.buildMenuRow('设置', $r('sys.symbol.gearshape'), '', true, () => {
          pushRoute(PageRoutes.Settings);
        })
        if (this.isLoggedIn) {
          this.buildMenuRow('退出登录', $r('sys.symbol.lock'), '', false, () => {
            this.logout();
          })
        } else {
          this.buildMenuRow('登录 / 注册', $r('sys.symbol.person'), '', false, () => {
            pushRoute(PageRoutes.Login);
          })
        }
      }
      .width('100%')
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: '#F1F3F8' })
      .borderRadius(24)
      .clip(true)

      Column({ space: 0 }) {
        this.buildMenuRow('帮助与反馈', $r('sys.symbol.questionmark_circle'), '', false, () => {
          pushRoute(PageRoutes.About);
        })
      }
      .width('100%')
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: '#F1F3F8' })
      .borderRadius(24)
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    SystemNavPage({
      title: '我的',
      showAction: true,
      actionLabel: '帮助',
      actionIcon: $r('sys.symbol.questionmark_circle'),
      onAction: () => {
        pushRoute(PageRoutes.About);
      },
      horizontalPadding: 14,
      contentSpace: 18,
      content: (): void => {
        this.buildProfileContent();
      }
    })
  }
}

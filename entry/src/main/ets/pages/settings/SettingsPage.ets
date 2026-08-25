import { common } from '@kit.AbilityKit';
import { showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { backRoute, pushPrivacyPolicy, pushUserAgreement } from '../../router/PageRoutes';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';
import { ThemeStore } from '../../stores/ThemeStore';
import { UserStore } from '../../stores/UserStore';

bootstrapStores();

@Entry
@Component
struct SettingsPage {
  @StorageLink(StoreKeys.UserIsLoggedIn) isLoggedIn: boolean = false;
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    ThemeStore.hydrate(hostContext);
  }

  private async logout(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const guardError = await UserStore.logout(hostContext);
    if (guardError) {
      showToast(`已退出，但屏时策略未完全清除，可能仍无法卸载：${guardError}`, this.getUIContext());
      backRoute();
      return;
    }
    showToast('已退出登录', this.getUIContext());
    backRoute();
  }

  private confirmLogout(): void {
    this.getUIContext().showAlertDialog({
      title: '退出登录',
      message: '退出后将移除本机全部屏时策略（含本地契约与定时契约），登录后会自动恢复。确认退出吗？',
      autoCancel: true,
      primaryButton: {
        value: '确认退出',
        fontColor: AppTheme.colors.danger,
        action: () => {
          void this.logout();
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  private getFooterMessage(): string {
    if (this.isLoggedIn) {
      return '已登录账号可在这里查看协议说明，或退出当前账号。';
    }
    return '未登录时可在这里查看协议说明；需要同步数据时再登录即可。';
  }

  @Builder
  private buildMenuRow(title: string, symbol: Resource, showDivider: boolean, onPress: () => void): void {
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
  private buildDarkModeRow(): void {
    Row({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.moon'))
        .fontSize(24)
        .fontColor([AppTheme.colors.textPrimary])

      Text('深色模式')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.themeMode === 'dark' })
        .selectedColor(AppTheme.colors.primary)
        .onChange((isOn: boolean) => {
          const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
          ThemeStore.setMode(hostContext, isOn ? 'dark' : 'light');
        })
    }
    .width('100%')
    .height(56)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 18, right: 18 })
  }

  @Builder
  private buildSettingsContent(): void {
    Column({ space: 16 }) {
      Column({ space: 0 }) {
        this.buildDarkModeRow()
        Divider()
          .color(AppTheme.colors.divider)
          .strokeWidth(1)
        this.buildMenuRow('隐私政策', $r('sys.symbol.person'), true, () => {
          pushPrivacyPolicy();
        })
        this.buildMenuRow('用户协议', $r('sys.symbol.doc_plaintext'), false, () => {
          pushUserAgreement();
        })
      }
      .width('100%')
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(24)
      .clip(true)

      if (this.isLoggedIn) {
        Button('退出登录')
          .width('100%')
          .height(48)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .backgroundColor(AppTheme.colors.dangerSoft)
          .fontColor(AppTheme.colors.danger)
          .onClick(() => {
            this.confirmLogout();
          })
      }

    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '设置',
        showBack: true,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildSettingsContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

import { common } from '@kit.AbilityKit';
import { showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';

bootstrapStores();

@Entry
@Component
struct SettingsPage {
  @StorageLink(StoreKeys.UserIsLoggedIn) isLoggedIn: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
  }

  private logout(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.logout(hostContext);
    showToast('已退出登录', this.getUIContext());
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
  private buildSettingsContent(): void {
    Column({ space: 16 }) {
      Column({ space: 0 }) {
        this.buildMenuRow('隐私政策', $r('sys.symbol.person'), true, () => {
          pushRoute(PageRoutes.PrivacyPolicy);
        })
        this.buildMenuRow('用户协议', $r('sys.symbol.doc_plaintext'), false, () => {
          pushRoute(PageRoutes.UserAgreement);
        })
      }
      .width('100%')
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: '#F1F3F8' })
      .borderRadius(24)
      .clip(true)

      if (this.isLoggedIn) {
        Button('退出登录')
          .width('100%')
          .height(52)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.dangerSoft)
          .fontColor(AppTheme.colors.danger)
          .border({ width: 1, color: AppTheme.colors.danger })
          .onClick(() => {
            this.logout();
          })
      }

      Text(this.getFooterMessage())
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
        .textAlign(TextAlign.Center)
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

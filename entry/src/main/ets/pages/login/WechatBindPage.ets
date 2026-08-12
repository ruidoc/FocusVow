import { common } from '@kit.AbilityKit';
import { showToast } from '../../common/Toast';
import { AppActionButton } from '../../components/common/AppActionButton';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { backRoute, returnToMainTab } from '../../router/PageRoutes';
import { UserStore } from '../../stores/UserStore';

@Entry
@Component
struct WechatBindPage {
  @State loading: boolean = false;

  private async onBind(): Promise<void> {
    if (UserStore.getUserInfo().openid.length > 0) {
      returnToMainTab('focus');
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.loading = true;
    const errorMessage = await UserStore.bindWechat(hostContext);
    this.loading = false;
    if (errorMessage) {
      showToast(errorMessage, this.getUIContext());
      return;
    }
    if (!UserStore.isLoggedIn()) {
      return;
    }
    showToast('微信绑定成功', this.getUIContext());
    returnToMainTab('focus');
  }

  private onSkip(): void {
    returnToMainTab('focus');
  }

  @Builder
  private buildPageBody(): void {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text('绑定微信')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')
        Text('绑定后下次可一键微信登录，更方便')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 24 })

      Text('建议绑定微信。也可以之后在「个人中心 → 个人信息」里绑定。')
        .fontSize(13)
        .fontColor(AppTheme.colors.textPrimary)
        .lineHeight(20)
        .width('100%')
        .padding(14)
        .backgroundColor(AppTheme.colors.primarySoft)
        .borderRadius(14)

      AppActionButton({
        label: this.loading ? '绑定中...' : '绑定微信',
        isEnabled: !this.loading,
        onPress: () => {
          void this.onBind();
        }
      })

      Text('暂时跳过')
        .fontSize(15)
        .fontColor(AppTheme.colors.textMuted)
        .margin({ top: 8 })
        .opacity(this.loading ? 0.5 : 1)
        .onClick(() => {
          if (!this.loading) {
            this.onSkip();
          }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '绑定微信',
        showBack: true,
        onBack: () => {
          backRoute();
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

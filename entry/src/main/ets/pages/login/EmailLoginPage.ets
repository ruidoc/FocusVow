import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { showToast } from '../../common/Toast';
import { AgreementConsentRow } from '../../components/common/AgreementConsentRow';
import { AppActionButton } from '../../components/common/AppActionButton';
import { IconTextInputCard } from '../../components/common/IconTextInputCard';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { backRoute, PageRoutes, replaceRoute, returnToMainTab } from '../../router/PageRoutes';
import {
  fetchHasOnboardingProfile,
  markOnboardingCompleted
} from '../../services/OnboardingApiService';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { confirmPrivacyAgreementForAuth } from '../../utils/PrivacyConsentUtil';

const EMAIL_PATTERN: RegExp = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

@Entry
@Component
struct EmailLoginPage {
  @State email: string = '';
  @State password: string = '';
  @State loading: boolean = false;
  @State agreedToTerms: boolean = false;
  @State switchLinkPressed: boolean = false;
  @State bottomInset: number = 12;

  aboutToAppear(): void {
    AppStorage.setOrCreate(StoreKeys.MainTabFloatingBar, false);
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const ui = this.getUIContext();
    window.getLastWindow(hostContext, (err, win) => {
      if (err.code) {
        return;
      }
      const navAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.bottomInset = Math.max(ui.px2vp(navAvoid.bottomRect.height), 12);
    });
  }

  private isFormValid(): boolean {
    return EMAIL_PATTERN.test(this.email.trim()) && this.password.length >= 6;
  }

  private async afterLoginSuccess(hostContext: common.UIAbilityContext): Promise<void> {
    showToast('登录成功', this.getUIContext());
    const loginFrom = String(AppStorage.get<string>(StoreKeys.LoginFrom) ?? '');
    if (loginFrom === 'welcome_old_user') {
      const hasProfile = await fetchHasOnboardingProfile(hostContext);
      if (hasProfile) {
        markOnboardingCompleted(hostContext);
        AppStorage.setOrCreate(StoreKeys.LoginFrom, '');
        AppStorage.setOrCreate(StoreKeys.OnboardingViaOldUser, false);
        returnToMainTab('focus');
        return;
      }
      AppStorage.setOrCreate(StoreKeys.OnboardingViaOldUser, true);
      AppStorage.setOrCreate(StoreKeys.LoginFrom, '');
      replaceRoute(PageRoutes.Onboarding);
      return;
    }
    AppStorage.setOrCreate(StoreKeys.LoginFrom, '');
    returnToMainTab('focus');
  }

  private async submitLogin(): Promise<void> {
    if (!EMAIL_PATTERN.test(this.email.trim()) || this.password.length < 6) {
      showToast('请输入有效邮箱和至少 6 位密码', this.getUIContext());
      return;
    }
    if (!this.agreedToTerms) {
      const accepted = await confirmPrivacyAgreementForAuth(this.getUIContext());
      if (!accepted) {
        return;
      }
      this.agreedToTerms = true;
    }

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.loading = true;
    const errorMessage = await UserStore.loginWithEmail(
      hostContext,
      this.email,
      this.password
    );
    this.loading = false;

    if (errorMessage) {
      showToast(errorMessage, this.getUIContext());
      return;
    }

    await this.afterLoginSuccess(hostContext);
  }

  @Builder
  private buildLoginContent(): void {
    Column() {
      Column() {
        Column({ space: 8 }) {
          Text('邮箱登录')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')
          Text('使用邮箱和密码登录专注契约账号')
            .fontSize(16)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ top: 40, bottom: 40 })

        IconTextInputCard({
          icon: $r('sys.symbol.envelope'),
          placeholder: '邮箱',
          text: this.email,
          inputType: InputType.Email,
          onTextChange: (value: string) => {
            this.email = value;
          }
        })
          .width('100%')
          .margin({ bottom: 16 })

        IconTextInputCard({
          icon: $r('sys.symbol.lock'),
          placeholder: '密码（至少 6 位）',
          text: this.password,
          inputType: InputType.Password,
          onTextChange: (value: string) => {
            this.password = value;
          }
        })
          .width('100%')
          .margin({ bottom: 24 })

        AppActionButton({
          label: this.loading ? '登录中...' : '登录',
          isEnabled: this.isFormValid() && !this.loading,
          onPress: () => {
            void this.submitLogin();
          }
        })

        Text('还没有账号？去注册')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.primary)
          .opacity(this.switchLinkPressed ? 0.6 : 1)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 16, bottom: 16 })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.switchLinkPressed = true;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.switchLinkPressed = false;
            }
          })
          .onClick(() => {
            replaceRoute(PageRoutes.Register);
          })
      }
      .layoutWeight(1)
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      AgreementConsentRow({
        agreed: this.agreedToTerms,
        centered: true,
        onAgreedChange: (agreed: boolean) => {
          this.agreedToTerms = agreed;
        }
      })
        .padding({ bottom: this.bottomInset })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '',
        showBack: true,
        usePageScroll: false,
        horizontalPadding: 24,
        bottomSpacerHeight: 0,
        onBack: () => {
          backRoute();
        },
        content: (): void => {
          this.buildLoginContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

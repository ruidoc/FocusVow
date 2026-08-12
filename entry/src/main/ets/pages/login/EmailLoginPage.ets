import { common } from '@kit.AbilityKit';
import { showToast } from '../../common/Toast';
import { AgreementConsentRow } from '../../components/common/AgreementConsentRow';
import { AppActionButton } from '../../components/common/AppActionButton';
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
  private buildInputCard(): void {
    Column({ space: 14 }) {
      TextInput({ placeholder: '邮箱', text: this.email })
        .type(InputType.Email)
        .height(52)
        .fontSize(16)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .borderRadius(AppTheme.radius.md)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.email = value;
        })

      TextInput({ placeholder: '密码（至少 6 位）', text: this.password })
        .type(InputType.Password)
        .height(52)
        .fontSize(16)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .borderRadius(AppTheme.radius.md)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.password = value;
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildLoginContent(): void {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text('邮箱登录')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')

        Text('使用邮箱和密码登录 FocusVow 账号')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.buildInputCard()

      AppActionButton({
        label: this.loading ? '登录中...' : '登录',
        isEnabled: this.isFormValid() && !this.loading,
        onPress: () => {
          void this.submitLogin();
        }
      })

      AgreementConsentRow({
        agreed: this.agreedToTerms,
        onAgreedChange: (agreed: boolean) => {
          this.agreedToTerms = agreed;
        }
      })

      Text('还没有账号？去注册')
        .fontSize(15)
        .fontColor(AppTheme.colors.primary)
        .opacity(this.switchLinkPressed ? 0.7 : 1)
        .padding({ top: 8, bottom: 8 })
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
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '邮箱登录',
        showBack: true,
        usePageScroll: true,
        horizontalPadding: 16,
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

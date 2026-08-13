import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { showToast } from '../../common/Toast';
import { AgreementConsentRow } from '../../components/common/AgreementConsentRow';
import { AppActionButton } from '../../components/common/AppActionButton';
import { IconTextInputCard } from '../../components/common/IconTextInputCard';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { backRoute, PageRoutes, replaceRoute } from '../../router/PageRoutes';
import { ExtendApiService } from '../../services/ExtendApiService';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { confirmPrivacyAgreementForAuth } from '../../utils/PrivacyConsentUtil';
import { getPendingReferralCode } from '../../utils/ReferralUtil';

const EMAIL_PATTERN: RegExp = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const CODE_COUNTDOWN_SECONDS: number = 60;
const VERIFY_CODE_MIN_LENGTH: number = 4;

@Entry
@Component
struct RegisterPage {
  @State email: string = '';
  @State verifyCode: string = '';
  @State username: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State loading: boolean = false;
  @State sendingCode: boolean = false;
  @State codeCountdown: number = 0;
  @State agreedToTerms: boolean = false;
  @State switchLinkPressed: boolean = false;
  @State bottomInset: number = 12;

  private countdownTimerId: number = -1;

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

  aboutToDisappear(): void {
    this.clearCountdownTimer();
  }

  private clearCountdownTimer(): void {
    if (this.countdownTimerId !== -1) {
      clearInterval(this.countdownTimerId);
      this.countdownTimerId = -1;
    }
  }

  private startCodeCountdown(): void {
    this.clearCountdownTimer();
    this.codeCountdown = CODE_COUNTDOWN_SECONDS;
    this.countdownTimerId = setInterval(() => {
      if (this.codeCountdown <= 1) {
        this.codeCountdown = 0;
        this.clearCountdownTimer();
        return;
      }
      this.codeCountdown -= 1;
    }, 1000);
  }

  private canSendVerifyCode(): boolean {
    return EMAIL_PATTERN.test(this.email.trim()) && !this.sendingCode && this.codeCountdown === 0;
  }

  private getSendCodeLabel(): string {
    if (this.sendingCode) {
      return '发送中...';
    }
    if (this.codeCountdown > 0) {
      return `${this.codeCountdown}s`;
    }
    return '获取验证码';
  }

  private passwordsMatch(): boolean {
    return this.password.length > 0 && this.password === this.confirmPassword;
  }

  private isFormValid(): boolean {
    return (
      EMAIL_PATTERN.test(this.email.trim()) &&
      this.verifyCode.trim().length >= VERIFY_CODE_MIN_LENGTH &&
      this.username.trim().length > 0 &&
      this.password.length >= 6 &&
      this.passwordsMatch()
    );
  }

  private async sendVerifyCode(): Promise<void> {
    if (!EMAIL_PATTERN.test(this.email.trim())) {
      showToast('请输入有效邮箱', this.getUIContext());
      return;
    }
    if (!this.canSendVerifyCode()) {
      return;
    }

    this.sendingCode = true;
    const response = await ExtendApiService.sendEmailCode(this.email.trim());
    this.sendingCode = false;

    if (response.statusCode !== 200) {
      showToast(response.message ?? '验证码发送失败', this.getUIContext());
      return;
    }

    showToast('验证码已发送', this.getUIContext());
    this.startCodeCountdown();
  }

  private async submitRegister(): Promise<void> {
    if (!EMAIL_PATTERN.test(this.email.trim())) {
      showToast('请输入有效邮箱', this.getUIContext());
      return;
    }
    if (this.verifyCode.trim().length < VERIFY_CODE_MIN_LENGTH) {
      showToast(`请输入邮箱验证码（至少 ${VERIFY_CODE_MIN_LENGTH} 位）`, this.getUIContext());
      return;
    }
    if (this.username.trim().length === 0) {
      showToast('请输入用户名', this.getUIContext());
      return;
    }
    if (this.password.length < 6) {
      showToast('密码至少 6 位', this.getUIContext());
      return;
    }
    if (!this.passwordsMatch()) {
      showToast('两次密码输入不一致', this.getUIContext());
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
    const errorMessage = await UserStore.registerWithEmail(
      hostContext,
      this.email,
      this.username,
      this.password,
      this.verifyCode,
      getPendingReferralCode(hostContext)
    );
    this.loading = false;

    if (errorMessage) {
      showToast(errorMessage, this.getUIContext());
      return;
    }

    showToast('注册成功', this.getUIContext());
    replaceRoute(PageRoutes.WechatBind);
  }

  @Builder
  private buildRegisterForm(): void {
    Column() {
      Column({ space: 8 }) {
        Text('创建账号')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')
        Text('注册后可同步账号数据，需先验证邮箱')
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

      Row({ space: 12 }) {
        IconTextInputCard({
          icon: $r('sys.symbol.key'),
          placeholder: '邮箱验证码',
          text: this.verifyCode,
          inputType: InputType.Number,
          maxLength: 6,
          onTextChange: (value: string) => {
            this.verifyCode = value;
          }
        })
          .layoutWeight(1)

        Button(this.getSendCodeLabel())
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .height(52)
          .constraintSize({ minWidth: 108 })
          .padding({ left: 16, right: 16 })
          .borderRadius(16)
          .clip(true)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.canSendVerifyCode() ? AppTheme.colors.primary : AppTheme.colors.textMuted)
          .backgroundColor(AppTheme.colors.primarySoft)
          .enabled(this.canSendVerifyCode())
          .opacity(this.canSendVerifyCode() ? 1 : 0.7)
          .onClick(() => {
            void this.sendVerifyCode();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 16 })

      IconTextInputCard({
        icon: $r('sys.symbol.person'),
        placeholder: '用户名',
        text: this.username,
        onTextChange: (value: string) => {
          this.username = value;
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
        .margin({ bottom: 16 })

      IconTextInputCard({
        icon: $r('sys.symbol.lock'),
        placeholder: '确认密码',
        text: this.confirmPassword,
        inputType: InputType.Password,
        onTextChange: (value: string) => {
          this.confirmPassword = value;
        }
      })
        .width('100%')
        .margin({ bottom: this.confirmPassword.length > 0 && this.password.length > 0 && !this.passwordsMatch() ? 8 : 24 })

      if (this.confirmPassword.length > 0 && this.password.length > 0 && !this.passwordsMatch()) {
        Text('两次密码输入不一致')
          .fontSize(14)
          .fontColor(AppTheme.colors.danger)
          .width('100%')
          .margin({ bottom: 12 })
      }

      AppActionButton({
        label: this.loading ? '注册中...' : '注册并登录',
        isEnabled: this.isFormValid() && !this.loading,
        onPress: () => {
          void this.submitRegister();
        }
      })

      Text('已有账号？去登录')
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
          replaceRoute(PageRoutes.Login);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildRegisterContent(): void {
    Column() {
      Scroll() {
        this.buildRegisterForm()
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

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
          this.buildRegisterContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

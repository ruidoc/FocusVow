import { common } from "@kit.AbilityKit";
import { AgreementConsentRow } from "../../components/common/AgreementConsentRow";
import { AppActionButton } from "../../components/common/AppActionButton";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { showToast } from "../../common/Toast";
import { AppTheme } from "../../constants/Theme";
import { backRoute, PageRoutes, replaceRoute, returnToMainTab } from "../../router/PageRoutes";
import { ExtendApiService } from "../../services/ExtendApiService";
import { UserStore } from "../../stores/UserStore";

const EMAIL_PATTERN: RegExp = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const CODE_COUNTDOWN_SECONDS: number = 60;

@Entry
@Component
struct RegisterPage {
  @State email: string = "";
  @State verifyCode: string = "";
  @State username: string = "";
  @State password: string = "";
  @State confirmPassword: string = "";
  @State loading: boolean = false;
  @State sendingCode: boolean = false;
  @State codeCountdown: number = 0;
  @State agreedToTerms: boolean = false;
  @State switchLinkPressed: boolean = false;

  private countdownTimerId: number = -1;

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
      return "发送中...";
    }
    if (this.codeCountdown > 0) {
      return `${this.codeCountdown}s`;
    }
    return "获取验证码";
  }

  private isFormValid(): boolean {
    return (
      EMAIL_PATTERN.test(this.email.trim()) &&
      this.verifyCode.trim().length >= 6 &&
      this.username.trim().length > 0 &&
      this.password.length >= 6 &&
      this.password === this.confirmPassword &&
      this.agreedToTerms
    );
  }

  private async sendVerifyCode(): Promise<void> {
    if (!EMAIL_PATTERN.test(this.email.trim())) {
      showToast("请输入有效邮箱", this.getUIContext());
      return;
    }
    if (!this.canSendVerifyCode()) {
      return;
    }

    this.sendingCode = true;
    const response = await ExtendApiService.sendEmailCode(this.email.trim());
    this.sendingCode = false;

    if (response.statusCode !== 200) {
      showToast(response.message ?? "验证码发送失败", this.getUIContext());
      return;
    }

    showToast("验证码已发送", this.getUIContext());
    this.startCodeCountdown();
  }

  private async submitRegister(): Promise<void> {
    if (!this.agreedToTerms) {
      showToast("请先阅读并同意《隐私政策》和《用户协议》", this.getUIContext());
      return;
    }
    if (!EMAIL_PATTERN.test(this.email.trim())) {
      showToast("请输入有效邮箱", this.getUIContext());
      return;
    }
    if (this.verifyCode.trim().length < 6) {
      showToast("请输入 6 位邮箱验证码", this.getUIContext());
      return;
    }
    if (this.username.trim().length === 0) {
      showToast("请输入用户名", this.getUIContext());
      return;
    }
    if (this.password.length < 6) {
      showToast("密码至少 6 位", this.getUIContext());
      return;
    }
    if (this.password !== this.confirmPassword) {
      showToast("两次密码输入不一致", this.getUIContext());
      return;
    }

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.loading = true;
    const errorMessage = await UserStore.registerWithEmail(
      hostContext,
      this.email,
      this.username,
      this.password,
      this.verifyCode,
    );
    this.loading = false;

    if (errorMessage) {
      showToast(errorMessage, this.getUIContext());
      return;
    }

    showToast("注册成功", this.getUIContext());
    returnToMainTab("focus");
  }

  @Builder
  private buildInputCard(): void {
    Column({ space: 14 }) {
      TextInput({ placeholder: "邮箱", text: this.email })
        .type(InputType.Email)
        .height(52)
        .fontSize(16)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .borderRadius(AppTheme.radius.md)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.email = value;
        })
      Row({ space: 12 }) {
        TextInput({ placeholder: "邮箱验证码", text: this.verifyCode })
          .type(InputType.Number)
          .height(52)
          .fontSize(16)
          .layoutWeight(1)
          .maxLength(6)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .borderRadius(AppTheme.radius.md)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.verifyCode = value;
          })
        Button(this.getSendCodeLabel())
          .type(ButtonType.Capsule)
          .height(52)
          .fontSize(14)
          .fontColor(this.canSendVerifyCode() ? AppTheme.colors.primary : AppTheme.colors.textMuted)
          .backgroundColor(AppTheme.colors.primarySoft)
          .padding({ left: 14, right: 14 })
          .enabled(this.canSendVerifyCode())
          .opacity(this.canSendVerifyCode() ? 1 : 0.7)
          .onClick(() => {
            void this.sendVerifyCode();
          })
      }
      .width("100%")
      .alignItems(VerticalAlign.Center)
      TextInput({ placeholder: "用户名", text: this.username })
        .height(52)
        .fontSize(16)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .borderRadius(AppTheme.radius.md)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.username = value;
        })
      TextInput({ placeholder: "密码（至少 6 位）", text: this.password })
        .type(InputType.Password)
        .height(52)
        .fontSize(16)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .borderRadius(AppTheme.radius.md)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.password = value;
        })
      TextInput({ placeholder: "确认密码", text: this.confirmPassword })
        .type(InputType.Password)
        .height(52)
        .fontSize(16)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .borderRadius(AppTheme.radius.md)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.confirmPassword = value;
        })
    }
    .width("100%")
    .padding(18)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildRegisterContent(): void {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text("创建账号")
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width("100%")
        Text("注册后可同步账号数据，需先验证邮箱")
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%")
      }
      .width("100%")
      .alignItems(HorizontalAlign.Start)

      this.buildInputCard()
      AppActionButton({
        label: this.loading ? "注册中..." : "注册并登录",
        isEnabled: this.isFormValid() && !this.loading,
        onPress: () => {
          void this.submitRegister();
        },
      })
      AgreementConsentRow({
        agreed: this.agreedToTerms,
        onAgreedChange: (agreed: boolean) => {
          this.agreedToTerms = agreed;
        },
      })
      Text("已有账号？去登录")
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
          replaceRoute(PageRoutes.Login);
        })
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Stack() {
      SystemNavPage({
        title: "注册",
        showBack: true,
        usePageScroll: true,
        horizontalPadding: 16,
        onBack: () => {
          backRoute();
        },
        content: (): void => {
          this.buildRegisterContent();
        },
      })
    }
    .width("100%")
    .height("100%");
  }
}

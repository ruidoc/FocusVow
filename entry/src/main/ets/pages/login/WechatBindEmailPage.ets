import { common } from '@kit.AbilityKit';
import { showToast } from '../../common/Toast';
import { AppActionButton } from '../../components/common/AppActionButton';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { createEmptyWxPendingInfo, WxPendingInfo } from '../../models/UserModel';
import { backRoute, PageRoutes, pushRoute, returnToMainTab } from '../../router/PageRoutes';
import { ExtendApiService } from '../../services/ExtendApiService';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

const EMAIL_PATTERN: RegExp = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const CODE_COUNTDOWN_SECONDS: number = 60;

@Entry
@Component
struct WechatBindEmailPage {
  @StorageLink(StoreKeys.WxPendingInfo) wxPending: WxPendingInfo = createEmptyWxPendingInfo();
  @State email: string = '';
  @State verifyCode: string = '';
  @State loading: boolean = false;
  @State skipping: boolean = false;
  @State sendingCode: boolean = false;
  @State codeCountdown: number = 0;
  private countdownTimer: number = -1;

  aboutToAppear(): void {
    if (this.isFromProfile()) {
      if (!UserStore.isLoggedIn()) {
        pushRoute(PageRoutes.Login);
      }
      return;
    }
    if (this.wxPending.openid.length === 0) {
      pushRoute(PageRoutes.Login);
    }
  }

  aboutToDisappear(): void {
    this.clearCountdown();
    if (this.isFromProfile()) {
      AppStorage.setOrCreate(StoreKeys.LoginFrom, '');
    }
  }

  private clearCountdown(): void {
    if (this.countdownTimer >= 0) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = -1;
    }
  }

  private startCodeCountdown(): void {
    this.clearCountdown();
    this.codeCountdown = CODE_COUNTDOWN_SECONDS;
    this.countdownTimer = setInterval(() => {
      if (this.codeCountdown <= 1) {
        this.clearCountdown();
        this.codeCountdown = 0;
        return;
      }
      this.codeCountdown -= 1;
    }, 1000);
  }

  private isFromProfile(): boolean {
    return String(AppStorage.get<string>(StoreKeys.LoginFrom) ?? '') === 'profile';
  }

  private canSendVerifyCode(): boolean {
    return EMAIL_PATTERN.test(this.email.trim()) && !this.sendingCode && this.codeCountdown === 0;
  }

  private isFormValid(): boolean {
    return EMAIL_PATTERN.test(this.email.trim()) && this.verifyCode.trim().length >= 4;
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

  private async onBind(): Promise<void> {
    if (!this.isFormValid()) {
      showToast('请输入有效邮箱和验证码', this.getUIContext());
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.loading = true;
    const errorMessage = this.isFromProfile()
      ? await UserStore.bindEmailByCode(hostContext, this.email, this.verifyCode)
      : await UserStore.wechatBindByEmail(hostContext, this.email, this.verifyCode);
    this.loading = false;
    if (errorMessage) {
      showToast(errorMessage, this.getUIContext());
      return;
    }
    if (this.isFromProfile()) {
      AppStorage.setOrCreate(StoreKeys.LoginFrom, '');
      showToast('邮箱绑定成功', this.getUIContext());
      backRoute();
      return;
    }
    showToast('登录成功', this.getUIContext());
    returnToMainTab('focus');
  }

  private async onSkip(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.skipping = true;
    const errorMessage = await UserStore.wechatCreateSkipEmail(hostContext);
    this.skipping = false;
    if (errorMessage) {
      showToast(errorMessage, this.getUIContext());
      return;
    }
    showToast('登录成功', this.getUIContext());
    returnToMainTab('focus');
  }

  @Builder
  private buildPageBody(): void {
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        Text('绑定邮箱')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')
        Text('绑定后可用邮箱登录，也能找回账号')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 12, bottom: 4 })

      Text('若你以前用邮箱注册过，请务必在此绑定，否则会生成新账号，看不到以前的专注数据')
        .fontSize(13)
        .fontColor(AppTheme.colors.danger)
        .lineHeight(18)
        .width('100%')
        .padding(14)
        .backgroundColor(AppTheme.colors.dangerSoft)
        .borderRadius(14)

      TextInput({ placeholder: '邮箱', text: this.email })
        .type(InputType.Email)
        .height(52)
        .fontSize(16)
        .backgroundColor(AppTheme.colors.surface)
        .borderRadius(14)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.email = value;
        })

      Row({ space: 10 }) {
        TextInput({ placeholder: '验证码', text: this.verifyCode })
          .type(InputType.Number)
          .layoutWeight(1)
          .height(52)
          .fontSize(16)
          .backgroundColor(AppTheme.colors.surface)
          .borderRadius(14)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.verifyCode = value;
          })

        Button(this.codeCountdown > 0 ? `${this.codeCountdown}s` : (this.sendingCode ? '发送中' : '获取验证码'))
          .height(52)
          .padding({ left: 14, right: 14 })
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .fontSize(13)
          .fontColor(AppTheme.colors.primary)
          .backgroundColor(AppTheme.colors.primarySoft)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .enabled(this.canSendVerifyCode())
          .onClick(() => {
            void this.sendVerifyCode();
          })
      }
      .width('100%')

      AppActionButton({
        label: this.loading ? '绑定中...' : '确认绑定',
        isEnabled: this.isFormValid() && !this.loading && !this.skipping,
        onPress: () => {
          void this.onBind();
        }
      })

      if (!this.isFromProfile()) {
        Text(this.skipping ? '创建中...' : '暂时跳过')
          .fontSize(15)
          .fontColor(AppTheme.colors.textMuted)
          .margin({ top: 8 })
          .opacity(this.skipping || this.loading ? 0.5 : 1)
          .onClick(() => {
            if (!this.skipping && !this.loading) {
              void this.onSkip();
            }
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '完善账号',
        showBack: true,
        onBack: () => {
          if (this.isFromProfile()) {
            AppStorage.setOrCreate(StoreKeys.LoginFrom, '');
            backRoute();
            return;
          }
          UserStore.setWxPendingInfo(null);
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

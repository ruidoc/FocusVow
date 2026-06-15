import { common } from '@kit.AbilityKit';
import { AppActionButton } from '../../components/common/AppActionButton';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { showToast } from '../../common/Toast';
import { AppTheme } from '../../constants/Theme';
import { backRoute, PageRoutes, pushRoute, replaceRoute } from '../../router/PageRoutes';
import { UserStore } from '../../stores/UserStore';

const EMAIL_PATTERN: RegExp = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

@Entry
@Component
struct RegisterPage {
  @State email: string = '';
  @State username: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State loading: boolean = false;

  private isFormValid(): boolean {
    return EMAIL_PATTERN.test(this.email.trim()) &&
      this.username.trim().length > 0 &&
      this.password.length >= 6 &&
      this.password === this.confirmPassword;
  }

  private async submitRegister(): Promise<void> {
    if (!EMAIL_PATTERN.test(this.email.trim())) {
      showToast('请输入有效邮箱', this.getUIContext());
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
    if (this.password !== this.confirmPassword) {
      showToast('两次密码输入不一致', this.getUIContext());
      return;
    }

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.loading = true;
    const errorMessage = await UserStore.registerWithEmail(
      hostContext,
      this.email,
      this.username,
      this.password
    );
    this.loading = false;

    if (errorMessage) {
      showToast(errorMessage, this.getUIContext());
      return;
    }

    showToast('注册成功', this.getUIContext());
    replaceRoute(PageRoutes.FocusHome);
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

      TextInput({ placeholder: '用户名', text: this.username })
        .height(52)
        .fontSize(16)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .borderRadius(AppTheme.radius.md)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.username = value;
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

      TextInput({ placeholder: '确认密码', text: this.confirmPassword })
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
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildRegisterContent(): void {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text('创建账号')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')

        Text('注册后可同步账号数据（当前为邮箱注册）')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.buildInputCard()

      AppActionButton({
        label: this.loading ? '注册中...' : '注册并登录',
        isEnabled: this.isFormValid() && !this.loading,
        onPress: () => {
          void this.submitRegister();
        }
      })

      Button('已有账号？去登录')
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .fontColor(AppTheme.colors.primary)
        .fontSize(15)
        .onClick(() => {
          pushRoute(PageRoutes.Login);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '注册',
        showBack: true,
        usePageScroll: true,
        horizontalPadding: 16,
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

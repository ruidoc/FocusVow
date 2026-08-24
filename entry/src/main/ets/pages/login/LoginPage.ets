import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { showToast } from '../../common/Toast';
import { AgreementConsentRow } from '../../components/common/AgreementConsentRow';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import {
  routeAfterWelcomeOldUserLogin
} from '../../services/OnboardingApiService';
import { backRoute, PageRoutes, pushRoute, replaceRoute, returnToMainTab } from '../../router/PageRoutes';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { confirmPrivacyAgreementForAuth } from '../../utils/PrivacyConsentUtil';
import { SIGNUP_TRIAL_EXISTING_USER_TOAST } from '../../utils/SignupTrialUtil';
import {
  clearPendingSignupTrialCelebration,
  tryPresentSignupTrialCelebration,
} from '../../utils/SignupTrialCelebrationUtil';

const WECHAT_GREEN: string = '#07C160';
const HUAWEI_RED: string = '#CF0A2C';

@Entry
@Component
struct LoginPage {
  @State loading: boolean = false;
  @State agreedToTerms: boolean = false;
  @State loginFrom: string = '';
  @State bottomInset: number = 12;

  aboutToAppear(): void {
    this.loginFrom = String(AppStorage.get<string>(StoreKeys.LoginFrom) ?? '');
    // 登录页不需要首页悬浮 Tab 的底部留白，否则协议离底太远
    AppStorage.setOrCreate(StoreKeys.MainTabFloatingBar, false);

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const ui = this.getUIContext();
    window.getLastWindow(hostContext, (err, win) => {
      if (err.code) {
        return;
      }
      const navAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      // 对齐 RN getPrivacyBottomPadding：max(bottomInset, 12)
      this.bottomInset = Math.max(ui.px2vp(navAvoid.bottomRect.height), 12);
    });
  }

  private async ensurePrivacy(): Promise<boolean> {
    if (!this.agreedToTerms) {
      const accepted = await confirmPrivacyAgreementForAuth(this.getUIContext());
      if (!accepted) {
        return false;
      }
      this.agreedToTerms = true;
    }
    return true;
  }

  private async afterLoginSuccess(hostContext: common.UIAbilityContext): Promise<void> {
    if (this.loginFrom === 'guest_membership_reclaim') {
      if (!UserStore.lastLoginIsNew) {
        clearPendingSignupTrialCelebration(hostContext);
        showToast(SIGNUP_TRIAL_EXISTING_USER_TOAST, this.getUIContext(), 3000);
      } else {
        showToast('登录成功', this.getUIContext());
      }
      AppStorage.setOrCreate(StoreKeys.LoginFrom, '');
      returnToMainTab('focus');
      if (UserStore.lastLoginIsNew) {
        void tryPresentSignupTrialCelebration(hostContext);
      }
      return;
    }
    showToast('登录成功', this.getUIContext());
    if (this.loginFrom === 'welcome_old_user') {
      const goHome = await routeAfterWelcomeOldUserLogin(
        hostContext,
        UserStore.lastLoginUserId
      );
      if (goHome) {
        returnToMainTab('focus');
      } else {
        replaceRoute(PageRoutes.Onboarding);
      }
      return;
    }
    AppStorage.setOrCreate(StoreKeys.LoginFrom, '');
    returnToMainTab('focus');
  }

  private async onWechatLogin(): Promise<void> {
    if (!(await this.ensurePrivacy())) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.loading = true;
    const result = await UserStore.loginWithWechat(hostContext);
    this.loading = false;

    if (result === UserStore.WECHAT_NEED_BIND) {
      pushRoute(PageRoutes.WechatBindEmail);
      return;
    }
    if (result) {
      showToast(result, this.getUIContext());
      return;
    }
    if (!UserStore.isLoggedIn()) {
      return;
    }
    await this.afterLoginSuccess(hostContext);
  }

  private async onHuaweiLogin(): Promise<void> {
    if (!(await this.ensurePrivacy())) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.loading = true;
    const result = await UserStore.loginWithHuawei(hostContext);
    this.loading = false;
    if (result) {
      showToast(result, this.getUIContext());
      return;
    }
    if (!UserStore.isLoggedIn()) {
      return;
    }
    await this.afterLoginSuccess(hostContext);
  }

  @Builder
  private buildLoginContent(): void {
    // 对齐 RN：标题+按钮成组垂直居中；协议贴底
    Column() {
      Column({ space: 0 }) {
        Column({ space: 10 }) {
          Image($r('app.media.startIcon'))
            .width(72)
            .height(72)
            .borderRadius(18)
            .margin({ bottom: 8 })

          Text('登录专注契约')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)

          Text('华为账号、微信或邮箱登录')
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 32 })

        Column() {
          Button() {
            Row({ space: 8 }) {
              Image($r('app.media.huawei'))
                .width(22)
                .height(22)
                .objectFit(ImageFit.Contain)
              Text(this.loading ? '请稍候...' : '华为账号登录')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
          }
          .width('100%')
          .height(52)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .backgroundColor(HUAWEI_RED)
          .borderRadius(AppTheme.radius.button)
          .enabled(!this.loading)
          .opacity(this.loading ? 0.7 : 1)
          .onClick(() => {
            void this.onHuaweiLogin();
          })
        }
        .width('100%')
        .margin({ top: 8, bottom: 4 })
        .borderRadius(AppTheme.radius.button)
        .clip(true)

        Column() {
          Button() {
            Row({ space: 8 }) {
              Image($r('app.media.wechat'))
                .width(22)
                .height(22)
                .objectFit(ImageFit.Contain)
              Text('微信登录/注册')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
          }
          .width('100%')
          .height(52)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .backgroundColor(WECHAT_GREEN)
          .borderRadius(AppTheme.radius.button)
          .enabled(!this.loading)
          .opacity(this.loading ? 0.7 : 1)
          .onClick(() => {
            void this.onWechatLogin();
          })
        }
        .width('100%')
        .margin({ top: 8, bottom: 4 })
        .borderRadius(AppTheme.radius.button)
        .clip(true)

        Column() {
          Button() {
            Row({ space: 8 }) {
              Image($r('app.media.mail'))
                .width(20)
                .height(20)
                .objectFit(ImageFit.Contain)
              Text(this.loading ? '请稍候...' : '邮箱登录')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.colors.textPrimary)
            }
          }
          .width('100%')
          .height(52)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .backgroundColor(AppTheme.colors.surface)
          .border({ width: 0, color: Color.Transparent })
          .borderRadius(AppTheme.radius.button)
          .enabled(!this.loading)
          .onClick(() => {
            pushRoute(PageRoutes.EmailLogin);
          })
        }
        .width('100%')
        .margin({ top: 8 })
        .borderRadius(AppTheme.radius.button)
        .clip(true)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 24, right: 24, bottom: 24 })
      .offset({ y: -20 })

      AgreementConsentRow({
        agreed: this.agreedToTerms,
        centered: true,
        onAgreedChange: (agreed: boolean) => {
          this.agreedToTerms = agreed;
        }
      })
        .padding({ left: 40, right: 40, bottom: this.bottomInset })
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
        horizontalPadding: 0,
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

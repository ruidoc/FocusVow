import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../../constants/Theme';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { OnboardingApiService } from '../../services/OnboardingApiService';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct WelcomePage {
  @State bottomInset: number = 0;
  @State topInset: number = 0;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const ui = this.getUIContext();
    window.getLastWindow(hostContext, (err, win) => {
      if (err.code) {
        return;
      }
      const systemAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.topInset = ui.px2vp(systemAvoid.topRect.height);
      this.bottomInset = ui.px2vp(navAvoid.bottomRect.height);
    });
  }

  private onStart(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    AppStorage.setOrCreate(StoreKeys.OnboardingViaOldUser, false);
    void OnboardingApiService.upsert(hostContext, {
      'current_step': 'welcome'
    });
    pushRoute(PageRoutes.Onboarding);
  }

  private onOldUser(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    AppStorage.setOrCreate(StoreKeys.OnboardingViaOldUser, true);
    AppStorage.setOrCreate(StoreKeys.LoginFrom, 'welcome_old_user');
    void OnboardingApiService.upsert(hostContext, {
      'current_step': 'welcome',
      'via_old_user': true
    });
    pushRoute(PageRoutes.Login);
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        Image($r('app.media.startIcon'))
          .width(72)
          .height(72)
          .borderRadius(18)
          .margin({ bottom: 28 })

        Text('专注，不必独自硬扛')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
          .width('100%')

        Text('和搭子一起锁机，轻松又高效')
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .lineHeight(24)
          .textAlign(TextAlign.Center)
          .padding({ left: 16, right: 16 })
          .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 24, right: 24 })

      Column({ space: 12 }) {
        Button('开始')
          .width('100%')
          .height(52)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(AppTheme.colors.primary)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .onClick(() => {
            this.onStart();
          })

        Text('我是老用户')
          .fontSize(15)
          .fontColor(AppTheme.colors.textMuted)
          .padding({ top: 10, bottom: 10 })
          .onClick(() => {
            this.onOldUser();
          })
      }
      .width('100%')
      .padding({
        left: 32,
        right: 32,
        bottom: Math.max(this.bottomInset, 16) + 24
      })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topInset })
    .backgroundColor(AppTheme.colors.background)
  }
}

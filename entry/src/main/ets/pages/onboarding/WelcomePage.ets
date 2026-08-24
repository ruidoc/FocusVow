import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppTheme } from '../../constants/Theme';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { OnboardingApiService } from '../../services/OnboardingApiService';
import { patchOnboardingMeta } from '../../utils/OnboardingMetaUtil';
import { AnalyticsService } from '../../services/AnalyticsService';
import { FeatureFlagStore } from '../../stores/FeatureFlagStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

const WELCOME_POINTS: string[] = [
  '专注时会锁住短视频、游戏',
  '搭子互立契约，违约有惩罚',
  '支持在线匹配搭子',
];

@Entry
@Component
struct WelcomePage {
  @State bottomInset: number = 0;
  @State topInset: number = 0;

  aboutToAppear(): void {
    AnalyticsService.trackEvent('welcome_viewed');
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    FeatureFlagStore.hydrate(hostContext);
    void FeatureFlagStore.sync(hostContext);
    void OnboardingApiService.reportWelcomeView(hostContext);
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
    patchOnboardingMeta({ entry_source: 'new_explore' });
    AnalyticsService.trackEvent('welcome_cta_clicked', { 'cta': 'start', 'entry_source': 'new_explore' });
    AppStorage.setOrCreate(StoreKeys.OnboardingViaOldUser, false);
    void OnboardingApiService.upsert(hostContext, {
      'current_step': 'welcome'
    });
    pushRoute(PageRoutes.Onboarding);
  }

  private onOldUser(): void {
    patchOnboardingMeta({ entry_source: 'welcome_old_user' });
    AnalyticsService.trackEvent('welcome_cta_clicked', { 'cta': 'old_user', 'entry_source': 'welcome_old_user' });
    AppStorage.setOrCreate(StoreKeys.OnboardingViaOldUser, true);
    AppStorage.setOrCreate(StoreKeys.LoginFrom, 'welcome_old_user');
    pushRoute(PageRoutes.Login);
  }

  build() {
    Column() {
      Column() {
        Image($r('app.media.startIcon'))
          .width(80)
          .height(80)
          .borderRadius(18)
          .margin({ bottom: 40 })

        Text('搭子结伴，一起上岸')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
          .margin({ bottom: 32 })

        Column({ space: 12 }) {
          ForEach(WELCOME_POINTS, (text: string, index: number) => {
            Row() {
              Text(`${index + 1}`)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.colors.primary)
                .width(22)
                .height(22)
                .textAlign(TextAlign.Center)
                .borderRadius(11)
                .backgroundColor('rgba(122, 90, 248, 0.09)')
                .margin({ right: 12 })
              Text(text)
                .fontSize(15)
                .fontColor(AppTheme.colors.textSecondary)
                .lineHeight(24)
                .textAlign(TextAlign.Start)
            }
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Start)
          }, (text: string) => text)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .alignItems(HorizontalAlign.Center)
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 24, right: 24 })

      Column({ space: 12 }) {
        Button('新用户探索')
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

        Text('老用户登录')
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

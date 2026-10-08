import { common } from '@kit.AbilityKit';
import { AppTheme } from '../../constants/Theme';
import { homeGlassCardBg, homeGlassPrimaryIconBg } from '../../constants/HomeCardStyle';
import { HomeGlassSurface } from './HomeGlassSurface';
import { DuoSessionView } from '../../models/DuoModel';
import { AnalyticsService } from '../../services/AnalyticsService';
import { hydrateScheduledGuardSyncFlags } from '../../services/ScheduledCovenantService';
import { openScheduledTaskTabOnce, pushLogin } from '../../router/PageRoutes';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';

@Component
export struct HomeScheduledSyncBanner {
  @StorageLink(StoreKeys.UserIsLoggedIn) isLoggedIn: boolean = false;
  @StorageLink(StoreKeys.NeedsScheduledGuardSync) needsScheduledGuardSync: boolean = false;
  @StorageLink(StoreKeys.ScheduledListAll) scheduledSessions: DuoSessionView[] = [];

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    hydrateScheduledGuardSyncFlags(hostContext);
  }

  private shouldShow(): boolean {
    return this.isLoggedIn && this.needsScheduledGuardSync && this.scheduledSessions.length > 0;
  }

  private onPress(): void {
    if (!UserStore.isLoggedIn()) {
      pushLogin();
      return;
    }
    const props: Record<string, Object> = {};
    props['entry_key'] = 'scheduled_sync';
    AnalyticsService.trackEvent('home_entry_clicked', props);
    openScheduledTaskTabOnce();
  }

  @Builder
  private buildBannerContent(): void {
    Row({ space: 12 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(18)
          .fontColor([AppTheme.colors.primary])
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .borderRadius(18)
      .backgroundColor(homeGlassPrimaryIconBg())

      Column({ space: 2 }) {
        Text('同步定时任务')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(1)
        Text('同步后定时任务方可生效')
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([AppTheme.colors.textMuted])
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }

  build() {
    if (!this.shouldShow()) {
      Column()
    } else {
      Column() {
        HomeGlassSurface({
          glassBackgroundColor: homeGlassCardBg(),
          fitContent: true,
          content: (): void => {
            this.buildBannerContent();
          },
        })
      }
      .width('100%')
      .margin({ top: 16 })
      .borderRadius(28)
      .clip(true)
      .onClick(() => {
        this.onPress();
      })
    }
  }
}

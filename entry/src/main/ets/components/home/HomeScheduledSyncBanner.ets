import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { AppTheme } from '../../constants/Theme';
import { homeGlassCardBg, homeGlassPrimaryIconBg } from '../../constants/HomeCardStyle';
import { HomeGlassSurface } from './HomeGlassSurface';
import { DuoSessionView } from '../../models/DuoModel';
import { AnalyticsService } from '../../services/AnalyticsService';
import { hydrateScheduledGuardSyncFlags, syncScheduledGuardsManually } from '../../services/ScheduledCovenantService';
import { ensureScreenTimeAuthorization } from '../../services/ScreenTimeService';
import { pushLogin } from '../../router/PageRoutes';
import { SettingsStore } from '../../stores/SettingsStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';

@Component
export struct HomeScheduledSyncBanner {
  @Prop embedInNoticeHub: boolean = false;
  @StorageLink(StoreKeys.UserIsLoggedIn) isLoggedIn: boolean = false;
  @StorageLink(StoreKeys.NeedsScheduledGuardSync) needsScheduledGuardSync: boolean = false;
  @StorageLink(StoreKeys.ScheduledListAll) scheduledSessions: DuoSessionView[] = [];
  @State private syncing: boolean = false;

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
    void this.syncNow();
  }

  private async syncNow(): Promise<void> {
    if (this.syncing) {
      return;
    }
    const props: Record<string, Object> = {};
    props['entry_key'] = 'scheduled_sync';
    AnalyticsService.trackEvent('home_entry_clicked', props);
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.syncing = true;
    try {
      const authResult = await ensureScreenTimeAuthorization(hostContext);
      SettingsStore.updateAuthorization(hostContext, authResult.ok, authResult.message);
      if (!authResult.ok) {
        return;
      }
      const result = await syncScheduledGuardsManually(hostContext);
      if (result.ok) {
        showToast('已同步到本机', this.getUIContext());
      } else if (result.message.length > 0) {
        showErrorToast(result.message, this.getUIContext());
      }
    } finally {
      this.syncing = false;
    }
  }

  @Builder
  private buildBannerContent(): void {
    Row({ space: 12 }) {
      Row() {
        if (this.syncing) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(AppTheme.colors.primary)
        } else {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(18)
            .fontColor([AppTheme.colors.primary])
        }
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .borderRadius(18)
      .backgroundColor(homeGlassPrimaryIconBg())

      Column({ space: 2 }) {
        Text(this.syncing ? '同步中...' : '同步定时任务')
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
      .margin({ top: this.embedInNoticeHub ? 0 : 16 })
      .borderRadius(28)
      .clip(true)
      .onClick(() => {
        if (!this.syncing) {
          this.onPress();
        }
      })
    }
  }
}

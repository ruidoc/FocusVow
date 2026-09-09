import { UsersIcon } from '../common/UsersIcon';
import { AppTheme } from '../../constants/Theme';
import { homeGlassCardBg, homeGlassPrimaryIconBg } from '../../constants/HomeCardStyle';
import { HomeGlassSurface } from './HomeGlassSurface';
import { openDuoWaitPage } from '../../services/DuoWaitContextService';
import { UserStore } from '../../stores/UserStore';
import { pushLogin } from '../../router/PageRoutes';
import { StoreKeys } from '../../stores/StoreKeys';

@Component
export struct HomeDuoWaitBanner {
  @StorageLink(StoreKeys.DuoWaitSessionId) duoWaitSessionId: string = '';
  @StorageLink(StoreKeys.DuoWaitTitle) duoWaitTitle: string = '';
  @StorageLink(StoreKeys.DuoWaitIsScheduled) duoWaitIsScheduled: boolean = false;
  @StorageLink(StoreKeys.DuoWaitScheduleLabel) duoWaitScheduleLabel: string = '';

  private shouldShow(): boolean {
    return this.duoWaitSessionId.length > 0 && !this.duoWaitIsScheduled;
  }

  private getDetail(): string {
    const title = this.duoWaitTitle.length > 0 ? this.duoWaitTitle : '搭子互督';
    return `${title} · 点击进入发给搭子`;
  }

  private onPress(): void {
    if (!UserStore.isLoggedIn()) {
      pushLogin();
      return;
    }
    openDuoWaitPage();
  }

  @Builder
  private buildBannerContent(): void {
    Row({ space: 12 }) {
      Row() {
        UsersIcon({ iconSize: 18, color: AppTheme.colors.primary })
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .borderRadius(18)
      .backgroundColor(homeGlassPrimaryIconBg())

      Column({ space: 2 }) {
        Text('等待搭子加入')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(1)
        Text(this.getDetail())
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
          .maxLines(1)
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

import { AppTheme } from '../../constants/Theme';
import { MainTabKey } from '../../router/PageRoutes';
import { StoreKeys } from '../../stores/StoreKeys';
import { ContractTabPage } from './ContractTabPage';
import { FocusHomePage } from './FocusHomePage';
import { getMainTabIcons } from './MainTabUtil';
import { ProfilePage } from './ProfilePage';
import { StatsPage } from './StatsPage';

@Component
export struct MainTabLegacyLayout {
  @Prop currentTab: MainTabKey = 'focus';
  @Prop bottomGestureInsetVp: number = 0;
  @Prop hideTabBar: boolean = false;
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';
  onTabChange?: (tab: MainTabKey) => void;

  @Builder
  private buildTabSymbol(tab: MainTabKey): void {
    SymbolGlyph(this.getTabSymbol(tab))
      .fontSize(21)
      .fontColor([this.currentTab === tab ? AppTheme.colors.primary : AppTheme.colors.textSecondary])
      .fontWeight(this.currentTab === tab ? 500 : 400)
  }

  private getTabSymbol(tab: MainTabKey): Resource {
    const icons = getMainTabIcons(tab);
    return this.currentTab === tab ? icons.selected : icons.normal;
  }

  @Builder
  private buildTabItem(tab: MainTabKey, title: string): void {
    Column({ space: 6 }) {
      this.buildTabSymbol(tab)

      Text(title)
        .fontSize(12)
        .fontWeight(this.currentTab === tab ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentTab === tab ? AppTheme.colors.primary : AppTheme.colors.textSecondary)
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 2 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onTabChange?.(tab);
    })
  }

  build() {
    Column() {
      Stack() {
        FocusHomePage()
          .width('100%')
          .height('100%')
          .visibility(this.currentTab === 'focus' ? Visibility.Visible : Visibility.Hidden)

        ContractTabPage({ isPageActive: this.currentTab === 'plans' })
          .width('100%')
          .height('100%')
          .visibility(this.currentTab === 'plans' ? Visibility.Visible : Visibility.Hidden)

        StatsPage()
          .width('100%')
          .height('100%')
          .visibility(this.currentTab === 'stats' ? Visibility.Visible : Visibility.Hidden)

        ProfilePage()
          .width('100%')
          .height('100%')
          .visibility(this.currentTab === 'profile' ? Visibility.Visible : Visibility.Hidden)
      }
      .width('100%')
      .layoutWeight(1)

      Row() {
        this.buildTabItem('focus', '专注')
        this.buildTabItem('plans', '任务')
        this.buildTabItem('stats', '统计')
        this.buildTabItem('profile', '我的')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 + this.bottomGestureInsetVp })
      .backgroundColor(AppTheme.colors.backgroundSoft)
      .border({ width: 1, color: AppTheme.colors.border })
      .visibility(this.hideTabBar ? Visibility.None : Visibility.Visible)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.colors.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

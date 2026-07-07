import { SymbolGlyphModifier } from "@kit.ArkUI";
import { HdsTabs, HdsTabsController, HdsTabsFloatingStyle } from "@kit.UIDesignKit";
import { AppTheme } from "../../constants/Theme";
import { MainTabKey } from "../../router/PageRoutes";
import { StoreKeys } from "../../stores/StoreKeys";
import { ContractTabPage } from "./ContractTabPage";
import { FocusHomePage } from "./FocusHomePage";
import { createImmersiveTabFloatingStyle } from "./ImmersiveMaterialUtil";
import { getMainTabIcons, indexToMainTab, mainTabToIndex } from "./MainTabUtil";
import { ProfilePage } from "./ProfilePage";
import { StatsPage } from "./StatsPage";
@Component
export struct MainTabImmersiveLayout {
  @Prop @Watch("onLinkedTabChanged") currentTab: MainTabKey = "focus";
  @Prop bottomGestureInsetVp: number = 0;
  @Prop @Watch("onHideTabBarChanged") hideTabBar: boolean = false;
  onTabChange?: (tab: MainTabKey) => void;
  @State private selectedTabIndex: number = 0;
  @State private barFloatingStyle: HdsTabsFloatingStyle = createImmersiveTabFloatingStyle(28);
  private tabsController: HdsTabsController = new HdsTabsController();

  aboutToAppear(): void {
    this.syncFloatingTabBarFlag();
    this.selectedTabIndex = mainTabToIndex(this.currentTab);
    this.refreshBarFloatingStyle();
  }

  aboutToDisappear(): void {
    AppStorage.set(StoreKeys.MainTabFloatingBar, false);
  }

  private syncFloatingTabBarFlag(): void {
    AppStorage.set(StoreKeys.MainTabFloatingBar, !this.hideTabBar);
  }

  private onHideTabBarChanged(): void {
    this.syncFloatingTabBarFlag();
  }

  private refreshBarFloatingStyle(): void {
    const bottomMargin = Math.max(28, 12 + this.bottomGestureInsetVp);
    this.barFloatingStyle = createImmersiveTabFloatingStyle(bottomMargin);
  }

  private onLinkedTabChanged(): void {
    const nextIndex = mainTabToIndex(this.currentTab);
    if (this.selectedTabIndex === nextIndex) {
      return;
    }
    this.selectedTabIndex = nextIndex;
    this.tabsController.changeIndex(nextIndex);
  }

  private buildSymbolTabBar(tab: MainTabKey, label: string): BottomTabBarStyle {
    const icons = getMainTabIcons(tab);
    const tabBarIcon: TabBarSymbol = {
      normal: new SymbolGlyphModifier(icons.normal)
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .fontSize(21)
        .fontColor([AppTheme.colors.textSecondary])
        .fontWeight(FontWeight.Regular),
      selected: new SymbolGlyphModifier(icons.selected)
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .fontSize(21)
        .fontColor([AppTheme.colors.primary])
        .fontWeight(FontWeight.Medium),
    };
    return new BottomTabBarStyle(tabBarIcon, label)
      .labelStyle({
        selectedColor: AppTheme.colors.primary,
        unselectedColor: AppTheme.colors.textSecondary,
        font: { size: 12 },
      })
      .padding({ left: 10, right: 10 })
      .symmetricExtensible(true);
  }

  build() {
    HdsTabs({ controller: this.tabsController, index: this.selectedTabIndex }) {
      TabContent() {
        FocusHomePage({
          onSelectTab: (tab: "plans") => {
            this.onTabChange?.(tab);
          },
        })
          .width("100%")
          .height("100%")
      }.tabBar(this.buildSymbolTabBar("focus", "专注"))
      TabContent() {
        ContractTabPage({ isPageActive: this.currentTab === "plans" })
          .width("100%")
          .height("100%")
      }.tabBar(this.buildSymbolTabBar("plans", "定时"))
      TabContent() {
        StatsPage()
          .width("100%")
          .height("100%")
      }.tabBar(this.buildSymbolTabBar("stats", "统计"))
      TabContent() {
        ProfilePage()
          .width("100%")
          .height("100%")
      }.tabBar(this.buildSymbolTabBar("profile", "我的"))
    }
    .barOverlap(true)
    .vertical(false)
    .barPosition(BarPosition.End)
    .scrollable(false)
    .barWidth(this.hideTabBar ? 0 : -1)
    .barHeight(this.hideTabBar ? 0 : -1)
    .animationDuration(0)
    .barFloatingStyle(this.barFloatingStyle)
    .onChange((index: number) => {
      this.selectedTabIndex = index;
      const nextTab = indexToMainTab(index);
      if (this.currentTab !== nextTab) {
        this.onTabChange?.(nextTab);
      }
    })
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }
}

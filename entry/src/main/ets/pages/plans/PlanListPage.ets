import { showToast } from "../../common/Toast";
import { PlanListContent } from "../../components/plans/PlanListContent";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { PageRoutes, backRoute, pushRoute } from "../../router/PageRoutes";
import { LockStore } from "../../stores/LockStore";
import { ScheduledListStore } from "../../stores/ScheduledListStore";
import { StoreKeys } from "../../stores/StoreKeys";
import { UserStore } from "../../stores/UserStore";
import { bootstrapStores } from "../../stores/StoreBootstrap";

bootstrapStores();

@Entry
@Component
struct PlanListPage {
  private listScroller: Scroller = new Scroller();
  @State private scrollerReady: boolean = false;

  private openCreate(): void {
    if (!UserStore.isLoggedIn()) {
      showToast("请先登录", this.getUIContext());
      pushRoute(PageRoutes.Login);
      return;
    }
    if (LockStore.isLocked()) {
      showToast("专注进行中，不可以创建契约", this.getUIContext());
      return;
    }
    ScheduledListStore.hydrate();
    AppStorage.setOrCreate(StoreKeys.ScheduledSessionCurrentId, "");
    ScheduledListStore.clearEditingSession();
    pushRoute(PageRoutes.PlanAdd);
  }

  @Builder
  private buildList(): void {
    PlanListContent({
      isPageActive: true,
      onCreatePlan: () => {
        this.openCreate();
      },
      onScrollerReady: (scroller: Scroller) => {
        this.listScroller = scroller;
        this.scrollerReady = true;
      },
    });
  }

  build() {
    Stack() {
      SystemNavPage({
        title: "定时任务",
        showBack: true,
        showAction: true,
        actionLabel: "新建",
        usePageScroll: false,
        horizontalPadding: 0,
        useFloatingTabInset: false,
        bottomSpacerHeight: 26,
        onBack: () => backRoute(),
        onAction: () => {
          this.openCreate();
        },
        bindScrollers: this.scrollerReady ? [this.listScroller] : [],
        content: (): void => {
          this.buildList();
        },
      })
    }
    .width("100%")
    .height("100%");
  }
}

import { common } from '@kit.AbilityKit';
import { PageHeader } from '../../components/common/PageHeader';
import { HomeNavButton } from '../../components/home/HomeNavButton';
import { FocusPlan } from '../../models/PlanModel';
import { FocusRunStatus, FocusSession, createIdleFocusSession } from '../../models/FocusSession';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { releaseScreenRestriction } from '../../services/ScreenTimeService';
import { FocusStore } from '../../stores/FocusStore';
import { PlanStore } from '../../stores/PlanStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Entry
@Component
struct FocusHomePage {
  @StorageLink(StoreKeys.FocusCurrentSession) currentSession: FocusSession = createIdleFocusSession();
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.SettingsStatusMessage) statusMessage: string = '先申请系统授权，再选择需要限制的应用';
  @State remainingLabel: string = FocusStore.getRemainingLabel();

  private timerId: number = -1;
  private isStopping: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    FocusStore.hydrate(hostContext);
    this.syncRemainingLabel();
    this.startTimer();
  }

  aboutToDisappear(): void {
    this.clearTimer();
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private startTimer(): void {
    this.clearTimer();
    this.timerId = setInterval(() => {
      this.syncRemainingLabel();
    }, 1000);
  }

  private syncRemainingLabel(): void {
    this.remainingLabel = FocusStore.getRemainingLabel();
    if (FocusStore.shouldAutoFinish()) {
      this.finishCurrentFocus(true);
    }
  }

  private async finishCurrentFocus(isAutoFinished: boolean): Promise<void> {
    if (this.currentSession.status !== FocusRunStatus.Running || this.isStopping) {
      return;
    }

    this.isStopping = true;
    this.clearTimer();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await releaseScreenRestriction(this.currentSession.selectedTokens, this.currentSession.mode);

    FocusStore.finishSession(hostContext);
    SettingsStore.updateStatusMessage(
      hostContext,
      result.ok
        ? (isAutoFinished ? '专注已完成，限制已自动解除' : '你已手动结束专注')
        : (isAutoFinished ? `专注已结束，但解除限制失败：${result.message}` : `结束专注失败：${result.message}`)
    );

    this.remainingLabel = FocusStore.getRemainingLabel();
    this.isStopping = false;
    this.startTimer();
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        PageHeader({
          title: '专注契约',
          subtitle: '本地版主链路：首页、快速专注、计划、设置已经拆开'
        })

        Column({ space: 10 }) {
          Text(this.currentSession.status === FocusRunStatus.Running ? this.remainingLabel : '准备开始')
            .fontSize(this.currentSession.status === FocusRunStatus.Running ? 44 : 24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')

          Text(this.currentSession.status === FocusRunStatus.Running
            ? `${this.currentSession.planName.length > 0 ? this.currentSession.planName : '快速专注'} 进行中`
            : '先完成授权和应用选择，再开始你的第一段专注')
            .fontSize(14)
            .fontColor(this.currentSession.status === FocusRunStatus.Running ? '#2563EB' : '#6B7280')
            .width('100%')

          if (this.currentSession.status === FocusRunStatus.Running) {
            Button('结束当前专注')
              .width('100%')
              .height(48)
              .type(ButtonType.Capsule)
              .backgroundColor('#EF4444')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.finishCurrentFocus(false);
              })
          }
        }
        .width('100%')
        .padding(22)
        .backgroundColor('#F3F7FF')
        .borderRadius(28)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 8 }) {
          Text('当前本地状态')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')

          Text(`授权状态：${this.hasAuthorized ? '已授权' : '未授权'}`)
            .fontSize(14)
            .fontColor('#374151')
          Text(`已选应用：${this.selectedAppCount} 个`)
            .fontSize(14)
            .fontColor('#374151')
          Text(`本地计划：${this.planCollection.length} 条`)
            .fontSize(14)
            .fontColor('#374151')
          Text(this.statusMessage)
            .fontSize(13)
            .fontColor('#6B7280')
            .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(24)
        .alignItems(HorizontalAlign.Start)

        HomeNavButton({
          title: '快速专注',
          description: '即时授权、选应用、开始本次专注',
          onPress: () => pushRoute(PageRoutes.QuickStart)
        })

        HomeNavButton({
          title: '计划列表',
          description: '查看和维护本地契约计划',
          onPress: () => pushRoute(PageRoutes.PlanList)
        })

        HomeNavButton({
          title: '设置与权限',
          description: '系统授权、应用选择、清空本地状态',
          onPress: () => pushRoute(PageRoutes.Settings)
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28, bottom: 28 })
      .backgroundColor('#F7F8FA')
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}

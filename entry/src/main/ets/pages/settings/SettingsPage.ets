import { common } from '@kit.AbilityKit';
import { PageHeader } from '../../components/common/PageHeader';
import { SettingsActionRow } from '../../components/settings/SettingsActionRow';
import { AppTheme } from '../../constants/Theme';
import { FocusPlan } from '../../models/PlanModel';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { FocusStore } from '../../stores/FocusStore';
import { PlanStore } from '../../stores/PlanStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Entry
@Component
struct SettingsPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @State statusMessage: string = '这里先保留权限入口和本地数据管理';

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    this.statusMessage = SettingsStore.getState().statusMessage;
  }

  private clearLocalData(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    PlanStore.reset(hostContext);
    FocusStore.setDurationMinutes(hostContext, 25);
    FocusStore.resetToIdle(hostContext);
    SettingsStore.reset(hostContext);
    this.statusMessage = '本地数据已清空';
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        PageHeader({
          title: '设置',
          subtitle: '本地版先放权限入口和清空状态能力',
          showBack: true,
          onBack: () => backRoute()
        })

        SettingsActionRow({
          title: '系统权限与应用选择',
          value: this.hasAuthorized ? `已授权 · ${this.selectedAppCount} 个应用` : '未授权',
          onPress: () => pushRoute(PageRoutes.Permission)
        })

        SettingsActionRow({
          title: '本地计划数量',
          value: `${this.planCollection.length} 条`,
          onPress: () => pushRoute(PageRoutes.PlanList)
        })

        Button('清空本地数据')
          .width('100%')
          .height(52)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.dangerSoft)
          .fontColor(AppTheme.colors.danger)
          .border({ width: 1, color: AppTheme.colors.danger })
          .onClick(() => {
            this.clearLocalData();
          })

        Text(this.statusMessage)
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28, bottom: 28 })
      .backgroundColor(AppTheme.colors.background)
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}

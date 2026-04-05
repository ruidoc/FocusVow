import { common } from '@kit.AbilityKit';
import { PageHeader } from '../../components/common/PageHeader';
import { AppTheme } from '../../constants/Theme';
import { backRoute } from '../../router/PageRoutes';
import {
  chooseRestrictedApps,
  requestScreenTimeAuthorization
} from '../../services/ScreenTimeService';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Entry
@Component
struct PermissionPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedTokens) selectedTokens: string[] = [];
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.SettingsStatusMessage) statusMessage: string = '先申请系统授权，再选择需要限制的应用';

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
  }

  private async authorize(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await requestScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, result.ok, result.message);
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    if (result.data) {
      SettingsStore.updateSelectedTokens(hostContext, result.data, result.message);
    } else {
      SettingsStore.updateStatusMessage(hostContext, result.message);
    }
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        PageHeader({
          title: '权限管理',
          subtitle: '这里单独承接系统授权和应用选择，和首页/快速专注共用一份状态',
          showBack: true,
          onBack: () => backRoute()
        })

        Column({ space: 10 }) {
          Text(`系统授权：${this.hasAuthorized ? '已完成' : '未完成'}`)
            .fontSize(15)
            .fontColor(AppTheme.colors.textPrimary)
          Text(`已选择应用：${this.selectedAppCount} 个`)
            .fontSize(15)
            .fontColor(AppTheme.colors.textPrimary)
          Text(this.statusMessage)
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor(AppTheme.colors.surface)
        .border({ width: 1, color: AppTheme.colors.border })
        .borderRadius(24)
        .alignItems(HorizontalAlign.Start)

        Button(this.hasAuthorized ? '重新申请系统授权' : '申请系统授权')
          .width('100%')
          .height(48)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .fontColor(AppTheme.colors.textPrimary)
          .border({ width: 1, color: AppTheme.colors.border })
          .onClick(() => {
            this.authorize();
          })

        Button('选择需要限制的应用')
          .width('100%')
          .height(48)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.surface)
          .fontColor(AppTheme.colors.textPrimary)
          .border({ width: 1, color: AppTheme.colors.border })
          .onClick(() => {
            this.chooseApps();
          })
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

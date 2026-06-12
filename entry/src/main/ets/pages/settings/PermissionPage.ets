import { common } from '@kit.AbilityKit';
import { AppTheme } from '../../constants/Theme';
import { SystemNavPage } from '../../components/common/SystemNavPage';
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

  @Builder
  private buildPermissionContent(): void {
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        Text('权限用途说明')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')

        Text('系统授权仅用于你主动开启的专注、契约和娱乐限额能力。只有你选择的应用会被纳入限制范围，你也可以随时重新选择或关闭。')
          .fontSize(13)
          .lineHeight(22)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
      .width('100%')
      .padding(18)
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(AppTheme.radius.lg)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 10 }) {
        Text(`系统授权：${this.hasAuthorized ? '已完成' : '未完成'}`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
        Text(`已选择应用：${this.selectedAppCount} 个`)
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)
        Text(this.statusMessage)
          .fontSize(13)
          .lineHeight(20)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
      .width('100%')
      .padding(18)
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(AppTheme.radius.lg)
      .alignItems(HorizontalAlign.Start)

      Button(this.hasAuthorized ? '重新申请系统授权' : '申请系统授权')
        .width('100%')
        .height(50)
        .type(ButtonType.Capsule)
        .backgroundColor(AppTheme.colors.primarySoft)
        .fontColor(AppTheme.colors.primary)
        .border({ width: 1, color: AppTheme.colors.primarySoft })
        .onClick(() => {
          this.authorize();
        })

      Button('选择需要限制的应用')
        .width('100%')
        .height(50)
        .type(ButtonType.Capsule)
        .backgroundColor(AppTheme.colors.surface)
        .fontColor(AppTheme.colors.textPrimary)
        .border({ width: 1, color: AppTheme.colors.border })
        .onClick(() => {
          this.chooseApps();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '权限与应用管理',
        showBack: true,
        horizontalPadding: 20,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildPermissionContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

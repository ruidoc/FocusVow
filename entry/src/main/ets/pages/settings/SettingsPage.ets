import { common } from '@kit.AbilityKit';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { SettingsActionRow } from '../../components/settings/SettingsActionRow';
import { AppTheme } from '../../constants/Theme';
import { FocusPlan } from '../../models/PlanModel';
import { PageRoutes, backRoute, pushRoute } from '../../router/PageRoutes';
import { LockStore } from '../../stores/LockStore';
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
  @State statusMessage: string = '这里集中放置权限说明、合规信息和本地数据管理';

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    this.statusMessage = SettingsStore.getState().statusMessage;
  }

  private clearLocalData(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    PlanStore.reset(hostContext);
    LockStore.setQuickFocusDurationMinutes(hostContext, 25);
    LockStore.clear(hostContext);
    SettingsStore.reset(hostContext);
    this.statusMessage = '本地数据已清空';
  }

  @Builder
  private buildSettingsContent(): void {
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        Text('上架准备')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')

        Text('这里统一提供权限用途说明、隐私政策与协议入口，便于用户了解专注限制的作用范围和数据处理方式。')
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

      SettingsActionRow({
        title: '权限与应用管理',
        value: this.hasAuthorized ? `已授权 · ${this.selectedAppCount} 个应用` : '未授权',
        description: '申请系统授权，选择专注模式下需要限制的应用',
        symbol: $r('sys.symbol.bolt_shield'),
        onPress: () => pushRoute(PageRoutes.Permission)
      })

      SettingsActionRow({
        title: '隐私政策',
        value: '',
        description: '查看本地数据、权限用途与后续登录能力的说明',
        symbol: $r('sys.symbol.person'),
        onPress: () => pushRoute(PageRoutes.PrivacyPolicy)
      })

      SettingsActionRow({
        title: '用户协议',
        value: '',
        description: '了解产品定位、使用边界和责任说明',
        symbol: $r('sys.symbol.doc_plaintext'),
        onPress: () => pushRoute(PageRoutes.UserAgreement)
      })

      SettingsActionRow({
        title: '关于我们',
        value: '',
        description: '查看产品介绍、当前能力与本地存储说明',
        symbol: $r('sys.symbol.square_grid_2x2'),
        onPress: () => pushRoute(PageRoutes.About)
      })

      SettingsActionRow({
        title: '契约记录',
        value: `${this.planCollection.length} 条`,
        description: '快速进入契约列表，统一查看和编辑计划',
        symbol: $r('sys.symbol.doc_plaintext'),
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
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '设置',
        showBack: true,
        horizontalPadding: 20,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildSettingsContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

import { SettingsActionRow } from '../../components/settings/SettingsActionRow';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { common } from '@kit.AbilityKit';
import { FocusPlan } from '../../models/PlanModel';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { CycleGuardStore } from '../../stores/CycleGuardStore';
import { PlanStore } from '../../stores/PlanStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { SettingsStore } from '../../stores/SettingsStore';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Component
export struct ProfilePage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @StorageLink(StoreKeys.CycleGuardSelectedAppCount) cycleSelectedAppCount: number = 0;
  @StorageLink(StoreKeys.CycleGuardQuotaMinutes) cycleQuotaMinutes: number = 60;
  @StorageLink(StoreKeys.CycleGuardEnabled) cycleEnabled: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    CycleGuardStore.hydrate(hostContext);
  }

  private getUserSubtitle(): string {
    return '登录功能后续接入，当前先管理你的专注与娱乐限额配置';
  }

  @Builder
  private buildSummaryMetric(label: string, value: string): void {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(11)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')

      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildProfileContent(): void {
    Column({ space: 16 }) {
      Column({ space: 16 }) {
        Row({ space: 14 }) {
          Row() {
            Text('FV')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .width(56)
          .height(56)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppTheme.colors.primary)
          .borderRadius(20)

          Column({ space: 4 }) {
            Text('用户中心')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.colors.textPrimary)
              .width('100%')

            Text(this.getUserSubtitle())
              .fontSize(13)
              .fontColor(AppTheme.colors.textSecondary)
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 18 }) {
          this.buildSummaryMetric('系统授权', this.hasAuthorized ? '已开启' : '未开启')
          this.buildSummaryMetric('契约数量', `${this.planCollection.length} 条`)
          this.buildSummaryMetric('娱乐限额', this.cycleEnabled ? '运行中' : '未启动')
        }
        .width('100%')
      }
      .width('100%')
      .padding(20)
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: AppTheme.colors.border })
      .alignItems(HorizontalAlign.Start)

      Column({ space: 12 }) {
        Text('常用入口')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')

        SettingsActionRow({
          title: '权限与应用',
          value: this.hasAuthorized ? `已授权 · ${this.selectedAppCount} 个应用` : '未授权',
          description: '管理系统授权与专注模式的应用选择',
          symbol: $r('sys.symbol.bolt_shield'),
          onPress: () => pushRoute(PageRoutes.Permission)
        })

        SettingsActionRow({
          title: '契约管理',
          value: `${this.planCollection.length} 条`,
          description: '查看和编辑每日自动生效的专注契约',
          symbol: $r('sys.symbol.doc_plaintext'),
          onPress: () => pushRoute(PageRoutes.PlanList)
        })

        SettingsActionRow({
          title: '娱乐限额',
          value: this.cycleEnabled ? `${this.cycleQuotaMinutes} 分钟` : '未启动',
          description: this.cycleSelectedAppCount > 0
            ? `已配置 ${this.cycleSelectedAppCount} 个娱乐应用`
            : '为娱乐类应用设置总可用时长',
          symbol: $r('sys.symbol.bolt'),
          onPress: () => pushRoute(PageRoutes.CycleGuardEdit)
        })

        SettingsActionRow({
          title: '快速专注',
          value: '立即开始',
          description: '临时进入一段专注时间，不依赖固定计划',
          symbol: $r('sys.symbol.timer'),
          onPress: () => pushRoute(PageRoutes.QuickStart)
        })
      }
      .width('100%')

      Column({ space: 12 }) {
        Text('账户与设置')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')

        SettingsActionRow({
          title: '设置',
          value: '',
          description: '权限说明、隐私政策、用户协议与本地数据管理',
          symbol: $r('sys.symbol.person'),
          onPress: () => pushRoute(PageRoutes.Settings)
        })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    SystemNavPage({
      title: '用户中心',
      horizontalPadding: 20,
      content: (): void => {
        this.buildProfileContent();
      }
    })
  }
}

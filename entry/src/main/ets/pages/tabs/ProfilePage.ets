import { SettingsActionRow } from '../../components/settings/SettingsActionRow';
import { AppTheme } from '../../constants/Theme';
import { FocusPlan } from '../../models/PlanModel';
import { PageRoutes, pushRoute } from '../../router/PageRoutes';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Component
export struct ProfilePage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row({ space: 14 }) {
          Text('FV')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .width(54)
            .height(54)
            .textAlign(TextAlign.Center)
            .backgroundColor(AppTheme.colors.primary)
            .borderRadius(20)
            .padding({ top: 14 })

          Column({ space: 4 }) {
            Text('FocusVow')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.colors.textPrimary)
              .width('100%')

            Text('先把我的页壳子还原，再继续填充会员和账户能力。')
              .fontSize(13)
              .fontColor(AppTheme.colors.textSecondary)
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column({ space: 10 }) {
          Text('会员与权益')
            .fontSize(12)
            .fontColor(AppTheme.colors.textMuted)

          Text('主链路视觉先按深色权益卡还原，功能后续继续补。')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')

          Row({ space: 18 }) {
            Column({ space: 4 }) {
              Text('授权')
                .fontSize(11)
                .fontColor(AppTheme.colors.textMuted)
              Text(this.hasAuthorized ? '已开启' : '未开启')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.hasAuthorized ? AppTheme.colors.primary : AppTheme.colors.textPrimary)
            }
            .alignItems(HorizontalAlign.Start)

            Column({ space: 4 }) {
              Text('限制应用')
                .fontSize(11)
                .fontColor(AppTheme.colors.textMuted)
              Text(`${this.selectedAppCount} 个`)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.colors.textPrimary)
            }
            .alignItems(HorizontalAlign.Start)

            Column({ space: 4 }) {
              Text('契约计划')
                .fontSize(11)
                .fontColor(AppTheme.colors.textMuted)
              Text(`${this.planCollection.length} 条`)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.colors.textPrimary)
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .borderRadius(AppTheme.radius.lg)
        .border({ width: 1, color: AppTheme.colors.border })
        .alignItems(HorizontalAlign.Start)

        Column({ space: 12 }) {
          SettingsActionRow({
            title: '系统权限与应用选择',
            value: this.hasAuthorized ? `已授权 · ${this.selectedAppCount} 个应用` : '未授权',
            onPress: () => pushRoute(PageRoutes.Settings)
          })

          SettingsActionRow({
            title: '契约计划',
            value: `${this.planCollection.length} 条`,
            onPress: () => pushRoute(PageRoutes.PlanList)
          })

          SettingsActionRow({
            title: '快速专注',
            value: '立即开始',
            onPress: () => pushRoute(PageRoutes.QuickStart)
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 22, bottom: 28 })
      .backgroundColor(AppTheme.colors.background)
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}

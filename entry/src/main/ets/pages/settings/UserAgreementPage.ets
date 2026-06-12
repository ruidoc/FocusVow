import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { backRoute } from '../../router/PageRoutes';

@Builder
function AgreementSection(title: string, body: string): void {
  Column({ space: 8 }) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppTheme.colors.textPrimary)
      .width('100%')

    Text(body)
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
}

@Entry
@Component
struct UserAgreementPage {
  @Builder
  private buildContent(): void {
    Column({ space: 14 }) {
      AgreementSection(
        '服务定位',
        '专注契约用于帮助你主动管理娱乐和分心应用的使用节奏，不提供对他人设备进行隐蔽控制或远程监管的能力。'
      )
      AgreementSection(
        '使用责任',
        '所有限制规则都应由用户本人主动创建、修改或关闭。请在了解规则后再开启专注、契约或娱乐限额，避免影响正常沟通和工作场景。'
      )
      AgreementSection(
        '后续能力',
        '后续接入登录功能后，如涉及账号、云同步或跨设备服务，我们会同步更新协议内容并再次向你展示。'
      )
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '用户协议',
        showBack: true,
        horizontalPadding: 20,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

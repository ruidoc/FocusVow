import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { backRoute } from '../../router/PageRoutes';

@Builder
function PrivacySection(title: string, body: string): void {
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
struct PrivacyPolicyPage {
  @Builder
  private buildContent(): void {
    Column({ space: 14 }) {
      PrivacySection(
        '信息范围',
        '专注契约当前默认将授权状态、契约配置、限额配置和受限应用选择结果保存在本机，用于完成专注限制和提醒功能。'
      )
      PrivacySection(
        '使用目的',
        '申请系统授权仅用于用户主动发起的专注、契约和娱乐限额能力，不会在未告知的情况下替你新增或修改限制规则。'
      )
      PrivacySection(
        '数据控制',
        '你可以在设置页重新选择应用、关闭相关模式或清空本地数据。后续若接入登录与同步能力，我们会单独补充云端存储和账号说明。'
      )
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '隐私政策',
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

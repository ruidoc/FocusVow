import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { backRoute } from '../../router/PageRoutes';

@Builder
function AboutSection(title: string, body: string): void {
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
struct AboutPage {
  @Builder
  private buildHeaderCard(): void {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Row() {
          Text('FV')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.primary)
        .borderRadius(16)

        Column({ space: 4 }) {
          Text('专注契约')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')

          Text('专注、契约与娱乐限额的自我管理工具')
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildContent(): void {
    Column({ space: 14 }) {
      this.buildHeaderCard()
      AboutSection(
        '当前能力',
        '你可以创建定时契约、开始快速专注，并为娱乐类应用设置总可用时长，用完后统一锁定。'
      )
      AboutSection(
        '数据存储',
        '当前版本以本地存储为主，后续接入登录后再逐步开放账号与同步能力。'
      )
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '关于我们',
        showBack: true,
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

import { AppTheme } from '../../constants/Theme';

@Component
export struct HomeNavButton {
  @Prop title: string = '';
  @Prop description: string = '';
  onPress?: () => void;

  build() {
    Button() {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)

          Text(this.description)
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('进入')
          .fontSize(13)
          .fontColor(AppTheme.colors.primary)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height(72)
    .type(ButtonType.Capsule)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .padding({ left: 18, right: 18 })
    .onClick(() => {
      this.onPress?.();
    })
  }
}

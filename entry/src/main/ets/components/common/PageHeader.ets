import { AppTheme } from '../../constants/Theme';

@Component
export struct PageHeader {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop showBack: boolean = false;
  onBack?: () => void;

  build() {
    Column({ space: 8 }) {
      Row() {
        if (this.showBack) {
          Button('返回')
            .type(ButtonType.Capsule)
            .height(32)
            .fontSize(13)
            .backgroundColor(AppTheme.colors.surfaceRaised)
            .fontColor(AppTheme.colors.textPrimary)
            .border({ width: 1, color: AppTheme.colors.border })
            .onClick(() => {
              this.onBack?.();
            })
        }

        Blank()
      }
      .width('100%')

      Text(this.title)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

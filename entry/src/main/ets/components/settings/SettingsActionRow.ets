import { AppTheme } from '../../constants/Theme';

@Component
export struct SettingsActionRow {
  @Prop title: string = '';
  @Prop value: string = '';
  onPress?: () => void;

  build() {
    Button() {
      Row() {
        Text(this.title)
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)
        Blank()
        Text(this.value)
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
      }
      .width('100%')
    }
    .width('100%')
    .height(52)
    .type(ButtonType.Capsule)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(18)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.onPress?.();
    })
  }
}

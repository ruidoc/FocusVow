import { AppTheme } from '../../constants/Theme';

export type AppActionButtonVariant = 'primary' | 'danger';

@Component
export struct AppActionButton {
  @Prop label: string = '';
  @Prop variant: AppActionButtonVariant = 'primary';
  @Prop isEnabled: boolean = true;
  @Prop buttonHeight: number = 52;
  onPress?: () => void;

  private getBackgroundColor(): string {
    return this.variant === 'danger' ? AppTheme.colors.dangerSoft : AppTheme.colors.primary;
  }

  private getFontColor(): string {
    return this.variant === 'danger' ? AppTheme.colors.danger : '#FFFFFF';
  }

  private getBorderColor(): string {
    return this.getBackgroundColor();
  }

  build() {
    // Capsule 会忽略自定义 borderRadius；须 Normal + 显式圆角才对齐 RN rounded-[30px]
    Button(this.label)
      .width('100%')
      .height(this.buttonHeight)
      .type(ButtonType.Normal)
      .borderRadius(AppTheme.radius.button)
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .backgroundColor(this.getBackgroundColor())
      .fontColor(this.getFontColor())
      .border({ width: 0, color: this.getBorderColor() })
      .enabled(this.isEnabled)
      .opacity(this.isEnabled ? 1 : 0.7)
      .onClick(() => {
        this.onPress?.();
      })
  }
}

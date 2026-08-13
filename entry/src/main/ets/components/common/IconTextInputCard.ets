import { AppTheme } from '../../constants/Theme';

/** 对齐 RN 登录/注册：白底圆角卡片 + 左侧图标 */
@Component
export struct IconTextInputCard {
  @Prop icon: Resource = $r('sys.symbol.envelope');
  @Prop placeholder: string = '';
  @Prop text: string = '';
  @Prop inputType: InputType = InputType.Normal;
  @Prop maxLength: number = 256;
  onTextChange?: (value: string) => void;

  build() {
    Row({ space: 12 }) {
      SymbolGlyph(this.icon)
        .fontSize(18)
        .fontColor([AppTheme.colors.textMuted])
      TextInput({ placeholder: this.placeholder, text: this.text })
        .type(this.inputType)
        .layoutWeight(1)
        .height(48)
        .fontSize(16)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .maxLength(this.maxLength)
        .onChange((value: string) => {
          this.onTextChange?.(value);
        })
    }
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
  }
}

import { AppTheme } from '../../constants/Theme';

@Component
export struct InputConfirmSheet {
  @Link visible: boolean;
  @Prop title: string = '';
  @Prop message: string = '';
  @Prop requiredText: string = '';
  @Prop confirmText: string = '确认';
  @Prop cancelText: string = '取消';
  @Prop inputHint: string = '确定要撕毁？请输入以下文字：';
  onConfirm?: () => void;
  onCancel?: () => void;

  @State private inputText: string = '';
  private closingByConfirm: boolean = false;

  private isMatch(): boolean {
    return this.inputText === this.requiredText;
  }

  private handleDismiss(): void {
    this.inputText = '';
    if (!this.closingByConfirm) {
      this.onCancel?.();
    }
    this.closingByConfirm = false;
  }

  private handleConfirm(): void {
    if (!this.isMatch()) {
      return;
    }
    this.closingByConfirm = true;
    this.onConfirm?.();
    this.inputText = '';
    this.visible = false;
  }

  @Builder
  sheetContent() {
    Column({ space: 16 }) {
      Row() {
        Blank()
          .width(32)

        Text(this.title)
          .layoutWeight(1)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)

        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([AppTheme.colors.textSecondary])
        }
          .width(32)
          .height(32)
          .padding(0)
          .backgroundColor(Color.Transparent)
          .border({ width: 0 })
          .onClick(() => {
            this.visible = false;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.message)
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .lineHeight(22)
        .width('100%')

      Text(this.inputHint)
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      Column() {
        Text(this.requiredText)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.warning)
          .lineHeight(22)
          .width('100%')
      }
      .width('100%')
      .padding(12)
      .backgroundColor(AppTheme.colors.surfaceRaised)
      .borderRadius(AppTheme.radius.sm)

      TextInput({ text: this.inputText, placeholder: '请在此输入...' })
        .width('100%')
        .height(48)
        .fontSize(15)
        .fontColor(AppTheme.colors.textPrimary)
        .placeholderColor(AppTheme.colors.textMuted)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .borderRadius(AppTheme.radius.sm)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.inputText = value;
        })

      Row({ space: 12 }) {
        Button(this.cancelText)
          .layoutWeight(1)
          .height(48)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.border)
          .fontColor(AppTheme.colors.primary)
          .onClick(() => {
            this.visible = false;
          })

        Button(this.confirmText)
          .layoutWeight(1)
          .height(48)
          .type(ButtonType.Capsule)
          .backgroundColor(this.isMatch() ? AppTheme.colors.danger : AppTheme.colors.border)
          .fontColor(this.isMatch() ? '#FFFFFF' : AppTheme.colors.textMuted)
          .enabled(this.isMatch())
          .opacity(this.isMatch() ? 1 : 0.7)
          .onClick(() => {
            this.handleConfirm();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({
      left: 18,
      right: 18,
      top: 24,
      bottom: 34
    })
  }

  build() {
    Column()
      .width(0)
      .height(0)
      .bindSheet($$this.visible, this.sheetContent(), {
        height: SheetSize.FIT_CONTENT,
        preferType: SheetType.BOTTOM,
        showClose: false,
        dragBar: true,
        backgroundColor: AppTheme.colors.backgroundSoft,
        onDisappear: () => {
          this.handleDismiss();
        }
      })
  }
}

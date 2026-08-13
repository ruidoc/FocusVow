import { AppTheme } from '../../constants/Theme';

const QUOTE_RED: string = '#DC2626';
const FIELD_BG: string = '#F5F7FB';

/**
 * 底部输入确认半模态，对齐 RN InputConfirmModal（撕毁契约）。
 */
@Component
export struct InputConfirmSheet {
  @Link visible: boolean;
  @Prop title: string = '';
  @Prop message: string = '';
  @Prop extraWarning: string = '';
  @Prop requiredText: string = '';
  @Prop confirmText: string = '确认';
  @Prop cancelText: string = '取消';
  @Prop inputHint: string = '请输入以下文字确认：';
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
    Column() {
      // 标题区：警告图标 + 标题居中，关闭在右上
      Stack({ alignContent: Alignment.TopEnd }) {
        Column({ space: 14 }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
              .fontSize(22)
              .fontColor([QUOTE_RED])
              .offset({ top: -1 })
            Text(this.title)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.colors.textPrimary)
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')

          Column({ space: 4 }) {
            Text(this.message)
              .fontSize(15)
              .fontColor(AppTheme.colors.textSecondary)
              .lineHeight(22)
              .textAlign(TextAlign.Center)
              .width('100%')

            if (this.extraWarning.length > 0) {
              Text(this.extraWarning)
                .fontSize(13)
                .fontColor(AppTheme.colors.warning)
                .lineHeight(19)
                .textAlign(TextAlign.Center)
                .width('100%')
            }
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 12 })
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 28 })

        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([AppTheme.colors.textMuted])
        }
        .width(28)
        .height(28)
        .padding(0)
        .backgroundColor(Color.Transparent)
        .margin({ top: 0, right: -4 })
        .onClick(() => {
          this.visible = false;
        })
      }
      .width('100%')

      Text(this.inputHint)
        .fontSize(13)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .margin({ bottom: 10 })

      Text(this.requiredText)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(QUOTE_RED)
        .lineHeight(22)
        .width('100%')
        .margin({ bottom: 14 })

      TextInput({ text: this.inputText, placeholder: '在此输入确认文字' })
        .width('100%')
        .height(48)
        .fontSize(15)
        .fontColor(AppTheme.colors.textPrimary)
        .placeholderColor(AppTheme.colors.textMuted)
        .backgroundColor(FIELD_BG)
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .margin({ bottom: 28 })
        .onChange((value: string) => {
          this.inputText = value;
        })

      Row({ space: 12 }) {
        Button(this.cancelText)
          .layoutWeight(1)
          .height(48)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .backgroundColor(FIELD_BG)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .onClick(() => {
            this.visible = false;
          })

        Button(this.confirmText)
          .layoutWeight(1)
          .height(48)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .backgroundColor(this.isMatch() ? AppTheme.colors.danger : FIELD_BG)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isMatch() ? '#FFFFFF' : AppTheme.colors.textMuted)
          .enabled(this.isMatch())
          .opacity(this.isMatch() ? 1 : 0.85)
          .onClick(() => {
            this.handleConfirm();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({
      left: 22,
      right: 22,
      top: 20,
      bottom: 32
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
        backgroundColor: AppTheme.colors.surface,
        onDisappear: () => {
          this.handleDismiss();
        }
      })
  }
}

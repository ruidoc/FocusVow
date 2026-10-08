import { AppTheme } from '../../constants/Theme';

/**
 * 系统 SaveButton：授权后可在 1 分钟内写入相册（无需 WRITE_IMAGEVIDEO）。
 */
@Component
export struct GallerySaveButton {
  @Prop saving: boolean = false;
  onSave: () => void = () => {};

  build() {
    Row() {
      if (this.saving) {
        LoadingProgress()
          .width(22)
          .height(22)
          .color(AppTheme.colors.textPrimary);
      } else {
        SaveButton({
          text: SaveDescription.SAVE_IMAGE,
          buttonType: ButtonType.Capsule,
        })
          .width('100%')
          .height(48)
          .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
            if (result === SaveButtonOnClickResult.SUCCESS) {
              this.onSave();
            }
          });
      }
    }
    .layoutWeight(1)
    .height(48)
    .justifyContent(FlexAlign.Center);
  }
}

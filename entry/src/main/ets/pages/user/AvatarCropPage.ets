import { common } from '@kit.AbilityKit';
import { display, router, window } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { CropModel, CropView } from '@xinyansoft/oh-crop';
import { showErrorToast, showToast } from '../../common/Toast';
import { AppTheme } from '../../constants/Theme';
import { backRoute } from '../../router/PageRoutes';
import { packAvatarPixelMap } from '../../services/AvatarCompressService';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

interface AvatarCropRouteParams {
  uri?: string;
}

@Entry
@Component
struct AvatarCropPage {
  @State private model: CropModel = new CropModel()
    .setFrameRatio(1)
    .setEllipseFrame(false)
    .setRotationEnabled(false)
    .setMaskColor('#AA000000')
    .setStrokeColor('#FFFFFF');
  @State isBusy: boolean = false;
  @State hasImage: boolean = false;
  @State topSafeInsetVp: number = 0;
  @State bottomSafeInsetVp: number = 0;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    const ui = this.getUIContext();
    window.getLastWindow(hostContext, (err, win) => {
      if (err.code) {
        return;
      }
      const systemAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.topSafeInsetVp = ui.px2vp(systemAvoid.topRect.height);
      this.bottomSafeInsetVp = ui.px2vp(navAvoid.bottomRect.height);
    });

    const params = router.getParams() as AvatarCropRouteParams;
    const uri = params?.uri ?? '';
    if (uri.length === 0) {
      showErrorToast('未选择图片', this.getUIContext());
      backRoute();
      return;
    }

    const screen = display.getDefaultDisplaySync();
    // 尽量宽：左右约 20vp；同时不超过可用高度的约 70%，避免顶到操作栏
    const sideMarginPx = Math.ceil(ui.vp2px(20) * 2);
    const maxByWidth = screen.width - sideMarginPx;
    const maxByHeight = Math.floor(screen.height * 0.7);
    const framePx = Math.max(200, Math.min(maxByWidth, maxByHeight));
    this.model
      .setImage(uri)
      .setFrameWidth(framePx)
      .setFrameRatio(1)
      .setEllipseFrame(false)
      .setRotationEnabled(false);
    this.hasImage = true;
  }

  private async confirmCropAndUpload(): Promise<void> {
    if (this.isBusy || !this.hasImage) {
      return;
    }
    this.isBusy = true;
    let cropped: image.PixelMap | undefined = undefined;
    try {
      cropped = await this.model.crop();
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const packed = await packAvatarPixelMap(hostContext, cropped);
      // 先释放 PixelMap，再上传文件，避免占用导致异常
      await cropped.release();
      cropped = undefined;
      const error = await UserStore.uploadPackedAvatar(hostContext, packed.absolutePath);
      if (error) {
        showErrorToast(error, this.getUIContext());
        return;
      }
      showToast('头像已更新', this.getUIContext());
      backRoute();
    } catch (error) {
      console.error(`Avatar crop failed: ${String(error)}`);
      showErrorToast('裁剪失败，请重试', this.getUIContext());
    } finally {
      if (cropped !== undefined) {
        await cropped.release();
      }
      this.isBusy = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text('取消')
          .fontSize(16)
          .fontColor(Color.White)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            if (!this.isBusy) {
              backRoute();
            }
          })

        Blank()

        Text('裁剪头像')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)

        Blank()

        Text(this.isBusy ? '处理中…' : '完成')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isBusy ? '#888888' : AppTheme.colors.primary)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            void this.confirmCropAndUpload();
          })
      }
      .width('100%')
      .height(56)
      .margin({ top: this.topSafeInsetVp })
      .alignItems(VerticalAlign.Center)

      if (this.hasImage) {
        CropView({ model: this.model })
          .layoutWeight(1)
          .width('100%')
      } else {
        Blank()
          .layoutWeight(1)
      }

      Text('拖动或双指缩放，框内区域将作为头像')
        .fontSize(13)
        .fontColor('#CCCCCC')
        .margin({ bottom: 16 + this.bottomSafeInsetVp, top: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#111111')
  }
}

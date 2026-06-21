import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

export const CERTIFICATE_SNAPSHOT_ID: string = 'certificateSnapshotRoot';

export async function saveCertificateSnapshot(
  uiContext: UIContext,
  context: common.UIAbilityContext,
  componentId: string = CERTIFICATE_SNAPSHOT_ID
): Promise<void> {
  const pixelMap = await captureComponentSnapshot(uiContext, componentId);
  const packer = image.createImagePacker();
  const packOpts: image.PackingOption = {
    format: 'image/png',
    quality: 100
  };
  const buffer = await packer.packToData(pixelMap, packOpts);
  const helper = photoAccessHelper.getPhotoAccessHelper(context);
  const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'png');
  const file = await fileIo.open(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
  try {
    await fileIo.write(file.fd, buffer);
  } finally {
    await fileIo.close(file.fd);
  }
}

function captureComponentSnapshot(uiContext: UIContext, componentId: string): Promise<image.PixelMap> {
  return new Promise<image.PixelMap>((resolve, reject) => {
    uiContext.getComponentSnapshot().get(componentId, (error: Error, pixmap: image.PixelMap) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(pixmap);
    });
  });
}

export function formatSaveError(error: BusinessError): string {
  if (error.message && error.message.length > 0) {
    return `保存失败：${error.message}`;
  }
  return `保存失败（${error.code}）`;
}

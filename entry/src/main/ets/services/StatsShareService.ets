import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { systemShare } from '@kit.ShareKit';
import { captureComponentSnapshot } from './CertificateImageService';

export const STATS_SNAPSHOT_ID: string = 'statsShareSnapshotRoot';

export async function captureStatsShareSnapshot(uiContext: UIContext): Promise<image.PixelMap> {
  // 长图 + scale 2 体积过大时系统分享会直接失败
  return captureComponentSnapshot(uiContext, STATS_SNAPSHOT_ID, {
    scale: 1,
    waitUntilRenderFinished: true
  });
}

export function buildStatsShareCachePath(context: common.Context): string {
  return `${context.filesDir}/stats_share_${Date.now()}.jpg`;
}

export async function writePixelMapToFile(pixelMap: image.PixelMap, filePath: string): Promise<void> {
  const packer = image.createImagePacker();
  const buffer = await packer.packToData(pixelMap, {
    format: 'image/jpeg',
    quality: 70
  });
  const file = await fileIo.open(
    filePath,
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
  );
  try {
    await fileIo.write(file.fd, buffer);
  } finally {
    await fileIo.close(file.fd);
  }
}

export async function shareStatsImageFile(
  context: common.UIAbilityContext,
  filePath: string,
  title: string,
  description: string
): Promise<void> {
  const shareData = new systemShare.SharedData({
    utd: utd.UniformDataType.IMAGE,
    title,
    description,
    uri: fileUri.getUriFromPath(filePath)
  });
  const controller = new systemShare.ShareController(shareData);
  await controller.show(context, {
    selectionMode: systemShare.SelectionMode.SINGLE,
    previewMode: systemShare.SharePreviewMode.DETAIL
  });
}

export function formatShareError(error: BusinessError): string {
  if (error.message && error.message.length > 0) {
    return `分享失败：${error.message}`;
  }
  return `分享失败（${error.code}）`;
}

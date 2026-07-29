import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';

/** 与 RN 对齐：输出边长 400、JPEG quality 0.7 */
const AVATAR_TARGET_SIDE: number = 400;
const AVATAR_JPEG_QUALITY: number = 70;

interface OpenedImageSource {
  source: image.ImageSource;
  fd: number;
}

/** 压缩结果：沙箱绝对路径（文件名可映射 internal://cache/xxx） */
export interface PackedAvatar {
  absolutePath: string;
  fileName: string;
}

function openImageSource(sourceUri: string): OpenedImageSource {
  const file = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
  return {
    source: image.createImageSource(file.fd),
    fd: file.fd
  };
}

async function writeJpegToCache(
  context: common.Context,
  pixelMap: image.PixelMap
): Promise<PackedAvatar> {
  const packer = image.createImagePacker();
  const buffer = await packer.packToData(pixelMap, {
    format: 'image/jpeg',
    quality: AVATAR_JPEG_QUALITY
  } as image.PackingOption);

  const fileName = `avatar_${Date.now()}.jpg`;
  // cacheDir 对应 internal://cache/
  const absolutePath = `${context.cacheDir}/${fileName}`;
  const outFile = await fileIo.open(
    absolutePath,
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
  );
  try {
    await fileIo.write(outFile.fd, buffer);
  } finally {
    await fileIo.close(outFile.fd);
  }

  const size = Number(fileIo.statSync(absolutePath).size);
  if (size <= 0) {
    throw new Error('头像写入后文件为空');
  }
  console.info(`[AvatarCompress] packed | path=${absolutePath} | size=${size}`);

  const packed: PackedAvatar = {
    absolutePath: absolutePath,
    fileName: fileName
  };
  return packed;
}

/** 将裁剪后的 PixelMap 缩到 400 并压成 JPEG 缓存文件 */
export async function packAvatarPixelMap(
  context: common.Context,
  pixelMap: image.PixelMap
): Promise<PackedAvatar> {
  const info = await pixelMap.getImageInfo();
  const srcW = info.size.width;
  const srcH = info.size.height;
  if (srcW <= 0 || srcH <= 0) {
    throw new Error('无效图片尺寸');
  }
  if (srcW !== AVATAR_TARGET_SIDE || srcH !== AVATAR_TARGET_SIDE) {
    const scale = AVATAR_TARGET_SIDE / Math.max(srcW, srcH);
    await pixelMap.scale(scale, scale);
  }
  return writeJpegToCache(context, pixelMap);
}

/**
 * 无裁剪页时的兜底：相册 URI → fd 解码 → 居中正方形 → 压缩到缓存。
 */
export async function compressAvatarForUpload(
  context: common.Context,
  sourceUri: string
): Promise<PackedAvatar> {
  const opened = openImageSource(sourceUri);
  let pixelMap: image.PixelMap | undefined = undefined;
  try {
    const info = await opened.source.getImageInfo();
    const srcWidth = info.size.width;
    const srcHeight = info.size.height;
    if (srcWidth <= 0 || srcHeight <= 0) {
      throw new Error('无效图片尺寸');
    }
    const side = Math.min(srcWidth, srcHeight);
    const regionX = Math.floor((srcWidth - side) / 2);
    const regionY = Math.floor((srcHeight - side) / 2);
    try {
      pixelMap = await opened.source.createPixelMap({
        desiredRegion: {
          x: regionX,
          y: regionY,
          size: { width: side, height: side }
        },
        desiredSize: {
          width: AVATAR_TARGET_SIDE,
          height: AVATAR_TARGET_SIDE
        },
        cropAndScaleStrategy: image.CropAndScaleStrategy.CROP_FIRST
      });
    } catch (_e) {
      pixelMap = await opened.source.createPixelMap({
        desiredSize: {
          width: srcWidth >= srcHeight
            ? Math.max(1, Math.round(srcWidth * AVATAR_TARGET_SIDE / srcHeight))
            : AVATAR_TARGET_SIDE,
          height: srcHeight >= srcWidth
            ? Math.max(1, Math.round(srcHeight * AVATAR_TARGET_SIDE / srcWidth))
            : AVATAR_TARGET_SIDE
        }
      });
      const mapped = await pixelMap.getImageInfo();
      const mw = mapped.size.width;
      const mh = mapped.size.height;
      const mSide = Math.min(mw, mh);
      await pixelMap.crop({
        x: Math.floor((mw - mSide) / 2),
        y: Math.floor((mh - mSide) / 2),
        size: { width: mSide, height: mSide }
      });
    }
    return writeJpegToCache(context, pixelMap);
  } finally {
    if (pixelMap !== undefined) {
      await pixelMap.release();
    }
    try {
      fileIo.closeSync(opened.fd);
    } catch (_closeErr) {
      // ignore
    }
  }
}

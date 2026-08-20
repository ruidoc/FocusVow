import { bundleManager } from '@kit.AbilityKit';
import deviceInfo from '@ohos.deviceInfo';

let cachedAppVersion: string = 'unknown';

export function getAppVersionSync(): string {
  return cachedAppVersion;
}

export async function getAppVersion(): Promise<string> {
  try {
    const bundleInfo = await bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
    );
    if (bundleInfo.versionName && bundleInfo.versionName.length > 0) {
      cachedAppVersion = bundleInfo.versionName;
      return cachedAppVersion;
    }
    return cachedAppVersion;
  } catch (error) {
    console.error(`getAppVersion failed: ${String(error)}`);
    return cachedAppVersion;
  }
}

/** HTTP 头只能安全传 ASCII；中文营销名会变成 Latin-1 乱码（如 荣耀 → è£è） */
function toAsciiSafe(value: string): string {
  let out = '';
  for (let i = 0; i < value.length; i++) {
    const code = value.charCodeAt(i);
    if (code >= 0x20 && code <= 0x7e) {
      out += value.charAt(i);
    }
  }
  return out.trim();
}

function normalizeBrand(brand: string, manufacture: string): string {
  const raw = [brand, manufacture]
    .map((v: string) => v.trim().toLowerCase())
    .find((v: string) => v.length > 0);
  if (!raw) {
    return '';
  }
  if (raw.includes('huawei') || raw.includes('华为')) {
    return 'huawei';
  }
  if (raw.includes('honor') || raw.includes('荣耀')) {
    return 'honor';
  }
  if (raw.includes('xiaomi') || raw.includes('redmi') || raw.includes('小米') ||
    raw.includes('红米')) {
    return 'xiaomi';
  }
  if (raw.includes('oppo')) {
    return 'oppo';
  }
  if (raw.includes('oneplus') || raw.includes('一加')) {
    return 'oneplus';
  }
  if (raw.includes('vivo') || raw.includes('iqoo')) {
    return 'vivo';
  }
  if (raw.includes('samsung') || raw.includes('三星')) {
    return 'samsung';
  }
  return toAsciiSafe(brand || manufacture).toLowerCase();
}

/**
 * 飞书/上报用设备展示名：优先英文品牌 + ASCII 机型（如 honor-90 Pro）。
 * 勿直接传 marketName 中文，否则经 HTTP 头会乱码。
 */
export function getDeviceModel(): string {
  try {
    const brand = normalizeBrand(
      deviceInfo.brand || '',
      deviceInfo.manufacture || ''
    );
    const market = toAsciiSafe(deviceInfo.marketName || '');
    const product = toAsciiSafe(deviceInfo.productModel || '');
    const model = market || product;
    if (brand && model) {
      return `${brand}-${model}`;
    }
    if (model) {
      return model;
    }
    if (brand) {
      return brand;
    }
  } catch (error) {
    console.error(`getDeviceModel failed: ${String(error)}`);
  }
  return '';
}

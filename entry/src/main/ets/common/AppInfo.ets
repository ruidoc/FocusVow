import { bundleManager } from '@kit.AbilityKit';
import deviceInfo from '@ohos.deviceInfo';

export async function getAppVersion(): Promise<string> {
  try {
    const bundleInfo = await bundleManager.getBundleInfoForSelf(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
    );
    if (bundleInfo.versionName && bundleInfo.versionName.length > 0) {
      return bundleInfo.versionName;
    }
    return 'unknown';
  } catch (error) {
    console.error(`getAppVersion failed: ${String(error)}`);
    return 'unknown';
  }
}

export function getDeviceModel(): string {
  try {
    if (deviceInfo.marketName && deviceInfo.marketName.length > 0) {
      return deviceInfo.marketName;
    }
    if (deviceInfo.productModel && deviceInfo.productModel.length > 0) {
      return deviceInfo.productModel;
    }
  } catch (error) {
    console.error(`getDeviceModel failed: ${String(error)}`);
  }
  return '';
}

import { bundleManager } from '@kit.AbilityKit';

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

import deviceInfo from '@ohos.deviceInfo';

/** PC / 二合一设备通常无屏时守护能力，需绕开权限与选 App */
export function isHarmonyPcOr2in1(): boolean {
  try {
    return deviceInfo.deviceType === '2in1';
  } catch {
    return false;
  }
}

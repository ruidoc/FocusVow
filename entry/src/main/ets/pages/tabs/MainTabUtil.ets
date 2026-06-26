import deviceInfo from '@ohos.deviceInfo';
import { MainTabKey } from '../../router/PageRoutes';

export const FLOATING_TAB_EXTRA_BOTTOM_VP: number = 72;
const IMMERSIVE_TAB_MIN_API_VERSION: number = 23;

export interface MainTabIconPair {
  normal: Resource;
  selected: Resource;
}

export function getMainTabIcons(tab: MainTabKey): MainTabIconPair {
  if (tab === 'focus') {
    return {
      normal: $r('sys.symbol.timer'),
      selected: $r('sys.symbol.timer_circle_fill')
    };
  }
  if (tab === 'plans') {
    return {
      normal: $r('sys.symbol.alarm'),
      selected: $r('sys.symbol.alarm_fill')
    };
  }
  if (tab === 'stats') {
    return {
      normal: $r('sys.symbol.histogram'),
      selected: $r('sys.symbol.histogram_fill')
    };
  }
  return {
    normal: $r('sys.symbol.person'),
    selected: $r('sys.symbol.person_fill')
  };
}

export function supportsImmersiveTab(): boolean {
  try {
    return deviceInfo.sdkApiVersion >= IMMERSIVE_TAB_MIN_API_VERSION;
  } catch {
    return false;
  }
}

export function mainTabToIndex(tab: MainTabKey): number {
  if (tab === 'plans') {
    return 1;
  }
  if (tab === 'stats') {
    return 2;
  }
  if (tab === 'profile') {
    return 3;
  }
  return 0;
}

export function indexToMainTab(index: number): MainTabKey {
  if (index === 1) {
    return 'plans';
  }
  if (index === 2) {
    return 'stats';
  }
  if (index === 3) {
    return 'profile';
  }
  return 'focus';
}

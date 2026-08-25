import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { HdsTabsBackgroundStyle, HdsTabsFloatingStyle, SystemMaterialParams } from '@kit.UIDesignKit';
import { isDarkThemeMode } from '../../constants/Theme';

interface ImmersiveMaterialSelection {
  materialType: hdsMaterial.MaterialType;
  materialLevel: hdsMaterial.MaterialLevel;
}

function resolveImmersiveMaterialSelection(): ImmersiveMaterialSelection {
  try {
    const supportedTypes: hdsMaterial.MaterialType[] = hdsMaterial.getSystemMaterialTypes();
    if (supportedTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0) {
      return {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
      };
    }
  } catch {
    // 设备不支持查询时走自适应降级
  }
  return {
    materialType: hdsMaterial.MaterialType.ADAPTIVE,
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
  };
}

export function createImmersiveTabFloatingStyle(barBottomMargin: number): HdsTabsFloatingStyle {
  const material = resolveImmersiveMaterialSelection();
  const isDark = isDarkThemeMode();
  const systemMaterialEffect: SystemMaterialParams = {
    materialType: material.materialType,
    materialLevel: material.materialLevel
  };
  const gradientMask: HdsTabsBackgroundStyle = {
    maskColor: isDark ? '#66121212' : '#66F1F3F5',
    maskHeight: 92
  };
  const floatingStyle: HdsTabsFloatingStyle = {
    barBottomMargin: barBottomMargin,
    adaptToHandedness: true,
    lightColor: isDark ? '#331E1E1E' : '#33FFFFFF',
    gradientMask: gradientMask,
    systemMaterialEffect: systemMaterialEffect
  };
  return floatingStyle;
}

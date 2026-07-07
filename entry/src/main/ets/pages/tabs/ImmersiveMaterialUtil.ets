import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { HdsTabsBackgroundStyle, HdsTabsFloatingStyle, SystemMaterialParams } from '@kit.UIDesignKit';

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
  const systemMaterialEffect: SystemMaterialParams = {
    materialType: material.materialType,
    materialLevel: material.materialLevel
  };
  const gradientMask: HdsTabsBackgroundStyle = {
    maskColor: '#66F1F3F5',
    maskHeight: 92
  };
  const floatingStyle: HdsTabsFloatingStyle = {
    barBottomMargin: barBottomMargin,
    adaptToHandedness: true,
    lightColor: '#33FFFFFF',
    gradientMask: gradientMask,
    systemMaterialEffect: systemMaterialEffect
  };
  return floatingStyle;
}

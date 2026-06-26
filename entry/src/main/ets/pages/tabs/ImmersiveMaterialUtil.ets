import { hdsMaterial } from '@hms.hds.hdsMaterial';
import { HdsTabsFloatingStyle, SystemMaterialParams } from '@kit.UIDesignKit';

export function createImmersiveTabFloatingStyle(barBottomMargin: number): HdsTabsFloatingStyle {
  const systemMaterialEffect: SystemMaterialParams = {
    materialType: hdsMaterial.MaterialType.ADAPTIVE,
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
  };
  const floatingStyle: HdsTabsFloatingStyle = {
    barBottomMargin: barBottomMargin,
    systemMaterialEffect: systemMaterialEffect
  };
  return floatingStyle;
}

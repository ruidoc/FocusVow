import { drawing } from '@kit.ArkGraphics2D';
import { AppTheme } from '../../constants/Theme';

/**
 * Lucide users：media/users.svg + SRC_IN 着色，与 iOS primary 色对齐。
 */
@Component
export struct UsersIcon {
  @Prop iconSize: number = 24;
  @Prop color: string = AppTheme.colors.primary;

  private tintFilter(): drawing.ColorFilter {
    const rgb = this.parseRgb(this.color);
    return drawing.ColorFilter.createBlendModeColorFilter(
      {
        alpha: 255,
        red: rgb[0],
        green: rgb[1],
        blue: rgb[2],
      },
      drawing.BlendMode.SRC_IN,
    );
  }

  private parseRgb(color: string): number[] {
    let hex = color.trim();
    if (hex.startsWith('#')) {
      hex = hex.slice(1);
    }
    if (hex.length === 8) {
      hex = hex.slice(2);
    }
    if (hex.length !== 6) {
      return [122, 90, 248]; // #7A5AF8
    }
    return [
      Number.parseInt(hex.slice(0, 2), 16),
      Number.parseInt(hex.slice(2, 4), 16),
      Number.parseInt(hex.slice(4, 6), 16),
    ];
  }

  build() {
    Image($r('app.media.users'))
      .width(this.iconSize)
      .height(this.iconSize)
      .objectFit(ImageFit.Contain)
      .colorFilter(this.tintFilter())
  }
}

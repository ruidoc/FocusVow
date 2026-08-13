class ThemeColors {
  background: string = '#F5F6FA';
  backgroundSoft: string = '#FFFFFF';
  surface: string = '#FFFFFF';
  surfaceRaised: string = '#F7F8FC';
  border: string = '#E6E8F0';
  borderStrong: string = '#D7DDEA';
  primary: string = '#7A5AF8';
  primarySoft: string = '#F1EDFF';
  textPrimary: string = '#111827';
  textSecondary: string = '#5B6475';
  textMuted: string = '#98A2B3';
  success: string = '#1F9D55';
  successSoft: string = '#E8F8EF';
  accentBlue: string = '#3B82F6';
  accentOrange: string = '#F97316';
  accentGreen: string = '#10B981';
  warning: string = '#C98512';
  danger: string = '#D64545';
  dangerSoft: string = '#FDECEC';
}

class ThemeRadius {
  sm: number = 14;
  md: number = 18;
  lg: number = 22;
  /** 主按钮圆角，对齐 RN Button rounded-[30px] */
  button: number = 30;
  pill: number = 999;
}

export class AppTheme {
  static readonly colors: ThemeColors = new ThemeColors();
  static readonly radius: ThemeRadius = new ThemeRadius();
  /**
   * 契约证书最大宽度（vp）。
   * 证书底图与文字按手机宽度排版，超出后印章/文案会错位。
   */
  static readonly certificateMaxWidth: number = 380;
}

/** 内容区最大宽度取窗口短边：竖屏铺满，横屏与竖屏同宽 */
export function resolveContentMaxWidthVp(widthVp: number, heightVp: number): number {
  return Math.min(widthVp, heightVp);
}

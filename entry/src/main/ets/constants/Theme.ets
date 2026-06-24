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
  successSoft: string = '#E8F7EE';
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
  pill: number = 999;
}

export class AppTheme {
  static readonly colors: ThemeColors = new ThemeColors();
  static readonly radius: ThemeRadius = new ThemeRadius();
}

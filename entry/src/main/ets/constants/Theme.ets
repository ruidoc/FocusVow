class ThemeColors {
  background: string = '#F8FAFC';
  backgroundSoft: string = '#FFFFFF';
  surface: string = '#FFFFFF';
  surfaceRaised: string = '#F1F5F9';
  border: string = '#E2E8F0';
  borderStrong: string = '#CBD5E1';
  primary: string = '#7A5AF8';
  primarySoft: string = '#EEE8FF';
  textPrimary: string = '#0F172A';
  textSecondary: string = '#475569';
  textMuted: string = '#94A3B8';
  success: string = '#16A34A';
  successSoft: string = '#DCFCE7';
  warning: string = '#D97706';
  danger: string = '#DC2626';
  dangerSoft: string = '#FEE2E2';
}

class ThemeRadius {
  sm: number = 16;
  md: number = 20;
  lg: number = 24;
  pill: number = 999;
}

export class AppTheme {
  static readonly colors: ThemeColors = new ThemeColors();
  static readonly radius: ThemeRadius = new ThemeRadius();
}

class ThemeColors {
  background: string = '#14141C';
  backgroundSoft: string = '#171722';
  surface: string = '#181821';
  surfaceRaised: string = '#1E1E29';
  border: string = '#262633';
  borderStrong: string = '#313142';
  primary: string = '#7A5AF8';
  primarySoft: string = '#2F2558';
  textPrimary: string = '#E5E7EB';
  textSecondary: string = '#9CA3AF';
  textMuted: string = '#6B7280';
  success: string = '#22C55E';
  successSoft: string = '#163523';
  warning: string = '#F59E0B';
  danger: string = '#F87171';
  dangerSoft: string = '#3B2027';
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

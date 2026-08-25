import { StoreKeys } from '../stores/StoreKeys';

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
  surfaceSecondary: string = '#F0F2F5';
  ring: string = '#E5E7EB';
  primaryMuted: string = '#7A5AF880';
  primaryMutedForeground: string = '#A78BFA';
  paywallCardSelected: string = '#FFFBF0';
  paywallCloseBtnBg: string = '#EEF2F7';
  divider: string = '#E8EBF0';
}

class ThemeRadius {
  sm: number = 14;
  md: number = 18;
  lg: number = 22;
  button: number = 30;
  pill: number = 999;
}

const LIGHT_COLORS: ThemeColors = {
  background: '#F5F7FB',
  backgroundSoft: '#FFFFFF',
  surface: '#FFFFFF',
  surfaceRaised: '#F7F8FC',
  border: '#E5E7EB',
  borderStrong: '#D7DDEA',
  primary: '#7A5AF8',
  primarySoft: '#F1EDFF',
  textPrimary: '#0F172A',
  textSecondary: '#64748B',
  textMuted: '#64748B',
  success: '#16A34A',
  successSoft: '#E8F8EF',
  accentBlue: '#2563EB',
  accentOrange: '#F97316',
  accentGreen: '#10B981',
  warning: '#C98512',
  danger: '#D64545',
  dangerSoft: '#FDECEC',
  surfaceSecondary: '#F0F2F5',
  ring: '#E5E7EB',
  primaryMuted: '#7A5AF880',
  primaryMutedForeground: '#A78BFA',
  paywallCardSelected: '#FFFBF0',
  paywallCloseBtnBg: '#EEF2F7',
  divider: '#E8EBF0',
};

const DARK_COLORS: ThemeColors = {
  background: '#121212',
  backgroundSoft: '#1A1A1A',
  surface: '#1E1E1E',
  surfaceRaised: '#252525',
  border: '#2A2A2A',
  borderStrong: '#333333',
  primary: '#7A5AF8',
  primarySoft: '#2A2440',
  textPrimary: '#F5F5F5',
  textSecondary: '#A3A3A3',
  textMuted: '#737373',
  success: '#22C55E',
  successSoft: '#143322',
  accentBlue: '#3B82F6',
  accentOrange: '#F97316',
  accentGreen: '#10B981',
  warning: '#F59E0B',
  danger: '#F87171',
  dangerSoft: '#3A1F1F',
  surfaceSecondary: '#1A1A1A',
  ring: '#333333',
  primaryMuted: '#2A2A2A',
  primaryMutedForeground: '#737373',
  paywallCardSelected: '#1C1A14',
  paywallCloseBtnBg: '#1A1A1A',
  divider: '#2A2A2A',
};

export type ThemeMode = 'light' | 'dark';

export function isDarkThemeMode(): boolean {
  return AppStorage.get<string>(StoreKeys.ThemeMode) === 'dark';
}

export function getThemeColors(): ThemeColors {
  return isDarkThemeMode() ? DARK_COLORS : LIGHT_COLORS;
}

export class AppTheme {
  static get colors(): ThemeColors {
    return getThemeColors();
  }

  static readonly radius: ThemeRadius = new ThemeRadius();
  static readonly certificateMaxWidth: number = 380;
}

/** 内容区最大宽度取窗口短边：竖屏铺满，横屏与竖屏同宽 */
export function resolveContentMaxWidthVp(widthVp: number, heightVp: number): number {
  return Math.min(widthVp, heightVp);
}

import { isDarkThemeMode } from './Theme';

export function homeGlassCardBg(isDark?: boolean): string {
  const dark = isDark ?? isDarkThemeMode();
  return dark ? 'rgba(30, 30, 30, 0.72)' : 'rgba(255, 255, 255, 0.72)';
}

export function homeGlassPrimaryIconBg(isDark?: boolean): string {
  const dark = isDark ?? isDarkThemeMode();
  return dark ? 'rgba(122, 90, 248, 0.18)' : 'rgba(122, 90, 248, 0.094)';
}

export function homeGlassGoldIconBg(): string {
  return 'rgba(212, 164, 74, 0.22)';
}

export function homeTodayMetricsBg(): string {
  // 明暗模式均保持白色半透明（对齐 RN，略提高透明度）
  return 'rgba(255, 255, 255, 0.10)';
}

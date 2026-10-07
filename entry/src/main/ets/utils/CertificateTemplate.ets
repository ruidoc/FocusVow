/** 与 RN certificate-scale：字号/间距缩放基准宽 */
export const CERTIFICATE_DESIGN_WIDTH: number = 340;

export const CERTIFICATE_CARD_WIDTH_RATIO: number = 0.86;

export const CERTIFICATE_PEEK_SIDE_SCALE: number = 0.86;

export const CERTIFICATE_PEEK_GAP: number = 16;

export function peekCarouselCardWidth(screenWidth: number): number {
  return Math.round(screenWidth * CERTIFICATE_CARD_WIDTH_RATIO);
}

/** 顺序与 RN CERTIFICATE_TEMPLATE_STYLES 一致 */
export const CERTIFICATE_TEMPLATES: string[] = [
  'classic',
  'valorant',
  'minimal',
  'delta',
  'retro',
  'retroLite',
];

export function certificateTemplateLabel(style: string): string {
  if (style === 'minimal') {
    return '现代极简';
  }
  if (style === 'retro') {
    return '复古告示';
  }
  if (style === 'retroLite') {
    return '复古简约';
  }
  if (style === 'valorant') {
    return '无畏契约';
  }
  if (style === 'delta') {
    return '三角洲行动';
  }
  return '庄严公证';
}

export const CONTRACT_FONT: string = 'LuoXiGangBiXingKai';

export class ContractPalette {
  title: string = '#3E2A12';
  docket: string = 'rgba(120, 92, 45, 0.78)';
  divider: string = '#D5C49E';
  clauseLabel: string = '#705018';
  clauseBody: string = '#382B18';
  highlight: string = '#1C1306';
}

export function certificateHidesTitle(style: string): boolean {
  return style === 'retro';
}

export function isCertificateDarkTheme(variant: string, style: string): boolean {
  const retroPaper = style === 'retro' || style === 'retroLite';
  if (style === 'valorant' || style === 'delta') {
    return true;
  }
  return variant === 'shame' && !retroPaper;
}

export function getContractDocket(datetime: string, prefix: string): string {
  const digits = datetime.replace(/\D/g, '');
  const datePart = digits.length >= 8 ? digits.substring(0, 8) : '20260924';
  const timePart = digits.length >= 12 ? digits.substring(8, 12) : '01';
  return `${prefix}字第 ${datePart} · ${timePart}号 · 官方公证归档`;
}

export function getContractPalette(variant: string, style: string): ContractPalette {
  const palette = new ContractPalette();
  if (variant === 'honor') {
    if (style === 'retro' || style === 'retroLite') {
      palette.title = style === 'retroLite' ? '#7A1A1A' : '#8F1E1E';
      palette.docket = 'rgba(143, 30, 30, 0.72)';
      palette.divider = style === 'retroLite' ? '#B89050' : '#C49A45';
      palette.clauseLabel = '#8F1E1E';
      palette.clauseBody = '#2E2218';
      palette.highlight = '#1A1008';
      return palette;
    }
    if (style === 'minimal') {
      palette.title = '#222222';
      palette.docket = '#8A7A60';
      palette.divider = '#D5C8A8';
      palette.clauseLabel = '#7D6330';
      palette.clauseBody = '#2B2B2B';
      palette.highlight = '#000000';
      return palette;
    }
    if (style === 'valorant') {
      palette.title = '#FFF8EA';
      palette.docket = 'rgba(212, 175, 105, 0.85)';
      palette.divider = '#C89D5E';
      palette.clauseLabel = '#EAC575';
      palette.clauseBody = '#E2E8F0';
      palette.highlight = '#FFFFFF';
      return palette;
    }
    if (style === 'delta') {
      palette.title = '#F4FFE0';
      palette.docket = 'rgba(210, 255, 0, 0.85)';
      palette.divider = '#D2FF00';
      palette.clauseLabel = '#D8FF33';
      palette.clauseBody = '#E2E8F0';
      palette.highlight = '#FFFFFF';
      return palette;
    }
    return palette;
  }
  if (style === 'retro' || style === 'retroLite') {
    palette.title = '#4A1414';
    palette.docket = 'rgba(74, 20, 20, 0.7)';
    palette.divider = style === 'retroLite' ? '#6A5040' : '#8A4A4A';
    palette.clauseLabel = '#781C1C';
    palette.clauseBody = '#2C1A1A';
    palette.highlight = '#0F0505';
    return palette;
  }
  if (style === 'minimal') {
    palette.title = '#F5D5D5';
    palette.docket = 'rgba(235, 150, 150, 0.65)';
    palette.divider = '#662222';
    palette.clauseLabel = '#FF7575';
    palette.clauseBody = '#D8C4C4';
    palette.highlight = '#FFA8A8';
    return palette;
  }
  if (style === 'valorant') {
    palette.title = '#FF4655';
    palette.docket = 'rgba(255, 70, 85, 0.85)';
    palette.divider = '#FF4655';
    palette.clauseLabel = '#FF5C6B';
    palette.clauseBody = '#E8ECF2';
    palette.highlight = '#FFA0A8';
    return palette;
  }
  if (style === 'delta') {
    palette.title = '#FF7A1A';
    palette.docket = 'rgba(255, 122, 26, 0.88)';
    palette.divider = '#FF7A1A';
    palette.clauseLabel = '#FF944D';
    palette.clauseBody = '#E8ECF0';
    palette.highlight = '#FFD1AA';
    return palette;
  }
  palette.title = '#F2D0D0';
  palette.docket = 'rgba(242, 208, 208, 0.7)';
  palette.divider = '#752A2A';
  palette.clauseLabel = '#E87A7A';
  palette.clauseBody = '#E0C8C8';
  palette.highlight = '#FFAFA8';
  return palette;
}

export function honorCertificateBackground(style: string): Resource {
  if (style === 'minimal') {
    return $r('app.media.bg_honor_minimal');
  }
  if (style === 'retro') {
    return $r('app.media.bg_honor_retro');
  }
  if (style === 'retroLite') {
    return $r('app.media.bg_honor_retro_lite');
  }
  if (style === 'valorant') {
    return $r('app.media.bg_honor_valorant');
  }
  if (style === 'delta') {
    return $r('app.media.bg_honor_delta');
  }
  return $r('app.media.bg_honor_classic');
}

export function shameCertificateBackground(style: string): Resource {
  if (style === 'minimal') {
    return $r('app.media.bg_shame_minimal');
  }
  if (style === 'retro') {
    return $r('app.media.bg_shame_retro');
  }
  if (style === 'retroLite') {
    return $r('app.media.bg_shame_retro_lite');
  }
  if (style === 'valorant') {
    return $r('app.media.bg_shame_valorant');
  }
  if (style === 'delta') {
    return $r('app.media.bg_shame_delta');
  }
  return $r('app.media.bg_shame_classic');
}

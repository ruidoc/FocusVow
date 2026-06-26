export type CertificateKind = 'honor' | 'shame';

export type ShameCertificateVariant = 'solo' | 'victim' | 'violator';

export const CERTIFICATE_FOOTER_BRAND: string = '专注契约';

export const CERTIFICATE_AD_SLOGAN: string = '来「专注契约」，和搭子一起守住专注时间。';

export interface HonorCertificateData {
  userName: string;
  partnerName: string;
  cardTitle: string;
  modeLabel: string;
  contractTitle: string;
  durationMinutes: number;
  resultNarrative: string;
  footerBrand: string;
  footerDatetime: string;
  adSlogan: string;
}

export interface ShameCertificateData {
  userName: string;
  counterpartName: string;
  cardTitle: string;
  roleLabel: string;
  modeLabel: string;
  contractTitle: string;
  totalMinutes: number;
  actualMinutes: number;
  resultNarrative: string;
  footerBrand: string;
  footerDatetime: string;
  adSlogan: string;
  shameVariant: ShameCertificateVariant;
}

export function createEmptyHonorCertificateData(): HonorCertificateData {
  return {
    userName: '',
    partnerName: '',
    cardTitle: '',
    modeLabel: '',
    contractTitle: '',
    durationMinutes: 0,
    resultNarrative: '',
    footerBrand: CERTIFICATE_FOOTER_BRAND,
    footerDatetime: '',
    adSlogan: CERTIFICATE_AD_SLOGAN
  };
}

export function createEmptyShameCertificateData(): ShameCertificateData {
  return {
    userName: '',
    counterpartName: '',
    cardTitle: '',
    roleLabel: '',
    modeLabel: '',
    contractTitle: '',
    totalMinutes: 0,
    actualMinutes: 0,
    resultNarrative: '',
    footerBrand: CERTIFICATE_FOOTER_BRAND,
    footerDatetime: '',
    adSlogan: CERTIFICATE_AD_SLOGAN,
    shameVariant: 'solo'
  };
}

export function isDuoHonorCertificate(data: HonorCertificateData): boolean {
  return data.partnerName.trim().length > 0;
}

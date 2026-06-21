export type CertificateKind = 'honor' | 'shame';

export interface HonorCertificateData {
  userName: string;
  dateLabel: string;
  contractTitle: string;
  durationMinutes: number;
  modeLabel: string;
  behaviorVerdict: string;
  closingRemark: string;
  issuedAt: string;
  qrContent: string;
  footerSlogan: string;
}

export interface ShameCertificateData {
  userName: string;
  datetimeLabel: string;
  contractTitle: string;
  totalMinutes: number;
  actualMinutes: number;
  modeLabel: string;
  breachNarrative: string;
  behaviorVerdict: string;
  punishmentLabel: string;
  qrContent: string;
  footerSlogan: string;
}

export function createEmptyHonorCertificateData(): HonorCertificateData {
  return {
    userName: '',
    dateLabel: '',
    contractTitle: '',
    durationMinutes: 0,
    modeLabel: '',
    behaviorVerdict: '',
    closingRemark: '',
    issuedAt: '',
    qrContent: 'FocusVow',
    footerSlogan: ''
  };
}

export function createEmptyShameCertificateData(): ShameCertificateData {
  return {
    userName: '',
    datetimeLabel: '',
    contractTitle: '',
    totalMinutes: 0,
    actualMinutes: 0,
    modeLabel: '',
    breachNarrative: '',
    behaviorVerdict: '',
    punishmentLabel: '',
    qrContent: 'FocusVow',
    footerSlogan: ''
  };
}

export type ShareSocialScene =
  | 'checkin'
  | 'milestone'
  | 'rescue'
  | 'honor'
  | 'victim'
  | 'violator';

export type ShareCertificateKind =
  | 'solo_honor'
  | 'solo_violator'
  | 'duo_honor'
  | 'victim'
  | 'violator';

export interface CertificateCopy {
  id: string;
  kind: ShareCertificateKind;
  titleZh: string;
  titleEn: string;
  coverHeadlineZh: string;
  coverHeadlineEn: string;
  sealZh: string;
  sealEn: string;
  bodyZh: string;
  bodyEn: string;
  tags: string;
  sortOrder: number;
}

export interface ShareCertificateImage {
  id: string;
  kinds: ShareCertificateKind[];
  imageUrl: string;
  colorMode: 'light' | 'dark';
  socialTemplateId: string;
  sortOrder: number;
}

export interface SocialMediaTemplateConfig {
  templateId: string;
  name: string;
  platform: string;
  layout: string;
  background: string;
  styleJson: string;
  sortOrder: number;
}

export interface ShareClientConfig {
  certificates: CertificateCopy[];
  certificateImages: ShareCertificateImage[];
  socialTemplates: SocialMediaTemplateConfig[];
}

export interface FocusShareVars {
  focus_mins: number;
  focus_hours: number;
  streak_days: number;
  task_title: string;
  partner_name: string;
}

export interface CertificateDisplayResult {
  title: string;
  body: string;
  seal: string;
}

export interface PosterCoverSplit {
  primary: string;
  secondary: string;
}

export function emptyCertificateDisplay(): CertificateDisplayResult {
  const empty: CertificateDisplayResult = {
    title: '',
    body: '',
    seal: '',
  };
  return empty;
}

export function emptyShareClientConfig(): ShareClientConfig {
  const config: ShareClientConfig = {
    certificates: [],
    certificateImages: [],
    socialTemplates: [],
  };
  return config;
}

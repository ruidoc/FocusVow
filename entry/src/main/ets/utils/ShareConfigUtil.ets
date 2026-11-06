import {
  CertificateCopy,
  CertificateDisplayResult,
  FocusShareVars,
  PosterCoverSplit,
  ShareCertificateImage,
  ShareCertificateKind,
  ShareClientConfig,
  SocialMediaTemplateConfig,
} from '../models/ShareConfigModel';

const CERTIFICATE_KINDS: ShareCertificateKind[] = [
  'solo_honor',
  'solo_violator',
  'duo_honor',
  'victim',
  'violator',
];

function asRecord(raw: Object | undefined): Record<string, Object> | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  return raw as Record<string, Object>;
}

function asString(value: Object | undefined, fallback: string = ''): string {
  if (typeof value === 'string') {
    return value;
  }
  if (value === undefined || value === null) {
    return fallback;
  }
  return String(value);
}

function asNumber(value: Object | undefined, fallback: number = 0): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function isCertificateKind(value: string): boolean {
  return CERTIFICATE_KINDS.indexOf(value as ShareCertificateKind) >= 0;
}

function mapCertificate(raw: Record<string, Object>): CertificateCopy | null {
  const kind = asString(raw['kind']);
  if (!isCertificateKind(kind)) {
    return null;
  }
  const id = asString(raw['id']).trim();
  if (id.length === 0) {
    return null;
  }
  return {
    id,
    kind: kind as ShareCertificateKind,
    titleZh: asString(raw['title_zh']).trim(),
    titleEn: asString(raw['title_en']).trim(),
    coverHeadlineZh: asString(raw['cover_headline_zh']).trim(),
    coverHeadlineEn: asString(raw['cover_headline_en']).trim(),
    sealZh: asString(raw['seal_zh']).trim(),
    sealEn: asString(raw['seal_en']).trim(),
    bodyZh: asString(raw['body_zh']).trim(),
    bodyEn: asString(raw['body_en']).trim(),
    tags: asString(raw['tags']).trim(),
    sortOrder: asNumber(raw['sort_order'], 0),
  };
}

function mapCertificateImage(raw: Record<string, Object>): ShareCertificateImage | null {
  const id = asString(raw['id']).trim();
  const imageUrl = asString(raw['image_url']).trim();
  const socialTemplateId = asString(raw['social_template_id']).trim();
  if (id.length === 0 || (imageUrl.length === 0 && socialTemplateId.length === 0)) {
    return null;
  }
  const kindsRaw = asString(raw['kinds'] || raw['kind']);
  const kinds: ShareCertificateKind[] = [];
  const parts = kindsRaw.split(',');
  for (let i = 0; i < parts.length; i++) {
    const item = parts[i].trim();
    if (isCertificateKind(item)) {
      kinds.push(item as ShareCertificateKind);
    }
  }
  if (kinds.length === 0) {
    return null;
  }
  return {
    id,
    kinds,
    imageUrl,
    colorMode: asString(raw['color_mode']) === 'dark' ? 'dark' : 'light',
    socialTemplateId,
    sortOrder: asNumber(raw['sort_order'], 0),
  };
}

function mapSocialTemplate(raw: Record<string, Object>): SocialMediaTemplateConfig | null {
  const templateId = asString(raw['template_id'] || raw['templateId']).trim();
  if (templateId.length === 0) {
    return null;
  }
  return {
    templateId,
    name: asString(raw['name']).trim(),
    platform: asString(raw['platform']).trim(),
    layout: asString(raw['layout']).trim(),
    background: asString(raw['background']).trim(),
    styleJson: asString(raw['style_json'] || raw['styleJson']).trim(),
    sortOrder: asNumber(raw['sort_order'], 0),
  };
}

function readObjectArray(raw: Object | undefined): Object[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw as Object[];
}

export function parseShareConfigFromResponse(data: Object | undefined): ShareClientConfig {
  const record = asRecord(data);
  const certificates: CertificateCopy[] = [];
  const certificateImages: ShareCertificateImage[] = [];
  const socialTemplates: SocialMediaTemplateConfig[] = [];

  const certRows = readObjectArray(record?.['certificates']);
  for (let i = 0; i < certRows.length; i++) {
    const row = asRecord(certRows[i]);
    if (!row) {
      continue;
    }
    const mapped = mapCertificate(row);
    if (mapped) {
      certificates.push(mapped);
    }
  }

  const imageRows = readObjectArray(record?.['certificate_images']);
  for (let j = 0; j < imageRows.length; j++) {
    const row = asRecord(imageRows[j]);
    if (!row) {
      continue;
    }
    const mapped = mapCertificateImage(row);
    if (mapped) {
      certificateImages.push(mapped);
    }
  }

  const templateRows = readObjectArray(record?.['social_templates']);
  for (let k = 0; k < templateRows.length; k++) {
    const row = asRecord(templateRows[k]);
    if (!row) {
      continue;
    }
    const mapped = mapSocialTemplate(row);
    if (mapped) {
      socialTemplates.push(mapped);
    }
  }

  certificates.sort((a, b) => a.sortOrder - b.sortOrder);
  certificateImages.sort((a, b) => a.sortOrder - b.sortOrder);
  socialTemplates.sort((a, b) => a.sortOrder - b.sortOrder);

  return { certificates, certificateImages, socialTemplates };
}

export function certificateCopiesForKind(
  config: ShareClientConfig,
  kind: ShareCertificateKind,
): CertificateCopy[] {
  const rows: CertificateCopy[] = [];
  for (let i = 0; i < config.certificates.length; i++) {
    if (config.certificates[i].kind === kind) {
      rows.push(config.certificates[i]);
    }
  }
  return rows;
}

export function certificateImagesForKind(
  config: ShareClientConfig,
  kind: ShareCertificateKind,
): ShareCertificateImage[] {
  const rows: ShareCertificateImage[] = [];
  for (let i = 0; i < config.certificateImages.length; i++) {
    const item = config.certificateImages[i];
    if (item.kinds.indexOf(kind) >= 0) {
      rows.push(item);
    }
  }
  return rows;
}

export function findSocialTemplate(
  templates: SocialMediaTemplateConfig[],
  templateId: string,
): SocialMediaTemplateConfig | null {
  const id = templateId.trim();
  if (id.length === 0) {
    return null;
  }
  for (let i = 0; i < templates.length; i++) {
    if (templates[i].templateId === id) {
      return templates[i];
    }
  }
  return null;
}

function fillTemplate(template: string, vars: Record<string, string | number>): string {
  return template
    .replace(/\{(\w+)\}/g, (_all: string, key: string) => {
      const value = vars[key];
      if (value === undefined || value === null) {
        return '';
      }
      return String(value);
    })
    .trim();
}

function shareVarsRecord(vars: FocusShareVars, tags: string = ''): Record<string, string | number> {
  const out: Record<string, string | number> = {};
  out['focus_mins'] = vars.focus_mins;
  out['focus_hours'] = vars.focus_hours;
  out['streak_days'] = vars.streak_days;
  out['task_title'] = vars.task_title;
  out['partner_name'] = vars.partner_name;
  if (tags.length > 0) {
    out['tags'] = tags;
  }
  return out;
}

export function focusShareVars(focusMinutes: number): FocusShareVars {
  const minutes = Math.max(0, Math.round(focusMinutes));
  const hours = minutes >= 60 ? Math.max(1, Math.round(minutes / 60)) : 0;
  const vars: FocusShareVars = {
    focus_mins: minutes,
    focus_hours: hours,
    streak_days: 0,
    task_title: '',
    partner_name: '',
  };
  return vars;
}

export function certificateDisplay(
  copy: CertificateCopy,
  vars: FocusShareVars,
): CertificateDisplayResult {
  const title = copy.titleZh.length > 0 ? copy.titleZh : copy.titleEn;
  const bodyRaw = copy.bodyZh.length > 0 ? copy.bodyZh : copy.bodyEn;
  const seal = copy.sealZh.length > 0 ? copy.sealZh : copy.sealEn;
  const result: CertificateDisplayResult = {
    title,
    body: fillTemplate(bodyRaw, shareVarsRecord(vars, copy.tags)),
    seal,
  };
  return result;
}

function certificateCoverHeadlineFallback(body: string, fallbackTitle: string = ''): string {
  const stripInlineTags = (line: string): string => {
    const hash = line.indexOf('#');
    return (hash >= 0 ? line.slice(0, hash) : line).trim();
  };
  const raw = body.trim();
  if (raw.length === 0) {
    return stripInlineTags(fallbackTitle);
  }
  const lines = raw.split('\n');
  const filtered: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = stripInlineTags(lines[i]);
    if (line.length > 0) {
      filtered.push(line);
    }
  }
  if (filtered.length > 0) {
    return filtered[0];
  }
  return stripInlineTags(fallbackTitle);
}

export function certificatePosterCoverLine(
  copy: CertificateCopy | null,
  vars: FocusShareVars,
  filledBody: string,
  filledTitle: string,
): string {
  if (copy) {
    const raw =
      copy.coverHeadlineZh.length > 0 ? copy.coverHeadlineZh : copy.coverHeadlineEn;
    const line = fillTemplate(raw.trim(), shareVarsRecord(vars, copy.tags));
    if (line.length > 0) {
      return line;
    }
  }
  return certificateCoverHeadlineFallback(filledBody, filledTitle);
}

export function splitCertificatePosterCover(coverText: string): PosterCoverSplit {
  const lines = coverText.split('\n');
  const trimmed: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line.length > 0) {
      trimmed.push(line);
    }
  }
  const split: PosterCoverSplit = {
    primary: trimmed.length > 0 ? trimmed[0] : '',
    secondary: trimmed.length > 1 ? trimmed[1] : '',
  };
  return split;
}

export function limitPosterTagsLine(tags: string, max: number = 2): string {
  const raw = tags.trim();
  if (raw.length === 0 || max <= 0) {
    return '';
  }
  const hashTags = raw.match(/#[^\s#]+/g);
  if (hashTags && hashTags.length > 0) {
    return hashTags.slice(0, max).join(' ');
  }
  const parts = raw.split(/\s+/);
  const filtered: string[] = [];
  for (let i = 0; i < parts.length; i++) {
    if (parts[i].length > 0) {
      filtered.push(parts[i]);
    }
  }
  return filtered.slice(0, max).join(' ');
}

export function buildClipboardFromCertificate(
  copy: CertificateCopy,
  vars: FocusShareVars,
): string {
  const display = certificateDisplay(copy, vars);
  const tags = copy.tags;
  if (display.body.length === 0) {
    return tags;
  }
  if (tags.length > 0 && display.body.indexOf(tags) < 0) {
    return `${display.body}\n${tags}`;
  }
  return display.body;
}

export function pickRandomIndex(len: number, avoidIndex: number = -1): number {
  if (len <= 0) {
    return 0;
  }
  if (len === 1) {
    return 0;
  }
  let next = Math.floor(Math.random() * len);
  if (avoidIndex >= 0 && next === avoidIndex) {
    next = (next + 1 + Math.floor(Math.random() * (len - 1))) % len;
  }
  return next;
}

import { formatChineseDateTime } from '../common/DateTimeFormatUtil';
import {
  CERTIFICATE_AD_SLOGAN,
  CERTIFICATE_FOOTER_BRAND,
  HonorCertificateData,
  ShameCertificateData,
  ShameCertificateVariant
} from '../models/CertificateModel';
import { ActiveLockState } from '../models/ActiveLockModel';
import { DuoShameRecord, DuoTimelineRecord, getDuoPartnerDisplayName } from '../models/DuoModel';
import { UserInfo } from '../models/UserModel';
import { resolveCountedActualMin } from '../utils/FocusValidity';

function formatIsoFromMs(ms: number): string {
  const date = new Date(ms);
  const year = date.getFullYear();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  const hour = date.getHours().toString().padStart(2, '0');
  const minute = date.getMinutes().toString().padStart(2, '0');
  const second = date.getSeconds().toString().padStart(2, '0');
  return `${year}-${month}-${day} ${hour}:${minute}:${second}`;
}

function getTotalMinutesFromLock(lock: ActiveLockState): number {
  if (lock.endAt > lock.startedAt) {
    return Math.max(1, Math.round((lock.endAt - lock.startedAt) / 60000));
  }
  return 25;
}

function getElapsedMinutesFromLock(lock: ActiveLockState, endedAt: number): number {
  if (lock.startedAt <= 0) {
    return 1;
  }
  const counted = resolveCountedActualMin(lock.startedAt, endedAt);
  return counted > 0 ? counted : 1;
}

function getLockTitle(lock: ActiveLockState): string {
  if (lock.title.trim().length > 0) {
    return lock.title.trim();
  }
  return '专注契约';
}

function buildShameRecordFromLock(
  lock: ActiveLockState,
  endedAt: number,
  breachRole: string,
  failedReason: string
): DuoShameRecord {
  const totalMin = getTotalMinutesFromLock(lock);
  const actualMin = Math.min(getElapsedMinutesFromLock(lock, endedAt), totalMin);
  const completedAt = formatIsoFromMs(endedAt);
  return {
    id: '',
    duo_session_id: lock.duoSessionId,
    title: getLockTitle(lock),
    session_type: lock.kind,
    participation_mode: lock.participationMode === 'duo' ? 'duo' : 'solo',
    total_min: totalMin,
    actual_min: actualMin,
    completed_at: completedAt,
    breach_role: breachRole,
    failed_reason: failedReason,
    partner: lock.partnerNickname.length > 0
      ? { id: '', nickname: lock.partnerNickname }
      : null
  };
}

function getDisplayName(user: UserInfo): string {
  if (user.username.trim().length > 0) {
    return user.username.trim();
  }
  if (user.phone.trim().length > 0) {
    return user.phone.trim();
  }
  return '无名用户';
}

function getCounterpartNameFromRecord(record: DuoTimelineRecord): string {
  return getDuoPartnerDisplayName(record.partner);
}

function getCounterpartNameFromShameRecord(record: DuoShameRecord): string {
  return getDuoPartnerDisplayName(record.partner);
}

function getTimelineModeLabel(record: DuoTimelineRecord): string {
  if (record.participation_mode === 'duo') {
    return '1v1 连坐契约';
  }
  return '单人专注契约';
}

function getShameModeLabel(record: DuoShameRecord): string {
  if (record.participation_mode === 'duo') {
    return '1v1 连坐契约';
  }
  return '单人专注契约';
}

function resolveShameVariant(record: DuoShameRecord): ShameCertificateVariant {
  if (record.participation_mode !== 'duo') {
    return 'solo';
  }
  return record.breach_role === 'violator' ? 'violator' : 'victim';
}

function buildSoloHonorCardTitle(): string {
  return '履约证书';
}

function buildDuoHonorCardTitle(): string {
  return '双人履约证书';
}

function buildSoloHonorResultNarrative(record: DuoTimelineRecord): string {
  return `完成「${record.title}」${record.actual_min} 分钟，契约履行完毕。`;
}

function buildDuoHonorResultNarrative(record: DuoTimelineRecord): string {
  return `两人共同完成 ${record.actual_min} 分钟，连坐契约履行完毕。`;
}

function buildSoloShameCardTitle(): string {
  return '违约记录';
}

function buildViolatorShameCardTitle(): string {
  return '连坐违约证书';
}

function buildVictimShameCardTitle(): string {
  return '连坐中止证书';
}

function buildSoloShameResultNarrative(record: DuoShameRecord): string {
  return `「${record.title}」第 ${record.actual_min} 分钟提前退出，本次契约未完成。`;
}

function buildViolatorShameResultNarrative(record: DuoShameRecord): string {
  return `于第 ${record.actual_min} 分钟退出，搭子因连坐规则同步终止。`;
}

function buildVictimShameResultNarrative(record: DuoShameRecord, counterpartName: string): string {
  return `搭子 ${counterpartName} 于第 ${record.actual_min} 分钟退出，我已完成 ${record.actual_min} / ${record.total_min} 分钟，本场因连坐规则终止。`;
}

export function buildHonorCertificateData(
  record: DuoTimelineRecord,
  fallbackDate: string,
  user: UserInfo,
  _successRate?: number
): HonorCertificateData {
  const completedRaw = record.completed_at ?? fallbackDate;
  const partnerName = record.participation_mode === 'duo' ? getCounterpartNameFromRecord(record) : '';
  const isDuo = partnerName.length > 0;
  return {
    userName: getDisplayName(user),
    partnerName,
    cardTitle: isDuo ? buildDuoHonorCardTitle() : buildSoloHonorCardTitle(),
    modeLabel: getTimelineModeLabel(record),
    contractTitle: record.title,
    durationMinutes: record.actual_min,
    resultNarrative: isDuo
      ? buildDuoHonorResultNarrative(record)
      : buildSoloHonorResultNarrative(record),
    footerBrand: CERTIFICATE_FOOTER_BRAND,
    footerDatetime: formatChineseDateTime(completedRaw, fallbackDate),
    adSlogan: CERTIFICATE_AD_SLOGAN
  };
}

export function buildShameCertificateData(
  record: DuoShameRecord,
  fallbackDate: string,
  user: UserInfo
): ShameCertificateData {
  const completedRaw = record.completed_at ?? fallbackDate;
  const variant = resolveShameVariant(record);
  const counterpartName = record.participation_mode === 'duo'
    ? getCounterpartNameFromShameRecord(record)
    : '';
  let cardTitle = buildSoloShameCardTitle();
  let roleLabel = '';
  let resultNarrative = buildSoloShameResultNarrative(record);
  if (variant === 'victim') {
    cardTitle = buildVictimShameCardTitle();
    roleLabel = '守约方';
    resultNarrative = buildVictimShameResultNarrative(record, counterpartName);
  } else if (variant === 'violator') {
    cardTitle = buildViolatorShameCardTitle();
    roleLabel = '违约方';
    resultNarrative = buildViolatorShameResultNarrative(record);
  }
  return {
    userName: getDisplayName(user),
    counterpartName,
    cardTitle,
    roleLabel,
    modeLabel: getShameModeLabel(record),
    contractTitle: record.title,
    totalMinutes: record.total_min,
    actualMinutes: record.actual_min,
    resultNarrative,
    footerBrand: CERTIFICATE_FOOTER_BRAND,
    footerDatetime: formatChineseDateTime(completedRaw, fallbackDate),
    adSlogan: CERTIFICATE_AD_SLOGAN,
    shameVariant: variant
  };
}

export function buildHonorCertificateFromLock(
  lock: ActiveLockState,
  user: UserInfo,
  endedAt: number = Date.now()
): HonorCertificateData {
  const totalMin = getTotalMinutesFromLock(lock);
  const elapsedMin = getElapsedMinutesFromLock(lock, endedAt);
  const durationMinutes = lock.endAt > 0 && endedAt >= lock.endAt - 5000 ? totalMin : Math.min(elapsedMin, totalMin);
  const completedAt = formatIsoFromMs(endedAt);
  const fallbackDate = completedAt.split(' ')[0];
  const record: DuoTimelineRecord = {
    id: '',
    duo_session_id: lock.duoSessionId,
    title: getLockTitle(lock),
    session_type: lock.kind,
    participation_mode: lock.participationMode === 'duo' ? 'duo' : 'solo',
    total_min: totalMin,
    actual_min: durationMinutes,
    completed_at: completedAt,
    partner: lock.partnerNickname.length > 0
      ? { id: '', nickname: lock.partnerNickname }
      : null
  };
  return buildHonorCertificateData(record, fallbackDate, user);
}

export function buildShameCertificateFromLock(
  lock: ActiveLockState,
  user: UserInfo,
  endedAt: number = Date.now(),
  breachRole: string = 'violator',
  failedReason: string = 'tear'
): ShameCertificateData {
  const record = buildShameRecordFromLock(lock, endedAt, breachRole, failedReason);
  const fallbackDate = formatIsoFromMs(endedAt).split(' ')[0];
  return buildShameCertificateData(record, fallbackDate, user);
}

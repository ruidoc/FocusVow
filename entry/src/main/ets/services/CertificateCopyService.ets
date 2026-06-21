import {
  HonorCertificateData,
  ShameCertificateData
} from '../models/CertificateModel';
import { ActiveLockState } from '../models/ActiveLockModel';
import { DuoShameRecord, DuoTimelineRecord } from '../models/DuoModel';
import { UserInfo } from '../models/UserModel';

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
  return Math.max(1, Math.round((endedAt - lock.startedAt) / 60000));
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
    failed_reason: failedReason
  };
}

function formatChineseDate(raw: string, fallbackDate: string): string {
  const source = raw.length > 0 ? raw : fallbackDate;
  const normalized = source.replace('T', ' ');
  const datePart = normalized.split(' ')[0];
  const segments = datePart.split('-');
  if (segments.length < 3) {
    return datePart;
  }
  const month = segments[1].padStart(2, '0');
  const day = segments[2].padStart(2, '0');
  return `${segments[0]}年${month}月${day}日`;
}

function formatChineseDateTime(raw: string, fallbackDate: string): string {
  const source = raw.length > 0 ? raw : fallbackDate;
  const normalized = source.replace('T', ' ');
  const parts = normalized.split(' ');
  const dateLabel = formatChineseDate(parts[0], fallbackDate);
  if (parts.length < 2) {
    return dateLabel;
  }
  const timePart = parts[1];
  const trimmedTime = timePart.length >= 5 ? timePart.substring(0, 5) : timePart;
  return `${dateLabel} ${trimmedTime}`;
}

function formatIsoDate(raw: string, fallbackDate: string): string {
  const source = raw.length > 0 ? raw : fallbackDate;
  const normalized = source.replace('T', ' ');
  return normalized.split(' ')[0];
}

function getDisplayName(user: UserInfo): string {
  if (user.username.trim().length > 0) {
    return user.username.trim();
  }
  if (user.phone.trim().length > 0) {
    return user.phone.trim();
  }
  return '无名考生';
}

function getQrContent(user: UserInfo): string {
  if (user.invite_code.trim().length > 0) {
    return `FocusVow专注契约 | 邀请码 ${user.invite_code.trim()}`;
  }
  return 'FocusVow专注契约';
}

function getTimelineModeLabel(record: DuoTimelineRecord): string {
  if (record.participation_mode === 'duo') {
    return '1v1 连坐契约';
  }
  return '单人闭关契约';
}

function getShameModeLabel(record: DuoShameRecord): string {
  if (record.participation_mode === 'duo') {
    return '1v1 连坐契约';
  }
  return '单人闭关契约';
}

function getShameReasonLabel(record: DuoShameRecord): string {
  const reason = record.failed_reason.trim().toLowerCase();
  if (reason.length === 0) {
    return record.breach_role === 'violator' ? '强杀断开' : '连带失败';
  }
  if (reason === 'tear' || reason === 'breach' || reason === 'manual_stop') {
    return '强杀断开';
  }
  if (reason === 'partner_breach') {
    return '被搭子连坐';
  }
  if (reason === 'timeout') {
    return '超时失守';
  }
  return record.failed_reason;
}

function buildHonorBehaviorVerdict(successRate?: number): string {
  if (successRate !== undefined && successRate > 0) {
    const percentile = Math.min(99, Math.max(1, Math.round(successRate)));
    return `顶住诱惑，物理隔离手机，此战胜率击败全球 ${percentile}% 考研党。`;
  }
  return '顶住诱惑，物理隔离手机，成功守完全程。';
}

function buildShameBehaviorVerdict(record: DuoShameRecord): string {
  if (record.participation_mode === 'duo' && record.breach_role !== 'violator') {
    return '被搭子连坐波及，本局清白记录一并作废。';
  }
  const reason = getShameReasonLabel(record);
  if (reason === '被搭子连坐') {
    return '搭子先撕毁契约，你被连坐记入耻辱柱。';
  }
  return '临阵脱逃，主动为同专业竞争对手腾出一个录取名额。';
}

function buildShameBreachNarrative(record: DuoShameRecord): string {
  const modeLabel = getShameModeLabel(record);
  if (record.participation_mode === 'duo' && record.breach_role !== 'violator') {
    return `在「${record.title}」${modeLabel}期间，搭子先毁约，你于第 ${record.actual_min} 分钟被连带判定失败。`;
  }
  return `在「${record.title}」${modeLabel}期间，因意志力极其薄弱，于第 ${record.actual_min} 分钟单方面强杀 App 撕毁生死契约。`;
}

export function buildHonorCertificateData(
  record: DuoTimelineRecord,
  fallbackDate: string,
  user: UserInfo,
  successRate?: number
): HonorCertificateData {
  const completedRaw = record.completed_at ?? fallbackDate;
  return {
    userName: getDisplayName(user),
    dateLabel: formatChineseDate(completedRaw, fallbackDate),
    contractTitle: record.title,
    durationMinutes: record.actual_min,
    modeLabel: getTimelineModeLabel(record),
    behaviorVerdict: buildHonorBehaviorVerdict(successRate),
    closingRemark: '特发此证，以资鼓励。距离成功上岸，再近一步。',
    issuedAt: formatIsoDate(completedRaw, fallbackDate),
    qrContent: getQrContent(user),
    footerSlogan: '扫码加入铁血闭关契约 | FocusVow 专注契约'
  };
}

export function buildShameCertificateData(
  record: DuoShameRecord,
  fallbackDate: string,
  user: UserInfo
): ShameCertificateData {
  const completedRaw = record.completed_at ?? fallbackDate;
  return {
    userName: getDisplayName(user),
    datetimeLabel: formatChineseDateTime(completedRaw, fallbackDate),
    contractTitle: record.title,
    totalMinutes: record.total_min,
    actualMinutes: record.actual_min,
    modeLabel: getShameModeLabel(record),
    breachNarrative: buildShameBreachNarrative(record),
    behaviorVerdict: buildShameBehaviorVerdict(record),
    punishmentLabel: '[ 2027年考研二战留级体验卡 ] 现已即时生效。',
    qrContent: getQrContent(user),
    footerSlogan: '围观此人下一次赌局 | 拒绝当鸽子下载 FocusVow'
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
    completed_at: completedAt
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

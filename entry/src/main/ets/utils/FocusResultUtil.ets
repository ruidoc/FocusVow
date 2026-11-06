import { ActiveLockState } from '../models/ActiveLockModel';
import { CertificatePendingSnapshot } from '../services/CertificatePendingService';
import { ShareCertificateKind } from '../models/ShareConfigModel';

export const FOCUS_RESULT_COVER_SNAPSHOT_ID: string = 'focusResultCoverSnapshot';
export const FOCUS_RESULT_CERT_SNAPSHOT_ID: string = 'focusResultCertSnapshot';

export function resolveShareKind(
  pending: CertificatePendingSnapshot,
): ShareCertificateKind {
  const lock = pending.lock;
  const isDuo = lock.participationMode === 'duo' || lock.duoSessionId.trim().length > 0;
  if (pending.kind === 'honor') {
    return isDuo ? 'duo_honor' : 'solo_honor';
  }
  if (!isDuo) {
    return 'solo_violator';
  }
  return pending.breachRole === 'victim' ? 'victim' : 'violator';
}

export function resolveFocusResultOutcome(pending: CertificatePendingSnapshot): 'success' | 'failed' {
  return pending.kind === 'honor' ? 'success' : 'failed';
}

export function resolveFocusMinutes(lock: ActiveLockState, endedAt: number): number {
  if (lock.startedAt <= 0) {
    return 0;
  }
  const seconds = Math.max(0, Math.floor((endedAt - lock.startedAt) / 1000));
  return Math.floor(seconds / 60);
}

export function focusResultPageTitle(shareKind: ShareCertificateKind): string {
  if (shareKind === 'duo_honor') {
    return '双人契约履行完成';
  }
  if (shareKind === 'solo_honor') {
    return '契约履行完成';
  }
  if (shareKind === 'victim') {
    return '被连坐撕毁';
  }
  if (shareKind === 'violator') {
    return '违约耻辱证已生成';
  }
  return '专注未守完全程';
}

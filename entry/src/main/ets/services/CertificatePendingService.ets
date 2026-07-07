import { CertificateKind, HonorCertificateData, ShameCertificateData } from '../models/CertificateModel';
import { ActiveLockState, normalizeActiveLockState } from '../models/ActiveLockModel';
import { AppTheme } from '../constants/Theme';
import {
  buildHonorCertificateFromLock,
  buildShameCertificateFromLock
} from './CertificateCopyService';
import {
  openHonorCertificatePreview,
  openShameCertificatePreview
} from './CertificateNavigationService';
import { StoreKeys } from '../stores/StoreKeys';
import { UserStore } from '../stores/UserStore';
import { bootstrapStores } from '../stores/StoreBootstrap';

bootstrapStores();

export interface CertificatePendingSnapshot {
  kind: CertificateKind;
  lock: ActiveLockState;
  endedAt: number;
  breachRole: string;
  failedReason: string;
}

let lastPresentedKey: string = '';

function syncStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

function buildPendingKey(pending: CertificatePendingSnapshot): string {
  return `${pending.kind}-${pending.endedAt}-${pending.lock.startedAt}-${pending.lock.title}`;
}

export function queueHonorCertificate(lock: ActiveLockState, endedAt: number = Date.now()): void {
  const snapshot: CertificatePendingSnapshot = {
    kind: 'honor',
    lock: normalizeActiveLockState(lock),
    endedAt,
    breachRole: '',
    failedReason: ''
  };
  syncStorageValue<CertificatePendingSnapshot>(StoreKeys.CertificatePending, snapshot);
}

export function queueShameCertificate(
  lock: ActiveLockState,
  endedAt: number = Date.now(),
  breachRole: string = 'violator',
  failedReason: string = 'tear'
): void {
  const snapshot: CertificatePendingSnapshot = {
    kind: 'shame',
    lock: normalizeActiveLockState(lock),
    endedAt,
    breachRole,
    failedReason
  };
  syncStorageValue<CertificatePendingSnapshot>(StoreKeys.CertificatePending, snapshot);
}

export function clearPendingCertificate(): void {
  syncStorageValue<CertificatePendingSnapshot | null>(StoreKeys.CertificatePending, null);
}

export function getPendingCertificate(): CertificatePendingSnapshot | null {
  const pending = AppStorage.get<CertificatePendingSnapshot | null>(StoreKeys.CertificatePending);
  if (pending === null || pending === undefined) {
    return null;
  }
  return pending;
}

function buildHonorDialogMessage(data: HonorCertificateData): string {
  if (data.partnerName.length > 0) {
    return `你和 ${data.partnerName} 已完成「${data.contractTitle}」，${data.cardTitle}已生成。可保存到相册或转发给搭子。`;
  }
  return `「${data.contractTitle}」已履约完成，${data.cardTitle}已生成。可保存到相册。`;
}

function buildShameDialogMessage(data: ShameCertificateData): string {
  if (data.shameVariant === 'victim') {
    return `「${data.contractTitle}」因 ${data.counterpartName} 退出而中止，${data.cardTitle}已生成。可保存到相册。`;
  }
  if (data.shameVariant === 'violator' && data.counterpartName.length > 0) {
    return `「${data.contractTitle}」本次未守完全程，因连坐规则影响了 ${data.counterpartName}。${data.cardTitle}已生成。`;
  }
  return `「${data.contractTitle}」本次未守完全程，${data.cardTitle}已生成。可保存到相册。`;
}

export function tryPresentCertificateGuide(uiContext: UIContext): void {
  const pending = getPendingCertificate();
  if (!pending) {
    return;
  }

  const pendingKey = buildPendingKey(pending);
  if (lastPresentedKey === pendingKey) {
    return;
  }
  lastPresentedKey = pendingKey;

  const user = UserStore.getUserInfo();
  if (pending.kind === 'honor') {
    const data = buildHonorCertificateFromLock(pending.lock, user, pending.endedAt);
    const isDuo = data.partnerName.length > 0;
    uiContext.showAlertDialog({
      title: isDuo ? '双人契约达成' : '契约履行完成',
      message: buildHonorDialogMessage(data),
      autoCancel: false,
      primaryButton: {
        value: isDuo ? '查看双人履约证' : '查看荣誉证',
        fontColor: AppTheme.colors.primary,
        action: () => {
          clearPendingCertificate();
          openHonorCertificatePreview(data);
        }
      },
      secondaryButton: {
        value: '稍后再说',
        action: () => {
          clearPendingCertificate();
        }
      }
    });
    return;
  }

  const data = buildShameCertificateFromLock(
    pending.lock,
    user,
    pending.endedAt,
    pending.breachRole,
    pending.failedReason
  );
  const dialogTitle = data.shameVariant === 'victim'
    ? '连坐中止 · 耻辱证已生成'
    : '违约耻辱证已生成';
  uiContext.showAlertDialog({
    title: dialogTitle,
    message: buildShameDialogMessage(data),
    autoCancel: false,
    primaryButton: {
      value: '查看耻辱证',
      fontColor: AppTheme.colors.danger,
      action: () => {
        clearPendingCertificate();
        openShameCertificatePreview(data);
      }
    },
    secondaryButton: {
      value: '稍后再说',
      action: () => {
        clearPendingCertificate();
      }
    }
  });
}

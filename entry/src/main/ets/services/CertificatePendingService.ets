import { router } from "@kit.ArkUI";
import { CertificateKind } from "../models/CertificateModel";
import { ActiveLockState, normalizeActiveLockState } from "../models/ActiveLockModel";
import { PageRoutes } from "../router/PageRoutes";
import { StoreKeys } from "../stores/StoreKeys";
import { bootstrapStores } from "../stores/StoreBootstrap";

bootstrapStores();

export interface CertificatePendingSnapshot {
  kind: CertificateKind;
  lock: ActiveLockState;
  endedAt: number;
  breachRole: string;
  failedReason: string;
}

let lastPresentedKey: string = "";

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
    kind: "honor",
    lock: normalizeActiveLockState(lock),
    endedAt,
    breachRole: "",
    failedReason: "",
  };
  syncStorageValue<CertificatePendingSnapshot>(StoreKeys.CertificatePending, snapshot);
}

export function queueShameCertificate(
  lock: ActiveLockState,
  endedAt: number = Date.now(),
  breachRole: string = "violator",
  failedReason: string = "tear",
): void {
  const snapshot: CertificatePendingSnapshot = {
    kind: "shame",
    lock: normalizeActiveLockState(lock),
    endedAt,
    breachRole,
    failedReason,
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

export function tryPresentCertificateGuide(uiContext: UIContext): boolean {
  void uiContext;
  const pending = getPendingCertificate();
  if (!pending) {
    return false;
  }

  const pendingKey = buildPendingKey(pending);
  if (lastPresentedKey === pendingKey) {
    return false;
  }
  lastPresentedKey = pendingKey;
  router.pushUrl({ url: PageRoutes.FocusResult }).catch((error: Error) => {
    console.warn(`[Certificate] open result failed: ${String(error)}`);
    lastPresentedKey = "";
  });
  return true;
}

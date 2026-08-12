import { common } from '@kit.AbilityKit';
import { AppContextHolder } from '../common/AppContextHolder';
import {
  readStoredString,
  removeStoredKey,
  writeStoredString
} from '../services/PreferencesService';

const PENDING_REFERRAL_KEY: string = 'pending_referral_code';

export function normalizeReferralCode(code?: string | null): string {
  return String(code ?? '')
    .trim()
    .replace(/\s+/g, '');
}

function resolveContext(context?: common.Context | null): common.Context | null {
  if (context) {
    return context;
  }
  return AppContextHolder.get();
}

export function savePendingReferralCode(
  code?: string | null,
  context?: common.Context | null
): void {
  const normalized = normalizeReferralCode(code);
  if (normalized.length === 0) {
    return;
  }
  const ctx = resolveContext(context);
  if (!ctx) {
    return;
  }
  writeStoredString(ctx, PENDING_REFERRAL_KEY, normalized);
}

export function getPendingReferralCode(context?: common.Context | null): string {
  const ctx = resolveContext(context);
  if (!ctx) {
    return '';
  }
  return normalizeReferralCode(readStoredString(ctx, PENDING_REFERRAL_KEY, ''));
}

export function clearPendingReferralCode(context?: common.Context | null): void {
  const ctx = resolveContext(context);
  if (!ctx) {
    return;
  }
  removeStoredKey(ctx, PENDING_REFERRAL_KEY);
}

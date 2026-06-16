import { common } from '@kit.AbilityKit';
import { FocusSyncPending } from '../models/FocusSyncModel';
import { readStoredString, removeStoredKey, writeStoredString } from './PreferencesService';

const FOCUS_SYNC_PENDING_KEY: string = 'focus.sync.pending';

export function loadFocusSyncPending(context: common.Context): FocusSyncPending | null {
  const rawValue = readStoredString(context, FOCUS_SYNC_PENDING_KEY, '');
  if (rawValue.length === 0) {
    return null;
  }

  try {
    return JSON.parse(rawValue) as FocusSyncPending;
  } catch {
    console.error('Failed to parse focus sync pending.');
    return null;
  }
}

export function saveFocusSyncPending(
  context: common.Context,
  pending: FocusSyncPending
): boolean {
  return writeStoredString(context, FOCUS_SYNC_PENDING_KEY, JSON.stringify(pending));
}

export function clearFocusSyncPending(context: common.Context): boolean {
  return removeStoredKey(context, FOCUS_SYNC_PENDING_KEY);
}

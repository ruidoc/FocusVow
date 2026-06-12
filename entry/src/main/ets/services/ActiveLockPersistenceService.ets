import { common } from '@kit.AbilityKit';
import { ActiveLockState, normalizeActiveLockState } from '../models/ActiveLockModel';
import { readStoredString, writeStoredString, removeStoredKey } from './PreferencesService';

const ACTIVE_LOCK_STATE_KEY: string = 'active.lock.state';
const QUICK_FOCUS_DURATION_KEY: string = 'quickFocus.durationMinutes';

export function loadPersistedActiveLockState(context: common.Context): ActiveLockState | null {
  const rawValue = readStoredString(context, ACTIVE_LOCK_STATE_KEY, '');
  if (rawValue.length === 0) {
    return null;
  }

  try {
    return normalizeActiveLockState(JSON.parse(rawValue) as Partial<ActiveLockState>);
  } catch {
    console.error('Failed to parse persisted active lock state.');
    return null;
  }
}

export function savePersistedActiveLockState(
  context: common.Context,
  state: ActiveLockState
): boolean {
  return writeStoredString(context, ACTIVE_LOCK_STATE_KEY, JSON.stringify(state));
}

export function clearPersistedActiveLockState(context: common.Context): boolean {
  return removeStoredKey(context, ACTIVE_LOCK_STATE_KEY);
}

export function loadPersistedQuickFocusDurationMinutes(context: common.Context): number {
  const rawValue = readStoredString(context, QUICK_FOCUS_DURATION_KEY, '25');
  const parsed = Number(rawValue);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 25;
}

export function savePersistedQuickFocusDurationMinutes(
  context: common.Context,
  durationMinutes: number
): boolean {
  return writeStoredString(context, QUICK_FOCUS_DURATION_KEY, durationMinutes.toString());
}

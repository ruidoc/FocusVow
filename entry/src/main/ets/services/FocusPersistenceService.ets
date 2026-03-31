import { common } from '@kit.AbilityKit';
import { FocusSession } from '../models/FocusSession';
import { removeStoredKey, readStoredString, writeStoredString } from './PreferencesService';

const FOCUS_SESSION_KEY: string = 'focus.currentSession';
const FOCUS_DURATION_KEY: string = 'focus.durationMinutes';

export function loadPersistedFocusSession(context: common.UIAbilityContext): FocusSession | null {
  const rawValue = readStoredString(context, FOCUS_SESSION_KEY, '');
  if (rawValue.length === 0) {
    return null;
  }

  try {
    return JSON.parse(rawValue) as FocusSession;
  } catch {
    console.error('Failed to parse persisted focus session.');
    return null;
  }
}

export function savePersistedFocusSession(
  context: common.UIAbilityContext,
  focusSession: FocusSession
): boolean {
  return writeStoredString(context, FOCUS_SESSION_KEY, JSON.stringify(focusSession));
}

export function clearPersistedFocusSession(context: common.UIAbilityContext): boolean {
  return removeStoredKey(context, FOCUS_SESSION_KEY);
}

export function loadPersistedDurationMinutes(context: common.UIAbilityContext): number {
  const rawValue = readStoredString(context, FOCUS_DURATION_KEY, '25');
  const parsed = Number(rawValue);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 25;
}

export function savePersistedDurationMinutes(
  context: common.UIAbilityContext,
  durationMinutes: number
): boolean {
  return writeStoredString(context, FOCUS_DURATION_KEY, durationMinutes.toString());
}

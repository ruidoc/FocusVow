import { common } from '@kit.AbilityKit';
import { isOnboardingCompleted } from '../services/OnboardingApiService';
import { readStoredString, writeStoredString } from '../services/PreferencesService';

const FOCUS_COUNT_KEY: string = 'focus_count';

export function getFocusCount(context: common.Context): number {
  const raw = readStoredString(context, FOCUS_COUNT_KEY, '0');
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 0;
}

export function incrementFocusCount(context: common.Context): number {
  const next = getFocusCount(context) + 1;
  writeStoredString(context, FOCUS_COUNT_KEY, String(next));
  return next;
}

export function hasCompletedOnboarding(context: common.Context): boolean {
  return isOnboardingCompleted(context);
}

export function isFirstTimeUser(context: common.Context): boolean {
  return hasCompletedOnboarding(context) && getFocusCount(context) === 0;
}

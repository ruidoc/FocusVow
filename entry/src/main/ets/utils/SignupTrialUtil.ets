import { common } from '@kit.AbilityKit';
import { readStoredString, removeStoredKey, writeStoredString } from '../services/PreferencesService';

const ELIGIBLE_KEY: string = 'signup_trial_eligible';

export const SIGNUP_TRIAL_EXISTING_USER_TOAST: string = '该账号已注册';
export const SIGNUP_TRIAL_TEAR_WARNING: string = '撕毁后将结束本次专注';

export function setSignupTrialEligible(context: common.Context, eligible: boolean): void {
  writeStoredString(context, ELIGIBLE_KEY, eligible ? '1' : '0');
}

export function clearSignupTrialEligible(context: common.Context): void {
  removeStoredKey(context, ELIGIBLE_KEY);
}

/** 未写入时保持原行为（视为可领） */
export function isSignupTrialEligible(context: common.Context): boolean {
  const stored = readStoredString(context, ELIGIBLE_KEY, '');
  if (stored.length === 0) {
    return true;
  }
  return stored === '1';
}

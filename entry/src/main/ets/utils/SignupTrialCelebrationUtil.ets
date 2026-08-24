import { common } from '@kit.AbilityKit';
import { BenefitStore } from '../stores/BenefitStore';
import { StoreKeys } from '../stores/StoreKeys';
import { UserStore } from '../stores/UserStore';
import { readStoredString, removeStoredKey, writeStoredString } from '../services/PreferencesService';
import {
  hasSkippedMembershipSignup,
  isWithinMembershipClaimWindow,
} from './OnboardingMembershipUtil';
import { isSignupTrialEligible, setSignupTrialEligible } from './SignupTrialUtil';

const PENDING_KEY: string = 'signup_trial_celebration_pending';

let presenting: boolean = false;

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(() => resolve(), ms);
  });
}

export function markPendingSignupTrialCelebration(context: common.Context): void {
  writeStoredString(context, PENDING_KEY, '1');
}

export function hasPendingSignupTrialCelebration(context: common.Context): boolean {
  return readStoredString(context, PENDING_KEY, '') === '1';
}

export function clearPendingSignupTrialCelebration(context: common.Context): void {
  removeStoredKey(context, PENDING_KEY);
}

export function shouldMarkSignupTrialCelebration(context: common.Context): boolean {
  if (!UserStore.isLoggedIn()) {
    return hasSkippedMembershipSignup(context) && isWithinMembershipClaimWindow(context);
  }
  return isSignupTrialEligible(context);
}

export function isSignupTrialMembershipActive(): boolean {
  const benefit = BenefitStore.getState();
  return benefit.isSubscribed === true || benefit.membershipStatus === 'active';
}

export async function tryPresentSignupTrialCelebration(
  context: common.Context,
  maxAttempts: number = 8,
  intervalMs: number = 800,
): Promise<boolean> {
  if (!hasPendingSignupTrialCelebration(context)) {
    return false;
  }
  if (!UserStore.isLoggedIn()) {
    return false;
  }
  if (!isSignupTrialEligible(context)) {
    clearPendingSignupTrialCelebration(context);
    return false;
  }
  if (presenting) {
    return false;
  }

  presenting = true;
  try {
    for (let i = 0; i < maxAttempts; i++) {
      await BenefitStore.refresh();
      if (isSignupTrialMembershipActive()) {
        clearPendingSignupTrialCelebration(context);
        setSignupTrialEligible(context, false);
        AppStorage.setOrCreate(StoreKeys.ShowSignupTrialCelebration, true);
        return true;
      }
      if (i < maxAttempts - 1) {
        await delay(intervalMs);
      }
    }
    return false;
  } finally {
    presenting = false;
  }
}

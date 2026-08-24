import { common } from '@kit.AbilityKit';
import { UserStore } from '../stores/UserStore';
import { StoreKeys } from '../stores/StoreKeys';
import { readStoredString, removeStoredKey, writeStoredString } from '../services/PreferencesService';
import { getFocusCount, hasCompletedOnboarding, incrementFocusCount } from './UserActivationUtil';
import { isSignupTrialEligible } from './SignupTrialUtil';
import { FIRST_FOCUS_TITLE } from '../services/FirstFocusPromptService';

const SKIPPED_MEMBERSHIP_SIGNUP_KEY: string = 'onboarding_skipped_membership_signup';
const MEMBERSHIP_CLAIM_DEADLINE_KEY: string = 'onboarding_membership_claim_deadline_ms';
const MEMBERSHIP_URGENCY_DEADLINE_KEY: string = 'onboarding_membership_urgency_deadline_ms';
const PENDING_ACTIVATION_MODAL_KEY: string = 'onboarding_activation_modal_pending';
const ACTIVATION_BANNER_ACTIVE_KEY: string = 'onboarding_activation_banner_active';

export const MEMBERSHIP_CLAIM_WINDOW_MS: number = 24 * 60 * 60 * 1000;
export const MEMBERSHIP_URGENCY_WINDOW_MS: number = 15 * 60 * 1000;
export const MEMBERSHIP_URGENCY_WINDOW_MINUTES: number = 15;

function readDeadlineMs(context: common.Context, key: string): number | null {
  const raw = readStoredString(context, key, '');
  if (raw.length === 0) {
    return null;
  }
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function writeDeadlineMs(context: common.Context, key: string, value: number): void {
  writeStoredString(context, key, String(value));
}

function notifyUrgencyChanged(): void {
  const current = AppStorage.get<number>(StoreKeys.MembershipUrgencyTick) ?? 0;
  AppStorage.setOrCreate(StoreKeys.MembershipUrgencyTick, current + 1);
}

export function markMembershipSignupSkipped(context: common.Context): void {
  writeStoredString(context, SKIPPED_MEMBERSHIP_SIGNUP_KEY, '1');
  writeDeadlineMs(context, MEMBERSHIP_CLAIM_DEADLINE_KEY, Date.now() + MEMBERSHIP_CLAIM_WINDOW_MS);
}

export function clearMembershipSignupSkipped(context: common.Context): void {
  removeStoredKey(context, SKIPPED_MEMBERSHIP_SIGNUP_KEY);
  removeStoredKey(context, MEMBERSHIP_CLAIM_DEADLINE_KEY);
}

export function hasSkippedMembershipSignup(context: common.Context): boolean {
  return readStoredString(context, SKIPPED_MEMBERSHIP_SIGNUP_KEY, '') === '1';
}

export function getMembershipClaimDeadlineMs(context: common.Context): number | null {
  return readDeadlineMs(context, MEMBERSHIP_CLAIM_DEADLINE_KEY);
}

export function isWithinMembershipClaimWindow(context: common.Context): boolean {
  const deadline = getMembershipClaimDeadlineMs(context);
  if (!deadline) {
    return !hasSkippedMembershipSignup(context);
  }
  return Date.now() < deadline;
}

export function isMembershipReclaimEligible(context: common.Context): boolean {
  if (UserStore.isLoggedIn()) {
    return false;
  }
  if (!hasSkippedMembershipSignup(context)) {
    return false;
  }
  return isWithinMembershipClaimWindow(context);
}

export function setPendingOnboardingActivationModal(context: common.Context): void {
  writeStoredString(context, PENDING_ACTIVATION_MODAL_KEY, '1');
  AppStorage.setOrCreate(StoreKeys.PendingOnboardingActivationModal, true);
}

export function hasPendingOnboardingActivationModal(context: common.Context): boolean {
  if (AppStorage.get<boolean>(StoreKeys.PendingOnboardingActivationModal) === true) {
    return true;
  }
  return readStoredString(context, PENDING_ACTIVATION_MODAL_KEY, '') === '1';
}

export function consumePendingOnboardingActivationModal(context: common.Context): boolean {
  if (!hasPendingOnboardingActivationModal(context)) {
    return false;
  }
  if (!canStillClaimOnboardingMembership(context)) {
    return false;
  }
  AppStorage.setOrCreate(StoreKeys.PendingOnboardingActivationModal, false);
  removeStoredKey(context, PENDING_ACTIVATION_MODAL_KEY);
  writeStoredString(context, ACTIVATION_BANNER_ACTIVE_KEY, '1');
  return true;
}

export function shouldShowOnboardingActivationBanner(context: common.Context): boolean {
  if (!hasCompletedOnboarding(context) || getFocusCount(context) > 0) {
    return false;
  }
  if (readStoredString(context, ACTIVATION_BANNER_ACTIVE_KEY, '') !== '1') {
    return false;
  }
  if (UserStore.isLoggedIn()) {
    return true;
  }
  return isMembershipReclaimEligible(context);
}

export function dismissOnboardingActivationBanner(context: common.Context): void {
  removeStoredKey(context, ACTIVATION_BANNER_ACTIVE_KEY);
}

export function clearOnboardingActivationUiState(context: common.Context): void {
  AppStorage.setOrCreate(StoreKeys.PendingOnboardingActivationModal, false);
  removeStoredKey(context, PENDING_ACTIVATION_MODAL_KEY);
  removeStoredKey(context, ACTIVATION_BANNER_ACTIVE_KEY);
  clearMembershipUrgencyCountdown(context);
}

function canStillClaimOnboardingMembership(context: common.Context): boolean {
  if (!hasCompletedOnboarding(context) || getFocusCount(context) > 0) {
    return false;
  }
  if (hasSkippedMembershipSignup(context)) {
    return isWithinMembershipClaimWindow(context);
  }
  if (UserStore.isLoggedIn()) {
    return isSignupTrialEligible(context);
  }
  return false;
}

export function isOnboardingMembershipBenefitActive(context: common.Context): boolean {
  return canStillClaimOnboardingMembership(context);
}

export function getMembershipUrgencyDeadlineMs(context: common.Context): number | null {
  return readDeadlineMs(context, MEMBERSHIP_URGENCY_DEADLINE_KEY);
}

export function getMembershipUrgencySecondsLeft(context: common.Context): number {
  const deadline = getMembershipUrgencyDeadlineMs(context);
  if (!deadline) {
    return 0;
  }
  return Math.max(0, Math.ceil((deadline - Date.now()) / 1000));
}

export function formatMembershipUrgencyCountdown(totalSeconds: number): string {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  const secLabel = seconds < 10 ? `0${seconds}` : `${seconds}`;
  return `${minutes}:${secLabel}`;
}

export function clearMembershipUrgencyCountdown(context?: common.Context): void {
  if (context) {
    removeStoredKey(context, MEMBERSHIP_URGENCY_DEADLINE_KEY);
  }
  notifyUrgencyChanged();
}

function revokeOnboardingMembershipEligibility(context: common.Context): void {
  dismissOnboardingActivationBanner(context);
  if (hasSkippedMembershipSignup(context)) {
    writeDeadlineMs(context, MEMBERSHIP_CLAIM_DEADLINE_KEY, Date.now() - 1);
  } else if (UserStore.isLoggedIn()) {
    writeStoredString(context, 'signup_trial_eligible', '0');
  }
}

export function expireMembershipUrgencyIfNeeded(context: common.Context): boolean {
  const deadline = getMembershipUrgencyDeadlineMs(context);
  if (!deadline || Date.now() < deadline) {
    return false;
  }
  clearMembershipUrgencyCountdown(context);
  revokeOnboardingMembershipEligibility(context);
  return true;
}

export function isMembershipUrgencyActive(context: common.Context): boolean {
  if (!hasCompletedOnboarding(context) || getFocusCount(context) > 0) {
    return false;
  }
  if (!canStillClaimOnboardingMembership(context)) {
    return false;
  }
  const deadline = getMembershipUrgencyDeadlineMs(context);
  if (!deadline) {
    return false;
  }
  return Date.now() < deadline;
}

export function shouldShowMembershipUrgencyCapsule(
  context: common.Context,
  hasActiveLock: boolean,
  hasPendingQuickStart: boolean,
): boolean {
  expireMembershipUrgencyIfNeeded(context);
  if (hasActiveLock || hasPendingQuickStart) {
    return false;
  }
  return isMembershipUrgencyActive(context);
}

export function startMembershipUrgencyCountdown(context: common.Context): void {
  if (!hasCompletedOnboarding(context) || getFocusCount(context) > 0) {
    return;
  }
  if (!canStillClaimOnboardingMembership(context)) {
    return;
  }
  const existing = getMembershipUrgencyDeadlineMs(context);
  if (existing && existing > Date.now()) {
    return;
  }
  writeDeadlineMs(context, MEMBERSHIP_URGENCY_DEADLINE_KEY, Date.now() + MEMBERSHIP_URGENCY_WINDOW_MS);
  notifyUrgencyChanged();
}

export function shouldWarnSignupTrialOnTear(context: common.Context, planTitle: string): boolean {
  const firstFocus = planTitle === FIRST_FOCUS_TITLE;
  if (UserStore.isLoggedIn()) {
    if (!isSignupTrialEligible(context)) {
      return false;
    }
    return getFocusCount(context) === 0 || firstFocus;
  }
  return isMembershipReclaimEligible(context) && getFocusCount(context) === 0;
}

export function abandonOnboardingMembershipOnTear(context: common.Context): void {
  if (getFocusCount(context) === 0) {
    incrementFocusCount(context);
  }
  dismissOnboardingActivationBanner(context);
  clearMembershipUrgencyCountdown(context);
  revokeOnboardingMembershipEligibility(context);
}

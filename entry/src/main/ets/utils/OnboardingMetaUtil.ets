export type OnboardingEntrySource = 'new_explore' | 'welcome_old_user';
export type OnboardingPath = 'register_first' | 'focus_first';
export type SignupPath = 'onboarding' | 'first_finish' | 'welcome_old_user' | 'register';

export interface OnboardingMeta {
  entry_source?: OnboardingEntrySource;
  onboarding_path?: OnboardingPath;
  benefit_eligible?: boolean;
}

let cachedMeta: OnboardingMeta = {};

function mergeProps(
  base: Record<string, Object>,
  extra?: Record<string, Object>,
): Record<string, Object> {
  if (!extra) {
    return base;
  }
  const merged: Record<string, Object> = {};
  const baseKeys = Object.keys(base);
  for (let i = 0; i < baseKeys.length; i++) {
    const key = baseKeys[i];
    merged[key] = base[key];
  }
  const extraKeys = Object.keys(extra);
  for (let j = 0; j < extraKeys.length; j++) {
    const extraKey = extraKeys[j];
    merged[extraKey] = extra[extraKey];
  }
  return merged;
}

export function getOnboardingMeta(): OnboardingMeta {
  return {
    entry_source: cachedMeta.entry_source,
    onboarding_path: cachedMeta.onboarding_path,
    benefit_eligible: cachedMeta.benefit_eligible,
  };
}

export function patchOnboardingMeta(patch: OnboardingMeta): OnboardingMeta {
  if (patch.entry_source !== undefined) {
    cachedMeta.entry_source = patch.entry_source;
  }
  if (patch.onboarding_path !== undefined) {
    cachedMeta.onboarding_path = patch.onboarding_path;
  }
  if (patch.benefit_eligible !== undefined) {
    cachedMeta.benefit_eligible = patch.benefit_eligible;
  }
  return getOnboardingMeta();
}

export function resetOnboardingMeta(): void {
  cachedMeta = {};
}

export function buildOnboardingMetaPatch(patch: OnboardingMeta): Record<string, Object> {
  patchOnboardingMeta(patch);
  const meta: Record<string, Object> = {};
  const snapshot = getOnboardingMeta();
  if (snapshot.entry_source) {
    meta['entry_source'] = snapshot.entry_source;
  }
  if (snapshot.onboarding_path) {
    meta['onboarding_path'] = snapshot.onboarding_path;
  }
  if (snapshot.benefit_eligible !== undefined) {
    meta['benefit_eligible'] = snapshot.benefit_eligible;
  }
  return meta;
}

export function resolveSignupPath(entrySource?: string): SignupPath {
  const from = String(entrySource || '').trim();
  if (from === 'onboarding_signup_benefit') {
    return 'onboarding';
  }
  if (from === 'guest_membership_reclaim') {
    return 'first_finish';
  }
  if (from === 'welcome_old_user') {
    return 'welcome_old_user';
  }
  return 'register';
}

export function buildOnboardingAnalyticsProps(
  extra?: Record<string, Object>,
): Record<string, Object> {
  const snapshot = getOnboardingMeta();
  const props: Record<string, Object> = {};
  if (snapshot.onboarding_path) {
    props['onboarding_path'] = snapshot.onboarding_path;
  }
  if (snapshot.entry_source) {
    props['journey_entry_source'] = snapshot.entry_source;
  }
  if (snapshot.benefit_eligible !== undefined) {
    props['benefit_eligible'] = snapshot.benefit_eligible;
  }
  return mergeProps(props, extra);
}

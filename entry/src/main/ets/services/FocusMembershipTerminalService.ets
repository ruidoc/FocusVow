import { common } from '@kit.AbilityKit';
import { ActiveLockState } from '../models/ActiveLockModel';
import {
  queueHonorCertificate,
  tryPresentCertificateGuide,
} from './CertificatePendingService';
import { afterGuestSoloFocusEnded } from './GuestSoloFocusService';
import { UserStore } from '../stores/UserStore';
import { getFocusCount, incrementFocusCount } from '../utils/UserActivationUtil';
import {
  clearMembershipSignupSkipped,
  clearMembershipUrgencyCountdown,
  dismissOnboardingActivationBanner,
} from '../utils/OnboardingMembershipUtil';
import {
  markPendingSignupTrialCelebration,
  shouldMarkSignupTrialCelebration,
  tryPresentSignupTrialCelebration,
} from '../utils/SignupTrialCelebrationUtil';
import { AnalyticsService } from './AnalyticsService';
import { buildOnboardingAnalyticsProps } from '../utils/OnboardingMetaUtil';

export async function handleSoloQuickFocusSuccess(
  uiContext: UIContext,
  hostContext: common.UIAbilityContext,
  lock: ActiveLockState,
  endedAt: number,
): Promise<void> {
  const wasFirstFocus = getFocusCount(hostContext) === 0;
  if (wasFirstFocus) {
    incrementFocusCount(hostContext);
  }

  const shouldCelebrate = wasFirstFocus && shouldMarkSignupTrialCelebration(hostContext);

  if (UserStore.isLoggedIn()) {
    if (!shouldCelebrate) {
      queueHonorCertificate(lock, endedAt);
      tryPresentCertificateGuide(uiContext);
    }
  }

  if (wasFirstFocus) {
    dismissOnboardingActivationBanner(hostContext);
    clearMembershipUrgencyCountdown(hostContext);
    if (UserStore.isLoggedIn()) {
      clearMembershipSignupSkipped(hostContext);
      AnalyticsService.trackEvent('focus_activation_completed', buildOnboardingAnalyticsProps({
        'is_logged_in': true,
        'guest_path': false,
        'plan_id': lock.planId,
      }));
    }
    if (shouldCelebrate) {
      markPendingSignupTrialCelebration(hostContext);
      if (UserStore.isLoggedIn()) {
        await tryPresentSignupTrialCelebration(hostContext);
      }
    }
  }

  afterGuestSoloFocusEnded(uiContext, lock, hostContext, false);
}

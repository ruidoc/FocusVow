import { common } from '@kit.AbilityKit';
import { FocusRunStatus, FocusSession } from '../models/FocusSession';
import { releaseScreenRestriction } from './ScreenTimeService';
import { FocusStore } from '../stores/FocusStore';
import { SettingsStore } from '../stores/SettingsStore';

let finishingFocusSession: boolean = false;

export async function finishRunningFocusSession(
  context: common.UIAbilityContext,
  session: FocusSession,
  successMessage: string,
  failurePrefix: string
): Promise<boolean> {
  if (finishingFocusSession || session.status !== FocusRunStatus.Running) {
    return false;
  }

  finishingFocusSession = true;
  try {
    const result = await releaseScreenRestriction(session.selectedTokens, session.mode);
    FocusStore.finishSession(context);
    SettingsStore.updateStatusMessage(
      context,
      result.ok ? successMessage : `${failurePrefix}：${result.message}`
    );
    return true;
  } finally {
    finishingFocusSession = false;
  }
}

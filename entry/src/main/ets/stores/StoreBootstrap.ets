import { createIdleLockState } from '../models/ActiveLockModel';
import { createHiddenInAppMessage } from '../models/InAppMessageModel';
import { createDefaultCycleGuardState } from '../models/CycleGuardModel';
import { createDefaultSettingsState } from '../models/PermissionModel';
import { createEmptyUserInfo, createEmptyWxPendingInfo } from '../models/UserModel';
import { StoreKeys } from './StoreKeys';

let bootstrapped: boolean = false;

export function bootstrapStores(): void {
  if (bootstrapped) {
    return;
  }

  const settingsState = createDefaultSettingsState();
  const cycleGuardState = createDefaultCycleGuardState();
  AppStorage.setOrCreate(StoreKeys.QuickFocusDurationMinutes, 25);
  AppStorage.setOrCreate(StoreKeys.LockActiveState, createIdleLockState());
  AppStorage.setOrCreate(StoreKeys.PlanCollection, []);
  AppStorage.setOrCreate(StoreKeys.PlanCurrentId, '');
  AppStorage.setOrCreate(StoreKeys.PlanFilterScope, 'today');
  AppStorage.setOrCreate(StoreKeys.SettingsHasAuthorized, settingsState.hasAuthorized);
  AppStorage.setOrCreate(StoreKeys.SettingsSelectedTokens, settingsState.selectedTokens);
  AppStorage.setOrCreate(StoreKeys.SettingsSelectedAppCount, settingsState.selectedAppCount);
  AppStorage.setOrCreate(StoreKeys.SettingsStatusMessage, settingsState.statusMessage);
  AppStorage.setOrCreate(StoreKeys.CycleGuardEnabled, cycleGuardState.enabled);
  AppStorage.setOrCreate(StoreKeys.CycleGuardQuotaMinutes, cycleGuardState.quotaMinutes);
  AppStorage.setOrCreate(StoreKeys.CycleGuardSelectedTokens, cycleGuardState.selectedTokens);
  AppStorage.setOrCreate(StoreKeys.CycleGuardSelectedAppCount, cycleGuardState.selectedAppCount);
  AppStorage.setOrCreate(StoreKeys.CycleGuardPhase, cycleGuardState.phase);
  AppStorage.setOrCreate(StoreKeys.CycleGuardStatusMessage, cycleGuardState.statusMessage);
  AppStorage.setOrCreate(StoreKeys.UserAccessToken, '');
  AppStorage.setOrCreate(StoreKeys.UserIsLoggedIn, false);
  AppStorage.setOrCreate(StoreKeys.UserInfo, createEmptyUserInfo());
  AppStorage.setOrCreate(StoreKeys.BenefitDayDuration, 0);
  AppStorage.setOrCreate(StoreKeys.BenefitTodayUsed, 0);
  AppStorage.setOrCreate(StoreKeys.BenefitDuoTodayUsed, 0);
  AppStorage.setOrCreate(StoreKeys.BenefitIsSubscribed, false);
  AppStorage.setOrCreate(StoreKeys.BenefitMembershipStatus, 'none');
  AppStorage.setOrCreate(StoreKeys.BenefitCommunityQrUrl, '');
  AppStorage.setOrCreate(StoreKeys.BenefitCommunityHint, '');
  AppStorage.setOrCreate(StoreKeys.BenefitFeatures, '');
  AppStorage.setOrCreate(StoreKeys.InAppMessage, createHiddenInAppMessage());
  AppStorage.setOrCreate(StoreKeys.ScheduledListAll, []);
  AppStorage.setOrCreate(StoreKeys.ScheduledListFilter, 'all');
  AppStorage.setOrCreate(StoreKeys.ScheduledListDirty, true);
  AppStorage.setOrCreate(StoreKeys.MainTabTarget, '');
  AppStorage.setOrCreate(StoreKeys.MainTabFloatingBar, false);
  AppStorage.setOrCreate(StoreKeys.DuoWaitSessionId, '');
  AppStorage.setOrCreate(StoreKeys.DuoWaitTitle, '');
  AppStorage.setOrCreate(StoreKeys.DuoWaitInviteText, '');
  AppStorage.setOrCreate(StoreKeys.DuoWaitIsScheduled, false);
  AppStorage.setOrCreate(StoreKeys.DuoWaitScheduleLabel, '');
  AppStorage.setOrCreate(StoreKeys.DuoWaitDurationMin, 0);
  AppStorage.setOrCreate(StoreKeys.DuoWaitExpireAtMs, 0);
  AppStorage.setOrCreate(StoreKeys.DuoWaitStartedAtMs, 0);
  AppStorage.setOrCreate(StoreKeys.OrgDetailId, '');
  AppStorage.setOrCreate(StoreKeys.OrgList, []);
  AppStorage.setOrCreate(StoreKeys.OrgDefaults, []);
  AppStorage.setOrCreate(StoreKeys.OrgMine, []);
  AppStorage.setOrCreate(StoreKeys.OrgLoading, false);
  AppStorage.setOrCreate(StoreKeys.InboxItems, []);
  AppStorage.setOrCreate(StoreKeys.InboxUnread, 0);
  AppStorage.setOrCreate(StoreKeys.InboxImportantUnread, 0);
  AppStorage.setOrCreate(StoreKeys.InboxLoading, false);
  AppStorage.setOrCreate(StoreKeys.InboxOpenId, '');
  AppStorage.setOrCreate(StoreKeys.InboxDetailId, '');
  AppStorage.setOrCreate(StoreKeys.OnboardingViaOldUser, false);
  AppStorage.setOrCreate(StoreKeys.LoginFrom, '');
  AppStorage.setOrCreate(StoreKeys.WxPendingInfo, createEmptyWxPendingInfo());
  bootstrapped = true;
}

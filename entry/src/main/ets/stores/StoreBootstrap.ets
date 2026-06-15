import { createIdleLockState } from '../models/ActiveLockModel';
import { createDefaultCycleGuardState } from '../models/CycleGuardModel';
import { createDefaultSettingsState } from '../models/PermissionModel';
import { createEmptyUserInfo } from '../models/UserModel';
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
  bootstrapped = true;
}

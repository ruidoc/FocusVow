import { createIdleFocusSession } from '../models/FocusSession';
import { createDefaultSettingsState } from '../models/PermissionModel';
import { StoreKeys } from './StoreKeys';

let bootstrapped: boolean = false;

export function bootstrapStores(): void {
  if (bootstrapped) {
    return;
  }

  const settingsState = createDefaultSettingsState();
  AppStorage.setOrCreate(StoreKeys.FocusDurationMinutes, 25);
  AppStorage.setOrCreate(StoreKeys.FocusCurrentSession, createIdleFocusSession());
  AppStorage.setOrCreate(StoreKeys.PlanCollection, []);
  AppStorage.setOrCreate(StoreKeys.PlanCurrentId, '');
  AppStorage.setOrCreate(StoreKeys.PlanFilterScope, 'today');
  AppStorage.setOrCreate(StoreKeys.SettingsHasAuthorized, settingsState.hasAuthorized);
  AppStorage.setOrCreate(StoreKeys.SettingsSelectedTokens, settingsState.selectedTokens);
  AppStorage.setOrCreate(StoreKeys.SettingsSelectedAppCount, settingsState.selectedAppCount);
  AppStorage.setOrCreate(StoreKeys.SettingsStatusMessage, settingsState.statusMessage);
  bootstrapped = true;
}

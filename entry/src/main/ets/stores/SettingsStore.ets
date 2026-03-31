import { common } from '@kit.AbilityKit';
import { SettingsState, createDefaultSettingsState } from '../models/PermissionModel';
import { loadPersistedSettings, savePersistedSettings } from '../services/SettingsPersistenceService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

function persistCurrentSettings(context: common.UIAbilityContext): void {
  savePersistedSettings(context, SettingsStore.getState());
}

export class SettingsStore {
  static hydrate(context: common.UIAbilityContext): void {
    bootstrapStores();
    const persistedState = loadPersistedSettings(context);
    const nextState = persistedState ?? createDefaultSettingsState();

    AppStorage.setOrCreate(StoreKeys.SettingsHasAuthorized, nextState.hasAuthorized);
    AppStorage.setOrCreate(StoreKeys.SettingsSelectedTokens, nextState.selectedTokens);
    AppStorage.setOrCreate(StoreKeys.SettingsSelectedAppCount, nextState.selectedAppCount);
    AppStorage.setOrCreate(StoreKeys.SettingsStatusMessage, nextState.statusMessage);
  }

  static getState(): SettingsState {
    bootstrapStores();
    return {
      hasAuthorized: AppStorage.get<boolean>(StoreKeys.SettingsHasAuthorized) ?? false,
      selectedTokens: AppStorage.get<string[]>(StoreKeys.SettingsSelectedTokens) ?? [],
      selectedAppCount: AppStorage.get<number>(StoreKeys.SettingsSelectedAppCount) ?? 0,
      statusMessage: AppStorage.get<string>(StoreKeys.SettingsStatusMessage) ?? createDefaultSettingsState().statusMessage
    };
  }

  static updateAuthorization(
    context: common.UIAbilityContext,
    hasAuthorized: boolean,
    statusMessage: string
  ): void {
    bootstrapStores();
    AppStorage.setOrCreate(StoreKeys.SettingsHasAuthorized, hasAuthorized);
    AppStorage.setOrCreate(StoreKeys.SettingsStatusMessage, statusMessage);
    persistCurrentSettings(context);
  }

  static updateSelectedTokens(
    context: common.UIAbilityContext,
    selectedTokens: string[],
    statusMessage: string
  ): void {
    bootstrapStores();
    AppStorage.setOrCreate(StoreKeys.SettingsSelectedTokens, [...selectedTokens]);
    AppStorage.setOrCreate(StoreKeys.SettingsSelectedAppCount, selectedTokens.length);
    AppStorage.setOrCreate(StoreKeys.SettingsStatusMessage, statusMessage);
    persistCurrentSettings(context);
  }

  static updateStatusMessage(context: common.UIAbilityContext, statusMessage: string): void {
    bootstrapStores();
    AppStorage.setOrCreate(StoreKeys.SettingsStatusMessage, statusMessage);
    persistCurrentSettings(context);
  }

  static reset(context: common.UIAbilityContext): void {
    bootstrapStores();
    const defaultState = createDefaultSettingsState();
    AppStorage.setOrCreate(StoreKeys.SettingsHasAuthorized, defaultState.hasAuthorized);
    AppStorage.setOrCreate(StoreKeys.SettingsSelectedTokens, defaultState.selectedTokens);
    AppStorage.setOrCreate(StoreKeys.SettingsSelectedAppCount, defaultState.selectedAppCount);
    AppStorage.setOrCreate(StoreKeys.SettingsStatusMessage, defaultState.statusMessage);
    persistCurrentSettings(context);
  }
}

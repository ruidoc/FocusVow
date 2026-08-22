import { common } from '@kit.AbilityKit';
import { SettingsState, createDefaultSettingsState } from '../models/PermissionModel';
import { loadPersistedSettings, savePersistedSettings } from '../services/SettingsPersistenceService';
import { UserAppApiService } from '../services/UserAppApiService';
import { isHarmonyPcOr2in1 } from '../utils/DeviceFormFactor';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

function persistCurrentSettings(context: common.UIAbilityContext): void {
  savePersistedSettings(context, SettingsStore.getState());
}

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

export class SettingsStore {
  static hydrate(context: common.UIAbilityContext): void {
    bootstrapStores();
    const persistedState = loadPersistedSettings(context);
    const nextState = persistedState ?? createDefaultSettingsState();
    if (isHarmonyPcOr2in1()) {
      nextState.hasAuthorized = true;
      nextState.statusMessage = 'PC/二合一设备无需屏时授权';
    }

    syncAppStorageValue(StoreKeys.SettingsHasAuthorized, nextState.hasAuthorized);
    syncAppStorageValue(StoreKeys.SettingsSelectedTokens, nextState.selectedTokens);
    syncAppStorageValue(StoreKeys.SettingsSelectedAppCount, nextState.selectedAppCount);
    syncAppStorageValue(StoreKeys.SettingsStatusMessage, nextState.statusMessage);
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
    // 新逻辑：双写统一表（失败不影响本机）
    void UserAppApiService.upsertSelectedTokens(selectedTokens);
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

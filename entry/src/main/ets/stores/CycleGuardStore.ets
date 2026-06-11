import { common } from '@kit.AbilityKit';
import {
  CycleGuardPhase,
  CycleGuardState,
  createDefaultCycleGuardState
} from '../models/CycleGuardModel';
import { loadPersistedCycleGuardState, savePersistedCycleGuardState } from '../services/CycleGuardPersistenceService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

function persistCurrentState(context: common.Context): void {
  savePersistedCycleGuardState(context, CycleGuardStore.getState());
}

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

export class CycleGuardStore {
  static hydrate(context: common.Context): void {
    bootstrapStores();
    const nextState = loadPersistedCycleGuardState(context) ?? createDefaultCycleGuardState();

    syncAppStorageValue(StoreKeys.CycleGuardEnabled, nextState.enabled);
    syncAppStorageValue(StoreKeys.CycleGuardQuotaMinutes, nextState.quotaMinutes);
    syncAppStorageValue(StoreKeys.CycleGuardSelectedTokens, nextState.selectedTokens);
    syncAppStorageValue(StoreKeys.CycleGuardSelectedAppCount, nextState.selectedAppCount);
    syncAppStorageValue(StoreKeys.CycleGuardPhase, nextState.phase);
    syncAppStorageValue(StoreKeys.CycleGuardStatusMessage, nextState.statusMessage);
  }

  static getState(): CycleGuardState {
    bootstrapStores();
    return {
      enabled: AppStorage.get<boolean>(StoreKeys.CycleGuardEnabled) ?? false,
      quotaMinutes: AppStorage.get<number>(StoreKeys.CycleGuardQuotaMinutes) ?? 60,
      selectedTokens: AppStorage.get<string[]>(StoreKeys.CycleGuardSelectedTokens) ?? [],
      selectedAppCount: AppStorage.get<number>(StoreKeys.CycleGuardSelectedAppCount) ?? 0,
      phase: (AppStorage.get<string>(StoreKeys.CycleGuardPhase) ?? 'idle') as CycleGuardPhase,
      statusMessage: AppStorage.get<string>(StoreKeys.CycleGuardStatusMessage) ?? createDefaultCycleGuardState().statusMessage
    };
  }

  static updateQuotaMinutes(context: common.Context, quotaMinutes: number): void {
    bootstrapStores();
    syncAppStorageValue(StoreKeys.CycleGuardQuotaMinutes, quotaMinutes);
    persistCurrentState(context);
  }

  static updateSelectedTokens(context: common.Context, selectedTokens: string[], statusMessage: string): void {
    bootstrapStores();
    syncAppStorageValue(StoreKeys.CycleGuardSelectedTokens, [...selectedTokens]);
    syncAppStorageValue(StoreKeys.CycleGuardSelectedAppCount, selectedTokens.length);
    syncAppStorageValue(StoreKeys.CycleGuardStatusMessage, statusMessage);
    persistCurrentState(context);
  }

  static updateRuntimeState(
    context: common.Context,
    enabled: boolean,
    phase: CycleGuardPhase,
    statusMessage: string
  ): void {
    bootstrapStores();
    syncAppStorageValue(StoreKeys.CycleGuardEnabled, enabled);
    syncAppStorageValue(StoreKeys.CycleGuardPhase, phase);
    syncAppStorageValue(StoreKeys.CycleGuardStatusMessage, statusMessage);
    persistCurrentState(context);
  }
}

import { common } from '@kit.AbilityKit';
import { CycleGuardPhase, CycleGuardState, createDefaultCycleGuardState } from '../models/CycleGuardModel';
import { loadPersistedCycleGuardState, savePersistedCycleGuardState } from '../services/CycleGuardPersistenceService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

function persistCurrentState(context: common.Context): void {
  savePersistedCycleGuardState(context, CycleGuardStore.getState());
}

export class CycleGuardStore {
  static hydrate(context: common.Context): void {
    bootstrapStores();
    const persistedState = loadPersistedCycleGuardState(context);
    const nextState = persistedState ?? createDefaultCycleGuardState();

    AppStorage.setOrCreate(StoreKeys.CycleGuardEnabled, nextState.enabled);
    AppStorage.setOrCreate(StoreKeys.CycleGuardQuotaMinutes, nextState.quotaMinutes);
    AppStorage.setOrCreate(StoreKeys.CycleGuardLockMinutes, nextState.lockMinutes);
    AppStorage.setOrCreate(StoreKeys.CycleGuardSelectedTokens, nextState.selectedTokens);
    AppStorage.setOrCreate(StoreKeys.CycleGuardSelectedAppCount, nextState.selectedAppCount);
    AppStorage.setOrCreate(StoreKeys.CycleGuardPhase, nextState.phase);
    AppStorage.setOrCreate(StoreKeys.CycleGuardStatusMessage, nextState.statusMessage);
  }

  static getState(): CycleGuardState {
    bootstrapStores();
    return {
      enabled: AppStorage.get<boolean>(StoreKeys.CycleGuardEnabled) ?? false,
      quotaMinutes: AppStorage.get<number>(StoreKeys.CycleGuardQuotaMinutes) ?? 60,
      lockMinutes: AppStorage.get<number>(StoreKeys.CycleGuardLockMinutes) ?? 20,
      selectedTokens: AppStorage.get<string[]>(StoreKeys.CycleGuardSelectedTokens) ?? [],
      selectedAppCount: AppStorage.get<number>(StoreKeys.CycleGuardSelectedAppCount) ?? 0,
      phase: (AppStorage.get<string>(StoreKeys.CycleGuardPhase) ?? 'idle') as CycleGuardPhase,
      statusMessage: AppStorage.get<string>(StoreKeys.CycleGuardStatusMessage) ?? createDefaultCycleGuardState().statusMessage
    };
  }

  static updateQuotaMinutes(context: common.Context, quotaMinutes: number): void {
    bootstrapStores();
    AppStorage.setOrCreate(StoreKeys.CycleGuardQuotaMinutes, quotaMinutes);
    persistCurrentState(context);
  }

  static updateLockMinutes(context: common.Context, lockMinutes: number): void {
    bootstrapStores();
    AppStorage.setOrCreate(StoreKeys.CycleGuardLockMinutes, lockMinutes);
    persistCurrentState(context);
  }

  static updateSelectedTokens(context: common.Context, selectedTokens: string[], statusMessage: string): void {
    bootstrapStores();
    AppStorage.setOrCreate(StoreKeys.CycleGuardSelectedTokens, [...selectedTokens]);
    AppStorage.setOrCreate(StoreKeys.CycleGuardSelectedAppCount, selectedTokens.length);
    AppStorage.setOrCreate(StoreKeys.CycleGuardStatusMessage, statusMessage);
    persistCurrentState(context);
  }

  static updateRuntimeState(
    context: common.Context,
    enabled: boolean,
    phase: CycleGuardPhase,
    statusMessage: string
  ): void {
    bootstrapStores();
    AppStorage.setOrCreate(StoreKeys.CycleGuardEnabled, enabled);
    AppStorage.setOrCreate(StoreKeys.CycleGuardPhase, phase);
    AppStorage.setOrCreate(StoreKeys.CycleGuardStatusMessage, statusMessage);
    persistCurrentState(context);
  }
}

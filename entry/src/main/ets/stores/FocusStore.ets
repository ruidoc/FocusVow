import { common } from '@kit.AbilityKit';
import {
  FocusRunStatus,
  FocusSession,
  FocusSource,
  RestrictionMode,
  createFocusSession,
  createIdleFocusSession,
  formatRemainingSeconds,
  getRemainingSeconds,
  isFocusSessionFinished
} from '../models/FocusSession';
import {
  clearPersistedFocusSession,
  loadPersistedDurationMinutes,
  loadPersistedFocusSession,
  savePersistedDurationMinutes,
  savePersistedFocusSession
} from '../services/FocusPersistenceService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

export class FocusStore {
  static hydrate(context: common.UIAbilityContext): void {
    bootstrapStores();
    const persistedSession = loadPersistedFocusSession(context);
    const persistedDuration = loadPersistedDurationMinutes(context);
    AppStorage.setOrCreate(StoreKeys.FocusDurationMinutes, persistedDuration);
    if (persistedSession) {
      AppStorage.setOrCreate(StoreKeys.FocusCurrentSession, persistedSession);
    }
  }

  static getDurationMinutes(): number {
    bootstrapStores();
    return AppStorage.get<number>(StoreKeys.FocusDurationMinutes) ?? 25;
  }

  static setDurationMinutes(context: common.UIAbilityContext, durationMinutes: number): void {
    bootstrapStores();
    AppStorage.setOrCreate(StoreKeys.FocusDurationMinutes, durationMinutes);
    savePersistedDurationMinutes(context, durationMinutes);
  }

  static getCurrentSession(): FocusSession {
    bootstrapStores();
    return AppStorage.get<FocusSession>(StoreKeys.FocusCurrentSession) ?? createIdleFocusSession(FocusStore.getDurationMinutes());
  }

  static isRunning(): boolean {
    return FocusStore.getCurrentSession().status === FocusRunStatus.Running;
  }

  static getRemainingLabel(nowAt: number = Date.now()): string {
    const session = FocusStore.getCurrentSession();
    if (session.status !== FocusRunStatus.Running) {
      return formatRemainingSeconds(FocusStore.getDurationMinutes() * 60);
    }

    return formatRemainingSeconds(getRemainingSeconds(session, nowAt));
  }

  static shouldAutoFinish(nowAt: number = Date.now()): boolean {
    const session = FocusStore.getCurrentSession();
    return session.status === FocusRunStatus.Running && isFocusSessionFinished(session, nowAt);
  }

  static startSession(
    context: common.UIAbilityContext,
    selectedTokens: string[],
    durationMinutes: number,
    source: FocusSource,
    planId: string,
    planName: string,
    mode: RestrictionMode
  ): FocusSession {
    bootstrapStores();
    const nextSession = createFocusSession(
      selectedTokens,
      durationMinutes,
      Date.now(),
      source,
      planId,
      planName,
      mode
    );

    AppStorage.setOrCreate(StoreKeys.FocusCurrentSession, nextSession);
    AppStorage.setOrCreate(StoreKeys.FocusDurationMinutes, durationMinutes);
    savePersistedDurationMinutes(context, durationMinutes);
    savePersistedFocusSession(context, nextSession);
    return nextSession;
  }

  static finishSession(context: common.UIAbilityContext): void {
    bootstrapStores();
    const currentDuration = FocusStore.getCurrentSession().durationMinutes || FocusStore.getDurationMinutes();
    const finishedSession = createIdleFocusSession(currentDuration);
    finishedSession.status = FocusRunStatus.Finished;
    AppStorage.setOrCreate(StoreKeys.FocusCurrentSession, finishedSession);
    clearPersistedFocusSession(context);
  }

  static resetToIdle(context: common.UIAbilityContext): void {
    bootstrapStores();
    AppStorage.setOrCreate(StoreKeys.FocusCurrentSession, createIdleFocusSession(FocusStore.getDurationMinutes()));
    clearPersistedFocusSession(context);
  }
}

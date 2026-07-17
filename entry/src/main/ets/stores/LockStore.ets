import { common } from '@kit.AbilityKit';
import {
  ActiveLockState,
  QuickFocusOptions,
  RestrictionMode,
  createCovenantLockState,
  createIdleLockState,
  createQuickFocusLockState,
  formatRemainingSeconds,
  getRemainingSeconds,
  isLocked,
  isTimedLockFinished
} from '../models/ActiveLockModel';
import { FocusPlan } from '../models/PlanModel';
import {
  loadPersistedActiveLockState,
  loadPersistedQuickFocusDurationMinutes,
  savePersistedActiveLockState,
  savePersistedQuickFocusDurationMinutes
} from '../services/ActiveLockPersistenceService';
import { FocusStartedNotifyService } from '../services/FocusStartedNotifyService';
import { getPlanWindow } from '../services/PlanWindowService';
import { loadPersistedPlans } from '../services/PlanPersistenceService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

function enrichCovenantLockFromPlans(context: common.Context, state: ActiveLockState): ActiveLockState {
  if (state.kind !== 'covenant' || state.planId.length === 0) {
    return state;
  }

  const plans: FocusPlan[] = loadPersistedPlans(context);
  const plan = plans.find((item: FocusPlan) => item.id === state.planId);
  if (!plan || !plan.enabled || plan.selectedTokens.length === 0) {
    return state;
  }

  const planWindow = getPlanWindow(plan, new Date());
  return createCovenantLockState(
    plan.id,
    plan.name,
    plan.selectedTokens,
    plan.mode,
    planWindow.startAt,
    planWindow.endAt,
    state.updatedAt,
    state.duoSessionId.length > 0 ? state.duoSessionId : plan.duoSessionId,
    state.recordId,
    state.participationMode,
    state.partnerNickname
  );
}

export class LockStore {
  static hydrate(context: common.Context): void {
    bootstrapStores();
    const persistedState = loadPersistedActiveLockState(context);
    const enrichedState = persistedState
      ? enrichCovenantLockFromPlans(context, persistedState)
      : createIdleLockState();
    if (
      persistedState &&
      enrichedState.kind === 'covenant' &&
      enrichedState.selectedCount > persistedState.selectedCount
    ) {
      savePersistedActiveLockState(context, enrichedState);
    }
    const persistedDuration = loadPersistedQuickFocusDurationMinutes(context);
    syncAppStorageValue(StoreKeys.QuickFocusDurationMinutes, persistedDuration);
    syncAppStorageValue(StoreKeys.LockActiveState, enrichedState);
  }

  /** 扩展进程等无 AppStorage 场景：仅写持久化 */
  static persistState(context: common.Context, state: ActiveLockState): void {
    savePersistedActiveLockState(context, state);
  }

  static setState(context: common.Context, state: ActiveLockState): void {
    bootstrapStores();
    savePersistedActiveLockState(context, state);
    syncAppStorageValue(StoreKeys.LockActiveState, state);
  }

  static clear(context: common.Context): void {
    LockStore.setState(context, createIdleLockState());
  }

  static getState(): ActiveLockState {
    bootstrapStores();
    return AppStorage.get<ActiveLockState>(StoreKeys.LockActiveState) ?? createIdleLockState();
  }

  static isLocked(): boolean {
    return isLocked(LockStore.getState());
  }

  static getQuickFocusDurationMinutes(): number {
    bootstrapStores();
    return AppStorage.get<number>(StoreKeys.QuickFocusDurationMinutes) ?? 25;
  }

  static setQuickFocusDurationMinutes(context: common.Context, durationMinutes: number): void {
    bootstrapStores();
    syncAppStorageValue(StoreKeys.QuickFocusDurationMinutes, durationMinutes);
    savePersistedQuickFocusDurationMinutes(context, durationMinutes);
  }

  static getRemainingLabel(nowAt: number = Date.now()): string {
    const state = LockStore.getState();
    if (!isLocked(state) || state.endAt <= 0) {
      return formatRemainingSeconds(LockStore.getQuickFocusDurationMinutes() * 60);
    }

    return formatRemainingSeconds(getRemainingSeconds(state, nowAt));
  }

  static shouldAutoFinish(nowAt: number = Date.now()): boolean {
    const state = LockStore.getState();
    return state.kind === 'quick_focus' && isTimedLockFinished(state, nowAt);
  }

  static shouldAutoCompleteCovenant(nowAt: number = Date.now()): boolean {
    const state = LockStore.getState();
    return state.kind === 'covenant' && state.endAt > 0 && isTimedLockFinished(state, nowAt);
  }

  static startQuickFocus(
    context: common.Context,
    selectedTokens: string[],
    durationMinutes: number,
    mode: RestrictionMode,
    options?: QuickFocusOptions
  ): ActiveLockState {
    const nextState = createQuickFocusLockState(
      selectedTokens,
      durationMinutes,
      mode,
      Date.now(),
      options?.title ?? '单人专注',
      options?.duoSessionId ?? '',
      options?.recordId ?? '',
      options?.participationMode ?? '',
      options?.partnerNickname ?? '',
      options?.startedAtMs,
      options?.endAtMs
    );
    LockStore.setState(context, nextState);
    LockStore.setQuickFocusDurationMinutes(context, durationMinutes);

    // 互督由服务端推送；客户端只报单人锁机（含未登录）
    const duoSessionId = options?.duoSessionId ?? '';
    const isDuo =
      duoSessionId.length > 0 ||
      options?.participationMode === 'duo';
    if (!isDuo) {
      FocusStartedNotifyService.reportSoloStarted(
        context,
        durationMinutes,
        options?.title
      );
    }

    return nextState;
  }
}

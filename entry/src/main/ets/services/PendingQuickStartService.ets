import { common } from '@kit.AbilityKit';
import { ApiConfig } from '../config/ApiConfig';
import { resolveInstantLockMinutes, TimerMode } from '../utils/TimerMode';
import { AnalyticsService } from './AnalyticsService';
import { FocusStartedNotifyService } from './FocusStartedNotifyService';
import {
  ceilToNextMinuteMs,
  removePlanGuardStrategy,
  syncDelayedOnceGuardStrategy,
} from './ScreenTimeService';
import { readStoredString, removeStoredKey, writeStoredString } from './PreferencesService';
import { LockStore } from '../stores/LockStore';
import { SettingsStore } from '../stores/SettingsStore';
import { StoreKeys } from '../stores/StoreKeys';
import { bootstrapStores } from '../stores/StoreBootstrap';
import { DuoBgSyncService } from './DuoBgSyncService';

const PENDING_KEY: string = 'pending.quick_start';

/**
 * 对齐 iOS DelayedOnce.activateIfDue：到点立刻开锁。
 * TimeGuard 只有 HH:mm，杀进程后可能整分才回调；前台不 round 到整分再等。
 */
async function startDelayedQuickFocus(
  context: common.Context,
  pending: PendingQuickStartState,
  fallbackPlanId: string = '',
): Promise<void> {
  const planId = pending.planId.length > 0 ? pending.planId : fallbackPlanId;
  const now = Date.now();
  const startedAtMs = pending.startAtMs > 0 ? pending.startAtMs : now;
  const lockMinutes = resolveInstantLockMinutes(pending.durationMinutes, pending.timerMode);
  // UI 用精确时长，不对齐 TimeGuard 整分，否则会多出当前分钟剩余秒数
  const endAtMs = startedAtMs + lockMinutes * 60_000;

  LockStore.startQuickFocus(
    context,
    pending.selectedTokens,
    pending.durationMinutes,
    pending.mode,
    {
      title: pending.title,
      participationMode: 'solo',
      timerMode: pending.timerMode,
      minDurationMin: pending.timerMode === 'countup' ? pending.durationMinutes : 0,
      planId: planId,
      startedAtMs: startedAtMs,
      endAtMs: endAtMs,
      skipStartedNotify: true,
      isDelayedSolo: true,
    },
  );
  // 对齐 iOS：开锁后立刻 POST，不先等策略同步
  const notifyTask: Promise<boolean> = FocusStartedNotifyService.reportAndWait(context, {
    scene: 'delayed_solo_start',
    durationMin: pending.durationMinutes,
    sessionType: 'solo_once',
    title: pending.title,
    timerMode: pending.timerMode,
    planId,
    delayMinutes: pending.delayMinutes,
    startedAtMs: startedAtMs,
  });
  await syncDelayedOnceGuardStrategy(
    planId,
    now,
    pending.durationMinutes,
    pending.timerMode,
    pending.selectedTokens,
    pending.mode,
  );
  await notifyTask;
}

const PROD_QUICK_START_DELAY_OPTIONS: number[] = [0, 5, 10, 15, 20, 30, 45, 60];
const DEV_QUICK_START_DELAY_OPTIONS: number[] = [0, 1, 5, 10, 15, 20, 30, 45, 60];

export function getQuickStartDelayOptions(): number[] {
  return ApiConfig.isDevEnvironment()
    ? DEV_QUICK_START_DELAY_OPTIONS
    : PROD_QUICK_START_DELAY_OPTIONS;
}

export interface PendingQuickStartPayload {
  title: string;
  durationMinutes: number;
  timerMode: TimerMode;
  mode: 'shield' | 'allow';
  delayMinutes: number;
  fromOnboarding: boolean;
}

interface PendingQuickStartState extends PendingQuickStartPayload {
  planId: string;
  startAtMs: number;
  selectedTokens: string[];
}

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

function parsePending(raw: string): PendingQuickStartState | null {
  if (raw.length === 0) {
    return null;
  }
  try {
    const data = JSON.parse(raw) as PendingQuickStartState;
    if (!data.title || !Number.isFinite(data.startAtMs) || !Number.isFinite(data.durationMinutes)) {
      return null;
    }
    return data;
  } catch {
    return null;
  }
}

function loadPending(context: common.Context): PendingQuickStartState | null {
  return parsePending(readStoredString(context, PENDING_KEY, ''));
}

function savePending(context: common.Context, pending: PendingQuickStartState): void {
  writeStoredString(context, PENDING_KEY, JSON.stringify(pending));
  syncPendingToAppStorage(pending);
}

function syncPendingToAppStorage(pending: PendingQuickStartState | null): void {
  if (!pending) {
    syncAppStorageValue(StoreKeys.PendingQuickStartTitle, '');
    syncAppStorageValue(StoreKeys.PendingQuickStartDelayMin, 0);
    syncAppStorageValue(StoreKeys.PendingQuickStartStartAtMs, 0);
    return;
  }
  syncAppStorageValue(StoreKeys.PendingQuickStartTitle, pending.title);
  syncAppStorageValue(StoreKeys.PendingQuickStartDelayMin, pending.delayMinutes);
  syncAppStorageValue(StoreKeys.PendingQuickStartStartAtMs, pending.startAtMs);
}

export function hydratePendingQuickStart(context: common.Context): void {
  bootstrapStores();
  syncPendingToAppStorage(loadPending(context));
  DuoBgSyncService.ensure();
}

export function hasPendingQuickStart(context: common.Context): boolean {
  return loadPending(context) !== null;
}

export function getPendingRemainSeconds(context: common.Context, nowMs: number = Date.now()): number {
  const pending = loadPending(context);
  if (!pending) {
    return 0;
  }
  return Math.max(0, Math.ceil((pending.startAtMs - nowMs) / 1000));
}

export function clearPendingQuickStart(context: common.Context): void {
  removeStoredKey(context, PENDING_KEY);
  syncPendingToAppStorage(null);
  DuoBgSyncService.ensure();
}

export async function cancelPendingQuickStart(context: common.Context): Promise<void> {
  const pending = loadPending(context);
  if (pending && pending.planId.length > 0) {
    await removePlanGuardStrategy(pending.planId);
  }
  clearPendingQuickStart(context);
}

export async function schedulePendingQuickStart(
  context: common.Context,
  payload: PendingQuickStartPayload,
): Promise<boolean> {
  const planId = `once_${Date.now()}`;
  // 对齐 RN：精确 now + N 分钟，倒计时从 N:00 起
  const startAtMs = Date.now() + payload.delayMinutes * 60_000;
  const selectedTokens = SettingsStore.getState().selectedTokens;
  const pending: PendingQuickStartState = {
    title: payload.title,
    durationMinutes: payload.durationMinutes,
    timerMode: payload.timerMode,
    mode: payload.mode,
    delayMinutes: payload.delayMinutes,
    fromOnboarding: payload.fromOnboarding,
    planId,
    startAtMs,
    selectedTokens,
  };
  // 先落盘，避免预约 start 同步触发 onStart 时读不到
  savePending(context, pending);
  // TimeGuard 策略开始时刻单独进整分，避免提前触发
  const result = await syncDelayedOnceGuardStrategy(
    planId,
    ceilToNextMinuteMs(startAtMs),
    payload.durationMinutes,
    payload.timerMode,
    selectedTokens,
    payload.mode,
  );
  if (!result.ok) {
    await cancelPendingQuickStart(context);
    return false;
  }
  DuoBgSyncService.ensure();
  AnalyticsService.trackEvent('quick_start_delayed_scheduled', {
    'delay_minutes': payload.delayMinutes,
    'duration_minutes': payload.durationMinutes,
    'timer_mode': payload.timerMode,
    'from_onboarding': payload.fromOnboarding,
  });
  return true;
}

let settling: boolean = false;

export async function activateDelayedOnceIfNeeded(
  context: common.Context,
  strategyName: string,
): Promise<boolean> {
  if (!strategyName.startsWith('once_')) {
    return false;
  }
  const pending = loadPending(context);
  if (!pending) {
    return false;
  }
  // 对齐 iOS activateIfDue：未到点不履约（允许约 2 秒误差）
  if (getPendingRemainSeconds(context) > 2) {
    return false;
  }
  await startDelayedQuickFocus(context, pending, strategyName);
  clearPendingQuickStart(context);
  return true;
}

export async function reconcilePendingQuickStart(context: common.Context): Promise<boolean> {
  const pending = loadPending(context);
  if (!pending || settling) {
    return false;
  }
  if (LockStore.isLocked()) {
    clearPendingQuickStart(context);
    return true;
  }
  if (getPendingRemainSeconds(context) > 0) {
    return false;
  }

  settling = true;
  try {
    clearPendingQuickStart(context);
    await startDelayedQuickFocus(context, pending, '');
    return true;
  } finally {
    settling = false;
  }
}

import { common } from "@kit.AbilityKit";
import { ApiConfig } from "../config/ApiConfig";
import { readStoredString, writeStoredString } from "./PreferencesService";
import { QuickTaskStore } from "../stores/QuickTaskStore";
import { ScheduledListStore } from "../stores/ScheduledListStore";
import { isSleepSchedule } from "../utils/ScheduledClockUtil";
import { ensureProMembership, isMemberActive, openVipPurchase } from "../utils/PaywallNavigationUtil";

export const FREE_QUICK_TASK_LIMIT: number = 2;
export const FREE_SCHEDULED_TASK_LIMIT: number = 1;
export const FREE_DELAYED_START_MINUTES: number = 5;
/** 免费版每日可预约延时专注次数（会员不限） */
export const FREE_DELAYED_START_DAILY_LIMIT: number = 1;
const DELAYED_START_USAGE_KEY: string = "delayed_start_usage";

export function countEnabledQuickTasks(excludeTaskId: string = ''): number {
  const tasks = QuickTaskStore.getTasks();
  let count = 0;
  for (let i = 0; i < tasks.length; i++) {
    if (!tasks[i].enabled) {
      continue;
    }
    if (excludeTaskId.length > 0 && tasks[i].id === excludeTaskId) {
      continue;
    }
    count += 1;
  }
  return count;
}

export function canEnableMoreQuickTasks(excludeTaskId: string = ''): boolean {
  if (isMemberActive()) {
    return true;
  }
  return countEnabledQuickTasks(excludeTaskId) < FREE_QUICK_TASK_LIMIT;
}

/** @returns true 可启用；false 已弹出快付 */
export function promptEnableQuickTaskSlot(excludeTaskId: string = ''): boolean {
  if (canEnableMoreQuickTasks(excludeTaskId)) {
    return true;
  }
  openVipPurchase('quick_task_slot', { proUnlock: true });
  return false;
}

export function countEnabledScheduledAsInitiator(excludeSessionId: string = ''): number {
  const sessions = ScheduledListStore.getAllSessions();
  let count = 0;
  for (let i = 0; i < sessions.length; i++) {
    const session = sessions[i];
    if (session.viewer_role !== 'initiator' || !session.enabled) {
      continue;
    }
    if (isSleepSchedule(session.schedule_json)) {
      continue;
    }
    if (excludeSessionId.length > 0 && session.session_id === excludeSessionId) {
      continue;
    }
    count += 1;
  }
  return count;
}

export function canEnableMoreScheduled(excludeSessionId: string = ''): boolean {
  if (isMemberActive()) {
    return true;
  }
  return countEnabledScheduledAsInitiator(excludeSessionId) < FREE_SCHEDULED_TASK_LIMIT;
}

/** @returns true 可启用；false 已弹出快付 */
export function promptEnableScheduledSlot(excludeSessionId: string = ''): boolean {
  if (excludeSessionId.length > 0) {
    const sessions = ScheduledListStore.getAllSessions();
    for (let i = 0; i < sessions.length; i++) {
      if (sessions[i].session_id === excludeSessionId && isSleepSchedule(sessions[i].schedule_json)) {
        return true;
      }
    }
  }
  if (canEnableMoreScheduled(excludeSessionId)) {
    return true;
  }
  openVipPurchase('scheduled_task_slot', { proUnlock: true });
  return false;
}

export function isProSlotQuotaMessage(message: string): boolean {
  return message.includes('免费版仅可启用') || message.includes('请开通会员或先关闭');
}

/** @returns true 已弹出快付 */
export function upsellIfProSlotQuota(message: string, kind: string): boolean {
  if (!isProSlotQuotaMessage(message)) {
    return false;
  }
  const source = kind === 'quick' ? 'quick_task_slot' : 'scheduled_task_slot';
  openVipPurchase(source, { proUnlock: true });
  return true;
}

export function openSlotUpsell(kind: string): void {
  const source = kind === 'quick' ? 'quick_task_slot' : 'scheduled_task_slot';
  openVipPurchase(source, { proUnlock: true });
}

/** 与 RN isPlanSlotEnabled：undefined 视为已启用 */
export function isPlanSlotEnabled(enabled?: boolean): boolean {
  return enabled !== false;
}

export function promptSlotUpsellIfDisabled(enabled: boolean | undefined, kind: string): void {
  if (isPlanSlotEnabled(enabled)) {
    return;
  }
  openSlotUpsell(kind);
}

function todayKey(): string {
  const now = new Date();
  const month = now.getMonth() + 1;
  const day = now.getDate();
  const monthText = month < 10 ? `0${month}` : `${month}`;
  const dayText = day < 10 ? `0${day}` : `${day}`;
  return `${now.getFullYear()}-${monthText}-${dayText}`;
}

function getDelayedStartUsageToday(context: common.Context): number {
  const raw = readStoredString(context, DELAYED_START_USAGE_KEY, "");
  const parts = raw.split("|");
  if (parts.length !== 2 || parts[0] !== todayKey()) {
    return 0;
  }
  const count = Number(parts[1]);
  return Number.isFinite(count) && count > 0 ? count : 0;
}

export function recordDelayedStartUsage(context: common.Context): void {
  if (isMemberActive()) {
    return;
  }
  const count = getDelayedStartUsageToday(context) + 1;
  writeStoredString(context, DELAYED_START_USAGE_KEY, `${todayKey()}|${count}`);
}

export function ensureDelayMinutesAllowed(context: common.Context, delayMinutes: number): boolean {
  if (delayMinutes <= 0) {
    return true;
  }
  if (isMemberActive()) {
    return true;
  }
  if (getDelayedStartUsageToday(context) < FREE_DELAYED_START_DAILY_LIMIT) {
    return true;
  }
  return ensureProMembership("delayed_start_limit", { proUnlock: true });
}

export function ensureDelayStartAllowed(context: common.Context, delayMinutes: number): boolean {
  return ensureDelayMinutesAllowed(context, delayMinutes);
}

function allDelayPickerOptions(): number[] {
  return ApiConfig.isDevEnvironment()
    ? [0, 1, 5, 10, 15, 20, 30, 45, 60]
    : [0, 5, 10, 15, 20, 30, 45, 60];
}

export function normalizeDelayMinutes(min: number): number {
  const opts = allDelayPickerOptions();
  if (opts.indexOf(min) >= 0) {
    return min;
  }
  if (min <= 0) {
    return 0;
  }
  const positive: number[] = [];
  for (let i = 0; i < opts.length; i++) {
    if (opts[i] > 0) {
      positive.push(opts[i]);
    }
  }
  let best = positive.length > 0 ? positive[0] : FREE_DELAYED_START_MINUTES;
  for (let i = 0; i < positive.length; i++) {
    const m = positive[i];
    if (Math.abs(m - min) < Math.abs(best - min)) {
      best = m;
    }
  }
  return best;
}

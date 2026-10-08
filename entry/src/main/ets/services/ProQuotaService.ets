import { common } from "@kit.AbilityKit";
import { ApiConfig } from "../config/ApiConfig";
import { QuickTaskStore } from "../stores/QuickTaskStore";
import { ScheduledListStore } from "../stores/ScheduledListStore";
import { ensureProMembership, isMemberActive, openVipPurchase } from "../utils/PaywallNavigationUtil";

export const FREE_QUICK_TASK_LIMIT: number = 2;
export const FREE_SCHEDULED_TASK_LIMIT: number = 1;
export const FREE_DELAYED_START_MINUTES: number = 5;
export const FREE_DELAYED_START_MINUTES_LIST: number[] = [5, 10, 15];
const DEV_FREE_DELAYED_START_MINUTES: number = 1;

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

function isFreeAllowedDelayMinutes(delayMinutes: number): boolean {
  if (FREE_DELAYED_START_MINUTES_LIST.indexOf(delayMinutes) >= 0) {
    return true;
  }
  if (ApiConfig.isDevEnvironment() && delayMinutes === DEV_FREE_DELAYED_START_MINUTES) {
    return true;
  }
  return false;
}

export function ensureDelayMinutesAllowed(delayMinutes: number): boolean {
  if (delayMinutes <= 0) {
    return true;
  }
  if (isMemberActive()) {
    return true;
  }
  if (!isFreeAllowedDelayMinutes(delayMinutes)) {
    return ensureProMembership('delayed_start_limit', {
      proUnlock: true,
      reason: '自定义延时为 Pro 专属',
    });
  }
  return true;
}

export function ensureDelayStartAllowed(context: common.Context, delayMinutes: number): boolean {
  if (delayMinutes <= 0) {
    return true;
  }
  if (!ensureDelayMinutesAllowed(delayMinutes)) {
    return false;
  }
  return true;
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

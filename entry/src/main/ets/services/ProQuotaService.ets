import { common } from "@kit.AbilityKit";
import { ApiConfig } from "../config/ApiConfig";
import { QuickTaskStore } from "../stores/QuickTaskStore";
import { ScheduledListStore } from "../stores/ScheduledListStore";
import { ensureProMembership, isMemberActive } from "../utils/PaywallNavigationUtil";

export const FREE_QUICK_TASK_LIMIT: number = 2;
export const FREE_SCHEDULED_TASK_LIMIT: number = 1;
export const FREE_DELAYED_START_MINUTES: number = 5;
export const FREE_DELAYED_START_MINUTES_LIST: number[] = [5, 10, 15];
const DEV_FREE_DELAYED_START_MINUTES: number = 1;

export function getQuickTaskCount(): number {
  return QuickTaskStore.getTasks().length;
}

export function canCreateQuickTask(): boolean {
  if (isMemberActive()) {
    return true;
  }
  return getQuickTaskCount() < FREE_QUICK_TASK_LIMIT;
}

export function ensureQuickTaskQuota(): boolean {
  if (canCreateQuickTask()) {
    return true;
  }
  return ensureProMembership("quick_task_limit", {
    proUnlock: true,
    reason: `免费用户最多创建 ${FREE_QUICK_TASK_LIMIT} 个快捷任务`,
  });
}

export function getInitiatedScheduledTaskCount(): number {
  const sessions = ScheduledListStore.getAllSessions();
  let count = 0;
  for (let i = 0; i < sessions.length; i++) {
    if (sessions[i].viewer_role === "initiator") {
      count += 1;
    }
  }
  return count;
}

export function canCreateScheduledTask(): boolean {
  if (isMemberActive()) {
    return true;
  }
  return getInitiatedScheduledTaskCount() < FREE_SCHEDULED_TASK_LIMIT;
}

export function ensureScheduledTaskQuota(): boolean {
  if (canCreateScheduledTask()) {
    return true;
  }
  return ensureProMembership("scheduled_task_limit", {
    proUnlock: true,
    reason: `免费用户最多创建 ${FREE_SCHEDULED_TASK_LIMIT} 个定时契约`,
  });
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
    return ensureProMembership("delayed_start_limit", {
      proUnlock: true,
      reason: '免费用户可用 5、10、15 分钟延时',
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

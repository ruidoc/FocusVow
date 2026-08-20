import { common } from '@kit.AbilityKit';
import { readStoredString, writeStoredString } from './PreferencesService';

const EXIT_PLAN_IDS_KEY: string = 'exit_plan_ids';

function todayDateKey(nowAt: number = Date.now()): string {
  const date = new Date(nowAt);
  const year = date.getFullYear();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function parseExitPlanIds(raw: string): string[] {
  if (raw.length === 0) {
    return [];
  }
  return raw.split(',').filter((item: string) => item.length > 0);
}

export function loadExitPlanIds(context: common.Context, nowAt: number = Date.now()): string[] {
  const today = todayDateKey(nowAt);
  const all = parseExitPlanIds(readStoredString(context, EXIT_PLAN_IDS_KEY, ''));
  const todayIds = all.filter((item: string) => item.startsWith(`${today}:`));
  if (todayIds.length !== all.length) {
    writeStoredString(context, EXIT_PLAN_IDS_KEY, todayIds.join(','));
  }
  return todayIds;
}

export function addExitPlanId(context: common.Context, planId: string): void {
  if (planId.length === 0) {
    return;
  }
  const entry = `${todayDateKey()}:${planId}`;
  const existing = loadExitPlanIds(context);
  if (existing.includes(entry)) {
    return;
  }
  writeStoredString(context, EXIT_PLAN_IDS_KEY, [...existing, entry].join(','));
}

export function clearExitPlanIds(context: common.Context): void {
  writeStoredString(context, EXIT_PLAN_IDS_KEY, '');
}

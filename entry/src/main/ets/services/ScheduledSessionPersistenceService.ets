import { common } from '@kit.AbilityKit';
import { readStoredString, writeStoredString } from './PreferencesService';

const GUARD_INDEX_KEY: string = 'scheduled.guard.index';

export interface ScheduledGuardSnapshot {
  sessionId: string;
  title: string;
  startTime: string;
  endTime: string;
  repeatDays: number[];
  selectedTokens: string[];
  mode: 'shield' | 'allow';
}

function guardKey(sessionId: string): string {
  return `scheduled.guard.${sessionId}`;
}

export function loadScheduledGuardIndex(context: common.Context): string[] {
  const raw = readStoredString(context, GUARD_INDEX_KEY, '[]');
  try {
    return JSON.parse(raw) as string[];
  } catch {
    return [];
  }
}

function saveScheduledGuardIndex(context: common.Context, sessionIds: string[]): void {
  writeStoredString(context, GUARD_INDEX_KEY, JSON.stringify(sessionIds));
}

export function saveScheduledGuardSnapshot(
  context: common.Context,
  snapshot: ScheduledGuardSnapshot
): void {
  writeStoredString(context, guardKey(snapshot.sessionId), JSON.stringify(snapshot));
  const index = loadScheduledGuardIndex(context);
  if (!index.includes(snapshot.sessionId)) {
    saveScheduledGuardIndex(context, [...index, snapshot.sessionId]);
  }
}

export function loadScheduledGuardSnapshot(
  context: common.Context,
  sessionId: string
): ScheduledGuardSnapshot | null {
  const raw = readStoredString(context, guardKey(sessionId), '');
  if (raw.length === 0) {
    return null;
  }
  try {
    return JSON.parse(raw) as ScheduledGuardSnapshot;
  } catch {
    return null;
  }
}

export function removeScheduledGuardSnapshot(context: common.Context, sessionId: string): void {
  writeStoredString(context, guardKey(sessionId), '');
  const index = loadScheduledGuardIndex(context).filter((id: string) => id !== sessionId);
  saveScheduledGuardIndex(context, index);
}

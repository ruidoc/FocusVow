import { common } from '@kit.AbilityKit';
import { readStoredString, writeStoredString } from './PreferencesService';

const GUARD_INDEX_KEY: string = 'scheduled.guard.index';
const GUARD_ISSUE_INDEX_KEY: string = 'scheduled.guard.issue.index';

export interface ScheduledGuardSnapshot {
  sessionId: string;
  title: string;
  startTime: string;
  endTime: string;
  repeatDays: number[];
  selectedTokens: string[];
  mode: 'shield' | 'allow';
}

export interface ScheduledGuardSyncIssue {
  sessionId: string;
  title: string;
  message: string;
  updatedAt: number;
}

function guardKey(sessionId: string): string {
  return `scheduled.guard.${sessionId}`;
}

function guardIssueKey(sessionId: string): string {
  return `scheduled.guard.issue.${sessionId}`;
}

export function loadScheduledGuardIndex(context: common.Context): string[] {
  const raw = readStoredString(context, GUARD_INDEX_KEY, '[]');
  try {
    return JSON.parse(raw) as string[];
  } catch {
    return [];
  }
}

export function loadScheduledGuardIssueIndex(context: common.Context): string[] {
  const raw = readStoredString(context, GUARD_ISSUE_INDEX_KEY, '[]');
  try {
    return JSON.parse(raw) as string[];
  } catch {
    return [];
  }
}

function saveScheduledGuardIndex(context: common.Context, sessionIds: string[]): void {
  writeStoredString(context, GUARD_INDEX_KEY, JSON.stringify(sessionIds));
}

function saveScheduledGuardIssueIndex(context: common.Context, sessionIds: string[]): void {
  writeStoredString(context, GUARD_ISSUE_INDEX_KEY, JSON.stringify(sessionIds));
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

export function saveScheduledGuardSyncIssue(
  context: common.Context,
  issue: ScheduledGuardSyncIssue
): void {
  writeStoredString(context, guardIssueKey(issue.sessionId), JSON.stringify(issue));
  const index = loadScheduledGuardIssueIndex(context);
  if (!index.includes(issue.sessionId)) {
    saveScheduledGuardIssueIndex(context, [...index, issue.sessionId]);
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

export function loadScheduledGuardSyncIssue(
  context: common.Context,
  sessionId: string
): ScheduledGuardSyncIssue | null {
  const raw = readStoredString(context, guardIssueKey(sessionId), '');
  if (raw.length === 0) {
    return null;
  }
  try {
    return JSON.parse(raw) as ScheduledGuardSyncIssue;
  } catch {
    return null;
  }
}

export function loadScheduledGuardSyncIssues(context: common.Context): ScheduledGuardSyncIssue[] {
  const issues: ScheduledGuardSyncIssue[] = [];
  for (const sessionId of loadScheduledGuardIssueIndex(context)) {
    const issue = loadScheduledGuardSyncIssue(context, sessionId);
    if (issue) {
      issues.push(issue);
    }
  }
  return issues;
}

export function removeScheduledGuardSnapshot(context: common.Context, sessionId: string): void {
  writeStoredString(context, guardKey(sessionId), '');
  const index = loadScheduledGuardIndex(context).filter((id: string) => id !== sessionId);
  saveScheduledGuardIndex(context, index);
}

export function removeScheduledGuardSyncIssue(context: common.Context, sessionId: string): void {
  writeStoredString(context, guardIssueKey(sessionId), '');
  const index = loadScheduledGuardIssueIndex(context).filter((id: string) => id !== sessionId);
  saveScheduledGuardIssueIndex(context, index);
}

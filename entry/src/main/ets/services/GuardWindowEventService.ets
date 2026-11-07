import { common } from '@kit.AbilityKit';
import { readStoredString, writeStoredString } from './PreferencesService';
import { DuoApiService } from './DuoApiService';
import { HttpService } from './HttpService';
import { FocusStartedNotifyService } from './FocusStartedNotifyService';

const STORE_KEY: string = 'guard.window.events';

export interface GuardWindowEvent {
  occurrence_id: string;
  session_id: string;
  plan_id: string;
  kind: 'start' | 'stop';
  result: string;
  fail_reason: string;
  started_at: number;
  ended_at: number;
  title: string;
  duration_min: number;
  timer_mode: string;
  mode: string;
}

export function scheduledOccurrenceId(sessionId: string, startedAt: number): string {
  return `${sessionId}:${startedAt}`;
}

function loadEvents(context: common.Context): GuardWindowEvent[] {
  const raw = readStoredString(context, STORE_KEY, '');
  if (raw.length === 0) {
    return [];
  }
  try {
    const parsed = JSON.parse(raw) as GuardWindowEvent[];
    if (!Array.isArray(parsed)) {
      return [];
    }
    const events: GuardWindowEvent[] = [];
    for (let i = 0; i < parsed.length; i++) {
      const item = parsed[i];
      events.push({
        occurrence_id: item.occurrence_id ?? '',
        session_id: item.session_id ?? '',
        plan_id: item.plan_id ?? '',
        kind: item.kind === 'stop' ? 'stop' : 'start',
        result: item.result ?? '',
        fail_reason: item.fail_reason ?? '',
        started_at: item.started_at ?? 0,
        ended_at: item.ended_at ?? 0,
        title: item.title ?? '',
        duration_min: item.duration_min ?? 0,
        timer_mode: item.timer_mode && item.timer_mode.length > 0 ? item.timer_mode : 'countdown',
        mode: item.mode && item.mode.length > 0 ? item.mode : 'allow',
      });
    }
    return events;
  } catch {
    return [];
  }
}

function saveEvents(context: common.Context, events: GuardWindowEvent[]): void {
  writeStoredString(context, STORE_KEY, JSON.stringify(events));
}

export function upsertGuardWindowEvent(context: common.Context, event: GuardWindowEvent): void {
  const events = loadEvents(context);
  let replaced = false;
  const next: GuardWindowEvent[] = [];
  for (let i = 0; i < events.length; i++) {
    const item = events[i];
    if (item.occurrence_id === event.occurrence_id && item.kind === event.kind) {
      next.push(event);
      replaced = true;
    } else {
      next.push(item);
    }
  }
  if (!replaced) {
    next.push(event);
  }
  saveEvents(context, next);
}

export function removeGuardWindowOccurrence(context: common.Context, occurrenceId: string): void {
  const events = loadEvents(context);
  const next: GuardWindowEvent[] = [];
  for (let i = 0; i < events.length; i++) {
    if (events[i].occurrence_id !== occurrenceId) {
      next.push(events[i]);
    }
  }
  saveEvents(context, next);
}

export function removeGuardWindowStart(context: common.Context, occurrenceId: string): void {
  const events = loadEvents(context);
  const next: GuardWindowEvent[] = [];
  for (let i = 0; i < events.length; i++) {
    const item = events[i];
    if (!(item.occurrence_id === occurrenceId && item.kind === 'start')) {
      next.push(item);
    }
  }
  saveEvents(context, next);
}

async function postOnceSync(
  context: common.Context,
  event: GuardWindowEvent,
  startedAt: number,
  endedAt: number,
  result: string,
  failReason: string
): Promise<boolean> {
  const durationMin = Math.max(1, event.duration_min);
  const counted = Math.max(0, Math.round((endedAt - startedAt) / 60000));
  const timerMode = event.timer_mode === 'countup' ? 'countup' : 'countdown';
  let actualMin = counted;
  if (result === 'SUCCESS') {
    actualMin = timerMode === 'countup' ? Math.max(durationMin, counted) : durationMin;
  }
  const body: Record<string, Object> = {
    'kind': 'solo_instant',
    'client_key': `solo_plan_${event.plan_id}`,
    'result': result === 'VIOLATION' ? 'VIOLATION' : 'SUCCESS',
    'started_at': startedAt,
    'ended_at': endedAt,
    'title': event.title,
    'duration_min': durationMin,
    'actual_min': actualMin,
    'mode': event.mode.length > 0 ? event.mode : 'allow',
    'participation_mode': 'solo',
    'timer_mode': timerMode,
    'plan_id': event.plan_id,
    'fail_reason': failReason,
  };
  const response = await HttpService.post('/focus/sync', body, true, true, context);
  return response.statusCode === 200;
}

async function flushOnceWindow(
  context: common.Context,
  occurrenceId: string,
  start: GuardWindowEvent | null,
  stop: GuardWindowEvent | null
): Promise<void> {
  const source = stop ?? start;
  if (source === null) {
    return;
  }
  if (stop !== null) {
    const startedAt = start !== null ? start.started_at : stop.started_at;
    const endedAt = stop.ended_at > 0 ? stop.ended_at : Date.now();
    const ok = await postOnceSync(
      context,
      source,
      startedAt,
      endedAt,
      stop.result === 'VIOLATION' ? 'VIOLATION' : 'SUCCESS',
      stop.fail_reason
    );
    if (ok) {
      removeGuardWindowOccurrence(context, occurrenceId);
    }
    return;
  }
  if (start === null) {
    return;
  }
  const windowEnd = start.started_at + Math.max(1, start.duration_min) * 60 * 1000;
  if (start.timer_mode === 'countup' || Date.now() < windowEnd) {
    const notified = await FocusStartedNotifyService.reportAndWait(context, {
      scene: 'delayed_solo_start',
      durationMin: start.duration_min,
      sessionType: 'solo_once',
      title: start.title,
      timerMode: start.timer_mode,
      planId: start.plan_id,
      startedAtMs: start.started_at,
    });
    if (notified) {
      removeGuardWindowStart(context, occurrenceId);
    }
    return;
  }
  const ok = await postOnceSync(context, start, start.started_at, windowEnd, 'SUCCESS', '');
  if (ok) {
    removeGuardWindowOccurrence(context, occurrenceId);
  }
}

export async function flushGuardWindowEvents(context: common.Context): Promise<void> {
  const events = loadEvents(context);
  const seen: string[] = [];
  for (let i = 0; i < events.length; i++) {
    const id = events[i].occurrence_id;
    if (seen.indexOf(id) < 0) {
      seen.push(id);
    }
  }
  for (let i = 0; i < seen.length; i++) {
    const occurrenceId = seen[i];
    let start: GuardWindowEvent | null = null;
    let stop: GuardWindowEvent | null = null;
    for (let j = 0; j < events.length; j++) {
      const item = events[j];
      if (item.occurrence_id !== occurrenceId) {
        continue;
      }
      if (item.kind === 'start') {
        start = item;
      } else if (item.kind === 'stop') {
        stop = item;
      }
    }
    const source = stop ?? start;
    if (source === null) {
      continue;
    }
    if (source.session_id.length === 0) {
      if (source.plan_id.startsWith('once_')) {
        await flushOnceWindow(context, occurrenceId, start, stop);
      }
      continue;
    }
    if (stop !== null) {
      const startedAt = start !== null ? start.started_at : stop.started_at;
      const response = await DuoApiService.completeScheduledWindow(
        source.session_id,
        context,
        occurrenceId,
        startedAt,
        stop.ended_at > 0 ? stop.ended_at : Date.now(),
        stop.result === 'VIOLATION' ? 'VIOLATION' : 'SUCCESS',
        stop.fail_reason
      );
      if (response.statusCode === 200) {
        removeGuardWindowOccurrence(context, occurrenceId);
      }
      continue;
    }
    if (start === null) {
      continue;
    }
    const windowEnd = start.started_at + Math.max(1, start.duration_min) * 60 * 1000;
    if (Date.now() < windowEnd) {
      const response = await DuoApiService.activateScheduledSession(source.session_id, context);
      if (response.statusCode === 200) {
        removeGuardWindowStart(context, occurrenceId);
      }
      continue;
    }
    const response = await DuoApiService.completeScheduledWindow(
      source.session_id,
      context,
      occurrenceId,
      start.started_at,
      windowEnd,
      'SUCCESS',
      ''
    );
    if (response.statusCode === 200) {
      removeGuardWindowOccurrence(context, occurrenceId);
    }
  }
}

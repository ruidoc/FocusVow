export interface StatsDayItem {
  date: string;
  actualMins: number;
}

export interface StatsByDay {
  prevActualMins: number;
  items: StatsDayItem[];
}

export interface CheckinDayFlags {
  date: string;
  focus: boolean;
  wake: boolean;
  sleep: boolean;
}

export interface CheckinByDay {
  streakDays: number;
  items: CheckinDayFlags[];
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

export function formatDateKey(date: Date): string {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

export function statsAnchorDate(period: string): string {
  const now = new Date();
  if (period === 'yesterday') {
    now.setDate(now.getDate() - 1);
  }
  return formatDateKey(now);
}

/** 今日/昨日/本周且不超过 7 天时，补齐锚点所在周的周一到周日。 */
export function alignWeekDays(items: StatsDayItem[], period: string): StatsDayItem[] {
  if (items.length === 0 || items.length > 7) {
    return items;
  }
  if (period !== 'today' && period !== 'yesterday' && period !== 'week') {
    return items;
  }
  const anchor = new Date(`${statsAnchorDate(period)}T12:00:00`);
  const weekday = anchor.getDay();
  const mondayOffset = weekday === 0 ? -6 : 1 - weekday;
  const start = new Date(anchor);
  start.setDate(anchor.getDate() + mondayOffset);
  const byDate: Record<string, number> = {};
  for (let i = 0; i < items.length; i++) {
    byDate[items[i].date.slice(0, 10)] = items[i].actualMins;
  }
  const aligned: StatsDayItem[] = [];
  for (let i = 0; i < 7; i++) {
    const day = new Date(start);
    day.setDate(start.getDate() + i);
    const key = formatDateKey(day);
    aligned.push({ date: key, actualMins: byDate[key] ?? 0 });
  }
  return aligned;
}

export function weekdayLabel(dateKey: string): string {
  const date = new Date(`${dateKey.slice(0, 10)}T12:00:00`);
  const labels = ['日', '一', '二', '三', '四', '五', '六'];
  return labels[date.getDay()];
}

export function dayOfMonth(dateKey: string): string {
  const n = Number(dateKey.slice(8, 10));
  if (!Number.isFinite(n) || n <= 0) {
    return '';
  }
  return `${n}`;
}

export function isFutureDate(dateKey: string): boolean {
  return dateKey.slice(0, 10) > formatDateKey(new Date());
}

export function alignCheckinWeekDays(items: CheckinDayFlags[], period: string): CheckinDayFlags[] {
  const stubs: StatsDayItem[] = [];
  for (let i = 0; i < items.length; i++) {
    stubs.push({ date: items[i].date, actualMins: 0 });
  }
  const aligned = alignWeekDays(stubs, period);
  if (aligned === stubs) {
    return items;
  }
  const byDate: Record<string, CheckinDayFlags> = {};
  for (let i = 0; i < items.length; i++) {
    byDate[items[i].date.slice(0, 10)] = items[i];
  }
  const result: CheckinDayFlags[] = [];
  for (let i = 0; i < aligned.length; i++) {
    const key = aligned[i].date.slice(0, 10);
    const found = byDate[key];
    result.push(found ?? { date: key, focus: false, wake: false, sleep: false });
  }
  return result;
}

export function parseStatsByDay(data: Object | undefined): StatsByDay | null {
  const raw = data as Record<string, Object> | undefined;
  if (!raw) {
    return null;
  }
  const items: StatsDayItem[] = [];
  const rawItems = raw['items'] as Object[] | undefined;
  if (rawItems) {
    for (let i = 0; i < rawItems.length; i++) {
      const row = rawItems[i] as Record<string, Object>;
      const date = String(row['date'] ?? '');
      if (date.length === 0) {
        continue;
      }
      items.push({ date: date, actualMins: Number(row['actual_mins'] ?? 0) });
    }
  }
  return {
    prevActualMins: Number(raw['prev_actual_mins'] ?? 0),
    items: items,
  };
}

function readChecked(items: Object[] | undefined, into: Record<string, CheckinDayFlags>, key: string): void {
  if (!items) {
    return;
  }
  for (let i = 0; i < items.length; i++) {
    const row = items[i] as Record<string, Object>;
    const date = String(row['date'] ?? '').slice(0, 10);
    if (date.length === 0) {
      continue;
    }
    const current: CheckinDayFlags = into[date] ?? { date: date, focus: false, wake: false, sleep: false };
    if (key === 'focus') {
      current.focus = row['checked'] === true;
    } else if (key === 'wake') {
      current.wake = row['checked'] === true;
    } else {
      current.sleep = row['checked'] === true;
    }
    into[date] = current;
  }
}

export function parseCheckinByDay(data: Object | undefined): CheckinByDay | null {
  const raw = data as Record<string, Object> | undefined;
  if (!raw) {
    return null;
  }
  const map: Record<string, CheckinDayFlags> = {};
  const focus = raw['focus'] as Record<string, Object> | undefined;
  const wake = raw['wake'] as Record<string, Object> | undefined;
  const sleep = raw['sleep'] as Record<string, Object> | undefined;
  readChecked(focus?.['items'] as Object[] | undefined, map, 'focus');
  readChecked(wake?.['items'] as Object[] | undefined, map, 'wake');
  readChecked(sleep?.['items'] as Object[] | undefined, map, 'sleep');
  const dates = Object.keys(map).sort();
  const items: CheckinDayFlags[] = [];
  for (let i = 0; i < dates.length; i++) {
    items.push(map[dates[i]]);
  }
  return {
    streakDays: Number(raw['streak_days'] ?? 0),
    items: items,
  };
}

export function durationDeltaText(period: string, currentMins: number, prevMins: number): string {
  const delta = Math.round(currentMins) - Math.round(prevMins);
  const abs = Math.abs(delta);
  const duration = abs < 60 ? `${abs}分钟` : (abs % 60 === 0 ? `${Math.floor(abs / 60)}小时` : `${Math.floor(abs / 60)}小时${abs % 60}分钟`);
  if (period === 'today') {
    if (delta === 0) {
      return '今日与昨日持平';
    }
    return delta > 0 ? `今日比昨日多 ${duration}` : `今日比昨日少 ${duration}`;
  }
  const base = period === 'yesterday' ? '前日' : (period === 'week' ? '上周' : '上月');
  if (delta === 0) {
    return `与${base}持平`;
  }
  return delta > 0 ? `比${base}多 ${duration}` : `比${base}少 ${duration}`;
}

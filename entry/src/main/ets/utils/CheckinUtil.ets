export type CheckinKind = 'wake' | 'sleep' | 'focus';

const WAKE_START: number = 5 * 60;
const WAKE_END: number = 8 * 60 + 30;
const SLEEP_START: number = 21 * 60;
const SLEEP_END: number = 23 * 60 + 30;

export interface CheckinFocusMinutesParts {
  total: number;
  hours: number;
  remainMinutes: number;
}

export function normalizeCheckinFocusMinutes(minutes: number): number {
  return Math.max(0, Math.floor(minutes));
}

export function splitCheckinFocusMinutes(minutes: number): CheckinFocusMinutesParts {
  const total = normalizeCheckinFocusMinutes(minutes);
  const parts: CheckinFocusMinutesParts = {
    total: total,
    hours: Math.floor(total / 60),
    remainMinutes: total % 60,
  };
  return parts;
}

export function formatCheckinWindowRange(startMin: number, endMin: number): string {
  const fmt = (total: number): string => {
    const h = Math.floor(total / 60);
    const m = total % 60;
    const mm = m < 10 ? `0${m}` : `${m}`;
    const hh = h < 10 ? `0${h}` : `${h}`;
    return `${hh}:${mm}`;
  };
  return `${fmt(startMin)} – ${fmt(endMin)}`;
}

export function wakeWindowLabel(): string {
  return formatCheckinWindowRange(WAKE_START, WAKE_END);
}

export function sleepWindowLabel(): string {
  return formatCheckinWindowRange(SLEEP_START, SLEEP_END);
}

function nowMinutes(): number {
  const now = new Date();
  return now.getHours() * 60 + now.getMinutes();
}

export function isWakeCheckinOpen(): boolean {
  const mins = nowMinutes();
  return mins >= WAKE_START && mins <= WAKE_END;
}

export function isSleepCheckinOpen(): boolean {
  const mins = nowMinutes();
  return mins >= SLEEP_START && mins <= SLEEP_END;
}

export function checkinTitle(kind: CheckinKind): string {
  if (kind === 'wake') {
    return '早起打卡';
  }
  if (kind === 'sleep') {
    return '早睡打卡';
  }
  return '专注打卡';
}

export function checkinQuote(kind: CheckinKind): string {
  if (kind === 'wake') {
    return '晨光正好，去成为想成为的人。';
  }
  if (kind === 'sleep') {
    return '今日收官，卸下疲惫，晚安好梦。';
  }
  return '保持专注，时间会给你答案。';
}

export function checkinTag(kind: CheckinKind): string {
  if (kind === 'wake') {
    return '晨曦契约 · 开启一天';
  }
  if (kind === 'sleep') {
    return '今日圆满 · 松弛收尾';
  }
  return '深度心流 · 沉浸专注';
}

export interface ShareCardItem {
  id: string;
  imageUrl: string;
  title: string;
  subtitle: string;
  dark: boolean;
  sortOrder: number;
}

export function fallbackShareCard(kind: CheckinKind): ShareCardItem {
  return {
    id: `fallback-${kind}`,
    imageUrl: '',
    title: checkinQuote(kind),
    subtitle: '',
    dark: kind === 'sleep',
    sortOrder: 0,
  };
}

export function parseShareCards(data: Object | undefined, kind: CheckinKind): ShareCardItem[] {
  const list = data as Object[] | undefined;
  const cards: ShareCardItem[] = [];
  if (!list) {
    return [fallbackShareCard(kind)];
  }
  for (let i = 0; i < list.length; i++) {
    const row = list[i] as Record<string, Object>;
    if (row['enabled'] === 0 || row['enabled'] === '0') {
      continue;
    }
    const title = String(row['title_zh'] ?? row['title'] ?? '').trim();
    cards.push({
      id: String(row['id'] ?? `card-${i}`),
      imageUrl: String(row['image_url'] ?? '').trim(),
      title: title.length > 0 ? title : checkinQuote(kind),
      subtitle: String(row['subtitle_zh'] ?? row['subtitle'] ?? '').trim(),
      dark: String(row['color_mode'] ?? '') === 'dark',
      sortOrder: Number(row['sort_order'] ?? 0),
    });
  }
  cards.sort((a: ShareCardItem, b: ShareCardItem) => {
    return a.sortOrder - b.sortOrder;
  });
  if (cards.length === 0) {
    return [fallbackShareCard(kind)];
  }
  return cards;
}

export interface SleepPlanStats {
  total_days: number;
  failed_days: number;
  streak_days: number;
  success_rate: number;
}

export interface SleepHistoryItem {
  id: string;
  date: string;
  status: 'completed' | 'failed';
  actual_min: number;
  total_min: number;
  start_min: number;
}

export function parseSleepPlanStats(raw: Object | undefined): SleepPlanStats | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const row = raw as Record<string, Object>;
  return {
    total_days: Math.max(0, Math.floor(Number(row['total_days'] ?? 0))),
    failed_days: Math.max(0, Math.floor(Number(row['failed_days'] ?? 0))),
    streak_days: Math.max(0, Math.floor(Number(row['streak_days'] ?? 0))),
    success_rate: Math.max(0, Math.floor(Number(row['success_rate'] ?? 0))),
  };
}

export function parseSleepHistoryItem(raw: Object | undefined): SleepHistoryItem | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const row = raw as Record<string, Object>;
  const date = String(row['date'] ?? '');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    return null;
  }
  const id = String(row['id'] ?? '');
  if (id.length === 0) {
    return null;
  }
  return {
    id,
    date,
    status: row['status'] === 'completed' ? 'completed' : 'failed',
    actual_min: Math.max(0, Math.round(Number(row['actual_min'] ?? 0))),
    total_min: Math.max(0, Math.round(Number(row['total_min'] ?? 0))),
    start_min: Math.max(0, Math.round(Number(row['start_min'] ?? 0))),
  };
}

export function formatSleepRecordDay(date: string): string {
  const parts = date.split('-');
  if (parts.length !== 3) {
    return date;
  }
  const year = Number(parts[0]);
  const month = Number(parts[1]);
  const day = Number(parts[2]);
  const now = new Date();
  if (year === now.getFullYear()) {
    return `${month}月${day}日`;
  }
  return `${year}年${month}月${day}日`;
}

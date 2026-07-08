function pad2(value: number): string {
  return value.toString().padStart(2, '0');
}

export function parseCompletedAtToDate(raw: string, fallbackDate: string): Date | null {
  if (raw.length > 0) {
    const parsed = new Date(raw);
    if (!isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  if (fallbackDate.length > 0) {
    const fallback = new Date(`${fallbackDate}T00:00:00`);
    if (!isNaN(fallback.getTime())) {
      return fallback;
    }
  }
  return null;
}

export function formatStatsDateTimeLabel(raw: string, fallbackDate: string): string {
  const date = parseCompletedAtToDate(raw, fallbackDate);
  if (!date) {
    return fallbackDate;
  }
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())} ${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

export function formatChineseDateTime(raw: string, fallbackDate: string): string {
  const date = parseCompletedAtToDate(raw, fallbackDate);
  if (!date) {
    return fallbackDate;
  }
  return `${date.getFullYear()}年${pad2(date.getMonth() + 1)}月${pad2(date.getDate())}日 ${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

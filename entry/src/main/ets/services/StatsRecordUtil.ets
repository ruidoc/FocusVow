import {
  DuoShameDay,
  DuoShameRecord,
  DuoTimelineDay,
  DuoTimelineRecord
} from '../models/DuoModel';

export const STATS_RECORD_SECTION_BG_COLOR: string = 'rgba(255, 255, 255, 0.72)';
export const HONOR_SECTION_BORDER_COLOR: string = 'rgba(31,157,85,0.18)';
export const HONOR_SECTION_DIVIDER_COLOR: string = 'rgba(31,157,85,0.10)';
export const SHAME_SECTION_BORDER_COLOR: string = '#F3D6D6';
export const SHAME_SECTION_DIVIDER_COLOR: string = 'rgba(243, 214, 214, 0.65)';

export type StatsPeriod = 'today' | 'week' | 'month';
export type StatsDetailSection = 'timeline' | 'shame';

export interface HonorRecordItem {
  day: string;
  record: DuoTimelineRecord;
}

export interface ShameRecordItem {
  day: string;
  record: DuoShameRecord;
}

export function getStatsPeriodLabel(period: StatsPeriod): string {
  if (period === 'week') {
    return '本周';
  }
  if (period === 'month') {
    return '本月';
  }
  return '今日';
}

export function getStatsDetailPageTitle(period: StatsPeriod, section: StatsDetailSection): string {
  const periodLabel = getStatsPeriodLabel(period);
  if (section === 'shame') {
    return `${periodLabel}违约耻辱柱`;
  }
  return `${periodLabel}履约荣誉墙`;
}

export function formatStatsDateTimeLabel(raw: string, fallbackDate: string): string {
  if (raw.length === 0) {
    return fallbackDate;
  }
  const normalized = raw.replace('T', ' ');
  const parts = normalized.split(' ');
  const datePart = parts.length > 0 ? parts[0] : fallbackDate;
  if (parts.length < 2) {
    return datePart;
  }
  const timePart = parts[1];
  const trimmedTime = timePart.length >= 5 ? timePart.substring(0, 5) : timePart;
  return `${datePart} ${trimmedTime}`;
}

export function getParticipationModeTag(participationMode: string): string {
  return participationMode === 'duo' ? '搭子' : '单人';
}

export function flattenTimelineDays(days: DuoTimelineDay[]): HonorRecordItem[] {
  const items: HonorRecordItem[] = [];
  for (let i = 0; i < days.length; i++) {
    const day = days[i];
    for (let j = 0; j < day.records.length; j++) {
      items.push({ day: day.date, record: day.records[j] });
    }
  }
  return items;
}

export function flattenShameDays(days: DuoShameDay[]): ShameRecordItem[] {
  const items: ShameRecordItem[] = [];
  for (let i = 0; i < days.length; i++) {
    const day = days[i];
    for (let j = 0; j < day.records.length; j++) {
      items.push({ day: day.date, record: day.records[j] });
    }
  }
  return items;
}

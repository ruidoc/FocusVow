import { formatStatsDateTimeLabel as formatStatsDateTimeLabelFromUtil } from '../common/DateTimeFormatUtil';
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
export type StatsDetailSection = 'timeline' | 'shame' | 'byTask';

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
  if (section === 'byTask') {
    return `${periodLabel}专注时长分布`;
  }
  return `${periodLabel}履约荣誉墙`;
}

export interface DurationLabelPart {
  kind: 'number' | 'unit';
  value: string;
}

/** 履约时长拆成数字 / 单位，方便分组件排版调间距 */
export function formatSuccessDurationParts(minutes: number): DurationLabelPart[] {
  const mins = Math.max(0, Math.floor(minutes));
  if (mins < 60) {
    return [
      { kind: 'number', value: String(mins) },
      { kind: 'unit', value: '分钟' }
    ];
  }
  const hours = Math.floor(mins / 60);
  const remainMinutes = mins % 60;
  if (remainMinutes === 0) {
    return [
      { kind: 'number', value: String(hours) },
      { kind: 'unit', value: '小时' }
    ];
  }
  return [
    { kind: 'number', value: String(hours) },
    { kind: 'unit', value: 'h' },
    { kind: 'number', value: String(remainMinutes) },
    { kind: 'unit', value: 'm' }
  ];
}

/** 对齐 RN TaskDurationChart.formatMinutes：如 1 小时 45 分钟 */
export function formatTaskDurationMinutes(minutes: number): string {
  const mins = Math.max(0, Math.floor(minutes));
  if (mins <= 0) {
    return '0 分钟';
  }
  if (mins < 60) {
    return `${mins} 分钟`;
  }
  const hours = Math.floor(mins / 60);
  const remainMinutes = mins % 60;
  if (remainMinutes === 0) {
    return `${hours} 小时`;
  }
  return `${hours} 小时 ${remainMinutes} 分钟`;
}

export function formatSuccessDurationLabel(minutes: number): string {
  const parts = formatSuccessDurationParts(minutes);
  let out = '';
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    if (part.kind === 'number') {
      if (out.length > 0) {
        out += ' ';
      }
      out += part.value;
    } else if (part.value === 'h' || part.value === 'm') {
      out += part.value;
    } else {
      out += ` ${part.value}`;
    }
  }
  return out;
}

export function formatStatsDateTimeLabel(raw: string, fallbackDate: string): string {
  return formatStatsDateTimeLabelFromUtil(raw, fallbackDate);
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

export function countDuoBlast(shame: DuoShameDay[]): number {
  let count = 0;
  for (let i = 0; i < shame.length; i++) {
    const day = shame[i];
    for (let j = 0; j < day.records.length; j++) {
      const record = day.records[j];
      if (record.participation_mode === 'duo' && record.breach_role === 'violator') {
        count += 1;
      }
    }
  }
  return count;
}

export function getDuoBlastReputationHint(count: number): string {
  if (count <= 0) {
    return '信誉良好';
  }
  if (count === 1) {
    return '首犯可谅';
  }
  if (count === 2) {
    return '偶有失手';
  }
  if (count <= 4) {
    return '搭子请当心';
  }
  return '信誉堪忧';
}

export function getContractWinRateHint(
  successRate: number,
  completedCount: number,
  failedCount: number
): string {
  const total = completedCount + failedCount;
  if (total <= 0) {
    return '暂无履约记录';
  }
  if (successRate >= 100) {
    return '全胜纪录';
  }
  if (successRate >= 85) {
    return '守约可靠';
  }
  if (successRate >= 65) {
    return '基本稳得住';
  }
  if (successRate >= 45) {
    return '胜负参半';
  }
  if (successRate >= 25) {
    return '失守偏多';
  }
  return '亟需调整';
}

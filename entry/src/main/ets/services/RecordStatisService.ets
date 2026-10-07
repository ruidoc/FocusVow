import { common } from '@kit.AbilityKit';
import { HttpService } from './HttpService';

/** 与 RN useRecordStore.getStatis / GET /record/statis 字段一致 */
export interface RecordStatisSnapshot {
  actual_mins: number;
  task_count: number;
  fail_count: number;
  success_rate: number;
  total_mins: number;
}

function asNumber(value: Object | undefined, fallback: number = 0): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

export function parseRecordStatis(data: Object | undefined): RecordStatisSnapshot | null {
  if (!data || typeof data !== 'object') {
    return null;
  }
  const row = data as Record<string, Object>;
  return {
    actual_mins: asNumber(row['actual_mins']),
    task_count: asNumber(row['task_count']),
    fail_count: asNumber(row['fail_count']),
    success_rate: asNumber(row['success_rate']),
    total_mins: asNumber(row['total_mins']),
  };
}

const LOG_TAG: string = 'RecordStatis';

export class RecordStatisService {
  static async fetch(context?: common.Context): Promise<RecordStatisSnapshot | null> {
    console.info(`[${LOG_TAG}] GET /record/statis ...`);
    const response = await HttpService.get('/record/statis', true, false, context);
    const code = Number(response.statusCode);
    const hasData = response.data !== undefined && response.data !== null;
    if (code !== 200) {
      console.warn(
        `[${LOG_TAG}] failed status=${response.statusCode} hasData=${hasData} msg=${response.message ?? ''}`,
      );
      return null;
    }
    const parsed = parseRecordStatis(response.data);
    if (!parsed) {
      console.warn(`[${LOG_TAG}] status=200 but data invalid hasData=${hasData}`);
      return null;
    }
    console.info(
      `[${LOG_TAG}] ok actual_mins=${parsed.actual_mins} task_count=${parsed.task_count} fail_count=${parsed.fail_count}`,
    );
    return parsed;
  }
}

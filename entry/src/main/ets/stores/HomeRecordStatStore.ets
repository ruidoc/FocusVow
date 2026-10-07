import { common } from '@kit.AbilityKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { RecordStatisService, RecordStatisSnapshot } from '../services/RecordStatisService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';
import { UserStore } from './UserStore';

export type { RecordStatisSnapshot };

function syncAppStorageValue<T>(key: string, value: T): void {
  AppStorage.setOrCreate<T>(key, value);
}

function clearHomeRecordStatis(): void {
  syncAppStorageValue(StoreKeys.HomeActualMins, 0);
  syncAppStorageValue(StoreKeys.HomeTaskCount, 0);
  syncAppStorageValue(StoreKeys.HomeFailCount, 0);
  syncAppStorageValue(StoreKeys.HomeSuccessRate, 0);
}

const LOG_TAG: string = 'HomeRecordStat';

const EMPTY_HOME_STATIS: RecordStatisSnapshot = {
  actual_mins: 0,
  task_count: 0,
  fail_count: 0,
  success_rate: 0,
  total_mins: 0,
};

function publishHomeRecordStatis(statis: RecordStatisSnapshot): void {
  syncAppStorageValue(StoreKeys.HomeActualMins, statis.actual_mins);
  syncAppStorageValue(StoreKeys.HomeTaskCount, statis.task_count);
  syncAppStorageValue(StoreKeys.HomeFailCount, statis.fail_count);
  syncAppStorageValue(StoreKeys.HomeSuccessRate, statis.success_rate);
}

/** 与 RN useRecordStore.getStatis → GET /record/statis */
export async function refreshHomeRecordStatis(context?: common.UIAbilityContext): Promise<RecordStatisSnapshot | null> {
  bootstrapStores();
  const hostContext = context ?? AppContextHolder.getAbility() ?? undefined;
  if (hostContext) {
    UserStore.hydrate(hostContext);
  }
  const loggedIn = UserStore.isLoggedIn();
  console.info(`[${LOG_TAG}] refresh start loggedIn=${loggedIn}`);
  if (!loggedIn) {
    clearHomeRecordStatis();
    console.info(`[${LOG_TAG}] skip: not logged in, cleared home stats`);
    return EMPTY_HOME_STATIS;
  }
  const statis = await RecordStatisService.fetch(hostContext);
  if (!statis) {
    console.warn(`[${LOG_TAG}] refresh done: fetch returned null (see RecordStatis / HttpService logs)`);
    return null;
  }
  publishHomeRecordStatis(statis);
  console.info(
    `[${LOG_TAG}] refresh ok actual_mins=${statis.actual_mins} task_count=${statis.task_count} fail_count=${statis.fail_count}`,
  );
  return statis;
}

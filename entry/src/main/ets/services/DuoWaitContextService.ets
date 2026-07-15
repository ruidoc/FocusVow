import { DuoSessionView } from '../models/DuoModel';
import { PageRoutes, pushRoute } from '../router/PageRoutes';
import { DuoBgSyncService } from './DuoBgSyncService';
import { StoreKeys } from '../stores/StoreKeys';
import { bootstrapStores } from '../stores/StoreBootstrap';

bootstrapStores();

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

function resolveWaitExpireAtMs(session: DuoSessionView): number {
  if (session.expire_at && session.expire_at.length > 0) {
    const ms = new Date(session.expire_at).getTime();
    if (Number.isFinite(ms) && ms > 0) {
      return ms;
    }
  }
  return Date.now() + 10 * 60 * 1000;
}

export function setInstantDuoWait(
  session: DuoSessionView,
  title: string,
  durationMin: number
): void {
  const expireAt = resolveWaitExpireAtMs(session);
  syncAppStorageValue(StoreKeys.DuoWaitSessionId, session.session_id);
  syncAppStorageValue(StoreKeys.DuoWaitTitle, title);
  syncAppStorageValue(StoreKeys.DuoWaitInviteText, session.invite_text ?? '');
  syncAppStorageValue(StoreKeys.DuoWaitIsScheduled, false);
  syncAppStorageValue(StoreKeys.DuoWaitScheduleLabel, '');
  syncAppStorageValue(StoreKeys.DuoWaitDurationMin, durationMin);
  syncAppStorageValue(StoreKeys.DuoWaitExpireAtMs, expireAt);
  syncAppStorageValue(StoreKeys.DuoWaitStartedAtMs, Date.now());
  DuoBgSyncService.ensure();
}

export function setScheduledDuoWait(session: DuoSessionView, scheduleLabel: string): void {
  syncAppStorageValue(StoreKeys.DuoWaitSessionId, session.session_id);
  syncAppStorageValue(StoreKeys.DuoWaitTitle, session.title);
  syncAppStorageValue(StoreKeys.DuoWaitInviteText, session.invite_text ?? '');
  syncAppStorageValue(StoreKeys.DuoWaitIsScheduled, true);
  syncAppStorageValue(StoreKeys.DuoWaitScheduleLabel, scheduleLabel);
  syncAppStorageValue(StoreKeys.DuoWaitDurationMin, 0);
  syncAppStorageValue(StoreKeys.DuoWaitExpireAtMs, 0);
  syncAppStorageValue(StoreKeys.DuoWaitStartedAtMs, 0);
}

export function clearDuoWaitContext(): void {
  syncAppStorageValue(StoreKeys.DuoWaitSessionId, '');
  syncAppStorageValue(StoreKeys.DuoWaitTitle, '');
  syncAppStorageValue(StoreKeys.DuoWaitInviteText, '');
  syncAppStorageValue(StoreKeys.DuoWaitIsScheduled, false);
  syncAppStorageValue(StoreKeys.DuoWaitScheduleLabel, '');
  syncAppStorageValue(StoreKeys.DuoWaitDurationMin, 0);
  syncAppStorageValue(StoreKeys.DuoWaitExpireAtMs, 0);
  syncAppStorageValue(StoreKeys.DuoWaitStartedAtMs, 0);
  DuoBgSyncService.ensure();
}

/** 等待页拉到服务端 expire_at 后同步，保证后台通知倒计时准确 */
export function syncDuoWaitExpireAt(expireAtIso?: string): void {
  if (!expireAtIso || expireAtIso.length === 0) {
    return;
  }
  const ms = new Date(expireAtIso).getTime();
  if (!Number.isFinite(ms) || ms <= 0) {
    return;
  }
  syncAppStorageValue(StoreKeys.DuoWaitExpireAtMs, ms);
}

export function hasDuoWaitContext(): boolean {
  bootstrapStores();
  const sessionId = AppStorage.get<string>(StoreKeys.DuoWaitSessionId) ?? '';
  return sessionId.length > 0;
}

export function openDuoWaitPage(): void {
  pushRoute(PageRoutes.DuoWait);
}

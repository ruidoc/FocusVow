import { DuoSessionView } from '../models/DuoModel';
import { PageRoutes, pushRoute } from '../router/PageRoutes';
import { StoreKeys } from '../stores/StoreKeys';
import { bootstrapStores } from '../stores/StoreBootstrap';

bootstrapStores();

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

export function setInstantDuoWait(
  session: DuoSessionView,
  title: string,
  durationMin: number
): void {
  syncAppStorageValue(StoreKeys.DuoWaitSessionId, session.session_id);
  syncAppStorageValue(StoreKeys.DuoWaitTitle, title);
  syncAppStorageValue(StoreKeys.DuoWaitInviteText, session.invite_text ?? '');
  syncAppStorageValue(StoreKeys.DuoWaitIsScheduled, false);
  syncAppStorageValue(StoreKeys.DuoWaitScheduleLabel, '');
  syncAppStorageValue(StoreKeys.DuoWaitDurationMin, durationMin);
}

export function setScheduledDuoWait(session: DuoSessionView, scheduleLabel: string): void {
  syncAppStorageValue(StoreKeys.DuoWaitSessionId, session.session_id);
  syncAppStorageValue(StoreKeys.DuoWaitTitle, session.title);
  syncAppStorageValue(StoreKeys.DuoWaitInviteText, session.invite_text ?? '');
  syncAppStorageValue(StoreKeys.DuoWaitIsScheduled, true);
  syncAppStorageValue(StoreKeys.DuoWaitScheduleLabel, scheduleLabel);
  syncAppStorageValue(StoreKeys.DuoWaitDurationMin, 0);
}

export function clearDuoWaitContext(): void {
  syncAppStorageValue(StoreKeys.DuoWaitSessionId, '');
  syncAppStorageValue(StoreKeys.DuoWaitTitle, '');
  syncAppStorageValue(StoreKeys.DuoWaitInviteText, '');
  syncAppStorageValue(StoreKeys.DuoWaitIsScheduled, false);
  syncAppStorageValue(StoreKeys.DuoWaitScheduleLabel, '');
  syncAppStorageValue(StoreKeys.DuoWaitDurationMin, 0);
}

export function hasDuoWaitContext(): boolean {
  bootstrapStores();
  const sessionId = AppStorage.get<string>(StoreKeys.DuoWaitSessionId) ?? '';
  return sessionId.length > 0;
}

export function openDuoWaitPage(): void {
  pushRoute(PageRoutes.DuoWait);
}

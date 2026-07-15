import { common } from '@kit.AbilityKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { ActiveLockState, isLocked, resolveDuoSessionIdFromLock, withLockPartnerNickname } from '../models/ActiveLockModel';
import { DuoPushPayload, PushDispatchOptions, UmengPushMessageBody } from '../models/DuoModel';
import { loadPersistedActiveLockState } from './ActiveLockPersistenceService';
import { releaseScreenRestriction, stopPlanGuardStrategyForWindow } from './ScreenTimeService';
import { DuoApiService } from './DuoApiService';
import { clearDuoWaitContext } from './DuoWaitContextService';
import {
  DuoInstantLockOptions,
  startOrAlignInstantDuoFocus
} from './DuoInstantLockService';
import { InAppMessageService } from './InAppMessageService';
import {
  clearScheduledActivationTracking,
  markScheduledListStale,
  removeGuardForSession
} from './ScheduledCovenantService';
import { ScheduledListStore } from '../stores/ScheduledListStore';
import { StoreKeys } from '../stores/StoreKeys';
import { readStoredString, removeStoredKey, writeStoredString } from './PreferencesService';
import { LockStore } from '../stores/LockStore';
import { refreshStats } from '../stores/StatsStore';
import { SettingsStore } from '../stores/SettingsStore';
import { queueShameCertificate } from './CertificatePendingService';
import { bootstrapStores } from '../stores/StoreBootstrap';

bootstrapStores();

const handledBreachSessionIds: Set<string> = new Set();
const PENDING_BREACH_KEY: string = 'duo.push.pendingBreach';

type PushMessageHandler = (
  context: common.UIAbilityContext,
  payload: DuoPushPayload,
  options?: PushDispatchOptions
) => Promise<void>;

export class DuoPushHandler {
  static extractCustomBody(body: UmengPushMessageBody | undefined): string {
    if (!body) {
      return '';
    }
    const customValue = body.custom;
    if (customValue === undefined || customValue === null) {
      return '';
    }
    return customValue;
  }

  static parsePushPayload(
    extra?: Record<string, string>,
    bodyText?: string
  ): DuoPushPayload {
    const emptyPayload: DuoPushPayload = { type: '' };
    const normalizedExtra = extra ?? {};

    if (normalizedExtra['type'] && normalizedExtra['type'].length > 0) {
      return DuoPushHandler.recordToPayload(normalizedExtra);
    }

    if (!bodyText || bodyText.length === 0) {
      if (normalizedExtra['type']) {
        return DuoPushHandler.recordToPayload(normalizedExtra);
      }
      return emptyPayload;
    }

    try {
      const parsed = JSON.parse(bodyText) as Record<string, string>;
      const merged = DuoPushHandler.mergeStringRecords(normalizedExtra, parsed);
      return DuoPushHandler.recordToPayload(merged);
    } catch {
      return DuoPushHandler.recordToPayload(normalizedExtra);
    }
  }

  static async handlePayload(
    payload: DuoPushPayload,
    options?: PushDispatchOptions,
    hostContext?: common.UIAbilityContext
  ): Promise<void> {
    if (payload.type.length === 0) {
      return;
    }

    const context = hostContext ?? AppContextHolder.getAbility();
    if (!context) {
      return;
    }

    const handler = DuoPushHandler.resolveHandler(payload.type);
    if (handler) {
      await handler(context, payload, options);
      return;
    }

    if (options?.isForeground) {
      DuoPushHandler.showForegroundBanner(payload, options);
    }
  }

  /** 冷启动或推送唤醒时，处理上次未完成的撕毁解除 */
  static async processPendingBreach(context: common.UIAbilityContext): Promise<void> {
    const raw = readStoredString(context, PENDING_BREACH_KEY, '');
    if (raw.length === 0) {
      return;
    }

    try {
      const payload = JSON.parse(raw) as DuoPushPayload;
      if (payload.type !== 'duo_breach') {
        DuoPushHandler.clearPendingBreach(context);
        return;
      }
      await DuoPushHandler.handleDuoBreach(context, payload, { isForeground: false });
    } catch {
      DuoPushHandler.clearPendingBreach(context);
    }
  }

  /**
   * 用户未点通知、直接打开 App 时，用一次远端状态补齐撕毁解除。
   * 仅在本地仍有搭子互督专注锁时查询，不是定时轮询。
   */
  static async syncActiveDuoBreachIfNeeded(
    context: common.UIAbilityContext,
    options?: PushDispatchOptions
  ): Promise<void> {
    const state = DuoPushHandler.resolveActiveLockState(context);
    if (state.participationMode !== 'duo') {
      return;
    }
    if (state.kind !== 'quick_focus' && state.kind !== 'covenant') {
      return;
    }

    const sessionId = resolveDuoSessionIdFromLock(state);
    if (sessionId.length === 0 || handledBreachSessionIds.has(sessionId)) {
      return;
    }

    const response = await DuoApiService.getSession(sessionId);
    const session = DuoApiService.parseSession(response);
    if (!session || session.status !== 'breached') {
      return;
    }

    const violatorName = session.breached_by_name && session.breached_by_name.length > 0
      ? session.breached_by_name
      : '搭子';
    const breachPayload: DuoPushPayload = {
      type: 'duo_breach',
      session_id: sessionId,
      violator_name: violatorName,
      message: `由于你的搭子 ${violatorName} 撕毁了契约，本次专注已中止`
    };
    await DuoPushHandler.handleDuoBreach(context, breachPayload, options);
  }

  /**
   * 回前台 / 冷启动：补齐「该锁未锁」与「已锁但 endAt 漂移」。
   * - 有本地 duo 锁：对齐服务端 end_at，或发现 breached 则走撕毁
   * - 有等待中的即时契约且远端已 active：按剩余时间开锁
   */
  static async syncActiveDuoSessionIfNeeded(
    context: common.UIAbilityContext,
    options?: PushDispatchOptions
  ): Promise<void> {
    await DuoPushHandler.syncActiveDuoBreachIfNeeded(context, options);

    LockStore.hydrate(context);
    const state = DuoPushHandler.resolveActiveLockState(context);
    const lockedSessionId = resolveDuoSessionIdFromLock(state);
    if (lockedSessionId.length > 0 && state.kind === 'quick_focus' && state.participationMode === 'duo') {
      const response = await DuoApiService.getSession(lockedSessionId);
      const session = DuoApiService.parseSession(response);
      if (session && session.status === 'active' && session.type !== 'scheduled') {
        SettingsStore.hydrate(context);
        const alignOptions: DuoInstantLockOptions = {
          navigateHome: false,
          clearWait: true,
          alignToServerEnd: true
        };
        await startOrAlignInstantDuoFocus(context, session, state.selectedTokens, alignOptions);
      }
      return;
    }

    if (LockStore.isLocked()) {
      return;
    }

    const waitSessionId = AppStorage.get<string>(StoreKeys.DuoWaitSessionId) ?? '';
    const waitIsScheduled = AppStorage.get<boolean>(StoreKeys.DuoWaitIsScheduled) === true;
    if (waitSessionId.length === 0 || waitIsScheduled) {
      return;
    }

    const response = await DuoApiService.getSession(waitSessionId);
    const session = DuoApiService.parseSession(response);
    if (!session) {
      return;
    }
    if (session.status === 'expired' || session.status === 'cancelled' || session.status === 'breached') {
      clearDuoWaitContext();
      return;
    }
    if (session.status !== 'active' || session.type === 'scheduled') {
      return;
    }

    SettingsStore.hydrate(context);
    const tokens = SettingsStore.getState().selectedTokens;
    const title = String(AppStorage.get<string>(StoreKeys.DuoWaitTitle) ?? session.title);
    const catchUpOptions: DuoInstantLockOptions = {
      title,
      navigateHome: options?.isForeground === true,
      clearWait: true,
      alignToServerEnd: true
    };
    await startOrAlignInstantDuoFocus(context, session, tokens, catchUpOptions);
  }

  private static persistPendingBreach(context: common.Context, payload: DuoPushPayload): void {
    writeStoredString(context, PENDING_BREACH_KEY, JSON.stringify(payload));
  }

  private static clearPendingBreach(context: common.Context): void {
    removeStoredKey(context, PENDING_BREACH_KEY);
  }

  private static resolveActiveLockState(context: common.Context): ActiveLockState {
    LockStore.hydrate(context);
    const persisted = loadPersistedActiveLockState(context);
    if (persisted) {
      return persisted;
    }
    return LockStore.getState();
  }

  private static resolveHandler(type: string): PushMessageHandler | null {
    switch (type) {
      case 'duo_joined':
        return DuoPushHandler.handleDuoJoined;
      case 'duo_start':
        return DuoPushHandler.handleDuoStart;
      case 'duo_breach':
        return DuoPushHandler.handleDuoBreach;
      case 'duo_scheduled_joined':
        return DuoPushHandler.handleDuoScheduledJoined;
      case 'duo_partner_left':
        return DuoPushHandler.handleDuoPartnerLeft;
      case 'duo_scheduled_cancelled':
        return DuoPushHandler.handleDuoScheduledCancelled;
      default:
        return null;
    }
  }

  private static showForegroundBanner(
    payload: DuoPushPayload,
    options?: PushDispatchOptions
  ): void {
    const title = options?.title && options.title.length > 0
      ? options.title
      : '专注契约提醒';
    const message = DuoPushHandler.resolveBannerMessage(payload, options);
    InAppMessageService.show(title, message, payload.type);
  }

  private static resolveBannerMessage(
    payload: DuoPushPayload,
    options?: PushDispatchOptions
  ): string {
    if (payload.message && payload.message.length > 0) {
      return payload.message;
    }
    if (options?.text && options.text.length > 0) {
      return options.text;
    }
    return '你有一条新的专注通知';
  }

  private static recordToPayload(record: Record<string, string>): DuoPushPayload {
    const payload: DuoPushPayload = {
      type: String(record['type'] ?? '')
    };
    const sessionId = record['session_id'];
    if (sessionId && sessionId.length > 0) {
      payload.session_id = sessionId;
    }
    const partnerName = record['partner_name'];
    if (partnerName && partnerName.length > 0) {
      payload.partner_name = partnerName;
    }
    const violatorName = record['violator_name'];
    if (violatorName && violatorName.length > 0) {
      payload.violator_name = violatorName;
    }
    const message = record['message'];
    if (message && message.length > 0) {
      payload.message = message;
    }
    const durationMin = record['duration_min'];
    if (durationMin && durationMin.length > 0) {
      payload.duration_min = durationMin;
    }
    const activeAt = record['active_at'];
    if (activeAt && activeAt.length > 0) {
      payload.active_at = activeAt;
    }
    const endAt = record['end_at'];
    if (endAt && endAt.length > 0) {
      payload.end_at = endAt;
    }
    return payload;
  }

  private static mergeStringRecords(
    left: Record<string, string>,
    right: Record<string, string>
  ): Record<string, string> {
    const merged: Record<string, string> = {};
    const leftKeys = Object.keys(left);
    for (let i = 0; i < leftKeys.length; i++) {
      const key = leftKeys[i];
      merged[key] = left[key];
    }
    const rightKeys = Object.keys(right);
    for (let i = 0; i < rightKeys.length; i++) {
      const key = rightKeys[i];
      merged[key] = right[key];
    }
    return merged;
  }

  private static async handleDuoJoined(
    context: common.UIAbilityContext,
    payload: DuoPushPayload,
    options?: PushDispatchOptions
  ): Promise<void> {
    const partnerName = payload.partner_name && payload.partner_name.length > 0
      ? payload.partner_name
      : '搭子';
    const message = `${partnerName} 加入了你的契约`;

    if (options?.isForeground) {
      const title = options.title && options.title.length > 0 ? options.title : '搭子加入';
      InAppMessageService.show(title, message, payload.type);
    }

    await DuoPushHandler.handleDuoStart(context, payload, options);
  }

  private static async handleDuoScheduledJoined(
    _context: common.UIAbilityContext,
    payload: DuoPushPayload,
    options?: PushDispatchOptions
  ): Promise<void> {
    ScheduledListStore.markDirty();

    const waitSessionId = AppStorage.get<string>(StoreKeys.DuoWaitSessionId) ?? '';
    if (
      waitSessionId.length > 0 &&
      payload.session_id &&
      waitSessionId === payload.session_id
    ) {
      clearDuoWaitContext();
    }

    if (!options?.isForeground) {
      return;
    }

    const partnerName = payload.partner_name && payload.partner_name.length > 0
      ? payload.partner_name
      : '搭子';
    const title = options.title && options.title.length > 0 ? options.title : '搭子加入';
    InAppMessageService.show(title, `${partnerName} 加入了你的定时搭子互督`, payload.type);
  }

  private static async handleDuoPartnerLeft(
    context: common.UIAbilityContext,
    payload: DuoPushPayload,
    options?: PushDispatchOptions
  ): Promise<void> {
    ScheduledListStore.markDirty();
    if (options?.isForeground) {
      const title = options.title && options.title.length > 0 ? options.title : '搭子退出';
      const message = payload.message && payload.message.length > 0
        ? payload.message
        : '你的搭子已退出定时互督';
      InAppMessageService.show(title, message, payload.type);
    }
  }

  private static async handleDuoScheduledCancelled(
    context: common.UIAbilityContext,
    payload: DuoPushPayload,
    options?: PushDispatchOptions
  ): Promise<void> {
    ScheduledListStore.markDirty();
    const sessionId = payload.session_id ?? '';
    if (sessionId.length > 0) {
      await removeGuardForSession(context, sessionId);
    }
    if (options?.isForeground) {
      const title = options.title && options.title.length > 0 ? options.title : '契约已作废';
      const message = payload.message && payload.message.length > 0
        ? payload.message
        : '发起人已作废定时契约';
      InAppMessageService.show(title, message, payload.type);
    }
  }

  private static async handleDuoStart(
    context: common.UIAbilityContext,
    payload: DuoPushPayload,
    _options?: PushDispatchOptions
  ): Promise<void> {
    const sessionId = payload.session_id ?? '';
    if (sessionId.length === 0) {
      return;
    }

    const response = await DuoApiService.getSession(sessionId);
    const session = DuoApiService.parseSession(response);
    if (!session || session.status !== 'active') {
      return;
    }
    if (session.type === 'scheduled') {
      ScheduledListStore.markDirty();
      if (_options?.isForeground) {
        const title = _options.title && _options.title.length > 0 ? _options.title : '定时互督开始';
        const message = payload.message && payload.message.length > 0
          ? payload.message
          : '定时搭子互督已开始，请立即锁机专注';
        InAppMessageService.show(title, message, payload.type);
      }
      return;
    }

    SettingsStore.hydrate(context);
    const tokens = SettingsStore.getState().selectedTokens;
    const startOptions: DuoInstantLockOptions = {
      navigateHome: true,
      clearWait: true,
      alignToServerEnd: true
    };
    await startOrAlignInstantDuoFocus(context, session, tokens, startOptions);
  }

  private static async handleDuoBreach(
    context: common.UIAbilityContext,
    payload: DuoPushPayload,
    options?: PushDispatchOptions
  ): Promise<void> {
    const sessionId = payload.session_id ?? '';
    if (sessionId.length === 0 || handledBreachSessionIds.has(sessionId)) {
      DuoPushHandler.clearPendingBreach(context);
      return;
    }

    DuoPushHandler.persistPendingBreach(context, payload);
    const state = DuoPushHandler.resolveActiveLockState(context);
    const activeSessionId = resolveDuoSessionIdFromLock(state);
    if (activeSessionId.length === 0 || activeSessionId !== sessionId) {
      return;
    }

    handledBreachSessionIds.add(sessionId);

    const message = payload.message && payload.message.length > 0
      ? payload.message
      : '由于你的搭子撕毁了契约，本次专注已中止';
    SettingsStore.hydrate(context);

    const violatorName = payload.violator_name && payload.violator_name.length > 0
      ? payload.violator_name
      : (state.partnerNickname.length > 0 ? state.partnerNickname : '搭子');
    const lockSnapshot = withLockPartnerNickname(state, violatorName);

    if (isLocked(state)) {
      if (state.kind === 'quick_focus') {
        await releaseScreenRestriction(state.selectedTokens, state.mode);
      } else if (state.kind === 'covenant') {
        await stopPlanGuardStrategyForWindow(state.planId);
      }
    }

    queueShameCertificate(lockSnapshot, Date.now(), 'victim', 'partner_breach');
    LockStore.clear(context);
    markScheduledListStale(context);
    refreshStats();
    clearScheduledActivationTracking(sessionId);
    SettingsStore.updateStatusMessage(context, message);
    DuoPushHandler.clearPendingBreach(context);

    if (options?.isForeground) {
      InAppMessageService.dismiss();
    }
  }
}

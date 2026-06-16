import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AppContextHolder } from '../common/AppContextHolder';
import { showToast } from '../common/Toast';
import { isLocked, QuickFocusOptions } from '../models/ActiveLockModel';
import { DuoPushPayload, UmengPushMessageBody } from '../models/DuoModel';
import { applyScreenRestriction, releaseScreenRestriction } from './ScreenTimeService';
import { DuoApiService } from './DuoApiService';
import { LockStore } from '../stores/LockStore';
import { SettingsStore } from '../stores/SettingsStore';
import { bootstrapStores } from '../stores/StoreBootstrap';

bootstrapStores();

const handledBreachSessionIds: Set<string> = new Set();

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

  static async handlePayload(payload: DuoPushPayload): Promise<void> {
    if (payload.type.length === 0) {
      return;
    }

    const context = AppContextHolder.getAbility();
    if (!context) {
      return;
    }

    if (payload.type === 'duo_joined') {
      await DuoPushHandler.handleDuoJoined(payload);
      return;
    }

    if (payload.type === 'duo_start') {
      await DuoPushHandler.handleDuoStart(context, payload);
      return;
    }

    if (payload.type === 'duo_breach') {
      await DuoPushHandler.handleDuoBreach(context, payload);
    }
  }

  static async checkRemoteSessionState(
    context: common.UIAbilityContext,
    sessionId: string
  ): Promise<void> {
    if (sessionId.length === 0) {
      return;
    }

    const response = await DuoApiService.getSession(sessionId);
    const session = DuoApiService.parseSession(response);
    if (!session || session.status !== 'breached') {
      return;
    }

    const violatorName = session.breached_by_name || '搭子';
    const breachPayload: DuoPushPayload = {
      type: 'duo_breach',
      session_id: sessionId,
      violator_name: violatorName,
      message: `由于你的搭子 ${violatorName} 撕毁了契约，本次专注已中止`
    };
    await DuoPushHandler.handleDuoBreach(context, breachPayload);
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

  private static async handleDuoJoined(payload: DuoPushPayload): Promise<void> {
    const partnerName = payload.partner_name && payload.partner_name.length > 0
      ? payload.partner_name
      : '搭子';
    showToast(`${partnerName} 加入了你的契约`);
  }

  private static async handleDuoStart(
    context: common.UIAbilityContext,
    payload: DuoPushPayload
  ): Promise<void> {
    const sessionId = payload.session_id ?? '';
    if (sessionId.length === 0 || LockStore.isLocked()) {
      return;
    }

    SettingsStore.hydrate(context);
    const tokens = SettingsStore.getState().selectedTokens;
    if (tokens.length === 0) {
      return;
    }

    const response = await DuoApiService.getSession(sessionId);
    const session = DuoApiService.parseSession(response);
    if (!session || session.status !== 'active') {
      return;
    }

    const durationMin = payload.duration_min
      ? Number(payload.duration_min)
      : session.duration_min;
    const lockResult = await applyScreenRestriction(tokens, 'allow');
    if (!lockResult.ok) {
      return;
    }

    const focusOptions: QuickFocusOptions = {
      title: session.title,
      duoSessionId: session.session_id,
      recordId: session.my_record_id || session.record_id || '',
      participationMode: 'duo'
    };
    LockStore.startQuickFocus(context, tokens, durationMin, 'allow', focusOptions);
  }

  private static async handleDuoBreach(
    context: common.UIAbilityContext,
    payload: DuoPushPayload
  ): Promise<void> {
    const sessionId = payload.session_id ?? '';
    if (sessionId.length === 0 || handledBreachSessionIds.has(sessionId)) {
      return;
    }

    const state = LockStore.getState();
    if (state.duoSessionId.length === 0 || state.duoSessionId !== sessionId) {
      return;
    }

    handledBreachSessionIds.add(sessionId);

    const message = payload.message && payload.message.length > 0
      ? payload.message
      : '由于你的搭子撕毁了契约，本次专注已中止';
    SettingsStore.hydrate(context);

    if (isLocked(state) && state.kind === 'quick_focus') {
      await releaseScreenRestriction(state.selectedTokens, state.mode);
    }

    LockStore.clear(context);
    SettingsStore.updateStatusMessage(context, message);

    try {
      await promptAction.showDialog({
        title: '契约被撕毁',
        message,
        buttons: [{ text: '知道了', color: '#DC2626' }]
      });
    } catch (error) {
      console.error(`show breach dialog failed: ${String(error)}`);
    }
  }
}

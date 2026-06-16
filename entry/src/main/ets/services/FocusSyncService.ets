import { common } from '@kit.AbilityKit';
import { ActiveLockState } from '../models/ActiveLockModel';
import {
  buildSessionTerminalClientKey,
  buildSoloInstantClientKey,
  FocusSyncPending,
  FocusSyncResult
} from '../models/FocusSyncModel';
import {
  clearFocusSyncPending,
  loadFocusSyncPending,
  saveFocusSyncPending
} from './FocusSyncPersistenceService';
import { HttpService } from './HttpService';
import { loadAccessToken } from './UserPersistenceService';

let flushing: boolean = false;

function resolveParticipationMode(state: ActiveLockState): string {
  if (state.participationMode === 'duo') {
    return 'duo';
  }
  return 'solo';
}

export class FocusSyncService {
  static hasPending(context: common.Context): boolean {
    return loadFocusSyncPending(context) !== null;
  }

  static saveSoloInstantPending(
    context: common.Context,
    state: ActiveLockState,
    result: FocusSyncResult,
    endedAt: number = Date.now()
  ): void {
    const durationMin = Math.max(1, Math.round((state.endAt - state.startedAt) / 60000));
    const actualMin = result === 'SUCCESS'
      ? durationMin
      : Math.max(0, Math.round((endedAt - state.startedAt) / 60000));

    const pending: FocusSyncPending = {
      kind: 'solo_instant',
      client_key: buildSoloInstantClientKey(state.startedAt),
      result,
      started_at: state.startedAt,
      ended_at: endedAt,
      title: state.title,
      duration_min: durationMin,
      actual_min: actualMin,
      mode: state.mode,
      apps: [...state.selectedTokens],
      participation_mode: resolveParticipationMode(state),
      fail_reason: result === 'VIOLATION' ? 'tear' : ''
    };
    saveFocusSyncPending(context, pending);
  }

  static saveSessionTerminalPending(
    context: common.Context,
    state: ActiveLockState,
    result: FocusSyncResult,
    endedAt: number = Date.now()
  ): void {
    const durationMin = Math.max(1, Math.round((state.endAt - state.startedAt) / 60000));
    const actualMin = result === 'SUCCESS'
      ? durationMin
      : Math.max(0, Math.round((endedAt - state.startedAt) / 60000));

    const pending: FocusSyncPending = {
      kind: 'session_terminal',
      client_key: buildSessionTerminalClientKey(state.duoSessionId),
      result,
      started_at: state.startedAt,
      ended_at: endedAt,
      title: state.title,
      duration_min: durationMin,
      actual_min: actualMin,
      mode: state.mode,
      apps: [...state.selectedTokens],
      participation_mode: resolveParticipationMode(state),
      duo_session_id: state.duoSessionId,
      record_id: state.recordId,
      fail_reason: result === 'VIOLATION' ? 'tear' : ''
    };
    saveFocusSyncPending(context, pending);
  }

  static async flushPending(context: common.Context): Promise<boolean> {
    const pending = loadFocusSyncPending(context);
    if (!pending) {
      return true;
    }

    const token = loadAccessToken(context);
    if (token.length === 0) {
      return false;
    }

    if (flushing) {
      return false;
    }

    flushing = true;
    try {
      const body: Record<string, Object> = {
        'kind': pending.kind,
        'client_key': pending.client_key,
        'result': pending.result,
        'ended_at': pending.ended_at
      };
      if (pending.started_at !== undefined) {
        body['started_at'] = pending.started_at;
      }
      if (pending.title) {
        body['title'] = pending.title;
      }
      if (pending.duration_min !== undefined) {
        body['duration_min'] = pending.duration_min;
      }
      if (pending.actual_min !== undefined) {
        body['actual_min'] = pending.actual_min;
      }
      if (pending.mode) {
        body['mode'] = pending.mode;
      }
      if (pending.apps && pending.apps.length > 0) {
        body['apps'] = pending.apps;
      }
      if (pending.participation_mode) {
        body['participation_mode'] = pending.participation_mode;
      }
      if (pending.fail_reason) {
        body['fail_reason'] = pending.fail_reason;
      }
      if (pending.duo_session_id) {
        body['duo_session_id'] = pending.duo_session_id;
      }
      if (pending.record_id) {
        body['record_id'] = pending.record_id;
      }

      const response = await HttpService.post('/focus/sync', body, true, true);
      if (response.statusCode === 200) {
        clearFocusSyncPending(context);
        return true;
      }
      return false;
    } finally {
      flushing = false;
    }
  }
}

import { common } from '@kit.AbilityKit';
import {
  ActiveLockState,
  QuickFocusOptions
} from '../models/ActiveLockModel';
import { DuoSessionView, resolveDuoCounterpartName } from '../models/DuoModel';
import { returnToMainTab } from '../router/PageRoutes';
import { LockStore } from '../stores/LockStore';
import { DuoBgSyncService } from './DuoBgSyncService';
import { FocusStartedNotifyService } from './FocusStartedNotifyService';
import { applyScreenRestriction } from './ScreenTimeService';
import { clearDuoWaitContext } from './DuoWaitContextService';
import {
  COUNTUP_OPEN_LOCK_MIN,
  isCountupMode,
  normalizeTimerMode
} from '../utils/TimerMode';

export interface DuoInstantLockResult {
  ok: boolean;
  message: string;
  alreadyLocked: boolean;
}

export interface DuoInstantLockOptions {
  title?: string;
  navigateHome?: boolean;
  clearWait?: boolean;
  /**
   * true：按服务端 end_at 对齐剩余时间（发起方延迟补锁）
   * false/缺省：按 duration_min 完整开锁（加入方即时开始）
   */
  alignToServerEnd?: boolean;
}

/** 解析服务端 ISO 时间为本地 ms；无效则返回 0 */
export function parseDuoServerTimeMs(value?: string): number {
  if (!value || value.length === 0) {
    return 0;
  }
  const ms = new Date(value).getTime();
  return Number.isFinite(ms) && ms > 0 ? ms : 0;
}

function resolveSessionTimerFields(session: DuoSessionView): [string, number, number] {
  const timerMode = normalizeTimerMode(session.timer_mode);
  const userDuration = session.duration_min > 0 ? session.duration_min : 25;
  const minDurationMin = timerMode === 'countup' ? userDuration : 0;
  return [timerMode, userDuration, minDurationMin];
}

/** 加入方：完整时长，不绑服务端 end_at */
export function buildDuoFullDurationOptions(
  session: DuoSessionView,
  title?: string
): QuickFocusOptions {
  const fields = resolveSessionTimerFields(session);
  const options: QuickFocusOptions = {
    title: title && title.length > 0 ? title : session.title,
    duoSessionId: session.session_id,
    recordId: session.my_record_id || session.record_id || '',
    participationMode: 'duo',
    partnerNickname: resolveDuoCounterpartName(session),
    timerMode: fields[0],
    minDurationMin: fields[2]
  };
  return options;
}

/** 发起方补锁：按服务端 active_at / end_at 对齐 */
export function buildDuoAlignedOptions(
  session: DuoSessionView,
  title?: string
): QuickFocusOptions {
  const fields = resolveSessionTimerFields(session);
  const timerMode = fields[0];
  const durationMin = fields[1];
  const minDurationMin = fields[2];
  // 正计时锁窗上限 23h；倒计时=契约时长
  const durationMs = (isCountupMode(timerMode) ? COUNTUP_OPEN_LOCK_MIN : durationMin) * 60 * 1000;
  const nowMs = Date.now();
  let startedAtMs = parseDuoServerTimeMs(session.active_at);
  let endAtMs = parseDuoServerTimeMs(session.end_at);

  if (endAtMs > 0) {
    if (endAtMs - nowMs > durationMs) {
      endAtMs = nowMs + durationMs;
    }
    if (startedAtMs <= 0 || endAtMs - startedAtMs > durationMs) {
      startedAtMs = endAtMs - durationMs;
    }
  }

  const options: QuickFocusOptions = {
    title: title && title.length > 0 ? title : session.title,
    duoSessionId: session.session_id,
    recordId: session.my_record_id || session.record_id || '',
    participationMode: 'duo',
    partnerNickname: resolveDuoCounterpartName(session),
    startedAtMs: startedAtMs > 0 ? startedAtMs : undefined,
    endAtMs: endAtMs > 0 ? endAtMs : undefined,
    timerMode: timerMode,
    minDurationMin: minDurationMin
  };
  return options;
}

/**
 * 即时搭子互督开锁。
 * - alignToServerEnd=false：加入方，完整 duration_min
 * - alignToServerEnd=true：发起方补锁，按 end_at 剩余时间；已锁同 session 时只对齐 endAt
 */
export async function startOrAlignInstantDuoFocus(
  context: common.Context,
  session: DuoSessionView,
  selectedTokens: string[],
  options?: DuoInstantLockOptions
): Promise<DuoInstantLockResult> {
  if (session.status !== 'active' || session.type === 'scheduled') {
    const skipped: DuoInstantLockResult = {
      ok: false,
      message: 'session_not_active_instant',
      alreadyLocked: false
    };
    return skipped;
  }

  const alignToServerEnd = options?.alignToServerEnd === true;
  const endAtMs = parseDuoServerTimeMs(session.end_at);
  // 正计时不因服务端 end_at 到点拒锁（锁窗很长，结束靠主动 complete）
  if (
    alignToServerEnd &&
    !isCountupMode(session.timer_mode) &&
    endAtMs > 0 &&
    endAtMs <= Date.now()
  ) {
    if (options?.clearWait !== false) {
      clearDuoWaitContext();
    }
    const ended: DuoInstantLockResult = {
      ok: false,
      message: 'session_already_ended',
      alreadyLocked: false
    };
    return ended;
  }

  LockStore.hydrate(context);
  const current = LockStore.getState();
  if (current.kind === 'quick_focus' && current.duoSessionId === session.session_id) {
    if (alignToServerEnd) {
      const focusOptions = buildDuoAlignedOptions(session, options?.title);
      if (focusOptions.endAtMs && focusOptions.endAtMs > 0 && current.endAt !== focusOptions.endAtMs) {
        const aligned: ActiveLockState = {
          kind: current.kind,
          strategyName: current.strategyName,
          title: focusOptions.title ?? current.title,
          planId: current.planId,
          selectedTokens: current.selectedTokens,
          selectedCount: current.selectedCount,
          mode: current.mode,
          startedAt: focusOptions.startedAtMs && focusOptions.startedAtMs > 0
            ? focusOptions.startedAtMs
            : current.startedAt,
          endAt: focusOptions.endAtMs,
          updatedAt: Date.now(),
          duoSessionId: current.duoSessionId,
          recordId: focusOptions.recordId && focusOptions.recordId.length > 0
            ? focusOptions.recordId
            : current.recordId,
          participationMode: 'duo',
          partnerNickname: focusOptions.partnerNickname && focusOptions.partnerNickname.length > 0
            ? focusOptions.partnerNickname
            : current.partnerNickname,
          timerMode: focusOptions.timerMode === 'countup' ? 'countup' : current.timerMode,
          minDurationMin: focusOptions.minDurationMin && focusOptions.minDurationMin > 0
            ? focusOptions.minDurationMin
            : current.minDurationMin,
          isDelayedSolo: current.isDelayedSolo
        };
        LockStore.setState(context, aligned);
      }
    }
    if (options?.clearWait !== false) {
      clearDuoWaitContext();
    }
    DuoBgSyncService.ensure();
    if (options?.navigateHome !== false) {
      returnToMainTab('focus');
    }
    const already: DuoInstantLockResult = {
      ok: true,
      message: '',
      alreadyLocked: true
    };
    return already;
  }

  if (LockStore.isLocked()) {
    const busy: DuoInstantLockResult = {
      ok: false,
      message: 'already_locked_other',
      alreadyLocked: true
    };
    return busy;
  }

  // 空 selectedTokens + allow = 全锁（对齐 RN）；不拦截
  // 发起互督额度在创建页已校验；加入互督不校验；补锁不再重复拦
  const lockResult = await applyScreenRestriction(selectedTokens, 'allow');
  if (!lockResult.ok) {
    const failed: DuoInstantLockResult = {
      ok: false,
      message: lockResult.message,
      alreadyLocked: false
    };
    return failed;
  }

  const focusOptions = alignToServerEnd
    ? buildDuoAlignedOptions(session, options?.title)
    : buildDuoFullDurationOptions(session, options?.title);
  const fields = resolveSessionTimerFields(session);
  const userDuration = fields[1];
  const timerMode = fields[0];
  LockStore.startQuickFocus(context, selectedTokens, userDuration, 'allow', focusOptions);

  FocusStartedNotifyService.report(context, {
    scene: alignToServerEnd ? 'duo_initiate_start' : 'duo_join_start',
    durationMin: userDuration,
    sessionId: session.session_id,
    sessionType: 'instant',
    title: focusOptions.title,
    timerMode: timerMode
  });

  if (options?.clearWait !== false) {
    clearDuoWaitContext();
  }
  DuoBgSyncService.ensure();
  if (options?.navigateHome !== false) {
    returnToMainTab('focus');
  }
  const started: DuoInstantLockResult = {
    ok: true,
    message: '',
    alreadyLocked: false
  };
  return started;
}

import { common } from '@kit.AbilityKit';
import {
  isOrgClassroomJoinable,
  OrgClassroomActive,
  OrgClassroomSummary,
} from '../models/OrgModel';
import { returnToMainTab } from '../router/PageRoutes';
import { LockStore } from '../stores/LockStore';
import { OrgStore } from '../stores/OrgStore';
import { SettingsStore } from '../stores/SettingsStore';
import { UserStore } from '../stores/UserStore';
import { applyScreenRestriction, releaseScreenRestriction } from './ScreenTimeService';
import { isHarmonyPcOr2in1 } from '../utils/DeviceFormFactor';
import { readStoredString, removeStoredKey, writeStoredString } from './PreferencesService';

const META_KEY: string = 'org.classroom.active';

export interface OrgClassroomActiveMeta {
  orgId: string;
  classroomId: string;
  recordId: string;
  allowExit: boolean;
  title: string;
  durationMin: number;
  endAt: string;
  exitRequestPending: boolean;
}

export interface OrgClassroomExitCopy {
  title: string;
  message: string;
  confirmText: string;
}

export function orgClassroomPlanId(classroomId: string): string {
  return `org_cls_${classroomId}`;
}

export function isOrgClassroomLockPlanId(planId: string): boolean {
  return planId.startsWith('org_cls_');
}

export function loadOrgClassroomMeta(context: common.Context): OrgClassroomActiveMeta | null {
  const raw = readStoredString(context, META_KEY, '');
  if (raw.length === 0) {
    return null;
  }
  try {
    const data = JSON.parse(raw) as OrgClassroomActiveMeta;
    if (!data.orgId || !data.classroomId) {
      return null;
    }
    return data;
  } catch {
    return null;
  }
}

export function saveOrgClassroomMeta(context: common.Context, meta: OrgClassroomActiveMeta | null): void {
  if (!meta) {
    removeStoredKey(context, META_KEY);
    return;
  }
  writeStoredString(context, META_KEY, JSON.stringify(meta));
}

export function patchOrgClassroomMeta(
  context: common.Context,
  patch: Partial<OrgClassroomActiveMeta>
): OrgClassroomActiveMeta | null {
  const meta = loadOrgClassroomMeta(context);
  if (!meta) {
    return null;
  }
  const next: OrgClassroomActiveMeta = {
    orgId: patch.orgId ?? meta.orgId,
    classroomId: patch.classroomId ?? meta.classroomId,
    recordId: patch.recordId ?? meta.recordId,
    allowExit: patch.allowExit ?? meta.allowExit,
    title: patch.title ?? meta.title,
    durationMin: patch.durationMin ?? meta.durationMin,
    endAt: patch.endAt ?? meta.endAt,
    exitRequestPending: patch.exitRequestPending ?? meta.exitRequestPending
  };
  saveOrgClassroomMeta(context, next);
  return next;
}

async function startOrgClassroomLocalLock(
  context: common.UIAbilityContext,
  orgId: string,
  classroom: OrgClassroomSummary,
  recordId: string,
  tokens: string[]
): Promise<boolean> {
  const restriction = await applyScreenRestriction(tokens, 'allow');
  if (!restriction.ok) {
    return false;
  }
  LockStore.startQuickFocus(context, tokens, 0, 'allow', {
    title: '正在上课中',
    participationMode: 'solo',
    timerMode: 'countup',
    minDurationMin: 0,
    planId: orgClassroomPlanId(classroom.id),
    recordId: recordId,
    skipStartedNotify: true
  });
  saveOrgClassroomMeta(context, {
    orgId: orgId,
    classroomId: classroom.id,
    recordId: recordId,
    allowExit: classroom.allow_exit,
    title: classroom.title,
    durationMin: classroom.duration_min,
    endAt: classroom.end_at,
    exitRequestPending: false
  });
  return true;
}

export async function joinAndStartOrgClassroom(
  context: common.UIAbilityContext,
  orgId: string,
  active: OrgClassroomActive,
  tokens: string[]
): Promise<string> {
  LockStore.hydrate(context);
  const classroom = active.classroom;
  if (LockStore.isLocked()) {
    return '已有专注任务正在进行中';
  }
  if (tokens.length === 0 && !isHarmonyPcOr2in1()) {
    return '请先选择白名单应用';
  }
  if (tokens.length > classroom.max_apps) {
    return `最多选择 ${classroom.max_apps} 个应用`;
  }

  const joinRes = await OrgStore.joinClassroom(orgId, classroom.id);
  if (joinRes.statusCode !== 200) {
    if ((joinRes.message ?? '').indexOf('课堂已结束') >= 0) {
      saveOrgClassroomMeta(context, null);
    }
    return joinRes.message && joinRes.message.length > 0 ? joinRes.message : '无法加入课堂';
  }

  const runningRecordId = joinRes.data ? String(joinRes.data['running_record_id'] ?? '') : '';
  if (runningRecordId.length > 0) {
    if (active.my_exit_request && active.my_exit_request.status === 'pending') {
      return '退出申请审核中，请等待发起人处理';
    }
    const ok = await startOrgClassroomLocalLock(context, orgId, classroom, runningRecordId, tokens);
    return ok ? '' : '恢复课堂专注失败';
  }

  const startedAt = Date.now();
  const startRes = await OrgStore.startClassroom(orgId, classroom.id, tokens, startedAt);
  const recordId = startRes.data ? String(startRes.data['record_id'] ?? '') : '';
  if (startRes.statusCode !== 200 || recordId.length === 0) {
    return startRes.message && startRes.message.length > 0 ? startRes.message : '开始失败';
  }
  const ok = await startOrgClassroomLocalLock(context, orgId, classroom, recordId, tokens);
  return ok ? '' : '加入课堂失败';
}

export async function releaseLocalOrgClassroomLock(context: common.Context): Promise<void> {
  LockStore.hydrate(context);
  const state = LockStore.getState();
  if (isOrgClassroomLockPlanId(state.planId) || loadOrgClassroomMeta(context) !== null) {
    if (state.selectedTokens.length > 0) {
      await releaseScreenRestriction(state.selectedTokens, state.mode);
    }
    if (isOrgClassroomLockPlanId(state.planId)) {
      LockStore.clear(context);
    }
  }
  saveOrgClassroomMeta(context, null);
}

export async function handleOrgClassroomEndedLocally(
  context: common.Context,
  message: string = '组织课堂已结束'
): Promise<string> {
  await releaseLocalOrgClassroomLock(context);
  return message;
}

export async function reconcileOrgClassroomOnForeground(context: common.Context): Promise<void> {
  LockStore.hydrate(context);
  const meta = loadOrgClassroomMeta(context);
  if (!meta) {
    return;
  }
  const state = LockStore.getState();
  if (!isOrgClassroomLockPlanId(state.planId)) {
    saveOrgClassroomMeta(context, null);
    return;
  }
  const active = await OrgStore.getActiveClassroom(meta.orgId);
  if (!isOrgClassroomJoinable(active) || !active || active.classroom.id !== meta.classroomId) {
    await handleOrgClassroomEndedLocally(context);
    return;
  }
  patchOrgClassroomMeta(context, {
    allowExit: active.classroom.allow_exit,
    endAt: active.classroom.end_at
  });
  const myReq = active.my_exit_request;
  if (myReq && myReq.status === 'pending') {
    patchOrgClassroomMeta(context, { exitRequestPending: true });
    return;
  }
  if (myReq && myReq.status === 'approved') {
    await releaseLocalOrgClassroomLock(context);
    return;
  }
  patchOrgClassroomMeta(context, { exitRequestPending: false });
}

export function getOrgClassroomExitCopy(meta: OrgClassroomActiveMeta | null): OrgClassroomExitCopy {
  const needApproval = !!meta && meta.allowExit;
  return {
    title: needApproval ? '申请退出' : '退出课堂',
    message: needApproval
      ? '确认向发起人提交退出申请？审批通过后才会解除专注。'
      : '确认退出本次课堂？退出后可再次加入。',
    confirmText: needApproval ? '提交申请' : '确认退出'
  };
}

export async function exitOrgClassroomFocus(context: common.UIAbilityContext): Promise<string> {
  const meta = loadOrgClassroomMeta(context);
  if (!meta) {
    return '课堂信息已失效';
  }
  if (meta.exitRequestPending) {
    return '退出申请审核中，请等待发起人处理';
  }
  const res = await OrgStore.leaveClassroom(meta.orgId, meta.classroomId);
  if (res.statusCode !== 200) {
    if ((res.message ?? '').indexOf('课堂已结束') >= 0) {
      await handleOrgClassroomEndedLocally(context);
      return '组织课堂已结束';
    }
    return res.message && res.message.length > 0 ? res.message : '退出失败';
  }
  const left = res.data ? res.data['left'] === true : false;
  if (left) {
    await releaseLocalOrgClassroomLock(context);
    returnToMainTab('focus');
    return '已退出课堂';
  }
  const pending = res.data ? res.data['pending'] === true : false;
  patchOrgClassroomMeta(context, { exitRequestPending: true });
  return pending ? '退出申请审核中，请等待发起人处理' : '退出申请已提交，等待发起人审批';
}

export function getSelectedClassroomTokens(): string[] {
  return SettingsStore.getState().selectedTokens;
}

export function currentUserId(): string {
  return UserStore.getUserInfo().id;
}

import { common } from '@kit.AbilityKit';
import { appPicker, guardService } from '@kit.ScreenTimeGuardKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FocusPlan, normalizePlanRepeatDays, normalizeTimeText } from '../models/PlanModel';
import { ScheduledGuardSnapshot } from './ScheduledSessionPersistenceService';
import { resolveInstantLockMinutes } from '../utils/TimerMode';
import { isHarmonyPcOr2in1 } from '../utils/DeviceFormFactor';

export interface GuardResult<T> {
  ok: boolean;
  data?: T;
  message: string;
}

interface GuardErrorLike {
  code?: number;
  message?: string;
}

interface ScheduledTimeSpec {
  name: string;
  startTime: string;
  endTime: string;
  repeat: number[];
}

const DOMAIN: number = 0x0000;
const TAG: string = 'ScreenTimeGuard';

function toBusinessMessage(fallback: string): string {
  return fallback;
}

function formatGuardError(action: string, error: Object): string {
  if (error instanceof Error && error.message.length > 0) {
    return error.message;
  }

  const guardError = error as GuardErrorLike;
  const codeText = guardError.code !== undefined ? `code=${guardError.code}` : 'code=unknown';
  const messageText =
    guardError.message !== undefined && guardError.message.length > 0 ? guardError.message : String(error);
  return `${action}: ${codeText}, ${messageText}`;
}

function logGuardError(action: string, error: Object): void {
  hilog.error(DOMAIN, TAG, '%{public}s', formatGuardError(action, error));
}

function guardOperationError(action: string, error: Object): Error {
  return new Error(formatGuardError(action, error));
}

function getRestrictionType(mode: 'shield' | 'allow'): guardService.RestrictionType {
  if (mode === 'allow') {
    return guardService.RestrictionType.TRUSTLIST_TYPE;
  }

  return guardService.RestrictionType.BLOCKLIST_TYPE;
}

function isGuardErrorCode(error: GuardErrorLike, code: guardService.GuardServiceErrorCode): boolean {
  return error.code === code;
}

const NONEXISTENT_STRATEGY_ERROR_CODE: number = 1019000006;

function getGuardErrorLike(error: Object): GuardErrorLike {
  const guardError = error as GuardErrorLike;
  if (guardError.code !== undefined) {
    return guardError;
  }
  if (error instanceof Error) {
    const codeMatch = error.message.match(/code=(\d+)/);
    if (codeMatch) {
      return { code: Number(codeMatch[1]), message: error.message };
    }
    return { message: error.message };
  }
  return guardError;
}

function isNonexistentStrategyError(error: Object): boolean {
  const guardError = getGuardErrorLike(error);
  if (isGuardErrorCode(guardError, guardService.GuardServiceErrorCode.NONEXISTENT_STRATEGY)) {
    return true;
  }
  if (guardError.code === NONEXISTENT_STRATEGY_ERROR_CODE) {
    return true;
  }
  const message = (guardError.message ?? String(error)).toLowerCase();
  return message.includes('nonexistent') && message.includes('strateg');
}

function shouldIgnoreStartError(error: GuardErrorLike): boolean {
  return isGuardErrorCode(error, guardService.GuardServiceErrorCode.STRATEGY_ALREADY_EXECUTED) ||
    isNonexistentStrategyError(error);
}

function shouldIgnoreStopError(error: GuardErrorLike): boolean {
  return isGuardErrorCode(error, guardService.GuardServiceErrorCode.STRATEGY_NOT_STARTED) ||
    isNonexistentStrategyError(error);
}

function shouldIgnoreRemoveError(error: GuardErrorLike): boolean {
  return isNonexistentStrategyError(error);
}

function createPlanGuardStrategy(plan: FocusPlan): guardService.GuardStrategy {
  return {
    name: plan.id,
    timeStrategy: {
      type: guardService.TimeStrategyType.START_END_TIME_TYPE,
      startTime: plan.startTime,
      endTime: plan.endTime,
      repeat: [...plan.repeatDays]
    },
    appInfo: {
      appTokens: [...plan.selectedTokens]
    },
    appRestrictionType: getRestrictionType(plan.mode)
  };
}

function createScheduledGuardStrategy(
  snapshot: ScheduledGuardSnapshot,
  spec: ScheduledTimeSpec
): guardService.GuardStrategy {
  return {
    name: spec.name,
    timeStrategy: {
      type: guardService.TimeStrategyType.START_END_TIME_TYPE,
      startTime: spec.startTime,
      endTime: spec.endTime,
      repeat: [...spec.repeat]
    },
    appInfo: {
      appTokens: [...snapshot.selectedTokens]
    },
    appRestrictionType: getRestrictionType(snapshot.mode)
  };
}

async function removeGuardStrategyQuietly(strategyName: string): Promise<void> {
  try {
    await guardService.stopGuardStrategy(strategyName);
  } catch (error) {
    const guardError = getGuardErrorLike(error as Object);
    if (!shouldIgnoreStopError(guardError)) {
      hilog.warn(DOMAIN, TAG, 'removeGuardStrategyQuietly stop %{public}s: %{public}s',
        strategyName, formatGuardError(`stopGuardStrategy(${strategyName})`, error as Object));
    }
  }
  try {
    await guardService.removeGuardStrategy(strategyName);
  } catch (error) {
    const guardError = getGuardErrorLike(error as Object);
    if (!shouldIgnoreRemoveError(guardError)) {
      hilog.warn(DOMAIN, TAG, 'removeGuardStrategyQuietly remove %{public}s: %{public}s',
        strategyName, formatGuardError(`removeGuardStrategy(${strategyName})`, error as Object));
    }
  }
}

async function upsertGuardStrategy(strategy: guardService.GuardStrategy): Promise<void> {
  try {
    await guardService.addGuardStrategy(strategy);
    return;
  } catch (error) {
    const guardError = getGuardErrorLike(error as Object);
    if (!isGuardErrorCode(guardError, guardService.GuardServiceErrorCode.STRATEGY_NAME_ALREADY_EXIST)) {
      throw guardOperationError(`addGuardStrategy(${strategy.name})`, error as Object);
    }
  }

  try {
    await guardService.updateGuardStrategy(strategy.name, strategy);
    return;
  } catch (updateError) {
    if (!isNonexistentStrategyError(updateError as Object)) {
      throw guardOperationError(`updateGuardStrategy(${strategy.name})`, updateError as Object);
    }
  }

  await removeGuardStrategyQuietly(strategy.name);
  try {
    await guardService.addGuardStrategy(strategy);
  } catch (readdError) {
    throw guardOperationError(`addGuardStrategy(${strategy.name})`, readdError as Object);
  }
}

async function cleanupStaleScheduledGuardNames(
  sessionId: string,
  wanted: Set<string>
): Promise<void> {
  const leftovers = scheduledSessionStrategyNames(sessionId);
  const existingStrategies = await guardService.queryGuardStrategies();
  const existingNames = new Set<string>(
    existingStrategies.map((item: guardService.GuardStrategy) => item.name)
  );
  for (let i = 0; i < leftovers.length; i++) {
    const name = leftovers[i];
    if (wanted.has(name) || !existingNames.has(name)) {
      continue;
    }
    await stopPlanGuardStrategy(name);
    await removePlanGuardStrategyInternal(name);
  }
}

async function addOrUpdatePlanGuardStrategy(
  plan: FocusPlan,
  existingNames?: Set<string>
): Promise<void> {
  const strategy = createPlanGuardStrategy(plan);
  const hasExistingStrategy = existingNames?.has(plan.id) ?? false;

  if (hasExistingStrategy) {
    try {
      await guardService.updateGuardStrategy(plan.id, strategy);
    } catch (error) {
      throw guardOperationError(`updateGuardStrategy(${plan.id})`, error as Object);
    }
    return;
  }

  try {
    await guardService.addGuardStrategy(strategy);
  } catch (error) {
    const guardError = error as GuardErrorLike;
    if (isGuardErrorCode(guardError, guardService.GuardServiceErrorCode.STRATEGY_NAME_ALREADY_EXIST)) {
      try {
        await guardService.updateGuardStrategy(plan.id, strategy);
      } catch (updateError) {
        throw guardOperationError(`updateGuardStrategy(${plan.id})`, updateError as Object);
      }
      return;
    }
    throw guardOperationError(`addGuardStrategy(${plan.id})`, error as Object);
  }
}

async function startPlanGuardStrategy(planId: string): Promise<void> {
  try {
    await guardService.startGuardStrategy(planId);
  } catch (error) {
    const guardError = getGuardErrorLike(error as Object);
    if (!shouldIgnoreStartError(guardError)) {
      throw guardOperationError(`startGuardStrategy(${planId})`, error as Object);
    }
  }
}

/** 定时契约未到窗口时 start 可能失败，add/update 成功即可由系统到点拉起 */
async function startScheduledGuardStrategy(strategyName: string): Promise<void> {
  try {
    await guardService.startGuardStrategy(strategyName);
  } catch (error) {
    const guardError = getGuardErrorLike(error as Object);
    if (shouldIgnoreStartError(guardError)) {
      return;
    }
    hilog.warn(
      DOMAIN,
      TAG,
      'startScheduledGuardStrategy lenient %{public}s: %{public}s',
      strategyName,
      formatGuardError(`startGuardStrategy(${strategyName})`, error as Object)
    );
  }
}

async function stopPlanGuardStrategy(planId: string): Promise<void> {
  try {
    await guardService.stopGuardStrategy(planId);
  } catch (error) {
    const guardError = getGuardErrorLike(error as Object);
    if (!shouldIgnoreStopError(guardError)) {
      throw guardOperationError(`stopGuardStrategy(${planId})`, error as Object);
    }
  }
}

async function removePlanGuardStrategyInternal(planId: string): Promise<void> {
  try {
    await guardService.removeGuardStrategy(planId);
  } catch (error) {
    const guardError = getGuardErrorLike(error as Object);
    if (!shouldIgnoreRemoveError(guardError)) {
      throw guardOperationError(`removeGuardStrategy(${planId})`, error as Object);
    }
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function getUserAuthGranted(): Promise<boolean> {
  try {
    const authStatus = await guardService.getUserAuthStatus();
    return authStatus === guardService.AuthStatus.AUTH_GRANTED;
  } catch {
    return false;
  }
}

/** 弹框关闭后授权成功时系统状态可能滞后，短轮询几次；拒绝则尽快返回 */
async function pollUserAuthGranted(maxRetry: number = 5, intervalMs: number = 80): Promise<boolean> {
  for (let i = 0; i < maxRetry; i++) {
    if (await getUserAuthGranted()) {
      return true;
    }
    if (i < maxRetry - 1) {
      await sleep(intervalMs);
    }
  }
  return false;
}

/** 查询屏时守护系统授权是否已授予 */
export async function checkScreenTimeAuthorized(): Promise<boolean> {
  if (isHarmonyPcOr2in1()) {
    return true;
  }
  return getUserAuthGranted();
}

export async function requestScreenTimeAuthorization(
  context: common.UIAbilityContext
): Promise<GuardResult<boolean>> {
  if (isHarmonyPcOr2in1()) {
    return {
      ok: true,
      data: true,
      message: 'PC/二合一设备无需屏时授权'
    };
  }
  try {
    await guardService.requestUserAuth(context);
  } catch (error) {
    // 部分机型取消会抛错；仍以最终系统状态为准
    hilog.warn(DOMAIN, TAG, 'requestUserAuth: %{public}s', String(error));
  }
  const granted = await pollUserAuthGranted();
  return {
    ok: granted,
    data: granted,
    message: granted ? '已完成系统授权' : '请完成健康使用设备权限授权'
  };
}

export async function ensureScreenTimeAuthorization(
  context: common.UIAbilityContext
): Promise<GuardResult<boolean>> {
  if (isHarmonyPcOr2in1()) {
    return { ok: true, data: true, message: 'PC/二合一设备无需屏时授权' };
  }
  if (await getUserAuthGranted()) {
    return { ok: true, data: true, message: '系统授权已开启' };
  }

  return requestScreenTimeAuthorization(context);
}

export async function chooseRestrictedApps(
  context: common.UIAbilityContext,
  selectedTokens: string[]
): Promise<GuardResult<string[]>> {
  if (isHarmonyPcOr2in1()) {
    return {
      ok: true,
      data: [...selectedTokens],
      message: 'PC/二合一设备暂不支持选择应用'
    };
  }
  try {
    const tokens = await appPicker.startAppPicker(context, { appTokens: selectedTokens });
    return {
      ok: true,
      data: tokens,
      message: tokens.length > 0 ? `已选择 ${tokens.length} 个应用` : '未选择应用'
    };
  } catch {
    return {
      ok: false,
      data: selectedTokens,
      message: toBusinessMessage('拉起应用选择失败')
    };
  }
}

/** 专注中打开系统「许可应用跳转页」，点击图标可启动白名单应用 */
export async function openTrustListAppForm(
  context: common.UIAbilityContext,
  selectedTokens: string[],
  subtitle: string = '点击图标打开应用'
): Promise<GuardResult<boolean>> {
  try {
    await appPicker.startAppForm(
      context,
      { appTokens: selectedTokens },
      subtitle,
      true
    );
    return { ok: true, data: true, message: '已打开白名单' };
  } catch {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('打开白名单失败')
    };
  }
}

export async function applyScreenRestriction(
  selectedTokens: string[],
  mode: 'shield' | 'allow'
): Promise<GuardResult<boolean>> {
  if (isHarmonyPcOr2in1()) {
    return { ok: true, data: true, message: '专注已开始（PC/二合一仅计时）' };
  }
  try {
    const restrictionType: guardService.RestrictionType = getRestrictionType(mode);

    await guardService.setAppsRestriction({ appTokens: selectedTokens }, restrictionType);
    return { ok: true, data: true, message: '专注已开始，限制已生效' };
  } catch {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('开启应用限制失败')
    };
  }
}

export async function releaseScreenRestriction(
  selectedTokens: string[],
  mode: 'shield' | 'allow'
): Promise<GuardResult<boolean>> {
  if (isHarmonyPcOr2in1()) {
    return { ok: true, data: true, message: '已解除应用限制' };
  }
  try {
    const restrictionType: guardService.RestrictionType = getRestrictionType(mode);

    await guardService.releaseAppsRestriction({ appTokens: selectedTokens }, restrictionType);
    return { ok: true, data: true, message: '已解除应用限制' };
  } catch {
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('解除应用限制失败')
    };
  }
}

export function isOnceStrategyName(strategyName: string): boolean {
  return strategyName.startsWith('once_');
}

function padClock(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

function clockOf(date: Date): string {
  return `${padClock(date.getHours())}:${padClock(date.getMinutes())}`;
}

function weekdayOf(date: Date): number {
  const day = date.getDay();
  return day === 0 ? 7 : day;
}

export function sessionIdFromGuardName(strategyName: string): string {
  if (!strategyName.startsWith('session_')) {
    return '';
  }
  let id = strategyName.substring('session_'.length);
  if (id.endsWith('_P1') || id.endsWith('_P2')) {
    id = id.substring(0, id.length - 3);
  }
  return id;
}

export function scheduledSessionStrategyNames(sessionId: string): string[] {
  return [
    `session_${sessionId}`,
    `session_${sessionId}_P1`,
    `session_${sessionId}_P2`
  ];
}

function clockMinutesFromText(timeText: string): number {
  const normalized = normalizeTimeText(timeText, '00:00');
  const parts = normalized.split(':');
  return Number(parts[0]) * 60 + Number(parts[1]);
}

function normalizeScheduledSnapshot(snapshot: ScheduledGuardSnapshot): ScheduledGuardSnapshot {
  return {
    sessionId: snapshot.sessionId,
    title: snapshot.title,
    startTime: normalizeTimeText(snapshot.startTime, '09:00'),
    endTime: normalizeTimeText(snapshot.endTime, '18:00'),
    repeatDays: normalizePlanRepeatDays(snapshot.repeatDays),
    selectedTokens: [...snapshot.selectedTokens],
    mode: snapshot.mode
  };
}

function nextHarmonyRepeatDay(day: number): number {
  return day === 7 ? 1 : day + 1;
}

function nextHarmonyRepeatDays(days: number[]): number[] {
  const out: number[] = [];
  for (let i = 0; i < days.length; i++) {
    const next = nextHarmonyRepeatDay(days[i]);
    if (!out.includes(next)) {
      out.push(next);
    }
  }
  return out;
}

function buildScheduledTimeSpecs(snapshot: ScheduledGuardSnapshot): ScheduledTimeSpec[] {
  const startMin = clockMinutesFromText(snapshot.startTime);
  const endMin = clockMinutesFromText(snapshot.endTime);
  const baseName = `session_${snapshot.sessionId}`;
  if (endMin >= startMin) {
    const same: ScheduledTimeSpec = {
      name: baseName,
      startTime: snapshot.startTime,
      endTime: snapshot.endTime,
      repeat: [...snapshot.repeatDays]
    };
    return [same];
  }
  const specs: ScheduledTimeSpec[] = [{
    name: `${baseName}_P1`,
    startTime: snapshot.startTime,
    endTime: '23:59',
    repeat: [...snapshot.repeatDays]
  }];
  if (endMin > 0) {
    specs.push({
      name: `${baseName}_P2`,
      startTime: '00:00',
      endTime: snapshot.endTime,
      repeat: nextHarmonyRepeatDays(snapshot.repeatDays)
    });
  }
  return specs;
}

/** TimeGuard 只有 HH:mm：结束时刻向上取整到下一整分，避免 UI 已到点系统还在锁 */
export function ceilToNextMinuteMs(ms: number): number {
  const date = new Date(ms);
  if (date.getSeconds() === 0 && date.getMilliseconds() === 0) {
    return ms;
  }
  date.setSeconds(0, 0);
  date.setMinutes(date.getMinutes() + 1);
  return date.getTime();
}

export async function syncDelayedOnceGuardStrategy(
  planId: string,
  startAtMs: number,
  durationMinutes: number,
  timerMode: string,
  selectedTokens: string[],
  mode: 'shield' | 'allow'
): Promise<GuardResult<number>> {
  if (isHarmonyPcOr2in1()) {
    const lockMinutes = resolveInstantLockMinutes(durationMinutes, timerMode);
    const endAtMs = ceilToNextMinuteMs(startAtMs + lockMinutes * 60_000);
    return { ok: true, data: endAtMs, message: '已预约延迟开始（PC/二合一仅计时）' };
  }
  if (selectedTokens.length === 0 && mode !== 'allow') {
    return { ok: false, data: 0, message: toBusinessMessage('请先选择要限制的应用') };
  }
  const lockMinutes = resolveInstantLockMinutes(durationMinutes, timerMode);
  const endAtMs = ceilToNextMinuteMs(startAtMs + lockMinutes * 60_000);
  const startDate = new Date(startAtMs);
  const endDate = new Date(endAtMs);
  const startDay = weekdayOf(startDate);
  const endDay = weekdayOf(endDate);
  const strategy: guardService.GuardStrategy = {
    name: planId,
    timeStrategy: {
      type: guardService.TimeStrategyType.START_END_TIME_TYPE,
      startTime: clockOf(startDate),
      endTime: clockOf(endDate),
      repeat: startDay === endDay ? [startDay] : [startDay, endDay]
    },
    appInfo: {
      appTokens: [...selectedTokens]
    },
    appRestrictionType: getRestrictionType(mode)
  };
  try {
    try {
      await guardService.addGuardStrategy(strategy);
    } catch (error) {
      const guardError = error as GuardErrorLike;
      if (!isGuardErrorCode(guardError, guardService.GuardServiceErrorCode.STRATEGY_NAME_ALREADY_EXIST)) {
        throw new Error(String(error));
      }
      await guardService.updateGuardStrategy(planId, strategy);
    }
    await startPlanGuardStrategy(planId);
    return { ok: true, data: endAtMs, message: '已预约延迟开始' };
  } catch (error) {
    logGuardError(`syncDelayedOnceGuardStrategy(${planId})`, error as Object);
    return {
      ok: false,
      data: 0,
      message: toBusinessMessage('预约延迟开始失败')
    };
  }
}

export async function syncScheduledSessionGuardStrategy(
  snapshot: ScheduledGuardSnapshot
): Promise<GuardResult<boolean>> {
  if (isHarmonyPcOr2in1()) {
    return { ok: true, data: true, message: 'PC/二合一设备跳过屏时策略注册' };
  }
  if (!(await getUserAuthGranted())) {
    return {
      ok: false,
      data: false,
      message: '未完成健康使用设备授权，无法注册屏时策略'
    };
  }

  const normalizedSnapshot = normalizeScheduledSnapshot(snapshot);
  const effectiveSnapshot: ScheduledGuardSnapshot = normalizedSnapshot.selectedTokens.length === 0
    ? {
      sessionId: normalizedSnapshot.sessionId,
      title: normalizedSnapshot.title,
      startTime: normalizedSnapshot.startTime,
      endTime: normalizedSnapshot.endTime,
      repeatDays: normalizedSnapshot.repeatDays,
      selectedTokens: [],
      mode: 'allow'
    }
    : normalizedSnapshot;

  if (effectiveSnapshot.repeatDays.length === 0) {
    return { ok: true, data: true, message: '今日已撕毁，跳过屏时策略注册' };
  }

  try {
    const specs = buildScheduledTimeSpecs(effectiveSnapshot);
    const wanted = new Set<string>(specs.map((item: ScheduledTimeSpec) => item.name));
    await cleanupStaleScheduledGuardNames(effectiveSnapshot.sessionId, wanted);
    for (let i = 0; i < specs.length; i++) {
      await upsertGuardStrategy(createScheduledGuardStrategy(effectiveSnapshot, specs[i]));
      // 未到窗口时 start 可能失败；add/update 成功即可由系统到点拉起，勿抛错中断后续 P2 注册
      await startScheduledGuardStrategy(specs[i].name);
    }
    return {
      ok: true,
      data: true,
      message: effectiveSnapshot.selectedTokens.length === 0
        ? '屏时策略已注册（全锁兜底）'
        : '屏时策略已注册'
    };
  } catch (error) {
    logGuardError(`syncScheduledSessionGuardStrategy(session_${snapshot.sessionId})`, error as Object);
    return {
      ok: false,
      data: false,
      message: formatGuardError('注册屏时策略失败', error as Object)
    };
  }
}

export async function removeScheduledSessionGuardStrategy(sessionId: string): Promise<GuardResult<boolean>> {
  try {
    const names = scheduledSessionStrategyNames(sessionId);
    for (let i = 0; i < names.length; i++) {
      await stopPlanGuardStrategy(names[i]);
      await removePlanGuardStrategyInternal(names[i]);
    }
    return { ok: true, data: true, message: '屏时策略已移除' };
  } catch (error) {
    logGuardError(`removeScheduledSessionGuardStrategy(session_${sessionId})`, error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('移除屏时策略失败')
    };
  }
}

export async function syncPlanGuardStrategy(plan: FocusPlan): Promise<GuardResult<boolean>> {
  if (plan.selectedTokens.length === 0) {
    await stopPlanGuardStrategy(plan.id);
    await removePlanGuardStrategyInternal(plan.id);
    return { ok: true, data: true, message: '计划未选择应用，已移除系统契约策略' };
  }

  try {
    await addOrUpdatePlanGuardStrategy(plan);
    if (plan.enabled) {
      await startPlanGuardStrategy(plan.id);
      return { ok: true, data: true, message: '系统契约策略已更新并启用' };
    }

    await stopPlanGuardStrategy(plan.id);
    return { ok: true, data: true, message: '系统契约策略已更新并暂停' };
  } catch (error) {
    logGuardError(`syncPlanGuardStrategy(${plan.id})`, error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('同步系统契约策略失败')
    };
  }
}

export async function stopPlanGuardStrategyForWindow(planId: string): Promise<GuardResult<boolean>> {
  try {
    const sessionId = sessionIdFromGuardName(planId);
    const names = sessionId.length > 0 ? scheduledSessionStrategyNames(sessionId) : [planId];
    for (let i = 0; i < names.length; i++) {
      await stopPlanGuardStrategy(names[i]);
    }
    return { ok: true, data: true, message: '已停止当前契约窗口' };
  } catch (error) {
    logGuardError(`stopPlanGuardStrategyForWindow(${planId})`, error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('停止契约策略失败')
    };
  }
}

export async function removePlanGuardStrategy(planId: string): Promise<GuardResult<boolean>> {
  try {
    await stopPlanGuardStrategy(planId);
    await removePlanGuardStrategyInternal(planId);
    return { ok: true, data: true, message: '系统契约策略已移除' };
  } catch (error) {
    logGuardError(`removePlanGuardStrategy(${planId})`, error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('移除系统契约策略失败')
    };
  }
}

function isSessionStrategyName(strategyName: string): boolean {
  return strategyName.startsWith('session_');
}

export async function removeAllSessionGuardStrategies(): Promise<GuardResult<boolean>> {
  try {
    const existingStrategies = await guardService.queryGuardStrategies();
    for (const strategy of existingStrategies) {
      if (!isSessionStrategyName(strategy.name)) {
        continue;
      }
      await stopPlanGuardStrategy(strategy.name);
      await removePlanGuardStrategyInternal(strategy.name);
    }
    return { ok: true, data: true, message: '已移除全部定时契约屏时策略' };
  } catch (error) {
    logGuardError('removeAllSessionGuardStrategies', error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('移除定时契约屏时策略失败')
    };
  }
}

/** 退出登录 / 卸载前：移除本应用注册的全部屏时策略（含 plan_、session_、周期守护等） */
export async function removeAllGuardStrategies(): Promise<GuardResult<boolean>> {
  try {
    const existingStrategies = await guardService.queryGuardStrategies();
    for (const strategy of existingStrategies) {
      await stopPlanGuardStrategy(strategy.name);
      await removePlanGuardStrategyInternal(strategy.name);
    }
    return { ok: true, data: true, message: '已移除全部屏时策略' };
  } catch (error) {
    logGuardError('removeAllGuardStrategies', error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('移除全部屏时策略失败')
    };
  }
}

export async function pruneSessionGuardStrategies(activeSessionIds: Set<string>): Promise<GuardResult<boolean>> {
  try {
    const existingStrategies = await guardService.queryGuardStrategies();
    for (const strategy of existingStrategies) {
      if (!isSessionStrategyName(strategy.name)) {
        continue;
      }
      const sessionId = sessionIdFromGuardName(strategy.name);
      if (sessionId.length > 0 && activeSessionIds.has(sessionId)) {
        continue;
      }
      await stopPlanGuardStrategy(strategy.name);
      await removePlanGuardStrategyInternal(strategy.name);
    }
    return { ok: true, data: true, message: '已清理过期定时契约屏时策略' };
  } catch (error) {
    logGuardError('pruneSessionGuardStrategies', error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('清理过期定时契约屏时策略失败')
    };
  }
}

export async function syncAllPlanGuardStrategies(plans: FocusPlan[]): Promise<GuardResult<boolean>> {
  if (isHarmonyPcOr2in1()) {
    return { ok: true, data: true, message: 'PC/二合一设备跳过系统契约策略同步' };
  }
  if (!(await getUserAuthGranted())) {
    return { ok: false, data: false, message: '未完成系统授权，跳过系统契约策略同步' };
  }

  try {
    const existingStrategies = await guardService.queryGuardStrategies();
    const existingNames = new Set<string>(
      existingStrategies.map((strategy: guardService.GuardStrategy) => strategy.name)
    );
    const activePlanIds = new Set<string>();

    for (const plan of plans) {
      activePlanIds.add(plan.id);
      if (plan.selectedTokens.length === 0) {
        await stopPlanGuardStrategy(plan.id);
        await removePlanGuardStrategyInternal(plan.id);
        continue;
      }

      await addOrUpdatePlanGuardStrategy(plan, existingNames);
      if (plan.enabled) {
        await startPlanGuardStrategy(plan.id);
      } else {
        await stopPlanGuardStrategy(plan.id);
      }
    }

    for (const strategy of existingStrategies) {
      if (strategy.name.startsWith('plan_') && !activePlanIds.has(strategy.name)) {
        await stopPlanGuardStrategy(strategy.name);
        await removePlanGuardStrategyInternal(strategy.name);
      }
    }

    return { ok: true, data: true, message: '系统契约策略已同步' };
  } catch (error) {
    logGuardError('syncAllPlanGuardStrategies', error as Object);
    return {
      ok: false,
      data: false,
      message: toBusinessMessage('同步全部系统契约策略失败')
    };
  }
}

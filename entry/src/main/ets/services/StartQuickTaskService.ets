import { common } from '@kit.AbilityKit';
import { QuickTask } from '../models/QuickTaskModel';
import { filterSessionAppsForHarmony } from '../models/DuoModel';
import { showErrorToast, showToast } from '../common/Toast';
import { UIContext } from '@kit.ArkUI';
import { ensureSoloFocusAccess } from './GuestSoloFocusService';
import { ensureDailyFocusQuota } from './DailyFocusQuotaService';
import {
  getQuickStartDelayOptions,
  hasPendingQuickStart,
  schedulePendingQuickStart,
} from './PendingQuickStartService';
import { applyScreenRestriction } from './ScreenTimeService';
import { LockStore } from '../stores/LockStore';
import { SettingsStore } from '../stores/SettingsStore';
import { QuickFocusOptions } from '../models/ActiveLockModel';
import { AnalyticsService } from './AnalyticsService';

function resolveDelayMinutes(delayMin: number): number {
  const options = getQuickStartDelayOptions();
  return options.indexOf(delayMin) >= 0 ? delayMin : 0;
}

function resolveTaskApps(context: common.Context, task: QuickTask): string[] {
  const harmonyApps = filterSessionAppsForHarmony(task.apps);
  if (harmonyApps.length > 0) {
    return harmonyApps;
  }
  return [...SettingsStore.getState().selectedTokens];
}

export async function startQuickTask(
  context: common.UIAbilityContext,
  uiContext: UIContext,
  task: QuickTask
): Promise<boolean> {
  if (!ensureSoloFocusAccess(context)) {
    return false;
  }
  if (LockStore.isLocked()) {
    showErrorToast('已有专注任务正在进行中', uiContext);
    return false;
  }
  if (hasPendingQuickStart(context)) {
    showErrorToast('已有预约中的专注，请等待开始', uiContext);
    return false;
  }

  const selectedTokens = resolveTaskApps(context, task);

  SettingsStore.updateSelectedTokens(
    context,
    selectedTokens,
    `已载入快捷任务「${task.title}」的应用`
  );

  const delayMinutes = resolveDelayMinutes(task.delay_min);
  const title = task.title.trim().length > 0 ? task.title.trim() : '快捷任务';
  const needMinutes = task.timer_mode === 'countup' ? 0 : task.duration_min;
  if (!(await ensureDailyFocusQuota(uiContext, needMinutes))) {
    return false;
  }

  if (delayMinutes > 0) {
    const scheduled = await schedulePendingQuickStart(context, {
      title: title,
      durationMinutes: task.duration_min,
      timerMode: task.timer_mode,
      mode: task.mode,
      delayMinutes: delayMinutes,
      fromOnboarding: false,
    });
    if (!scheduled) {
      showErrorToast('预约失败，请检查健康使用设备权限', uiContext);
      return false;
    }
    showToast(`${delayMinutes} 分钟后开始专注`, uiContext);
    return true;
  }

  const result = await applyScreenRestriction(selectedTokens, task.mode);
  if (!result.ok) {
    showErrorToast(result.message, uiContext);
    return false;
  }

  const focusOptions: QuickFocusOptions = {
    title: title,
    participationMode: 'solo',
    timerMode: task.timer_mode,
    minDurationMin: task.timer_mode === 'countup' ? task.duration_min : 0,
  };
  LockStore.startQuickFocus(
    context,
    selectedTokens,
    task.duration_min,
    task.mode,
    focusOptions
  );
  AnalyticsService.trackEvent('session_started', {
    'plan_id': LockStore.getState().planId,
    'focus_type': 'once',
    'duration_minutes': task.duration_min,
    'mode': task.mode,
    'entry_source': 'quick_task',
    'is_first_focus': false
  });
  showToast('专注已开始', uiContext);
  return true;
}

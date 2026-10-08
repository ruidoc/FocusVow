/** 与 focus-rn resolveQuickPayLines + pro-quick-pay-host 文案一致（中文） */

export interface QuickPayDisplayCopy {
  line1: string;
  line2: string;
}

export function resolveQuickPaySceneLines(entrySource: string): QuickPayDisplayCopy {
  switch (entrySource) {
    case 'quick_task_slot':
    case 'quick_task_limit':
      return { line1: '免费可用 2 个快捷任务', line2: '' };
    case 'scheduled_task_slot':
    case 'scheduled_task_limit':
      return { line1: '免费可用 1 条定时任务', line2: '' };
    case 'cycle_guard':
      return {
        line1: '短视频限额为 Pro 专属',
        line2: '升级解锁防沉迷强锁',
      };
    case 'scheduled_duo':
      return {
        line1: '定时互督为 Pro 专属',
        line2: '升级立即发起定时搭子',
      };
    case 'delayed_start_limit':
      return {
        line1: '自定义延时为 Pro 专属',
        line2: '升级享无限延时专注',
      };
    case 'membership_expiring':
      return {
        line1: '会员权益即将到期',
        line2: '续费畅享无限专注',
      };
    case 'membership_last_day':
      return {
        line1: '会员还剩最后 1 天',
        line2: '现在续订特惠升级',
      };
    case 'membership_expired':
      return {
        line1: '会员已到期任务已暂停',
        line2: '立即续订恢复特权',
      };
    default:
      return { line1: '免费版额度已用完', line2: '' };
  }
}

/** subtitle=reason / title / line2 与 RN ProQuickPayPayload 同义 */
export function mergeQuickPayDisplayCopy(
  entrySource: string,
  subtitle: string,
  title: string,
  line2Override: string,
): QuickPayDisplayCopy {
  const scene = resolveQuickPaySceneLines(entrySource);
  const sub = subtitle.trim();
  const tit = title.trim();
  const line2Extra = line2Override.trim();
  const line1 = sub.length > 0 ? sub : (tit.length > 0 ? tit : scene.line1);
  const line2 = line2Extra.length > 0 ? line2Extra : scene.line2;
  return { line1, line2 };
}

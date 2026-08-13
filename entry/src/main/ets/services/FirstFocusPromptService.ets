import { common } from '@kit.AbilityKit';
import { readStoredString, writeStoredString } from './PreferencesService';

const PENDING_KEY: string = 'first_focus_prompt_pending';
const DISMISS_KEY: string = 'first_focus_prompt_dismissed_at';

export const FIRST_FOCUS_TITLE: string = '第一次专注';
export const FIRST_FOCUS_MINUTES: number = 5;

/** 引导真正走完时标记，首页通知弹完后再出首次专注引导 */
export function markFirstFocusPromptPending(context: common.Context): void {
  writeStoredString(context, PENDING_KEY, '1');
}

export function shouldShowFirstFocusPrompt(context: common.Context): boolean {
  if (readStoredString(context, DISMISS_KEY, '').length > 0) {
    return false;
  }
  return readStoredString(context, PENDING_KEY, '') === '1';
}

export function markFirstFocusPromptDone(context: common.Context): void {
  writeStoredString(context, DISMISS_KEY, String(Date.now()));
  writeStoredString(context, PENDING_KEY, '');
}

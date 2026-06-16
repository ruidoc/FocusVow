import { promptAction, UIContext, ShowToastOptions } from '@kit.ArkUI';

const DEFAULT_TOAST_DURATION: number = 2000;
const ERROR_TOAST_DURATION: number = 3000;

export function showToast(
  message: string,
  uiContext?: UIContext,
  duration: number = DEFAULT_TOAST_DURATION
): void {
  const options: ShowToastOptions = {
    message,
    duration
  };

  if (uiContext) {
    uiContext.getPromptAction().showToast(options);
    return;
  }

  promptAction.showToast(options);
}

export function showErrorToast(
  message: string,
  uiContext?: UIContext,
  fallback: string = '操作失败，请稍后重试'
): void {
  const text = message.length > 0 ? message : fallback;
  showToast(text, uiContext, ERROR_TOAST_DURATION);
}

import { promptAction, UIContext, ShowToastOptions } from '@kit.ArkUI';

const DEFAULT_TOAST_DURATION: number = 2000;

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

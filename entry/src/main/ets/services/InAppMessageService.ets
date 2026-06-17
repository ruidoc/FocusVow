import { createHiddenInAppMessage, InAppMessageView } from '../models/InAppMessageModel';
import { StoreKeys } from '../stores/StoreKeys';

const DEFAULT_DURATION_MS: number = 4500;

let dismissTimerId: number = -1;

export class InAppMessageService {
  static show(title: string, message: string, type: string = '', durationMs: number = DEFAULT_DURATION_MS): void {
    const normalizedTitle = title.length > 0 ? title : '专注契约提醒';
    const normalizedMessage = message.length > 0 ? message : '你有一条新的专注通知';
    const nextMessage: InAppMessageView = {
      id: `${Date.now()}`,
      title: normalizedTitle,
      message: normalizedMessage,
      type,
      visible: true
    };

    AppStorage.setOrCreate(StoreKeys.InAppMessage, nextMessage);
    InAppMessageService.scheduleDismiss(durationMs);
  }

  static dismiss(): void {
    InAppMessageService.clearDismissTimer();
    const current = AppStorage.get<InAppMessageView>(StoreKeys.InAppMessage) ?? createHiddenInAppMessage();
    if (!current.visible) {
      return;
    }

    AppStorage.setOrCreate(StoreKeys.InAppMessage, {
      id: current.id,
      title: current.title,
      message: current.message,
      type: current.type,
      visible: false
    });
  }

  private static scheduleDismiss(durationMs: number): void {
    InAppMessageService.clearDismissTimer();
    dismissTimerId = setTimeout(() => {
      dismissTimerId = -1;
      InAppMessageService.dismiss();
    }, durationMs);
  }

  private static clearDismissTimer(): void {
    if (dismissTimerId !== -1) {
      clearTimeout(dismissTimerId);
      dismissTimerId = -1;
    }
  }
}

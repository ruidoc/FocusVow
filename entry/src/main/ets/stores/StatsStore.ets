import { refreshHomeRecordStatis } from './HomeRecordStatStore';

let reloadHandler: (() => void) | null = null;
let homeReloadHandler: (() => void) | null = null;

export function registerStatsReload(handler: () => void): void {
  reloadHandler = handler;
}

export function unregisterStatsReload(): void {
  reloadHandler = null;
}

/** 首页今日卡片与 RN getStatis 同源，专注结束等场景与统计 Tab 一并刷新 */
export function registerHomeStatsReload(handler: () => void): void {
  homeReloadHandler = handler;
}

export function unregisterHomeStatsReload(): void {
  homeReloadHandler = null;
}

export function refreshStats(): void {
  reloadHandler?.();
  if (homeReloadHandler) {
    homeReloadHandler();
    return;
  }
  void refreshHomeRecordStatis();
}

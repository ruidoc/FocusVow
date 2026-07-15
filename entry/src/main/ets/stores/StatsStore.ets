let reloadHandler: (() => void) | null = null;

export function registerStatsReload(handler: () => void): void {
  reloadHandler = handler;
}

export function unregisterStatsReload(): void {
  reloadHandler = null;
}

export function refreshStats(): void {
  reloadHandler?.();
}

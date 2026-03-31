export enum FocusRunStatus {
  Idle = 'idle',
  Running = 'running',
  Finished = 'finished'
}

export interface FocusSession {
  selectedTokens: string[];
  selectedCount: number;
  durationMinutes: number;
  startAt: number;
  endAt: number;
  status: FocusRunStatus;
}

export function createFocusSession(selectedTokens: string[], durationMinutes: number, startAt: number): FocusSession {
  const safeDuration = durationMinutes > 0 ? durationMinutes : 25;

  return {
    selectedTokens: [...selectedTokens],
    selectedCount: selectedTokens.length,
    durationMinutes: safeDuration,
    startAt,
    endAt: startAt + safeDuration * 60 * 1000,
    status: FocusRunStatus.Running
  };
}

export function getRemainingSeconds(session: FocusSession, nowAt: number): number {
  const remainMs = session.endAt - nowAt;
  if (remainMs <= 0) {
    return 0;
  }

  return Math.ceil(remainMs / 1000);
}

export function isFocusSessionFinished(session: FocusSession, nowAt: number): boolean {
  return getRemainingSeconds(session, nowAt) === 0;
}

export function formatRemainingSeconds(totalSeconds: number): string {
  const safeSeconds = Math.max(0, totalSeconds);
  const minutes = Math.floor(safeSeconds / 60);
  const seconds = safeSeconds % 60;

  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

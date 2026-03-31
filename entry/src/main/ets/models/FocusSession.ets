export type RestrictionMode = 'shield' | 'allow';

export enum FocusSource {
  QuickStart = 'quick_start',
  Plan = 'plan'
}

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
  source: FocusSource;
  planId: string;
  planName: string;
  mode: RestrictionMode;
}

export function createIdleFocusSession(durationMinutes: number = 25): FocusSession {
  return {
    selectedTokens: [],
    selectedCount: 0,
    durationMinutes,
    startAt: 0,
    endAt: 0,
    status: FocusRunStatus.Idle,
    source: FocusSource.QuickStart,
    planId: '',
    planName: '',
    mode: 'shield'
  };
}

export function createFocusSession(
  selectedTokens: string[],
  durationMinutes: number,
  startAt: number,
  source: FocusSource = FocusSource.QuickStart,
  planId: string = '',
  planName: string = '',
  mode: RestrictionMode = 'shield'
): FocusSession {
  const safeDuration = durationMinutes > 0 ? durationMinutes : 25;

  return {
    selectedTokens: [...selectedTokens],
    selectedCount: selectedTokens.length,
    durationMinutes: safeDuration,
    startAt,
    endAt: startAt + safeDuration * 60 * 1000,
    status: FocusRunStatus.Running,
    source,
    planId,
    planName,
    mode
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

export type FocusSyncResult = 'SUCCESS' | 'VIOLATION';

export type FocusSyncKind = 'solo_instant' | 'session_terminal';

export interface FocusSyncPending {
  kind: FocusSyncKind;
  client_key: string;
  result: FocusSyncResult;
  ended_at: number;
  started_at?: number;
  title?: string;
  duration_min?: number;
  actual_min?: number;
  mode?: string;
  apps?: string[];
  participation_mode?: string;
  fail_reason?: string;
  duo_session_id?: string;
  record_id?: string;
  timer_mode?: string;
}

export function buildSoloInstantClientKey(planIdOrStartedAt: string | number): string {
  if (
    typeof planIdOrStartedAt === 'string' &&
    planIdOrStartedAt.startsWith('once_')
  ) {
    return `solo_plan_${planIdOrStartedAt}`;
  }
  return `solo_${planIdOrStartedAt}`;
}

export function buildSessionTerminalClientKey(duoSessionId: string): string {
  return `session_${duoSessionId}`;
}

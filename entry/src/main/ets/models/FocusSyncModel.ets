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
}

export function buildSoloInstantClientKey(startedAt: number): string {
  return `solo_${startedAt}`;
}

export function buildSessionTerminalClientKey(duoSessionId: string): string {
  return `session_${duoSessionId}`;
}

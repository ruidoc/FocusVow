import { describe, it, expect } from '@ohos/hypium';
import {
  FocusSource,
  createFocusSession,
  formatRemainingSeconds,
  getRemainingSeconds,
  isFocusSessionFinished
} from '../main/ets/models/FocusSession';

export default function focusSessionTest() {
  describe('focusSessionTest', () => {
    it('creates a running session with expected timestamps', 0, () => {
      const startAt = 1_700_000_000_000;
      const session = createFocusSession(['token-a', 'token-b'], 25, startAt, FocusSource.Plan, 'plan-1', '晨间专注');

      expect(session.durationMinutes).assertEqual(25);
      expect(session.selectedCount).assertEqual(2);
      expect(session.startAt).assertEqual(startAt);
      expect(session.endAt).assertEqual(startAt + 25 * 60 * 1000);
      expect(session.status).assertEqual('running');
      expect(session.source).assertEqual('plan');
      expect(session.planId).assertEqual('plan-1');
      expect(session.planName).assertEqual('晨间专注');
    });

    it('calculates remaining seconds and finish state', 0, () => {
      const startAt = 1_700_000_000_000;
      const session = createFocusSession(['token-a'], 10, startAt);

      expect(getRemainingSeconds(session, startAt + 2 * 60 * 1000)).assertEqual(8 * 60);
      expect(isFocusSessionFinished(session, startAt + 9 * 60 * 1000)).assertFalse();
      expect(isFocusSessionFinished(session, startAt + 10 * 60 * 1000)).assertTrue();
      expect(getRemainingSeconds(session, startAt + 12 * 60 * 1000)).assertEqual(0);
    });

    it('formats remaining seconds as mm:ss', 0, () => {
      expect(formatRemainingSeconds(5)).assertEqual('00:05');
      expect(formatRemainingSeconds(65)).assertEqual('01:05');
      expect(formatRemainingSeconds(600)).assertEqual('10:00');
    });
  });
}

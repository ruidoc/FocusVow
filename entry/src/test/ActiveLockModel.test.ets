import { describe, it, expect } from '@ohos/hypium';
import {
  createQuickFocusLockState,
  formatRemainingSeconds,
  getRemainingSeconds,
  isTimedLockFinished
} from '../main/ets/models/ActiveLockModel';

export default function activeLockModelTest() {
  describe('activeLockModelTest', () => {
    it('creates a quick focus lock with expected timestamps', 0, () => {
      const startAt = 1_700_000_000_000;
      const lock = createQuickFocusLockState(['token-a', 'token-b'], 25, 'shield', startAt);

      expect(lock.kind).assertEqual('quick_focus');
      expect(lock.selectedCount).assertEqual(2);
      expect(lock.startedAt).assertEqual(startAt);
      expect(lock.endAt).assertEqual(startAt + 25 * 60 * 1000);
      expect(lock.title).assertEqual('单人专注');
    });

    it('aligns quick focus lock to server end_at', 0, () => {
      const nowAt = 1_700_000_000_000;
      const serverStart = nowAt - 60_000;
      const serverEnd = nowAt + 9 * 60 * 1000;
      const lock = createQuickFocusLockState(
        ['token-a'],
        10,
        'allow',
        nowAt,
        '搭子互督',
        'session-1',
        'record-1',
        'duo',
        '搭子',
        serverStart,
        serverEnd
      );

      expect(lock.startedAt).assertEqual(serverStart);
      expect(lock.endAt).assertEqual(serverEnd);
      expect(getRemainingSeconds(lock, nowAt)).assertEqual(9 * 60);
    });

    it('calculates remaining seconds and finish state', 0, () => {
      const startAt = 1_700_000_000_000;
      const lock = createQuickFocusLockState(['token-a'], 10, 'shield', startAt);

      expect(getRemainingSeconds(lock, startAt + 2 * 60 * 1000)).assertEqual(8 * 60);
      expect(isTimedLockFinished(lock, startAt + 9 * 60 * 1000)).assertFalse();
      expect(isTimedLockFinished(lock, startAt + 10 * 60 * 1000)).assertTrue();
      expect(getRemainingSeconds(lock, startAt + 12 * 60 * 1000)).assertEqual(0);
    });

    it('formats remaining seconds as mm:ss', 0, () => {
      expect(formatRemainingSeconds(5)).assertEqual('00:05');
      expect(formatRemainingSeconds(65)).assertEqual('01:05');
      expect(formatRemainingSeconds(600)).assertEqual('10:00');
    });
  });
}

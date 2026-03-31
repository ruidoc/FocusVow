import localUnitTest from './LocalUnit.test';
import focusSessionTest from './FocusSession.test';

export default function testsuite() {
  localUnitTest();
  focusSessionTest();
}
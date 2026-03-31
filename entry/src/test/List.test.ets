import localUnitTest from './LocalUnit.test';
import focusSessionTest from './FocusSession.test';
import planModelTest from './PlanModel.test';

export default function testsuite() {
  localUnitTest();
  focusSessionTest();
  planModelTest();
}
import localUnitTest from './LocalUnit.test';
import activeLockModelTest from './ActiveLockModel.test';
import planModelTest from './PlanModel.test';

export default function testsuite() {
  localUnitTest();
  activeLockModelTest();
  planModelTest();
}
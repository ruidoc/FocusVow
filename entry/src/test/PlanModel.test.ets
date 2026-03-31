import { describe, it, expect } from '@ohos/hypium';
import {
  createPlanFromDraft,
  filterPlansByScope,
  getPlanDurationMinutes,
  removePlanById,
  summarizeRepeatDays,
  upsertPlan
} from '../main/ets/models/PlanModel';

export default function planModelTest() {
  describe('planModelTest', () => {
    it('creates a normalized local plan from draft data', 0, () => {
      const plan = createPlanFromDraft({
        name: '晨间专注',
        startTime: '9:30',
        endTime: '18:5',
        repeatDays: [1, 2, 3, 4, 5],
        selectedTokens: ['app-a', 'app-b'],
        mode: 'allow'
      }, 1_700_000_000_000);

      expect(plan.name).assertEqual('晨间专注');
      expect(plan.startTime).assertEqual('09:30');
      expect(plan.endTime).assertEqual('18:05');
      expect(plan.selectedCount).assertEqual(2);
      expect(plan.mode).assertEqual('allow');
      expect(plan.enabled).assertTrue();
      expect(getPlanDurationMinutes(plan)).assertEqual(515);
    });

    it('clamps invalid hours and minutes into valid ranges', 0, () => {
      const plan = createPlanFromDraft({
        name: '边界测试',
        startTime: '27:75',
        endTime: '-1:90',
        repeatDays: [1],
        selectedTokens: ['app-a'],
        mode: 'shield'
      }, 1_700_000_000_900);

      expect(plan.startTime).assertEqual('23:59');
      expect(plan.endTime).assertEqual('00:59');
    });

    it('upserts and removes plans by id', 0, () => {
      const first = createPlanFromDraft({
        name: '晨间专注',
        startTime: '08:00',
        endTime: '10:00',
        repeatDays: [1, 2, 3],
        selectedTokens: ['app-a'],
        mode: 'shield'
      }, 1_700_000_000_000);

      const second = createPlanFromDraft({
        name: '夜间专注',
        startTime: '21:00',
        endTime: '22:00',
        repeatDays: [5, 6, 0],
        selectedTokens: ['app-b'],
        mode: 'shield'
      }, 1_700_000_000_500);

      const updatedFirst = { ...first, name: '晨间深度专注' };
      const upserted = upsertPlan(upsertPlan([], first), second);
      const replaced = upsertPlan(upserted, updatedFirst);

      expect(replaced.length).assertEqual(2);
      expect(replaced[0].name).assertEqual('晨间深度专注');

      const removed = removePlanById(replaced, second.id);
      expect(removed.length).assertEqual(1);
      expect(removed[0].id).assertEqual(first.id);
    });

    it('filters plans and summarizes repeat days', 0, () => {
      const weekdayPlan = createPlanFromDraft({
        name: '工作日专注',
        startTime: '09:00',
        endTime: '18:00',
        repeatDays: [1, 2, 3, 4, 5],
        selectedTokens: ['app-a'],
        mode: 'shield'
      }, 1_700_000_000_000);

      const weekendPlan = createPlanFromDraft({
        name: '周末专注',
        startTime: '10:00',
        endTime: '12:00',
        repeatDays: [0, 6],
        selectedTokens: ['app-b'],
        mode: 'shield'
      }, 1_700_000_000_500);

      const todayPlans = filterPlansByScope([weekdayPlan, weekendPlan], 'today', 1);
      const allPlans = filterPlansByScope([weekdayPlan, weekendPlan], 'all', 1);

      expect(todayPlans.length).assertEqual(1);
      expect(todayPlans[0].name).assertEqual('工作日专注');
      expect(allPlans.length).assertEqual(2);
      expect(summarizeRepeatDays([1, 2, 3, 4, 5])).assertEqual('工作日');
      expect(summarizeRepeatDays([0, 6])).assertEqual('周末');
    });
  });
}

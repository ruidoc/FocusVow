import { common } from '@kit.AbilityKit';
import { FocusPlan, PlanFilterScope } from '../models/PlanModel';
import { readStoredString, writeStoredString } from './PreferencesService';

const PLAN_COLLECTION_KEY: string = 'plan.collection';
const PLAN_FILTER_SCOPE_KEY: string = 'plan.filterScope';

export function loadPersistedPlans(context: common.UIAbilityContext): FocusPlan[] {
  const rawValue = readStoredString(context, PLAN_COLLECTION_KEY, '[]');
  try {
    return JSON.parse(rawValue) as FocusPlan[];
  } catch {
    console.error('Failed to parse persisted plans.');
    return [];
  }
}

export function savePersistedPlans(context: common.UIAbilityContext, plans: FocusPlan[]): boolean {
  return writeStoredString(context, PLAN_COLLECTION_KEY, JSON.stringify(plans));
}

export function loadPersistedPlanFilterScope(context: common.UIAbilityContext): PlanFilterScope {
  const rawValue = readStoredString(context, PLAN_FILTER_SCOPE_KEY, 'today');
  return rawValue === 'all' ? 'all' : 'today';
}

export function savePersistedPlanFilterScope(
  context: common.UIAbilityContext,
  scope: PlanFilterScope
): boolean {
  return writeStoredString(context, PLAN_FILTER_SCOPE_KEY, scope);
}

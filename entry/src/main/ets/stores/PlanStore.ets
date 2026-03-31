import { common } from '@kit.AbilityKit';
import {
  FocusPlan,
  PlanDraft,
  PlanFilterScope,
  createPlanFromDraft,
  filterPlansByScope,
  getPlanById,
  removePlanById,
  updatePlanFromDraft,
  upsertPlan
} from '../models/PlanModel';
import {
  loadPersistedPlanFilterScope,
  loadPersistedPlans,
  savePersistedPlanFilterScope,
  savePersistedPlans
} from '../services/PlanPersistenceService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

function getTodayWeekday(): number {
  const jsWeekday = new Date().getDay();
  return jsWeekday;
}

export class PlanStore {
  static hydrate(context: common.UIAbilityContext): void {
    bootstrapStores();
    const persistedPlans = loadPersistedPlans(context);
    const persistedFilterScope = loadPersistedPlanFilterScope(context);
    AppStorage.setOrCreate(StoreKeys.PlanCollection, persistedPlans);
    AppStorage.setOrCreate(StoreKeys.PlanFilterScope, persistedFilterScope);
  }

  static getPlans(): FocusPlan[] {
    bootstrapStores();
    return AppStorage.get<FocusPlan[]>(StoreKeys.PlanCollection) ?? [];
  }

  static getCurrentPlanId(): string {
    bootstrapStores();
    return AppStorage.get<string>(StoreKeys.PlanCurrentId) ?? '';
  }

  static setCurrentPlanId(planId: string): void {
    bootstrapStores();
    AppStorage.setOrCreate(StoreKeys.PlanCurrentId, planId);
  }

  static getCurrentPlan(): FocusPlan | undefined {
    return getPlanById(PlanStore.getPlans(), PlanStore.getCurrentPlanId());
  }

  static getFilterScope(): PlanFilterScope {
    bootstrapStores();
    return (AppStorage.get<string>(StoreKeys.PlanFilterScope) ?? 'today') as PlanFilterScope;
  }

  static setFilterScope(context: common.UIAbilityContext, scope: PlanFilterScope): void {
    bootstrapStores();
    AppStorage.setOrCreate(StoreKeys.PlanFilterScope, scope);
    savePersistedPlanFilterScope(context, scope);
  }

  static getFilteredPlans(): FocusPlan[] {
    return filterPlansByScope(PlanStore.getPlans(), PlanStore.getFilterScope(), getTodayWeekday());
  }

  static savePlan(context: common.UIAbilityContext, draft: PlanDraft, planId?: string): FocusPlan {
    bootstrapStores();
    const existingPlan = planId ? getPlanById(PlanStore.getPlans(), planId) : undefined;
    const nextPlan = existingPlan
      ? updatePlanFromDraft(existingPlan, draft, Date.now())
      : createPlanFromDraft(draft, Date.now());

    const nextPlans = upsertPlan(PlanStore.getPlans(), nextPlan);
    AppStorage.setOrCreate(StoreKeys.PlanCollection, nextPlans);
    savePersistedPlans(context, nextPlans);
    PlanStore.setCurrentPlanId(nextPlan.id);
    return nextPlan;
  }

  static togglePlanEnabled(context: common.UIAbilityContext, planId: string, enabled: boolean): void {
    const currentPlan = getPlanById(PlanStore.getPlans(), planId);
    if (!currentPlan) {
      return;
    }

    const nextPlan: FocusPlan = {
      id: currentPlan.id,
      name: currentPlan.name,
      startTime: currentPlan.startTime,
      endTime: currentPlan.endTime,
      repeatDays: currentPlan.repeatDays,
      selectedTokens: currentPlan.selectedTokens,
      selectedCount: currentPlan.selectedCount,
      mode: currentPlan.mode,
      enabled,
      createdAt: currentPlan.createdAt,
      updatedAt: Date.now()
    };
    const nextPlans = upsertPlan(PlanStore.getPlans(), nextPlan);
    AppStorage.setOrCreate(StoreKeys.PlanCollection, nextPlans);
    savePersistedPlans(context, nextPlans);
  }

  static removePlan(context: common.UIAbilityContext, planId: string): void {
    const nextPlans = removePlanById(PlanStore.getPlans(), planId);
    AppStorage.setOrCreate(StoreKeys.PlanCollection, nextPlans);
    savePersistedPlans(context, nextPlans);
    if (PlanStore.getCurrentPlanId() === planId) {
      PlanStore.setCurrentPlanId('');
    }
  }

  static reset(context: common.UIAbilityContext): void {
    AppStorage.setOrCreate(StoreKeys.PlanCollection, []);
    AppStorage.setOrCreate(StoreKeys.PlanCurrentId, '');
    savePersistedPlans(context, []);
    savePersistedPlanFilterScope(context, 'today');
  }
}

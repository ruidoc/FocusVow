import { common } from '@kit.AbilityKit';
import { CycleGuardState } from '../models/CycleGuardModel';
import { readStoredString, writeStoredString } from './PreferencesService';

const CYCLE_GUARD_STATE_KEY: string = 'cycle.guard.state';

export function loadPersistedCycleGuardState(context: common.Context): CycleGuardState | null {
  const rawValue = readStoredString(context, CYCLE_GUARD_STATE_KEY, '');
  if (rawValue.length === 0) {
    return null;
  }

  try {
    return JSON.parse(rawValue) as CycleGuardState;
  } catch {
    console.error('Failed to parse persisted cycle guard state.');
    return null;
  }
}

export function savePersistedCycleGuardState(
  context: common.Context,
  state: CycleGuardState
): boolean {
  return writeStoredString(context, CYCLE_GUARD_STATE_KEY, JSON.stringify(state));
}

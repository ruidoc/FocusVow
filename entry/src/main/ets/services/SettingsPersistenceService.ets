import { common } from '@kit.AbilityKit';
import { SettingsState } from '../models/PermissionModel';
import { readStoredString, writeStoredString } from './PreferencesService';

const SETTINGS_STATE_KEY: string = 'settings.state';

export function loadPersistedSettings(context: common.UIAbilityContext): SettingsState | null {
  const rawValue = readStoredString(context, SETTINGS_STATE_KEY, '');
  if (rawValue.length === 0) {
    return null;
  }

  try {
    return JSON.parse(rawValue) as SettingsState;
  } catch {
    console.error('Failed to parse persisted settings.');
    return null;
  }
}

export function savePersistedSettings(context: common.UIAbilityContext, settingsState: SettingsState): boolean {
  return writeStoredString(context, SETTINGS_STATE_KEY, JSON.stringify(settingsState));
}

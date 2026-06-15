import { common } from '@kit.AbilityKit';
import { UserInfo } from '../models/UserModel';
import { readStoredString, removeStoredKey, writeStoredString } from './PreferencesService';

const ACCESS_TOKEN_KEY: string = 'user.accessToken';
const USER_INFO_KEY: string = 'user.info';

export function loadAccessToken(context: common.Context): string {
  return readStoredString(context, ACCESS_TOKEN_KEY, '');
}

export function saveAccessToken(context: common.Context, token: string): boolean {
  return writeStoredString(context, ACCESS_TOKEN_KEY, token);
}

export function loadPersistedUserInfo(context: common.Context): UserInfo | null {
  const rawValue = readStoredString(context, USER_INFO_KEY, '');
  if (rawValue.length === 0) {
    return null;
  }

  try {
    return JSON.parse(rawValue) as UserInfo;
  } catch {
    console.error('Failed to parse persisted user info.');
    return null;
  }
}

export function savePersistedUserInfo(context: common.Context, userInfo: UserInfo): boolean {
  return writeStoredString(context, USER_INFO_KEY, JSON.stringify(userInfo));
}

export function clearUserSession(context: common.Context): void {
  removeStoredKey(context, ACCESS_TOKEN_KEY);
  removeStoredKey(context, USER_INFO_KEY);
}

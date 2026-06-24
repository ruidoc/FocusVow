import { common } from '@kit.AbilityKit';
import { createEmptyUserInfo, parseUserInfo, UserInfo } from '../models/UserModel';
import { AuthApiService } from '../services/AuthApiService';
import { ExtendApiService } from '../services/ExtendApiService';
import { FocusSyncService } from '../services/FocusSyncService';
import { UmengSdkService } from '../services/UmengSdkService';
import {
  clearUserSession,
  loadAccessToken,
  loadPersistedUserInfo,
  saveAccessToken,
  savePersistedUserInfo
} from '../services/UserPersistenceService';
import { bootstrapStores } from './StoreBootstrap';
import { StoreKeys } from './StoreKeys';

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

export class UserStore {
  static hydrate(context: common.UIAbilityContext): void {
    bootstrapStores();
    const token = loadAccessToken(context);
    const userInfo = loadPersistedUserInfo(context);
    const isLoggedIn = token.length > 0 && userInfo !== null;

    syncAppStorageValue(StoreKeys.UserAccessToken, token);
    syncAppStorageValue(StoreKeys.UserIsLoggedIn, isLoggedIn);
    syncAppStorageValue(StoreKeys.UserInfo, userInfo ?? createEmptyUserInfo());
  }

  static getAccessToken(): string {
    bootstrapStores();
    return AppStorage.get<string>(StoreKeys.UserAccessToken) ?? '';
  }

  static getUserInfo(): UserInfo {
    bootstrapStores();
    return AppStorage.get<UserInfo>(StoreKeys.UserInfo) ?? createEmptyUserInfo();
  }

  static isLoggedIn(): boolean {
    bootstrapStores();
    return AppStorage.get<boolean>(StoreKeys.UserIsLoggedIn) ?? false;
  }

  static async loginWithEmail(
    context: common.UIAbilityContext,
    email: string,
    password: string
  ): Promise<string | null> {
    const response = await AuthApiService.loginWithEmail(email.trim(), password);
    if (response.statusCode !== 200) {
      return response.message ?? '登录失败';
    }

    const token = String(response.data?.['token'] ?? '');
    if (token.length === 0) {
      return '登录失败：未返回 token';
    }

    return UserStore.applySessionToken(context, token);
  }

  static async registerWithEmail(
    context: common.UIAbilityContext,
    email: string,
    username: string,
    password: string,
    verifyCode: string
  ): Promise<string | null> {
    const trimmedEmail = email.trim();
    const trimmedCode = verifyCode.trim();
    const verifyResponse = await ExtendApiService.verifyEmailCode(trimmedEmail, trimmedCode);
    if (verifyResponse.statusCode !== 200) {
      return verifyResponse.message ?? '验证码错误或已过期';
    }

    const registerResponse = await AuthApiService.registerWithEmail(
      trimmedEmail,
      username.trim(),
      password
    );
    if (registerResponse.statusCode !== 200) {
      return registerResponse.message ?? '注册失败';
    }

    return UserStore.loginWithEmail(context, trimmedEmail, password);
  }

  static async refreshUserInfo(context: common.UIAbilityContext): Promise<string | null> {
    const response = await AuthApiService.fetchSelfInfo();
    if (response.statusCode === 401) {
      UserStore.logout(context);
      return response.message ?? '请重新登录';
    }
    if (response.statusCode !== 200) {
      return response.message ?? '获取用户信息失败';
    }

    const userInfo = parseUserInfo(response.data);
    if (!userInfo) {
      return '用户信息格式异常';
    }

    savePersistedUserInfo(context, userInfo);
    syncAppStorageValue(StoreKeys.UserInfo, userInfo);
    syncAppStorageValue(StoreKeys.UserIsLoggedIn, true);
    UmengSdkService.ensureInitialized(context);
    UmengSdkService.bindUserAlias(userInfo.id);
    return null;
  }

  static async syncRemoteIfLoggedIn(context: common.UIAbilityContext): Promise<void> {
    if (!UserStore.isLoggedIn()) {
      return;
    }
    const errorMessage = await UserStore.refreshUserInfo(context);
    if (errorMessage) {
      console.warn(`UserStore sync skipped: ${errorMessage}`);
    }
  }

  static logout(context: common.UIAbilityContext): void {
    bootstrapStores();
    UmengSdkService.clearUserAlias();
    clearUserSession(context);
    syncAppStorageValue(StoreKeys.UserAccessToken, '');
    syncAppStorageValue(StoreKeys.UserIsLoggedIn, false);
    syncAppStorageValue(StoreKeys.UserInfo, createEmptyUserInfo());
  }

  private static async applySessionToken(
    context: common.UIAbilityContext,
    token: string
  ): Promise<string | null> {
    saveAccessToken(context, token);
    syncAppStorageValue(StoreKeys.UserAccessToken, token);
    syncAppStorageValue(StoreKeys.UserIsLoggedIn, true);

    const refreshError = await UserStore.refreshUserInfo(context);
    if (refreshError) {
      UserStore.logout(context);
      return refreshError;
    }
    void FocusSyncService.flushPending(context);
    return null;
  }
}

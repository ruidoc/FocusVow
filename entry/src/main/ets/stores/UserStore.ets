import { common } from '@kit.AbilityKit';
import {
  createEmptyUserInfo,
  createEmptyWxPendingInfo,
  parseUserInfo,
  parseWxPendingInfo,
  UserInfo,
  WxPendingInfo
} from '../models/UserModel';
import { AuthApiService } from '../services/AuthApiService';
import { compressAvatarForUpload } from '../services/AvatarCompressService';
import { ExtendApiService } from '../services/ExtendApiService';
import { FocusSyncService } from '../services/FocusSyncService';
import { syncAllPlanGuardStrategies } from '../services/ScreenTimeService';
import { clearAllScheduledGuardOnLogout, clearScheduledGuardSyncFlags, loadScheduledListOnLogin, markAwaitingScheduledGuardSyncCheck } from '../services/ScheduledCovenantService';
import { clearExitPlanIds } from '../services/ExitPlanIdsService';
import { WeChatOpenService } from '../services/WeChatOpenService';
import { HuaweiAccountService } from '../services/HuaweiAccountService';
import { PlanStore } from './PlanStore';
import { QuickTaskStore } from './QuickTaskStore';
import { CycleGuardStore } from './CycleGuardStore';
import { BenefitStore } from './BenefitStore';
import { InboxStore } from './InboxStore';
import { refreshStats } from './StatsStore';
import { AnalyticsService, LoginMethod } from '../services/AnalyticsService';
import { UmengSdkService } from '../services/UmengSdkService';
import { ensureOnboardingDeviceId, OnboardingApiService } from '../services/OnboardingApiService';
import {
  clearUserSession,
  loadAccessToken,
  loadPersistedUserInfo,
  saveAccessToken,
  savePersistedUserInfo
} from '../services/UserPersistenceService';
import { ReferralApiService } from '../services/ReferralApiService';
import { clearDuoWaitContext } from '../services/DuoWaitContextService';
import {
  clearPendingReferralCode,
  getPendingReferralCode,
  normalizeReferralCode,
  savePendingReferralCode
} from '../utils/ReferralUtil';
import {
  clearSignupTrialEligible,
  setSignupTrialEligible
} from '../utils/SignupTrialUtil';
import {
  buildOnboardingAnalyticsProps,
  resolveSignupPath,
} from '../utils/OnboardingMetaUtil';
import { StoreKeys } from './StoreKeys';
import { bootstrapStores } from './StoreBootstrap';

function syncAppStorageValue<T>(key: string, value: T): void {
  if (!AppStorage.set<T>(key, value)) {
    AppStorage.setOrCreate<T>(key, value);
  }
}

/** 复制 UserInfo，保证 AppStorage 写入新引用以触发 @StorageLink */
function cloneUserInfo(source: UserInfo): UserInfo {
  const cloned: UserInfo = {
    id: source.id,
    username: source.username,
    phone: source.phone,
    email: source.email,
    avatar: source.avatar,
    sex: source.sex,
    invite_code: source.invite_code,
    openid: source.openid,
    huawei_id: source.huawei_id
  };
  return cloned;
}

function cloneWxPending(source: WxPendingInfo): WxPendingInfo {
  return {
    openid: source.openid,
    unionid: source.unionid,
    nickname: source.nickname,
    headimgurl: source.headimgurl,
    sex: source.sex
  };
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

  static getWxPendingInfo(): WxPendingInfo {
    bootstrapStores();
    return AppStorage.get<WxPendingInfo>(StoreKeys.WxPendingInfo) ?? createEmptyWxPendingInfo();
  }

  static setWxPendingInfo(info: WxPendingInfo | null): void {
    bootstrapStores();
    syncAppStorageValue(
      StoreKeys.WxPendingInfo,
      info ? cloneWxPending(info) : createEmptyWxPendingInfo()
    );
  }

  static lastLoginUserId: string = '';
  static lastLoginIsNew: boolean = false;

  /** 微信新用户需绑邮箱时的标记，非错误文案 */
  static readonly WECHAT_NEED_BIND: string = 'WECHAT_NEED_BIND';

  static async loginWithEmail(
    context: common.UIAbilityContext,
    email: string,
    password: string,
    isNew: boolean = false
  ): Promise<string | null> {
    const response = await AuthApiService.loginWithEmail(email.trim(), password);
    if (response.statusCode !== 200) {
      return response.message ?? '登录失败';
    }

    const token = String(response.data?.['token'] ?? '');
    if (token.length === 0) {
      return '登录失败：未返回 token';
    }
    UserStore.lastLoginUserId = String(response.data?.['user_id'] ?? '');
    return UserStore.applySessionToken(context, token, 'email', isNew);
  }

  static async loginWithWechat(context: common.UIAbilityContext): Promise<string | null> {
    const auth = await WeChatOpenService.requestAuthCode(context);
    if (!auth.ok) {
      if (auth.cancelled) {
        return null;
      }
      return auth.message.length > 0 ? auth.message : '微信授权失败';
    }

    const response = await AuthApiService.loginWithWechatCode(auth.code);
    if (response.statusCode === 20003) {
      const pending = parseWxPendingInfo(response.data);
      if (!pending) {
        return '微信资料缺失，请重试';
      }
      UserStore.setWxPendingInfo(pending);
      return UserStore.WECHAT_NEED_BIND;
    }
    if (response.statusCode !== 200) {
      return response.message ?? '微信登录失败';
    }
    const token = String(response.data?.['token'] ?? '');
    if (token.length === 0) {
      return '微信登录失败：未返回 token';
    }
    UserStore.lastLoginUserId = String(response.data?.['user_id'] ?? '');
    UserStore.setWxPendingInfo(null);
    return UserStore.applySessionToken(
      context,
      token,
      'wechat',
      response.data?.['is_new'] === true
    );
  }

  static async loginWithHuawei(context: common.UIAbilityContext): Promise<string | null> {
    const auth = await HuaweiAccountService.requestIdToken(context);
    if (!auth.ok) {
      if (auth.cancelled) {
        return null;
      }
      return auth.message.length > 0 ? auth.message : '华为账号授权失败';
    }

    const response = await AuthApiService.loginWithHuawei(
      auth.code,
      auth.idToken,
      auth.nickName.trim(),
      auth.avatarUri.trim()
    );
    if (response.statusCode !== 200) {
      return response.message ?? '华为账号登录失败';
    }
    const token = String(response.data?.['token'] ?? '');
    if (token.length === 0) {
      return '华为账号登录失败：未返回 token';
    }
    UserStore.lastLoginUserId = String(response.data?.['user_id'] ?? '');
    return UserStore.applySessionToken(
      context,
      token,
      'huawei',
      response.data?.['is_new'] === true
    );
  }

  static async wechatBindByEmail(
    context: common.UIAbilityContext,
    email: string,
    code: string
  ): Promise<string | null> {
    const pending = UserStore.getWxPendingInfo();
    if (pending.openid.length === 0) {
      return '微信信息缺失，请重新登录';
    }
    const wxBody: Record<string, Object> = {
      'openid': pending.openid,
      'unionid': pending.unionid,
      'nickname': pending.nickname,
      'headimgurl': pending.headimgurl,
      'sex': pending.sex
    };
    const response = await AuthApiService.wechatBindByEmail(email.trim(), code.trim(), wxBody);
    if (response.statusCode !== 200) {
      return response.message ?? '绑定失败';
    }
    const token = String(response.data?.['token'] ?? '');
    if (token.length === 0) {
      return '绑定失败：未返回 token';
    }
    UserStore.lastLoginUserId = String(response.data?.['user_id'] ?? '');
    UserStore.setWxPendingInfo(null);
    return UserStore.applySessionToken(context, token, 'wechat');
  }

  static async wechatCreateSkipEmail(context: common.UIAbilityContext): Promise<string | null> {
    const pending = UserStore.getWxPendingInfo();
    if (pending.openid.length === 0) {
      return '微信信息缺失，请重新登录';
    }
    const wxBody: Record<string, Object> = {
      'openid': pending.openid,
      'unionid': pending.unionid,
      'nickname': pending.nickname,
      'headimgurl': pending.headimgurl,
      'sex': pending.sex
    };
    const response = await AuthApiService.wechatCreate(wxBody);
    if (response.statusCode !== 200) {
      return response.message ?? '注册失败';
    }
    const token = String(response.data?.['token'] ?? '');
    if (token.length === 0) {
      return '注册失败：未返回 token';
    }
    UserStore.lastLoginUserId = String(response.data?.['user_id'] ?? '');
    UserStore.setWxPendingInfo(null);
    return UserStore.applySessionToken(context, token, 'wechat', true);
  }

  /** 已登录用户绑定邮箱（资料页） */
  static async bindEmailByCode(
    context: common.UIAbilityContext,
    email: string,
    code: string
  ): Promise<string | null> {
    const response = await AuthApiService.bindEmailByCode(email.trim(), code.trim());
    if (response.statusCode !== 200) {
      return response.message ?? '邮箱绑定失败';
    }
    return UserStore.refreshUserInfo(context);
  }

  /** 已登录用户绑定微信 */
  static async bindWechat(context: common.UIAbilityContext): Promise<string | null> {
    const auth = await WeChatOpenService.requestAuthCode(context);
    if (!auth.ok) {
      if (auth.cancelled) {
        return null;
      }
      return auth.message.length > 0 ? auth.message : '微信授权失败';
    }
    const response = await AuthApiService.bindWechatByCode(auth.code);
    if (response.statusCode !== 200) {
      return response.message ?? '微信绑定失败';
    }
    return UserStore.refreshUserInfo(context);
  }

  /** 已登录用户绑定华为账号 */
  static async bindHuawei(context: common.UIAbilityContext): Promise<string | null> {
    const auth = await HuaweiAccountService.requestIdToken(context);
    if (!auth.ok) {
      if (auth.cancelled) {
        return null;
      }
      return auth.message.length > 0 ? auth.message : '华为账号授权失败';
    }
    const response = await AuthApiService.bindHuaweiByCode(
      auth.code,
      auth.idToken,
      auth.nickName.trim(),
      auth.avatarUri.trim()
    );
    if (response.statusCode !== 200) {
      return response.message ?? '华为账号绑定失败';
    }
    return UserStore.refreshUserInfo(context);
  }

  static async registerWithEmail(
    context: common.UIAbilityContext,
    email: string,
    username: string,
    password: string,
    verifyCode: string,
    referralCode: string = ''
  ): Promise<string | null> {
    const trimmedEmail = email.trim();
    const trimmedCode = verifyCode.trim();
    const normalizedReferral = normalizeReferralCode(referralCode);
    const verifyResponse = await ExtendApiService.verifyEmailCode(trimmedEmail, trimmedCode);
    if (verifyResponse.statusCode !== 200) {
      return verifyResponse.message ?? '验证码错误或已过期';
    }

    if (normalizedReferral.length > 0) {
      savePendingReferralCode(normalizedReferral, context);
    }

    const registerResponse = await AuthApiService.registerWithEmail(
      trimmedEmail,
      username.trim(),
      password,
      normalizedReferral
    );
    if (registerResponse.statusCode !== 200) {
      return registerResponse.message ?? '注册失败';
    }

    return UserStore.loginWithEmail(context, trimmedEmail, password, true);
  }

  /** 登录后尝试绑定本地暂存的邀请码 */
  static async flushPendingReferral(context: common.UIAbilityContext): Promise<void> {
    const code = getPendingReferralCode(context);
    if (code.length === 0) {
      return;
    }
    const response = await ReferralApiService.bind(code);
    if (response.statusCode === 200) {
      clearPendingReferralCode(context);
      return;
    }
    const message = String(response.message ?? '');
    if (message.includes('已绑定') || response.statusCode === 400) {
      if (message.includes('已绑定')) {
        clearPendingReferralCode(context);
      }
    }
  }

  static async refreshUserInfo(context: common.UIAbilityContext): Promise<string | null> {
    const response = await AuthApiService.fetchSelfInfo();
    if (response.statusCode === 401) {
      await UserStore.logout(context);
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
    // 新对象引用，保证 @StorageLink 能立刻刷新展示
    syncAppStorageValue(StoreKeys.UserInfo, cloneUserInfo(userInfo));
    syncAppStorageValue(StoreKeys.UserIsLoggedIn, true);
    UmengSdkService.ensureInitialized(context);
    // 通知授权延后到首页 ensureNotifyOnLaunch，避免引导/登录阶段过早弹窗
    UmengSdkService.bindUserAlias(userInfo.id);
    const deviceId = ensureOnboardingDeviceId(context);
    AnalyticsService.identifyUser(userInfo.id, {
      'username': userInfo.username,
      'email': userInfo.email,
      'phone': userInfo.phone,
      'device_id': deviceId
    }, context);
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
    try {
      await BenefitStore.refresh();
    } catch (error) {
      console.warn(`BenefitStore sync skipped: ${String(error)}`);
    }
  }

  /** 用接口返回或请求字段立刻合并本地 UserInfo（对齐 RN，避免等 refresh 才刷新 UI） */
  private static applyUserInfoPatch(
    context: common.UIAbilityContext,
    data: Record<string, Object>,
    responseData?: Record<string, Object>
  ): void {
    const current = UserStore.getUserInfo();
    const fromServer = parseUserInfo(responseData);
    let next: UserInfo;
    if (fromServer !== null) {
      next = fromServer;
    } else {
      next = {
        id: current.id,
        username: data['username'] !== undefined ? String(data['username']) : current.username,
        phone: current.phone,
        email: current.email,
        avatar: data['avatar'] !== undefined ? String(data['avatar']) : current.avatar,
        sex: data['sex'] !== undefined ? Number(data['sex']) : current.sex,
        invite_code: current.invite_code,
        openid: data['openid'] !== undefined ? String(data['openid']) : current.openid,
        huawei_id: data['huawei_id'] !== undefined ? String(data['huawei_id']) : current.huawei_id
      };
    }
    savePersistedUserInfo(context, next);
    // 始终写入新对象引用，确保 @StorageLink 触发重绘
    syncAppStorageValue(StoreKeys.UserInfo, cloneUserInfo(next));
  }

  /** 更新用户资料（用户名 / 性别 / 头像 URL） */
  static async updateUser(
    context: common.UIAbilityContext,
    data: Record<string, Object>
  ): Promise<string | null> {
    const response = await AuthApiService.updateUser(data);
    if (response.statusCode !== 200) {
      return response.message ?? '更新失败';
    }
    UserStore.applyUserInfoPatch(context, data, response.data);
    // 后台再拉一次完整资料；失败不影响已合并的本地展示
    const refreshed = await UserStore.refreshUserInfo(context);
    if (refreshed) {
      console.warn(`UserStore refresh after update skipped: ${refreshed}`);
    }
    return null;
  }

  /** 选图后压缩到缓存再上传（相册临时 URI 不可直接上传） */
  static async uploadAvatar(
    context: common.UIAbilityContext,
    fileUri: string
  ): Promise<string | null> {
    let absolutePath: string;
    try {
      const packed = await compressAvatarForUpload(context, fileUri);
      absolutePath = packed.absolutePath;
    } catch (error) {
      console.warn(`Avatar compress failed: ${String(error)}`);
      return '头像处理失败，请重试';
    }
    return UserStore.uploadPackedAvatar(context, absolutePath);
  }

  /** 已裁剪并压缩到缓存的文件直接上传 */
  static async uploadPackedAvatar(
    context: common.UIAbilityContext,
    absolutePath: string
  ): Promise<string | null> {
    const uploadRes = await AuthApiService.uploadAvatarFile(absolutePath, context);
    if (uploadRes.statusCode !== 200) {
      return uploadRes.message ?? '头像上传失败';
    }
    const url = String(uploadRes.data?.['url'] ?? '');
    if (url.length === 0) {
      return '头像上传失败：未返回地址';
    }
    return UserStore.updateUser(context, { 'avatar': url } as Record<string, Object>);
  }

  static async logout(context: common.UIAbilityContext): Promise<string | null> {
    bootstrapStores();
    const guardResult = await clearAllScheduledGuardOnLogout(context);
    CycleGuardStore.hydrate(context);
    UmengSdkService.clearUserAlias();
    AnalyticsService.trackLogout(context);
    clearDuoWaitContext();
    clearSignupTrialEligible(context);
    clearScheduledGuardSyncFlags(context);
    clearExitPlanIds(context);
    clearUserSession(context);
    BenefitStore.reset();
    InboxStore.reset();
    QuickTaskStore.clearTasks();
    UserStore.setWxPendingInfo(null);
    syncAppStorageValue(StoreKeys.UserAccessToken, '');
    syncAppStorageValue(StoreKeys.UserIsLoggedIn, false);
    syncAppStorageValue(StoreKeys.UserInfo, createEmptyUserInfo());
    refreshStats();
    if (!guardResult.ok) {
      return guardResult.message;
    }
    return null;
  }

  private static async applySessionToken(
    context: common.UIAbilityContext,
    token: string,
    loginMethod?: LoginMethod,
    isNew: boolean = false
  ): Promise<string | null> {
    UserStore.lastLoginIsNew = isNew;
    saveAccessToken(context, token);
    syncAppStorageValue(StoreKeys.UserAccessToken, token);
    syncAppStorageValue(StoreKeys.UserIsLoggedIn, true);
    setSignupTrialEligible(context, isNew);
    markAwaitingScheduledGuardSyncCheck(context);

    const refreshError = await UserStore.refreshUserInfo(context);
    if (refreshError) {
      await UserStore.logout(context);
      return refreshError;
    }
    const userId = UserStore.getUserInfo().id.trim();
    if (userId.length > 0) {
      void OnboardingApiService.bindToUser(context, userId);
    }
    void FocusSyncService.flushPending(context);
    void QuickTaskStore.loadAll();
    void UserStore.syncGuardsOnLogin(context);
    void UserStore.flushPendingReferral(context);
    refreshStats();
    if (loginMethod) {
      const loginFrom = AppStorage.get<string>(StoreKeys.LoginFrom) ?? '';
      const entrySource = loginFrom.length > 0 ? loginFrom : undefined;
      const analyticsExtra: Record<string, Object> = {
        'signup_path': resolveSignupPath(entrySource),
      };
      if (entrySource) {
        analyticsExtra['entry_source'] = entrySource;
      }
      const enriched = buildOnboardingAnalyticsProps(analyticsExtra);
      if (isNew) {
        AnalyticsService.trackRegisterCompleted(loginMethod, context, enriched);
      } else {
        AnalyticsService.trackLoginCompleted(loginMethod, context, enriched);
      }
    }
    return null;
  }

  static async syncGuardsOnLogin(context: common.UIAbilityContext): Promise<void> {
    PlanStore.hydrate(context);
    await loadScheduledListOnLogin(context);
    const planResult = await syncAllPlanGuardStrategies(PlanStore.getPlans());
    if (!planResult.ok) {
      console.warn(`Plan guard sync on login skipped: ${planResult.message}`);
    }
  }
}

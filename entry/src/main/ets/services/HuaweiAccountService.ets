import { authentication } from '@kit.AccountKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

export interface HuaweiAuthResult {
  ok: boolean;
  cancelled: boolean;
  code: string;
  idToken: string;
  nickName: string;
  avatarUri: string;
  message: string;
}

const ERROR_NOT_LOGIN: number = 1001502001;
const ERROR_NETWORK: number = 1001502005;
const ERROR_INTERNAL: number = 1001502009;
const ERROR_USER_CANCEL: number = 1001502012;
const ERROR_DUPLICATE: number = 1001500002;
const ERROR_SYSTEM_SERVICE: number = 12300001;

const EMPTY_AUTH: HuaweiAuthResult = {
  ok: false,
  cancelled: false,
  code: '',
  idToken: '',
  nickName: '',
  avatarUri: '',
  message: ''
};

function makeAuthResult(overrides: Partial<HuaweiAuthResult> = {}): HuaweiAuthResult {
  return {
    ok: overrides.ok ?? EMPTY_AUTH.ok,
    cancelled: overrides.cancelled ?? EMPTY_AUTH.cancelled,
    code: overrides.code ?? EMPTY_AUTH.code,
    idToken: overrides.idToken ?? EMPTY_AUTH.idToken,
    nickName: overrides.nickName ?? EMPTY_AUTH.nickName,
    avatarUri: overrides.avatarUri ?? EMPTY_AUTH.avatarUri,
    message: overrides.message ?? EMPTY_AUTH.message
  };
}

export class HuaweiAccountService {
  /** 授权登录并获取昵称、头像（scope=profile） */
  static async requestIdToken(context: common.UIAbilityContext): Promise<HuaweiAuthResult> {
    const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();
    authRequest.scopes = ['profile'];
    authRequest.permissions = ['serviceauthcode'];
    authRequest.forceAuthorization = true;
    authRequest.state = util.generateRandomUUID();

    try {
      const controller = new authentication.AuthenticationController(context);
      const response = await controller.executeRequest(authRequest);
      const authResponse = response as authentication.AuthorizationWithHuaweiIDResponse;
      const requestState = authRequest.state ?? '';
      const responseState = authResponse.state ?? '';
      if (requestState !== responseState) {
        return makeAuthResult({ message: '华为登录校验失败，请重试' });
      }
      const credential = authResponse.data;
      const code = credential?.authorizationCode ?? '';
      const idToken = credential?.idToken ?? '';
      if (code.length === 0 && idToken.length === 0) {
        return makeAuthResult({ message: '华为授权失败，请重试' });
      }
      return makeAuthResult({
        ok: true,
        code: code,
        idToken: idToken,
        nickName: credential?.nickName ?? '',
        avatarUri: credential?.avatarUri ?? ''
      });
    } catch (error) {
      return HuaweiAccountService.mapError(error);
    }
  }

  private static mapError(error: Object): HuaweiAuthResult {
    const biz = error as BusinessError;
    const code = Number(biz.code ?? 0);
    if (code === ERROR_USER_CANCEL || code === ERROR_DUPLICATE) {
      return makeAuthResult({ cancelled: true });
    }
    let message = '华为账号登录失败';
    if (code === ERROR_NOT_LOGIN) {
      message = '请先登录华为账号后再试';
    } else if (code === ERROR_NETWORK) {
      message = '网络异常，请检查后重试';
    } else if (code === ERROR_INTERNAL || code === ERROR_SYSTEM_SERVICE) {
      message = '华为账号服务异常，请稍后重试';
    }
    return makeAuthResult({ message: message });
  }
}

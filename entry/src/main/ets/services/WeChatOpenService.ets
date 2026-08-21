import { common, Want } from '@kit.AbilityKit';
import {
  BaseReq,
  BaseResp,
  ErrCode,
  PayReq,
  PayResp,
  SendAuthReq,
  SendAuthResp,
  WXApi,
  WXApiEventHandler,
  WXAPIFactory
} from '@tencent/wechat_open_sdk';
import { WECHAT_APP_ID } from '../config/WeChatConfig';

type OnWXResp = (resp: BaseResp) => void;
type OnWXReq = (req: BaseReq) => void;

class WXApiEventHandlerImpl implements WXApiEventHandler {
  private onReqCallbacks: Map<OnWXReq, OnWXReq> = new Map();
  private onRespCallbacks: Map<OnWXResp, OnWXResp> = new Map();

  registerOnWXReqCallback(on: OnWXReq): void {
    this.onReqCallbacks.set(on, on);
  }

  unregisterOnWXReqCallback(on: OnWXReq): void {
    this.onReqCallbacks.delete(on);
  }

  registerOnWXRespCallback(on: OnWXResp): void {
    this.onRespCallbacks.set(on, on);
  }

  unregisterOnWXRespCallback(on: OnWXResp): void {
    this.onRespCallbacks.delete(on);
  }

  onReq(req: BaseReq): void {
    this.onReqCallbacks.forEach((callback: OnWXReq) => {
      callback(req);
    });
  }

  onResp(resp: BaseResp): void {
    this.onRespCallbacks.forEach((callback: OnWXResp) => {
      callback(resp);
    });
  }
}

export interface WeChatAuthResult {
  ok: boolean;
  code: string;
  message: string;
  cancelled: boolean;
}

export interface WeChatPayResult {
  ok: boolean;
  message: string;
  cancelled: boolean;
}

export interface WeChatPayParams {
  partnerId: string;
  prepayId: string;
  nonceStr: string;
  timeStamp: string;
  sign: string;
}

/**
 * 微信 OpenSDK 封装：授权登录 / APP 支付 / 回跳处理。
 * 需在微信开放平台为该移动应用配置鸿蒙 Bundle ID + Identifier 并审核通过。
 */
export class WeChatOpenService {
  private static api: WXApi | null = null;
  private static readonly eventHandler: WXApiEventHandlerImpl = new WXApiEventHandlerImpl();
  private static pendingAuthResolve: ((result: WeChatAuthResult) => void) | null = null;
  private static pendingPayResolve: ((result: WeChatPayResult) => void) | null = null;

  static getApi(): WXApi {
    if (WeChatOpenService.api === null) {
      WeChatOpenService.api = WXAPIFactory.createWXAPI(WECHAT_APP_ID);
      WeChatOpenService.eventHandler.registerOnWXRespCallback((resp: BaseResp) => {
        WeChatOpenService.dispatchResp(resp);
      });
    }
    return WeChatOpenService.api;
  }

  static handleWant(want: Want): boolean {
    return WeChatOpenService.getApi().handleWant(want, WeChatOpenService.eventHandler);
  }

  static isInstalled(): boolean {
    try {
      return WeChatOpenService.getApi().isWXAppInstalled();
    } catch (error) {
      console.warn(`WeChat isWXAppInstalled failed: ${String(error)}`);
      return false;
    }
  }

  private static dispatchResp(resp: BaseResp): void {
    if (resp instanceof SendAuthResp) {
      WeChatOpenService.handleAuthResp(resp);
      return;
    }
    if (resp instanceof PayResp) {
      WeChatOpenService.handlePayResp(resp);
    }
  }

  private static handleAuthResp(resp: SendAuthResp): void {
    const resolve = WeChatOpenService.pendingAuthResolve;
    if (!resolve) {
      return;
    }
    WeChatOpenService.pendingAuthResolve = null;

    if (resp.errCode === ErrCode.ERR_OK) {
      const code = String(resp.code ?? '').trim();
      if (code.length === 0) {
        resolve({
          ok: false,
          code: '',
          message: '微信授权码为空',
          cancelled: false
        });
        return;
      }
      resolve({
        ok: true,
        code: code,
        message: '',
        cancelled: false
      });
      return;
    }

    if (resp.errCode === ErrCode.ERR_USER_CANCEL) {
      resolve({
        ok: false,
        code: '',
        message: '已取消微信授权',
        cancelled: true
      });
      return;
    }

    resolve({
      ok: false,
      code: '',
      message: resp.errStr ?? `微信授权失败(${resp.errCode})`,
      cancelled: false
    });
  }

  private static handlePayResp(resp: PayResp): void {
    const resolve = WeChatOpenService.pendingPayResolve;
    if (!resolve) {
      return;
    }
    WeChatOpenService.pendingPayResolve = null;

    if (resp.errCode === ErrCode.ERR_OK) {
      resolve({
        ok: true,
        message: '',
        cancelled: false
      });
      return;
    }

    if (resp.errCode === ErrCode.ERR_USER_CANCEL) {
      resolve({
        ok: false,
        message: '已取消支付',
        cancelled: true
      });
      return;
    }

    resolve({
      ok: false,
      message: resp.errStr ?? `支付失败(${resp.errCode})`,
      cancelled: false
    });
  }

  /** 拉起微信授权，返回 code */
  static async requestAuthCode(context: common.UIAbilityContext): Promise<WeChatAuthResult> {
    if (!WeChatOpenService.isInstalled()) {
      return {
        ok: false,
        code: '',
        message: '请先安装微信',
        cancelled: false
      };
    }

    if (WeChatOpenService.pendingAuthResolve) {
      WeChatOpenService.pendingAuthResolve({
        ok: false,
        code: '',
        message: '已有进行中的微信授权',
        cancelled: true
      });
      WeChatOpenService.pendingAuthResolve = null;
    }

    const req = new SendAuthReq();
    req.scope = 'snsapi_userinfo';
    req.state = `focusvow_${Date.now()}`;
    req.isOption1 = false;
    req.nonAutomatic = true;
    req.transaction = `auth_${Date.now()}`;
    req.callbackAbility = 'EntryAbility';

    return new Promise<WeChatAuthResult>(async (resolve: (r: WeChatAuthResult) => void) => {
      WeChatOpenService.pendingAuthResolve = resolve;
      try {
        const finishedWrap = WeChatOpenService.getApi().sendReq(context, req);
        const finished = await Promise.resolve(finishedWrap);
        if (!finished) {
          WeChatOpenService.pendingAuthResolve = null;
          resolve({
            ok: false,
            code: '',
            message: '无法打开微信，请确认已安装',
            cancelled: false
          });
        }
      } catch (error) {
        WeChatOpenService.pendingAuthResolve = null;
        resolve({
          ok: false,
          code: '',
          message: `拉起微信失败：${String(error)}`,
          cancelled: false
        });
      }
    });
  }

  /** 拉起微信 APP 支付（参数来自 /payment/wechat-subscription-app） */
  static async requestPayment(
    context: common.UIAbilityContext,
    params: WeChatPayParams
  ): Promise<WeChatPayResult> {
    if (!WeChatOpenService.isInstalled()) {
      return {
        ok: false,
        message: '请先安装微信',
        cancelled: false
      };
    }

    if (WeChatOpenService.pendingPayResolve) {
      WeChatOpenService.pendingPayResolve({
        ok: false,
        message: '已有进行中的微信支付',
        cancelled: true
      });
      WeChatOpenService.pendingPayResolve = null;
    }

    const req = new PayReq();
    req.appId = WECHAT_APP_ID;
    req.partnerId = params.partnerId;
    req.prepayId = params.prepayId;
    req.nonceStr = params.nonceStr;
    req.timeStamp = params.timeStamp;
    req.packageValue = 'Sign=WXPay';
    req.sign = params.sign;
    req.transaction = `pay_${Date.now()}`;
    req.callbackAbility = 'EntryAbility';

    return new Promise<WeChatPayResult>(async (resolve: (r: WeChatPayResult) => void) => {
      WeChatOpenService.pendingPayResolve = resolve;
      try {
        const finishedWrap = WeChatOpenService.getApi().sendReq(context, req);
        const finished = await Promise.resolve(finishedWrap);
        if (!finished) {
          WeChatOpenService.pendingPayResolve = null;
          resolve({
            ok: false,
            message: '无法打开微信，请确认已安装',
            cancelled: false
          });
        }
      } catch (error) {
        WeChatOpenService.pendingPayResolve = null;
        resolve({
          ok: false,
          message: `拉起微信支付失败：${String(error)}`,
          cancelled: false
        });
      }
    });
  }
}

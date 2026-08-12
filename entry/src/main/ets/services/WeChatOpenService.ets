import { common, Want } from '@kit.AbilityKit';
import {
  BaseReq,
  BaseResp,
  ErrCode,
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

/**
 * 微信 OpenSDK 封装：授权登录 / 回跳处理。
 * 需在微信开放平台为该移动应用配置鸿蒙 Bundle ID + Identifier 并审核通过。
 */
export class WeChatOpenService {
  private static api: WXApi | null = null;
  private static readonly eventHandler: WXApiEventHandlerImpl = new WXApiEventHandlerImpl();
  private static pendingResolve: ((result: WeChatAuthResult) => void) | null = null;

  static getApi(): WXApi {
    if (WeChatOpenService.api === null) {
      WeChatOpenService.api = WXAPIFactory.createWXAPI(WECHAT_APP_ID);
      WeChatOpenService.eventHandler.registerOnWXRespCallback((resp: BaseResp) => {
        WeChatOpenService.handleAuthResp(resp);
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

  private static handleAuthResp(resp: BaseResp): void {
    const resolve = WeChatOpenService.pendingResolve;
    if (!resolve) {
      return;
    }
    WeChatOpenService.pendingResolve = null;

    if (!(resp instanceof SendAuthResp)) {
      resolve({
        ok: false,
        code: '',
        message: '未收到微信授权结果',
        cancelled: false
      });
      return;
    }

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

    if (WeChatOpenService.pendingResolve) {
      WeChatOpenService.pendingResolve({
        ok: false,
        code: '',
        message: '已有进行中的微信授权',
        cancelled: true
      });
      WeChatOpenService.pendingResolve = null;
    }

    const req = new SendAuthReq();
    req.scope = 'snsapi_userinfo';
    req.state = `focusvow_${Date.now()}`;
    req.isOption1 = false;
    req.nonAutomatic = true;
    req.transaction = `auth_${Date.now()}`;
    req.callbackAbility = 'EntryAbility';

    return new Promise<WeChatAuthResult>(async (resolve: (r: WeChatAuthResult) => void) => {
      WeChatOpenService.pendingResolve = resolve;
      try {
        const finishedWrap = WeChatOpenService.getApi().sendReq(context, req);
        const finished = await Promise.resolve(finishedWrap);
        if (!finished) {
          WeChatOpenService.pendingResolve = null;
          resolve({
            ok: false,
            code: '',
            message: '无法打开微信，请确认已安装',
            cancelled: false
          });
        }
      } catch (error) {
        WeChatOpenService.pendingResolve = null;
        resolve({
          ok: false,
          code: '',
          message: `拉起微信失败：${String(error)}`,
          cancelled: false
        });
      }
    });
  }
}

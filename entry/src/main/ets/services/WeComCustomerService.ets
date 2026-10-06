import { common, Want } from '@kit.AbilityKit';
import { WECOM_CUSTOMER_SERVICE_URL } from '../config/WeComConfig';
import { WeChatOpenService } from './WeChatOpenService';

const SCENE_PARAM_MAX_LEN: number = 128;

function buildCustomerServiceUrl(entrySource: string): string {
  const raw = entrySource.trim();
  if (raw.length === 0 || raw.length > SCENE_PARAM_MAX_LEN) {
    return WECOM_CUSTOMER_SERVICE_URL;
  }
  const separator = WECOM_CUSTOMER_SERVICE_URL.indexOf('?') >= 0 ? '&' : '?';
  return `${WECOM_CUSTOMER_SERVICE_URL}${separator}scene_param=${encodeURIComponent(raw)}`;
}

const buildKefuScheme = (url: string): string => {
  const target = url.includes('?') ? `${url}&schema=1` : `${url}?schema=1`;
  return `weixin://biz/ww/kefu/${target}`;
};

export function isWecomCustomerServiceLink(url: string): boolean {
  const value = url.trim();
  if (value.length === 0) {
    return false;
  }
  if (value.indexOf('work.weixin.qq.com/kfid/') >= 0) {
    return true;
  }
  const base = WECOM_CUSTOMER_SERVICE_URL.split('?')[0];
  return base.length > 0 && value.indexOf(base) === 0;
}

export class WeComCustomerService {
  static async open(
    context: common.UIAbilityContext,
    entrySource: string = '',
  ): Promise<string | null> {
    if (!WeChatOpenService.isInstalled()) {
      return '请先安装微信';
    }

    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: buildKefuScheme(buildCustomerServiceUrl(entrySource)),
    };

    try {
      await context.startAbility(want);
      return null;
    } catch (error) {
      return `无法打开微信客服：${String(error)}`;
    }
  }
}

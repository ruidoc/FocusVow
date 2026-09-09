import { common, Want } from '@kit.AbilityKit';
import { WECOM_CUSTOMER_SERVICE_URL } from '../config/WeComConfig';
import { WeChatOpenService } from './WeChatOpenService';

const buildKefuScheme = (url: string): string => {
  const target = url.includes('?') ? `${url}&schema=1` : `${url}?schema=1`;
  return `weixin://biz/ww/kefu/${target}`;
};

export class WeComCustomerService {
  static async open(context: common.UIAbilityContext): Promise<string | null> {
    if (!WeChatOpenService.isInstalled()) {
      return '请先安装微信';
    }

    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: buildKefuScheme(WECOM_CUSTOMER_SERVICE_URL),
    };

    try {
      await context.startAbility(want);
      return null;
    } catch (error) {
      return `无法打开微信客服：${String(error)}`;
    }
  }
}

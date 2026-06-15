/**
 * 友盟 Push 后台「应用信息」中的 Umeng Message Secret。
 * 需与包名 com.freeshore.focusvow 对应。
 *
 * 华为离线推送：Client ID 配置在 entry/src/main/module.json5 → module.metadata.client_id。
 */
export class UmengConfig {
  static readonly APP_MESSAGE_SECRET: string = '84665d4f61a7afabc478997556404c44';
  static readonly PUSH_ALIAS_TYPE: string = 'focusvow';
}

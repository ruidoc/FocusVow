export class ApiConfig {
  /** 与 FocusExpo 开发环境一致，发布前可改为生产地址 */
  // static readonly BASE_URL: string = 'https://focus.freeshore.cn/dev-api';
  static readonly BASE_URL: string = 'http://192.168.0.104:8849';
  static readonly PROJECT_TAG: string = 'focusvow';
  static readonly OS_TAG: string = 'harmony';
  static readonly CONNECT_TIMEOUT_MS: number = 12000;
  static readonly READ_TIMEOUT_MS: number = 20000;
}

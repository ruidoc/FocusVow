import BuildProfile from 'BuildProfile';

export class ApiConfig {
  /** 由 build-profile buildProfileFields 按 debug/release 注入 */
  static readonly BASE_URL: string = BuildProfile.API_BASE_URL;
  static readonly PROJECT_TAG: string = 'focusone';
  static readonly OS_TAG: string = 'harmony';
  static readonly CONNECT_TIMEOUT_MS: number = 12000;
  static readonly READ_TIMEOUT_MS: number = 20000;

  /** debug 包指向 dev-api；release 为 /api */
  static isDevEnvironment(): boolean {
    return ApiConfig.BASE_URL.includes('/dev-api');
  }
}

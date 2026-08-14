import { ApiConfig } from './ApiConfig';

/** 与 RN 共用同一 Project API Key，经后端 /i 代理上报 */
export class PostHogConfig {
  static readonly API_KEY: string = 'phc_A4Pt2WQHEQLedNR9wyLMxSHrpdnOdUTCiR8LHNGT5QG';
  static readonly HOST: string = `${ApiConfig.BASE_URL}/i`;
}

import { emptyShareClientConfig, ShareClientConfig } from '../models/ShareConfigModel';
import { parseShareConfigFromResponse } from '../utils/ShareConfigUtil';
import { HttpService } from './HttpService';

export class ShareConfigService {
  private static cached: ShareClientConfig | null = null;
  private static loading: Promise<ShareClientConfig> | null = null;

  static invalidate(): void {
    ShareConfigService.cached = null;
    ShareConfigService.loading = null;
  }

  static async fetchFresh(): Promise<ShareClientConfig> {
    try {
      const response = await HttpService.get('/share-cards/config', true);
      if (response.statusCode !== 200) {
        return emptyShareClientConfig();
      }
      return parseShareConfigFromResponse(response.data);
    } catch (_e) {
      return emptyShareClientConfig();
    }
  }

  static async load(): Promise<ShareClientConfig> {
    if (ShareConfigService.cached) {
      return ShareConfigService.cached;
    }
    if (ShareConfigService.loading) {
      return ShareConfigService.loading;
    }
    ShareConfigService.loading = ShareConfigService.fetchFresh().then((config: ShareClientConfig) => {
      ShareConfigService.cached = config;
      ShareConfigService.loading = null;
      return config;
    }).catch(() => {
      ShareConfigService.loading = null;
      return emptyShareClientConfig();
    });
    return ShareConfigService.loading;
  }
}

import { ContractProfile, parseContractProfile, parsePointLogPage, PointLogPage } from '../models/PointModel';
import { HttpService } from './HttpService';

export class PointApiService {
  static async getProfile(userId: string): Promise<ContractProfile | null> {
    const path = `/point/profile/${encodeURIComponent(userId)}`;
    const response = await HttpService.get(path, true);
    if (response.statusCode !== 200) {
      return null;
    }
    return parseContractProfile(response.data);
  }

  static async getLogs(page: number): Promise<PointLogPage> {
    const query: Record<string, string> = {};
    query['page'] = String(Math.max(1, page));
    const response = await HttpService.getWithQuery('/point/logs', query, true);
    if (response.statusCode !== 200) {
      return parsePointLogPage(undefined);
    }
    return parsePointLogPage(response.data);
  }
}

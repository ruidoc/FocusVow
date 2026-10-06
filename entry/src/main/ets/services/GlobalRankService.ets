import {
  GlobalRankData,
  GlobalRankMode,
  GlobalRankPeriod,
  parseGlobalRank,
} from '../models/GlobalRankModel';
import { HttpService } from './HttpService';

export class GlobalRankService {
  static async fetch(period: GlobalRankPeriod, mode: GlobalRankMode): Promise<GlobalRankData | null> {
    const query: Record<string, string> = {
      'period': period,
      'mode': mode,
    };
    const response = await HttpService.getWithQuery('/record/rank', query);
    if (response.statusCode !== 200) {
      return null;
    }
    return parseGlobalRank(response.data, period, mode);
  }
}

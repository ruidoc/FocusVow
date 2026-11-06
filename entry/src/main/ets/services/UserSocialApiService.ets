import {
  FollowGraphTab,
  FollowRelation,
  FollowRow,
  parseFollowList,
  parseFollowRelation,
} from '../models/UserSocialModel';
import { HttpService } from './HttpService';

export interface MutualFriendRow {
  id: string;
  username: string;
  avatar: string;
}

function parseMutualFriends(raw: Object | undefined): MutualFriendRow[] {
  if (!raw || typeof raw !== 'object') {
    return [];
  }
  const data = raw as Record<string, Object>;
  const list = data['list'];
  if (!Array.isArray(list)) {
    return [];
  }
  const out: MutualFriendRow[] = [];
  for (let i = 0; i < list.length; i++) {
    const row = list[i] as Record<string, Object>;
    const id = String(row['id'] ?? '').trim();
    if (id.length === 0) {
      continue;
    }
    const item: MutualFriendRow = {
      id: id,
      username: String(row['username'] ?? '').trim(),
      avatar: String(row['avatar'] ?? '').trim(),
    };
    out.push(item);
  }
  return out;
}

export class UserSocialApiService {
  static async getMutualFriends(): Promise<MutualFriendRow[]> {
    const response = await HttpService.get('/user/mutual-friends', true);
    if (response.statusCode !== 200) {
      return [];
    }
    return parseMutualFriends(response.data);
  }

  static async getFollowGraph(userId: string, kind: FollowGraphTab): Promise<FollowRow[]> {
    const query: Record<string, string> = {};
    query['user_id'] = userId;
    query['kind'] = kind;
    const response = await HttpService.getWithQuery('/user/follow-graph', query, true);
    if (response.statusCode !== 200) {
      return [];
    }
    return parseFollowList(response.data);
  }

  static async follow(targetId: string): Promise<FollowRelation | null> {
    const path = `/user/follow/${encodeURIComponent(targetId)}`;
    const response = await HttpService.post(path, {}, true);
    if (response.statusCode !== 200) {
      return null;
    }
    return parseFollowRelation(response.data);
  }

  static async unfollow(targetId: string): Promise<FollowRelation | null> {
    const path = `/user/follow/${encodeURIComponent(targetId)}`;
    const response = await HttpService.delete(path, true);
    if (response.statusCode !== 200) {
      return null;
    }
    return parseFollowRelation(response.data);
  }
}

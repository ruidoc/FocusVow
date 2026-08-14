export interface UserInfo {
  id: string;
  username: string;
  phone: string;
  email: string;
  avatar: string;
  sex: number;
  invite_code: string;
  openid: string;
  huawei_id: string;
}

/** 微信授权后待绑定的用户资料（statusCode 20003） */
export interface WxPendingInfo {
  openid: string;
  unionid: string;
  nickname: string;
  headimgurl: string;
  sex: number;
}

export interface ApiEnvelope {
  statusCode: number;
  message?: string;
  data?: Record<string, Object>;
}

export function createEmptyUserInfo(): UserInfo {
  return {
    id: '',
    username: '',
    phone: '',
    email: '',
    avatar: '',
    sex: 0,
    invite_code: '',
    openid: '',
    huawei_id: ''
  };
}

export function createEmptyWxPendingInfo(): WxPendingInfo {
  return {
    openid: '',
    unionid: '',
    nickname: '',
    headimgurl: '',
    sex: 0
  };
}

export function parseWxPendingInfo(raw: Record<string, Object> | undefined): WxPendingInfo | null {
  if (!raw) {
    return null;
  }
  const openid = String(raw['openid'] ?? '').trim();
  if (openid.length === 0) {
    return null;
  }
  return {
    openid: openid,
    unionid: String(raw['unionid'] ?? ''),
    nickname: String(raw['nickname'] ?? raw['username'] ?? ''),
    headimgurl: String(raw['headimgurl'] ?? raw['avatar'] ?? ''),
    sex: Number(raw['sex'] ?? 0)
  };
}

export function parseUserInfo(raw: Record<string, Object> | undefined): UserInfo | null {
  if (!raw) {
    return null;
  }

  const id = String(raw['id'] ?? '');
  if (id.length === 0) {
    return null;
  }

  return {
    id,
    username: String(raw['username'] ?? ''),
    phone: String(raw['phone'] ?? ''),
    email: String(raw['email'] ?? ''),
    avatar: String(raw['avatar'] ?? ''),
    sex: Number(raw['sex'] ?? 0),
    invite_code: String(raw['invite_code'] ?? ''),
    openid: String(raw['openid'] ?? ''),
    huawei_id: String(raw['huawei_id'] ?? '')
  };
}

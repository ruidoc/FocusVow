export interface UserInfo {
  id: string;
  username: string;
  phone: string;
  email: string;
  avatar: string;
  sex: number;
  invite_code: string;
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
    invite_code: ''
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
    invite_code: String(raw['invite_code'] ?? '')
  };
}

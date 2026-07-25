export type MembershipStatus = 'none' | 'pending' | 'active';

export interface BenefitState {
  dayDuration: number;
  /** 今日总专注（兼容） */
  todayUsed: number;
  /** 今日互督已用（额度进度条，暂不做限制） */
  duoTodayUsed: number;
  isSubscribed: boolean;
  membershipStatus: MembershipStatus;
  communityQrUrl: string;
  communityHint: string;
  features: string;
}

export function createEmptyBenefitState(): BenefitState {
  return {
    dayDuration: 0,
    todayUsed: 0,
    duoTodayUsed: 0,
    isSubscribed: false,
    membershipStatus: 'none',
    communityQrUrl: '',
    communityHint: '',
    features: ''
  };
}

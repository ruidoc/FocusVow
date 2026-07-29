export type MembershipStatus = 'none' | 'pending' | 'active';

export interface BenefitState {
  dayDuration: number;
  /** 今日总专注时长 */
  todayUsed: number;
  /** 今日互督已用（字段保留） */
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

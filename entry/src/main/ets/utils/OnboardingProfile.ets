export type OnboardingIdentity =
  | 'junior_high'
  | 'high_school'
  | 'college'
  | 'graduated'
  | 'other';

export type OnboardingGoal =
  | 'zhongkao'
  | 'gaokao'
  | 'kaoyan'
  | 'kaogong'
  | 'daily_study'
  | 'quit_phone'
  | 'work_focus'
  | 'other';

export interface OnboardingOption {
  id: string;
  title: string;
  desc: string;
}

export const IDENTITY_OPTIONS: OnboardingOption[] = [
  { id: 'junior_high', title: '初中生', desc: '日常学习或备考' },
  { id: 'high_school', title: '高中生', desc: '备战高考或日常学习' },
  { id: 'college', title: '大学生', desc: '考研、考公或提升专注' },
  { id: 'graduated', title: '已毕业', desc: '工作专注或继续备考' },
  { id: 'other', title: '其他', desc: '先选一个接近的就行' }
];

export function getGoalsForIdentity(identity: string): OnboardingOption[] {
  if (identity === 'junior_high') {
    return [
      { id: 'zhongkao', title: '中考', desc: '稳住复习节奏' },
      { id: 'daily_study', title: '日常学习', desc: '写作业、背书时不被打断' },
      { id: 'quit_phone', title: '戒手机', desc: '减少刷短视频和无效滑动' },
      { id: 'other', title: '其他', desc: '先体验强制专注' }
    ];
  }
  if (identity === 'high_school') {
    return [
      { id: 'gaokao', title: '高考', desc: '锁住分心，稳住复习节奏' },
      { id: 'daily_study', title: '日常学习', desc: '写作业、背书时不被打断' },
      { id: 'quit_phone', title: '戒手机', desc: '减少刷短视频和无效滑动' },
      { id: 'other', title: '其他', desc: '先体验强制专注' }
    ];
  }
  if (identity === 'college') {
    return [
      { id: 'kaoyan', title: '考研', desc: '长周期备考，需要硬约束' },
      { id: 'kaogong', title: '考公', desc: '刷题阶段减少手机干扰' },
      { id: 'daily_study', title: '日常学习', desc: '课程、论文、技能提升' },
      { id: 'quit_phone', title: '戒手机', desc: '从高频分心 App 开始' },
      { id: 'other', title: '其他', desc: '先体验强制专注' }
    ];
  }
  if (identity === 'graduated') {
    return [
      { id: 'kaogong', title: '考公', desc: '下班后也要守住专注块' },
      { id: 'kaoyan', title: '考研', desc: '在职备考需要更强约束' },
      { id: 'work_focus', title: '工作专注', desc: '深度工作不被手机带走' },
      { id: 'quit_phone', title: '戒手机', desc: '减少碎片化刷机' },
      { id: 'other', title: '其他', desc: '先体验强制专注' }
    ];
  }
  return [
    { id: 'daily_study', title: '日常学习', desc: '需要一段不被打断的时间' },
    { id: 'quit_phone', title: '戒手机', desc: '先锁住最分心的应用' },
    { id: 'work_focus', title: '工作专注', desc: '进入心流状态' },
    { id: 'other', title: '其他', desc: '先体验强制专注' }
  ];
}

export function goalToProblem(goal: string): string {
  if (goal === 'quit_phone') {
    return 'video';
  }
  if (
    goal === 'zhongkao' ||
    goal === 'gaokao' ||
    goal === 'kaoyan' ||
    goal === 'kaogong' ||
    goal === 'daily_study'
  ) {
    return 'study';
  }
  return 'other';
}

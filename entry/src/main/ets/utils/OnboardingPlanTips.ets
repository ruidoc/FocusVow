export type PlanTipId = 'duo' | 'schedule' | 'limit';
export type PlanTipTheme = 'study' | 'screen' | 'work' | 'default';

export interface PlanTipContent {
  id: PlanTipId;
  title: string;
  body: string;
}

const PLAN_TIP_ORDER: PlanTipId[] = ['duo', 'schedule', 'limit'];

export function resolvePlanTipTheme(identity: string, goal: string): PlanTipTheme {
  if (goal === 'child_phone' || goal === 'quit_phone') {
    return 'screen';
  }
  if (goal === 'work_focus') {
    return 'work';
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
  if (identity === 'parent') {
    return 'screen';
  }
  if (identity === 'employed' || identity === 'freelance') {
    return 'work';
  }
  if (identity === 'secondary' || identity === 'college') {
    return 'study';
  }
  return 'default';
}

function duoBody(theme: PlanTipTheme): string {
  if (theme === 'study') {
    return '拉同学或备考搭子一起锁机，一人毁约双方失败，更容易坚持到上岸。';
  }
  if (theme === 'screen') {
    return '和朋友互相监督戒手机，偷玩会被搭子知道，自律不再靠一个人硬扛。';
  }
  if (theme === 'work') {
    return '和同事约定专注时段互督，摸鱼成本更高，深度工作更容易进入状态。';
  }
  return '找搭子一起锁机互督，有人陪着更容易把专注坚持下去。';
}

function scheduleBody(theme: PlanTipTheme): string {
  if (theme === 'study') {
    return '把复习时段设成定时锁机，到点自动执行，不用每天靠意志力启动。';
  }
  if (theme === 'screen') {
    return '睡前、起床或碎片时间设自动锁机，减少无意识刷手机的习惯。';
  }
  if (theme === 'work') {
    return '工作日上午/下午设固定锁机时段，给深度工作留出不被打扰的时间块。';
  }
  return '常用时段设成定时锁机，到点执行，专注变成固定节奏。';
}

function limitBody(theme: PlanTipTheme): string {
  if (theme === 'study') {
    return '给短视频、游戏设每日限额，学习时间不被娱乐 App 打断。';
  }
  if (theme === 'screen') {
    return '娱乐 App 每日限时，超了自动锁死，从根上控制刷手机时长。';
  }
  if (theme === 'work') {
    return '午休娱乐设限额，下午不再陷入短视频，工作状态更好切换回来。';
  }
  return '给容易分心的 App 设每日限额，超时就锁，帮你守住专注时间。';
}

export function getPlanTips(identity: string, goal: string): PlanTipContent[] {
  const theme = resolvePlanTipTheme(identity, goal);
  const tips: PlanTipContent[] = [];
  for (let i = 0; i < PLAN_TIP_ORDER.length; i++) {
    const id = PLAN_TIP_ORDER[i];
    if (id === 'duo') {
      tips.push({ id, title: '搭子互督', body: duoBody(theme) });
    } else if (id === 'schedule') {
      tips.push({ id, title: '定时锁机', body: scheduleBody(theme) });
    } else {
      tips.push({ id, title: '短视频限额', body: limitBody(theme) });
    }
  }
  return tips;
}

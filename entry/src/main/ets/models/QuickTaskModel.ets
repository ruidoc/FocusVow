import { TimerMode } from '../utils/TimerMode';

export interface QuickTask {
  id: string;
  title: string;
  duration_min: number;
  timer_mode: TimerMode;
  mode: 'shield' | 'allow';
  delay_min: number;
  no_stop: boolean;
  apps: string[];
}

export interface QuickTaskUpsertPayload {
  title: string;
  duration_min: number;
  timer_mode: TimerMode;
  mode: 'shield' | 'allow';
  delay_min: number;
  no_stop: boolean;
  apps: string[];
}

export function parseQuickTask(raw: Record<string, Object> | null | undefined): QuickTask | null {
  if (!raw || raw['id'] === undefined || raw['id'] === null) {
    return null;
  }
  const timerMode = String(raw['timer_mode'] ?? '') === 'countup' ? 'countup' : 'countdown';
  const mode = String(raw['mode'] ?? '') === 'shield' ? 'shield' : 'allow';
  const appsRaw = raw['apps'];
  const apps: string[] = [];
  if (appsRaw instanceof Array) {
    appsRaw.forEach((item: Object) => {
      const ref = String(item ?? '').trim();
      if (ref.length > 0) {
        apps.push(ref);
      }
    });
  }
  const noStopRaw = raw['no_stop'];
  const noStop =
    noStopRaw === true ||
    noStopRaw === 1 ||
    String(noStopRaw) === '1';
  return {
    id: String(raw['id']),
    title: String(raw['title'] ?? ''),
    duration_min: Math.max(5, Number(raw['duration_min']) || 25),
    timer_mode: timerMode,
    mode: mode,
    delay_min: Number(raw['delay_min']) || 0,
    no_stop: noStop,
    apps: apps
  };
}

export function getStartDelayLabel(minutes: number): string {
  if (minutes <= 0) {
    return '立即';
  }
  if (minutes === 60) {
    return '1 小时后';
  }
  return `${minutes} 分钟后`;
}

export function startWhenLabel(minutes: number): string {
  if (minutes <= 0) {
    return '立即开始';
  }
  return `${getStartDelayLabel(minutes)}开始`;
}

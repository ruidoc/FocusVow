export interface ScheduledScenePreset {
  id: string;
  name: string;
  description: string;
  background: Resource;
  startTime: string;
  endTime: string;
  repeat: number[];
}

export const SCHEDULED_SCENE_PRESETS: ScheduledScenePreset[] = [
  {
    id: 'morning_reading',
    name: '晨读',
    description: '清晨专注，开启高效一天',
    background: $r('app.media.scene_sleep'),
    startTime: '06:30',
    endTime: '08:00',
    repeat: [1, 2, 3, 4, 5, 6, 7],
  },
  {
    id: 'study',
    name: '写作业',
    description: '晚间专注，阻断娱乐干扰',
    background: $r('app.media.scene_study'),
    startTime: '19:30',
    endTime: '22:00',
    repeat: [1, 2, 3, 4, 5, 6, 7],
  },
  {
    id: 'breath',
    name: '学习充电',
    description: '放下手机，专注学习充电',
    background: $r('app.media.scene_breath'),
    startTime: '16:00',
    endTime: '17:00',
    repeat: [1, 2, 3, 4, 5],
  },
];

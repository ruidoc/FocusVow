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
    id: 'early_sleep',
    name: '早睡',
    description: '睡前锁定，杜绝熬夜刷手机',
    background: $r('app.media.scene_sleep'),
    startTime: '22:30',
    endTime: '5:00',
    repeat: [1, 2, 3, 4, 5, 6, 7],
  },
  {
    id: 'study',
    name: '学习',
    description: '晚间专注，阻断娱乐干扰',
    background: $r('app.media.scene_study'),
    startTime: '19:30',
    endTime: '22:00',
    repeat: [1, 2, 3, 4, 5, 6, 7],
  },
  {
    id: 'breath',
    name: '透透气',
    description: '刷手机太久，出门透透气',
    background: $r('app.media.scene_breath'),
    startTime: '16:00',
    endTime: '17:00',
    repeat: [1, 2, 3, 4, 5],
  },
];

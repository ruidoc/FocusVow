import { common } from '@kit.AbilityKit';
import {
  DuoSessionView,
  getScheduleRepeatDays,
  getScheduledListStatusLabel,
  getScheduledSessionEndMin,
  getScheduledSessionStartMin,
  isInactiveScheduledListSession,
} from '../../models/DuoModel';
import { summarizeRepeatDays } from '../../models/PlanModel';
import { minutesToHours } from '../../models/ActiveLockModel';
import { AppTheme } from '../../constants/Theme';
import { loadExitPlanIds } from '../../services/ExitPlanIdsService';

interface ScheduledStatusTagStyle {
  textColor: string;
  backgroundColor: string;
}

@Component
export struct ScheduledSessionCard {
  @Prop session: DuoSessionView = {
    session_id: '',
    token: '',
    type: 'scheduled',
    status: 'scheduled',
    title: '',
    duration_min: 0,
    timer_mode: 'countdown',
    mode: 'allow',
    participation_mode: 'solo'
  };
  onPress?: () => void;
  @State private statusTick: number = 0;
  private timerId: number = -1;

  aboutToAppear(): void {
    this.startStatusTimer();
  }

  aboutToDisappear(): void {
    this.clearStatusTimer();
  }

  private startStatusTimer(): void {
    this.clearStatusTimer();
    this.timerId = setInterval(() => {
      this.statusTick += 1;
    }, 60_000);
  }

  private clearStatusTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private getStatusLabel(): string {
    const _tick = this.statusTick;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return getScheduledListStatusLabel(this.session, loadExitPlanIds(hostContext));
  }

  private getStatusTagStyle(label: string): ScheduledStatusTagStyle {
    if (label === '今日已撕毁') {
      return {
        textColor: AppTheme.colors.danger,
        backgroundColor: AppTheme.colors.dangerSoft
      };
    }
    if (label === '今日已完成') {
      return {
        textColor: AppTheme.colors.success,
        backgroundColor: AppTheme.colors.successSoft
      };
    }
    if (label === '今日不生效') {
      return {
        textColor: AppTheme.colors.textMuted,
        backgroundColor: AppTheme.colors.surfaceRaised
      };
    }
    if (this.session.status === 'active') {
      return {
        textColor: AppTheme.colors.primary,
        backgroundColor: AppTheme.colors.primarySoft
      };
    }
    return {
      textColor: '#2563EB',
      backgroundColor: '#EEF5FF'
    };
  }

  private getTimeLabel(): string {
    const start = this.session.schedule_start && this.session.schedule_start.length > 0
      ? this.session.schedule_start
      : '09:00';
    const end = this.session.schedule_end && this.session.schedule_end.length > 0
      ? this.session.schedule_end
      : '18:00';
    const durationMin = Math.max(0, getScheduledSessionEndMin(this.session) - getScheduledSessionStartMin(this.session));
    return `${start} - ${end} · ${minutesToHours(durationMin)}`;
  }

  private getRepeatLabel(): string {
    const repeat = this.session.schedule_repeat ?? '';
    return summarizeRepeatDays(getScheduleRepeatDays(repeat));
  }

  @Builder
  private buildStatusTag(label: string): void {
    Text(label)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.getStatusTagStyle(label).textColor)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(this.getStatusTagStyle(label).backgroundColor)
      .borderRadius(AppTheme.radius.pill)
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(this.session.title.length > 0 ? this.session.title : '定时契约')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        this.buildStatusTag(this.getStatusLabel())
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column({ space: 4 }) {
        Text(this.getTimeLabel())
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')

        Text(`${this.getRepeatLabel()} · ${this.session.expects_duo ? '搭子互督' : '单人专注'}`)
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')

        if (this.session.partner?.nickname) {
          Text(`搭子：${this.session.partner.nickname}`)
            .fontSize(12)
            .fontColor(AppTheme.colors.textMuted)
            .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(16)
    .padding(16)
    .opacity(isInactiveScheduledListSession(this.session) ? 0.55 : 1)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.onPress?.();
    })
  }
}

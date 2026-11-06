import { common } from '@kit.AbilityKit';
import {
  DuoSessionView,
  getScheduleRepeatDays,
  getScheduledListStatusLabel,
  getScheduledParticipationLabel,
  getScheduledSessionEndMin,
  getScheduledSessionStartMin,
  isInactiveScheduledListSession,
} from '../../models/DuoModel';
import { summarizeRepeatDays } from '../../models/PlanModel';
import { minutesToHours } from '../../models/ActiveLockModel';
import { getScheduledDurationMinutes } from '../../services/ScheduledPlanValidation';
import { AppTheme, isDarkThemeMode } from '../../constants/Theme';
import { loadExitPlanIds } from '../../services/ExitPlanIdsService';
import { isSleepSchedule } from '../../utils/ScheduledClockUtil';

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
    participation_mode: 'solo',
    enabled: true,
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

  private colorWithAlpha(hex: string): string {
    const raw = hex.replace('#', '');
    if (raw.length !== 6) {
      return hex;
    }
    const red = parseInt(raw.substring(0, 2), 16);
    const green = parseInt(raw.substring(2, 4), 16);
    const blue = parseInt(raw.substring(4, 6), 16);
    return `rgba(${red}, ${green}, ${blue}, 0.094)`;
  }

  private mutedTagBackground(): string {
    return isDarkThemeMode() ? 'rgba(255, 255, 255, 0.06)' : 'rgba(0, 0, 0, 0.06)';
  }

  private getStatusTagStyle(label: string): ScheduledStatusTagStyle {
    if (label === '未启用' || label === '今日不生效') {
      return {
        textColor: AppTheme.colors.text3,
        backgroundColor: this.mutedTagBackground()
      };
    }
    if (label === '今日已撕毁') {
      return {
        textColor: AppTheme.colors.danger,
        backgroundColor: this.colorWithAlpha(AppTheme.colors.danger)
      };
    }
    if (label === '今日已完成') {
      return {
        textColor: AppTheme.colors.success,
        backgroundColor: this.colorWithAlpha(AppTheme.colors.success)
      };
    }
    if (this.session.status === 'active') {
      return {
        textColor: AppTheme.colors.primary,
        backgroundColor: this.colorWithAlpha(AppTheme.colors.primary)
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
    const durationMin = getScheduledDurationMinutes(
      getScheduledSessionStartMin(this.session),
      getScheduledSessionEndMin(this.session)
    );
    return `${start} - ${end} · ${minutesToHours(durationMin)}`;
  }

  private getRepeatLabel(): string {
    const repeat = this.session.schedule_repeat ?? '';
    return summarizeRepeatDays(getScheduleRepeatDays(repeat));
  }

  private formatEndDate(): string {
    const raw = this.session.end_date ?? '';
    if (raw.length >= 10) {
      return raw.substring(0, 10);
    }
    return raw;
  }

  @Builder
  private buildSleepBadge(): void {
    Text('早睡')
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor('#06B6D4')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor('rgba(6, 182, 212, 0.14)')
      .borderRadius(AppTheme.radius.pill)
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
      Row({ space: 6 }) {
        Text(this.session.title.length > 0 ? this.session.title : '定时契约')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        if (isSleepSchedule(this.session.schedule_json)) {
          this.buildSleepBadge()
        }
        if (!this.session.enabled) {
          this.buildStatusTag('未启用')
        } else {
          this.buildStatusTag(this.getStatusLabel())
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column({ space: 4 }) {
        Text(this.getTimeLabel())
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')

        Text(`${this.getRepeatLabel()} · ${getScheduledParticipationLabel(this.session)}`)
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')

        if (this.session.partner?.nickname) {
          Text(`搭子：${this.session.partner.nickname}`)
            .fontSize(12)
            .fontColor(AppTheme.colors.textMuted)
            .width('100%')
        }

        if ((this.session.end_date ?? '').length > 0) {
          Text(`截止 ${this.formatEndDate()}`)
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

import {
  DuoSessionView,
  getScheduleRepeatDays,
  getScheduledSessionEndMin,
  getScheduledSessionStartMin,
  getScheduledSessionStatusLabel,
  isInactiveScheduledSession,
  isScheduledSessionActivationOpen
} from '../../models/DuoModel';
import { summarizeRepeatDays } from '../../models/PlanModel';
import { minutesToHours } from '../../models/ActiveLockModel';
import { AppTheme } from '../../constants/Theme';

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

  private isEffectivelyActive(): boolean {
    return isScheduledSessionActivationOpen(this.session);
  }

  private getTagBackgroundColor(): string {
    if (this.isEffectivelyActive()) {
      return AppTheme.colors.primarySoft;
    }
    if (this.session.expects_duo && this.session.participation_mode !== 'duo') {
      return '#F7EFE0';
    }
    return '#EEF5FF';
  }

  private getTagTextColor(): string {
    if (this.isEffectivelyActive()) {
      return AppTheme.colors.primary;
    }
    if (this.session.expects_duo && this.session.participation_mode !== 'duo') {
      return AppTheme.colors.warning;
    }
    return '#2563EB';
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

  private isDuoMode(): boolean {
    return this.session.expects_duo === true;
  }

  @Builder
  private buildStatusTags(): void {
    Row({ space: 6 }) {
      if (this.isDuoMode()) {
        Text('搭子')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.warning)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#F7EFE0')
          .borderRadius(AppTheme.radius.pill)
      }

      Text(getScheduledSessionStatusLabel(this.session))
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getTagTextColor())
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor(this.getTagBackgroundColor())
        .borderRadius(AppTheme.radius.pill)
    }
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

        this.buildStatusTags()
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
    .opacity(isInactiveScheduledSession(this.session) ? 0.55 : 1)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.onPress?.();
    })
  }
}

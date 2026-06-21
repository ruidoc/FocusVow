import {
  DuoSessionView,
  getScheduleRepeatDays,
  getScheduledSessionStatusLabel
} from '../../models/DuoModel';
import { summarizeRepeatDays } from '../../models/PlanModel';
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
    mode: 'allow',
    participation_mode: 'solo'
  };
  onPress?: () => void;

  private getTagBackgroundColor(): string {
    if (this.session.status === 'active') {
      return AppTheme.colors.primarySoft;
    }
    if (this.session.expects_duo && this.session.participation_mode !== 'duo') {
      return '#F7EFE0';
    }
    return '#EEF5FF';
  }

  private getTagTextColor(): string {
    if (this.session.status === 'active') {
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
    return `${start} - ${end}`;
  }

  private getRepeatLabel(): string {
    const repeat = this.session.schedule_repeat ?? '';
    return summarizeRepeatDays(getScheduleRepeatDays(repeat));
  }

  private getAppCount(): number {
    if (this.session.my_app_count !== undefined && this.session.my_app_count > 0) {
      return this.session.my_app_count;
    }
    return this.session.my_apps?.length ?? 0;
  }

  private isDuoMode(): boolean {
    return this.session.expects_duo === true;
  }

  @Builder
  private buildStatusTags(): void {
    Row({ space: 6 }) {
      if (this.isDuoMode()) {
        Text('搭子')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.warning)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#F7EFE0')
          .borderRadius(AppTheme.radius.pill)
      }

      Text(getScheduledSessionStatusLabel(this.session))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getTagTextColor())
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(this.getTagBackgroundColor())
        .borderRadius(AppTheme.radius.pill)
    }
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text(this.session.title.length > 0 ? this.session.title : '定时契约')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .layoutWeight(1)

        this.buildStatusTags()
      }
      .width('100%')

      Text(this.getTimeLabel())
        .fontSize(15)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Text(`${this.getRepeatLabel()} · ${this.getAppCount()} 个应用 · ${this.session.expects_duo ? '搭子互督' : '单人专注'}`)
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      if (this.session.partner?.nickname) {
        Text(`搭子：${this.session.partner.nickname}`)
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
      }
    }
    .width('100%')
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .padding(18)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.onPress?.();
    })
  }
}

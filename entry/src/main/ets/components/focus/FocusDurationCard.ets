import { AppTheme, isDarkThemeMode } from '../../constants/Theme';
import { TimerMode } from '../../utils/TimerMode';

function formatDurationLabel(minutes: number): string {
  if (minutes < 60) {
    return `${minutes} 分钟`;
  }
  const hours = Math.floor(minutes / 60);
  const remain = minutes % 60;
  if (remain === 0) {
    return `${hours} 小时`;
  }
  return `${hours} 小时 ${remain} 分钟`;
}

function rangeLabelColor(): string {
  return isDarkThemeMode() ? '#AAAAAA' : '#888888';
}

@Component
export struct FocusDurationCard {
  @Prop title: string = '';
  @Prop timerMode: TimerMode = 'countdown';
  @Prop durationMinutes: number = 25;
  @Prop outlined: boolean = false;
  onDurationChange?: (minutes: number) => void;

  private readonly durationMin: number = 5;
  private readonly durationMax: number = 180;
  private readonly durationStep: number = 5;

  private cardTitle(): string {
    if (this.title.length > 0) {
      return this.title;
    }
    return this.timerMode === 'countup' ? '最短专注时长' : '专注时长';
  }

  private normalizeDuration(raw: number): number {
    let next = Math.max(this.durationMin, Math.min(this.durationMax, Math.floor(raw)));
    next = Math.round(next / this.durationStep) * this.durationStep;
    return Math.max(this.durationMin, Math.min(this.durationMax, next));
  }

  build() {
    Column({ space: 0 }) {
      Text(this.cardTitle())
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
        .margin({ bottom: 8 })

      Text(formatDurationLabel(this.durationMinutes))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.primary)
        .lineHeight(24)
        .width('100%')
        .textAlign(TextAlign.Center)

      Slider({
        value: this.durationMinutes,
        min: this.durationMin,
        max: this.durationMax,
        step: this.durationStep,
        style: SliderStyle.OutSet,
      })
        .width('100%')
        .margin({ top: 20 })
        .blockColor(AppTheme.colors.primary)
        .trackColor(AppTheme.colors.border)
        .selectedColor(AppTheme.colors.primary)
        .showSteps(false)
        .showTips(false)
        .onChange((value: number) => {
          this.onDurationChange?.(this.normalizeDuration(value));
        })

      Row() {
        Text('5 分钟')
          .fontSize(13)
          .fontColor(rangeLabelColor())
        Blank()
        Text('3 小时')
          .fontSize(13)
          .fontColor(rangeLabelColor())
      }
      .width('100%')

      if (this.timerMode === 'countup') {
        Text('满最短时长后可随时正常结束。')
          .fontSize(13)
          .lineHeight(18)
          .fontWeight(FontWeight.Regular)
          .fontColor(AppTheme.colors.text3)
          .width('100%')
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding(this.outlined ? 20 : 16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border(this.outlined ? { width: 1, color: AppTheme.colors.border } : { width: 0 })
  }
}

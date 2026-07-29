import { AppTheme } from '../../constants/Theme';
import { TimerMode } from '../../utils/TimerMode';

@Component
export struct TimerModeSegmented {
  @Prop value: TimerMode = 'countdown';
  onChange?: (mode: TimerMode) => void;

  build() {
    Row({ space: 0 }) {
      Text('倒计时')
        .layoutWeight(1)
        .fontSize(14)
        .fontColor(this.value === 'countdown' ? '#0F172A' : AppTheme.colors.textSecondary)
        .fontWeight(this.value === 'countdown' ? FontWeight.Medium : FontWeight.Regular)
        .textAlign(TextAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .borderRadius(20)
        .backgroundColor(this.value === 'countdown' ? Color.White : Color.Transparent)
        .onClick(() => {
          this.onChange?.('countdown');
        })

      Text('正计时')
        .layoutWeight(1)
        .fontSize(14)
        .fontColor(this.value === 'countup' ? '#0F172A' : AppTheme.colors.textSecondary)
        .fontWeight(this.value === 'countup' ? FontWeight.Medium : FontWeight.Regular)
        .textAlign(TextAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .borderRadius(20)
        .backgroundColor(this.value === 'countup' ? Color.White : Color.Transparent)
        .onClick(() => {
          this.onChange?.('countup');
        })
    }
    .width(220)
    .padding(4)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(999)
  }
}

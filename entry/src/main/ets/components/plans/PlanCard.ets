import { FocusPlan, summarizeRepeatDays } from '../../models/PlanModel';
import { AppTheme } from '../../constants/Theme';

@Component
export struct PlanCard {
  @Prop plan: FocusPlan = {
    id: '',
    name: '',
    startTime: '09:00',
    endTime: '18:00',
    repeatDays: [1, 2, 3, 4, 5],
    selectedTokens: [],
    selectedCount: 0,
    mode: 'shield',
    enabled: true,
    createdAt: 0,
    updatedAt: 0
  };
  onPress?: () => void;

  build() {
    Button() {
      Column({ space: 10 }) {
        Row() {
          Text(this.plan.name)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
          Blank()
          Text(this.plan.enabled ? '已启用' : '已暂停')
            .fontSize(12)
            .fontColor(this.plan.enabled ? AppTheme.colors.primary : AppTheme.colors.textMuted)
        }
        .width('100%')

        Text(`${this.plan.startTime} - ${this.plan.endTime}`)
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')

        Text(`${summarizeRepeatDays(this.plan.repeatDays)} · ${this.plan.selectedCount} 个应用 · ${this.plan.mode === 'shield' ? '锁定模式' : '放行模式'}`)
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .type(ButtonType.Capsule)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .padding(18)
    .onClick(() => {
      this.onPress?.();
    })
  }
}

import { FocusPlan, summarizeRepeatDays } from '../../models/PlanModel';

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
            .fontColor('#111827')
          Blank()
          Text(this.plan.enabled ? '已启用' : '已暂停')
            .fontSize(12)
            .fontColor(this.plan.enabled ? '#2563EB' : '#9CA3AF')
        }
        .width('100%')

        Text(`${this.plan.startTime} - ${this.plan.endTime}`)
          .fontSize(14)
          .fontColor('#374151')
          .width('100%')

        Text(`${summarizeRepeatDays(this.plan.repeatDays)} · ${this.plan.selectedCount} 个应用 · ${this.plan.mode === 'shield' ? '锁定模式' : '放行模式'}`)
          .fontSize(12)
          .fontColor('#6B7280')
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .type(ButtonType.Capsule)
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .padding(18)
    .onClick(() => {
      this.onPress?.();
    })
  }
}

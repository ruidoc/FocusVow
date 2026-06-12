import {
  FocusPlan,
  getPlanDurationMinutes,
  getPlanNextStartText,
  getPlanPresentationLabel,
  getPlanPresentationState,
  summarizeRepeatDays
} from '../../models/PlanModel';
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
  onDelete?: () => void;
  onToggle?: () => void;

  private getTagBackgroundColor(): string {
    const state = getPlanPresentationState(this.plan);
    if (state === 'running') {
      return AppTheme.colors.primarySoft;
    }
    if (state === 'upcoming') {
      return '#F7EFE0';
    }
    if (state === 'paused') {
      return AppTheme.colors.surfaceRaised;
    }
    return '#EEF5FF';
  }

  private getTagTextColor(): string {
    const state = getPlanPresentationState(this.plan);
    if (state === 'running') {
      return AppTheme.colors.primary;
    }
    if (state === 'upcoming') {
      return AppTheme.colors.warning;
    }
    if (state === 'paused') {
      return AppTheme.colors.textMuted;
    }
    return '#2563EB';
  }

  private getModeLabel(): string {
    return this.plan.mode === 'shield' ? '锁定模式' : '放行模式';
  }

  private getDurationLabel(): string {
    return `${getPlanDurationMinutes(this.plan)} 分钟`;
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 12 }) {
        Row() {
          Text(this.plan.name)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .layoutWeight(1)

          Text(getPlanPresentationLabel(this.plan))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getTagTextColor())
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.getTagBackgroundColor())
            .borderRadius(AppTheme.radius.pill)
        }
        .width('100%')

        Text(`${this.plan.startTime} - ${this.plan.endTime} · ${this.getDurationLabel()}`)
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')

        Text(`${summarizeRepeatDays(this.plan.repeatDays)} · ${this.plan.selectedCount} 个应用 · ${this.getModeLabel()}`)
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')

        Text(getPlanNextStartText(this.plan))
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.onPress?.();
      })

      Row({ space: 10 }) {
        Button('编辑')
          .layoutWeight(1)
          .height(36)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .fontColor(AppTheme.colors.textPrimary)
          .border({ width: 0, color: AppTheme.colors.surfaceRaised })
          .onClick(() => {
            this.onPress?.();
          })

        Button(this.plan.enabled ? '停用' : '启用')
          .layoutWeight(1)
          .height(36)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.primarySoft)
          .fontColor(AppTheme.colors.primary)
          .border({ width: 0, color: AppTheme.colors.primarySoft })
          .onClick(() => {
            this.onToggle?.();
          })

        Button('删除')
          .layoutWeight(1)
          .height(36)
          .type(ButtonType.Capsule)
          .backgroundColor(AppTheme.colors.dangerSoft)
          .fontColor(AppTheme.colors.danger)
          .border({ width: 0, color: AppTheme.colors.dangerSoft })
          .onClick(() => {
            this.onDelete?.();
          })
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
    .padding(18)
  }
}

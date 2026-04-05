import { AppTheme } from '../../constants/Theme';
import { FocusRunStatus, FocusSession, createIdleFocusSession, getRemainingSeconds } from '../../models/FocusSession';
import { FocusPlan } from '../../models/PlanModel';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

type StatsPeriod = 'today' | 'week' | 'month';

@Component
export struct StatsPage {
  @StorageLink(StoreKeys.FocusCurrentSession) currentSession: FocusSession = createIdleFocusSession();
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @State currentPeriod: StatsPeriod = 'today';

  private getPeriodLabel(period: StatsPeriod): string {
    if (period === 'week') {
      return '本周';
    }
    if (period === 'month') {
      return '本月';
    }
    return '今日';
  }

  private getPlanSummary(): string {
    if (this.planCollection.length === 0) {
      return '还没有契约';
    }
    if (this.planCollection.length === 1) {
      return '1 条契约在运行体系里';
    }
    return `${this.planCollection.length} 条契约已进入体系`;
  }

  private getPeriodHeadline(): string {
    if (this.currentPeriod === 'week') {
      return '本周统计骨架';
    }
    if (this.currentPeriod === 'month') {
      return '本月统计骨架';
    }
    return '今日统计骨架';
  }

  private getPeriodHint(): string {
    return `${this.getPeriodLabel(this.currentPeriod)}数据还未接入真实聚合逻辑，当前先对齐 FocusExpo 的页面结构和视觉层级。`;
  }

  private getCurrentFocusSummary(): string {
    if (this.currentSession.status !== FocusRunStatus.Running) {
      return '当前没有进行中的专注，可从首页或快速专注重新开始。';
    }

    const remainingSeconds = getRemainingSeconds(this.currentSession, Date.now());
    const remainingMinutes = Math.ceil(remainingSeconds / 60);
    return `${this.currentSession.planName.length > 0 ? this.currentSession.planName : '快速专注'} 还剩 ${remainingMinutes} 分钟`;
  }

  @Builder
  private buildPeriodButton(period: StatsPeriod, active: boolean): void {
    Text(this.getPeriodLabel(period))
      .fontSize(13)
      .fontWeight(active ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(active ? '#FFFFFF' : AppTheme.colors.textSecondary)
      .padding({ left: 16, right: 16, top: 9, bottom: 9 })
      .backgroundColor(active ? AppTheme.colors.primary : AppTheme.colors.surface)
      .borderRadius(AppTheme.radius.pill)
      .border({ width: 1, color: active ? AppTheme.colors.primary : AppTheme.colors.border })
      .onClick(() => {
        this.currentPeriod = period;
      })
  }

  @Builder
  private buildStatCard(label: string, value: string, detail: string): void {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(12)
        .fontColor(AppTheme.colors.textMuted)

      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)

      Text(detail)
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 6 }) {
          Text('专注统计')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')

          Text(this.getPeriodHint())
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
        }
        .width('100%')

        Row({ space: 10 }) {
          this.buildPeriodButton('today', this.currentPeriod === 'today')
          this.buildPeriodButton('week', this.currentPeriod === 'week')
          this.buildPeriodButton('month', this.currentPeriod === 'month')
        }
        .width('100%')

        this.buildStatCard(this.getPeriodHeadline(), `${this.planCollection.length}`, this.getPlanSummary())
        this.buildStatCard(
          `${this.getPeriodLabel(this.currentPeriod)}限制应用`,
          `${this.selectedAppCount}`,
          this.selectedAppCount > 0 ? `当前以 ${this.getPeriodLabel(this.currentPeriod)} 视角展示骨架数据` : '还没有选择任何限制应用'
        )
        this.buildStatCard(
          `${this.getPeriodLabel(this.currentPeriod)}当前状态`,
          this.currentSession.status === FocusRunStatus.Running ? '专注中' : '空闲中',
          this.getCurrentFocusSummary()
        )
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 22, bottom: 28 })
      .backgroundColor(AppTheme.colors.background)
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}

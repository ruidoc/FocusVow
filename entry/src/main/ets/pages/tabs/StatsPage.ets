import { PageScaffold } from '../../components/common/PageScaffold';
import { AppTheme } from '../../constants/Theme';
import {
  ActiveLockState,
  createIdleLockState,
  getRemainingSeconds,
  isLocked
} from '../../models/ActiveLockModel';
import { FocusPlan } from '../../models/PlanModel';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

type StatsPeriod = 'today' | 'week' | 'month';

@Component
export struct StatsPage {
  @StorageLink(StoreKeys.LockActiveState) activeLock: ActiveLockState = createIdleLockState();
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
    if (!isLocked(this.activeLock)) {
      return '当前没有进行中的专注，可从首页或快速专注重新开始。';
    }

    if (this.activeLock.endAt <= 0) {
      return `${this.activeLock.title} 锁定中`;
    }

    const remainingSeconds = getRemainingSeconds(this.activeLock, Date.now());
    const remainingMinutes = Math.ceil(remainingSeconds / 60);
    return `${this.activeLock.title} 还剩 ${remainingMinutes} 分钟`;
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

  @Builder
  private buildStatsContent(): void {
    Scroll() {
      Column({ space: 16 }) {
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
          isLocked(this.activeLock) ? '锁定中' : '空闲中',
          this.getCurrentFocusSummary()
        )
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .layoutWeight(1)
    .align(Alignment.Top)
  }

  build() {
    PageScaffold({
      subtitle: this.getPeriodHint(),
      headerMode: 'default',
      showDecoration: false,
      topPadding: 12,
      bottomPadding: 12,
      horizontalPadding: 20,
      content: (): void => {
        this.buildStatsContent();
      }
    })
  }
}

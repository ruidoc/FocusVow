import { router } from '@kit.ArkUI';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { formatSleepRecordDay, parseSleepHistoryItem, SleepHistoryItem } from '../../models/SleepPlanModel';
import { minutesToHours } from '../../models/ActiveLockModel';
import { backRoute } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';

const PAGE_SIZE: number = 30;

function readSessionId(): string {
  try {
    const params = router.getParams() as Record<string, Object> | undefined;
    const raw = params?.['sessionId'];
    if (typeof raw === 'string') {
      return raw.trim();
    }
  } catch (_e) {
  }
  return '';
}

function minutesToClock(min: number): string {
  const dayMin = 24 * 60;
  const n = ((min % dayMin) + dayMin) % dayMin;
  const h = Math.floor(n / 60);
  const m = n % 60;
  return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
}

function formatSleepPlanClockRange(startMin: number, totalMin: number): string {
  if (totalMin <= 0) {
    return '';
  }
  return `${minutesToClock(startMin)} - ${minutesToClock(startMin + totalMin)}`;
}

@Entry
@Component
struct SleepRecordsPage {
  @State sessionId: string = '';
  @State items: SleepHistoryItem[] = [];
  @State page: number = 1;
  @State total: number = 0;
  @State loading: boolean = true;

  aboutToAppear(): void {
    this.sessionId = readSessionId();
    void this.loadPage(1, false);
  }

  private hasMore(): boolean {
    return this.items.length < this.total;
  }

  private async loadPage(nextPage: number, append: boolean): Promise<void> {
    if (this.sessionId.length === 0) {
      this.loading = false;
      return;
    }
    this.loading = true;
    const response = await DuoApiService.getScheduledRecords(this.sessionId, nextPage, PAGE_SIZE);
    if (response.statusCode === 200 && response.data) {
      const body = response.data as Record<string, Object>;
      const rawItems = body['items'];
      const list: SleepHistoryItem[] = [];
      if (Array.isArray(rawItems)) {
        for (let i = 0; i < rawItems.length; i++) {
          const parsed = parseSleepHistoryItem(rawItems[i] as Record<string, Object>);
          if (parsed) {
            list.push(parsed);
          }
        }
      }
      this.items = append ? [...this.items, ...list] : list;
      this.total = Math.max(0, Math.floor(Number(body['total'] ?? list.length)));
      this.page = nextPage;
    }
    this.loading = false;
  }

  @Builder
  private buildRow(item: SleepHistoryItem): void {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(formatSleepRecordDay(item.date))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
        Text(formatSleepPlanClockRange(item.start_min, item.total_min))
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 4 }) {
        Text(item.status === 'completed' ? '守约' : '毁约')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.status === 'completed' ? AppTheme.colors.success : AppTheme.colors.danger)
        Text(`实际 ${minutesToHours(item.actual_min)}`)
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
  }

  @Builder
  private buildContent(): void {
    if (this.sessionId.length === 0) {
      Text('缺少契约信息')
        .fontSize(14)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 40 })
    } else if (this.loading && this.items.length === 0) {
      LoadingProgress().width(32).height(32).margin({ top: 40 })
    } else if (this.items.length === 0) {
      Text('暂无履约记录')
        .fontSize(14)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 40 })
    } else {
      Column({ space: 10 }) {
        ForEach(this.items, (item: SleepHistoryItem) => {
          this.buildRow(item)
        }, (item: SleepHistoryItem) => item.id)

        if (this.hasMore()) {
          Button(this.loading ? '加载中…' : '加载更多')
            .width('100%')
            .height(44)
            .type(ButtonType.Normal)
            .backgroundColor(AppTheme.colors.surface)
            .fontColor(AppTheme.colors.primary)
            .enabled(!this.loading)
            .margin({ top: 8 })
            .onClick(() => {
              void this.loadPage(this.page + 1, true);
            })
        }
      }
      .width('100%')
    }
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '早睡记录',
        showBack: true,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildContent();
        },
      })
    }
    .width('100%')
    .height('100%')
  }
}

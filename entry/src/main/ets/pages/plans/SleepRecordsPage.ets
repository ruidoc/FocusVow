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

function sleepRecordTimeLine(item: SleepHistoryItem): string {
  const timeRange = formatSleepPlanClockRange(item.start_min, item.total_min);
  if (timeRange.length === 0) {
    return '';
  }
  const statusInParens = item.status === 'completed' ? '成功' : '失败';
  return `${timeRange}（${statusInParens}）`;
}

@Entry
@Component
struct SleepRecordsPage {
  @State sessionId: string = '';
  @State items: SleepHistoryItem[] = [];
  @State page: number = 1;
  @State total: number = 0;
  @State loading: boolean = true;
  @State scrollerReady: boolean = false;
  private listScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.scrollerReady = true;
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
  private buildRow(
    item: SleepHistoryItem,
    isLast: boolean,
    timeLine: string,
  ): void {
    Row() {
      Column({ space: 4 }) {
        Text(formatSleepRecordDay(item.date))
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)
        if (timeLine.length > 0) {
          Text(timeLine)
            .fontSize(12)
            .fontColor(AppTheme.colors.text3)
            .margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .padding({ right: 12 })

      Text(minutesToHours(item.actual_min))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(
          item.status === 'completed'
            ? AppTheme.colors.success
            : AppTheme.colors.danger,
        )
    }
    .width('100%')
    .padding({
      top: 12,
      bottom: 12,
      left: 16,
      right: 16,
    })
    .backgroundColor(AppTheme.colors.surface)
    .border(
      isLast
        ? { width: 0 }
        : { width: { bottom: 1 }, color: AppTheme.colors.border },
    )
  }

  @Builder
  private buildContent(): void {
    if (this.sessionId.length === 0) {
      Text('还没有早睡契约')
        .fontSize(14)
        .fontColor(AppTheme.colors.text3)
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })
    } else if (this.loading && this.items.length === 0) {
      LoadingProgress().width(32).height(32).margin({ top: 24 })
    } else if (this.items.length === 0) {
      Text('还没有早睡记录')
        .fontSize(14)
        .fontColor(AppTheme.colors.text3)
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })
    } else {
      List({ space: 0, scroller: this.listScroller }) {
        ForEach(this.items, (item: SleepHistoryItem, index: number) => {
          ListItem() {
            this.buildRow(
              item,
              index === this.items.length - 1 && !this.hasMore(),
              sleepRecordTimeLine(item),
            )
          }
        }, (item: SleepHistoryItem) => item.id)

        if (this.hasMore()) {
          ListItem() {
            Row() {
              Text(this.loading ? '加载中…' : '加载更多')
                .fontSize(14)
                .fontColor(AppTheme.colors.primary)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 16, bottom: 16 })
            .onClick(() => {
              if (!this.loading) {
                void this.loadPage(this.page + 1, true);
              }
            })
          }
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(AppTheme.colors.background)
    }
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '早睡记录',
        showBack: true,
        usePageScroll: false,
        horizontalPadding: 0,
        bindScrollers: this.scrollerReady ? [this.listScroller] : [],
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

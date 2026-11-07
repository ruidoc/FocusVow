import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { PointLogItem } from '../../models/PointModel';
import { backRoute } from '../../router/PageRoutes';
import { PointApiService } from '../../services/PointApiService';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { formatContractPointDelta, formatContractPoints } from '../../utils/ContractPointUtil';

bootstrapStores();

function formatLogSubtitle(item: PointLogItem): string {
  const chunks: string[] = [];
  if (item.remark.length > 0) {
    chunks.push(item.remark);
  }
  const raw = item.createdAt.trim();
  if (raw.length >= 16) {
    chunks.push(`${raw.slice(5, 10)} ${raw.slice(11, 16)}`);
  } else if (raw.length > 0) {
    chunks.push(raw);
  }
  chunks.push(`余额 ${formatContractPoints(item.balanceAfter)}`);
  return chunks.join(' · ');
}

@Entry
@Component
struct PointLogsPage {
  @State items: PointLogItem[] = [];
  @State page: number = 1;
  @State hasMore: boolean = false;
  @State loading: boolean = true;
  @State scrollerReady: boolean = false;
  private listScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.scrollerReady = true;
    void this.load(1, false);
  }

  onPageShow(): void {
    void this.load(1, false);
  }

  private async load(nextPage: number, append: boolean): Promise<void> {
    this.loading = true;
    const data = await PointApiService.getLogs(nextPage);
    if (append) {
      const merged: PointLogItem[] = [];
      for (let i = 0; i < this.items.length; i++) {
        merged.push(this.items[i]);
      }
      for (let j = 0; j < data.items.length; j++) {
        merged.push(data.items[j]);
      }
      this.items = merged;
    } else {
      this.items = data.items;
    }
    this.page = data.page;
    this.hasMore = data.hasMore;
    this.loading = false;
  }

  @Builder
  private buildRow(item: PointLogItem, showDivider: boolean): void {
    Column() {
      Row() {
        Column({ space: 4 }) {
          Text(item.type.length > 0 ? item.type : '变动')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
          Text(formatLogSubtitle(item))
            .fontSize(12)
            .fontColor(AppTheme.colors.text3)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ right: 12 })
        Text(formatContractPointDelta(item.delta))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(item.delta >= 0 ? AppTheme.colors.success : AppTheme.colors.danger)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      if (showDivider) {
        Divider()
          .color(AppTheme.colors.border)
          .strokeWidth(1)
          .margin({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .backgroundColor(AppTheme.colors.background)
  }

  @Builder
  private buildPageContent(): void {
    if (this.loading && this.items.length === 0) {
      Column() {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(AppTheme.colors.primary)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.colors.background)
    } else if (this.items.length === 0) {
      Column() {
        Text('还没有加减分记录')
          .fontSize(14)
          .fontColor(AppTheme.colors.text3)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(AppTheme.colors.background)
    } else {
      List({ scroller: this.listScroller }) {
        ForEach(this.items, (item: PointLogItem, index: number) => {
          ListItem() {
            this.buildRow(item, index < this.items.length - 1)
          }
        }, (item: PointLogItem) => item.id)
        if (this.hasMore) {
          ListItem() {
            Row() {
              Text(this.loading ? '加载中…' : '加载更多')
                .fontSize(14)
                .fontColor(AppTheme.colors.primary)
            }
            .width('100%')
            .height(48)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              if (!this.loading) {
                void this.load(this.page + 1, true);
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
        title: '契约分明细',
        showBack: true,
        usePageScroll: false,
        horizontalPadding: 0,
        bindScrollers: this.scrollerReady ? [this.listScroller] : [],
        onBack: (): void => {
          backRoute();
        },
        content: (): void => {
          this.buildPageContent();
        },
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.colors.background)
  }
}

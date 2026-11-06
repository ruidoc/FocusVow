import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { PointLogItem } from '../../models/PointModel';
import { backRoute } from '../../router/PageRoutes';
import { PointApiService } from '../../services/PointApiService';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { formatContractPointDelta } from '../../utils/ContractPointUtil';

bootstrapStores();

@Entry
@Component
struct PointLogsPage {
  @State items: PointLogItem[] = [];
  @State page: number = 1;
  @State hasMore: boolean = false;
  @State loading: boolean = true;

  aboutToAppear(): void {
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
  private buildPageContent(): void {
    Column() {
      if (this.loading && this.items.length === 0) {
        LoadingProgress().width(28).height(28)
      } else {
        List({ space: 8 }) {
          ForEach(this.items, (item: PointLogItem) => {
            ListItem() {
              Row() {
                Column({ space: 4 }) {
                  Text(item.type.length > 0 ? item.type : '变动')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                  if (item.remark.length > 0) {
                    Text(item.remark)
                      .fontSize(12)
                      .fontColor(AppTheme.colors.textSecondary)
                  }
                  Text(item.createdAt)
                    .fontSize(11)
                    .fontColor(AppTheme.colors.text3)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(formatContractPointDelta(item.delta))
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(item.delta >= 0 ? AppTheme.colors.success : AppTheme.colors.danger)
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }
          }, (item: PointLogItem) => item.id)
        }
        .width('100%')
        .layoutWeight(1)

        if (this.hasMore) {
          Button(this.loading ? '加载中…' : '加载更多')
            .width('100%')
            .height(40)
            .margin({ top: 12 })
            .enabled(!this.loading)
            .onClick(() => {
              void this.load(this.page + 1, true);
            })
        }
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '契约分明细',
        showBack: true,
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
  }
}

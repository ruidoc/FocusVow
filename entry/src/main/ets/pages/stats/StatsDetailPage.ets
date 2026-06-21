import { common } from '@kit.AbilityKit';
import { showErrorToast } from '../../common/Toast';
import { buildHonorCertificateData, buildShameCertificateData } from '../../services/CertificateCopyService';
import {
  openHonorCertificatePreview,
  openShameCertificatePreview
} from '../../services/CertificateNavigationService';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { HonorRecordListSection } from '../../components/stats/HonorRecordListSection';
import { ShameRecordListSection } from '../../components/stats/ShameRecordListSection';
import { AppTheme } from '../../constants/Theme';
import {
  DuoShameDay,
  DuoShameRecord,
  DuoTimelineDay,
  DuoTimelineRecord
} from '../../models/DuoModel';
import { backRoute } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import {
  flattenShameDays,
  flattenTimelineDays,
  getStatsDetailPageTitle,
  HonorRecordItem,
  ShameRecordItem,
  StatsDetailSection,
  StatsPeriod
} from '../../services/StatsRecordUtil';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

const PAGE_SIZE: number = 20;

@Entry
@Component
struct StatsDetailPage {
  @State currentPeriod: StatsPeriod = 'today';
  @State currentSection: StatsDetailSection = 'timeline';
  @State timeline: DuoTimelineDay[] = [];
  @State shame: DuoShameDay[] = [];
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  @State errorMessage: string = '';
  @State visibleCount: number = PAGE_SIZE;

  private listScroller: Scroller = new Scroller();
  @State private scrollerReady: boolean = false;
  private reloadVersion: number = 0;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    const storedPeriod = String(AppStorage.get<string>(StoreKeys.StatsDetailPeriod) ?? 'today');
    const storedSection = String(AppStorage.get<string>(StoreKeys.StatsDetailSection) ?? 'timeline');
    this.currentPeriod = storedPeriod === 'week' || storedPeriod === 'month' ? storedPeriod : 'today';
    this.currentSection = storedSection === 'shame' ? 'shame' : 'timeline';
    this.scrollerReady = true;
    void this.reload(false);
  }

  private getAllItems(): HonorRecordItem[] | ShameRecordItem[] {
    if (this.currentSection === 'timeline') {
      return flattenTimelineDays(this.timeline);
    }
    return flattenShameDays(this.shame);
  }

  private getVisibleHonorItems(): HonorRecordItem[] {
    const allItems = flattenTimelineDays(this.timeline);
    return allItems.slice(0, this.visibleCount);
  }

  private getVisibleShameItems(): ShameRecordItem[] {
    const allItems = flattenShameDays(this.shame);
    return allItems.slice(0, this.visibleCount);
  }

  private hasMoreItems(): boolean {
    return this.visibleCount < this.getAllItems().length;
  }

  private loadMore(): void {
    if (this.isLoading || !this.hasMoreItems()) {
      return;
    }
    this.visibleCount += PAGE_SIZE;
  }

  private async reload(fromPull: boolean): Promise<void> {
    const requestVersion = ++this.reloadVersion;
    if (fromPull) {
      this.isRefreshing = true;
    } else {
      this.isLoading = true;
    }
    this.errorMessage = '';
    this.visibleCount = PAGE_SIZE;

    if (!UserStore.isLoggedIn()) {
      this.errorMessage = `登录后可查看${getStatsDetailPageTitle(this.currentPeriod, this.currentSection)}`;
      this.timeline = [];
      this.shame = [];
      this.isLoading = false;
      this.isRefreshing = false;
      return;
    }

    if (this.currentSection === 'timeline') {
      const timelineRes = await DuoApiService.getStatsTimeline(this.currentPeriod);
      if (requestVersion !== this.reloadVersion) {
        return;
      }
      if (timelineRes.statusCode !== 200) {
        this.errorMessage = timelineRes.message ?? '履约记录加载失败';
        showErrorToast(this.errorMessage, this.getUIContext());
      }
      const timelineData = DuoApiService.parseTimeline(timelineRes);
      this.timeline = timelineData?.items ?? [];
    } else {
      const shameRes = await DuoApiService.getStatsShame(this.currentPeriod);
      if (requestVersion !== this.reloadVersion) {
        return;
      }
      if (shameRes.statusCode !== 200) {
        this.errorMessage = shameRes.message ?? '违约记录加载失败';
        showErrorToast(this.errorMessage, this.getUIContext());
      }
      const shameData = DuoApiService.parseShame(shameRes);
      this.shame = shameData?.items ?? [];
    }

    this.isLoading = false;
    this.isRefreshing = false;
  }

  private openShameRecord(record: DuoShameRecord, fallbackDate: string): void {
    const data = buildShameCertificateData(record, fallbackDate, UserStore.getUserInfo());
    openShameCertificatePreview(data);
  }

  private openHonorRecord(record: DuoTimelineRecord, fallbackDate: string): void {
    const data = buildHonorCertificateData(record, fallbackDate, UserStore.getUserInfo());
    openHonorCertificatePreview(data);
  }

  @Builder
  private buildStatusBlock(): void {
    if (this.isLoading) {
      Text(`正在加载${getStatsDetailPageTitle(this.currentPeriod, this.currentSection)}...`)
        .fontSize(13)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 16 })
    } else if (this.errorMessage.length > 0) {
      Text(this.errorMessage)
        .fontSize(13)
        .fontColor(AppTheme.colors.danger)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  private buildListFooter(): void {
    if (this.isLoading || this.getAllItems().length === 0) {
      Blank()
    } else if (this.hasMoreItems()) {
      Text('上拉加载更多')
        .fontSize(12)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 8, bottom: 16 })
    } else {
      Text('已加载全部')
        .fontSize(12)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 8, bottom: 16 })
    }
  }

  @Builder
  private buildRecordList(): void {
    if (this.currentSection === 'timeline') {
      HonorRecordListSection({
        items: this.getVisibleHonorItems(),
        onItemPress: (item: HonorRecordItem) => {
          this.openHonorRecord(item.record, item.day);
        }
      })
    } else {
      ShameRecordListSection({
        items: this.getVisibleShameItems(),
        onItemPress: (item: ShameRecordItem) => {
          this.openShameRecord(item.record, item.day);
        }
      })
    }
  }

  @Builder
  private buildPageBody(): void {
    Refresh({ refreshing: $$this.isRefreshing }) {
      List({ space: 12, scroller: this.listScroller }) {
        ListItem() {
          this.buildStatusBlock()
        }

        if (!this.isLoading) {
          ListItem() {
            this.buildRecordList()
          }

          ListItem() {
            this.buildListFooter()
          }
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => {
        this.loadMore();
      })
    }
    .pullToRefresh(true)
    .onRefreshing(() => {
      void this.reload(true);
    })
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: getStatsDetailPageTitle(this.currentPeriod, this.currentSection),
        showBack: true,
        usePageScroll: false,
        bindScrollers: this.scrollerReady ? [this.listScroller] : [],
        horizontalPadding: 14,
        bottomSpacerHeight: 0,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildPageBody();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

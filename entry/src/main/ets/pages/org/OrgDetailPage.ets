import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { showErrorToast, showToast } from '../../common/Toast';
import { UsersIcon } from '../../components/common/UsersIcon';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import {
  ORG_DEFAULT_INTRO,
  ORG_DEFAULT_THEME,
  OrgDetail,
  OrgLive,
  OrgLiveDuo,
  OrgLiveSolo,
  OrgLiveWaiting,
  OrgRank,
  OrgRankItem
} from '../../models/OrgModel';
import { createEmptyUserInfo, UserInfo } from '../../models/UserModel';
import { PageRoutes, backRoute, pushOrgMembers, pushRoute } from '../../router/PageRoutes';
import { formatSuccessDurationLabel, getStatsPeriodLabel, StatsPeriod } from '../../services/StatsRecordUtil';
import { OrgStore } from '../../stores/OrgStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

type OrgTab = 'rank' | 'waiting' | 'duo' | 'solo';

interface OrgTabItem {
  key: OrgTab;
  label: string;
}

interface RankMedalStyle {
  row: string;
  border: string;
  fg: string;
}

const PERIODS: StatsPeriod[] = ['today', 'week', 'month'];
const RANK_LIMIT: number = 10;
const TABS: OrgTabItem[] = [
  { key: 'rank', label: '🌟 排行榜' },
  { key: 'waiting', label: '⌛️ 待加入' },
  { key: 'duo', label: '搭子互督中' },
  { key: 'solo', label: '单人专注中' }
];

@Entry
@Component
struct OrgDetailPage {
  @StorageLink(StoreKeys.UserInfo) userInfo: UserInfo = createEmptyUserInfo();
  @State orgId: string = '';
  @State detail: OrgDetail | null = null;
  @State rank: OrgRank | null = null;
  @State live: OrgLive | null = null;
  @State currentTab: OrgTab = 'rank';
  @State currentPeriod: StatsPeriod = 'today';
  @State pageLoading: boolean = true;
  @State tabLoading: boolean = false;
  @State refreshing: boolean = false;
  @State leaving: boolean = false;
  @State joining: boolean = false;
  @State topSafeInsetVp: number = 0;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }
    this.orgId = String(AppStorage.get<string>(StoreKeys.OrgDetailId) ?? '');
    this.loadTopSafeInset(hostContext);
    void this.loadInitial();
  }

  private loadTopSafeInset(hostContext: common.UIAbilityContext): void {
    const ui = this.getUIContext();
    window.getLastWindow(hostContext, (err, win) => {
      if (err.code) {
        return;
      }
      const systemAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topSafeInsetVp = ui.px2vp(systemAvoid.topRect.height);
    });
  }

  private async loadInitial(): Promise<void> {
    if (this.orgId.length === 0) {
      this.pageLoading = false;
      return;
    }
    // 换组织时清掉上一组织缓存，避免旧信息闪一下
    if (this.detail && this.detail.id !== this.orgId) {
      this.detail = null;
      this.rank = null;
      this.live = null;
    }
    const storeDetail = OrgStore.getDetail();
    if (storeDetail && storeDetail.id !== this.orgId) {
      OrgStore.clearDetail();
    }
    this.pageLoading = true;
    await OrgStore.fetchDetail(this.orgId);
    await OrgStore.fetchRank(this.orgId, 'today');
    await OrgStore.fetchLive(this.orgId);
    this.syncFromStore();
    this.pageLoading = false;
  }

  private syncFromStore(): void {
    this.detail = OrgStore.getDetail();
    this.rank = OrgStore.getRank();
    this.live = OrgStore.getLive();
  }

  private getThemeColor(): string {
    if (this.detail && this.detail.theme_color.length > 0) {
      return this.detail.theme_color;
    }
    return ORG_DEFAULT_THEME;
  }

  private isOwner(): boolean {
    return !!this.detail && this.detail.owner_id === this.userInfo.id;
  }

  private isMember(): boolean {
    if (!this.detail) {
      return false;
    }
    if (this.detail.is_member) {
      return true;
    }
    if (this.detail.role === 'owner' || this.detail.role === 'member') {
      return true;
    }
    return this.detail.owner_id === this.userInfo.id;
  }

  private isMe(userId: string): boolean {
    return userId === this.userInfo.id;
  }

  private getIntroText(): string {
    if (this.detail && this.detail.intro.trim().length > 0) {
      return this.detail.intro.trim();
    }
    return ORG_DEFAULT_INTRO;
  }

  private getRankMedalStyle(rankNo: number): RankMedalStyle | null {
    if (rankNo === 1) {
      return { row: '#FFF9E8', border: '#F0D978', fg: '#9A6E00' };
    }
    if (rankNo === 2) {
      return { row: '#F5F7FA', border: '#C8CED6', fg: '#5C6570' };
    }
    if (rankNo === 3) {
      return { row: '#FFF5EC', border: '#E8C09A', fg: '#8A5528' };
    }
    return null;
  }

  private getTabLabel(item: OrgTabItem): string {
    if (item.key === 'rank') {
      return item.label;
    }
    if (!this.live) {
      return item.label;
    }
    let count = 0;
    if (item.key === 'waiting') {
      count = this.live.waiting.length;
    } else if (item.key === 'duo') {
      count = this.live.duo_active.length;
    } else if (item.key === 'solo') {
      count = this.live.solo_active.length;
    }
    return count > 0 ? `${item.label} ${count}` : item.label;
  }

  private async refreshCurrentTab(): Promise<void> {
    if (this.orgId.length === 0) {
      return;
    }
    this.refreshing = true;
    try {
      if (this.currentTab === 'rank') {
        await OrgStore.fetchRank(this.orgId, this.currentPeriod);
      } else {
        await OrgStore.fetchLive(this.orgId);
      }
      this.syncFromStore();
    } finally {
      this.refreshing = false;
    }
  }

  private async onPeriodChange(next: StatsPeriod): Promise<void> {
    if (next === this.currentPeriod || this.tabLoading || this.orgId.length === 0) {
      return;
    }
    this.currentPeriod = next;
    this.tabLoading = true;
    await OrgStore.fetchRank(this.orgId, next);
    this.syncFromStore();
    this.tabLoading = false;
  }

  private async onTabChange(next: OrgTab): Promise<void> {
    if (next === this.currentTab || this.orgId.length === 0) {
      return;
    }
    this.currentTab = next;
    if (next === 'rank') {
      return;
    }
    this.tabLoading = true;
    await OrgStore.fetchLive(this.orgId);
    this.syncFromStore();
    this.tabLoading = false;
  }

  private onCopyCode(): void {
    if (!this.detail || this.detail.invite_code.length === 0) {
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.detail.invite_code);
      pasteboard.getSystemPasteboard().setData(data);
      showToast('邀请码已复制', this.getUIContext());
    } catch (_e) {
      showErrorToast('复制失败', this.getUIContext());
    }
  }

  private onLeavePress(): void {
    if (!this.isMember() || this.isOwner() || this.leaving || this.orgId.length === 0) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '退出组织',
      message: '确认退出该组织？\n退出后需要重新输入邀请码才能再次加入。',
      primaryButton: {
        value: '退出组织',
        fontColor: AppTheme.colors.danger,
        action: () => {
          void this.performLeave();
        }
      },
      secondaryButton: {
        value: '取消',
        fontColor: '#0A59F7',
        action: () => {}
      }
    });
  }

  private async performLeave(): Promise<void> {
    if (this.leaving) {
      return;
    }
    this.leaving = true;
    const response = await OrgStore.leave(this.orgId);
    this.leaving = false;
    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? '退出失败', this.getUIContext());
      return;
    }
    showToast('已退出组织', this.getUIContext());
    backRoute();
  }

  private async performJoin(): Promise<void> {
    if (this.isMember() || this.joining || this.orgId.length === 0) {
      return;
    }
    this.joining = true;
    const response = await OrgStore.joinById(this.orgId);
    this.joining = false;
    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? '加入失败', this.getUIContext());
      return;
    }
    this.syncFromStore();
    showToast('已加入组织', this.getUIContext());
  }

  @Builder
  private buildHeader(): void {
    Column() {
      Row() {
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([Color.White])
        }
          .width(44)
          .height(44)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            backRoute();
          })

        Row() {
          if (this.detail && this.detail.avatar.length > 0) {
            Image(this.detail.avatar)
              .width(36)
              .height(36)
              .borderRadius(10)
              .objectFit(ImageFit.Cover)
          } else {
            UsersIcon({ iconSize: 20, color: '#FFFFFF' })
          }
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(255,255,255,0.18)')
        .borderRadius(10)
        .margin({ right: 10 })
        .clip(true)

        Text(this.detail ? this.detail.name : '组织')
          .layoutWeight(1)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (!this.isMember()) {
          Button({ type: ButtonType.Normal }) {
            Text(this.joining ? '加入中..' : '加入')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
            .height(28)
            .padding({ left: 12, right: 12 })
            .backgroundColor('#38FFFFFF')
            .borderRadius(16)
            .opacity(this.joining ? 0.6 : 1)
            .enabled(!this.joining)
            .onClick(() => {
              void this.performJoin();
            })
        } else if (this.isOwner()) {
          Button({ type: ButtonType.Normal }) {
            SymbolGlyph($r('sys.symbol.gearshape'))
              .fontSize(16)
              .fontColor([Color.White])
          }
            .width(36)
            .height(36)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              pushRoute(PageRoutes.OrgManage);
            })
        } else {
          Button({ type: ButtonType.Normal }) {
            Text('退出')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
            .height(28)
            .padding({ left: 10, right: 10 })
            .backgroundColor('#33FFFFFF')
            .borderRadius(16)
            .onClick(() => {
              this.onLeavePress();
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 12 }) {
        Text(this.getIntroText())
          .fontSize(14)
          .lineHeight(21)
          .fontColor('rgba(255,255,255,0.78)')
          .maxLines(3)
          .width('100%')

        Row({ space: 10 }) {
          Row({ space: 4 }) {
            Text(`${this.detail ? this.detail.member_count : 0} 位成员`)
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.82)')
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(12)
              .fontColor(['rgba(255,255,255,0.7)'])
          }
          .onClick(() => {
            if (this.orgId.length > 0) {
              pushOrgMembers(this.orgId);
            }
          })

          if (this.detail && this.detail.invite_code.length > 0) {
            Row({ space: 4 }) {
              Text(this.detail.invite_code)
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor('rgba(255,255,255,0.92)')
                .letterSpacing(0.4)
              SymbolGlyph($r('sys.symbol.doc_plaintext'))
                .fontSize(10)
                .fontColor(['rgba(255,255,255,0.85)'])
            }
            .padding({ left: 7, right: 7, top: 3, bottom: 3 })
            .backgroundColor('rgba(255,255,255,0.14)')
            .borderRadius(6)
            .onClick(() => {
              this.onCopyCode();
            })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding({
      left: 8,
      right: 8,
      top: this.topSafeInsetVp,
      bottom: 18
    })
    .backgroundColor(this.getThemeColor())
  }

  @Builder
  private buildTabBar(): void {
    Scroll() {
      Row() {
        ForEach(TABS, (item: OrgTabItem) => {
          Column() {
            Text(this.getTabLabel(item))
              .fontSize(14)
              .fontWeight(this.currentTab === item.key ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.currentTab === item.key ? AppTheme.colors.textPrimary : AppTheme.colors.textMuted)
            if (this.currentTab === item.key) {
              Row()
                .width('70%')
                .height(3)
                .backgroundColor(AppTheme.colors.primary)
                .borderRadius(999)
                .margin({ top: 8 })
            }
          }
          .height(44)
          .padding({ left: 12, right: 12 })
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            void this.onTabChange(item.key);
          })
        }, (item: OrgTabItem) => item.key)
      }
      .alignItems(VerticalAlign.Center)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(44)
    .backgroundColor(AppTheme.colors.background)
    .border({ width: { bottom: 1 }, color: AppTheme.colors.border })
  }

  @Builder
  private buildUserRow(
    key: string,
    avatar: string,
    title: string,
    subtitle: string,
    highlight: boolean
  ): void {
    Row({ space: 12 }) {
      Image(avatar.length > 0 ? avatar : $r('app.media.startIcon'))
        .width(40)
        .height(40)
        .borderRadius(12)
        .objectFit(ImageFit.Cover)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(subtitle)
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(highlight ? `${AppTheme.colors.primary}12` : AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(12)
  }

  @Builder
  private buildRankRow(item: OrgRankItem): void {
    Row({ space: 8 }) {
      if (item.rank <= 3) {
        Text(`${item.rank}`)
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(
            item.rank === 1 ? '#9A6E00' : item.rank === 2 ? '#5C6570' : '#8A5528'
          )
          .backgroundColor(
            item.rank === 1 ? '#F6E7A8' : item.rank === 2 ? '#E6E9EE' : '#F0D5BC'
          )
          .borderRadius(14)
      } else {
        Text(`${item.rank}`)
          .width(28)
          .textAlign(TextAlign.Center)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textMuted)
      }

      Image(item.avatar.length > 0 ? item.avatar : $r('app.media.startIcon'))
        .width(36)
        .height(36)
        .borderRadius(10)
        .objectFit(ImageFit.Cover)

      Text(item.username)
        .layoutWeight(1)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(formatSuccessDurationLabel(item.actual_mins))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getRankMedalStyle(item.rank)?.fg ?? AppTheme.colors.textSecondary)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(
      this.getRankMedalStyle(item.rank)?.row ??
        (this.isMe(item.user_id) ? `${AppTheme.colors.primary}12` : AppTheme.colors.surface)
    )
    .border({
      width: 1,
      color: this.getRankMedalStyle(item.rank)?.border ?? AppTheme.colors.border
    })
    .borderRadius(12)
  }

  @Builder
  private buildRankTab(): void {
    Column({ space: 12 }) {
      Row() {
        Row({ space: 8 }) {
          ForEach(PERIODS, (period: StatsPeriod) => {
            Text(getStatsPeriodLabel(period))
              .fontSize(13)
              .fontWeight(this.currentPeriod === period ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.currentPeriod === period ? AppTheme.colors.primary : AppTheme.colors.textSecondary)
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .backgroundColor(
                this.currentPeriod === period ? `${AppTheme.colors.primary}18` : AppTheme.colors.surface
              )
              .borderRadius(999)
              .onClick(() => {
                void this.onPeriodChange(period);
              })
          }, (period: StatsPeriod) => period)
        }
        .layoutWeight(1)

        if (this.rank && this.rank.my_rank !== null && !this.tabLoading) {
          Text(`我的第 ${this.rank.my_rank} 名`)
            .fontSize(12)
            .fontColor(AppTheme.colors.textMuted)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.tabLoading) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color(AppTheme.colors.primary)
          .margin({ top: 40, bottom: 40 })
      } else if (this.rank && this.rank.items.length > 0) {
        ForEach(this.rank.items.slice(0, RANK_LIMIT), (item: OrgRankItem) => {
          this.buildRankRow(item)
        }, (item: OrgRankItem) => item.user_id)
      } else {
        Text('暂无排行数据')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 40, bottom: 40 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 32 })
  }

  @Builder
  private buildWaitingTab(): void {
    Column({ space: 8 }) {
      if (this.tabLoading) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color(AppTheme.colors.primary)
          .margin({ top: 40, bottom: 40 })
      } else if (this.live && this.live.waiting.length > 0) {
        ForEach(this.live.waiting, (item: OrgLiveWaiting) => {
          this.buildUserRow(
            item.user_id,
            item.avatar,
            `${item.username}${this.isMe(item.user_id) ? '（我）' : ''}`,
            `${item.title.length > 0 ? item.title : '互督邀请'} · 等待搭子加入`,
            this.isMe(item.user_id)
          )
        }, (item: OrgLiveWaiting) => item.user_id)
      } else {
        Text('暂无等待加入的互督')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 40, bottom: 40 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 32 })
  }

  @Builder
  private buildDuoTab(): void {
    Column({ space: 8 }) {
      if (this.tabLoading) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color(AppTheme.colors.primary)
          .margin({ top: 40, bottom: 40 })
      } else if (this.live && this.live.duo_active.length > 0) {
        ForEach(this.live.duo_active, (item: OrgLiveDuo) => {
          this.buildUserRow(
            item.user_id,
            item.avatar,
            `${item.username}${this.isMe(item.user_id) ? '（我）' : ''}`,
            item.peer_username.length > 0
              ? `${item.title.length > 0 ? item.title : '互督'} · 与 ${item.peer_username}`
              : (item.title.length > 0 ? item.title : '搭子互督中'),
            this.isMe(item.user_id)
          )
        }, (item: OrgLiveDuo) => item.user_id)
      } else {
        Text('暂无进行中的互督')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 40, bottom: 40 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 32 })
  }

  @Builder
  private buildSoloTab(): void {
    Column({ space: 8 }) {
      if (this.tabLoading) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color(AppTheme.colors.primary)
          .margin({ top: 40, bottom: 40 })
      } else if (this.live && this.live.solo_active.length > 0) {
        ForEach(this.live.solo_active, (item: OrgLiveSolo) => {
          this.buildUserRow(
            item.user_id,
            item.avatar,
            `${item.username}${this.isMe(item.user_id) ? '（我）' : ''}`,
            item.title.length > 0 ? item.title : '单人专注中',
            this.isMe(item.user_id)
          )
        }, (item: OrgLiveSolo) => item.user_id)
      } else {
        Text('暂无单人专注中的成员')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 40, bottom: 40 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 32 })
  }

  @Builder
  private buildTabBody(): void {
    if (this.currentTab === 'rank') {
      this.buildRankTab()
    } else if (this.currentTab === 'waiting') {
      this.buildWaitingTab()
    } else if (this.currentTab === 'duo') {
      this.buildDuoTab()
    } else {
      this.buildSoloTab()
    }
  }

  @Builder
  private buildPageBody(): void {
    if (this.pageLoading && (!this.detail || this.detail.id !== this.orgId)) {
      Column() {
        LoadingProgress()
          .width(36)
          .height(36)
          .color(AppTheme.colors.primary)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      Column() {
        this.buildHeader()
        this.buildTabBar()
        Refresh({ refreshing: $$this.refreshing }) {
          Scroll() {
            this.buildTabBody()
          }
          .width('100%')
          .scrollBar(BarState.Off)
        }
        .onRefreshing(() => {
          void this.refreshCurrentTab();
        })
        .pullToRefresh(true)
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
    }
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '',
        showBack: false,
        showTitleBar: false,
        usePageScroll: false,
        horizontalPadding: 0,
        topSpacerHeight: 0,
        hiddenTitleTopPadding: 0,
        bottomSpacerHeight: 0,
        content: (): void => {
          this.buildPageBody();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

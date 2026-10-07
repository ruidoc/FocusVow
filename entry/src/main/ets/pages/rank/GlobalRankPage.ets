import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme, isDarkThemeMode } from '../../constants/Theme';
import {
  DUO_AI_PARTNER_ID,
  formatRankMinutes,
  GLOBAL_RANK_MIN_MINS,
  GlobalRankData,
  GlobalRankMode,
  GlobalRankPeriod,
  periodLabel,
  RankMember,
  RankRow,
} from '../../models/GlobalRankModel';
import { backRoute, pushLogin } from '../../router/PageRoutes';
import { GlobalRankService } from '../../services/GlobalRankService';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

const PERIODS: GlobalRankPeriod[] = ['today', 'week', 'month', 'all'];
const RANK_LIMIT: number = 50;

interface RankMedalStyle {
  row: string;
  border: string;
  fg: string;
}

@Entry
@Component
struct GlobalRankPage {
  @State period: GlobalRankPeriod = 'today';
  @State mode: GlobalRankMode = 'solo';
  @State loading: boolean = true;
  @State rows: RankRow[] = [];
  @State myRankText: string = '';
  @State hasMyRank: boolean = false;
  @State myRank: number = 0;
  @State listRows: RankRow[] = [];

  aboutToAppear(): void {
    if (!UserStore.isLoggedIn()) {
      pushLogin();
      return;
    }
    void this.reload();
  }

  private async reload(): Promise<void> {
    this.loading = true;
    const data: GlobalRankData | null = await GlobalRankService.fetch(this.period, this.mode);
    this.loading = false;
    if (!data) {
      this.rows = [];
      this.listRows = [];
      this.myRankText = '';
      this.hasMyRank = false;
      this.myRank = 0;
      return;
    }
    const filtered: RankRow[] = [];
    for (let i = 0; i < data.items.length; i++) {
      if (data.items[i].minutes >= GLOBAL_RANK_MIN_MINS) {
        filtered.push(data.items[i]);
      }
    }
    const capped = filtered.slice(0, RANK_LIMIT);
    this.rows = capped;
    const rest: RankRow[] = [];
    for (let j = 0; j < capped.length; j++) {
      if (capped[j].rank > 3) {
        rest.push(capped[j]);
      }
    }
    this.listRows = rest;
    this.hasMyRank = data.hasMyRank;
    this.myRank = data.myRank;
    if (data.hasMyRank) {
      this.myRankText = '';
    } else if (data.myMinutes > 0 && data.myMinutes < GLOBAL_RANK_MIN_MINS) {
      this.myRankText = '未上榜（满 5 分钟才计入）';
    } else {
      this.myRankText = '未上榜';
    }
  }

  private rowAtRank(rank: number): RankRow | null {
    for (let i = 0; i < this.rows.length; i++) {
      if (this.rows[i].rank === rank) {
        return this.rows[i];
      }
    }
    return null;
  }

  private isMyRow(row: RankRow): boolean {
    const myId = UserStore.getUserInfo().id;
    if (myId.length === 0) {
      return false;
    }
    for (let i = 0; i < row.members.length; i++) {
      if (row.members[i].userId === myId) {
        return true;
      }
    }
    return false;
  }

  private podiumIncludesMe(): boolean {
    const first = this.rowAtRank(1);
    const second = this.rowAtRank(2);
    const third = this.rowAtRank(3);
    if (first !== null && this.isMyRow(first)) {
      return true;
    }
    if (second !== null && this.isMyRow(second)) {
      return true;
    }
    if (third !== null && this.isMyRow(third)) {
      return true;
    }
    return false;
  }

  private getMedalStyle(place: number): RankMedalStyle {
    const isDark = isDarkThemeMode();
    if (place === 1) {
      return isDark
        ? { row: '#1C1A14', border: 'rgba(212,164,74,0.38)', fg: '#E8C56A' }
        : { row: '#FFF9E8', border: '#F0D978', fg: '#9A6E00' };
    }
    if (place === 2) {
      return isDark
        ? { row: '#181B20', border: 'rgba(200,206,214,0.35)', fg: '#B8C0CC' }
        : { row: '#F5F7FA', border: '#C8CED6', fg: '#5C6570' };
    }
    return isDark
      ? { row: '#1F1610', border: 'rgba(232,192,154,0.35)', fg: '#D4A574' }
      : { row: '#FFF5EC', border: '#E8C09A', fg: '#8A5528' };
  }

  private medalEmoji(place: number): string {
    if (place === 1) {
      return '🥇';
    }
    if (place === 2) {
      return '🥈';
    }
    return '🥉';
  }

  private pedestalHeight(place: number): number {
    if (place === 1) {
      return 72;
    }
    if (place === 2) {
      return 52;
    }
    return 42;
  }

  private podiumAvatarSize(place: number): number {
    return place === 1 ? 56 : 46;
  }

  private rowTitle(row: RankRow): string {
    if (row.members.length === 0) {
      return '用户';
    }
    if (!row.isDuo || row.members.length < 2) {
      return row.members[0].username;
    }
    return `${row.members[0].username} × ${row.members[1].username}`;
  }

  private memberShowPro(member: RankMember): boolean {
    return member.isPro && member.userId !== DUO_AI_PARTNER_ID;
  }

  @Builder
  private buildMemberFace(member: RankMember, size: number): void {
    if (member.userId === DUO_AI_PARTNER_ID) {
      Image($r('app.media.ai_bot'))
        .width(Math.round(size * 0.6))
        .height(Math.round(size * 0.6))
        .objectFit(ImageFit.Contain)
    } else if (member.avatar.length > 0) {
      Image(member.avatar)
        .width(size)
        .height(size)
        .objectFit(ImageFit.Cover)
    } else {
      Image($r('app.media.startIcon'))
        .width(size)
        .height(size)
        .objectFit(ImageFit.Cover)
    }
  }

  @Builder
  private buildMemberAvatar(member: RankMember, size: number, highlight: boolean): void {
    Stack({ alignContent: Alignment.TopEnd }) {
      Stack() {
        this.buildMemberFace(member, size)
      }
      .width(size)
      .height(size)
      .borderRadius(size / 2)
      .backgroundColor('#FFFFFF')
      .clip(true)
      .border({
        width: highlight ? 2 : 0,
        color: AppTheme.colors.primary,
      })
      if (this.memberShowPro(member)) {
        Text('Pro')
          .fontSize(Math.max(6, Math.round(size * 0.16)))
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .padding({
            left: Math.max(2, Math.round(size * 0.06)),
            right: Math.max(2, Math.round(size * 0.06)),
            top: 1,
            bottom: 1,
          })
          .borderRadius(4)
          .backgroundColor('#D4A44A')
          .border({ width: 1, color: '#FFFFFF' })
          .margin({ top: -1, right: -1 })
      }
    }
    .width(size)
    .height(size)
  }

  @Builder
  private buildRowAvatar(row: RankRow, size: number, highlight: boolean, compact: boolean): void {
    if (row.isDuo && row.members.length >= 2) {
      Stack({ alignContent: Alignment.Start }) {
        this.buildMemberAvatar(
          row.members[0],
          size,
          highlight && row.members[0].userId === UserStore.getUserInfo().id,
        )
        Stack({ alignContent: Alignment.Start }) {
          this.buildMemberAvatar(
            row.members[1],
            size,
            highlight && row.members[1].userId === UserStore.getUserInfo().id,
          )
        }
        .margin({ left: size - Math.round(size * 0.34) })
      }
      .width(size * 2 - Math.round(size * 0.34))
      .height(size)
      .margin({ bottom: compact ? 0 : 6 })
    } else if (row.members.length > 0) {
      Row() {
        this.buildMemberAvatar(row.members[0], size, highlight)
      }
      .margin({ bottom: compact ? 0 : 6 })
    }
  }

  @Builder
  private buildPodiumSlot(row: RankRow | null, place: number): void {
    if (row === null) {
      Column() {
        Row()
          .width(this.podiumAvatarSize(place) * 2 - Math.round(this.podiumAvatarSize(place) * 0.34))
          .height(this.podiumAvatarSize(place))
          .borderRadius(14)
          .backgroundColor(AppTheme.colors.surface)
          .margin({ bottom: 8 })
        Row()
          .width('88%')
          .height(this.pedestalHeight(place))
          .borderRadius({ topLeft: 10, topRight: 10 })
          .backgroundColor(AppTheme.colors.surface)
      }
      .layoutWeight(1)
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.End)
      .opacity(0.35)
    } else {
      Column() {
        Text(this.medalEmoji(place))
          .fontSize(place === 1 ? 30 : 24)
        Row() {
          this.buildRowAvatar(row, this.podiumAvatarSize(place), this.isMyRow(row), false)
        }
        .margin({ top: 6 })
        Text(this.rowTitle(row))
          .fontSize(place === 1 ? 13 : 11)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ left: 2, right: 2 })
        Text(formatRankMinutes(row.minutes))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getMedalStyle(place).fg)
          .margin({ top: 2, bottom: 8 })
        Row() {
          Text(`${place}`)
            .fontSize(place === 1 ? 22 : 18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getMedalStyle(place).fg)
        }
        .width('88%')
        .height(this.pedestalHeight(place))
        .borderRadius({ topLeft: 10, topRight: 10 })
        .backgroundColor(this.getMedalStyle(place).row)
        .border({
          width: { top: 1, left: 1, right: 1, bottom: 0 },
          color: this.getMedalStyle(place).border,
        })
        .justifyContent(FlexAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.End)
    }
  }

  @Builder
  private buildPodium(): void {
    Row() {
      this.buildPodiumSlot(this.rowAtRank(2), 2)
      this.buildPodiumSlot(this.rowAtRank(1), 1)
      this.buildPodiumSlot(this.rowAtRank(3), 3)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12 })
    .borderRadius(12)
    .alignItems(VerticalAlign.Bottom)
    .backgroundColor(
      this.podiumIncludesMe() ? 'rgba(122, 90, 248, 0.07)' : AppTheme.colors.surface,
    )
    .margin({ bottom: 8 })
  }

  @Builder
  private buildPeriod(item: GlobalRankPeriod): void {
    Row() {
      Text(periodLabel(item))
        .fontSize(13)
        .fontWeight(this.period === item ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.period === item ? '#7A5AF8' : AppTheme.colors.textSecondary)
    }
    .padding({ left: 14, right: 14, top: 7, bottom: 7 })
    .borderRadius(999)
    .backgroundColor(this.period === item ? 'rgba(122, 90, 248, 0.09)' : AppTheme.colors.surface)
    .onClick(() => {
      if (this.period === item) {
        return;
      }
      this.period = item;
      void this.reload();
    })
  }

  @Builder
  private buildMode(item: GlobalRankMode, label: string): void {
    Row() {
      Text(label)
        .fontSize(14)
        .fontWeight(this.mode === item ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.mode === item ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary)
    }
    .layoutWeight(1)
    .height(36)
    .justifyContent(FlexAlign.Center)
    .borderRadius(9)
    .backgroundColor(this.mode === item ? AppTheme.colors.background : Color.Transparent)
    .onClick(() => {
      if (this.mode === item) {
        return;
      }
      this.mode = item;
      void this.reload();
    })
  }

  @Builder
  private buildRow(row: RankRow): void {
    Row({ space: 0 }) {
      Text(`${row.rank}`)
        .width(28)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.text3)
        .textAlign(TextAlign.Center)
      Row() {
        this.buildRowAvatar(row, 36, this.isMyRow(row), true)
      }
      .width(
        row.isDuo && row.members.length >= 2
          ? 36 * 2 - Math.round(36 * 0.34) + 4
          : 40,
      )
      .margin({ left: 4, right: 10 })
      Text(this.rowTitle(row))
        .layoutWeight(1)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(formatRankMinutes(row.minutes))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textSecondary)
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.isMyRow(row) ? 'rgba(122, 90, 248, 0.07)' : AppTheme.colors.surface)
  }

  @Builder
  private buildContent(): void {
    Column({ space: 12 }) {
      Row() {
        this.buildMode('solo', '单人')
        this.buildMode('duo', '搭子')
      }
      .width('100%')
      .padding(3)
      .borderRadius(12)
      .backgroundColor(AppTheme.colors.surface)

      Row() {
        Row({ space: 8 }) {
          ForEach(PERIODS, (item: GlobalRankPeriod) => {
            this.buildPeriod(item)
          }, (item: GlobalRankPeriod) => item)
        }
        .layoutWeight(1)
        if (this.hasMyRank) {
          Text(`我第 ${this.myRank} 名`)
            .fontSize(12)
            .fontColor(AppTheme.colors.text3)
            .margin({ left: 8 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.loading) {
        LoadingProgress().width(32).height(32).color(AppTheme.colors.primary)
      } else if (this.rows.length === 0) {
        Text(this.mode === 'duo' ? '暂无搭子榜数据' : '暂无排行')
          .fontSize(13)
          .fontColor(AppTheme.colors.text3)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 40 })
      } else {
        this.buildPodium()
        Column({ space: 8 }) {
          ForEach(this.listRows, (row: RankRow) => {
            this.buildRow(row)
          }, (row: RankRow) => row.key)
        }
        .width('100%')
        .margin({ top: 8 })
      }

      if (this.myRankText.length > 0) {
        Text(this.myRankText)
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '全站排行榜',
        showBack: true,
        usePageScroll: true,
        onBack: () => {
          backRoute();
        },
        content: (): void => {
          this.buildContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

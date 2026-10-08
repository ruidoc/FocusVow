import {
  checkinQuote,
  fallbackShareCard,
  normalizeCheckinFocusMinutes,
  ShareCardItem,
} from '../../utils/CheckinUtil';
import { checkinPosterHeight } from '../../utils/CertificateTemplate';

@Component
struct CheckinGoldText {
  @Prop value: string = '';
  @Prop fontSize: number = 48;

  build() {
    Text(this.value)
      .fontSize(this.fontSize)
      .lineHeight(this.fontSize)
      .fontWeight(FontWeight.Medium)
      .fontColor('#E8D48A')
      .margin({ right: 3 })
      .translate({ y: 1 })
  }
}

@Component
export struct CheckinPoster {
  @Prop kind: string = 'focus';
  @Prop card: ShareCardItem = fallbackShareCard('focus');
  @Prop focusMinutes: number = 0;
  @Prop taskCount: number = 0;
  @Prop successRate: string = '0%';
  @Prop username: string = '朋友';
  @Prop avatar: string = '';
  @Prop posterWidth: number = 320;
  /** 屏宽 vp，用于高度与 RN min(width-40,380)*1.45 一致；0 则按宽*1.45 */
  @Prop layoutScreenWidthVp: number = 0;
  @Prop snapshotId: string = '';

  private posterHeight(): number {
    if (this.layoutScreenWidthVp > 0) {
      return checkinPosterHeight(this.layoutScreenWidthVp);
    }
    return Math.round(this.posterWidth * 1.45);
  }

  /** 与 RN certificate-scale 基准宽 340 同比缩放 */
  private s(value: number): number {
    return Math.round(value * this.posterWidth / 340);
  }

  private focusMinutesFloored(): number {
    return normalizeCheckinFocusMinutes(this.focusMinutes);
  }

  private focusHoursPart(): number {
    return Math.floor(this.focusMinutesFloored() / 60);
  }

  private focusRemainMinutesPart(): number {
    return this.focusMinutesFloored() % 60;
  }

  private onPhoto(): boolean {
    return this.card.imageUrl.length > 0;
  }

  private ink(): string {
    if (this.onPhoto()) {
      return '#FFFFFF';
    }
    return this.card.dark ? '#FAF8F5' : '#1C1924';
  }

  private muted(): string {
    if (this.onPhoto()) {
      return 'rgba(255, 255, 255, 0.78)';
    }
    return this.card.dark ? 'rgba(250, 248, 245, 0.68)' : 'rgba(28, 25, 36, 0.55)';
  }

  private divider(): string {
    if (this.onPhoto()) {
      return 'rgba(255, 255, 255, 0.28)';
    }
    return this.card.dark ? 'rgba(255, 255, 255, 0.16)' : 'rgba(28, 25, 36, 0.08)';
  }

  private pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private clockText(): string {
    const now = new Date();
    return `${this.pad2(now.getHours())}:${this.pad2(now.getMinutes())}`;
  }

  private dateDay(): string {
    return `${new Date().getDate()}`;
  }

  private dateMonthYear(): string {
    const now = new Date();
    return `${now.getFullYear()} 年 ${now.getMonth() + 1} 月`;
  }

  private quoteText(): string {
    if (this.card.title.length > 0) {
      return this.card.title;
    }
    if (this.kind === 'wake') {
      return checkinQuote('wake');
    }
    if (this.kind === 'sleep') {
      return checkinQuote('sleep');
    }
    return checkinQuote('focus');
  }

  private initial(): string {
    const name = this.username.trim();
    if (name.length === 0) {
      return '友';
    }
    return name.substring(0, 1).toUpperCase();
  }

  @Builder
  private buildUnit(label: string): void {
    Text(label)
      .fontSize(this.s(13))
      .lineHeight(this.s(13))
      .fontWeight(FontWeight.Normal)
      .fontColor('#FFFFFF')
  }

  @Builder
  private buildFocusDurationHero(): void {
    if (this.focusMinutesFloored() < 60) {
      Flex({
        direction: FlexDirection.Row,
        alignItems: ItemAlign.Baseline,
        justifyContent: FlexAlign.Start,
      }) {
        CheckinGoldText({ value: `${this.focusMinutesFloored()}`, fontSize: this.s(48) })
        this.buildUnit('分钟高效专注')
      }
      .alignSelf(ItemAlign.Start)
    } else {
      Flex({
        direction: FlexDirection.Row,
        alignItems: ItemAlign.Baseline,
        justifyContent: FlexAlign.Start,
      }) {
        CheckinGoldText({ value: `${this.focusHoursPart()}`, fontSize: this.s(48) })
        this.buildUnit('小时')
        if (this.focusRemainMinutesPart() > 0) {
          CheckinGoldText({ value: `${this.focusRemainMinutesPart()}`, fontSize: this.s(48) })
          this.buildUnit('分钟')
        }
        this.buildUnit('高效专注')
      }
      .alignSelf(ItemAlign.Start)
    }
  }

  @Builder
  private buildHero(): void {
    if (this.kind === 'wake' || this.kind === 'sleep') {
      Flex({
        direction: FlexDirection.Row,
        alignItems: ItemAlign.Baseline,
        justifyContent: FlexAlign.Start,
      }) {
        CheckinGoldText({ value: this.clockText(), fontSize: this.s(48) })
        this.buildUnit(this.kind === 'wake' ? '早起打卡' : '早睡打卡')
      }
      .alignSelf(ItemAlign.Start)
    } else {
      Column() {
        this.buildFocusDurationHero()

        Flex({
          direction: FlexDirection.Row,
          alignItems: ItemAlign.Baseline,
          justifyContent: FlexAlign.Start,
        }) {
          CheckinGoldText({
            value: `${Math.max(0, Math.floor(this.taskCount))}`,
            fontSize: this.s(24),
          })
          this.buildUnit('个任务')
          CheckinGoldText({ value: this.successRate, fontSize: this.s(24) })
            .margin({ left: this.s(12) })
          this.buildUnit('完成率')
        }
        .alignSelf(ItemAlign.Start)
        .margin({ top: this.s(8), left: this.s(2) })
      }
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private buildHeader(): void {
    Row() {
      Row() {
        if (this.avatar.length > 0) {
          Image(this.avatar)
            .width(32)
            .height(32)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            Text(this.initial())
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.ink())
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.divider())
        }
        Text(this.username)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.ink())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 9 })
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      Column() {
        Text(this.dateDay())
          .fontSize(52)
          .fontWeight(FontWeight.Lighter)
          .fontColor(this.ink())
          .lineHeight(56)
          .letterSpacing(-1)
        Text(this.dateMonthYear())
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.muted())
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.End)
      .margin({ left: 12 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 22, right: 22, top: 28 })
  }

  @Builder
  private buildQuote(): void {
    Column() {
      this.buildHero()
      Text(this.quoteText())
        .fontSize(this.s(26))
        .lineHeight(this.s(40))
        .letterSpacing(0.6)
        .fontFamily('serif')
        .fontWeight(FontWeight.Lighter)
        .fontColor(this.ink())
        .width('100%')
        .padding({ top: this.s(6), bottom: this.s(10) })
        .margin({ top: 22, bottom: this.card.subtitle.length > 0 ? 8 : 4 })

      if (this.card.subtitle.length > 0) {
        Column() {
          Column()
            .width(this.s(32))
            .height(1)
            .backgroundColor(this.divider())
            .margin({ bottom: 14 })
          Text(this.card.subtitle)
            .fontSize(this.s(15))
            .lineHeight(this.s(22))
            .fontFamily('serif')
            .fontColor(this.muted())
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ top: 20, bottom: 4 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 22, right: 22, bottom: 28 })
  }

  @Builder
  private buildFooter(): void {
    Row() {
      Image($r('app.media.startIcon'))
        .width(32)
        .height(32)
        .borderRadius(8)
        .objectFit(ImageFit.Contain)
      Column() {
        Text('专注契约APP')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.card.dark ? '#FFFFFF' : '#0F172A')
        Text('与搭子立约，互督学习自律')
          .fontSize(11)
          .fontColor(this.card.dark ? 'rgba(255,255,255,0.7)' : '#64748B')
          .margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .backgroundColor(this.card.dark ? 'rgba(0,0,0,0.45)' : 'rgba(255,255,255,0.55)')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.card.imageUrl.length > 0) {
        Image(this.card.imageUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else if (this.card.dark) {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 135,
            colors: [['#181E29', 0], ['#0E131B', 1]]
          })
      } else {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 135,
            colors: [['#F7ECE1', 0], ['#E8D5C4', 1]]
          })
      }

      Column() {
        this.buildHeader()
        Blank()
        this.buildQuote()
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 60 })

      this.buildFooter()
    }
    .width(this.posterWidth)
    .height(this.posterHeight())
    .clip(true)
    .id(this.snapshotId)
  }
}

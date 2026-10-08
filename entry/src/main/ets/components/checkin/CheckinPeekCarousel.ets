import { AppTheme } from '../../constants/Theme';
import { CheckinPoster } from '../home/CheckinPoster';
import {
  peekCarouselPageStride,
  peekCarouselPeekMargin,
  peekCarouselScaleAnchorX,
  peekCarouselScaleFor,
  peekCarouselSnapTargetIndex,
  peekCarouselTrackOffset,
  peekCarouselZIndexFor,
} from '../common/PeekCarouselUtil';
import { CheckinKind, fallbackShareCard, ShareCardItem } from '../../utils/CheckinUtil';
import { checkinPosterHeight, peekCarouselCardWidth } from '../../utils/CertificateTemplate';

@Component
struct CheckinCarouselPosterSlot {
  @Prop kind: CheckinKind = 'focus';
  @Prop card: ShareCardItem = fallbackShareCard('focus');
  @Prop focusMinutes: number = 0;
  @Prop taskCount: number = 0;
  @Prop successRate: string = '0%';
  @Prop username: string = '';
  @Prop avatar: string = '';
  @Prop posterWidth: number = 320;
  @Prop layoutScreenWidthVp: number = 390;

  build() {
    CheckinPoster({
      kind: this.kind,
      card: this.card,
      focusMinutes: this.focusMinutes,
      taskCount: this.taskCount,
      successRate: this.successRate,
      username: this.username,
      avatar: this.avatar,
      posterWidth: this.posterWidth,
      layoutScreenWidthVp: this.layoutScreenWidthVp,
      snapshotId: `checkinPoster_${this.card.id}`,
    })
  }
}

@Component
export struct CheckinPeekCarousel {
  @Prop kind: CheckinKind = 'focus';
  @Prop cards: ShareCardItem[] = [];
  @Prop focusMinutes: number = 0;
  @Prop taskCount: number = 0;
  @Prop successRate: string = '0%';
  @Prop username: string = '';
  @Prop avatar: string = '';
  @Link @Watch('onActiveIndexChanged') activeIndex: number;
  @State private viewportWidth: number = 0;
  @State private carouselProgress: number = 0;
  private carouselSnapDuration: number = 320;
  private panStartProgress: number = 0;
  private panEndVelocityX: number = 0;

  aboutToAppear(): void {
    this.carouselProgress = this.activeIndex;
  }

  private onActiveIndexChanged(): void {
    if (Math.abs(this.carouselProgress - this.activeIndex) > 0.001) {
      this.carouselProgress = this.activeIndex;
    }
  }

  private layoutWidth(): number {
    return this.viewportWidth > 0 ? this.viewportWidth : 390;
  }

  private posterCardWidth(): number {
    return peekCarouselCardWidth(this.layoutWidth());
  }

  private carouselHeight(): number {
    return checkinPosterHeight(this.layoutWidth());
  }

  private maxIndex(): number {
    return Math.max(0, this.cards.length - 1);
  }

  private onPanStart(): void {
    this.panStartProgress = this.carouselProgress;
  }

  private onPanUpdate(offsetX: number): void {
    const stride = peekCarouselPageStride(this.layoutWidth());
    if (stride <= 0) {
      return;
    }
    const next = this.panStartProgress - offsetX / stride;
    this.carouselProgress = Math.max(0, Math.min(this.maxIndex(), next));
  }

  private onPanEnd(event?: GestureEvent): void {
    this.panEndVelocityX = event?.velocityX ?? 0;
    const target = peekCarouselSnapTargetIndex(
      this.carouselProgress,
      this.maxIndex(),
      this.panStartProgress,
      this.panEndVelocityX,
    );
    this.panEndVelocityX = 0;
    this.getUIContext().animateTo({
      duration: this.carouselSnapDuration,
      curve: Curve.EaseOut,
    }, () => {
      this.carouselProgress = target;
      this.activeIndex = target;
    });
  }

  @Builder
  private buildPosterSlot(card: ShareCardItem, cardWidth: number): void {
    CheckinCarouselPosterSlot({
      kind: this.kind,
      card: card,
      focusMinutes: this.focusMinutes,
      taskCount: this.taskCount,
      successRate: this.successRate,
      username: this.username,
      avatar: this.avatar,
      posterWidth: cardWidth,
      layoutScreenWidthVp: this.layoutWidth(),
    })
  }

  build() {
    Column() {
      if (this.cards.length <= 1) {
        Row() {
          if (this.cards.length === 1) {
            Column() {
              this.buildPosterSlot(this.cards[0], this.posterCardWidth())
            }
            .width(this.posterCardWidth())
            .height(this.carouselHeight())
          }
        }
        .width('100%')
        .height(this.carouselHeight())
        .justifyContent(FlexAlign.Center)
      } else {
        Stack({ alignContent: Alignment.Start }) {
          Row() {
            ForEach(this.cards, (card: ShareCardItem, index: number) => {
              Row() {
                Column() {
                  this.buildPosterSlot(card, this.posterCardWidth())
                }
                .width(this.posterCardWidth())
                .height(this.carouselHeight())
                .scale({
                  x: peekCarouselScaleFor(index, this.carouselProgress),
                  y: peekCarouselScaleFor(index, this.carouselProgress),
                  centerX: peekCarouselScaleAnchorX(index, this.carouselProgress),
                  centerY: '50%',
                })
                .zIndex(peekCarouselZIndexFor(index, this.carouselProgress))
              }
              .width(peekCarouselPageStride(this.layoutWidth()))
              .height(this.carouselHeight())
              .justifyContent(FlexAlign.Start)
            }, (card: ShareCardItem) => card.id)
          }
          .padding({
            left: peekCarouselPeekMargin(this.layoutWidth()),
            right: peekCarouselPeekMargin(this.layoutWidth()),
          })
          .translate({ x: peekCarouselTrackOffset(this.carouselProgress, this.layoutWidth()) })
        }
        .width('100%')
        .height(this.carouselHeight())
        .clip(false)
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionStart(() => {
              this.onPanStart();
            })
            .onActionUpdate((event: GestureEvent) => {
              this.onPanUpdate(event.offsetX);
            })
            .onActionEnd((event: GestureEvent) => {
              this.onPanEnd(event);
            })
            .onActionCancel((event: GestureEvent) => {
              this.onPanEnd(event);
            }),
        )
      }

      if (this.cards.length > 1) {
        Row({ space: 6 }) {
          ForEach(this.cards, (card: ShareCardItem, index: number) => {
            Column()
              .width(this.activeIndex === index ? 16 : 6)
              .height(6)
              .borderRadius(3)
              .backgroundColor(
                this.activeIndex === index ? AppTheme.colors.textPrimary : AppTheme.colors.text3,
              )
          }, (card: ShareCardItem) => `checkin_peek_dot_${card.id}`)
        }
        .margin({ top: 14 })
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .onAreaChange((_old: Area, area: Area) => {
      const width = Number(area.width);
      if (width > 0 && Math.abs(width - this.viewportWidth) > 1) {
        this.viewportWidth = width;
      }
    })
  }
}

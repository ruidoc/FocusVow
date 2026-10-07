import { CheckinPoster } from '../home/CheckinPoster';
import { AppTheme } from '../../constants/Theme';
import { CheckinKind, ShareCardItem } from '../../utils/CheckinUtil';
import { peekCarouselCardWidth } from '../../utils/CertificateTemplate';
import {
  peekCarouselPageStride,
  peekCarouselPeekMargin,
  peekCarouselScaleAnchorX,
  peekCarouselScaleFor,
  peekCarouselSnapTargetIndex,
  peekCarouselTrackOffset,
  peekCarouselZIndexFor,
} from '../common/PeekCarouselUtil';

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
  @Link viewportWidth: number;

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

  private posterCardWidth(): number {
    const base = this.viewportWidth > 0 ? this.viewportWidth : 320;
    return peekCarouselCardWidth(base);
  }

  private posterHeight(): number {
    return Math.round(this.posterCardWidth() * 1.45);
  }

  private maxIndex(): number {
    return Math.max(0, this.cards.length - 1);
  }

  private onPanStart(): void {
    this.panStartProgress = this.carouselProgress;
  }

  private onPanUpdate(offsetX: number): void {
    const stride = peekCarouselPageStride(this.viewportWidth);
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
  private buildPoster(card: ShareCardItem): void {
    CheckinPoster({
      kind: this.kind,
      card: card,
      focusMinutes: this.focusMinutes,
      taskCount: this.taskCount,
      successRate: this.successRate,
      username: this.username,
      avatar: this.avatar,
      posterWidth: this.posterCardWidth(),
      snapshotId: `checkinPoster_${card.id}`,
    })
  }

  build() {
    Column() {
      if (this.cards.length <= 1) {
        Row() {
          if (this.cards.length === 1) {
            Column() {
              this.buildPoster(this.cards[0])
            }
            .width(this.posterCardWidth())
            .height(this.posterHeight())
          }
        }
        .width('100%')
        .height(this.posterHeight())
        .justifyContent(FlexAlign.Center)
      } else {
        Stack({ alignContent: Alignment.Start }) {
          Row() {
            ForEach(this.cards, (card: ShareCardItem, index: number) => {
              Row() {
                Column() {
                  this.buildPoster(card)
                }
                .width(this.posterCardWidth())
                .height(this.posterHeight())
                .scale({
                  x: peekCarouselScaleFor(index, this.carouselProgress),
                  y: peekCarouselScaleFor(index, this.carouselProgress),
                  centerX: peekCarouselScaleAnchorX(index, this.carouselProgress),
                  centerY: '50%',
                })
                .zIndex(peekCarouselZIndexFor(index, this.carouselProgress))
              }
              .width(peekCarouselPageStride(this.viewportWidth))
              .height(this.posterHeight())
              .justifyContent(FlexAlign.Start)
            }, (card: ShareCardItem) => card.id)
          }
          .padding({
            left: peekCarouselPeekMargin(this.viewportWidth),
            right: peekCarouselPeekMargin(this.viewportWidth),
          })
          .translate({ x: peekCarouselTrackOffset(this.carouselProgress, this.viewportWidth) })
        }
        .width('100%')
        .height(this.posterHeight())
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

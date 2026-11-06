import { AppTheme } from '../../constants/Theme';
import {
  createEmptyHonorCertificateData,
  createEmptyShameCertificateData,
  HonorCertificateData,
  ShameCertificateData,
} from '../../models/CertificateModel';
import { checkinPosterHeight, peekCarouselCardWidth } from '../../utils/CertificateTemplate';
import {
  peekCarouselPageStride,
  peekCarouselPeekMargin,
  peekCarouselScaleAnchorX,
  peekCarouselScaleFor,
  peekCarouselSnapTargetIndex,
  peekCarouselTrackOffset,
  peekCarouselZIndexFor,
} from '../common/PeekCarouselUtil';
import { CertificateCarouselSlot } from '../certificate/CertificatePreviewPeekCarousel';
import { FocusResultPoster } from './FocusResultPoster';
import { FOCUS_RESULT_CERT_SNAPSHOT_ID, FOCUS_RESULT_COVER_SNAPSHOT_ID } from '../../utils/FocusResultUtil';

@Component
export struct FocusResultPeekCarousel {
  @Prop showCertificateSlide: boolean = true;
  @Prop imageUrl: string = '';
  @Prop backgroundId: string = 'warm';
  @Prop colorMode: 'light' | 'dark' = 'light';
  @Prop username: string = '';
  @Prop avatar: string = '';
  @Prop endedAt: number = 0;
  @Prop minutes: number = 0;
  @Prop coverLine: string = '';
  @Prop tags: string = '';
  @Prop kind: string = 'honor';
  @Prop honorData: HonorCertificateData = createEmptyHonorCertificateData();
  @Prop shameData: ShameCertificateData = createEmptyShameCertificateData();
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

  private layoutWidth(): number {
    return this.viewportWidth > 0 ? this.viewportWidth : 390;
  }

  private cardWidth(): number {
    return peekCarouselCardWidth(this.layoutWidth());
  }

  private carouselHeight(): number {
    return checkinPosterHeight(this.layoutWidth());
  }

  private slideCount(): number {
    return this.showCertificateSlide ? 2 : 1;
  }

  private maxIndex(): number {
    return Math.max(0, this.slideCount() - 1);
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
  private buildSlide(index: number): void {
    if (index === 0) {
      FocusResultPoster({
        imageUrl: this.imageUrl,
        backgroundId: this.backgroundId,
        colorMode: this.colorMode,
        username: this.username,
        avatar: this.avatar,
        endedAt: this.endedAt,
        minutes: this.minutes,
        coverLine: this.coverLine,
        tags: this.tags,
        posterWidth: this.cardWidth(),
        layoutScreenWidthVp: this.layoutWidth(),
        snapshotId: FOCUS_RESULT_COVER_SNAPSHOT_ID,
      })
    } else {
      CertificateCarouselSlot({
        kind: this.kind,
        honorData: this.honorData,
        shameData: this.shameData,
        templateStyle: 'classic',
        snapshotId: FOCUS_RESULT_CERT_SNAPSHOT_ID,
      })
    }
  }

  build() {
    Column() {
      if (!this.showCertificateSlide) {
        FocusResultPoster({
          imageUrl: this.imageUrl,
          backgroundId: this.backgroundId,
          colorMode: this.colorMode,
          username: this.username,
          avatar: this.avatar,
          endedAt: this.endedAt,
          minutes: this.minutes,
          coverLine: this.coverLine,
          tags: this.tags,
          posterWidth: this.cardWidth(),
          layoutScreenWidthVp: this.layoutWidth(),
          snapshotId: FOCUS_RESULT_COVER_SNAPSHOT_ID,
        })
      } else {
        Column() {
          Stack({ alignContent: Alignment.Start }) {
            Row() {
              ForEach([0, 1], (index: number) => {
                if (index === 1 && !this.showCertificateSlide) {
                  Blank()
                } else {
                  Row() {
                    Column() {
                      this.buildSlide(index)
                    }
                    .width(this.cardWidth())
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
                }
              }, (index: number) => `focus_result_slide_${index}`)
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

          if (this.slideCount() > 1) {
            Row({ space: 6 }) {
              ForEach([0, 1], (index: number) => {
                Column()
                  .width(this.activeIndex === index ? 16 : 6)
                  .height(6)
                  .borderRadius(3)
                  .backgroundColor(
                    this.activeIndex === index ? AppTheme.colors.textPrimary : AppTheme.colors.text3,
                  )
              }, (index: number) => `focus_result_dot_${index}`)
            }
            .margin({ top: 14 })
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
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

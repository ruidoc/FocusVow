import { AppTheme } from '../../constants/Theme';
import {
  createEmptyHonorCertificateData,
  createEmptyShameCertificateData,
  HonorCertificateData,
  isDuoHonorCertificate,
  ShameCertificateData,
} from '../../models/CertificateModel';
import { CERTIFICATE_SNAPSHOT_ID } from '../../services/CertificateImageService';
import { CERTIFICATE_TEMPLATES, peekCarouselCardWidth } from '../../utils/CertificateTemplate';
import {
  peekCarouselPageStride,
  peekCarouselPeekMargin,
  peekCarouselScaleAnchorX,
  peekCarouselScaleFor,
  peekCarouselSnapTargetIndex,
  peekCarouselTrackOffset,
  peekCarouselZIndexFor,
} from '../common/PeekCarouselUtil';
import { DuoHonorCertificateCard } from './DuoHonorCertificateCard';
import { HonorCertificateCard } from './HonorCertificateCard';
import { ShameCertificateCard } from './ShameCertificateCard';
import { TraitorShameCertificateCard } from './TraitorShameCertificateCard';
import { VictimShameCertificateCard } from './VictimShameCertificateCard';

@Component
struct CertificateCarouselSlot {
  @Prop kind: string = 'honor';
  @Prop honorData: HonorCertificateData = createEmptyHonorCertificateData();
  @Prop shameData: ShameCertificateData = createEmptyShameCertificateData();
  @Prop templateStyle: string = CERTIFICATE_TEMPLATES[0];
  @Prop snapshotId: string = '';

  build() {
    if (this.kind === 'shame') {
      if (this.shameData.shameVariant === 'victim') {
        VictimShameCertificateCard({
          data: this.shameData,
          templateStyle: this.templateStyle,
          snapshotId: this.snapshotId,
        })
      } else if (this.shameData.shameVariant === 'violator') {
        TraitorShameCertificateCard({
          data: this.shameData,
          templateStyle: this.templateStyle,
          snapshotId: this.snapshotId,
        })
      } else {
        ShameCertificateCard({
          data: this.shameData,
          templateStyle: this.templateStyle,
          snapshotId: this.snapshotId,
        })
      }
    } else if (isDuoHonorCertificate(this.honorData)) {
      DuoHonorCertificateCard({
        data: this.honorData,
        templateStyle: this.templateStyle,
        snapshotId: this.snapshotId,
      })
    } else {
      HonorCertificateCard({
        data: this.honorData,
        templateStyle: this.templateStyle,
        snapshotId: this.snapshotId,
      })
    }
  }
}

@Component
export struct CertificatePreviewPeekCarousel {
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

  private posterHeight(): number {
    return Math.round(this.cardWidth() * 1448 / 1086);
  }

  private snapshotIdFor(style: string): string {
    return `${CERTIFICATE_SNAPSHOT_ID}_${style}`;
  }

  private maxIndex(): number {
    return Math.max(0, CERTIFICATE_TEMPLATES.length - 1);
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
  private buildCertificateSlot(style: string): void {
    CertificateCarouselSlot({
      kind: this.kind,
      honorData: this.honorData,
      shameData: this.shameData,
      templateStyle: style,
      snapshotId: this.snapshotIdFor(style),
    })
  }

  build() {
    Column() {
      if (CERTIFICATE_TEMPLATES.length <= 1) {
        Row() {
          if (CERTIFICATE_TEMPLATES.length === 1) {
            Column() {
              this.buildCertificateSlot(CERTIFICATE_TEMPLATES[0])
            }
            .width(this.cardWidth())
            .height(this.posterHeight())
          }
        }
        .width('100%')
        .height(this.posterHeight())
        .justifyContent(FlexAlign.Center)
      } else {
        Stack({ alignContent: Alignment.Start }) {
          Row() {
            ForEach(CERTIFICATE_TEMPLATES, (style: string, index: number) => {
              Row() {
                Column() {
                  this.buildCertificateSlot(style)
                }
                .width(this.cardWidth())
                .height(this.posterHeight())
                .scale({
                  x: peekCarouselScaleFor(index, this.carouselProgress),
                  y: peekCarouselScaleFor(index, this.carouselProgress),
                  centerX: peekCarouselScaleAnchorX(index, this.carouselProgress),
                  centerY: '50%',
                })
                .zIndex(peekCarouselZIndexFor(index, this.carouselProgress))
              }
              .width(peekCarouselPageStride(this.layoutWidth()))
              .height(this.posterHeight())
              .justifyContent(FlexAlign.Start)
            }, (style: string) => style)
          }
          .padding({
            left: peekCarouselPeekMargin(this.layoutWidth()),
            right: peekCarouselPeekMargin(this.layoutWidth()),
          })
          .translate({ x: peekCarouselTrackOffset(this.carouselProgress, this.layoutWidth()) })
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

      if (CERTIFICATE_TEMPLATES.length > 1) {
        Row({ space: 6 }) {
          ForEach(CERTIFICATE_TEMPLATES, (style: string, index: number) => {
            Column()
              .width(this.activeIndex === index ? 16 : 6)
              .height(6)
              .borderRadius(3)
              .backgroundColor(
                this.activeIndex === index ? AppTheme.colors.textPrimary : AppTheme.colors.text3,
              )
          }, (style: string) => `cert_peek_dot_${style}`)
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

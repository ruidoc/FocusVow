import { AppTheme } from '../../constants/Theme';

const RING_SIZE = 300;
const RING_CENTER = RING_SIZE / 2;
const RING_RADIUS = 136;
const RING_STROKE = 28;
const GRADIENT_START = '#2575FC';
const GRADIENT_END = '#6A11CB';
const TRACK_COLOR = '#E8E6F2';
const MIN_ARC_RATIO = 10 / (2 * Math.PI * RING_RADIUS);

@Component
export struct FocusTimeRing {
  @Prop remainingLabel: string = '00:00';
  @Prop elapsedMinutes: number = 0;
  @Prop @Watch('onRingDataChange') progressValue: number = 0;
  @Prop isDuo: boolean = false;
  @Prop useCompactTime: boolean = false;
  @Prop isCountup: boolean = false;
  /** 正计时最短时长（分钟），用于副文案 */
  @Prop minDurationMinutes: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private canvasReady: boolean = false;

  onRingDataChange(): void {
    if (this.canvasReady) {
      this.drawRing();
    }
  }

  private getSweepRatio(): number {
    const ratio = this.progressValue / 100;
    if (ratio <= 0) {
      return MIN_ARC_RATIO;
    }
    return Math.min(ratio, 1);
  }

  private drawRing(): void {
    const ctx = this.context;
    ctx.clearRect(0, 0, RING_SIZE, RING_SIZE);

    ctx.beginPath();
    ctx.arc(RING_CENTER, RING_CENTER, RING_RADIUS, 0, Math.PI * 2);
    ctx.lineWidth = RING_STROKE;
    ctx.strokeStyle = TRACK_COLOR;
    ctx.lineCap = 'round';
    ctx.stroke();

    const sweepRatio = this.getSweepRatio();
    const gradient = ctx.createLinearGradient(RING_CENTER, 0, RING_CENTER, RING_SIZE);
    gradient.addColorStop(0, GRADIENT_START);
    gradient.addColorStop(1, GRADIENT_END);

    ctx.beginPath();
    ctx.lineWidth = RING_STROKE;
    ctx.strokeStyle = gradient;
    ctx.lineCap = 'round';

    if (sweepRatio >= 1) {
      ctx.arc(RING_CENTER, RING_CENTER, RING_RADIUS, 0, Math.PI * 2);
    } else {
      const startAngle = -Math.PI / 2;
      const endAngle = startAngle + sweepRatio * Math.PI * 2;
      ctx.arc(RING_CENTER, RING_CENTER, RING_RADIUS, startAngle, endAngle);
    }

    ctx.stroke();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Canvas(this.context)
        .width(RING_SIZE)
        .height(RING_SIZE)
        .onReady(() => {
          this.canvasReady = true;
          this.drawRing();
        })

      Column({ space: 12 }) {
        Text(this.isCountup ? '已专注时间' : '剩余时间 (分钟)')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textSecondary)

        Text(this.remainingLabel)
          .fontSize(this.useCompactTime ? 48 : 64)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .letterSpacing(-1)

        Row({ space: 5 }) {
          SymbolGlyph(this.isDuo ? $r('sys.symbol.person_fill') : $r('sys.symbol.clock'))
            .fontSize(15)
            .fontColor(['#7A5AF8'])

          Text(
            this.isCountup
              ? (this.isDuo
                ? `共同最短 ${this.minDurationMinutes} 分钟`
                : `最短 ${this.minDurationMinutes} 分钟`)
              : (this.isDuo ? `已共同专注 ${this.elapsedMinutes} 分钟` : `已专注 ${this.elapsedMinutes} 分钟`)
          )
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#858699')
        }
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor('rgba(133, 134, 153, 0.1)')
        .borderRadius(12)
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width(RING_SIZE)
    .height(RING_SIZE)
  }
}

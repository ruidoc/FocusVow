import { StoreKeys } from '../../stores/StoreKeys';

interface DecorationStar {
  leftPct: number;
  topPct: number;
  opacity: number;
  scale: number;
}

/** 固定星点位置，对齐 RN decoration 随机分布观感（避免重绘抖动） */
const DECORATION_STARS: DecorationStar[] = [
  { leftPct: 8, topPct: 12, opacity: 0.18, scale: 0.7 },
  { leftPct: 15, topPct: 34, opacity: 0.32, scale: 1.1 },
  { leftPct: 22, topPct: 6, opacity: 0.24, scale: 0.9 },
  { leftPct: 31, topPct: 48, opacity: 0.14, scale: 0.6 },
  { leftPct: 38, topPct: 18, opacity: 0.41, scale: 1.2 },
  { leftPct: 44, topPct: 72, opacity: 0.22, scale: 0.8 },
  { leftPct: 52, topPct: 28, opacity: 0.35, scale: 1.0 },
  { leftPct: 58, topPct: 8, opacity: 0.16, scale: 0.65 },
  { leftPct: 63, topPct: 56, opacity: 0.28, scale: 0.95 },
  { leftPct: 69, topPct: 38, opacity: 0.12, scale: 0.55 },
  { leftPct: 74, topPct: 14, opacity: 0.38, scale: 1.15 },
  { leftPct: 79, topPct: 64, opacity: 0.2, scale: 0.75 },
  { leftPct: 84, topPct: 42, opacity: 0.3, scale: 1.05 },
  { leftPct: 88, topPct: 22, opacity: 0.17, scale: 0.68 },
  { leftPct: 92, topPct: 78, opacity: 0.26, scale: 0.88 },
  { leftPct: 11, topPct: 58, opacity: 0.21, scale: 0.82 },
  { leftPct: 19, topPct: 82, opacity: 0.33, scale: 1.08 },
  { leftPct: 27, topPct: 26, opacity: 0.15, scale: 0.58 },
  { leftPct: 35, topPct: 88, opacity: 0.27, scale: 0.92 },
  { leftPct: 41, topPct: 62, opacity: 0.19, scale: 0.72 },
  { leftPct: 47, topPct: 4, opacity: 0.36, scale: 1.18 },
  { leftPct: 54, topPct: 46, opacity: 0.13, scale: 0.52 },
  { leftPct: 61, topPct: 24, opacity: 0.29, scale: 0.98 },
  { leftPct: 66, topPct: 70, opacity: 0.23, scale: 0.84 },
  { leftPct: 72, topPct: 52, opacity: 0.31, scale: 1.02 },
  { leftPct: 77, topPct: 30, opacity: 0.16, scale: 0.62 },
  { leftPct: 83, topPct: 10, opacity: 0.4, scale: 1.25 },
  { leftPct: 89, topPct: 54, opacity: 0.18, scale: 0.7 },
  { leftPct: 94, topPct: 36, opacity: 0.25, scale: 0.86 },
  { leftPct: 6, topPct: 44, opacity: 0.34, scale: 1.12 },
];

@Component
export struct PageBackgroundDecoration {
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';

  private isDark(): boolean {
    return this.themeMode === 'dark';
  }

  @Builder
  private buildStars(): void {
    Stack() {
      ForEach(DECORATION_STARS, (star: DecorationStar) => {
        Circle()
          .width(2 * star.scale)
          .height(2 * star.scale)
          .fill('#FFFFFF')
          .opacity(star.opacity)
          .position({ x: `${star.leftPct}%`, y: `${star.topPct}%` })
      }, (star: DecorationStar) => `${star.leftPct}-${star.topPct}`)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (!this.isDark()) {
        Image($r('app.media.bg_light'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#0D0D12')

        Image($r('app.media.background_gradient'))
          .width('150%')
          .height('120%')
          .objectFit(ImageFit.Cover)
          .opacity(0.4)
          .position({ x: -120, y: -200 })

        this.buildStars()
      }
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}

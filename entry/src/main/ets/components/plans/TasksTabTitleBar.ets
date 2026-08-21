import { AppTheme } from '../../constants/Theme';

const TITLE_SIZE_VP: number = 20;
const TITLE_LINE_VP: number = 26;
const TAB_GAP_VP: number = 14;
const INDICATOR_GAP_VP: number = 4;
const INDICATOR_HEIGHT_VP: number = 3;
const INDICATOR_WIDTH_RATIO: number = 0.6;

interface TabMeasure {
  x: number;
  width: number;
}

@Component
export struct TasksTabTitleBar {
  @Prop progress: number = 0;
  onTabPress?: (index: number) => void;

  @State private tabMeasures: TabMeasure[] = [
    { x: 0, width: 0 },
    { x: 0, width: 0 }
  ];

  private clampProgress(): number {
    return Math.max(0, Math.min(1, this.progress));
  }

  private getTabActiveFactor(index: number): number {
    const distance = Math.abs(this.progress - index);
    return Math.max(0, 1 - Math.min(distance, 1));
  }

  private getIndicatorLeft(): number {
    const m0 = this.tabMeasures[0];
    const m1 = this.tabMeasures[1];
    if (m0.width <= 0 || m1.width <= 0) {
      return 0;
    }
    const t = this.clampProgress();
    const fullLeft = m0.x + (m1.x - m0.x) * t;
    const fullWidth = m0.width + (m1.width - m0.width) * t;
    const indicatorWidth = fullWidth * INDICATOR_WIDTH_RATIO;
    return fullLeft + (fullWidth - indicatorWidth) / 2;
  }

  private getIndicatorWidth(): number {
    const m0 = this.tabMeasures[0];
    const m1 = this.tabMeasures[1];
    if (m0.width <= 0 || m1.width <= 0) {
      return 0;
    }
    const t = this.clampProgress();
    const fullWidth = m0.width + (m1.width - m0.width) * t;
    return fullWidth * INDICATOR_WIDTH_RATIO;
  }

  private updateTabMeasure(index: number, area: Area): void {
    const x = Number(area.position.x);
    const width = Number(area.width);
    if (width <= 0) {
      return;
    }
    const next: TabMeasure[] = [
      this.tabMeasures[0],
      this.tabMeasures[1]
    ];
    next[index] = { x: x, width: width };
    this.tabMeasures = next;
  }

  @Builder
  private buildTabTitle(label: string, index: number): void {
    Text(label)
      .fontSize(TITLE_SIZE_VP)
      .lineHeight(TITLE_LINE_VP)
      .fontWeight(this.getTabActiveFactor(index) >= 0.5 ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(AppTheme.colors.textPrimary)
      .opacity(0.38 + this.getTabActiveFactor(index) * 0.62)
      .maxLines(1)
      .onAreaChange((_old: Area, area: Area) => {
        this.updateTabMeasure(index, area);
      })
      .onClick(() => {
        this.onTabPress?.(index);
      })
  }

  build() {
    Column() {
      Row({ space: TAB_GAP_VP }) {
        this.buildTabTitle('快捷任务', 0)
        this.buildTabTitle('定时任务', 1)
      }
      .alignItems(VerticalAlign.Bottom)
      .height(TITLE_LINE_VP)

      if (this.getIndicatorWidth() > 0) {
        Row()
          .width(this.getIndicatorWidth())
          .height(INDICATOR_HEIGHT_VP)
          .borderRadius(999)
          .backgroundColor(AppTheme.colors.primary)
          .margin({
            left: this.getIndicatorLeft(),
            top: INDICATOR_GAP_VP
          })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .height(TITLE_LINE_VP + INDICATOR_GAP_VP + INDICATOR_HEIGHT_VP)
  }
}

import { AppTheme } from '../../constants/Theme';

export interface ContractFulfillment {
  solo_completed_count: number;
  solo_failed_count: number;
  duo_completed_count: number;
  duo_violator_count: number;
  duo_cohort_count: number;
}

interface FulfillmentSegment {
  key: string;
  value: number;
  color: ResourceColor;
  fullLabel: string;
  group: string;
}

const RING_STROKE: number = 20;

@Component
export struct ContractFulfillmentChart {
  @Prop @Watch('onDataChange') data: ContractFulfillment = {
    solo_completed_count: 0,
    solo_failed_count: 0,
    duo_completed_count: 0,
    duo_violator_count: 0,
    duo_cohort_count: 0
  };
  @Prop title: string = '契约履约分布';

  @State private segments: FulfillmentSegment[] = [];
  @State private total: number = 0;
  @State private successRate: number = 0;
  @State private panelValues: number[] = [1];
  @State private panelColors: ResourceColor[] = ['#F1F2F6'];

  aboutToAppear(): void {
    this.refreshDerived();
  }

  onDataChange(): void {
    this.refreshDerived();
  }

  private refreshDerived(): void {
    const next: FulfillmentSegment[] = [
      {
        key: 'solo-completed',
        value: this.data.solo_completed_count,
        color: AppTheme.colors.primary,
        fullLabel: '单人履约',
        group: 'solo'
      },
      {
        key: 'solo-failed',
        value: this.data.solo_failed_count,
        color: '#F59E0B',
        fullLabel: '单人违约',
        group: 'solo'
      },
      {
        key: 'duo-completed',
        value: this.data.duo_completed_count,
        color: '#8B5CF6',
        fullLabel: '互督履约',
        group: 'duo'
      },
      {
        key: 'duo-violator',
        value: this.data.duo_violator_count,
        color: '#EF4444',
        fullLabel: '互督我违约',
        group: 'duo'
      },
      {
        key: 'duo-cohort',
        value: this.data.duo_cohort_count,
        color: '#3B82F6',
        fullLabel: '互督被连累',
        group: 'duo'
      }
    ];
    let sum = 0;
    for (let i = 0; i < next.length; i++) {
      sum += next[i].value;
    }
    this.segments = next;
    this.total = sum;
    this.successRate =
      sum <= 0
        ? 0
        : Math.round(
          ((this.data.solo_completed_count + this.data.duo_completed_count) / sum) * 100
        );

    if (sum <= 0) {
      this.panelValues = [1];
      this.panelColors = ['#F1F2F6'];
      return;
    }
    const values: number[] = [];
    const colors: ResourceColor[] = [];
    for (let i = 0; i < next.length; i++) {
      if (next[i].value > 0) {
        values.push(next[i].value);
        colors.push(next[i].color);
      }
    }
    this.panelValues = values.length > 0 ? values : [1];
    this.panelColors = colors.length > 0 ? colors : ['#F1F2F6'];
  }

  private shouldShowDivider(index: number): boolean {
    if (index <= 0 || index >= this.segments.length) {
      return false;
    }
    return this.segments[index - 1].group === 'solo' && this.segments[index].group === 'duo';
  }

  @Builder
  private buildLegendRow(seg: FulfillmentSegment, index: number): void {
    Column({ space: 0 }) {
      if (this.shouldShowDivider(index)) {
        Divider()
          .color('#F1F2F6')
          .strokeWidth(1)
          .margin({ bottom: 8 })
      }
      Row() {
        Blank()
          .width(12)
          .height(12)
          .borderRadius(6)
          .backgroundColor(seg.color)
          .margin({ right: 8 })
        Text(seg.fullLabel)
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${seg.value}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
        Text(' 次')
          .fontSize(11)
          .fontColor(AppTheme.colors.textMuted)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 10 })
    }
    .width('100%')
  }

  build() {
    Column({ space: 16 }) {
      Text(this.title)
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      if (this.total === 0) {
        Column({ space: 12 }) {
          Stack({ alignContent: Alignment.Center }) {
            DataPanel({
              values: this.panelValues,
              max: 1,
              type: DataPanelType.Circle
            })
              .width('100%')
              .aspectRatio(1)
              .strokeWidth(RING_STROKE)
              .trackBackgroundColor('#F1F2F6')
              .valueColors(this.panelColors)
              .closeEffect(true)
              .trackShadow(null)
          }
          .width('55%')
          .aspectRatio(1)

          Text('还没有契约记录，先发起一局试试')
            .fontSize(13)
            .fontColor(AppTheme.colors.textMuted)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .alignItems(HorizontalAlign.Center)
      } else {
        Row({ space: 8 }) {
          Stack({ alignContent: Alignment.Center }) {
            DataPanel({
              values: this.panelValues,
              max: this.total,
              type: DataPanelType.Circle
            })
              .width('100%')
              .aspectRatio(1)
              .strokeWidth(RING_STROKE)
              .trackBackgroundColor('#F1F2F6')
              .valueColors(this.panelColors)
              .closeEffect(true)
              .trackShadow(null)

            Column({ space: 2 }) {
              Text(`${this.successRate}%`)
                .fontSize(22)
                .fontWeight(FontWeight.Normal)
                .fontColor(AppTheme.colors.textPrimary)
              Text('守约率')
                .fontSize(12)
                .fontColor(AppTheme.colors.textMuted)
            }
            .alignItems(HorizontalAlign.Center)
          }
          .layoutWeight(11)
          .aspectRatio(1)

          Column() {
            ForEach(this.segments, (seg: FulfillmentSegment, index: number) => {
              this.buildLegendRow(seg, index)
            }, (seg: FulfillmentSegment) => seg.key)
          }
          .layoutWeight(9)
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
    .alignItems(HorizontalAlign.Start)
  }
}

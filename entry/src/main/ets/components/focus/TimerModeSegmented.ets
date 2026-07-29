import {
  ItemRestriction,
  SegmentButton,
  SegmentButtonOptions,
  SegmentButtonTextItem
} from '@kit.ArkUI';
import { TimerMode } from '../../utils/TimerMode';

/** 倒计时 / 正计时：系统原生 SegmentButton（页签样式） */
@Component
export struct TimerModeSegmented {
  @Prop @Watch('syncIndexesFromValue') value: TimerMode = 'countdown';
  onChange?: (mode: TimerMode) => void;
  @State selectedIndexes: number[] = [0];
  // SegmentButton.options 是 @ObjectLink，必须用 @State 持有
  @State options: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '倒计时' }, { text: '正计时' }] as ItemRestriction<SegmentButtonTextItem>,
    fontSize: 14,
    selectedFontSize: 14,
    // 默认上下 padding 仅 4，略增高以贴近 RN 40 高度
    buttonPadding: { top: 10, right: 8, bottom: 10, left: 8 }
  });

  aboutToAppear(): void {
    this.syncIndexesFromValue();
  }

  private syncIndexesFromValue(): void {
    const next = this.value === 'countup' ? 1 : 0;
    if (this.selectedIndexes.length === 1 && this.selectedIndexes[0] === next) {
      return;
    }
    this.selectedIndexes = [next];
  }

  build() {
    // SegmentButton 占满可用宽度；外层限宽，避免拉满整行
    Column() {
      SegmentButton({
        options: this.options,
        selectedIndexes: $selectedIndexes,
        onItemClicked: (index: number) => {
          this.onChange?.(index === 1 ? 'countup' : 'countdown');
        }
      })
    }
    .width(220)
  }
}

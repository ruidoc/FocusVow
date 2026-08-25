import {
  ItemRestriction,
  SegmentButton,
  SegmentButtonOptions,
  SegmentButtonTextItem
} from '@kit.ArkUI';
import { AppTheme } from '../../constants/Theme';
import { StoreKeys } from '../../stores/StoreKeys';
import { TimerMode } from '../../utils/TimerMode';

/** 倒计时 / 正计时：系统原生 SegmentButton（页签样式） */
@Component
export struct TimerModeSegmented {
  @Prop @Watch('syncIndexesFromValue') value: TimerMode = 'countdown';
  onChange?: (mode: TimerMode) => void;
  @StorageLink(StoreKeys.ThemeMode) @Watch('onThemeModeChanged') themeMode: string = 'light';
  @State selectedIndexes: number[] = [0];
  @State options: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '倒计时' }, { text: '正计时' }] as ItemRestriction<SegmentButtonTextItem>,
    fontSize: 14,
    selectedFontSize: 14,
    buttonPadding: { top: 10, right: 8, bottom: 10, left: 8 }
  });

  aboutToAppear(): void {
    this.syncIndexesFromValue();
    this.rebuildOptions();
  }

  private onThemeModeChanged(): void {
    this.rebuildOptions();
  }

  private rebuildOptions(): void {
    const isDark = this.themeMode === 'dark';
    this.options = SegmentButtonOptions.tab({
      buttons: [{ text: '倒计时' }, { text: '正计时' }] as ItemRestriction<SegmentButtonTextItem>,
      fontSize: 14,
      selectedFontSize: 14,
      fontColor: AppTheme.colors.textSecondary,
      selectedFontColor: isDark ? AppTheme.colors.textPrimary : '#0F172A',
      backgroundColor: AppTheme.colors.surfaceSecondary,
      selectedBackgroundColor: isDark ? AppTheme.colors.surfaceRaised : '#FFFFFF',
      buttonPadding: { top: 10, right: 8, bottom: 10, left: 8 }
    });
  }

  private syncIndexesFromValue(): void {
    const next = this.value === 'countup' ? 1 : 0;
    if (this.selectedIndexes.length === 1 && this.selectedIndexes[0] === next) {
      return;
    }
    this.selectedIndexes = [next];
  }

  build() {
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

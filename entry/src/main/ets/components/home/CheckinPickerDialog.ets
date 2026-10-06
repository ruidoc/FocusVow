import { AppTheme } from '../../constants/Theme';
import { parseCheckinByDay } from '../../models/StatsChartModel';
import { HttpService } from '../../services/HttpService';
import { isSleepCheckinOpen, isWakeCheckinOpen, sleepWindowLabel, wakeWindowLabel } from '../../utils/CheckinUtil';

@CustomDialog
export struct CheckinPickerDialog {
  controller: CustomDialogController;
  onSelect: (kind: string) => void = (kind: string): void => {
    void kind;
  };
  @State streakDays: number = 0;

  aboutToAppear(): void {
    void this.loadStreak();
  }

  private async loadStreak(): Promise<void> {
    const response = await HttpService.getWithQuery('/checkins/stats/by-day', { 'period': 'today' }, true);
    if (response.statusCode !== 200) {
      return;
    }
    const parsed = parseCheckinByDay(response.data);
    this.streakDays = parsed?.streakDays ?? 0;
  }

  private choose(kind: string, enabled: boolean): void {
    if (!enabled) {
      return;
    }
    this.controller.close();
    this.onSelect(kind);
  }

  @Builder
  private buildOption(kind: string, title: string, subtitle: string, enabled: boolean, symbol: Resource): void {
    Row() {
      Row() {
        SymbolGlyph(symbol)
          .fontSize(22)
          .fontColor([enabled ? AppTheme.colors.primary : AppTheme.colors.textMuted])
      }
      .width(28)
      .justifyContent(FlexAlign.Center)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(enabled ? AppTheme.colors.textPrimary : AppTheme.colors.text3)
        if (subtitle.length > 0) {
          Text(subtitle)
            .fontSize(12)
            .fontColor(AppTheme.colors.text3)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 8 })
    }
    .width('100%')
    .padding({ left: 24, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.choose(kind, enabled);
    })
  }

  build() {
    Column() {
      Text('选择打卡类型')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 6 })
      this.buildOption('wake', '早起打卡', `开放时段 ${wakeWindowLabel()}`, isWakeCheckinOpen(), $r('sys.symbol.sun_max'))
      Divider().color(AppTheme.colors.border).strokeWidth(0.5)
      this.buildOption('sleep', '早睡打卡', `开放时段 ${sleepWindowLabel()}`, isSleepCheckinOpen(), $r('sys.symbol.moon'))
      Divider().color(AppTheme.colors.border).strokeWidth(0.5)
      this.buildOption('focus', '专注打卡', '', true, $r('sys.symbol.bolt'))
      Text(`已连续打卡${this.streakDays}天`)
        .fontSize(12)
        .fontColor(AppTheme.colors.text3)
        .lineHeight(18)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ left: 20, right: 20, top: 10, bottom: 4 })
    }
    .width(320)
    .padding({ top: 18, bottom: 14 })
    .borderRadius(20)
    .backgroundColor(AppTheme.colors.surface)
    .alignItems(HorizontalAlign.Center)
  }
}

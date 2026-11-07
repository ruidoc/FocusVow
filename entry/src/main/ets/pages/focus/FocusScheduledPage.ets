import { common } from '@kit.AbilityKit';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { backRoute } from '../../router/PageRoutes';
import {
  cancelPendingQuickStart,
  formatPendingQuickStartClockTime,
  formatPendingRemainClock,
  getPendingQuickStart,
  getPendingRemainSeconds,
  hasPendingQuickStart,
  isClockPendingQuickStart,
  PendingQuickStartState,
  splitPendingRemainHoursMinutes,
} from '../../services/PendingQuickStartService';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct FocusScheduledPage {
  @State showEmpty: boolean = false;
  @State waitLabel: string = '等待开始';
  @State countdownText: string = '0:00';
  @State countdownFontSize: number = 64;
  @State titleText: string = '';
  @State hintText: string = '';
  private timerId: number = -1;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!hasPendingQuickStart(hostContext)) {
      backRoute();
      return;
    }
    this.refreshPanelState();
    this.startTimer();
  }

  aboutToDisappear(): void {
    this.clearTimer();
  }

  onPageShow(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!hasPendingQuickStart(hostContext)) {
      backRoute();
      return;
    }
    this.refreshPanelState();
  }

  private startTimer(): void {
    this.clearTimer();
    this.timerId = setInterval(() => {
      this.refreshPanelState();
    }, 1000);
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private refreshPanelState(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const pending = getPendingQuickStart(hostContext);
    if (pending === null) {
      this.showEmpty = true;
      return;
    }
    this.showEmpty = false;
    const remainSec = getPendingRemainSeconds(hostContext);
    const isClock = isClockPendingQuickStart(pending);
    this.waitLabel = isClock ? '预约专注' : '等待开始';
    this.countdownFontSize = isClock ? 48 : 64;
    if (isClock) {
      this.countdownText = formatPendingQuickStartClockTime(pending.startAtMs);
    } else {
      this.countdownText = formatPendingRemainClock(remainSec);
    }
    this.titleText = pending.title;
    this.hintText = this.resolveAutoLockHint(pending, remainSec);
  }

  private resolveAutoLockHint(pending: PendingQuickStartState, remainSec: number): string {
    if (isClockPendingQuickStart(pending)) {
      const parts = splitPendingRemainHoursMinutes(remainSec);
      if (parts.hours > 0) {
        return `${parts.hours}小时${parts.minutes}分钟后自动锁机`;
      }
      return `${parts.minutes} 分钟后自动锁机`;
    }
    return `${pending.delayMinutes} 分钟后自动锁机`;
  }

  @Builder
  private buildEmptyPanel(): void {
    Column() {
      Text('暂无预约')
        .fontColor(AppTheme.colors.textSecondary)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private buildPendingPanel(): void {
    Column({ space: 0 }) {
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.clock'))
          .fontSize(18)
          .fontColor([AppTheme.colors.primary])
        Text(this.waitLabel)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textSecondary)
      }
      .margin({ bottom: 20 })

      Text(this.countdownText)
        .fontSize(this.countdownFontSize)
        .fontWeight(FontWeight.Lighter)
        .fontColor(AppTheme.colors.textPrimary)
        .textAlign(TextAlign.Center)

      Text(this.titleText)
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 40 })
        .constraintSize({ maxWidth: 280 })

      Text(this.hintText)
        .fontSize(15)
        .fontColor(AppTheme.colors.textSecondary)
        .textAlign(TextAlign.Center)
        .margin({ top: 12 })

      Text('取消预约')
        .fontSize(15)
        .fontColor(AppTheme.colors.warning)
        .textAlign(TextAlign.Center)
        .margin({ top: 64 })
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .onClick(() => {
          const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
          void cancelPendingQuickStart(hostContext).then(() => {
            backRoute();
          });
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 20, right: 20 })
  }

  @Builder
  private buildPanelBody(): void {
    Column() {
      if (this.showEmpty) {
        this.buildEmptyPanel();
      } else {
        this.buildPendingPanel();
      }
    }
    .width('100%')
    .constraintSize({ minHeight: '100%' })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '预约专注',
        showBack: true,
        usePageScroll: false,
        horizontalPadding: 16,
        useFloatingTabInset: false,
        onBack: (): void => {
          backRoute();
        },
        content: (): void => {
          this.buildPanelBody();
        },
      })
    }
    .width('100%')
    .height('100%')
  }
}

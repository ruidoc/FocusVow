import { common } from '@kit.AbilityKit';
import {
  FIRST_FOCUS_MINUTES,
  FIRST_FOCUS_TITLE,
} from '../../services/FirstFocusPromptService';
import { pushQuickStart } from '../../router/PageRoutes';
import { AnalyticsService } from '../../services/AnalyticsService';
import { AppTheme } from '../../constants/Theme';
import { homeGlassCardBg, homeGlassGoldIconBg } from '../../constants/HomeCardStyle';
import { HomeGlassSurface } from './HomeGlassSurface';
import {
  expireMembershipUrgencyIfNeeded,
  formatMembershipUrgencyCountdown,
  getMembershipUrgencySecondsLeft,
  shouldShowMembershipUrgencyCapsule,
} from '../../utils/OnboardingMembershipUtil';

@Component
export struct HomeMembershipUrgencyCapsule {
  @Prop hasActiveLock: boolean = false;
  @Prop hasPendingQuickStart: boolean = false;
  @State private capsuleTick: number = 0;
  private timerId: number = -1;

  aboutToAppear(): void {
    this.startTimer();
  }

  aboutToDisappear(): void {
    this.clearTimer();
  }

  private startTimer(): void {
    this.clearTimer();
    this.timerId = setInterval(() => {
      this.capsuleTick += 1;
    }, 1000);
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private getHostContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private shouldShow(): boolean {
    const _tick = this.capsuleTick;
    const hostContext = this.getHostContext();
    expireMembershipUrgencyIfNeeded(hostContext);
    if (!shouldShowMembershipUrgencyCapsule(hostContext, this.hasActiveLock, this.hasPendingQuickStart)) {
      return false;
    }
    return getMembershipUrgencySecondsLeft(hostContext) > 0;
  }

  private getCountdownLabel(): string {
    const _tick = this.capsuleTick;
    return formatMembershipUrgencyCountdown(getMembershipUrgencySecondsLeft(this.getHostContext()));
  }

  private onPress(): void {
    const props: Record<string, Object> = {};
    props['seconds_left'] = getMembershipUrgencySecondsLeft(this.getHostContext());
    AnalyticsService.trackEvent('membership_urgency_capsule_clicked', props);
    pushQuickStart(FIRST_FOCUS_TITLE, FIRST_FOCUS_MINUTES, true);
  }

  @Builder
  private buildCapsuleContent(): void {
    Row({ space: 12 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.gift'))
          .fontSize(18)
          .fontColor(['#D4A44A'])
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .borderRadius(18)
      .backgroundColor(homeGlassGoldIconBg())

      Column({ space: 2 }) {
        Text('新人权益即将失效')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .maxLines(1)
        Text() {
          Span(this.getCountdownLabel())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#D97706')
          Span(' 后失效 · 完成专注领取会员')
            .fontSize(12)
            .fontColor(AppTheme.colors.textSecondary)
        }
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([AppTheme.colors.textMuted])
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }

  build() {
    if (!this.shouldShow()) {
      Column()
    } else {
      Column() {
        HomeGlassSurface({
          glassBackgroundColor: homeGlassCardBg(),
          content: (): void => {
            this.buildCapsuleContent();
          },
        })
      }
      .width('100%')
      .margin({ top: 16 })
      .borderRadius(28)
      .clip(true)
      .onClick(() => {
        this.onPress();
      })
    }
  }
}

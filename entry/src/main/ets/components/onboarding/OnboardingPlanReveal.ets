import { AppTheme } from '../../constants/Theme';
import { getPlanTips, PlanTipContent } from '../../utils/OnboardingPlanTips';

const GENERATING_DURATION_MS: number = 5000;
const GENERATING_HOLD_MS: number = 500;

@Component
export struct OnboardingPlanReveal {
  @Prop identity: string = '';
  @Prop goal: string = '';
  onComplete: () => void = () => {
  };
  @State private generating: boolean = true;
  @State private generateProgress: number = 0;
  @State private tipIndex: number = 0;
  private tips: PlanTipContent[] = [];
  private generateTimerId: number = -1;
  private generateStartedAt: number = 0;

  aboutToAppear(): void {
    this.tips = getPlanTips(this.identity, this.goal);
    this.generating = true;
    this.generateProgress = 0;
    this.generateStartedAt = Date.now();
    this.generateTimerId = setInterval(() => {
      this.tickGenerating();
    }, 50);
  }

  aboutToDisappear(): void {
    if (this.generateTimerId >= 0) {
      clearInterval(this.generateTimerId);
      this.generateTimerId = -1;
    }
  }

  private tickGenerating(): void {
    const elapsed = Date.now() - this.generateStartedAt;
    const ratio = Math.min(1, elapsed / GENERATING_DURATION_MS);
    const eased = 0.5 - 0.5 * Math.cos(Math.PI * ratio);
    const next = Math.min(100, Math.floor(eased * 100));
    this.generateProgress = next;
    if (ratio >= 1) {
      if (this.generateTimerId >= 0) {
        clearInterval(this.generateTimerId);
        this.generateTimerId = -1;
      }
      setTimeout(() => {
        this.generating = false;
      }, GENERATING_HOLD_MS);
    }
  }

  private currentTip(): PlanTipContent | null {
    if (this.tipIndex < 0 || this.tipIndex >= this.tips.length) {
      return null;
    }
    return this.tips[this.tipIndex];
  }

  private isLastTip(): boolean {
    return this.tipIndex >= this.tips.length - 1;
  }

  private onPrimaryPress(): void {
    if (this.isLastTip()) {
      this.onComplete();
      return;
    }
    this.tipIndex = this.tipIndex + 1;
  }

  @Builder
  private buildGenerating(): void {
    Column({ space: 0 }) {
      Text(`${this.generateProgress}%`)
        .fontSize(84)
        .fontWeight(FontWeight.Lighter)
        .fontColor(AppTheme.colors.accentBlue)
        .margin({ top: 112 })
      Text('专注方案生成中...')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 72 })
      Text('根据你的身份和目标，为你匹配解决思路')
        .fontSize(15)
        .fontColor(AppTheme.colors.textSecondary)
        .lineHeight(22)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 12 })
        .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 32, right: 32 })
  }

  @Builder
  private buildTipCard(tip: PlanTipContent): void {
    Column({ space: 0 }) {
      Text(tip.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 10 })
      Text(tip.body)
        .fontSize(16)
        .fontColor(AppTheme.colors.textSecondary)
        .lineHeight(24)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 24, bottom: 24 })
    .backgroundColor('rgba(0,0,0,0.04)')
    .borderRadius(24)
  }

  @Builder
  private buildReady(): void {
    Column() {
      Text('专属方案已生成')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .textAlign(TextAlign.Center)
        .width('100%')
      Text('已为你定制3套高效的专注方案，帮你夺回时间')
        .fontSize(15)
        .fontColor(AppTheme.colors.textSecondary)
        .lineHeight(24)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 8, bottom: 32 })

      if (this.currentTip() !== null) {
        this.buildTipCard(this.currentTip() as PlanTipContent)
      }

      Button(this.isLastTip() ? '记住了' : '下一步')
        .width('100%')
        .height(52)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor(AppTheme.colors.primary)
        .borderRadius(AppTheme.radius.button)
        .margin({ top: 32 })
        .onClick(() => {
          this.onPrimaryPress();
        })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 32, right: 32, top: 8 })
    .justifyContent(FlexAlign.Start)
  }

  build() {
    Column() {
      if (this.generating) {
        this.buildGenerating()
      } else {
        this.buildReady()
      }
    }
    .width('100%')
    .layoutWeight(1)
  }
}

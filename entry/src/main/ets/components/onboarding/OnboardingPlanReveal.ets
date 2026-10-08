import { AppTheme } from '../../constants/Theme';
import { StoreKeys } from '../../stores/StoreKeys';
import { getPlanTips, PlanTipContent } from '../../utils/OnboardingPlanTips';

const GENERATING_DURATION_MS: number = 5000;
const GENERATING_HOLD_MS: number = 500;

@Component
struct PlanTipCard {
  @Prop title: string = '';
  @Prop body: string = '';
  @Prop tipId: string = '';
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';

  private tipSymbol(): Resource {
    if (this.tipId === 'duo') {
      return $r('sys.symbol.person_badge_plus');
    }
    if (this.tipId === 'schedule') {
      return $r('sys.symbol.alarm');
    }
    return $r('sys.symbol.play');
  }

  private tipColor(): string {
    if (this.tipId === 'duo') {
      return AppTheme.colors.accentBlue;
    }
    if (this.tipId === 'schedule') {
      return AppTheme.colors.primary;
    }
    return AppTheme.colors.fuchsia;
  }

  build() {
    Column({ space: 0 }) {
      SymbolGlyph(this.tipSymbol())
        .fontSize(40)
        .fontColor([this.tipColor()])
        .margin({ bottom: 16 })
      Text(this.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .textAlign(TextAlign.Center)
        .lineHeight(30)
        .width('100%')
        .margin({ bottom: 10 })
      Text(this.body)
        .fontSize(16)
        .fontColor(AppTheme.colors.textSecondary)
        .lineHeight(24)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24, top: 24, bottom: 24 })
    .backgroundColor(this.themeMode === 'dark' ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)')
    .borderRadius(24)
  }
}

@Component
export struct OnboardingPlanReveal {
  @Prop identity: string = '';
  @Prop goal: string = '';
  onComplete: () => void = () => {
  };
  @State private generating: boolean = true;
  @State private generateProgress: number = 0;
  @State private tipIndex: number = 0;
  @State private tipTitle: string = '';
  @State private tipBody: string = '';
  @State private tipId: string = '';
  @State private tipSlot: number = 0;
  @State private tips: PlanTipContent[] = [];
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';
  private generateTimerId: number = -1;
  private generateStartedAt: number = 0;

  aboutToAppear(): void {
    this.tips = getPlanTips(this.identity, this.goal);
    this.applyTip(0);
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

  private applyTip(index: number): void {
    if (index < 0 || index >= this.tips.length) {
      return;
    }
    const tip = this.tips[index];
    this.tipIndex = index;
    this.tipId = tip.id;
    this.tipTitle = tip.title;
    this.tipBody = tip.body;
    this.tipSlot = this.tipSlot + 1;
  }

  private isLastTip(): boolean {
    return this.tips.length === 0 || this.tipIndex >= this.tips.length - 1;
  }

  private onPrimaryPress(): void {
    if (this.isLastTip()) {
      this.onComplete();
      return;
    }
    this.applyTip(this.tipIndex + 1);
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

      if (this.tipSlot % 2 === 0) {
        PlanTipCard({
          title: this.tipTitle,
          body: this.tipBody,
          tipId: this.tipId,
        })
      } else {
        PlanTipCard({
          title: this.tipTitle,
          body: this.tipBody,
          tipId: this.tipId,
        })
      }

      Row({ space: 8 }) {
        Row()
          .width(this.tipIndex === 0 ? 18 : 6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(this.tipIndex === 0 ? AppTheme.colors.primary : (this.themeMode === 'dark' ? 'rgba(255,255,255,0.18)' : 'rgba(0,0,0,0.12)'))
        Row()
          .width(this.tipIndex === 1 ? 18 : 6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(this.tipIndex === 1 ? AppTheme.colors.primary : (this.themeMode === 'dark' ? 'rgba(255,255,255,0.18)' : 'rgba(0,0,0,0.12)'))
        Row()
          .width(this.tipIndex === 2 ? 18 : 6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(this.tipIndex === 2 ? AppTheme.colors.primary : (this.themeMode === 'dark' ? 'rgba(255,255,255,0.18)' : 'rgba(0,0,0,0.12)'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 20 })

      Button() {
        Text(this.isLastTip() ? '下一步' : '记住了')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width('100%')
      .height(48)
      .type(ButtonType.Normal)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .backgroundColor(AppTheme.colors.primary)
      .borderRadius(AppTheme.radius.button)
      .margin({ top: 20 })
      .onClick(() => {
        this.onPrimaryPress();
      })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 32, right: 32, top: 24 })
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

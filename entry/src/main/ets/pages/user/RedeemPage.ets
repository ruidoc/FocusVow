import { common } from "@kit.AbilityKit";
import { pasteboard } from "@kit.BasicServicesKit";
import { showErrorToast, showToast } from "../../common/Toast";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { AppTheme } from "../../constants/Theme";
import { ApiEnvelope, createEmptyUserInfo, UserInfo } from "../../models/UserModel";
import { PageRoutes, backRoute, pushRoute } from "../../router/PageRoutes";
import { HttpService } from "../../services/HttpService";
import {
  parseReferralProgress,
  ReferralApiService
} from "../../services/ReferralApiService";
import { BenefitStore } from "../../stores/BenefitStore";
import { StoreKeys } from "../../stores/StoreKeys";
import { UserStore } from "../../stores/UserStore";
import { bootstrapStores } from "../../stores/StoreBootstrap";

bootstrapStores();

const DEVELOPER_WECHAT: string = "ruimsion";
const ACCENT: string = "#D4A44A";
const SUCCESS: string = "#16A34A";
const CARD_BG: string = "#FFFBF0";
const BORDER: string = "rgba(212,164,74,0.35)";
const INVITE_ACCENT: string = '#3B82F6';

interface InviteStep {
  need: number;
  days: number;
}

const INVITE_STEPS: InviteStep[] = [
  { need: 1, days: 15 },
  { need: 2, days: 30 },
  { need: 3, days: 60 }
];

@Entry
@Component
struct RedeemPage {
  @StorageLink(StoreKeys.UserIsLoggedIn) isLoggedIn: boolean = false;
  @StorageLink(StoreKeys.UserInfo) userInfo: UserInfo = createEmptyUserInfo();
  @StorageLink(StoreKeys.BenefitMembershipStatus) membershipStatus: string = "none";
  @StorageLink(StoreKeys.BenefitIsSubscribed) isSubscribed: boolean = false;
  @State codeInput: string = "";
  @State isSubmitting: boolean = false;
  @State justRedeemed: boolean = false;
  @State expiresLabel: string = "";
  @State myInviteCode: string = "";
  @State inviteSuccessCount: number = 0;
  @State inviteDaysEarned: number = 0;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    BenefitStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }
    if (this.userInfo.invite_code.length > 0) {
      this.myInviteCode = this.userInfo.invite_code;
    }
    void this.refreshMembership();
    void this.loadInviteProgress();
  }

  private formatExpiry(raw: Object | undefined | null): string {
    if (raw === undefined || raw === null) {
      return '';
    }
    const d = new Date(String(raw));
    if (Number.isNaN(d.getTime())) {
      return '';
    }
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${d.getFullYear()}.${m}.${day}`;
  }

  private async refreshMembership(): Promise<void> {
    await BenefitStore.refresh();
    const subRes: ApiEnvelope = await HttpService.get('/subscription');
    if (subRes.statusCode === 200 && subRes.data) {
      const data = subRes.data as Record<string, Object>;
      const label = this.formatExpiry(data['expires_at']);
      if (label.length > 0) {
        this.expiresLabel = label;
      }
    }
  }

  private async loadInviteProgress(): Promise<void> {
    const response = await ReferralApiService.progress();
    if (response.statusCode !== 200) {
      return;
    }
    const progress = parseReferralProgress(response.data);
    if (!progress) {
      return;
    }
    if (progress.invite_code.length > 0) {
      this.myInviteCode = progress.invite_code;
    }
    this.inviteSuccessCount = progress.successful_count;
    this.inviteDaysEarned = progress.total_days_earned;
  }

  private isActive(): boolean {
    return this.isSubscribed || this.membershipStatus === "active";
  }

  private showSuccess(): boolean {
    return this.isActive() || this.justRedeemed;
  }

  private inviteFillRatio(): number {
    if (this.inviteSuccessCount <= 0) {
      return 0;
    }
    if (this.inviteSuccessCount === 1) {
      return 0.5;
    }
    return 1;
  }

  private async onRedeem(): Promise<void> {
    if (this.isSubmitting) {
      return;
    }
    const code = this.codeInput.trim();
    if (code.length === 0) {
      showToast("请输入兑换码", this.getUIContext());
      return;
    }
    this.isSubmitting = true;
    const body: Record<string, Object> = {
      'code': code
    };
    const response: ApiEnvelope = await HttpService.post('/redeem', body);
    this.isSubmitting = false;
    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? "兑换失败", this.getUIContext());
      return;
    }
    this.codeInput = "";
    this.justRedeemed = true;
    const data = response.data as Record<string, Object> | undefined;
    if (data) {
      const redemption = data['redemption'] as Record<string, Object> | undefined;
      const subscription = data['subscription'] as Record<string, Object> | undefined;
      const expires = redemption?.['expires_at'] ?? subscription?.['expires_at'];
      const label = this.formatExpiry(expires);
      if (label.length > 0) {
        this.expiresLabel = label;
      }
    }
    await BenefitStore.refresh();
    showToast("兑换成功", this.getUIContext());
  }

  private onCopyWechat(): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, DEVELOPER_WECHAT);
      pasteboard.getSystemPasteboard().setData(data);
      showToast("微信号已复制", this.getUIContext());
    } catch (_e) {
      showErrorToast("复制失败", this.getUIContext());
    }
  }

  private onCopyInvite(): void {
    if (this.myInviteCode.length === 0) {
      showToast("邀请码加载中，请稍后再试", this.getUIContext());
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.myInviteCode);
      pasteboard.getSystemPasteboard().setData(data);
      showToast("邀请码已复制", this.getUIContext());
    } catch (_e) {
      showErrorToast("复制失败", this.getUIContext());
    }
  }

  @Builder
  private buildWechatHint(hint: string): void {
    Column({ space: 6 }) {
      Text(hint)
        .fontSize(13)
        .fontColor('#7B8494')
        .width("100%")
        .textAlign(TextAlign.Center)
      Row({ space: 5 }) {
        SymbolGlyph($r("sys.symbol.doc_plaintext"))
          .fontSize(13)
          .fontColor(['#7B8494'])
        Text("复制微信号")
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#7B8494')
      }
      .onClick(() => {
        this.onCopyWechat();
      })
    }
    .width("100%")
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private buildSuccessCards(): void {
    Column({ space: 16 }) {
      Column({ space: 14 }) {
        Text("兑换成功")
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(SUCCESS)
          .width("100%")
        Text("每日专注时长已不限额度。")
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%")
        if (this.expiresLabel.length > 0) {
          Text(`到期时间 ${this.expiresLabel}`)
            .fontSize(13)
            .fontColor('#A16207')
            .width("100%")
            .margin({ top: 2 })
        }
      }
      .width("100%")
      .padding(20)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(CARD_BG)
      .border({ width: 1, color: BORDER })
      .borderRadius(20)
      Column() {
        this.buildWechatHint("加管理员好友进搭子匹配群，快速找搭子")
      }
      .width("100%")
      .padding({ left: 4, right: 4 })
      .margin({ top: 24 })
    }.width("100%");
  }

  @Builder
  private buildRedeemForm(): void {
    Column({ space: 16 }) {
      Column({ space: 16 }) {
        Text("输入兑换码")
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .width("100%")
        Text("兑换会员后可解锁每日无限专注时长。")
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%")
        TextInput({ placeholder: "请输入兑换码", text: this.codeInput })
          .height(52)
          .width("100%")
          .fontSize(17)
          .fontColor(AppTheme.colors.textPrimary)
          .placeholderColor("#A89B88")
          .padding({ left: 16, right: 16 })
          .backgroundColor(Color.White)
          .border({ width: 1.5, color: "rgba(212,164,74,0.45)" })
          .borderRadius(12)
          .type(InputType.Normal)
          .onChange((value: string) => {
            this.codeInput = value;
          })
        Button(this.isSubmitting ? "兑换中…" : "立即兑换")
          .width("100%")
          .height(48)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor("#461702")
          .backgroundColor(ACCENT)
          .borderRadius(24)
          .enabled(!this.isSubmitting)
          .opacity(this.isSubmitting ? 0.55 : 1)
          .onClick(() => {
            void this.onRedeem();
          })
      }
      .width("100%")
      .padding(20)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(CARD_BG)
      .border({ width: 1, color: BORDER })
      .borderRadius(20)
      Column() {
        this.buildWechatHint("没有兑换码？联系管理员免费获取")
      }
      .width("100%")
      .padding({ left: 4, right: 4 })
      .margin({ top: 24 })
    }.width("100%");
  }

  @Builder
  private buildInviteStepNode(step: InviteStep): void {
    Row() {
      if (this.inviteSuccessCount >= step.need) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(12)
          .fontColor([Color.White])
      } else if (this.inviteSuccessCount === step.need - 1) {
        Row()
          .width(7)
          .height(7)
          .borderRadius(4)
          .backgroundColor(INVITE_ACCENT)
      }
    }
    .width(20)
    .height(20)
    .justifyContent(FlexAlign.Center)
    .borderRadius(10)
    .backgroundColor(
      this.inviteSuccessCount >= step.need
        ? INVITE_ACCENT
        : (this.inviteSuccessCount === step.need - 1 ? Color.White : '#E2E8F0')
    )
    .border(
      this.inviteSuccessCount === step.need - 1 && this.inviteSuccessCount < step.need
        ? { width: 2.5, color: INVITE_ACCENT }
        : { width: 0 }
    )
  }

  @Builder
  private buildInviteSection(): void {
    Column({ space: 14 }) {
      Column({ space: 16 }) {
        Text(this.showSuccess() ? '邀请搭子，再得60天会员！' : '邀请搭子得60天会员！')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')
        Text('对方填你的邀请码并注册，双方各得 15 天')
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
          .lineHeight(19)
          .width('100%')

        Column({ space: 12 }) {
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width('100%')
              .height(4)
              .margin({ left: 7, right: 7 })
              .borderRadius(2)
              .backgroundColor('#E2EBF7')
            Row()
              .width(`${Math.max(0, this.inviteFillRatio() * 100)}%`)
              .height(4)
              .margin({ left: 7 })
              .borderRadius(2)
              .backgroundColor(INVITE_ACCENT)
              .align(Alignment.Start)
            Row() {
              ForEach(INVITE_STEPS, (step: InviteStep) => {
                this.buildInviteStepNode(step)
              }, (step: InviteStep) => `${step.need}`)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
          .width('100%')
          .height(22)

          Row() {
            ForEach(INVITE_STEPS, (step: InviteStep, index: number) => {
              Column({ space: 2 }) {
                Text(`+${step.days}天`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(
                    this.inviteSuccessCount >= step.need || this.inviteSuccessCount === step.need - 1
                      ? INVITE_ACCENT
                      : AppTheme.colors.textMuted
                  )
                Text(`邀${step.need}人`)
                  .fontSize(11)
                  .fontColor(
                    this.inviteSuccessCount >= step.need || this.inviteSuccessCount === step.need - 1
                      ? AppTheme.colors.textSecondary
                      : AppTheme.colors.textMuted
                  )
              }
              .width(64)
              .alignItems(
                index === 0
                  ? HorizontalAlign.Start
                  : (index === INVITE_STEPS.length - 1 ? HorizontalAlign.End : HorizontalAlign.Center)
              )
            }, (step: InviteStep) => `label-${step.need}`)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
        .width('100%')
        .padding({ left: 4, right: 4 })

        Row() {
          Text() {
            Span('邀请码 ')
              .fontSize(13)
              .fontColor(AppTheme.colors.textMuted)
            Span(this.myInviteCode.length > 0 ? this.myInviteCode : '…')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textPrimary)
          }
          .layoutWeight(1)
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.doc_plaintext'))
              .fontSize(14)
              .fontColor([INVITE_ACCENT])
            Text('复制')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(INVITE_ACCENT)
          }
          .onClick(() => {
            this.onCopyInvite();
          })
        }
        .width('100%')
        .height(42)
        .padding({ left: 12, right: 12 })
        .backgroundColor('#F1F5F9')
        .borderRadius(12)
      }
      .width('100%')
      .padding(20)
      .backgroundColor(Color.White)
      .borderRadius(16)

      Row({ space: 2 }) {
        Text(
          this.inviteDaysEarned > 0
            ? `邀请记录 · 已得 ${this.inviteDaysEarned} 天`
            : '邀请记录'
        )
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([AppTheme.colors.textMuted])
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .onClick(() => {
        pushRoute(PageRoutes.InviteRecord);
      })
    }
    .width('100%')
    .margin({ top: 16 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildPageBody(): void {
    Column({ space: 0 }) {
      if (this.showSuccess()) {
        this.buildSuccessCards();
      } else {
        this.buildRedeemForm();
      }
      this.buildInviteSection()
    }
    .width("100%")
    .padding({ left: 4, right: 4, top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Stack() {
      SystemNavPage({
        title: "兑换会员",
        showBack: true,
        usePageScroll: true,
        horizontalPadding: 20,
        onBack: () => {
          backRoute();
        },
        content: (): void => {
          this.buildPageBody();
        },
      })
    }
    .width("100%")
    .height("100%");
  }
}

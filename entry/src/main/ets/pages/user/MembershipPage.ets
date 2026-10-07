import { common } from "@kit.AbilityKit";
import { router, window } from "@kit.ArkUI";
import { showErrorToast, showToast } from "../../common/Toast";
import { LegalUrls } from "../../constants/LegalUrls";
import { AppTheme, isDarkThemeMode } from "../../constants/Theme";
import { createEmptyUserInfo, UserInfo } from "../../models/UserModel";
import { backRoute, PageRoutes, pushLogin, pushRoute, pushWebView } from "../../router/PageRoutes";
import { AnalyticsService } from "../../services/AnalyticsService";
import { BenefitStore } from "../../stores/BenefitStore";
import { FeatureFlagStore } from "../../stores/FeatureFlagStore";
import {
  SubscriptionApiService,
  SubscriptionSnapshot,
  VipProduct,
} from "../../services/SubscriptionApiService";
import { WeChatOpenService, WeChatPayParams } from "../../services/WeChatOpenService";
import { StoreKeys } from "../../stores/StoreKeys";
import { UserStore } from "../../stores/UserStore";
import { bootstrapStores } from "../../stores/StoreBootstrap";
import { confirmPaidServiceAgreement } from "../../utils/PrivacyConsentUtil";

bootstrapStores();

const GOLD: string = "#D4A44A";
const CHECKOUT_TEXT: string = "#461702";
const TRIAL_GREEN: string = "#16A34A";
const WECHAT_YEARLY_BENEFIT_DAYS: number = 14 * 30;

interface MembershipPerk {
  title: string;
  desc: string;
  symbol: Resource;
}

const PERKS: MembershipPerk[] = [
  { title: "无限定时", desc: "定时任务不限次", symbol: $r("sys.symbol.calendar") },
  { title: "短视频限额", desc: "到点强行锁机", symbol: $r("sys.symbol.timer") },
  { title: "无限快捷", desc: "快捷任务不限条", symbol: $r("sys.symbol.bolt") },
  { title: "无限延时", desc: "自定义延时时长", symbol: $r("sys.symbol.hourglass") },
];

function formatPrice(fen: number): string {
  const yuan = fen / 100;
  if (Number.isInteger(yuan)) {
    return `¥${yuan}`;
  }
  return `¥${yuan.toFixed(2)}`;
}

function splitPriceDisplay(raw: string): string[] {
  const text = raw.replace(/\s/g, "");
  const match = text.match(/^([^0-9]*)([0-9]+(?:[.,][0-9]+)?)/);
  if (!match) {
    return ["¥", raw];
  }
  const symbol = match[1].length > 0 ? match[1] : "¥";
  return [symbol, match[2]];
}

function planTitle(period: number): string {
  if (period >= 12) {
    return "年会员";
  }
  if (period === 2) {
    return "双月会员";
  }
  if (period === 7) {
    return "周会员";
  }
  return "月会员";
}

function planTag(period: number): string {
  if (period >= 12) {
    return "多送2个月";
  }
  if (period === 2) {
    return "限时特惠";
  }
  return "";
}

function benefitDays(period: number): number {
  if (period >= 12) {
    return WECHAT_YEARLY_BENEFIT_DAYS;
  }
  return Math.max(period, 1) * 30;
}

function dayPrice(product: VipProduct): string {
  return formatPrice(Math.round(product.price / benefitDays(product.period)));
}

function formatExpiry(dateStr: string): string {
  if (dateStr.length === 0) {
    return "";
  }
  const d = new Date(dateStr);
  if (Number.isNaN(d.getTime())) {
    return "";
  }
  const month = d.getMonth() + 1;
  const day = d.getDate();
  return `${d.getFullYear()}/${month < 10 ? `0${month}` : month}/${day < 10 ? `0${day}` : day}`;
}

function daysUntil(dateStr: string): number | null {
  if (dateStr.length === 0) {
    return null;
  }
  const d = new Date(dateStr);
  if (Number.isNaN(d.getTime())) {
    return null;
  }
  return Math.max(0, Math.ceil((d.getTime() - Date.now()) / 86400000));
}

function resolveEntrySource(params: Record<string, Object> | undefined): string {
  if (!params) {
    return "profile";
  }
  const raw = params["entry_source"];
  if (raw === undefined) {
    return "profile";
  }
  const text = String(raw).trim();
  return text.length > 0 ? text : "profile";
}

function sortPlans(a: VipProduct, b: VipProduct): number {
  if (a.period >= 12 && b.period < 12) {
    return -1;
  }
  if (b.period >= 12 && a.period < 12) {
    return 1;
  }
  return b.period - a.period;
}

@Entry
@Component
struct MembershipPage {
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = "light";
  @StorageLink(StoreKeys.UserInfo) userInfo: UserInfo = createEmptyUserInfo();
  @StorageLink(StoreKeys.BenefitMembershipStatus) membershipStatus: string = "none";
  @StorageLink(StoreKeys.BenefitIsSubscribed) isBenefitSubscribed: boolean = false;
  @State products: VipProduct[] = [];
  @State selectedProductId: string = "";
  @State loadingProducts: boolean = true;
  @State paymentStatus: string = "idle";
  @State agreed: boolean = false;
  @State subscription: SubscriptionSnapshot | null = null;
  @State bottomInset: number = 12;
  @State contentWidth: number = 360;
  private entrySource: string = "profile";

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    FeatureFlagStore.hydrate(hostContext);
    const ui = this.getUIContext();
    window.getLastWindow(hostContext, (err, win) => {
      if (err.code) {
        return;
      }
      const navAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.bottomInset = Math.max(ui.px2vp(navAvoid.bottomRect.height), 12);
      const statusAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topInsetVp = Math.max(ui.px2vp(statusAvoid.topRect.height), 0);
    });
    if (!UserStore.isLoggedIn()) {
      pushLogin();
      return;
    }
    if (!FeatureFlagStore.isPromoVipOn()) {
      pushRoute(PageRoutes.Redeem);
      return;
    }
    const routeParams = router.getParams() as Record<string, Object>;
    this.entrySource = resolveEntrySource(routeParams);
    this.trackRightsViewed();
    void this.load();
  }

  @State topInsetVp: number = 0;

  private isActive(): boolean {
    return (
      this.isBenefitSubscribed ||
      this.membershipStatus === "active" ||
      (this.subscription !== null && SubscriptionApiService.isEntitled(this.subscription))
    );
  }

  private async load(): Promise<void> {
    this.loadingProducts = true;
    void BenefitStore.refresh();
    this.subscription = await SubscriptionApiService.fetchSubscription();
    const list = await SubscriptionApiService.listVipProducts();
    const visible: VipProduct[] = [];
    for (let i = 0; i < list.length; i++) {
      visible.push(list[i]);
    }
    visible.sort(sortPlans);
    this.products = visible;
    let selected = visible.length > 0 ? visible[0].product_id : "";
    for (let i = 0; i < visible.length; i++) {
      if (visible[i].period >= 12) {
        selected = visible[i].product_id;
        break;
      }
    }
    this.selectedProductId = selected;
    this.loadingProducts = false;
  }

  private trackRightsViewed(): void {
    const props: Record<string, Object> = {};
    props["screen_name"] = "rights_page";
    props["entry_source"] = this.entrySource;
    props["placement"] = "membership_center";
    props["subscription_status"] = this.membershipStatus;
    props["is_entitled"] = this.isActive();
    AnalyticsService.trackEvent("rights_page_viewed", props);
  }

  private getSelectedProduct(): VipProduct | null {
    for (let i = 0; i < this.products.length; i++) {
      if (this.products[i].product_id === this.selectedProductId) {
        return this.products[i];
      }
    }
    return this.products.length > 0 ? this.products[0] : null;
  }

  private planCardWidth(): number {
    const pad = 20;
    const gap = 10;
    const w = this.contentWidth > 0 ? this.contentWidth : 360;
    return (w - pad - gap * 2) / 2.5;
  }

  private remainRatio(): number {
    if (!this.isActive() || this.subscription === null) {
      return 0;
    }
    const left = daysUntil(this.subscription.expires_at);
    if (left === null) {
      return 0;
    }
    const periodDays = 30;
    return Math.min(1, Math.max(0.08, left / periodDays));
  }

  private plansSectionTitle(): string {
    if (this.isActive()) {
      return "续费套餐";
    }
    return "选择套餐";
  }

  private isProductSelected(productId: string): boolean {
    return productId === this.selectedProductId;
  }

  private isLastPlan(index: number): boolean {
    return index >= this.products.length - 1;
  }

  private checkoutLabel(): string {
    const product = this.getSelectedProduct();
    if (!product) {
      return "选择套餐";
    }
    const price = formatPrice(product.price);
    if (this.isActive()) {
      return `立即续费 · ${price}`;
    }
    return `立即支付 · ${price}`;
  }

  private displayName(): string {
    const name = this.userInfo.username.trim();
    return name.length > 0 ? name : "朋友";
  }

  private async ensureAgreement(): Promise<boolean> {
    if (this.agreed) {
      return true;
    }
    const accepted = await confirmPaidServiceAgreement(this.getUIContext());
    if (!accepted) {
      return false;
    }
    this.agreed = true;
    return true;
  }

  private async doCheckout(): Promise<void> {
    const product = this.getSelectedProduct();
    if (!product || this.paymentStatus === "processing") {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.paymentStatus = "processing";
    try {
      const order = await SubscriptionApiService.createWechatSubscriptionOrder(product.product_id);
      if (!order) {
        throw new Error("下单失败");
      }
      const payParams: WeChatPayParams = {
        partnerId: order.partnerId,
        prepayId: order.prepayId,
        nonceStr: order.nonceStr,
        timeStamp: order.timeStamp,
        sign: order.sign,
      };
      const payResult = await WeChatOpenService.requestPayment(hostContext, payParams);
      if (payResult.cancelled) {
        this.paymentStatus = "idle";
        return;
      }
      if (!payResult.ok) {
        throw new Error(payResult.message || "支付失败");
      }
      await SubscriptionApiService.waitForEntitlement(order.out_trade_no);
      await BenefitStore.refresh();
      this.subscription = await SubscriptionApiService.fetchSubscription();
      this.paymentStatus = "idle";
      showToast("开通成功，权益已生效", this.getUIContext());
    } catch (error) {
      this.paymentStatus = "idle";
      showErrorToast(String(error), this.getUIContext());
    }
  }

  private onCheckout(): void {
    if (!this.getSelectedProduct()) {
      return;
    }
    void this.ensureAgreement().then((ok: boolean) => {
      if (ok) {
        void this.doCheckout();
      }
    });
  }

  private openRedeem(): void {
    router
      .pushUrl({
        url: PageRoutes.Redeem,
        params: {
          entry_source: "membership_center",
        },
      })
      .catch((error: Error) => {
        console.warn(`[Membership] open redeem failed: ${String(error)}`);
      });
  }

  @Builder
  private buildHero(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Text("Pro")
        .fontSize(72)
        .fontWeight(FontWeight.Bolder)
        .fontColor(this.goldText())
        .opacity(this.isActive() ? 0.12 : 0.07)
        .letterSpacing(2)
        .position({ x: "66%", y: this.isActive() ? this.topInsetVp - 46 : this.topInsetVp - 14 })
      Column() {
        Row() {
          Row() {
            SymbolGlyph($r("sys.symbol.chevron_left"))
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor([this.goldText()])
          }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            backRoute();
          })
          Blank()
        }
        .width("100%")
        .margin({ bottom: 8 })
        Row() {
          if (this.userInfo.avatar.length > 0) {
            Image(this.userInfo.avatar)
              .width(56)
              .height(56)
              .borderRadius(28)
              .objectFit(ImageFit.Cover);
          } else {
            Image($r("app.media.startIcon")).width(56).height(56).borderRadius(28);
          }
          Column() {
            Text(this.isActive() ? "Pro 生效中" : "尚未开通")
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.goldText())
            if (this.isActive()) {
              Row() {
                Column()
                  .width(`${Math.round(this.remainRatio() * 100)}%`)
                  .height(4)
                  .backgroundColor(GOLD)
              }
              .width(160)
              .height(4)
              .borderRadius(2)
              .backgroundColor(
                isDarkThemeMode() ? "rgba(232,162,58,0.22)" : "rgba(212,164,74,0.35)",
              )
              .clip(true)
              .margin({ top: 8 });
            }
            Text(
              this.isActive() &&
              this.subscription !== null &&
              this.subscription.expires_at.length > 0
                ? `有效期至${formatExpiry(this.subscription.expires_at)}`
                : "开通后解锁全部高级专注能力",
            )
              .fontSize(12)
              .fontColor(isDarkThemeMode() ? "#C4A574" : "#A16207")
              .margin({ top: 6 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 12 })
        }
        .width("100%")
        .alignItems(VerticalAlign.Center)
      }.width("100%")
    }
    .width("100%")
    .padding({
      left: 20,
      right: 20,
      top: this.topInsetVp + 4,
      bottom: 36,
    })
    .linearGradient({
      angle: 135,
      colors: isDarkThemeMode()
        ? [
            ["#2A2318", 0],
            ["#1A1612", 1],
          ]
        : [
            ["#FFF6E4", 0],
            ["#F7E7C6", 1],
          ],
    })
    .margin({ top: 0 });
  }

  private goldText(): string {
    return isDarkThemeMode() ? "#F3D7A0" : "#8A5A12";
  }

  @Builder
  private buildPlanTag(product: VipProduct): void {
    if (planTag(product.period).length > 0) {
      Text(planTag(product.period))
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(
          this.isProductSelected(product.product_id)
            ? CHECKOUT_TEXT
            : AppTheme.colors.textSecondary,
        )
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(
          product.period >= 12
            ? this.isProductSelected(product.product_id)
              ? TRIAL_GREEN
              : isDarkThemeMode()
                ? "#3A3A3A"
                : "#E8E8E8"
            : this.isProductSelected(product.product_id)
              ? GOLD
              : isDarkThemeMode()
                ? "#3A3A3A"
                : "#E8E8E8",
        )
        .borderRadius(8);
    }
  }

  @Builder
  private buildPlanCard(product: VipProduct, index: number): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Text(planTitle(product.period))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width("100%")
          .textAlign(TextAlign.Start)
        Flex({
          direction: FlexDirection.Row,
          alignItems: ItemAlign.Baseline,
          justifyContent: FlexAlign.Start,
        }) {
          Text(splitPriceDisplay(formatPrice(product.price))[0])
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)
            .margin({ right: 2 })
          Text(splitPriceDisplay(formatPrice(product.price))[1])
            .fontSize(36)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
        }
        .margin({ top: 16 })
        Text(`约 ${dayPrice(product)}/天`)
          .fontSize(11)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%")
          .textAlign(TextAlign.Start)
          .margin({ top: 4 })
      }
      .width("100%")
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12, right: 12, top: 18, bottom: 16 })
      .borderRadius(24)
      .backgroundColor(
        this.isProductSelected(product.product_id)
          ? isDarkThemeMode()
            ? "#2A2318"
            : "#FFF8EB"
          : isDarkThemeMode()
            ? AppTheme.colors.background
            : "#FFFFFF",
      )
      .border({
        width: 2,
        color: this.isProductSelected(product.product_id) ? GOLD : AppTheme.colors.border,
      })
      Column() {
        this.buildPlanTag(product)
      }
      .margin({ left: 10, top: -8 })
    }
    .width(this.planCardWidth())
    .margin({ right: this.isLastPlan(index) ? 0 : 10 })
    .onClick(() => {
      this.selectedProductId = product.product_id;
    });
  }

  @Builder
  private buildPerk(perk: MembershipPerk): void {
    Row() {
      Row() {
        SymbolGlyph(perk.symbol)
          .fontSize(20)
          .fontColor([GOLD])
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(isDarkThemeMode() ? AppTheme.colors.surfaceSecondary : "#F1F5F9")
      Column() {
        Text(perk.title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
        Text(perk.desc)
          .fontSize(11)
          .fontColor(AppTheme.colors.textSecondary)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })
    }
    .width("48%")
    .alignItems(VerticalAlign.Center)
    .margin({ bottom: 16 });
  }

  @Builder
  private buildSheet(): void {
    Column() {
      Text(this.plansSectionTitle())
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .width("100%")
        .padding({ left: 20, right: 20, bottom: 12 })

      if (this.loadingProducts) {
        LoadingProgress().width(32).height(32).color(GOLD).margin({ top: 24, bottom: 24 });
      } else if (this.products.length === 0) {
        Text("暂未开放")
          .fontSize(15)
          .fontColor(AppTheme.colors.textMuted)
          .width("100%")
          .textAlign(TextAlign.Center)
          .padding({ top: 24, bottom: 24 });
      } else {
        Scroll() {
          Row() {
            ForEach(
              this.products,
              (product: VipProduct, index: number) => {
                this.buildPlanCard(product, index);
              },
              (product: VipProduct) => product.product_id,
            )
          }
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Top)
          .padding({ left: 20, right: 20, top: 10, bottom: 4 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .nestedScroll({
          scrollForward: NestedScrollMode.SELF_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST,
        })
        .width("100%")
        .align(Alignment.TopStart);
      }
      Text("会员权益")
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .width("100%")
        .padding({ left: 20, right: 20, top: 28, bottom: 12 })
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(
          PERKS,
          (perk: MembershipPerk) => {
            this.buildPerk(perk);
          },
          (perk: MembershipPerk) => perk.title,
        )
      }
      .width("100%")
      .padding({ left: 20, right: 20 })
      Column() {
        Text("邀请得会员")
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width("100%")
          .margin({ bottom: 12 })
        Row() {
          Text("去邀请")
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)
        }
        .width(138)
        .justifyContent(FlexAlign.Center)
        .padding({ top: 12, bottom: 12 })
        .borderRadius(2)
        .backgroundColor(isDarkThemeMode() ? AppTheme.colors.surfaceSecondary : "#F1F5F9")
        .onClick(() => {
          this.openRedeem();
        })
      }
      .width("100%")
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 28 })
    }
    .width("100%")
    .layoutWeight(1)
    .padding({ top: 20 })
    .margin({ top: -20 })
    .borderRadius({ topLeft: 24, topRight: 24 })
    .backgroundColor(AppTheme.colors.surface);
  }

  @Builder
  private buildFooter(): void {
    Column({ space: 10 }) {
      Row() {
        if (this.paymentStatus === "processing") {
          LoadingProgress().width(22).height(22).color(CHECKOUT_TEXT);
        } else {
          Text(this.checkoutLabel())
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(CHECKOUT_TEXT);
        }
      }
      .width("100%")
      .height(54)
      .justifyContent(FlexAlign.Center)
      .borderRadius(27)
      .backgroundColor(GOLD)
      .opacity(this.getSelectedProduct() === null || this.paymentStatus === "processing" ? 0.5 : 1)
      .onClick(() => {
        if (this.getSelectedProduct() !== null && this.paymentStatus !== "processing") {
          this.onCheckout();
        }
      })
      Row({ space: 4 }) {
        Checkbox()
          .select(this.agreed)
          .selectedColor(GOLD)
          .width(15)
          .height(15)
          .onChange((checked: boolean) => {
            this.agreed = checked;
          })
        Text("我已阅读并同意")
          .fontSize(11)
          .fontColor(AppTheme.colors.textMuted)
          .onClick(() => {
            this.agreed = !this.agreed;
          })
        Text("《付费服务协议》")
          .fontSize(11)
          .fontColor(AppTheme.colors.textPrimary)
          .onClick(() => {
            pushWebView(LegalUrls.PAID_SERVICE, "付费服务协议");
          })
      }
      .width("100%")
      .justifyContent(FlexAlign.Center)
    }
    .width("100%")
    .padding({
      left: 20,
      right: 20,
      top: 12,
      bottom: this.bottomInset,
    })
    .backgroundColor(AppTheme.colors.surface);
  }

  @Builder
  private buildContent(): void {
    Column() {
      Scroll() {
        Column() {
          this.buildHero()
          this.buildSheet()
        }
        .width("100%")
        .constraintSize({ minHeight: "100%" })
        .onAreaChange((_old: Area, area: Area) => {
          const next = area.width as number;
          if (next > 0 && Math.abs(next - this.contentWidth) > 1) {
            this.contentWidth = next;
          }
        })
      }
      .layoutWeight(1)
      .width("100%")
      .scrollBar(BarState.Off)
      .clip(false)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.products.length > 0) {
        this.buildFooter();
      }
    }
    .width("100%")
    .height("100%")
    .backgroundColor(AppTheme.colors.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP]);
  }

  build() {
    Stack() {
      this.buildContent()
    }
    .width("100%")
    .height("100%")
    .backgroundColor(AppTheme.colors.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }
}

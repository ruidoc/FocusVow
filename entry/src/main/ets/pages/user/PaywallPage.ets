import { common } from "@kit.AbilityKit";
import { router, window } from "@kit.ArkUI";
import { showErrorToast, showToast } from "../../common/Toast";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { LegalUrls } from "../../constants/LegalUrls";
import { VipProduct, SubscriptionApiService } from "../../services/SubscriptionApiService";
import { WeChatOpenService, WeChatPayParams } from "../../services/WeChatOpenService";
import { AnalyticsService } from "../../services/AnalyticsService";
import { BenefitStore } from "../../stores/BenefitStore";
import { FeatureFlagStore } from "../../stores/FeatureFlagStore";
import { AppTheme, isDarkThemeMode } from "../../constants/Theme";
import { bootstrapStores } from "../../stores/StoreBootstrap";
import { StoreKeys } from "../../stores/StoreKeys";
import { UserStore } from "../../stores/UserStore";
import { backRoute, PageRoutes, pushRoute, pushWebView } from "../../router/PageRoutes";
import { confirmPaidServiceAgreement } from "../../utils/PrivacyConsentUtil";
import { PRO_UNLOCK_DEFAULT_SUBTITLE, PRO_UNLOCK_TITLE } from "../../utils/PaywallNavigationUtil";
import { completeOnboardingAfterPaywall } from "../../utils/OnboardingMembershipUtil";

bootstrapStores();

const BENEFITS: string[] = [
  "无限延时专注，自定义延时时长",
  "无限多段定时，工作日/周末自动循环",
  "无限快捷预设，一键开启",
  "短视频与应用限额，到点强行锁机",
];

const GOLD: string = "#D4A44A";
const CHECKOUT_TEXT: string = "#461702";
const TRIAL_GREEN: string = "#16A34A";
const CHECK_BLUE: string = "#2563EB";

function getCheckoutButtonText(product: VipProduct | null): string {
  if (!product) {
    return "请选择套餐";
  }
  if (product.period === 2) {
    return "解锁双月权益";
  }
  return "解锁月度权益";
}

function formatPrice(fen: number): string {
  const yuan = fen / 100;
  if (Number.isInteger(yuan)) {
    return `¥${yuan}`;
  }
  return `¥${yuan.toFixed(2)}`;
}

function formatWeeklyPrice(product: VipProduct): string {
  const weeks =
    product.period >= 12 ? 52 : product.period === 7 ? 1 : Math.max(product.period, 1) * (30 / 7);
  return formatPrice(Math.round(product.price / weeks));
}

function getPlanTitle(period: number): string {
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

function getPlanDuration(period: number): string {
  if (period >= 12) {
    return "12 个月";
  }
  if (period === 2) {
    return "2 个月";
  }
  if (period === 7) {
    return "7 天";
  }
  return "1 个月";
}

function resolveEntrySource(params: Record<string, Object> | undefined): string {
  if (!params) {
    return "unknown";
  }
  const raw = params["entry_source"];
  if (raw === undefined) {
    return "unknown";
  }
  const text = String(raw).trim();
  return text.length > 0 ? text : "unknown";
}

function resolveProUnlock(params: Record<string, Object> | undefined): boolean {
  if (!params) {
    return false;
  }
  const raw = params["pro_unlock"];
  return raw === '1' || raw === 1 || raw === true;
}

function resolveProUnlockReason(params: Record<string, Object> | undefined): string {
  if (!params) {
    return "";
  }
  const raw = params["pro_unlock_reason"];
  if (raw === undefined) {
    return "";
  }
  return String(raw).trim();
}

function buildProductTrackProps(product: VipProduct, entrySource: string): Record<string, Object> {
  const props: Record<string, Object> = {};
  props["screen_name"] = "paywall_index";
  props["entry_source"] = entrySource;
  props["placement"] = "paywall_index";
  props["product_id"] = product.product_id;
  props["product_name"] = product.name;
  props["period"] = product.period;
  props["price"] = product.price;
  props["currency"] = "CNY";
  props["purchase_source"] = "wechat";
  props["offer_type"] = "none";
  return props;
}

@Entry
@Component
struct PaywallPage {
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = "light";
  @State products: VipProduct[] = [];
  @State selectedProductId: string = "";
  @State loadingProducts: boolean = true;
  @State paymentStatus: string = "idle";
  @State agreed: boolean = false;
  @State bottomInset: number = 12;
  private entrySource: string = "unknown";
  private proUnlock: boolean = false;
  private membershipCenter: boolean = false;
  private proUnlockReason: string = "";
  private afterOnboarding: boolean = false;
  private openedAtMs: number = 0;
  private paywallClosedTracked: boolean = false;

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
    });
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }
    if (!FeatureFlagStore.isPromoVipOn()) {
      pushRoute(PageRoutes.Redeem);
      return;
    }
    const routeParams = router.getParams() as Record<string, Object>;
    this.entrySource = resolveEntrySource(routeParams);
    this.proUnlock = resolveProUnlock(routeParams);
    this.proUnlockReason = resolveProUnlockReason(routeParams);
    this.afterOnboarding = String(routeParams?.["after_onboarding"] ?? "") === "1";
    const surfaceMembership = String(routeParams?.["surface"] ?? "") === "membership";
    this.membershipCenter = surfaceMembership;
    if (surfaceMembership) {
      router.replaceUrl({
        url: PageRoutes.Membership,
        params: {
          "entry_source": this.entrySource,
        },
      }).catch((error: Error) => {
        console.warn(`[Paywall] redirect membership failed: ${String(error)}`);
      });
      return;
    }
    this.openedAtMs = Date.now();
    this.paywallClosedTracked = false;
    AnalyticsService.trackEvent("paywall_opened", this.buildPaywallContextProps());
    void this.loadProducts();
  }

  aboutToDisappear(): void {
    this.trackPaywallClosed("navigate_away");
    if (this.afterOnboarding) {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      completeOnboardingAfterPaywall(hostContext);
    }
  }

  private exitPaywall(closeAction: string): void {
    this.trackPaywallClosed(closeAction);
    if (this.afterOnboarding) {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      completeOnboardingAfterPaywall(hostContext);
      return;
    }
    backRoute();
  }

  private buildPaywallContextProps(product?: VipProduct | null): Record<string, Object> {
    const props: Record<string, Object> = {};
    props["screen_name"] = "paywall_index";
    props["entry_source"] = this.entrySource;
    props["placement"] = "paywall_index";
    props["purchase_source"] = "wechat";
    if (product) {
      props["product_id"] = product.product_id;
      props["period"] = product.period;
    }
    return props;
  }

  private trackPaywallClosed(closeAction: string): void {
    if (this.paywallClosedTracked) {
      return;
    }
    this.paywallClosedTracked = true;
    const product = this.getSelectedProduct();
    const props = this.buildPaywallContextProps(product);
    props["close_action"] = closeAction;
    props["dwell_ms"] = Date.now() - this.openedAtMs;
    AnalyticsService.trackEvent("paywall_closed", props);
  }

  private getSelectedProduct(): VipProduct | null {
    for (let i = 0; i < this.products.length; i++) {
      if (this.products[i].product_id === this.selectedProductId) {
        return this.products[i];
      }
    }
    return this.products.length > 0 ? this.products[0] : null;
  }

  private getMaxPeriod(): number {
    let max = 0;
    for (let i = 0; i < this.products.length; i++) {
      if (this.products[i].period > max) {
        max = this.products[i].period;
      }
    }
    return max;
  }

  private isCheckoutDisabled(): boolean {
    return (
      this.paymentStatus === "processing" ||
      this.products.length === 0 ||
      this.selectedProductId.length === 0
    );
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

  @Builder
  private buildCheckoutButtonLabel(): void {
    if (this.paymentStatus === "processing") {
      Text("处理中...").fontSize(17).fontWeight(FontWeight.Bold).fontColor(CHECKOUT_TEXT);
    } else if (!this.getSelectedProduct()) {
      Text("请选择套餐").fontSize(17).fontWeight(FontWeight.Bold).fontColor(CHECKOUT_TEXT);
    } else {
      Text(getCheckoutButtonText(this.getSelectedProduct()))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(CHECKOUT_TEXT);
    }
  }

  private async loadProducts(): Promise<void> {
    this.loadingProducts = true;
    const list = await SubscriptionApiService.listVipProducts();
    const visible: VipProduct[] = [];
    for (let i = 0; i < list.length; i++) {
      const product = list[i];
      if (this.membershipCenter || product.period < 12) {
        if (!this.proUnlock || product.period === 2) {
          visible.push(product);
        }
      }
    }
    const sorted = visible.slice().sort((a, b) => b.period - a.period);
    this.products = sorted;
    let selected = sorted.length > 0 ? sorted[0].product_id : "";
    for (let i = 0; i < sorted.length; i++) {
      if (sorted[i].period === 2) {
        selected = sorted[i].product_id;
        break;
      }
    }
    this.selectedProductId = selected;
    this.loadingProducts = false;
  }

  private async doCheckout(): Promise<void> {
    const product = this.getSelectedProduct();
    if (!product) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const productProps = buildProductTrackProps(product, this.entrySource);
    AnalyticsService.trackEvent("paywall_purchase_clicked", productProps);
    AnalyticsService.trackEvent("purchase_started", productProps);
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
        AnalyticsService.trackEvent("purchase_cancelled", productProps);
        return;
      }
      if (!payResult.ok) {
        throw new Error(payResult.message || "支付失败");
      }
      const synced = await SubscriptionApiService.waitForEntitlement(order.out_trade_no);
      await BenefitStore.refresh();
      if (!synced && !BenefitStore.getState().isSubscribed) {
        this.paymentStatus = "success";
        productProps["is_entitled"] = false;
        AnalyticsService.trackEvent("purchase_completed", productProps);
        showToast("支付已到账，会员权益同步稍慢，请稍后刷新查看", this.getUIContext(), 2500);
        this.exitPaywall("purchase_success");
        return;
      }
      this.paymentStatus = "success";
      productProps["is_entitled"] = true;
      AnalyticsService.trackEvent("purchase_completed", productProps);
      showToast("开通成功，权益已生效", this.getUIContext());
      this.exitPaywall("purchase_success");
    } catch (error) {
      this.paymentStatus = "failed";
      productProps["error_code"] = "PURCHASE_FAILED";
      productProps["error_message"] = String(error);
      AnalyticsService.trackEvent("purchase_failed", productProps);
      showErrorToast(String(error), this.getUIContext());
    }
  }

  @Builder
  private buildBenefitRow(text: string): void {
    Row({ space: 8 }) {
      SymbolGlyph($r("sys.symbol.checkmark_circle"))
        .fontSize(22)
        .fontColor([CHECK_BLUE])
      Text(text)
        .fontSize(15)
        .lineHeight(22)
        .fontColor(AppTheme.colors.textSecondary)
    }.alignItems(VerticalAlign.Center);
  }

  @Builder
  private buildPromoBadge(): void {
    Text("限时特惠")
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor("#FFFFFF")
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .backgroundColor(TRIAL_GREEN)
      .borderRadius(4);
  }

  @Builder
  private buildRecommendedBadge(): void {
    Text("更多用户选择")
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor("#FFFFFF")
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .backgroundColor(TRIAL_GREEN)
      .borderRadius(4);
  }

  @Builder
  private buildProductCard(product: VipProduct): void {
    Column({ space: 0 }) {
      Row() {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Text(getPlanTitle(product.period))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textPrimary)
            if (product.period === 2) {
              this.buildPromoBadge();
            } else if (product.period >= 12 && product.period === this.getMaxPeriod()) {
              this.buildRecommendedBadge();
            }
          }.alignItems(VerticalAlign.Center)
          Text(`${getPlanDuration(product.period)} · ${formatPrice(product.price)}`)
            .fontSize(13)
            .fontColor(AppTheme.colors.textMuted)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Row({ space: 0 }) {
          Text(formatWeeklyPrice(product))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)
          Text("/周")
            .fontSize(13)
            .fontColor(AppTheme.colors.textMuted)
            .margin({ bottom: 4 })
        }.alignItems(VerticalAlign.Bottom)
      }
      .width("100%")
      .alignItems(VerticalAlign.Center)
    }
    .width("100%")
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor(
      product.product_id === this.selectedProductId
        ? AppTheme.colors.paywallCardSelected
        : AppTheme.colors.surface,
    )
    .border({
      width: 2,
      color: product.product_id === this.selectedProductId ? GOLD : AppTheme.colors.border,
    })
    .borderRadius(18)
    .onClick(() => {
      this.selectedProductId = product.product_id;
      AnalyticsService.trackEvent(
        "paywall_product_selected",
        buildProductTrackProps(product, this.entrySource),
      );
    });
  }

  private getPaywallTitle(): string {
    if (this.membershipCenter) {
      return "会员中心";
    }
    return this.proUnlock ? PRO_UNLOCK_TITLE : "开通 Pro 会员";
  }

  private openMembershipCenter(): void {
    router.pushUrl({
      url: PageRoutes.Membership,
      params: {
        "entry_source": this.entrySource,
      },
    }).catch((error: Error) => {
      console.warn(`[Paywall] open membership failed: ${String(error)}`);
    });
  }

  private getPaywallSubtitle(): string {
    if (this.proUnlockReason.length > 0) {
      return this.proUnlockReason;
    }
    if (this.proUnlock) {
      return PRO_UNLOCK_DEFAULT_SUBTITLE;
    }
    return "解锁全部专注能力，开通后立即生效";
  }

  private getPaywallSubtitleColor(): string {
    if (this.proUnlockReason.length > 0) {
      return isDarkThemeMode() ? '#E8C878' : '#A16207';
    }
    return AppTheme.colors.textSecondary;
  }

  private isPaywallSubtitleEmphasized(): boolean {
    return this.proUnlockReason.length > 0;
  }

  @Builder
  private buildScrollBody(): void {
    Column({ space: 0 }) {
      Text(this.getPaywallTitle())
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .width("100%")
        .textAlign(TextAlign.Center)
        .margin({ bottom: 8 })
      Text(this.getPaywallSubtitle())
        .fontSize(15)
        .lineHeight(22)
        .fontWeight(this.isPaywallSubtitleEmphasized() ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.getPaywallSubtitleColor())
        .width("100%")
        .textAlign(TextAlign.Center)
        .margin({ bottom: 32 })
      Column({ space: 10 }) {
        ForEach(
          BENEFITS,
          (text: string) => {
            this.buildBenefitRow(text);
          },
          (text: string) => text,
        )
      }
      .alignItems(HorizontalAlign.Start)
      .alignSelf(ItemAlign.Center)
      .margin({ bottom: 48 })

      if (this.loadingProducts) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(GOLD)
        }
        .width("100%")
        .height(120)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else if (this.products.length === 0) {
        Text("暂未开放")
          .fontSize(15)
          .fontColor(AppTheme.colors.textMuted)
          .width("100%")
          .textAlign(TextAlign.Center)
          .padding({ top: 24, bottom: 24 });
      } else {
        Column({ space: 12 }) {
          ForEach(
            this.products,
            (product: VipProduct) => {
              this.buildProductCard(product);
            },
            (product: VipProduct) => product.product_id,
          )
        }.width("100%");
      }
    }
    .width("100%")
    .padding({ bottom: 12 })
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildCheckoutFooter(): void {
    Column({ space: 10 }) {
      Button({ type: ButtonType.Normal }) {
        this.buildCheckoutButtonLabel()
      }
      .width("100%")
      .height(54)
      .buttonStyle(ButtonStyleMode.NORMAL)
      .backgroundColor(GOLD)
      .borderRadius(27)
      .clip(true)
      .enabled(!this.isCheckoutDisabled())
      .opacity(this.isCheckoutDisabled() ? 0.55 : 1)
      .onClick(() => {
        this.onCheckout();
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
      .alignItems(VerticalAlign.Center)

      if (this.proUnlock && !this.membershipCenter) {
        Text("更多套餐")
          .fontSize(13)
          .fontColor(AppTheme.colors.primary)
          .margin({ top: 8 })
          .onClick(() => {
            this.openMembershipCenter();
          })
      }
    }
    .width("100%")
    .padding({
      left: 0,
      right: 0,
      top: 12,
      bottom: this.bottomInset,
    })
    .backgroundColor(AppTheme.colors.background);
  }

  @Builder
  private buildContent(): void {
    Column() {
      Scroll() {
        Column() {
          Blank().layoutWeight(4)
          this.buildScrollBody()
          Blank().layoutWeight(6)
        }
        .width("100%")
        .constraintSize({ minHeight: "100%" })
      }
      .layoutWeight(1)
      .width("100%")
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)

      this.buildCheckoutFooter()
    }
    .width("100%")
    .height("100%")
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Stack() {
      SystemNavPage({
        title: "",
        showBack: true,
        usePageScroll: false,
        horizontalPadding: 20,
        bottomSpacerHeight: 0,
        onBack: () => {
          this.exitPaywall("close_button");
        },
        useFloatingTabInset: false,
        content: (): void => {
          this.buildContent();
        },
      })
    }
    .width("100%")
    .height("100%");
  }
}

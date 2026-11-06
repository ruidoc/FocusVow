import { common } from "@kit.AbilityKit";
import { router } from "@kit.ArkUI";
import { showErrorToast, showToast } from "../../common/Toast";
import { LegalUrls } from "../../constants/LegalUrls";
import { PageRoutes, pushWebView } from "../../router/PageRoutes";
import { AnalyticsService } from "../../services/AnalyticsService";
import {
  SubscriptionApiService,
  VipProduct,
  WeChatPayOrderData,
} from "../../services/SubscriptionApiService";
import { WeChatOpenService, WeChatPayParams } from "../../services/WeChatOpenService";
import { BenefitStore } from "../../stores/BenefitStore";
import { FeatureFlagStore } from "../../stores/FeatureFlagStore";
import { StoreKeys } from "../../stores/StoreKeys";
import { mergeQuickPayDisplayCopy, QuickPayDisplayCopy } from "../../utils/ProQuickPayCopy";
import {
  isProductCouponDeal,
  isWechatCouponActive,
  planPromoEndsAt,
  quickPayBadgeLabel,
  quickPayCtaLabel,
  resolveQuickPayProduct,
} from "../../utils/PaywallUtil";

/** 快付弹窗固定亮色壳，与 RN ConfirmationModal gold + Colors.light 一致，不跟随 App 暗黑 */
const GOLD_LINE1: string = "#B8741A";
const GOLD_HIGHLIGHT: string = "#FFE08A";
const GOLD_ACCENT_DEEP: string = "#C45A00";
const TRIAL_GREEN: string = "#16A34A";
const LIMITED_OFFER_GIFT: string = "#FFF0D4";
const RESTORE_PRICE: string = "#F59E0B";
const SHELL_BG: string = "#F5F7FB";
const SHELL_TOP: string = "#FFF7EB";
const LIGHT_TEXT: string = "#0F172A";
const LIGHT_TEXT3: string = "#94A3B8";
const PRICE_FONT_SIZE: number = 60;
const SUFFIX_FONT_SIZE: number = 24;
const ARROW_SIZE: number = 35;
const BADGE_FONT_SIZE: number = 13;
const SHEET_CORNER_RADIUS: number = 24;
const SHEET_SIDE_INSET: number = 8;
/** 角标浮在「元升级」行上方，不参与底对齐 */
const BADGE_FLOAT_ABOVE_SUFFIX: number = 20;
/** 负值把字形沉到字框底边，消掉数字字框底部留白 */
const PRICE_GLYPH_SINK: number = -14;
const SUFFIX_GLYPH_SINK: number = -4;

function yuanText(fen: number): string {
  const yuan = Math.round(fen) / 100;
  const rounded = Math.round(yuan * 100) / 100;
  if (Number.isInteger(rounded)) {
    return `${rounded}`;
  }
  return rounded.toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
}

function closeQuickPay(): void {
  AppStorage.setOrCreate(StoreKeys.ProQuickPayVisible, false);
  AppStorage.setOrCreate(StoreKeys.ProQuickPaySource, "");
  AppStorage.setOrCreate(StoreKeys.ProQuickPayReason, "");
  AppStorage.setOrCreate(StoreKeys.ProQuickPayTitle, "");
  AppStorage.setOrCreate(StoreKeys.ProQuickPayLine2, "");
}
@Component
export struct ProQuickPayHost {
  @Prop hostId: string = "main";
  @StorageLink(StoreKeys.ProQuickPayVisible) @Watch("syncSheet") visible: boolean = false;
  @StorageLink(StoreKeys.ProQuickPayForegroundHost) @Watch("syncSheet") foregroundHost: string = "main";
  @StorageLink(StoreKeys.ProQuickPaySource) source: string = "";
  @StorageLink(StoreKeys.ProQuickPayReason) reason: string = "";
  @StorageLink(StoreKeys.ProQuickPayTitle) title: string = "";
  @StorageLink(StoreKeys.ProQuickPayLine2) line2Override: string = "";
  @State private sheetOpen: boolean = false;
  private presenting: boolean = false;
  @State private product: VipProduct | null = null;
  @State private paying: boolean = false;
  @State private promoEndsAt: number = 0;
  @State private promoTick: number = 0;
  @State private catalog: VipProduct[] = [];
  private quickPayOpenedAtMs: number = 0;
  private quickPayClosedTracked: boolean = false;
  private promoTimerId: number = -1;

  aboutToAppear(): void {
    this.syncSheet();
  }

  aboutToDisappear(): void {
    this.clearPromoTimer();
  }

  private clearPromoTimer(): void {
    if (this.promoTimerId >= 0) {
      clearInterval(this.promoTimerId);
      this.promoTimerId = -1;
    }
  }

  private refreshPromoState(): void {
    const product = this.product;
    if (!product) {
      this.promoEndsAt = 0;
      return;
    }
    const endsAt = planPromoEndsAt(product, this.catalog);
    this.promoEndsAt = endsAt ?? 0;
  }

  private startPromoTimer(): void {
    this.clearPromoTimer();
    this.promoTimerId = setInterval(() => {
      this.promoTick++;
      if (this.promoEndsAt > 0 && this.promoEndsAt <= Date.now()) {
        void this.loadProduct();
      }
    }, 1000);
  }

  private async onSheetOpen(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    void FeatureFlagStore.sync(hostContext);
    void this.loadProduct();
  }

  private syncSheet(): void {
    const show = this.visible && this.foregroundHost === this.hostId;
    if (show) {
      if (!this.presenting) {
        this.presenting = true;
        this.quickPayClosedTracked = false;
        this.quickPayOpenedAtMs = Date.now();
        AnalyticsService.trackEvent("paywall_opened", this.buildQuickPayTrackProps());
        void this.onSheetOpen();
      }
      if (!this.sheetOpen) {
        this.sheetOpen = true;
      }
      return;
    }
    if (this.sheetOpen) {
      this.sheetOpen = false;
    }
    if (!this.presenting) {
      return;
    }
    this.presenting = false;
    this.paying = false;
    if (!this.visible) {
      this.trackQuickPayClosed("dismiss");
    }
  }

  private buildQuickPayTrackProps(): Record<string, Object> {
    const props: Record<string, Object> = {};
    props["paywall_name"] = "paywall_quick";
    props["entry_source"] = this.source;
    props["purchase_intent"] = "subscribe";
    const product = this.product;
    if (product) {
      props["product_id"] = product.product_id;
      props["period"] = product.period;
      props["price"] = product.price;
      props["currency"] = "CNY";
    }
    return props;
  }

  private trackQuickPayClosed(closeAction: string): void {
    if (this.quickPayClosedTracked) {
      return;
    }
    this.quickPayClosedTracked = true;
    const props = this.buildQuickPayTrackProps();
    props["close_action"] = closeAction;
    props["dwell_ms"] = Date.now() - this.quickPayOpenedAtMs;
    AnalyticsService.trackEvent("paywall_closed", props);
  }

  private displayCopy(): QuickPayDisplayCopy {
    return mergeQuickPayDisplayCopy(this.source, this.reason, this.title, this.line2Override);
  }

  private ctaLabel(): string {
    if (!this.product) {
      return "请选择套餐";
    }
    return quickPayCtaLabel(this.product.period);
  }

  private async loadProduct(): Promise<void> {
    const list = await SubscriptionApiService.listVipProducts();
    this.catalog = list;
    this.product = resolveQuickPayProduct(list);
    this.refreshPromoState();
    this.startPromoTimer();
  }

  private dismiss(): void {
    closeQuickPay();
    this.visible = false;
  }

  private openFullPaywall(): void {
    AnalyticsService.trackEvent(
      "paywall_more_plans_clicked",
      this.buildQuickPayTrackProps(),
    );
    this.trackQuickPayClosed("more_plans");
    const params: Record<string, Object> = {};
    params["entry_source"] = this.source;
    this.dismiss();
    router.pushUrl({ url: PageRoutes.Membership, params }).catch(() => {});
  }

  private async pay(): Promise<void> {
    const product = this.product;
    if (!product || this.paying) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const props = this.buildQuickPayTrackProps();
    props["purchase_source"] = "wechat";
    AnalyticsService.trackEvent("paywall_purchase_clicked", props);
    AnalyticsService.trackEvent("purchase_started", props);
    this.paying = true;
    try {
      const order: WeChatPayOrderData | null =
        await SubscriptionApiService.createWechatSubscriptionOrder(product.product_id);
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
        this.paying = false;
        AnalyticsService.trackEvent("purchase_cancelled", props);
        return;
      }
      if (!payResult.ok) {
        throw new Error(payResult.message || "支付失败");
      }
      await SubscriptionApiService.waitForEntitlement(order.out_trade_no);
      await BenefitStore.refresh();
      props["is_entitled"] = BenefitStore.isMemberActive();
      AnalyticsService.trackEvent("purchase_completed", props);
      showToast("开通成功，权益已生效", this.getUIContext());
      this.paying = false;
      this.trackQuickPayClosed("purchase_success");
      this.dismiss();
    } catch (error) {
      this.paying = false;
      props["error_message"] = String(error);
      AnalyticsService.trackEvent("purchase_failed", props);
      showErrorToast(String(error), this.getUIContext());
    }
  }

  private hasSceneLine2(): boolean {
    return this.displayCopy().line2.length > 0;
  }

  private sceneLine2Text(): string {
    return this.displayCopy().line2;
  }

  @Builder
  private buildLine2(): void {
    if (this.hasSceneLine2()) {
      Text(this.sceneLine2Text())
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(LIGHT_TEXT)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width("100%")
        .margin({ top: 8 });
    } else {
      Flex({
        direction: FlexDirection.Row,
        alignItems: ItemAlign.Center,
        justifyContent: FlexAlign.Center,
      }) {
        Text("现在升级 ")
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(LIGHT_TEXT)
        Stack({ alignContent: Alignment.Bottom }) {
          Row()
            .width(42)
            .height(12)
            .borderRadius(6)
            .backgroundColor(GOLD_HIGHLIGHT)
            .opacity(0.85)
            .margin({ bottom: 4 })
          Text("Pro")
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(LIGHT_TEXT)
        }
        Text(" 更划算")
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(LIGHT_TEXT)
      }
      .width("100%")
      .margin({ top: 8 });
    }
  }

  private loadedProductPrice(): number {
    const product = this.product;
    if (!product) {
      return 0;
    }
    const endsAt = product.coupon_ends_at;
    if (typeof endsAt === "number" && !isWechatCouponActive(endsAt)) {
      const delta = product.coupon_delta_fen ?? 0;
      if (delta > 0) {
        return product.price + delta;
      }
      if (product.original_price > 0) {
        return product.original_price;
      }
    }
    return product.price;
  }

  private showCouponPromoLine(): boolean {
    if (this.promoEndsAt > 0) {
      return true;
    }
    return this.product !== null && this.product.period === 2;
  }

  private promoRemainText(): string {
    const now = Date.now() + (this.promoTick >= 0 ? 0 : 0);
    const totalSec = Math.max(0, Math.ceil((this.promoEndsAt - now) / 1000));
    const hours = Math.floor(totalSec / 3600);
    const minutes = Math.floor((totalSec % 3600) / 60);
    const seconds = totalSec % 60;
    const pad = (value: number): string => (value < 10 ? `0${value}` : `${value}`);
    return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
  }

  private showRestorePrice(): boolean {
    const product = this.product;
    if (!product || (product.coupon_delta_fen ?? 0) <= 0) {
      return false;
    }
    if (!isProductCouponDeal(product)) {
      return false;
    }
    return typeof product.coupon_ends_at === "number";
  }

  private restorePriceText(): string {
    const product = this.product;
    if (!product) {
      return "";
    }
    const fen = this.loadedProductPrice() + (product.coupon_delta_fen ?? 0);
    return `结束恢复 ¥${yuanText(fen)}`;
  }

  @Builder
  private buildPriceBlock(): void {
    if (!this.product) {
      Row() {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(LIGHT_TEXT)
      }
      .width("100%")
      .justifyContent(FlexAlign.Center)
      .margin({ top: 36 });
    } else {
      Row() {
        Text(yuanText(this.loadedProductPrice()))
          .fontSize(PRICE_FONT_SIZE)
          .lineHeight(PRICE_FONT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(LIGHT_TEXT)
          .letterSpacing(-3)
          .baselineOffset(PRICE_GLYPH_SINK)
        Stack({ alignContent: Alignment.BottomStart }) {
          Row() {
            Text("元升级")
              .fontSize(SUFFIX_FONT_SIZE)
              .lineHeight(SUFFIX_FONT_SIZE)
              .fontWeight(FontWeight.Bold)
              .fontColor(LIGHT_TEXT)
              .baselineOffset(SUFFIX_GLYPH_SINK)
            Image($r("app.media.upgrade"))
              .width(ARROW_SIZE)
              .height(ARROW_SIZE)
              .objectFit(ImageFit.Contain)
              .margin({ left: 2 })
          }.alignItems(VerticalAlign.Bottom)
          Row() {
            Text(this.product ? quickPayBadgeLabel(this.product.period) : "双月 Pro")
              .fontSize(BADGE_FONT_SIZE)
              .lineHeight(BADGE_FONT_SIZE)
              .fontWeight(FontWeight.Bold)
              .fontColor("#5C2D00")
              .letterSpacing(0.3)
          }
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(12)
          .clip(true)
          .linearGradient({
            angle: 90,
            colors: [
              ["#FFC04A", 0],
              ["#FF8F1A", 1],
            ],
          })
          .position({
            x: 0,
            y: -BADGE_FLOAT_ABOVE_SUFFIX,
          })
        }
        .margin({ left: 8, bottom: 8 })
      }
      .alignItems(VerticalAlign.Bottom)
      .justifyContent(FlexAlign.Center)
      .alignSelf(ItemAlign.Center)
      .margin({ top: this.showCouponPromoLine() ? 24 : 36 });
    }
  }

  @Builder
  private buildCouponPromoLine(): void {
    Row({ space: 8 }) {
      Row({ space: 4 }) {
        SymbolGlyph($r("sys.symbol.gift"))
          .fontSize(13)
          .fontColor([LIMITED_OFFER_GIFT])
        Text(this.promoEndsAt > 0 ? "特惠仅剩" : "限时特惠")
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor("#FFFFFF")
      }
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(8)
      .backgroundColor(TRIAL_GREEN)
      .alignItems(VerticalAlign.Center)

      if (this.promoEndsAt > 0) {
        Text(this.promoRemainText())
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(TRIAL_GREEN)
          .letterSpacing(0.5)
      }
    }
    .justifyContent(FlexAlign.Center)
    .margin({ top: 10 })
  }

  @Builder
  private buildContentSlot(): void {
    Column() {
      Text(this.displayCopy().line1)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(GOLD_LINE1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width("100%")

      if (this.showCouponPromoLine()) {
        this.buildCouponPromoLine()
      } else {
        this.buildLine2()
      }
      this.buildPriceBlock()
      if (this.showRestorePrice()) {
        Text(this.restorePriceText())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(RESTORE_PRICE)
          .textAlign(TextAlign.Center)
          .margin({ top: 10 })
      }
      Row({ space: 12 }) {
        Text("升级即同意《付费服务协议》")
          .fontSize(12)
          .fontColor(LIGHT_TEXT3)
          .onClick(() => {
            pushWebView(LegalUrls.PAID_SERVICE, "付费服务协议");
          })
        Text("更多套餐")
          .fontSize(12)
          .fontColor(GOLD_ACCENT_DEEP)
          .onClick(() => {
            this.openFullPaywall();
          })
      }
      .width("100%")
      .justifyContent(FlexAlign.Start)
      .margin({ top: 22 })
    }
    .width("100%")
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 4 });
  }

  @Builder
  private buildSheetCard(): void {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        this.buildContentSlot()
        Row() {
          if (this.paying) {
            LoadingProgress().width(22).height(22).color("#FFF8EB");
          } else {
            Text(this.ctaLabel())
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor("#FFF8EB")
              .letterSpacing(0.5);
          }
        }
        .width("100%")
        .height(56)
        .margin({ top: 14 })
        .justifyContent(FlexAlign.Center)
        .borderRadius(28)
        .clip(true)
        .opacity(this.product && !this.paying ? 1 : 0.55)
        .linearGradient({
          angle: 135,
          colors: [
            ["#1F140C", 0],
            ["#3D2A1A", 0.5],
            ["#5C4530", 1],
          ],
        })
        .shadow({
          radius: 8,
          color: "#2C1E1247",
          offsetX: 0,
          offsetY: 4,
        })
        .onClick(() => {
          if (this.product && !this.paying) {
            void this.pay();
          }
        })
      }
      .width("100%")
      .padding({
        left: 24,
        right: 24,
        top: 36,
        bottom: 40,
      })
      .linearGradient({
        angle: 180,
        colors: [
          [SHELL_TOP, 0],
          [SHELL_BG, 1],
        ],
      })
      .backgroundColor(SHELL_BG)
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph($r("sys.symbol.xmark"))
          .fontSize(20)
          .fontColor([LIGHT_TEXT3])
      }
      .width(28)
      .height(28)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .margin({ top: 12, right: 12 })
      .onClick(() => {
        this.dismiss();
      })
    }
    .width("100%")
    .borderRadius({
      topLeft: SHEET_CORNER_RADIUS,
      topRight: SHEET_CORNER_RADIUS,
      bottomLeft: 0,
      bottomRight: 0,
    })
    .clip(true);
  }

  @Builder
  private sheetContent(): void {
    Column() {
      this.buildSheetCard()
    }
    .width("100%")
    .padding({ left: SHEET_SIDE_INSET, right: SHEET_SIDE_INSET });
  }

  build() {
    Column()
      .width(0)
      .height(0)
      .bindSheet($$this.sheetOpen, this.sheetContent(), {
        height: SheetSize.FIT_CONTENT,
        preferType: SheetType.BOTTOM,
        showClose: false,
        dragBar: false,
        backgroundColor: Color.Transparent,
        maskColor: "rgba(0, 0, 0, 0.5)",
        onDisappear: () => {
          if (this.foregroundHost === this.hostId) {
            closeQuickPay();
          }
          this.paying = false;
        },
      });
  }
}

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
import { FeatureFlagKeys } from "../../config/FeatureFlags";
import { FeatureFlagStore } from "../../stores/FeatureFlagStore";
import { StoreKeys } from "../../stores/StoreKeys";
import { mergeQuickPayDisplayCopy, QuickPayDisplayCopy } from "../../utils/ProQuickPayCopy";

/** 快付弹窗固定亮色壳，与 RN ConfirmationModal gold + Colors.light 一致，不跟随 App 暗黑 */
const GOLD_LINE1: string = "#B8741A";
const GOLD_ACCENT_DEEP: string = "#C45A00";
const SHELL_BG: string = "#F5F7FB";
const SHELL_TOP: string = "#FFF7EB";
const LIGHT_TEXT: string = "#0F172A";
const LIGHT_TEXT2: string = "#64748B";
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
  const yuan = fen / 100;
  return Number.isInteger(yuan) ? `${yuan}` : yuan.toFixed(2);
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
  @StorageLink(StoreKeys.ProQuickPayVisible) @Watch("onVisibleChanged") visible: boolean = false;
  @StorageLink(StoreKeys.ProQuickPaySource) source: string = "";
  @StorageLink(StoreKeys.ProQuickPayReason) reason: string = "";
  @StorageLink(StoreKeys.ProQuickPayTitle) title: string = "";
  @StorageLink(StoreKeys.ProQuickPayLine2) line2Override: string = "";
  @StorageLink(StoreKeys.FeatureFlagsOff) featuresOff: string[] = [];
  @State private product: VipProduct | null = null;
  @State private paying: boolean = false;

  aboutToAppear(): void {
    if (this.visible) {
      void this.onSheetOpen();
    }
  }

  private async onSheetOpen(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    void FeatureFlagStore.sync(hostContext);
    void this.loadProduct();
  }

  private onVisibleChanged(): void {
    if (this.visible) {
      void this.onSheetOpen();
    } else {
      this.paying = false;
    }
  }

  private displayCopy(): QuickPayDisplayCopy {
    return mergeQuickPayDisplayCopy(this.source, this.reason, this.title, this.line2Override);
  }

  private showInviteAlt(): boolean {
    return !FeatureFlagStore.isFeatureOff(FeatureFlagKeys.QUICK_PAY_INVITE);
  }

  private ctaLabel(): string {
    if (!this.product) {
      return "请选择套餐";
    }
    return "升级双月Pro";
  }

  private async loadProduct(): Promise<void> {
    const list = await SubscriptionApiService.listVipProducts();
    let picked: VipProduct | null = null;
    for (let i = 0; i < list.length; i++) {
      if (list[i].period === 2) {
        picked = list[i];
        break;
      }
    }
    if (!picked && list.length > 0) {
      picked = list[0];
    }
    this.product = picked;
  }

  private dismiss(): void {
    closeQuickPay();
    this.visible = false;
  }

  private openFullPaywall(): void {
    const params: Record<string, Object> = {};
    params["entry_source"] = this.source;
    this.dismiss();
    router.pushUrl({ url: PageRoutes.Membership, params }).catch(() => {});
  }

  private openInviteRedeem(): void {
    const params: Record<string, Object> = {};
    params["entry_source"] = `pro_quick_pay_${this.source}`;
    this.dismiss();
    router.pushUrl({ url: PageRoutes.Redeem, params }).catch(() => {});
  }

  private async pay(): Promise<void> {
    const product = this.product;
    if (!product || this.paying) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const props: Record<string, Object> = {};
    props["screen_name"] = "pro_quick_pay";
    props["entry_source"] = this.source;
    props["product_id"] = product.product_id;
    props["period"] = product.period;
    props["price"] = product.price;
    props["currency"] = "CNY";
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
        Text("Pro")
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(LIGHT_TEXT)
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
    return this.product !== null ? this.product.price : 0;
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
            Text("双月 Pro")
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
      .margin({ top: 36 });
    }
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

      this.buildLine2()
      this.buildPriceBlock()
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

        if (this.showInviteAlt()) {
          Text("邀请好友，免费领 Pro ›")
            .fontSize(13)
            .lineHeight(20)
            .fontColor(LIGHT_TEXT2)
            .textAlign(TextAlign.Center)
            .width("100%")
            .margin({ top: 14 })
            .onClick(() => {
              this.openInviteRedeem();
            });
        }
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
      .bindSheet($$this.visible, this.sheetContent(), {
        height: SheetSize.FIT_CONTENT,
        preferType: SheetType.BOTTOM,
        showClose: false,
        dragBar: false,
        backgroundColor: Color.Transparent,
        maskColor: "rgba(0, 0, 0, 0.5)",
        onDisappear: () => {
          closeQuickPay();
          this.paying = false;
        },
      });
  }
}

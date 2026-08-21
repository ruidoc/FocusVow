import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { LegalUrls } from '../../constants/LegalUrls';
import { VipProduct, SubscriptionApiService } from '../../services/SubscriptionApiService';
import { WeChatOpenService, WeChatPayParams } from '../../services/WeChatOpenService';
import { BenefitStore } from '../../stores/BenefitStore';
import { FeatureFlagStore } from '../../stores/FeatureFlagStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { UserStore } from '../../stores/UserStore';
import { backRoute, PageRoutes, pushRoute, pushWebView } from '../../router/PageRoutes';

bootstrapStores();

const BENEFITS: string[] = [
  '无限选择APP数量/分类',
  '不限制每日专注时长',
  '支持放行模式（应用白名单）',
  '内部专属群优先支持',
];

const PAGE_BG: string = '#F5F7FB';
const GOLD: string = '#D4A44A';
const TEXT: string = '#0F172A';
const TEXT_MUTED: string = '#64748B';
const BORDER: string = '#E5E7EB';
const CARD: string = '#FFFFFF';
const CARD_SELECTED: string = '#FFFBF0';

function formatPrice(fen: number): string {
  return `¥${(fen / 100).toFixed(2)}`;
}

function formatWeeklyPrice(product: VipProduct): string {
  const weeks =
    product.period >= 12 ? 52 : product.period === 7 ? 1 : Math.max(product.period, 1) * (30 / 7);
  return formatPrice(Math.round(product.price / weeks));
}

@Entry
@Component
struct PaywallPage {
  @State products: VipProduct[] = [];
  @State selectedProductId: string = '';
  @State loadingProducts: boolean = true;
  @State paymentStatus: string = 'idle';
  @State agreed: boolean = false;
  @State bottomInset: number = 12;

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
    void this.loadProducts();
  }

  private getSelectedProduct(): VipProduct | null {
    for (let i = 0; i < this.products.length; i++) {
      if (this.products[i].product_id === this.selectedProductId) {
        return this.products[i];
      }
    }
    return this.products.length > 0 ? this.products[0] : null;
  }

  private isCheckoutDisabled(): boolean {
    return this.paymentStatus === 'processing' ||
      this.products.length === 0 ||
      this.selectedProductId.length === 0;
  }

  private getCheckoutLabel(): string {
    if (this.paymentStatus === 'processing') {
      return '处理中...';
    }
    const product = this.getSelectedProduct();
    if (product) {
      return `立即开通 ${formatPrice(product.price)}`;
    }
    return '立即开通';
  }

  private async loadProducts(): Promise<void> {
    this.loadingProducts = true;
    const list = await SubscriptionApiService.listVipProducts();
    this.products = list;
    if (list.length > 0) {
      let best = list[0];
      for (let i = 1; i < list.length; i++) {
        if (list[i].period > best.period) {
          best = list[i];
        }
      }
      this.selectedProductId = best.product_id;
    }
    this.loadingProducts = false;
  }

  private async doCheckout(): Promise<void> {
    const product = this.getSelectedProduct();
    if (!product) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.paymentStatus = 'processing';
    try {
      const order = await SubscriptionApiService.createWechatSubscriptionOrder(product.product_id);
      if (!order) {
        throw new Error('下单失败');
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
        this.paymentStatus = 'idle';
        return;
      }
      if (!payResult.ok) {
        throw new Error(payResult.message || '支付失败');
      }
      const synced = await SubscriptionApiService.waitForEntitlement(order.out_trade_no);
      await BenefitStore.refresh();
      if (!synced && !BenefitStore.getState().isSubscribed) {
        this.paymentStatus = 'success';
        showToast('支付已到账，会员权益同步稍慢，请稍后刷新查看', this.getUIContext(), 2500);
        backRoute();
        return;
      }
      this.paymentStatus = 'success';
      showToast('开通成功，权益已生效', this.getUIContext());
      backRoute();
    } catch (error) {
      this.paymentStatus = 'failed';
      showErrorToast(String(error), this.getUIContext());
    }
  }

  private onCheckout(): void {
    if (!this.getSelectedProduct()) {
      return;
    }
    if (!this.agreed) {
      showToast('请先阅读并同意《付费服务协议》', this.getUIContext());
      return;
    }
    void this.doCheckout();
  }

  @Builder
  private buildBenefitRow(text: string): void {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.checkmark_circle'))
        .fontSize(18)
        .fontColor(['#16A34A'])
      Text(text)
        .fontSize(15)
        .fontColor(TEXT_MUTED)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildProductCard(product: VipProduct): void {
    Column({ space: 0 }) {
      Row() {
        Column({ space: 4 }) {
          Text(product.name)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT)
          Text(`约 ${formatWeeklyPrice(product)}/周`)
            .fontSize(13)
            .fontColor(TEXT_MUTED)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(formatPrice(product.price))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor(product.product_id === this.selectedProductId ? CARD_SELECTED : CARD)
    .border({
      width: 2,
      color: product.product_id === this.selectedProductId ? GOLD : BORDER,
    })
    .borderRadius(18)
    .shadow({
      radius: product.product_id === this.selectedProductId ? 12 : 4,
      color: product.product_id === this.selectedProductId ? 'rgba(212,164,74,0.18)' : 'rgba(15,23,42,0.04)',
      offsetX: 0,
      offsetY: 2,
    })
    .onClick(() => {
      this.selectedProductId = product.product_id;
    })
  }

  @Builder
  private buildScrollBody(): void {
    Column({ space: 20 }) {
      Text('开通 Pro 会员')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT)
        .width('100%')
        .textAlign(TextAlign.Center)

      Column({ space: 10 }) {
        ForEach(BENEFITS, (text: string) => {
          this.buildBenefitRow(text);
        }, (text: string) => text)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(CARD)
      .borderRadius(18)
      .border({ width: 1, color: '#EEF1F6' })

      if (this.loadingProducts) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(GOLD)
        }
        .width('100%')
        .height(120)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.products.length === 0) {
        Text('暂未开放')
          .fontSize(15)
          .fontColor(TEXT_MUTED)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 24, bottom: 24 })
      } else {
        Column({ space: 12 }) {
          ForEach(this.products, (product: VipProduct) => {
            this.buildProductCard(product);
          }, (product: VipProduct) => product.product_id)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ bottom: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildCheckoutFooter(): void {
    Column({ space: 10 }) {
      Divider()
        .color('#E8EBF0')
        .strokeWidth(1)

      Button(this.getCheckoutLabel())
        .width('100%')
        .height(54)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#461702')
        .backgroundColor(GOLD)
        .borderRadius(27)
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
        Text('我已阅读并同意')
          .fontSize(11)
          .fontColor(TEXT_MUTED)
          .onClick(() => {
            this.agreed = !this.agreed;
          })
        Text('《付费服务协议》')
          .fontSize(11)
          .fontColor(TEXT)
          .onClick(() => {
            pushWebView(LegalUrls.PAID_SERVICE, '付费服务协议');
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      left: 0,
      right: 0,
      top: 12,
      bottom: this.bottomInset,
    })
    .backgroundColor(PAGE_BG)
  }

  @Builder
  private buildContent(): void {
    Column() {
      Scroll() {
        this.buildScrollBody()
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      this.buildCheckoutFooter()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '开通会员',
        showBack: true,
        usePageScroll: false,
        horizontalPadding: 20,
        bottomSpacerHeight: 0,
        onBack: () => {
          backRoute();
        },
        pageBackgroundColor: PAGE_BG,
        titleBarBackgroundColor: PAGE_BG,
        useFloatingTabInset: false,
        content: (): void => {
          this.buildContent();
        },
      })
    }
    .width('100%')
    .height('100%');
  }
}

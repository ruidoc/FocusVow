import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { LegalUrls } from '../../constants/LegalUrls';
import { AppTheme } from '../../constants/Theme';
import { PageRoutes, pushRoute, pushWebView } from '../../router/PageRoutes';
import { AnalyticsService } from '../../services/AnalyticsService';
import { SubscriptionApiService, VipProduct, WeChatPayOrderData } from '../../services/SubscriptionApiService';
import { WeChatOpenService, WeChatPayParams } from '../../services/WeChatOpenService';
import { BenefitStore } from '../../stores/BenefitStore';
import { StoreKeys } from '../../stores/StoreKeys';

const GOLD: string = '#B8741A';

function yuanText(fen: number): string {
  const yuan = fen / 100;
  return Number.isInteger(yuan) ? `${yuan}` : yuan.toFixed(2);
}

function quickLines(source: string, reason: string): string[] {
  if (reason.length > 0) {
    return [reason, '现在升级 Pro 更划算'];
  }
  if (source === 'quick_task_slot' || source === 'quick_task_limit') {
    return ['免费可用 2 个快捷任务', '现在升级 Pro 更划算'];
  }
  if (source === 'scheduled_task_slot' || source === 'scheduled_task_limit') {
    return ['免费可用 1 条定时任务', '现在升级 Pro 更划算'];
  }
  if (source === 'cycle_guard') {
    return ['短视频限额为 Pro 专属', '升级解锁防沉迷强锁'];
  }
  if (source === 'scheduled_duo') {
    return ['定时互督为 Pro 专属', '升级立即发起定时搭子'];
  }
  if (source === 'delayed_start_limit') {
    return ['免费延时今日已用完', '升级享无限延时专注'];
  }
  if (source === 'membership_expiring') {
    return ['会员权益即将到期', '续费畅享无限专注'];
  }
  if (source === 'membership_last_day') {
    return ['会员还剩最后 1 天', '现在续订特惠升级'];
  }
  if (source === 'membership_expired') {
    return ['会员已到期任务已暂停', '立即续订恢复特权'];
  }
  return ['免费版额度已用完', '现在升级 Pro 更划算'];
}

function closeQuickPay(): void {
  AppStorage.setOrCreate(StoreKeys.ProQuickPayVisible, false);
}

@CustomDialog
export struct ProQuickPayDialog {
  controller: CustomDialogController;
  @StorageLink(StoreKeys.ProQuickPaySource) source: string = '';
  @StorageLink(StoreKeys.ProQuickPayReason) reason: string = '';
  @StorageLink(StoreKeys.ThemeMode) themeMode: string = 'light';
  @State product: VipProduct | null = null;
  @State paying: boolean = false;

  aboutToAppear(): void {
    void this.loadProduct();
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

  private lineAt(index: number): string {
    const lines = quickLines(this.source, this.reason);
    return index === 0 ? lines[0] : lines[1];
  }

  private dismiss(): void {
    closeQuickPay();
    this.controller.close();
  }

  private async pay(): Promise<void> {
    const product = this.product;
    if (!product || this.paying) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const props: Record<string, Object> = {};
    props['screen_name'] = 'pro_quick_pay';
    props['entry_source'] = this.source;
    props['product_id'] = product.product_id;
    props['period'] = product.period;
    props['price'] = product.price;
    props['currency'] = 'CNY';
    props['purchase_source'] = 'wechat';
    AnalyticsService.trackEvent('paywall_purchase_clicked', props);
    AnalyticsService.trackEvent('purchase_started', props);
    this.paying = true;
    try {
      const order: WeChatPayOrderData | null = await SubscriptionApiService.createWechatSubscriptionOrder(product.product_id);
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
        this.paying = false;
        AnalyticsService.trackEvent('purchase_cancelled', props);
        return;
      }
      if (!payResult.ok) {
        throw new Error(payResult.message || '支付失败');
      }
      await SubscriptionApiService.waitForEntitlement(order.out_trade_no);
      await BenefitStore.refresh();
      props['is_entitled'] = BenefitStore.isMemberActive();
      AnalyticsService.trackEvent('purchase_completed', props);
      showToast('开通成功，权益已生效', this.getUIContext());
      this.paying = false;
      this.dismiss();
    } catch (error) {
      this.paying = false;
      props['error_message'] = String(error);
      AnalyticsService.trackEvent('purchase_failed', props);
      showErrorToast(String(error), this.getUIContext());
    }
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Blank().layoutWeight(1)
        Text('关闭')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .onClick(() => {
            this.dismiss();
          })
      }
      .width('100%')

      Text(this.lineAt(0))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(GOLD)
        .width('100%')
        .textAlign(TextAlign.Center)
      Text(this.lineAt(1))
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
        .textAlign(TextAlign.Center)

      if (this.product) {
        Text(`${yuanText(this.product.price)}元`)
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
        Text('双月 Pro · 微信一次性支付')
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
      } else {
        LoadingProgress().width(28).height(28)
      }

      Button(this.paying ? '处理中...' : '升级双月Pro')
        .width('100%')
        .height(48)
        .enabled(!this.paying && this.product !== null)
        .onClick(() => {
          void this.pay();
        })

      Text('更多套餐')
        .fontSize(14)
        .fontColor(AppTheme.colors.primary)
        .onClick(() => {
          this.dismiss();
          pushRoute(PageRoutes.Membership);
        })

      Text('升级即同意《付费服务协议》')
        .fontSize(12)
        .fontColor(AppTheme.colors.textMuted)
        .onClick(() => {
          pushWebView(LegalUrls.PAID_SERVICE, '付费服务协议');
        })
    }
    .width(320)
    .padding(20)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(20)
  }
}

let quickPayClaimed: boolean = false;

@Component
export struct ProQuickPayHost {
  @StorageLink(StoreKeys.ProQuickPayVisible) @Watch('onVisibleChanged') visible: boolean = false;
  private opened: boolean = false;
  private dialog: CustomDialogController = new CustomDialogController({
    builder: ProQuickPayDialog({}),
    customStyle: true,
    autoCancel: true,
    alignment: DialogAlignment.Center,
    maskColor: 'rgba(0, 0, 0, 0.4)',
    cancel: () => {
      closeQuickPay();
    },
  });

  private onVisibleChanged(): void {
    if (this.visible) {
      if (quickPayClaimed || this.opened) {
        return;
      }
      quickPayClaimed = true;
      this.opened = true;
      this.dialog.open();
      return;
    }
    if (this.opened) {
      this.opened = false;
      quickPayClaimed = false;
      this.dialog.close();
    }
  }

  build() {
    Column()
      .width(0)
      .height(0)
  }
}

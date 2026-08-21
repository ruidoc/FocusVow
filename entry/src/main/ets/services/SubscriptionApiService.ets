import { HttpService } from './HttpService';
import { ApiEnvelope } from '../models/UserModel';
import { isPromoVipProductId } from '../config/FeatureFlags';

export interface VipProduct {
  id: string;
  name: string;
  period: number;
  product_id: string;
  price: number;
  original_price: number;
  is_subscription: number;
}

export interface WeChatPayOrderData {
  partnerId: string;
  prepayId: string;
  nonceStr: string;
  timeStamp: string;
  sign: string;
  out_trade_no: string;
}

export interface SubscriptionSnapshot {
  status: string;
  expires_at: string;
}

const ENTITLED_STATUSES: Set<string> = new Set(['active', 'canceled', 'cancelled']);

function asString(value: Object | undefined, fallback: string = ''): string {
  if (typeof value === 'string') {
    return value;
  }
  if (value === undefined || value === null) {
    return fallback;
  }
  return String(value);
}

function asNumber(value: Object | undefined, fallback: number = 0): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseVipProduct(raw: Object | undefined): VipProduct | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const data = raw as Record<string, Object>;
  const productId = asString(data['product_id']);
  if (!isPromoVipProductId(productId)) {
    return null;
  }
  const item: VipProduct = {
    id: asString(data['id']),
    name: asString(data['name']),
    period: asNumber(data['period'], 0),
    product_id: productId,
    price: asNumber(data['price'], 0),
    original_price: asNumber(data['original_price'], 0),
    is_subscription: asNumber(data['is_subscription'], 0),
  };
  return item;
}

function parseWeChatPayOrderData(raw: Object | undefined): WeChatPayOrderData | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const data = raw as Record<string, Object>;
  const order: WeChatPayOrderData = {
    partnerId: asString(data['partnerId']),
    prepayId: asString(data['prepayId']),
    nonceStr: asString(data['nonceStr']),
    timeStamp: asString(data['timeStamp']),
    sign: asString(data['sign']),
    out_trade_no: asString(data['out_trade_no']),
  };
  return order;
}

function parseSubscriptionSnapshot(raw: Object | undefined): SubscriptionSnapshot | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const data = raw as Record<string, Object>;
  const snapshot: SubscriptionSnapshot = {
    status: asString(data['status']),
    expires_at: asString(data['expires_at']),
  };
  return snapshot;
}

export class SubscriptionApiService {
  static async listVipProducts(): Promise<VipProduct[]> {
    const query: Record<string, string> = {
      'product_class': 'focus',
      'is_subscription': '1',
    };
    const response: ApiEnvelope = await HttpService.getWithQuery(
      '/product/list',
      query,
      true,
    );
    if (response.statusCode !== 200 || response.data === undefined) {
      return [];
    }
    const dataObj = response.data as Object;
    if (!Array.isArray(dataObj)) {
      return [];
    }
    const list = dataObj as Object[];
    const items: VipProduct[] = [];
    for (let i = 0; i < list.length; i++) {
      const parsed = parseVipProduct(list[i]);
      if (parsed) {
        items.push(parsed);
      }
    }
    items.sort((a: VipProduct, b: VipProduct) => a.period - b.period);
    return items;
  }

  static async createWechatSubscriptionOrder(productId: string): Promise<WeChatPayOrderData | null> {
    const body: Record<string, Object> = {
      'product_id': productId,
    };
    const response: ApiEnvelope = await HttpService.post(
      '/payment/wechat-subscription-app',
      body,
      true,
    );
    if (response.statusCode !== 200 || response.data === undefined) {
      throw new Error(response.message ?? '下单失败');
    }
    return parseWeChatPayOrderData(response.data as Object);
  }

  static async fetchSubscription(): Promise<SubscriptionSnapshot | null> {
    const response: ApiEnvelope = await HttpService.get('/subscription');
    if (response.statusCode !== 200 || response.data === undefined || response.data === null) {
      return null;
    }
    return parseSubscriptionSnapshot(response.data as Object);
  }

  static async confirmWechatPaid(outTradeNo: string): Promise<boolean> {
    if (outTradeNo.length === 0) {
      return false;
    }
    const body: Record<string, Object> = {
      'out_trade_no': outTradeNo,
    };
    const response: ApiEnvelope = await HttpService.post(
      '/payment/wechat-subscription-status',
      body,
      true,
    );
    if (response.statusCode !== 200 || response.data === undefined) {
      return false;
    }
    const data = response.data as Record<string, Object>;
    return data['is_paid'] === true || asString(data['trade_state']) === 'SUCCESS';
  }

  static isEntitled(subscription: SubscriptionSnapshot | null, now: Date = new Date()): boolean {
    if (!subscription) {
      return false;
    }
    if (subscription.status.length === 0 || subscription.expires_at.length === 0) {
      return false;
    }
    if (!ENTITLED_STATUSES.has(subscription.status)) {
      return false;
    }
    const expiresAt = new Date(subscription.expires_at);
    if (Number.isNaN(expiresAt.getTime())) {
      return false;
    }
    return expiresAt > now;
  }

  static async waitForEntitlement(
    outTradeNo: string = '',
    maxAttempts: number = 8
  ): Promise<boolean> {
    const delaysMs: number[] = [500, 800, 1200, 1500, 2000, 2500, 3000, 4000];
    const attempts = Math.min(maxAttempts, delaysMs.length);
    for (let i = 0; i < attempts; i++) {
      if (delaysMs[i] > 0) {
        await SubscriptionApiService.sleep(delaysMs[i]);
      }
      if (outTradeNo.length > 0) {
        await SubscriptionApiService.confirmWechatPaid(outTradeNo);
      }
      const subscription = await SubscriptionApiService.fetchSubscription();
      if (SubscriptionApiService.isEntitled(subscription)) {
        return true;
      }
    }
    return false;
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }
}

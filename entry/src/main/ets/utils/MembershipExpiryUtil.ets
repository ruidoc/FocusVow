import { common } from '@kit.AbilityKit';
import { UserStore } from '../stores/UserStore';
import { SubscriptionApiService, SubscriptionSnapshot } from '../services/SubscriptionApiService';
import { readStoredString, removeStoredKey, writeStoredString } from '../services/PreferencesService';
import { openVipPurchase } from './PaywallNavigationUtil';

const SNAP_KEY: string = 'membership_expiry_snap';
const PROMPT_KEY: string = 'membership_expiry_prompt';

const STORE_SOURCES: Set<string> = new Set(['app_store', 'google_play']);

interface Snap {
  expires_at: string;
  source: string;
  status: string;
  canceled_at: string;
}

interface PromptState {
  expiresAt: string;
  phases: string[];
  lastDate: string;
}

type Phase = 'soon' | 'last_day' | 'expired';

function todayKey(): string {
  const d = new Date();
  const month = d.getMonth() + 1 < 10 ? `0${d.getMonth() + 1}` : `${d.getMonth() + 1}`;
  const day = d.getDate() < 10 ? `0${d.getDate()}` : `${d.getDate()}`;
  return `${d.getFullYear()}-${month}-${day}`;
}

function readJson<T>(context: common.Context, key: string): T | null {
  const raw = readStoredString(context, key, '');
  if (raw.length === 0) {
    return null;
  }
  try {
    return JSON.parse(raw) as T;
  } catch (_e) {
    return null;
  }
}

function writeJson(context: common.Context, key: string, value: Object): void {
  writeStoredString(context, key, JSON.stringify(value));
}

function willAutoRenew(snap: Snap): boolean {
  if (!STORE_SOURCES.has(snap.source)) {
    return false;
  }
  if (snap.status === 'canceled' || snap.status === 'cancelled') {
    return false;
  }
  if (snap.canceled_at.length > 0) {
    return false;
  }
  return snap.status === 'active';
}

function remainingDays(expiresAt: string, now: number = Date.now()): number {
  const exp = new Date(expiresAt).getTime();
  if (Number.isNaN(exp)) {
    return 999;
  }
  return Math.ceil((exp - now) / (24 * 60 * 60 * 1000));
}

function phaseOf(days: number): Phase | null {
  if (days < -3) {
    return null;
  }
  if (days <= 0) {
    return 'expired';
  }
  if (days === 1) {
    return 'last_day';
  }
  if (days <= 3) {
    return 'soon';
  }
  return null;
}

export function rememberMembershipSnapshot(context: common.Context, sub: SubscriptionSnapshot | null): void {
  if (!sub || sub.expires_at.length === 0) {
    return;
  }
  const snap: Snap = {
    expires_at: sub.expires_at,
    source: '',
    status: sub.status,
    canceled_at: sub.status === 'canceled' || sub.status === 'cancelled' ? '1' : '',
  };
  writeJson(context, SNAP_KEY, snap);
}

export function clearMembershipExpiryPrompt(context: common.Context): void {
  removeStoredKey(context, SNAP_KEY);
  removeStoredKey(context, PROMPT_KEY);
}

/** 登录后 / 冷启动拉完订阅再调：临期 / 到期各阶段每天最多弹 1 次 */
export function maybePromptMembershipExpiry(
  context: common.Context,
  sub: SubscriptionSnapshot | null,
): void {
  if (!UserStore.isLoggedIn()) {
    return;
  }
  rememberMembershipSnapshot(context, sub);

  const snap = readJson<Snap>(context, SNAP_KEY);
  if (!snap || snap.expires_at.length === 0) {
    return;
  }

  const entitled = SubscriptionApiService.isEntitled(sub);
  const days = remainingDays(snap.expires_at);
  const phase = phaseOf(days);
  if (!phase) {
    return;
  }
  if (entitled && willAutoRenew(snap)) {
    return;
  }
  if (!entitled && phase !== 'expired') {
    return;
  }
  if (entitled && phase === 'expired') {
    return;
  }

  const prev = readJson<PromptState>(context, PROMPT_KEY);
  let state: PromptState = prev && prev.expiresAt === snap.expires_at
    ? prev
    : { expiresAt: snap.expires_at, phases: [], lastDate: '' };
  if (state.phases.indexOf(phase) >= 0) {
    return;
  }
  const today = todayKey();
  if (state.lastDate === today) {
    return;
  }

  const phases: string[] = [];
  for (let i = 0; i < state.phases.length; i++) {
    phases.push(state.phases[i]);
  }
  phases.push(phase);
  state.phases = phases;
  state.lastDate = today;
  writeJson(context, PROMPT_KEY, state);

  const entrySource =
    phase === 'expired'
      ? 'membership_expired'
      : phase === 'last_day'
        ? 'membership_last_day'
        : 'membership_expiring';
  openVipPurchase(entrySource, { proUnlock: true });
}

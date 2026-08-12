import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { DuoSessionView } from '../../models/DuoModel';
import { backRoute, returnToMainTab } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import {
  DuoInstantLockOptions,
  startOrAlignInstantDuoFocus
} from '../../services/DuoInstantLockService';
import { clearDuoWaitContext } from '../../services/DuoWaitContextService';
import { HttpService } from '../../services/HttpService';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

const MATCH_WAIT_MIN_SEC_DEFAULT: number = 10;
const MATCH_WAIT_MAX_SEC_DEFAULT: number = 45;
const BLUE_MAIN: string = '#2E90FA';
const BLUE_SOFT: string = '#E8F3FE';
const BLUE_WASH: string = '#E6F0FA';
const BLUE_RING: string = 'rgba(46, 144, 250, 0.18)';
const GREEN: string = '#10B981';

type MatchPhase = 'searching' | 'starting' | 'failed';

function randomMatchDelayMs(minMs: number, maxMs: number): number {
  const lo = Math.max(1000, minMs);
  const hi = Math.max(lo, maxMs);
  return lo + Math.floor(Math.random() * (hi - lo + 1));
}

function formatElapsed(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  const mm = String(m).padStart(2, '0');
  const ss = String(s).padStart(2, '0');
  return `${mm}:${ss}`;
}

@Entry
@Component
struct DuoMatchPage {
  @StorageLink(StoreKeys.SettingsSelectedTokens) selectedTokens: string[] = [];
  @State phase: MatchPhase = 'searching';
  @State elapsedSec: number = 0;
  @State title: string = '';
  @State pulseOn: boolean = false;

  private sessionId: string = '';
  private cancelled: boolean = false;
  private starting: boolean = false;
  private tickId: number = -1;
  private matchTimerId: number = -1;
  private pulseTimerId: number = -1;

  aboutToAppear(): void {
    this.sessionId = String(AppStorage.get<string>(StoreKeys.DuoWaitSessionId) ?? '');
    this.title = String(AppStorage.get<string>(StoreKeys.DuoWaitTitle) ?? '搭子互督');
    if (this.sessionId.length === 0) {
      backRoute();
      return;
    }
    this.startPulse();
    this.startMatchFlow();
  }

  aboutToDisappear(): void {
    this.cancelled = true;
    this.clearTimers();
  }

  private clearTimers(): void {
    if (this.tickId !== -1) {
      clearInterval(this.tickId);
      this.tickId = -1;
    }
    if (this.matchTimerId !== -1) {
      clearTimeout(this.matchTimerId);
      this.matchTimerId = -1;
    }
    if (this.pulseTimerId !== -1) {
      clearInterval(this.pulseTimerId);
      this.pulseTimerId = -1;
    }
  }

  private startPulse(): void {
    this.pulseTimerId = setInterval(() => {
      if (this.phase === 'searching') {
        this.pulseOn = !this.pulseOn;
      }
    }, 900);
  }

  private async fetchWaitRangeMs(): Promise<[number, number]> {
    const fallbackMin = MATCH_WAIT_MIN_SEC_DEFAULT * 1000;
    const fallbackMax = MATCH_WAIT_MAX_SEC_DEFAULT * 1000;
    try {
      const response = await HttpService.get('/config/static', false);
      if (response.statusCode !== 200 || !response.data) {
        return [fallbackMin, fallbackMax];
      }
      const data = response.data as Record<string, Object>;
      const duo = data['duo'] as Record<string, Object> | undefined;
      if (!duo) {
        return [fallbackMin, fallbackMax];
      }
      const minSec = Number(duo['online_match_wait_min_sec']);
      const maxSec = Number(duo['online_match_wait_max_sec']);
      const minMs =
        Number.isFinite(minSec) && minSec >= 1 ? Math.round(minSec * 1000) : fallbackMin;
      let maxMs =
        Number.isFinite(maxSec) && maxSec >= 1 ? Math.round(maxSec * 1000) : fallbackMax;
      if (maxMs < minMs) {
        maxMs = minMs;
      }
      return [minMs, maxMs];
    } catch (_e) {
      return [fallbackMin, fallbackMax];
    }
  }

  private startMatchFlow(): void {
    this.cancelled = false;
    this.starting = false;
    this.phase = 'searching';
    this.elapsedSec = 0;

    const startedAt = Date.now();
    this.tickId = setInterval(() => {
      this.elapsedSec = Math.floor((Date.now() - startedAt) / 1000);
    }, 250);

    void this.scheduleMatch();
  }

  private async scheduleMatch(): Promise<void> {
    const range = await this.fetchWaitRangeMs();
    if (this.cancelled) {
      return;
    }
    const delay = randomMatchDelayMs(range[0], range[1]);
    this.matchTimerId = setTimeout(() => {
      void this.performMatch();
    }, delay);
  }

  private async performMatch(): Promise<void> {
    if (this.cancelled || this.starting) {
      return;
    }
    this.starting = true;
    if (this.tickId !== -1) {
      clearInterval(this.tickId);
      this.tickId = -1;
    }
    this.phase = 'starting';

    const response = await DuoApiService.instantOnlineMatch(this.sessionId);
    if (this.cancelled) {
      return;
    }

    const session: DuoSessionView | null = DuoApiService.parseSession(response);
    if (!session || session.status !== 'active') {
      this.phase = 'failed';
      this.starting = false;
      showErrorToast(
        response.message && response.message.length > 0
          ? response.message
          : '匹配失败，请稍后重试',
        this.getUIContext()
      );
      backRoute();
      return;
    }

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const lockOptions: DuoInstantLockOptions = {
      alignToServerEnd: true,
      navigateHome: false,
      clearWait: true
    };
    const lockResult = await startOrAlignInstantDuoFocus(
      hostContext,
      session,
      this.selectedTokens,
      lockOptions
    );
    if (this.cancelled) {
      return;
    }
    if (!lockResult.ok) {
      this.phase = 'failed';
      this.starting = false;
      showErrorToast('锁机未成功开启，请返回首页重试', this.getUIContext());
      backRoute();
      return;
    }

    clearDuoWaitContext();
    showToast('匹配成功，专注已开启', this.getUIContext());
    returnToMainTab('focus');
  }

  private cancelMatch(): void {
    if (this.starting || this.phase === 'starting') {
      return;
    }
    this.cancelled = true;
    this.clearTimers();
    backRoute();
  }

  private statusText(): string {
    if (this.phase === 'starting') {
      return '匹配成功，正在开启专注…';
    }
    if (this.phase === 'failed') {
      return '匹配未完成';
    }
    if (this.elapsedSec < 8) {
      return '正在为你寻找搭子…';
    }
    if (this.elapsedSec < 20) {
      return '继续扩大匹配范围…';
    }
    return '马上就好，请稍候…';
  }

  private accentColor(): string {
    return this.phase === 'starting' ? GREEN : BLUE_MAIN;
  }

  private matched(): boolean {
    return this.phase === 'starting';
  }

  @Builder
  private buildAvatarPair(): void {
    Row({ space: 10 }) {
      Column({ space: 8 }) {
        Row() {
          SymbolGlyph($r('sys.symbol.person_fill'))
            .fontSize(28)
            .fontColor([this.accentColor()])
        }
        .width(64)
        .height(64)
        .justifyContent(FlexAlign.Center)
        .borderRadius(22)
        .backgroundColor(Color.White)
        .border({ width: 1.5, color: this.accentColor() })
        Text('我')
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
      }
      .alignItems(HorizontalAlign.Center)

      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(56)
          .height(2)
          .borderRadius(1)
          .backgroundColor(BLUE_RING)
        Row()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor(this.accentColor())
          .opacity(this.matched() ? 1 : (this.pulseOn ? 1 : 0.55))
      }
      .width(72)
      .height(24)

      Column({ space: 8 }) {
        Row() {
          SymbolGlyph(
            this.matched() ? $r('sys.symbol.checkmark') : $r('sys.symbol.person')
          )
            .fontSize(28)
            .fontColor([this.accentColor()])
        }
        .width(64)
        .height(64)
        .justifyContent(FlexAlign.Center)
        .borderRadius(22)
        .backgroundColor(this.matched() ? Color.White : BLUE_SOFT)
        .border({ width: 1.5, color: this.accentColor() })
        .opacity(this.matched() ? 1 : (this.pulseOn ? 0.95 : 0.55))
        Text(this.matched() ? '搭子' : '寻找中')
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
      }
      .alignItems(HorizontalAlign.Center)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(148)
  }

  @Builder
  private buildMatchContent(): void {
    Column() {
      Column({ space: 32 }) {
        this.buildAvatarPair()

        Column({ space: 8 }) {
          Text(formatElapsed(this.elapsedSec))
            .fontSize(40)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .letterSpacing(3)
          Text(this.statusText())
            .fontSize(15)
            .fontColor(AppTheme.colors.textSecondary)
            .textAlign(TextAlign.Center)
            .lineHeight(22)
        }
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 16 })

        Column({ space: 20 }) {
          if (this.phase === 'searching') {
            Button('取消匹配')
              .height(40)
              .padding({ left: 20, right: 20 })
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textSecondary)
              .backgroundColor(Color.White)
              .borderRadius(28)
              .onClick(() => {
                this.cancelMatch();
              })
          } else {
            Text('请稍候，不要离开')
              .fontSize(13)
              .fontColor(AppTheme.colors.textMuted)
          }
        }
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 48 })
      }
      .width('100%')
      .padding({ left: 32, right: 32, top: 72, bottom: 24 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BLUE_WASH)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '',
        showBack: true,
        usePageScroll: false,
        horizontalPadding: 0,
        bottomSpacerHeight: 0,
        topSpacerHeight: 8,
        titleBarBottomPadding: 0,
        onBack: () => {
          backRoute();
        },
        content: (): void => {
          this.buildMatchContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

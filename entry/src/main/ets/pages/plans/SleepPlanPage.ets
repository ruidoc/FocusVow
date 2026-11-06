import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { ProQuickPayHost } from '../../components/paywall/ProQuickPayDialog';
import { AppTheme } from '../../constants/Theme';
import {
  DuoSessionView,
  getScheduledListStatusLabel,
  getScheduledParticipationLabel,
  isInactiveScheduledSession,
} from '../../models/DuoModel';
import { parseSleepPlanStats, SleepPlanStats } from '../../models/SleepPlanModel';
import { summarizeRepeatDays } from '../../models/PlanModel';
import { minutesToHours } from '../../models/ActiveLockModel';
import {
  backRoute,
  PageRoutes,
  pushPlanAddSleep,
  pushRoute,
  pushSleepRecords,
} from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import { loadExitPlanIds } from '../../services/ExitPlanIdsService';
import {
  markGuardSyncIssue,
  removeGuardForSession,
  syncGuardForSession,
} from '../../services/ScheduledCovenantService';
import { toastIfScheduleOverlapsEnabled } from '../../services/ScheduledPlanValidation';
import { promptEnableScheduledSlot, upsellIfProSlotQuota } from '../../services/ProQuotaService';
import { markQuickPayForeground } from '../../utils/PaywallNavigationUtil';
import { ScheduledListStore } from '../../stores/ScheduledListStore';
import { LockStore } from '../../stores/LockStore';
import { UserStore } from '../../stores/UserStore';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import {
  clockDurationMinutes,
  inScheduledClockWindow,
  parseMinutesFromClock,
  repeatDaysOfSession,
  resolveSleepSession,
} from '../../utils/ScheduledClockUtil';

bootstrapStores();

const SLEEP_ACCENT_COLOR: string = '#06B6D4';

@Entry
@Component
struct SleepPlanPage {
  @StorageLink(StoreKeys.ScheduledListAll) allSessions: DuoSessionView[] = [];
  @StorageLink(StoreKeys.ScheduledListDirty) listDirty: boolean = true;
  @State session: DuoSessionView | null = null;
  @State stats: SleepPlanStats | null = null;
  @State loadingList: boolean = true;
  @State settingsOpen: boolean = false;
  @State switchEnabled: boolean = true;
  @State toggleBusy: boolean = false;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    UserStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    ScheduledListStore.hydrate();
    void this.reloadAll();
  }

  onPageShow(): void {
    markQuickPayForeground("sleep_plan");
    if (this.listDirty) {
      void this.reloadAll();
    } else {
      this.refreshSessionFromStore();
    }
  }

  private refreshSessionFromStore(): void {
    this.session = resolveSleepSession(this.allSessions);
    if (this.session && !this.toggleBusy) {
      this.switchEnabled = this.session.enabled !== false;
    }
    if (this.session) {
      void this.loadStats(this.session.session_id);
    } else {
      this.stats = null;
    }
  }

  private async reloadAll(): Promise<void> {
    this.loadingList = true;
    if (UserStore.isLoggedIn()) {
      const response = await DuoApiService.getScheduledList();
      const list = DuoApiService.parseScheduledList(response);
      if (response.statusCode === 200) {
        ScheduledListStore.setAllSessions(list.items);
        ScheduledListStore.clearDirty();
      }
    }
    this.refreshSessionFromStore();
    this.loadingList = false;
  }

  private async loadStats(sessionId: string): Promise<void> {
    const response = await DuoApiService.getScheduledStats(sessionId);
    if (response.statusCode === 200) {
      this.stats = parseSleepPlanStats(response.data as Record<string, Object>);
    }
  }

  private openCreate(): void {
    if (LockStore.isLocked()) {
      showToast('专注进行中，暂不可创建契约', this.getUIContext());
      return;
    }
    pushPlanAddSleep();
  }

  private openEdit(): void {
    if (!this.session) {
      return;
    }
    if (isInactiveScheduledSession(this.session) || this.session.editable === false) {
      showToast('当前契约不可编辑', this.getUIContext());
      return;
    }
    if (LockStore.isLocked()) {
      showToast('专注进行中，暂不可编辑契约', this.getUIContext());
      return;
    }
    const now = new Date();
    const startMin = parseMinutesFromClock(this.session.schedule_start || '22:30');
    const endMin = parseMinutesFromClock(this.session.schedule_end || '06:30', startMin + 60);
    if (
      this.session.status === 'active' &&
      inScheduledClockWindow(
        startMin,
        endMin,
        repeatDaysOfSession(this.session),
        now.getHours() * 60 + now.getMinutes(),
        now.getDay(),
      )
    ) {
      showToast('契约进行中，请结束后再编辑', this.getUIContext());
      return;
    }
    this.settingsOpen = false;
    ScheduledListStore.setEditingSession(this.session);
    pushRoute(PageRoutes.PlanAdd);
  }

  private async onToggleEnabled(next: boolean): Promise<void> {
    const current = this.session;
    if (!current || current.viewer_role !== 'initiator' || this.toggleBusy) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (next) {
      if (toastIfScheduleOverlapsEnabled(current)) {
        this.switchEnabled = current.enabled !== false;
        return;
      }
      if (!promptEnableScheduledSlot(current.session_id)) {
        this.switchEnabled = false;
        return;
      }
      this.toggleBusy = true;
      const response = await DuoApiService.scheduledUpdate(current.session_id, { enabled: true });
      const updated = DuoApiService.parseSession(response);
      this.toggleBusy = false;
      if (!updated || !updated.enabled) {
        const msg = response.message ?? '更新失败';
        if (!upsellIfProSlotQuota(msg, 'scheduled')) {
          showErrorToast(msg, this.getUIContext());
        }
        this.switchEnabled = false;
        return;
      }
      this.session = updated;
      this.switchEnabled = true;
      ScheduledListStore.patchSession(updated);
      const guardResult = await syncGuardForSession(hostContext, updated, updated.my_apps ?? []);
      if (!guardResult.ok) {
        markGuardSyncIssue(hostContext, updated, guardResult.message);
      }
      return;
    }
    const wasEnabled = current.enabled !== false;
    this.switchEnabled = false;
    current.enabled = false;
    this.session = current;
    ScheduledListStore.patchSession(current);
    await removeGuardForSession(hostContext, current.session_id);
    this.toggleBusy = true;
    const response = await DuoApiService.scheduledUpdate(current.session_id, { enabled: false });
    const updated = DuoApiService.parseSession(response);
    this.toggleBusy = false;
    if (!updated) {
      showErrorToast(response.message ?? '更新失败', this.getUIContext());
      void this.reloadAll();
      if (wasEnabled && this.session) {
        await syncGuardForSession(hostContext, this.session, this.session.my_apps ?? []);
      }
      return;
    }
    this.session = updated;
    this.switchEnabled = updated.enabled !== false;
    ScheduledListStore.patchSession(updated);
  }

  private statusLabel(): string {
    if (!this.session) {
      return '';
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (this.session.enabled === false) {
      return '已关闭';
    }
    return getScheduledListStatusLabel(this.session, loadExitPlanIds(hostContext));
  }

  @Builder
  private buildStat(value: string, label: string, accent: boolean = false): void {
    Column({ space: 6 }) {
      Text(value)
        .fontSize(28)
        .fontWeight(FontWeight.Medium)
        .fontColor(accent ? SLEEP_ACCENT_COLOR : AppTheme.colors.textPrimary)
      Text(label)
        .fontSize(13)
        .fontColor(AppTheme.colors.textMuted)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildStatsCard(): void {
    Column({ space: 0 }) {
      Row() {
        this.buildStat(`${this.stats?.total_days ?? 0}天`, '累计早睡', false)
        this.buildStat(`${this.stats?.streak_days ?? 0}天`, '连续早睡', true)
        this.buildStat(`${this.stats?.success_rate ?? 0}%`, '完成率', false)
      }
      .width('100%')
      .padding({ top: 20, bottom: 18 })

      Divider().color(AppTheme.colors.divider)

      Row() {
        Text(`共${(this.stats?.total_days ?? 0) + (this.stats?.failed_days ?? 0)}天，失败${this.stats?.failed_days ?? 0}天`)
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .layoutWeight(1)
        Text('查看早睡记录')
          .fontSize(13)
          .fontColor(AppTheme.colors.primary)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .onClick(() => {
        if (this.session) {
          pushSleepRecords(this.session.session_id);
        }
      })
    }
    .width('100%')
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
  }

  private planCardStartClock(): string {
    if (!this.session) {
      return '22:30';
    }
    const start = this.session.schedule_start;
    if (start !== undefined && start.length > 0) {
      return start;
    }
    return '22:30';
  }

  private planCardEndClock(): string {
    if (!this.session) {
      return '06:30';
    }
    const end = this.session.schedule_end;
    if (end !== undefined && end.length > 0) {
      return end;
    }
    return '06:30';
  }

  private planCardDurationSuffix(): string {
    const start = this.planCardStartClock();
    const end = this.planCardEndClock();
    const durationMin = clockDurationMinutes(
      parseMinutesFromClock(start),
      parseMinutesFromClock(end, parseMinutesFromClock(start) + 60),
    );
    if (durationMin <= 0) {
      return '';
    }
    return ` · ${minutesToHours(durationMin)}`;
  }

  @Builder
  private buildPlanCard(): void {
    if (this.session) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text(this.session.title.length > 0 ? this.session.title : '早睡守护')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .layoutWeight(1)
        Text(this.statusLabel())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textSecondary)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .borderRadius(999)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(`${this.planCardStartClock()} - ${this.planCardEndClock()}${this.planCardDurationSuffix()}`)
        .fontSize(15)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      Text(`${summarizeRepeatDays(repeatDaysOfSession(this.session))} · ${getScheduledParticipationLabel(this.session)}`)
        .fontSize(13)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
    .opacity(this.session.enabled !== false ? 1 : 0.88)
    }
  }

  @Builder
  private buildEmpty(): void {
    Column({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.moon'))
        .fontSize(48)
        .fontColor([SLEEP_ACCENT_COLOR])
      Text('还没有早睡契约')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
      Text('从今天开始，帮你彻底戒掉熬夜')
        .fontSize(14)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textMuted)
        .textAlign(TextAlign.Center)
        .width('100%')

      Column({ space: 8 }) {
        Text('为什么熬夜有毒，必须早睡？')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(SLEEP_ACCENT_COLOR)
          .width('100%')
        Text('每熬一夜，都在透支明天。深夜刷手机会压住褪黑素，睡得浅、醒得累：第二天注意力散、记不住、易怒，越熬越废。你以为只是多刷一会儿，其实是在透支健康。下定决心，今天就早睡！')
          .fontSize(14)
          .lineHeight(21)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor('rgba(6, 182, 212, 0.12)')
      .borderRadius(AppTheme.radius.lg)
      .border({ width: 1, color: 'rgba(6, 182, 212, 0.28)' })

      Button('添加早睡')
        .width('100%')
        .height(48)
        .borderRadius(AppTheme.radius.button)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .margin({ top: 8 })
        .onClick(() => {
          this.openCreate();
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 24, bottom: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildActiveContent(): void {
    Column({ space: 14 }) {
      this.buildStatsCard()
      this.buildPlanCard()
      Text('今晚的自律，是给明天清醒的自己最好的礼物。')
        .fontSize(14)
        .lineHeight(21)
        .fontColor(AppTheme.colors.textMuted)
        .fontStyle(FontStyle.Italic)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 4 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
  }

  @Builder
  private buildSettingsEntry(): void {
    Text('早睡设置')
      .fontSize(15)
      .fontColor(AppTheme.colors.textMuted)
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding({ top: 8, bottom: 28 })
      .onClick(() => {
        if (this.session) {
          this.switchEnabled = this.session.enabled !== false;
        }
        this.settingsOpen = true;
      })
  }

  @Builder
  private buildSettingsSheet(): void {
    Column({ space: 16 }) {
      Text('早睡设置')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
        .textAlign(TextAlign.Center)

      Column({ space: 8 }) {
        Row() {
          Text('启用任务')
            .fontSize(16)
            .fontColor(AppTheme.colors.textPrimary)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.switchEnabled })
            .selectedColor(AppTheme.colors.primary)
            .enabled(this.session?.viewer_role === 'initiator' && !this.toggleBusy)
            .onChange((isOn: boolean) => {
              void this.onToggleEnabled(isOn);
            })
        }
        .width('100%')
        Text('启用后才会生效，关闭则不生效')
          .fontSize(13)
          .lineHeight(18)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppTheme.colors.surface)
      .borderRadius(AppTheme.radius.lg)

      Button('编辑早睡计划')
        .width('100%')
        .height(48)
        .type(ButtonType.Normal)
        .backgroundColor(AppTheme.colors.surface)
        .fontColor(AppTheme.colors.primary)
        .borderRadius(AppTheme.radius.button)
        .onClick(() => {
          this.openEdit();
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 24 })
  }

  @Builder
  private buildPageContent(): void {
    if (this.loadingList) {
      LoadingProgress().width(36).height(36).margin({ top: 80 })
    } else if (this.session) {
      Column() {
        Scroll() {
          this.buildActiveContent()
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        this.buildSettingsEntry()
      }
      .width('100%')
      .height('100%')
    } else {
      this.buildEmpty()
    }
  }

  build() {
    Stack() {
      ProQuickPayHost({ hostId: 'sleep_plan' })
      SystemNavPage({
        title: '早睡',
        showBack: true,
        usePageScroll: false,
        horizontalPadding: 0,
        bottomSpacerHeight: 0,
        useFloatingTabInset: false,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildPageContent();
        },
      })

      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.settingsOpen, this.buildSettingsSheet(), {
          height: SheetSize.FIT_CONTENT,
          preferType: SheetType.BOTTOM,
          showClose: true,
          dragBar: true,
          backgroundColor: AppTheme.colors.backgroundSoft,
          onDisappear: () => {
            this.settingsOpen = false;
          },
        })
    }
    .width('100%')
    .height('100%')
  }
}

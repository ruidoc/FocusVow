import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { DuoInviteClipboardService, extractDuoInviteToken } from '../../services/DuoInviteClipboardService';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { DuoSessionView } from '../../models/DuoModel';
import { QuickFocusOptions } from '../../models/ActiveLockModel';
import { PageRoutes, backRoute, replaceRoute } from '../../router/PageRoutes';
import { applyScreenRestriction } from '../../services/ScreenTimeService';
import { DuoApiService } from '../../services/DuoApiService';
import { LockStore } from '../../stores/LockStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Entry
@Component
struct DuoWaitPage {
  @StorageLink(StoreKeys.SettingsSelectedTokens) selectedTokens: string[] = [];
  @State session: DuoSessionView | null = null;
  @State inviteText: string = '';
  @State remainSeconds: number = 300;
  @State isStarting: boolean = false;

  private sessionId: string = '';
  private timerId: number = -1;

  aboutToAppear(): void {
    this.sessionId = String(AppStorage.get<string>('duo.wait.session_id') ?? '');
    this.inviteText = String(AppStorage.get<string>('duo.wait.invite_text') ?? '');
    if (this.sessionId.length === 0) {
      backRoute();
      return;
    }
    void this.refreshSession();
    this.startTimers();
  }

  aboutToDisappear(): void {
    this.clearTimers();
  }

  private clearTimers(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private startTimers(): void {
    this.clearTimers();
    this.timerId = setInterval(() => {
      if (this.remainSeconds > 0) {
        this.remainSeconds -= 1;
        return;
      }
      void this.refreshSession();
    }, 1000);
  }

  private toastError(message: string): void {
    showErrorToast(message, this.getUIContext());
  }

  private remainLabel(): string {
    const minutes = Math.floor(this.remainSeconds / 60);
    const seconds = (this.remainSeconds % 60).toString().padStart(2, '0');
    return `${minutes}:${seconds}`;
  }

  private getSessionTitle(): string {
    return this.session?.title ?? String(AppStorage.get<string>('duo.wait.title') ?? '双人连坐');
  }

  private getSessionDurationLabel(): string {
    const durationMin = Number(AppStorage.get<number>('duo.wait.duration_min') ?? this.session?.duration_min ?? 0);
    if (durationMin >= 60) {
      const h = Math.floor(durationMin / 60);
      const m = durationMin % 60;
      return m === 0 ? `${h} 小时` : `${h} 小时 ${m} 分钟`;
    }
    return `${durationMin} 分钟`;
  }

  private getInitiatorName(): string {
    return this.session?.initiator?.nickname ?? '我';
  }

  private getPartnerName(): string {
    return this.session?.partner?.nickname ?? '等待搭子';
  }

  private async refreshSession(): Promise<void> {
    const response = await DuoApiService.getSession(this.sessionId);
    const next = DuoApiService.parseSession(response);
    if (!next) {
      if (response.statusCode === 400 && (response.message ?? '').includes('过期')) {
        this.toastError('邀请已过期');
        this.clearTimers();
        replaceRoute(PageRoutes.FocusHome);
      }
      return;
    }

    this.session = next;
    if (next.invite_text && next.invite_text.length > 0) {
      this.inviteText = next.invite_text;
      AppStorage.setOrCreate('duo.wait.invite_text', next.invite_text);
    }
    if (next.expire_at) {
      const remain = Math.max(0, Math.floor((new Date(next.expire_at).getTime() - Date.now()) / 1000));
      this.remainSeconds = remain;
    }

    if (next.status === 'expired' || next.status === 'cancelled') {
      this.clearTimers();
      this.toastError(next.status === 'cancelled' ? '已取消邀请' : '邀请已过期');
      replaceRoute(PageRoutes.FocusHome);
      return;
    }

    if (next.status === 'active') {
      await this.startLocalFocus(next);
    }
  }

  private async startLocalFocus(session: DuoSessionView): Promise<void> {
    if (this.isStarting) {
      return;
    }
    this.isStarting = true;
    this.clearTimers();

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const durationMin = Number(AppStorage.get<number>('duo.wait.duration_min') ?? session.duration_min);
    const title = String(AppStorage.get<string>('duo.wait.title') ?? session.title);
    const result = await applyScreenRestriction(this.selectedTokens, 'allow');
    if (!result.ok) {
      this.toastError(result.message);
      this.isStarting = false;
      return;
    }

    const focusOptions: QuickFocusOptions = {
      title,
      duoSessionId: session.session_id,
      recordId: session.my_record_id || session.record_id || '',
      participationMode: 'duo'
    };
    LockStore.startQuickFocus(hostContext, this.selectedTokens, durationMin, 'allow', focusOptions);
    replaceRoute(PageRoutes.FocusHome);
  }

  private async copyInvite(): Promise<void> {
    if (this.inviteText.length === 0) {
      return;
    }
    const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.inviteText);
    const systemPasteboard = pasteboard.getSystemPasteboard();
    await systemPasteboard.setData(pasteData);
    DuoInviteClipboardService.dismissToken(extractDuoInviteToken(this.inviteText));
    showToast('口令已复制，请发给搭子', this.getUIContext());
  }

  private async cancelInvite(): Promise<void> {
    await DuoApiService.cancelSession(this.sessionId);
    this.clearTimers();
    replaceRoute(PageRoutes.FocusHome);
  }

  @Builder
  private buildParticipantRow(name: string, status: string, active: boolean): void {
    Row({ space: 10 }) {
      Text(name.substring(0, 1))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(active ? AppTheme.colors.primary : AppTheme.colors.textMuted)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor(active ? AppTheme.colors.primarySoft : AppTheme.colors.surfaceRaised)
        .borderRadius(18)

      Column({ space: 2 }) {
        Text(name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')
        Text(status)
          .fontSize(12)
          .fontColor(active ? AppTheme.colors.success : AppTheme.colors.textMuted)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildRitualCard(): void {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Text(this.getSessionTitle())
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')
          .textAlign(TextAlign.Center)

        Text(`${this.getSessionDurationLabel()} · 一人撕毁，两人失败`)
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')

      Column({ space: 12 }) {
        this.buildParticipantRow(this.getInitiatorName(), '已发起契约', true)
        this.buildParticipantRow(
          this.getPartnerName(),
          this.session?.partner ? '已加入，准备开始' : '等待加入',
          this.session?.partner !== null && this.session?.partner !== undefined
        )
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
  }

  @Builder
  private buildInviteCard(): void {
    Column({ space: 12 }) {
      Text('邀请口令')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Text(this.inviteText.length > 0 ? this.inviteText : '正在生成口令…')
        .fontSize(14)
        .lineHeight(22)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
  }

  @Builder
  private buildPageBody(): void {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text(this.remainLabel())
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')
          .textAlign(TextAlign.Center)

        Text('等待搭子加入')
          .fontSize(16)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')

      Text('把下方口令发给搭子，对方加入后双方将同时开始锁机。')
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      this.buildRitualCard()
      this.buildInviteCard()

      Button('复制口令')
        .width('100%')
        .height(52)
        .type(ButtonType.Capsule)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .onClick(() => {
          void this.copyInvite();
        })

      Button('取消邀请')
        .width('100%')
        .height(52)
        .type(ButtonType.Capsule)
        .backgroundColor(AppTheme.colors.surface)
        .fontColor(AppTheme.colors.textPrimary)
        .border({ width: 1, color: AppTheme.colors.border })
        .onClick(() => {
          void this.cancelInvite();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '等待搭子',
        showBack: true,
        usePageScroll: true,
        bottomSpacerHeight: 28,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildPageBody();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

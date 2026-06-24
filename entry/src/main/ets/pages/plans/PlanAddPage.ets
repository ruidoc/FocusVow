import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { AppActionButton } from '../../components/common/AppActionButton';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { PLAN_REPEAT_DAY_OPTIONS, getRepeatDayShortLabel, validateScheduledStartTime } from '../../models/PlanModel';
import { DuoScheduledCreatePayload, DuoParticipationMode } from '../../models/DuoModel';
import { PageRoutes, backRoute, replaceRoute } from '../../router/PageRoutes';
import {
  chooseRestrictedApps,
  ensureScreenTimeAuthorization
} from '../../services/ScreenTimeService';
import { DuoApiService } from '../../services/DuoApiService';
import { DuoInviteClipboardService } from '../../services/DuoInviteClipboardService';
import { setScheduledDuoWait } from '../../services/DuoWaitContextService';
import { markGuardSyncIssue, syncGuardForSession } from '../../services/ScheduledCovenantService';
import { ScheduledListStore } from '../../stores/ScheduledListStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

/** 与 TimePicker.onChange 入参结构对齐 */
interface PlanTimePickerResult {
  hour: number;
  minute: number;
}

@Entry
@Component
struct PlanAddPage {
  @State planName: string = '';
  @State startTime: string = '09:00';
  @State endTime: string = '09:30';
  @State repeatDays: number[] = [1, 2, 3, 4, 5];
  @State selectedTokens: string[] = [];
  @State mode: 'shield' | 'allow' = 'allow';
  @State participationMode: DuoParticipationMode = 'solo';
  @State isSaving: boolean = false;
  @State hasInitializedDefaultTime: boolean = false;
  @State timePickerVisible: boolean = false;
  @State timePickerTarget: 'start' | 'end' = 'start';
  @State timePickerDraft: Date = new Date();

  private readonly dayOptions: number[] = PLAN_REPEAT_DAY_OPTIONS;

  private padTimePart(value: number): string {
    return value.toString().padStart(2, '0');
  }

  private formatTime(date: Date): string {
    return `${this.padTimePart(date.getHours())}:${this.padTimePart(date.getMinutes())}`;
  }

  private initDefaultTimeRange(): void {
    const now = new Date();
    const start = new Date(now.getTime() + 5 * 60 * 1000);
    const end = new Date(start.getTime() + 30 * 60 * 1000);
    this.startTime = this.formatTime(start);
    this.endTime = this.formatTime(end);
    this.hasInitializedDefaultTime = true;
  }

  private timeStringToDate(time: string): Date {
    const normalized = time.trim();
    const result = new Date();
    if (!normalized.includes(':')) {
      return result;
    }
    const parts = normalized.split(':');
    const hour = Math.min(23, Math.max(0, Math.floor(Number(parts[0]) || 0)));
    const minute = Math.min(59, Math.max(0, Math.floor(Number(parts[1]) || 0)));
    result.setHours(hour, minute, 0, 0);
    return result;
  }

  private openTimePicker(target: 'start' | 'end'): void {
    this.timePickerTarget = target;
    this.timePickerDraft = this.timeStringToDate(target === 'start' ? this.startTime : this.endTime);
    this.timePickerVisible = true;
  }

  private confirmTimePicker(): void {
    const nextTime = this.formatTime(this.timePickerDraft);
    if (this.timePickerTarget === 'start') {
      this.startTime = nextTime;
    } else {
      this.endTime = nextTime;
    }
    this.timePickerVisible = false;
  }

  private cancelTimePicker(): void {
    this.timePickerVisible = false;
  }

  private appCardTitle(): string {
    return '要放行的应用';
  }

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    UserStore.hydrate(hostContext);
    const settingsState = SettingsStore.getState();
    this.selectedTokens = [...settingsState.selectedTokens];
    if (!this.hasInitializedDefaultTime) {
      this.initDefaultTimeRange();
    }
  }

  private toggleRepeatDay(day: number): void {
    if (this.repeatDays.includes(day)) {
      this.repeatDays = this.repeatDays.filter((item: number) => item !== day);
      return;
    }

    this.repeatDays = [...this.repeatDays, day].sort((left, right) => left - right);
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    if (result.data) {
      this.selectedTokens = [...result.data];
      SettingsStore.updateSelectedTokens(hostContext, result.data, result.message);
      return;
    }

    if (result.message.length > 0) {
      showErrorToast(result.message, this.getUIContext());
    }
  }

  private timeToMinutes(time: string): number {
    const parts = time.split(':');
    const hour = Math.floor(Number(parts[0]) || 0);
    const minute = Math.floor(Number(parts[1]) || 0);
    return hour * 60 + minute;
  }

  private async savePlan(): Promise<void> {
    if (this.isSaving) {
      return;
    }

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const uiContext = this.getUIContext();
    if (!UserStore.isLoggedIn()) {
      showErrorToast('请先登录后再创建契约', uiContext);
      return;
    }
    if (this.selectedTokens.length === 0) {
      showErrorToast('请先至少选择 1 个应用，再保存契约', uiContext);
      return;
    }
    if (this.planName.trim().length === 0) {
      showErrorToast('请先填写本次契约要做什么', uiContext);
      return;
    }
    if (this.participationMode === 'duo' && !UserStore.isLoggedIn()) {
      showErrorToast('搭子互督需要先登录账号', uiContext);
      return;
    }

    const startTimeError = validateScheduledStartTime(this.startTime, this.repeatDays);
    if (startTimeError.length > 0) {
      showErrorToast(startTimeError, uiContext);
      return;
    }

    this.isSaving = true;
    const authResult = await ensureScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, authResult.ok, authResult.message);
    if (!authResult.ok) {
      showErrorToast('未完成系统授权，无法注册屏时策略', uiContext);
      this.isSaving = false;
      return;
    }

    const title = this.planName.trim();
    const schedulePayload: DuoScheduledCreatePayload = {
      title,
      start: this.startTime,
      start_min: this.timeToMinutes(this.startTime),
      end: this.endTime,
      end_min: this.timeToMinutes(this.endTime),
      repeat: this.repeatDays.join(','),
      participation_mode: this.participationMode,
      initiator_apps: [...this.selectedTokens],
      mode: this.mode
    };
    const scheduleResponse = await DuoApiService.scheduledCreate(schedulePayload);
    const session = DuoApiService.parseSession(scheduleResponse);
    if (!session) {
      showErrorToast(scheduleResponse.message ?? '创建契约失败', uiContext);
      this.isSaving = false;
      return;
    }

    const guardResult = await syncGuardForSession(hostContext, session);
    if (!guardResult.ok) {
      const warningMessage = '契约已创建，但本机屏时策略注册失败，请到计划页重试';
      markGuardSyncIssue(hostContext, session, warningMessage);
      SettingsStore.updateStatusMessage(hostContext, warningMessage);
      showErrorToast(warningMessage, uiContext);
    } else {
      SettingsStore.updateStatusMessage(hostContext, guardResult.message);
    }

    if (session.token.length > 0) {
      DuoInviteClipboardService.dismissToken(session.token);
    }

    ScheduledListStore.markDirty();
    ScheduledListStore.setFilter('initiated');

    if (this.participationMode === 'duo') {
      const scheduleLabel = `${this.startTime} - ${this.endTime}`;
      setScheduledDuoWait(session, scheduleLabel);
      if (guardResult.ok) {
        showToast('创建成功，请邀请搭子加入', uiContext);
      }
      this.isSaving = false;
      replaceRoute(PageRoutes.DuoWait);
      return;
    }

    if (guardResult.ok) {
      showToast('创建成功', uiContext);
    }
    this.isSaving = false;
    backRoute();
  }

  @Builder
  buildParticipationCard(): void {
    Column({ space: 14 }) {
      Text('履约方式')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Row({ space: 0 }) {
        Text('单人专注')
          .layoutWeight(1)
          .fontSize(15)
          .fontColor(this.participationMode === 'solo' ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary)
          .fontWeight(this.participationMode === 'solo' ? FontWeight.Medium : FontWeight.Regular)
          .textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
          .borderRadius(20)
          .backgroundColor(this.participationMode === 'solo' ? AppTheme.colors.surface : Color.Transparent)
          .onClick(() => {
            this.participationMode = 'solo';
          })

        Text('搭子互督')
          .layoutWeight(1)
          .fontSize(15)
          .fontColor(this.participationMode === 'duo' ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary)
          .fontWeight(this.participationMode === 'duo' ? FontWeight.Medium : FontWeight.Regular)
          .textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
          .borderRadius(20)
          .backgroundColor(this.participationMode === 'duo' ? AppTheme.colors.surface : Color.Transparent)
          .onClick(() => {
            this.participationMode = 'duo';
          })
      }
      .width('100%')
      .padding(4)
      .backgroundColor(AppTheme.colors.surfaceRaised)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(999)

      Text(this.participationMode === 'duo'
        ? '保存后邀请搭子，到点双方一起履约；一人撕毁，两人都记为失败。'
        : '仅自己按时段履约，适合固定学习节奏。')
        .fontSize(13)
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
  buildModeSegment(): void {
    Row({ space: 0 }) {
      Text('锁定模式')
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(this.mode === 'shield' ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary)
        .fontWeight(this.mode === 'shield' ? FontWeight.Medium : FontWeight.Regular)
        .textAlign(TextAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .borderRadius(20)
        .backgroundColor(this.mode === 'shield' ? AppTheme.colors.surfaceRaised : Color.Transparent)
        .onClick(() => {
          this.mode = 'shield';
        })

      Text('放行模式')
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(this.mode === 'allow' ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary)
        .fontWeight(this.mode === 'allow' ? FontWeight.Medium : FontWeight.Regular)
        .textAlign(TextAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .borderRadius(20)
        .backgroundColor(this.mode === 'allow' ? AppTheme.colors.surfaceRaised : Color.Transparent)
        .onClick(() => {
          this.mode = 'allow';
        })
    }
    .width('80%')
    .padding(4)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(999)
  }

  @Builder
  buildNameCard(): void {
    Column({ space: 14 }) {
      Text('契约名称')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      TextInput({ text: this.planName, placeholder: '请输入' })
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontColor(AppTheme.colors.textPrimary)
        .placeholderColor(AppTheme.colors.textMuted)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .border({ width: 1, color: AppTheme.colors.border })
        .borderRadius(12)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.planName = value;
        })
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
  }

  @Builder
  buildTimeCard(): void {
    Column({ space: 14 }) {
      Text('专注时段')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')

      Row({ space: 8 }) {
        Row({ space: 6 }) {
          Text(this.startTime)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)

          SymbolGlyph($r('sys.symbol.clock'))
            .fontSize(14)
            .fontColor([AppTheme.colors.textMuted])
        }
        .layoutWeight(1)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .border({ width: 1, color: AppTheme.colors.border })
        .borderRadius(12)
        .onClick(() => {
          this.openTimePicker('start');
        })

        Text('至')
          .fontSize(14)
          .fontColor(AppTheme.colors.textMuted)

        Row({ space: 6 }) {
          Text(this.endTime)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)

          SymbolGlyph($r('sys.symbol.clock'))
            .fontSize(14)
            .fontColor([AppTheme.colors.textMuted])
        }
        .layoutWeight(1)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .border({ width: 1, color: AppTheme.colors.border })
        .borderRadius(12)
        .onClick(() => {
          this.openTimePicker('end');
        })
      }
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
  buildAppCard(): void {
    Column({ space: 14 }) {
      Row() {
        Text(this.appCardTitle())
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)

        Text('+ 选择')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.primary)
          .onClick(() => {
            this.chooseApps();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.selectedTokens.length === 0) {
        Text('未选择应用')
          .fontSize(15)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
      } else {
        Text(`已选 ${this.selectedTokens.length} 个应用`)
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
  }

  @Builder
  buildRepeatDaysCard(): void {
    Column({ space: 14 }) {
      Row() {
        Text('每周几重复')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
        Blank()
        Text(`已选${this.repeatDays.length}天`)
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach(this.dayOptions, (item: number) => {
          Button({ type: ButtonType.Capsule }) {
            Stack() {
              Text(getRepeatDayShortLabel(item))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.repeatDays.includes(item) ? '#FFFFFF' : AppTheme.colors.textPrimary)
            }
            .width('100%')
            .height('100%')
            .alignContent(Alignment.Center)
          }
          .width(36)
          .height(36)
          .padding(0)
          .backgroundColor(this.repeatDays.includes(item) ? AppTheme.colors.primary : AppTheme.colors.surfaceRaised)
          .onClick(() => {
            this.toggleRepeatDay(item);
          })
        }, (item: number) => item.toString())
      }
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
  buildContractBody(): void {
    Column({ space: 18 }) {
      this.buildNameCard()
      this.buildTimeCard()
      this.buildParticipationCard()
      this.buildAppCard()
      this.buildRepeatDaysCard()

      AppActionButton({
        label: this.isSaving ? '创建中...' : '签定契约',
        isEnabled: !this.isSaving,
        onPress: () => {
          void this.savePlan();
        }
      })
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildTimePickerSheet(): void {
    Column({ space: 18 }) {
      Text(this.timePickerTarget === 'start' ? '选择开始时间' : '选择结束时间')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
        .textAlign(TextAlign.Center)

      TimePicker({
        selected: this.timePickerDraft,
        format: TimePickerFormat.HOUR_MINUTE
      })
        .width('100%')
        .useMilitaryTime(true)
        .onChange((value: PlanTimePickerResult) => {
          const next = new Date(this.timePickerDraft);
          next.setHours(value.hour, value.minute, 0, 0);
          this.timePickerDraft = next;
        })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(48)
          .type(ButtonType.Capsule)
          .fontSize(16)
          .fontColor(AppTheme.colors.textSecondary)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .onClick(() => {
            this.cancelTimePicker();
          })

        Button('确定')
          .layoutWeight(1)
          .height(48)
          .type(ButtonType.Capsule)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(AppTheme.colors.primary)
          .onClick(() => {
            this.confirmTimePicker();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: 20,
      bottom: 28
    })
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '创建契约',
        showBack: true,
        usePageScroll: true,
        bottomSpacerHeight: 28,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildContractBody();
        }
      })

      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.timePickerVisible, this.buildTimePickerSheet(), {
          height: SheetSize.FIT_CONTENT,
          preferType: SheetType.BOTTOM,
          showClose: false,
          dragBar: true,
          backgroundColor: AppTheme.colors.backgroundSoft
        })
    }
    .width('100%')
    .height('100%')
  }
}

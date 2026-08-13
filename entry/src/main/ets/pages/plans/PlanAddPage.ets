import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
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
import { validateScheduledPlanTime } from '../../services/ScheduledPlanValidation';
import { ScheduledListStore } from '../../stores/ScheduledListStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

/** 创建契约暂不展示履约方式，默认单人；改 true 可恢复 */
const SHOW_PARTICIPATION_MODE: boolean = false;

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
  private nameInputController: TextInputController = new TextInputController();

  private padTimePart(value: number): string {
    return value.toString().padStart(2, '0');
  }

  private formatTime(date: Date): string {
    return `${this.padTimePart(date.getHours())}:${this.padTimePart(date.getMinutes())}`;
  }

  private initDefaultTimeRange(): void {
    const now = new Date();
    let start = new Date(now.getTime());
    let end = new Date(start.getTime() + 20 * 60 * 1000);
    if (end.getDate() !== start.getDate() || end.getMonth() !== start.getMonth()) {
      start = new Date(now.getTime());
      start.setHours(23, 40, 0, 0);
      end = new Date(start.getTime() + 20 * 60 * 1000);
    }
    this.startTime = this.formatTime(start);
    this.endTime = this.formatTime(end);
    this.hasInitializedDefaultTime = true;
  }

  private minutesToTime(totalMinutes: number): string {
    const hour = Math.floor(totalMinutes / 60);
    const minute = totalMinutes % 60;
    return `${this.padTimePart(hour)}:${this.padTimePart(minute)}`;
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
    this.blurNameInput();
    this.timePickerTarget = target;
    this.timePickerDraft = this.timeStringToDate(target === 'start' ? this.startTime : this.endTime);
    this.timePickerVisible = true;
  }

  private confirmTimePicker(): void {
    const nextTime = this.formatTime(this.timePickerDraft);
    const uiContext = this.getUIContext();
    if (this.timePickerTarget === 'start') {
      const startMin = this.timeToMinutes(nextTime);
      const endMin = startMin + 20;
      if (endMin > 24 * 60 - 1) {
        showErrorToast('暂不支持跨日，请改早一点的开始时间', uiContext);
        this.timePickerVisible = false;
        return;
      }
      this.startTime = nextTime;
      this.endTime = this.minutesToTime(endMin);
    } else {
      const startMin = this.timeToMinutes(this.startTime);
      const endMin = this.timeToMinutes(nextTime);
      if (endMin <= startMin) {
        showErrorToast('暂不支持跨日，请将结束时间设在当天内', uiContext);
        this.timePickerVisible = false;
        return;
      }
      if (endMin - startMin < 20) {
        showErrorToast('时长至少20分钟', uiContext);
        this.timePickerVisible = false;
        return;
      }
      this.endTime = nextTime;
    }
    this.timePickerVisible = false;
  }

  private cancelTimePicker(): void {
    this.timePickerVisible = false;
  }

  private appCardTitle(): string {
    return this.mode === 'allow' ? '允许使用的应用' : '要锁定的应用';
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

  private blurNameInput(): void {
    this.nameInputController.stopEditing();
  }

  private async chooseApps(): Promise<void> {
    this.blurNameInput();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    this.blurNameInput();
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
    if (this.planName.trim().length === 0) {
      showErrorToast('请输入契约名称', uiContext);
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

    ScheduledListStore.hydrate();
    const scheduleTimeError = validateScheduledPlanTime(
      this.startTime,
      this.endTime,
      this.repeatDays,
      ScheduledListStore.getAllSessions()
    );
    if (scheduleTimeError.length > 0) {
      showErrorToast(scheduleTimeError, uiContext);
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
      showToast('契约已签订，请务必遵守', uiContext);
    }
    this.isSaving = false;
    backRoute();
  }

  @Builder
  buildParticipationCard(): void {
    Column() {
      Row() {
        Text('履约方式')
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)

        Blank()

        Row({ space: 0 }) {
          Text('单人专注')
            .fontSize(13)
            .fontColor(this.participationMode === 'solo' ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary)
            .fontWeight(this.participationMode === 'solo' ? FontWeight.Medium : FontWeight.Regular)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(8)
            .backgroundColor(this.participationMode === 'solo' ? AppTheme.colors.surfaceRaised : Color.Transparent)
            .onClick(() => {
              this.participationMode = 'solo';
            })

          Text('搭子互督')
            .fontSize(13)
            .fontColor(this.participationMode === 'duo' ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary)
            .fontWeight(this.participationMode === 'duo' ? FontWeight.Medium : FontWeight.Regular)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(8)
            .backgroundColor(this.participationMode === 'duo' ? AppTheme.colors.surfaceRaised : Color.Transparent)
            .onClick(() => {
              this.participationMode = 'duo';
            })
        }
        .padding(2)
        .border({ width: 1, color: AppTheme.colors.border })
        .borderRadius(10)
        .backgroundColor(AppTheme.colors.surface)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      Text(this.participationMode === 'duo'
        ? '保存后邀请搭子，到点双方一起履约；一人撕毁，两人都记为失败。'
        : '仅自己按时段履约，适合固定学习节奏。')
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 18 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .clip(true)
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
    Row() {
      Text('契约名称')
        .fontSize(16)
        .fontColor(AppTheme.colors.textPrimary)

      TextInput({
        text: this.planName,
        placeholder: '请输入',
        controller: this.nameInputController
      })
        .layoutWeight(1)
        .height(40)
        .fontSize(15)
        .fontColor(AppTheme.colors.textPrimary)
        .placeholderColor(AppTheme.colors.textMuted)
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .border({ width: 0 })
        .showUnderline(false)
        .cancelButton({ style: CancelButtonStyle.INVISIBLE })
        .defaultFocus(false)
        .textAlign(TextAlign.End)
        .padding({ left: 12, right: 8 })
        .enterKeyType(EnterKeyType.Done)
        .onChange((value: string) => {
          this.planName = value;
        })
        .onSubmit(() => {
          this.blurNameInput();
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 58 })
    .padding({ left: 18, right: 18, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .clip(true)
  }

  @Builder
  buildTimeCard(): void {
    Row() {
      Text('起始时间')
        .fontSize(16)
        .fontColor(AppTheme.colors.textPrimary)

      Blank()

      Row({ space: 8 }) {
        Text(this.startTime)
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(8)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .onClick(() => {
            this.openTimePicker('start');
          })

        Text('至')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)

        Text(this.endTime)
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(8)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .onClick(() => {
            this.openTimePicker('end');
          })
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .clip(true)
  }

  @Builder
  buildAppCard(): void {
    Column() {
      Row() {
        Text(this.appCardTitle())
          .layoutWeight(1)
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)

        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(14)
            .fontColor([AppTheme.colors.textMuted])
          Text('选择')
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .borderRadius(16)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .onClick(() => {
          this.chooseApps();
        })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      Text(this.selectedTokens.length === 0 ? '未选择应用' : `已选 ${this.selectedTokens.length} 个应用`)
        .fontSize(14)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 18 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .clip(true)
  }

  @Builder
  buildRepeatDaysCard(): void {
    Column() {
      Row() {
        Text('每周几重复')
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)
        Blank()
        Text(`已选${this.repeatDays.length}天`)
          .fontSize(14)
          .fontColor(AppTheme.colors.textMuted)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 8 })

      Row({ space: 8 }) {
        ForEach(this.dayOptions, (item: number) => {
          Stack() {
            Text(getRepeatDayShortLabel(item))
              .fontSize(15)
              .fontColor(this.repeatDays.includes(item) ? '#FFFFFF' : AppTheme.colors.textPrimary)
          }
          .width(38)
          .height(38)
          .borderRadius(19)
          .clip(true)
          .backgroundColor(this.repeatDays.includes(item) ? AppTheme.colors.primary : AppTheme.colors.border)
          .onClick(() => {
            this.toggleRepeatDay(item);
          })
        }, (item: number) => item.toString())
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 8, bottom: 20 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .clip(true)
  }

  @Builder
  buildContractBody(): void {
    Column({ space: 18 }) {
      this.buildNameCard()
      if (SHOW_PARTICIPATION_MODE) {
        this.buildParticipationCard()
      }
      this.buildTimeCard()
      this.buildAppCard()
      this.buildRepeatDaysCard()

      Button(this.isSaving ? '生效中...' : '签定契约')
        .width('100%')
        .height(52)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .borderRadius(AppTheme.radius.button)
        .clip(true)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .enabled(!this.isSaving)
        .opacity(this.isSaving ? 0.7 : 1)
        .margin({ top: 12 })
        .onClick(() => {
          void this.savePlan();
        })
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
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .fontSize(16)
          .fontColor(AppTheme.colors.textSecondary)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .onClick(() => {
            this.cancelTimePicker();
          })

        Button('确定')
          .layoutWeight(1)
          .height(48)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
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

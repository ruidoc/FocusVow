import { common } from '@kit.AbilityKit';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { PlanDraft, PLAN_REPEAT_DAY_OPTIONS, getRepeatDayShortLabel } from '../../models/PlanModel';
import { PageRoutes, backRoute, replaceRoute } from '../../router/PageRoutes';
import {
  chooseRestrictedApps,
  ensureScreenTimeAuthorization,
  syncPlanGuardStrategy
} from '../../services/ScreenTimeService';
import { PlanStore } from '../../stores/PlanStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

/** 与 UIContext.showTimePickerDialog 的 onAccept 入参结构对齐（@kit.ArkUI 未导出对应类型名） */
interface PlanTimePickerAcceptValue {
  hour?: number;
  minute?: number;
}

@Entry
@Component
struct PlanAddPage {
  @State planName: string = '';
  @State startTime: string = '09:00';
  @State endTime: string = '09:30';
  @State repeatDays: number[] = [1, 2, 3, 4, 5];
  @State selectedTokens: string[] = [];
  @State mode: 'shield' | 'allow' = 'shield';
  @State statusMessage: string = '';
  @State hasInitializedDefaultTime: boolean = false;

  private readonly dayOptions: number[] = PLAN_REPEAT_DAY_OPTIONS;

  private padTimePart(value: number): string {
    return value.toString().padStart(2, '0');
  }

  private formatTime(date: Date): string {
    return `${this.padTimePart(date.getHours())}:${this.padTimePart(date.getMinutes())}`;
  }

  private initDefaultTimeRange(): void {
    const now = new Date();
    const end = new Date(now.getTime() + 30 * 60 * 1000);
    this.startTime = this.formatTime(now);
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

  private showStartTimePicker(): void {
    this.getUIContext().showTimePickerDialog({
      selected: this.timeStringToDate(this.startTime),
      useMilitaryTime: true,
      onAccept: (value: PlanTimePickerAcceptValue) => {
        if (value.hour !== undefined && value.minute !== undefined) {
          this.startTime = `${this.padTimePart(value.hour)}:${this.padTimePart(value.minute)}`;
        }
      }
    });
  }

  private showEndTimePicker(): void {
    this.getUIContext().showTimePickerDialog({
      selected: this.timeStringToDate(this.endTime),
      useMilitaryTime: true,
      onAccept: (value: PlanTimePickerAcceptValue) => {
        if (value.hour !== undefined && value.minute !== undefined) {
          this.endTime = `${this.padTimePart(value.hour)}:${this.padTimePart(value.minute)}`;
        }
      }
    });
  }

  private appCardTitle(): string {
    return this.mode === 'shield' ? '要锁定的应用' : '要放行的应用';
  }

  private shouldShowStatusLine(): boolean {
    if (this.statusMessage.length === 0) {
      return false;
    }
    const m = /^已选择 (\d+) 个应用$/.exec(this.statusMessage);
    if (m !== null && Number(m[1]) === this.selectedTokens.length) {
      return false;
    }
    return true;
  }

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    const settingsState = SettingsStore.getState();
    this.selectedTokens = [...settingsState.selectedTokens];
    this.statusMessage = settingsState.statusMessage;
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
      this.statusMessage = result.message;
      return;
    }

    this.statusMessage = result.message;
  }

  private async savePlan(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (this.selectedTokens.length === 0) {
      this.statusMessage = '请先至少选择 1 个应用，再保存契约';
      return;
    }

    const draft: PlanDraft = {
      name: this.planName,
      startTime: this.startTime,
      endTime: this.endTime,
      repeatDays: this.repeatDays,
      selectedTokens: this.selectedTokens,
      mode: this.mode
    };

    const authResult = await ensureScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, authResult.ok, authResult.message);
    const savedPlan = PlanStore.savePlan(hostContext, draft);
    if (!authResult.ok) {
      const message = '契约已保存，但未完成系统授权，系统不会自动按时生效';
      this.statusMessage = message;
      SettingsStore.updateStatusMessage(hostContext, message);
      replaceRoute(PageRoutes.PlanList);
      return;
    }

    const syncResult = await syncPlanGuardStrategy(savedPlan);
    this.statusMessage = syncResult.message;
    SettingsStore.updateStatusMessage(hostContext, syncResult.message);
    replaceRoute(PageRoutes.PlanList);
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
        Row() {
          Text(this.startTime)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
        }
        .layoutWeight(1)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .border({ width: 1, color: AppTheme.colors.border })
        .borderRadius(12)
        .onClick(() => {
          this.showStartTimePicker();
        })

        Text('至')
          .fontSize(14)
          .fontColor(AppTheme.colors.textMuted)

        Row() {
          Text(this.endTime)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
        }
        .layoutWeight(1)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .border({ width: 1, color: AppTheme.colors.border })
        .borderRadius(12)
        .onClick(() => {
          this.showEndTimePicker();
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

      if (this.shouldShowStatusLine()) {
        Text(this.statusMessage)
          .fontSize(12)
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
  buildValidityCard(): void {
    Row() {
      Text('有效时长')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
      Blank()
      Row({ space: 4 }) {
        Text('长期有效')
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
        Text('›')
          .fontSize(18)
          .fontColor(AppTheme.colors.textMuted)
      }
    }
    .width('100%')
    .padding(20)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
  }

  @Builder
  buildContractBody(): void {
    Column({ space: 18 }) {
      Row() {
        this.buildModeSegment()
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 8 })

      this.buildNameCard()
      this.buildTimeCard()
      this.buildAppCard()
      this.buildRepeatDaysCard()
      this.buildValidityCard()

      Button('签定契约')
        .width('100%')
        .height(52)
        .type(ButtonType.Capsule)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .margin({ top: 8 })
        .onClick(() => {
          void this.savePlan();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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
    }
    .width('100%')
    .height('100%')
  }
}

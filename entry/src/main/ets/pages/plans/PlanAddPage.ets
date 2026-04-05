import { common } from '@kit.AbilityKit';
import { PageScaffold } from '../../components/common/PageScaffold';
import { AppTheme } from '../../constants/Theme';
import { PlanDraft } from '../../models/PlanModel';
import { PageRoutes, backRoute, replaceRoute } from '../../router/PageRoutes';
import { chooseRestrictedApps } from '../../services/ScreenTimeService';
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
  @State startTime: string = '20:01';
  @State endTime: string = '20:21';
  @State repeatDays: number[] = [1, 2, 3, 4, 5];
  @State selectedTokens: string[] = [];
  @State mode: 'shield' | 'allow' = 'shield';
  @State statusMessage: string = '';

  private readonly dayOptions: number[] = [1, 2, 3, 4, 5, 6, 0];

  private padTimePart(value: number): string {
    return value.toString().padStart(2, '0');
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

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    const settingsState = SettingsStore.getState();
    this.selectedTokens = [...settingsState.selectedTokens];
    this.statusMessage = settingsState.statusMessage;
  }

  private getWeekdayLabel(day: number): string {
    switch (day) {
      case 1:
        return '一';
      case 2:
        return '二';
      case 3:
        return '三';
      case 4:
        return '四';
      case 5:
        return '五';
      case 6:
        return '六';
      default:
        return '日';
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

  private savePlan(): void {
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

    PlanStore.savePlan(hostContext, draft);
    replaceRoute(PageRoutes.PlanList);
  }

  private appsSubtitle(): string {
    if (this.selectedTokens.length === 0) {
      return '未选择应用';
    }
    return `已选 ${this.selectedTokens.length} 个应用`;
  }

  @Builder
  buildContractHeader(): void {
    Row() {
      Button() {
        Text('‹')
          .fontSize(22)
          .fontColor(AppTheme.colors.textPrimary)
      }
      .width(36)
      .height(36)
      .type(ButtonType.Normal)
      .backgroundColor(AppTheme.colors.surfaceRaised)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(18)
      .onClick(() => {
        backRoute();
      })

      Text('创建契约')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.textPrimary)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Row()
        .width(36)
        .height(36)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildContractBody(): void {
    Column() {
      Scroll() {
        Column({ space: 14 }) {
          Column() {
            Row() {
              Text('契约名称')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.colors.textPrimary)
              TextInput({ text: this.planName, placeholder: '请输入' })
                .layoutWeight(1)
                .height(40)
                .textAlign(TextAlign.End)
                .fontSize(15)
                .fontColor(AppTheme.colors.textPrimary)
                .placeholderColor(AppTheme.colors.textMuted)
                .backgroundColor(Color.Transparent)
                .border({ width: 0 })
                .onChange((value: string) => {
                  this.planName = value;
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .border({ width: 1, color: AppTheme.colors.border })
          .borderRadius(AppTheme.radius.sm)

          Column({ space: 14 }) {
            Row() {
              Text('起始时间')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.colors.textPrimary)
              Row({ space: 6 }) {
                Row() {
                  Text(this.startTime)
                    .fontSize(15)
                    .fontColor(AppTheme.colors.textPrimary)
                }
                .layoutWeight(1)
                .height(36)
                .justifyContent(FlexAlign.Center)
                .backgroundColor(AppTheme.colors.surface)
                .border({ width: 1, color: AppTheme.colors.border })
                .borderRadius(10)
                .onClick(() => {
                  this.showStartTimePicker();
                })

                Text('至')
                  .fontSize(14)
                  .fontColor(AppTheme.colors.textMuted)

                Row() {
                  Text(this.endTime)
                    .fontSize(15)
                    .fontColor(AppTheme.colors.textPrimary)
                }
                .layoutWeight(1)
                .height(36)
                .justifyContent(FlexAlign.Center)
                .backgroundColor(AppTheme.colors.surface)
                .border({ width: 1, color: AppTheme.colors.border })
                .borderRadius(10)
                .onClick(() => {
                  this.showEndTimePicker();
                })
              }
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .border({ width: 1, color: AppTheme.colors.border })
          .borderRadius(AppTheme.radius.sm)

          Row() {
            Text('锁定模式')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textPrimary)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.mode === 'allow' })
              .onChange((isOn: boolean) => {
                this.mode = isOn ? 'allow' : 'shield';
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .border({ width: 1, color: AppTheme.colors.border })
          .borderRadius(AppTheme.radius.sm)
          .alignItems(VerticalAlign.Center)

          Column({ space: 10 }) {
            Row() {
              Text(this.appCardTitle())
                .layoutWeight(1)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.colors.textPrimary)
              Button('+ 选择')
                .type(ButtonType.Capsule)
                .height(32)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .backgroundColor(AppTheme.colors.primarySoft)
                .fontColor(AppTheme.colors.primary)
                .border({ width: 1, color: AppTheme.colors.primary })
                .onClick(() => {
                  this.chooseApps();
                })
            }
            .width('100%')

            Text(this.appsSubtitle())
              .fontSize(13)
              .fontColor(AppTheme.colors.textMuted)
              .width('100%')

            if (this.statusMessage.length > 0) {
              Text(this.statusMessage)
                .fontSize(12)
                .fontColor(AppTheme.colors.textSecondary)
                .width('100%')
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .border({ width: 1, color: AppTheme.colors.border })
          .borderRadius(AppTheme.radius.sm)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 14 }) {
            Row() {
              Text('每周几重复')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.colors.textPrimary)
              Blank()
              Text(`已选${this.repeatDays.length}天`)
                .fontSize(13)
                .fontColor(AppTheme.colors.textMuted)
            }
            .width('100%')

            Row({ space: 4 }) {
              ForEach(this.dayOptions, (item: number) => {
                Button(this.getWeekdayLabel(item))
                  .layoutWeight(1)
                  .height(36)
                  .type(ButtonType.Capsule)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .backgroundColor(this.repeatDays.includes(item) ? AppTheme.colors.primary : AppTheme.colors.surface)
                  .fontColor(this.repeatDays.includes(item) ? '#FFFFFF' : AppTheme.colors.textPrimary)
                  .border({
                    width: 1,
                    color: this.repeatDays.includes(item) ? AppTheme.colors.primary : AppTheme.colors.border
                  })
                  .onClick(() => {
                    this.toggleRepeatDay(item);
                  })
              }, (item: number) => item.toString())
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .border({ width: 1, color: AppTheme.colors.border })
          .borderRadius(AppTheme.radius.sm)
          .alignItems(HorizontalAlign.Start)

          Row() {
            Text('有效时长')
              .fontSize(15)
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
          .padding(16)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .border({ width: 1, color: AppTheme.colors.border })
          .borderRadius(AppTheme.radius.sm)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding({ bottom: 8 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .align(Alignment.Top)

      Button('签定契约')
        .width('100%')
        .height(54)
        .type(ButtonType.Capsule)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .margin({ top: 12 })
        .onClick(() => {
          this.savePlan();
        })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      PageScaffold({
        headerMode: 'custom',
        showDecoration: true,
        topPadding: 12,
        bottomPadding: 12,
        horizontalPadding: 20,
        header: (): void => {
          this.buildContractHeader();
        },
        content: (): void => {
          this.buildContractBody();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
